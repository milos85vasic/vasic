#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Lumen index doctor — detect SILENTLY corrupt embeddings.
#
# WHY THIS EXISTS
# ---------------
# A GPU fault wrote 758 identical vectors covering 695 distinct texts across 55
# files into this project's index. Every conventional check passed: no NaN, no
# Inf, no all-zero, L2 norm 1.000000083, correct dimensionality. A full forensic
# audit declared the index "TRUSTWORTHY" on exactly those measurements — and was
# wrong, because a stale-but-well-formed vector is invisible per-vector.
#
# The only thing that exposes it is AGGREGATE distinctness: N distinct texts
# must produce N distinct vectors. This script checks that, alongside the
# conventional per-vector tests, and never opens the DB for writing.
#
#   ./scripts/lumen-index-doctor.sh [project-path] [--require-live-backend]
#
# Exit 0 = healthy · 1 = corruption found · 2 = could not inspect
#
# NOTHING BELOW IS ASSUMED ABOUT THE HOST. Every value is derived, and every
# derivation has an env override for when detection is wrong:
#
#   LUMEN_STORE          index store dir   (default $XDG_DATA_HOME/lumen,
#                                           XDG_DATA_HOME defaulting to
#                                           $HOME/.local/share — this is what
#                                           lumen's own config.XDGDataDir() does,
#                                           on macOS too)
#   LUMEN_INDEX_DB       pin one index.db and skip the store scan entirely
#   LUMEN_VEC_TABLE      pin the sqlite-vec vector shadow table
#   LUMEN_VEC_DIMS       pin the vector width (floats per vector)
#   LUMEN_VEC_ELEM       pin the element type: float32 | int8
#   LUMEN_EMBED_MODEL    pin the model lumen would use now
#   LUMEN_BACKEND        ollama | lmstudio
#   OLLAMA_HOST          ollama base URL   (scheme optional: host:port is fine)
#   LM_STUDIO_HOST       LM Studio base URL
#   LUMEN_CONFIG         lumen config.yaml (default $XDG_CONFIG_HOME/lumen/config.yaml)
#   LUMEN_DUP_THRESHOLD  identical-group size that means corruption (default 10)
#   LUMEN_NORM_MIN/MAX   accepted L2 norm band (default 0.99 / 1.01)
#   LUMEN_PROBE_TIMEOUT  seconds for backend probes (default 5)
#
# THE VECTOR WIDTH IS NEVER A LITERAL. It is taken from the vec0 virtual-table
# declaration (`embedding float[768]`), cross-checked against the block bytes on
# disk and against project_meta.vec_dimensions. A wrong width silently misreads
# EVERY vector, so when the sources disagree and no override is given the doctor
# reports "could not inspect" rather than guessing.
#
# THE BACKEND IS OPTIONAL BY DEFAULT. Inspecting a database does not require a
# running ollama, so an unreachable backend degrades the model-mismatch NOTE and
# leaves the corruption verdict untouched. Pass --require-live-backend (or set
# LUMEN_DOCTOR_REQUIRE_BACKEND=1) to make an unreachable backend "could not
# inspect" (exit 2) instead.
# ------------------------------------------------------------------------------
set -uo pipefail

# Print the header block above, so --help can never drift out of sync with it
# the way a hardcoded `sed -n '2,30p'` line range does the moment anyone edits.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

PROJ=""
REQUIRE_BACKEND="${LUMEN_DOCTOR_REQUIRE_BACKEND:-0}"
for a in "$@"; do
    case "$a" in
        --require-live-backend) REQUIRE_BACKEND=1 ;;
        --help|-h)              usage; exit 0 ;;
        -*)                     echo "lumen-index-doctor: unknown option '$a'" >&2
                                echo "usage: $0 [project-path] [--require-live-backend]" >&2
                                exit 2 ;;
        *)                      [[ -z "$PROJ" ]] && PROJ="$a" ;;
    esac
done
PROJ="${PROJ:-$(pwd)}"

# XDG first, $HOME second - matching lumen's config.XDGDataDir() exactly.
STORE="${LUMEN_STORE:-${XDG_DATA_HOME:-$HOME/.local/share}/lumen}"
CONFIG="${LUMEN_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/lumen/config.yaml}"

PROJ="$PROJ" STORE="$STORE" CONFIG="$CONFIG" REQUIRE_BACKEND="$REQUIRE_BACKEND" python3 - <<'PY'
import os, sqlite3, glob, collections, sys, re, json, hashlib

proj   = os.path.realpath(os.environ["PROJ"])
store  = os.environ["STORE"]
config = os.environ["CONFIG"]
require_backend = os.environ.get("REQUIRE_BACKEND", "0") not in ("", "0", "no", "false")

