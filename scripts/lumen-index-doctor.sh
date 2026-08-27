#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Lumen index doctor — detect SILENTLY corrupt embeddings.
#
# WHY THIS EXISTS
# ---------------
# A GPU fault wrote 758 identical vectors covering 695 distinct texts across 55
# files into this project's index. Every conventional check passed: no NaN, no
# Inf, no all-zero, L2 norm 1.000000083, correct 768 dimensions. A full forensic
# audit declared the index "TRUSTWORTHY" on exactly those measurements — and was
# wrong, because a stale-but-well-formed vector is invisible per-vector.
#
# The only thing that exposes it is AGGREGATE distinctness: N distinct texts
# must produce N distinct vectors. This script checks that, alongside the
# conventional per-vector tests, and never opens the DB for writing.
#
#   ./scripts/lumen-index-doctor.sh [project-path]
#
# Exit 0 = healthy · 1 = corruption found · 2 = could not inspect
# ------------------------------------------------------------------------------
set -uo pipefail
PROJ="${1:-$(pwd)}"
STORE="${LUMEN_STORE:-$HOME/.local/share/lumen}"

PROJ="$PROJ" STORE="$STORE" python3 - <<'PY'
import os, sqlite3, glob, collections, sys

proj  = os.path.realpath(os.environ["PROJ"])
store = os.environ["STORE"]

db = None
for d in glob.glob(os.path.join(store, "*", "index.db")):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % d, uri=True)
        r = c.execute("SELECT value FROM project_meta WHERE key='project_path'").fetchone()
        c.close()
        if r and os.path.realpath(r[0]) == proj:
            db = d; break
    except Exception:
        continue

if not db:
    print("❌ no Lumen index found for %s under %s" % (proj, store)); sys.exit(2)
print("index: %s" % db)

c = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
try:
    model = c.execute("SELECT value FROM project_meta WHERE key='embedding_model'").fetchone()
    print("model: %s" % (model[0] if model else "?"))
except Exception:
    pass

print("integrity_check: %s" % c.execute("PRAGMA integrity_check").fetchone()[0])

files_total = c.execute("SELECT COUNT(*) FROM files").fetchone()[0]
files_done  = c.execute("SELECT COUNT(*) FROM files WHERE hash<>''").fetchone()[0]
chunks      = c.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
print("files: %d fully indexed, %d queued placeholders | chunks: %d"
      % (files_done, files_total - files_done, chunks))

# Decode the sqlite-vec shadow table: contiguous little-endian float32,
# 768 dims per vector, 1024 vectors per block.
DIM = 768; VB = DIM * 4
counts = collections.Counter(); total = 0
for (blob,) in c.execute("SELECT vectors FROM vec_chunks_vector_chunks00"):
    if not blob: continue
    for i in range(len(blob) // VB):
        counts[blob[i*VB:(i+1)*VB]] += 1; total += 1

if total == 0:
    print("⚠️  no vectors stored yet - nothing to check"); c.close(); sys.exit(0)

groups = sorted([n for n in counts.values() if n > 1], reverse=True)
dup_vectors = sum(groups)
print("vectors: %d total, %d distinct" % (total, len(counts)))

bad = False
# THE test the conventional audit lacked.
if groups:
    print("❌ %d duplicate-vector group(s); %d vectors (%.2f%%) are not unique"
          % (len(groups), dup_vectors, 100.0*dup_vectors/total))
    print("   largest identical group: %d copies of ONE vector" % groups[0])
    print("   A GPU/backend fault returns a stale buffer under HTTP 200. These")
    print("   vectors are well-formed and pass every per-vector test.")
    # A handful of genuine duplicates (identical boilerplate) is plausible;
    # a group in the hundreds is not.
    if groups[0] >= 10:
        bad = True
else:
    print("✅ every stored vector is distinct")

# Conventional checks, retained because they catch the louder failure modes.
import struct, math
nan = zero = wrongdim = badnorm = 0
for v in counts:
    f = struct.unpack("<%df" % DIM, v)
    if any(math.isnan(x) or math.isinf(x) for x in f): nan += 1; continue
    n = math.sqrt(sum(x*x for x in f))
    if n == 0.0: zero += 1
    elif not (0.99 <= n <= 1.01): badnorm += 1
print("per-vector: %d NaN/Inf, %d all-zero, %d off-norm" % (nan, zero, badnorm))
if nan or zero or badnorm: bad = True

c.close()
if bad:
    print("\n❌ CORRUPTION DETECTED")
    print("   Fix the backend first:  ./scripts/ollama-vulkan-remediation.sh --check")
    print("   Then REBUILD (not incremental - affected files have a hash and are skipped):")
    print("     ./scripts/lumen-reindex.sh %s --force" % proj)
    sys.exit(1)
print("\n✅ index healthy")
PY