def env(name, default=None):
    v = os.environ.get(name, "")
    return v if v else default

def envint(name, default):
    v = os.environ.get(name, "")
    try:
        return int(v) if v else default
    except ValueError:
        return default

def envfloat(name, default):
    v = os.environ.get(name, "")
    try:
        return float(v) if v else default
    except ValueError:
        return default

# ── exit codes are PRIVATE (see the bash mapping at the bottom) ───────────────
E_HEALTHY, E_NOINDEX, E_CORRUPT, E_UNKNOWNGEOM = 20, 21, 22, 23

notes = []

# ── 1. what model would lumen use RIGHT NOW? ─────────────────────────────────
# Precedence copied from lumen's internal/config/service.go applyEnvOverrides:
# env override wins, then config.yaml servers[0], then the built-in default.
DEFAULT_MODEL = {"lmstudio": "nomic-ai/nomic-embed-code-GGUF"}.get(
    (env("LUMEN_BACKEND") or "ollama").lower(), "ordis/jina-embeddings-v2-base-code")

def read_config_servers(path):
    """servers[0] from lumen's config.yaml, without a yaml dependency.

    Only the handful of scalar keys we care about are read; anything unparsable
    yields {} so a malformed config degrades to the defaults instead of a crash.
    """
    out = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except Exception:
        return out
    block = re.split(r'^\s*servers\s*:', text, maxsplit=1, flags=re.M)
    if len(block) < 2:
        return out
    # first "- key: value" entry only
    first = re.split(r'^\s*-\s', block[1], flags=re.M)
    if len(first) < 2:
        return out
    for line in first[1].splitlines():
        if re.match(r'^\s*-\s', line):
            break
        m = re.match(r'^\s*(backend|host|model|dims|ctx_length)\s*:\s*(.+?)\s*$', line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out

cfg = read_config_servers(config)
backend = (env("LUMEN_BACKEND") or cfg.get("backend") or "ollama").lower()

def normalise_url(u, default_port):
    """OLLAMA_HOST is conventionally written bare (127.0.0.1:11434, or even
    :11434). lumen passes it through as a URL, so normalise before curling it."""
    if not u:
        return u
    u = u.strip()
    if not re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*://', u):
        if u.startswith(":"):
            u = "localhost" + u
        u = "http://" + u
    if not re.search(r':\d+(/|$)', u):
        u = u.rstrip("/") + ":" + str(default_port)
    return u.rstrip("/")

if backend == "lmstudio":
    host = normalise_url(env("LM_STUDIO_HOST") or cfg.get("host") or "http://localhost:1234", 1234)
else:
    host = normalise_url(env("OLLAMA_HOST") or cfg.get("host") or "http://localhost:11434", 11434)

configured_model = env("LUMEN_EMBED_MODEL") or cfg.get("model") or DEFAULT_MODEL

# ── 2. what is the backend actually serving? (best effort, never fatal) ──────
def http_json(url, timeout):
    import urllib.request
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None

probe_timeout = envint("LUMEN_PROBE_TIMEOUT", 5)
live_running, live_available, backend_reachable = [], [], False
if backend == "lmstudio":
    d = http_json(host + "/v1/models", probe_timeout)
    if d is not None:
        backend_reachable = True
        live_available = [m.get("id", "") for m in (d.get("data") or [])]
else:
    d = http_json(host + "/api/ps", probe_timeout)
    if d is not None:
        backend_reachable = True
        live_running = [m.get("model") or m.get("name", "") for m in (d.get("models") or [])]
    d = http_json(host + "/api/tags", probe_timeout)
    if d is not None:
        backend_reachable = True
        live_available = [m.get("model") or m.get("name", "") for m in (d.get("models") or [])]

def same_model(a, b):
    """ollama reports `name:latest`; lumen stores the bare name it was given."""
    if not a or not b:
        return False
    return a.split(":")[0] == b.split(":")[0] if (a.endswith(":latest") or b.endswith(":latest")) else a == b

if not backend_reachable:
    if require_backend:
        print("❌ %s backend unreachable at %s and --require-live-backend was given" % (backend, host))
        print("   Refusing to report either 'healthy' or 'corrupt' from an unverified backend.")
        sys.exit(E_UNKNOWNGEOM)
    notes.append("%s backend unreachable at %s - live-model comparison skipped "
                 "(the index inspection below does not need it)" % (backend, host))

# ── 3. locate every index belonging to this project ──────────────────────────
# lumen keys the store dir on sha256(path \0 model \0 IndexVersion)[:16], so a
# model change silently starts a SECOND index. Scanning finds them all; the
# hash is then SOLVED (below) rather than assumed.
pinned = env("LUMEN_INDEX_DB")
candidates = []
if pinned:
    candidates = [pinned]
else:
    candidates = sorted(glob.glob(os.path.join(store, "*", "index.db"))) + \
                 sorted(glob.glob(os.path.join(store, "index.db")))

matches = []
for d in candidates:
    try:
        c = sqlite3.connect("file:%s?mode=ro" % d, uri=True)
        rows = dict(c.execute("SELECT key, value FROM project_meta").fetchall())
        c.close()
    except Exception:
        continue
    p = rows.get("project_path")
    if pinned or (p and os.path.realpath(p) == proj):
        matches.append((d, rows.get("embedding_model", "?"), rows))

if not matches:
    print("❌ no Lumen index found for %s under %s" % (proj, store))
    if not backend_reachable:
        print("   (the backend was also unreachable at %s, so the store path could" % host)
        print("    not be cross-checked - this is 'could not inspect', not 'healthy')")
    sys.exit(E_NOINDEX)

# Solve for lumen's IndexVersion from a known (path, model, dir) triple instead
# of pasting the constant. Gives a VERIFIED value, or nothing at all.
index_version = None
for db, model, _ in matches:
    want = os.path.basename(os.path.dirname(db))
    if len(want) != 16:
        continue
    for iv in [str(i) for i in range(0, 64)]:
        h = hashlib.sha256(("%s\x00%s\x00%s" % (proj, model, iv)).encode()).hexdigest()[:16]
        if h == want:
            index_version = iv
            break
    if index_version:
        break

# Inspect the index for the model lumen would use now; else the newest one.
db, index_model, meta = matches[0]
for m in matches:
    if same_model(m[1], configured_model):
        db, index_model, meta = m
        break

print("index: %s" % db)
print("model: %s" % index_model)
print("backend: %s at %s (reachable: %s)" % (backend, host, "yes" if backend_reachable else "NO"))

# ── 4. the model-mismatch condition, reported because it costs a whole index ──
if not same_model(index_model, configured_model):
    print("⚠️  MODEL MISMATCH: this index was built with '%s' but lumen would now"
          % index_model)
    print("   use '%s'. lumen hashes the model into the store path, so the next"
          % configured_model)
    print("   index run will build a SECOND index from zero rather than update this one.")
    if index_version:
        nh = hashlib.sha256(("%s\x00%s\x00%s" % (proj, configured_model, index_version)).encode()).hexdigest()[:16]
        print("   That second index would land at: %s"
              % os.path.join(store, nh, "index.db"))
if len(matches) > 1:
    print("⚠️  %d indexes already exist for this project (one per model):" % len(matches))
    for m in matches:
        print("     %s  model=%s" % (m[0], m[1]))
if live_running and not any(same_model(x, index_model) for x in live_running):
    print("⚠️  the backend is currently running %s, not this index's %s"
          % (", ".join(live_running), index_model))
elif backend_reachable and live_available and not any(same_model(x, index_model) for x in live_available):
    print("⚠️  %s does not serve '%s' at all (has: %s)"
          % (backend, index_model, ", ".join(live_available) or "nothing"))

try:
    c = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
except Exception as e:
    print("❌ cannot open %s read-only: %s" % (db, e))
    sys.exit(E_NOINDEX)

try:
    print("integrity_check: %s" % c.execute("PRAGMA integrity_check").fetchone()[0])
except Exception as e:
    print("❌ integrity_check could not run: %s" % e)
    sys.exit(E_UNKNOWNGEOM)

def scalar(sql, default=0):
    try:
        return c.execute(sql).fetchone()[0]
    except Exception:
        return default

files_total = scalar("SELECT COUNT(*) FROM files")
files_done  = scalar("SELECT COUNT(*) FROM files WHERE hash<>''")
chunks      = scalar("SELECT COUNT(*) FROM chunks")
print("files: %d fully indexed, %d queued placeholders | chunks: %d"
      % (files_done, files_total - files_done, chunks))

# ── 5. discover the sqlite-vec shadow tables instead of naming them ──────────
# sqlite-vec derives them from the vec0 table name: <vec>_vector_chunks<NN>
# holds the packed vectors and <vec>_chunks holds the per-block validity bitmap.
tables = {}
try:
    for name, sql in c.execute("SELECT name, sql FROM sqlite_master WHERE type='table'"):
        tables[name] = sql or ""
except Exception as e:
    print("❌ cannot read the schema: %s" % e)
    sys.exit(E_UNKNOWNGEOM)

vec_table = env("LUMEN_VEC_TABLE")
if vec_table and vec_table not in tables:
    print("❌ LUMEN_VEC_TABLE='%s' is not a table in this index" % vec_table)
    sys.exit(E_UNKNOWNGEOM)
if not vec_table:
    cands = sorted(n for n in tables if re.search(r'_vector_chunks\d+$', n))
    if not cands:
        print("❌ this database has no sqlite-vec vector table "
              "(looked for *_vector_chunks<NN>)")
        print("   Nothing can be decoded, so no verdict is possible.")
        sys.exit(E_UNKNOWNGEOM)
    vec_table = cands[0]
prefix = re.sub(r'_vector_chunks\d+$', '', vec_table)
validity_table = prefix + "_chunks"

# ── 6. the vector geometry, from THREE independent sources ──────────────────
ELEM = {"float": ("f", 4), "float32": ("f", 4), "f32": ("f", 4),
        "int8": ("b", 1), "i8": ("b", 1)}
sources = {}          # label -> dims
elem_name = None

# (a) the vec0 virtual-table declaration - authoritative for DECODING
decl = tables.get(prefix, "")
m = re.search(r'\b(\w+)\s*\[\s*(\d+)\s*\]', decl)
if m:
    t = m.group(1).lower()
    if t == "bit":
        print("❌ this index stores bit vectors; this doctor decodes float32/int8 only")
        sys.exit(E_UNKNOWNGEOM)
    if t in ELEM:
        elem_name = t
        sources["vec0 declaration"] = int(m.group(2))

# (b) the bytes on disk - derived from data, assumes nothing
try:
    row = c.execute("SELECT k.size, length(v.vectors) FROM %s k JOIN %s v ON v.rowid=k.%s "
                    "WHERE k.size>0 LIMIT 1"
                    % (validity_table, vec_table,
                       "chunk_id" if "chunk_id" in tables.get(validity_table, "") else "rowid")).fetchone()
    if row and row[0]:
        per = row[1] // row[0]
        w = ELEM.get(elem_name or "float", ("f", 4))[1]
        if per % w == 0:
            sources["block bytes on disk"] = per // w
except Exception:
    pass          # older schema has no `size` column - the other sources cover it

# (c) what lumen recorded
v = meta.get("vec_dimensions")
if v and str(v).isdigit():
    sources["project_meta.vec_dimensions"] = int(v)

override = envint("LUMEN_VEC_DIMS", 0)
elem_name = (env("LUMEN_VEC_ELEM") or elem_name or "float32").lower()
if elem_name not in ELEM:
    print("❌ LUMEN_VEC_ELEM='%s' is not one of: %s" % (elem_name, ", ".join(sorted(ELEM))))
    sys.exit(E_UNKNOWNGEOM)
packfmt, elemsize = ELEM[elem_name]

if override:
    DIM = override
    print("vector width: %d %s (pinned by LUMEN_VEC_DIMS)" % (DIM, elem_name))
elif not sources:
    print("❌ the vector width could not be derived from the vec0 declaration, "
          "from the stored blocks, or from project_meta.vec_dimensions.")
    print("   Decoding with a guessed width misreads every vector, so no verdict "
          "is possible. Pin it with LUMEN_VEC_DIMS=<n> if you know it.")
    sys.exit(E_UNKNOWNGEOM)
else:
    agreed = set(sources.values())
    if len(agreed) > 1:
        print("❌ the index disagrees with itself about the vector width:")
        for k in sorted(sources):
            print("     %-28s %d" % (k, sources[k]))
        print("   Refusing to pick one - a wrong width misreads every vector. "
              "Pin it with LUMEN_VEC_DIMS=<n>.")
        sys.exit(E_UNKNOWNGEOM)
    DIM = agreed.pop()
    print("vector width: %d %s (derived from: %s)"
          % (DIM, elem_name, "; ".join("%s=%d" % (k, sources[k]) for k in sorted(sources))))
if DIM <= 0:
    print("❌ nonsensical vector width %d" % DIM)
    sys.exit(E_UNKNOWNGEOM)
VB = DIM * elemsize

# CRITICAL: sqlite-vec ALLOCATES 1024-vector blocks and marks live slots in a
# per-block `validity` bitmap. Freed and never-written slots still hold bytes -
# usually all-zero, or a stale vector from a previous occupant. Decoding every
# allocated slot therefore counts garbage as data.
#
# This is exactly how an earlier revision of this script over-reported: it saw
# 43 duplicate groups / 2.05% when the true live figure was 1 group / 0.32%,
# because ~34,500 freed slots were being counted. It is the mirror image of the
# original forensic audit's error - that one sampled too NARROW a slice and
# declared the index clean; this one read too WIDE and cried corruption.
#
# Mask by validity: only slots whose bit is set are real.
validity = {}
try:
    validity = {r[0]: r[1] for r in c.execute("SELECT rowid, validity FROM %s" % validity_table)}
except Exception:
    pass   # older schema without the shadow table: fall back to counting all

counts = collections.Counter(); total = 0; ragged = 0; freed = 0
try:
    rows = c.execute("SELECT rowid, vectors FROM %s" % vec_table)
except Exception as e:
    print("❌ cannot read %s: %s" % (vec_table, e))
    sys.exit(E_UNKNOWNGEOM)
for brow, blob in rows:
    if not blob: continue
    if len(blob) % VB:
        ragged += 1          # block is not a whole number of vectors
    vbits = validity.get(brow)
    for i in range(len(blob) // VB):
        if vbits is not None and not ((vbits[i // 8] >> (i % 8)) & 1):
            freed += 1        # allocated but not live - not data
            continue
        counts[blob[i*VB:(i+1)*VB]] += 1; total += 1
print("slots: %d live, %d freed/unwritten (excluded from every check below)"
      % (total, freed))

if total == 0:
    print("⚠️  no vectors stored yet - nothing to check")
    for n in notes: print("NOTE: %s" % n)
    c.close(); sys.exit(E_HEALTHY)

groups = sorted([n for n in counts.values() if n > 1], reverse=True)
dup_vectors = sum(groups)
print("vectors: %d total, %d distinct" % (total, len(counts)))

threshold = envint("LUMEN_DUP_THRESHOLD", 10)
bad = False
# THE test the conventional audit lacked.
if groups:
    print("❌ %d duplicate-vector group(s); %d vectors (%.2f%%) are not unique"
          % (len(groups), dup_vectors, 100.0*dup_vectors/total))
    print("   largest identical group: %d copies of ONE vector" % groups[0])
    print("   A GPU/backend fault returns a stale buffer under HTTP 200. These")
    print("   vectors are well-formed and pass every per-vector test.")
    # Any duplicate group is REPORTED. Only a large one is treated as
    # corruption, since identical boilerplate legitimately embeds identically.
    # Previously a small group printed ❌ and still exited 0 - output and exit
    # code disagreed, which is worse than either verdict alone.
    if groups[0] >= threshold:
        bad = True
    else:
        print("   (largest group is %d, under the corruption threshold of %d:"
              " reported, not failed)" % (groups[0], threshold))
else:
    print("✅ every stored vector is distinct")

# Conventional checks, retained because they catch the louder failure modes.
import struct, math
nmin = envfloat("LUMEN_NORM_MIN", 0.99)
nmax = envfloat("LUMEN_NORM_MAX", 1.01)
nan = zero = badnorm = 0
for v in counts:
    f = struct.unpack("<%d%s" % (DIM, packfmt), v)
    if any(math.isnan(x) or math.isinf(x) for x in f): nan += 1; continue
    n = math.sqrt(sum(x*x for x in f))
    if n == 0.0: zero += 1
    elif not (nmin <= n <= nmax): badnorm += 1
print("per-vector: %d NaN/Inf, %d all-zero, %d off-norm (band %.3f-%.3f), %d ragged block(s)"
      % (nan, zero, badnorm, nmin, nmax, ragged))
if nan or zero or badnorm or ragged: bad = True

c.close()
for n in notes: print("NOTE: %s" % n)
if bad:
    print("\n❌ CORRUPTION DETECTED")
    print("   Fix the backend first:  ./scripts/ollama-vulkan-remediation.sh --check")
    print("   Then REBUILD (not incremental - affected files have a hash and are skipped):")
    print("     ./scripts/lumen-reindex.sh %s --force" % proj)
    sys.exit(E_CORRUPT)
print("\n✅ index healthy")
sys.exit(E_HEALTHY)
PY
rc=$?
# The python block uses PRIVATE exit codes (20 healthy / 21 no index /
# 22 corruption / 23 geometry or backend undeterminable) precisely so that an
# uncaught exception - which python reports as 1 - can never be mistaken for our
# own "corruption found" verdict.
# An earlier version listed 1 in the pass-through arm, so a crash WAS reported
# as corruption. Anything unrecognised now maps to 2 (could not inspect).
case $rc in
    20) exit 0 ;;
    21) exit 2 ;;
    22) exit 1 ;;
    23) exit 2 ;;
    *)  echo "❌ doctor could not complete (internal error, rc=$rc)" >&2; exit 2 ;;
esac
