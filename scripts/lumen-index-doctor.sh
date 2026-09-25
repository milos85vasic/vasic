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
#   LUMEN_NORM_MIN/MAX   accepted L2 norm band (default 0.99 / 1.01). float32
#                        indexes ONLY: int8 vectors are stored scaled to their own
#                        maximum, so their raw L2 norm is 428..1312 on the real
#                        store and no unit-norm band can apply (see INT8 below).
#   LUMEN_INT8_SCALE_DOMINANCE  share of distinct live vectors that must sit on
#                        ONE max|component| for the int8 scale check to apply
#                        (default 0.90)
#   LUMEN_INT8_SCALE_TOP the int8 saturation value that scale must equal
#                        (default 127; max-abs quantisation puts the largest
#                        component AT it). A legitimate int8 store that is NOT
#                        quantised max-abs (different scheme or scale) will read
#                        rc 2 "scale invariant not established" until this is
#                        set to that store's own top; the doctor cannot guess it.
#   A set-but-non-numeric value of ANY numeric LUMEN_* tuning variable is rc 2
#   naming the variable; it is never silently replaced by the default.
#   LUMEN_INT8_MIN_VECTORS  fewest distinct live vectors that can state a scale
#                        (default 10)
#   LUMEN_DOCTOR_PREFLIGHT_TIMEOUT  seconds --prove-failure allows its live
#                        pre-flight run against the real store (default 900; the
#                        real run took 157 s on a 1.25M-vector store). 0 DISABLES
#                        the timeout, i.e. the run is UNBOUNDED. Applies to
#                        --prove-failure only.
#   LUMEN_PROBE_TIMEOUT  seconds for backend probes (default 5)
#
# INT8 STORAGE — WHAT IS CHECKED, AND THE RECALL COST (measured on specimens of
# 1000 vectors, 2026-09-24). The scale invariant is derived from the data and
# then held to a fixed anchor: it is ESTABLISHED only if (1) at least
# LUMEN_INT8_MIN_VECTORS distinct live vectors exist, (2) one max|component|
# covers >= LUMEN_INT8_SCALE_DOMINANCE of them, and (3) that value is
# LUMEN_INT8_SCALE_TOP. Established: vectors on any other scale are "off-scale"
# and are corruption (rc 1). NOT established: rc 2, COULD NOT DETERMINE — the
# same principle as the width / no-vector-table cases, never a clean bill.
#
#     off-scale share of vectors      verdict
#     0.5%                            DETECTED   rc 1
#     exactly 10%                     DETECTED   rc 1
#     11%                             not established   rc 2
#     60%                             not established   rc 2
#     100% (all rescaled together)    not established   rc 2 (mode != top)
#     N < 10 distinct live vectors    not established   rc 2
#
# So above 10% the doctor cannot say WHICH side is right and says so, rather than
# reading a broken index as healthy. Duplicate, all-zero and ragged-block checks
# run regardless. Corruption (1) outranks could-not-determine (2).
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
PROVE=0
for a in "$@"; do
    case "$a" in
        --require-live-backend) REQUIRE_BACKEND=1 ;;
        --prove-failure)        PROVE=1 ;;
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

# ══════════════════════════════════════════════════════════════════════════════
# §1.1 PAIRED MUTATION PROOF  —  --prove-failure
#
# WHY THIS SHAPE
# --------------
# The defect this doctor exists for is a vector that is well-formed and WRONG.
# A proof of it must therefore build an index that is well-formed and wrong, and
# show the doctor going red on it — asserting the prose would be exactly the
# bluff the doctor was written to end.
#
# The control is SYNTHETIC and healthy BY CONSTRUCTION: a throwaway sqlite index
# generated from the same constants the mutations perturb, so no state of this
# host's real Lumen store — corrupt, missing, half-built — can redden it and
# switch the battery off. That failure mode is not hypothetical; it is recorded
# in docs/check-registry.md as "the inoperative-proof defect", found in two of
# this repository's gates on 2026-09-01.
#
# The LIVE run still happens first, with the REAL entry point against the REAL
# store, and is REPORTED, never gating: a proof that only ever touches a sandbox
# while the real instrument cannot start is the other half of the same defect.
#
# HERMETIC BY CONSTRUCTION. Every mutation writes only inside a `mktemp -d`.
# The backend is pointed at a closed port so no network request can succeed and
# no answer from this host's real ollama can change a verdict. Nothing under the
# real LUMEN_STORE is opened, for reading or for writing.
#
# NOTE ON sqlite-vec: the doctor decodes the shadow tables with plain SQL and
# never loads the extension, so the specimen is plain sqlite3 — which is the
# point: if building the specimen needed sqlite-vec, the proof would be testing
# sqlite-vec rather than the doctor.
# ══════════════════════════════════════════════════════════════════════════════
if [[ $PROVE -eq 1 ]]; then
    echo "LUMEN-INDEX-DOCTOR §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"
    command -v python3 >/dev/null 2>&1 || {
        echo "UNDETERMINED: python3 is not on PATH, so no specimen can be built and" >&2
        echo "  nothing was proved. This is neither a pass nor a fail." >&2
        exit 2; }

    SELF="${BASH_SOURCE[0]}"
    P_PASS=0; P_FAIL=0

    # ---- PRE-FLIGHT: the REAL entry point against the REAL store -------------
    # The real run's cost grows with the index (measured 157 s on a 1.25M-vector
    # store, 2026-09-24), so a fixed 120 s cap turned "the index grew" into
    # "the real instrument cannot start" and aborted the whole proof. Tunable;
    # a real hang still fails, just later.
    pf_out="$(timeout "${LUMEN_DOCTOR_PREFLIGHT_TIMEOUT:-900}" bash "$SELF" "$PROJ" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0) printf 'ℹ %-30s the real instrument ran against the real store and returned rc=0 (healthy)\n' "PRE-FLIGHT live-run" ;;
        1) printf 'ℹ %-30s the real instrument RAN and returned rc=1 (real corruption). REPORTED,\n' "PRE-FLIGHT live-run"
           printf '%-32s NOT GATING — the battery below uses a synthetic control.\n' "" ;;
        2) printf 'ℹ %-30s the real instrument RAN and returned rc=2 (could not inspect). REPORTED,\n' "PRE-FLIGHT live-run"
           printf '%-32s NOT GATING — the battery below uses a synthetic control.\n' "" ;;
        124) printf '❌ %-30s the real instrument TIMED OUT; it cannot start, so it cannot guard anything\n' "PRE-FLIGHT live-run"
           P_FAIL=$((P_FAIL+1)) ;;
        *) printf '❌ %-30s the real instrument exited rc=%s, outside its own 0/1/2 contract\n' "PRE-FLIGHT live-run" "$pf_rc"
           printf '%s\n' "$pf_out" | tail -3 | sed 's/^/        /'
           P_FAIL=$((P_FAIL+1)) ;;
    esac

    SB="$(mktemp -d "${TMPDIR:-/tmp}/lumen-doctor-proof.XXXXXX")" || {
        echo "UNDETERMINED: cannot create a sandbox; the proof could not run" >&2; exit 2; }
    trap 'rm -rf "$SB"' EXIT INT TERM      # cleanup: restore by removal, nothing outside $SB is touched
    echo "  sandbox: $SB"

    SB_PROJ="$SB/project"; mkdir -p "$SB_PROJ" || { echo "UNDETERMINED: cannot populate the sandbox" >&2; exit 2; }

    # build_specimen <store-dir> <mode>
    # Modes are the states the doctor claims to tell apart. Every one of them is
    # WELL-FORMED sqlite: nothing here is caught by a parse error.
    build_specimen() {
        STORE_DIR="$1" MODE="$2" SPEC_PROJ="$SB_PROJ" python3 - <<'MKPY'
import os, sqlite3, struct, math, shutil

store = os.environ["STORE_DIR"]; mode = os.environ["MODE"]
proj  = os.path.realpath(os.environ["SPEC_PROJ"])
# Population-size specimens (int8): the scale invariant is a PERCENTAGE claim,
# so its cases need a population. Everything else keeps the small 16-vector one.
BIGN = {"int8off05": 1000, "int8off10": 1000, "int8off11": 1000,
        "int8off60": 1000, "int8uniform": 1000, "int8tiny": 6}
DIM, N = 8, BIGN.get(mode, 16)
shutil.rmtree(store, ignore_errors=True)
d = os.path.join(store, "aaaaaaaaaaaaaaaa")
os.makedirs(d)
db = os.path.join(d, "index.db")

def unit(seed):
    v = [math.sin(seed * 7.0 + j * 3.0) + 0.5 for j in range(DIM)]
    n = math.sqrt(sum(x * x for x in v))
    return [x / n for x in v]

vecs = [unit(i) for i in range(N)]
INT8 = mode.startswith("int8")
def q8(v, top=127):
    # lumen-style per-vector max-abs quantisation: the largest |component| is
    # scaled to `top`, so the L2 norm of the STORED bytes is NOT 1 (measured on
    # the real index 2026-09-24: 428..1312, and max|component| == 127 for
    # every vector). A unit-norm band cannot hold for int8.
    m = max(abs(x) for x in v) or 1.0
    return [int(round(x / m * top)) for x in v]
if INT8 and mode in BIGN:
    import random
    rng = random.Random(4242)
    raw = [[rng.gauss(0, 1) for _ in range(DIM)] for _ in range(N)]
    vecs = [q8(v) for v in raw]
    off = {"int8off05": 5, "int8off10": 100, "int8off11": 110, "int8off60": 600}.get(mode, 0)
    for i in range(off):
        vecs[i] = q8(raw[i], top=40)              # a different max scale
    if mode == "int8uniform":
        vecs = [q8(v, top=60) for v in raw]       # EVERY vector on one wrong scale
elif INT8:
    vecs = [q8(v) for v in vecs]
    if   mode == "int8dup":      vecs = [q8(unit(0))] * 12 + [q8(unit(i)) for i in range(1, N - 11)]
    elif mode == "int8zero":     vecs[5] = [0] * DIM
    elif mode == "int8offscale": vecs[7] = q8(unit(7), top=40)      # one vector on the wrong scale
    elif mode == "int8noscale":  vecs = [q8(unit(i), top=20 + (i * 37) % 108) for i in range(N)]   # no dominant scale
if   mode == "dup":     vecs = [unit(0)] * 12 + [unit(i) for i in range(1, N - 11)]
elif mode == "nan":     vecs[3] = [float("nan")] * DIM
elif mode == "zero":    vecs[5] = [0.0] * DIM
elif mode == "offnorm": vecs[7] = [x * 2.0 for x in vecs[7]]

if INT8:
    blob = b"".join(struct.pack("<%db" % DIM, *v) for v in vecs)
else:
    blob = b"".join(struct.pack("<%df" % DIM, *v) for v in vecs)
if mode == "ragged":
    blob += b"\x01\x02\x03"          # not a whole number of vectors

dims_meta = 9 if mode == "geomclash" else DIM
vec_name  = "items_notavectortable" if mode == "novec" else "items_vector_chunks00"

c = sqlite3.connect(db)
c.execute("CREATE TABLE project_meta(key TEXT PRIMARY KEY, value TEXT)")
c.executemany("INSERT INTO project_meta VALUES (?,?)", [
    ("project_path", proj), ("embedding_model", "synthetic-embed-v1"),
    ("vec_dimensions", str(dims_meta))])
c.execute("CREATE TABLE files(path TEXT, hash TEXT)")
c.executemany("INSERT INTO files VALUES (?,?)", [("f%d" % i, "h%d" % i) for i in range(4)])
c.execute("CREATE TABLE chunks(id INTEGER PRIMARY KEY)")
c.executemany("INSERT INTO chunks VALUES (?)", [(i,) for i in range(N)])
c.execute("CREATE TABLE %s(vectors BLOB)" % vec_name)
c.execute("INSERT INTO %s(rowid, vectors) VALUES (1, ?)" % vec_name, (blob,))
# sqlite-vec's per-block validity bitmap: every one of the N slots is live.
if INT8:
    # The doctor derives the element type from the vec0 declaration
    # (`name type[N]`); plain sqlite accepts any type name, so this is enough.
    c.execute("CREATE TABLE items(embedding int8[%d])" % DIM)
c.execute("CREATE TABLE items_chunks(validity BLOB, size INTEGER)")
c.execute("INSERT INTO items_chunks(rowid, validity, size) VALUES (1, ?, ?)",
          (bytes([0xFF] * ((N + 7) // 8)), N))
c.commit(); c.close()
MKPY
    }

    # run_doctor <store-dir> [extra argv...] -> prints output, returns the rc
    # The backend is pinned at a closed port and the config at a path that does
    # not exist, so this host's real ollama and real lumen config cannot reach
    # any verdict below.
    run_doctor() {
        local store="$1"; shift
        env HOME="$SB" \
            LUMEN_STORE="$store" \
            LUMEN_CONFIG="$SB/no-such-config.yaml" \
            OLLAMA_HOST="127.0.0.1:1" \
            LUMEN_PROBE_TIMEOUT=1 \
            timeout 120 bash "$SELF" "$SB_PROJ" "$@" 2>&1
    }

    p_ok()  { P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

    # assert_absent <label> <needle>: the LAST assert_case output must NOT contain
    # <needle> (used to prove a could-not-determine run never printed a clean bill).
    assert_absent() {
        if grep -qF -- "$2" <<<"${LAST_OUT:-}"; then
            p_bad "$1" "the output contained '$2' — a could-not-determine run read as healthy"
        else
            p_ok "$1" "and it never printed '$2'"
        fi
    }

    # assert_case <label> <mode> <want-rc> <needle> [extra argv...]
    assert_case() {
        local label="$1" mode="$2" want="$3" needle="$4"; shift 4
        local store="$SB/store" out rc
        if ! build_specimen "$store" "$mode"; then
            p_bad "$label" "the specimen could not be built (mode=$mode) — nothing was proved by this case"
            return
        fi
        out="$(run_doctor "$store" "$@")"; rc=$?
        LAST_OUT="$out"
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=$want, got rc=$rc (mode=$mode)"
            printf '%s\n' "$out" | tail -5 | sed 's/^/        /'
            return
        fi
        if [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            p_bad "$label" "rc=$want as required, but the output never NAMED '$needle' — an unnamed finding is not actionable"
            printf '%s\n' "$out" | tail -5 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=$rc${needle:+, and it named '$needle'}"
    }

    # ---- CONTROL: synthetic, healthy by construction -------------------------
    # Only a failure of THE CONTROL aborts the battery. An earlier pre-flight
    # failure is already reported on its own line and must not be blamed on the
    # control (it was: "the synthetic control did not pass" over a control that
    # had just printed a green line).
    _control_before=$P_FAIL
    assert_case "CONTROL synthetic-healthy" clean 0 "index healthy"
    if [[ $P_FAIL -gt $_control_before ]]; then
        echo "----------------------------------------------------------------------"
        echo "❌ LUMEN-INDEX-DOCTOR §1.1 PROOF: ABORTED — the synthetic control did not pass,"
        echo "   so ZERO mutations ran and nothing below would have been proved."
        exit 1
    fi

    # ---- The mutations -------------------------------------------------------
    # M1 is THE one: 12 byte-identical vectors that pass every per-vector test —
    # no NaN, no Inf, no zero, unit norm, correct width. This is the exact shape
    # of the GPU fault that a full forensic audit once certified "TRUSTWORTHY".
    assert_case "M1 stale-duplicate-vectors " dup      1 "duplicate-vector group"
    assert_case "M2 NaN-vector              " nan      1 "NaN/Inf"
    assert_case "M3 all-zero-vector         " zero     1 "all-zero"
    assert_case "M4 off-norm-vector         " offnorm  1 "off-norm"
    assert_case "M5 ragged-block            " ragged   1 "ragged block"
    # M5b-M5f — int8 storage (what lumen actually writes). The float unit-norm
    # band does not hold for int8, so a HEALTHY int8 index must not read as
    # corrupt (it did: every vector was "off-norm"), and the four real faults
    # must still be caught.
    assert_case "M5b int8-healthy           " int8ok        0 "index healthy"
    assert_case "M5c int8-stale-duplicates  " int8dup       1 "duplicate-vector group"
    assert_case "M5d int8-all-zero-vector   " int8zero      1 "all-zero"
    assert_case "M5e int8-off-scale-vector  " int8offscale  1 "off-scale"
    # M5f-M5k — the scale invariant NOT ESTABLISHED is could-not-determine
    # (rc 2, never a clean bill). Measured recall (specimens above, N=1000):
    # 0.5% and exactly 10% off-scale are DETECTED (rc 1); 11%, 60% off-scale and a
    # uniform rescale of EVERY vector are not established (rc 2), as is a
    # population too small (N<10) to state a scale at all.
    assert_case "M5f int8-no-dominant-scale " int8noscale   2 "not established"
    assert_absent "M5f2 never-healthy        " "index healthy"
    assert_case "M5g int8 0.5% off-scale    " int8off05     1 "off-scale"
    assert_case "M5h int8 10% off-scale     " int8off10     1 "off-scale"
    assert_case "M5i int8 11% off-scale     " int8off11     2 "not established"
    assert_absent "M5i2 never-healthy        " "index healthy"
    assert_case "M5j int8 60% off-scale     " int8off60     2 "not established"
    assert_absent "M5j2 never-healthy        " "index healthy"
    assert_case "M5k int8 uniform rescale   " int8uniform   2 "not established"
    assert_absent "M5k2 never-healthy        " "index healthy"
    assert_case "M5l int8 tiny population   " int8tiny      2 "not established"
    assert_absent "M5l2 never-healthy        " "index healthy"
    # M6/M7 are the SC-013 half: could-not-inspect must never read as healthy.
    assert_case "M6 width-disagreement      " geomclash 2 "disagrees with itself"
    assert_case "M7 no-vector-table         " novec    2 "no sqlite-vec vector table"

    # M11 — a non-numeric tuning value must FAIL LOUDLY (rc 2, naming the
    #       variable), never fall back to the strict default in silence: the run
    #       would then judge the index by a threshold the operator did not choose
    #       and did not know had been ignored.
    env_case() {   # env_case <label> <specimen-mode> <VAR> <bad-value>
        local label="$1" mode="$2" var="$3" val="$4" out rc
        build_specimen "$SB/store" "$mode" >/dev/null 2>&1
        out="$(env HOME="$SB" LUMEN_STORE="$SB/store" LUMEN_CONFIG="$SB/no-such-config.yaml" \
                   OLLAMA_HOST="127.0.0.1:1" LUMEN_PROBE_TIMEOUT=1 "$var=$val" \
                   timeout 120 bash "$SELF" "$SB_PROJ" 2>&1)"; rc=$?
        if [[ $rc -eq 2 ]] && grep -qF -- "$var" <<<"$out" && ! grep -qF "index healthy" <<<"$out"; then
            p_ok "$label" "rc=2, named $var, no clean bill"
        else
            p_bad "$label" "expected rc=2 naming $var and no 'index healthy', got rc=$rc"
            printf '%s\n' "$out" | tail -3 | sed 's/^/        /'
        fi
    }
    env_case "M11a bad-INT8-DOMINANCE     " int8ok LUMEN_INT8_SCALE_DOMINANCE  abc
    env_case "M11b bad-INT8-TOP           " int8ok LUMEN_INT8_SCALE_TOP        12x
    env_case "M11c bad-INT8-MIN-VECTORS   " int8ok LUMEN_INT8_MIN_VECTORS      ten
    env_case "M11d bad-NORM-MIN (float32) " clean  LUMEN_NORM_MIN              abc
    env_case "M11e bad-NORM-MAX (float32) " clean  LUMEN_NORM_MAX              1,01

    # M8 — the element type is pinned to something that cannot be decoded. It
    #      needs an env override rather than a specimen change, so it is driven
    #      explicitly rather than through assert_case.
    build_specimen "$SB/store" clean >/dev/null 2>&1
    _m8_out="$(env HOME="$SB" LUMEN_STORE="$SB/store" LUMEN_CONFIG="$SB/no-such-config.yaml" \
                   OLLAMA_HOST="127.0.0.1:1" LUMEN_PROBE_TIMEOUT=1 LUMEN_VEC_ELEM="not-a-type" \
                   timeout 120 bash "$SELF" "$SB_PROJ" 2>&1)"; _m8_rc=$?
    if [[ $_m8_rc -eq 2 ]] && grep -qF "is not one of" <<<"$_m8_out"; then
        p_ok "M8 bad-element-type (env)  " "rc=2, and it named the rejected element type"
    else
        p_bad "M8 bad-element-type (env)  " "expected rc=2 naming the rejected type, got rc=$_m8_rc"
    fi

    # M9 — the store holds no index for this project at all. "Nothing to look
    #      at" is not "nothing wrong": it must be 2, never 0.
    mkdir -p "$SB/empty-store"
    _m9_out="$(run_doctor "$SB/empty-store")"; _m9_rc=$?
    if [[ $_m9_rc -eq 2 ]] && grep -qF "no Lumen index found" <<<"$_m9_out"; then
        p_ok "M9 no-index-for-project    " "rc=2, and it named the missing index"
    else
        p_bad "M9 no-index-for-project    " "expected rc=2 naming the missing index, got rc=$_m9_rc"
    fi

    # M10 — --require-live-backend with the backend closed. The doctor must
    #       refuse to certify from an unverified backend rather than proceed.
    build_specimen "$SB/store" clean >/dev/null 2>&1
    _m10_out="$(run_doctor "$SB/store" --require-live-backend)"; _m10_rc=$?
    if [[ $_m10_rc -eq 2 ]] && grep -qF "backend unreachable" <<<"$_m10_out"; then
        p_ok "M10 required-backend-down  " "rc=2, and it refused to report healthy or corrupt"
    else
        p_bad "M10 required-backend-down  " "expected rc=2 naming the unreachable backend, got rc=$_m10_rc"
    fi

    # ---- RESTORED CONTROL ----------------------------------------------------
    assert_case "CONTROL restored          " clean 0 "index healthy"

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "❌ LUMEN-INDEX-DOCTOR §1.1 MUTATION PROOF: FAIL — ${P_FAIL} case(s) did not hold."
        exit 1
    fi
    echo "✅ LUMEN-INDEX-DOCTOR §1.1 MUTATION PROOF: PASS — the real entry point ran against"
    echo "   the real store (reported, never gating), a synthetic control that is healthy by"
    echo "   construction passed, and all ${P_PASS} checks above held with the required"
    echo "   three-valued verdict (the count is the live pass counter, not a literal):"
    echo "   real corruptions as rc=1 — including the well-formed duplicate-vector fault"
    echo "   every conventional per-vector test passes, on float32 AND int8 storage —"
    echo "   could-not-inspect states as rc=2 rather than a clean bill of health, and"
    echo "   healthy specimens as rc=0."
    exit 0
fi

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
    # A SET but non-numeric value is an operator error and FAILS LOUDLY (rc 2,
    # naming the variable). It used to fall back to the default in silence, so
    # the index was judged by a threshold the operator had not chosen and did not
    # know had been ignored. Unset or empty still means "use the default".
    v = os.environ.get(name, "")
    try:
        return int(v) if v else default
    except ValueError:
        print("❌ %s='%s' is not a whole number; refusing to guess a threshold "
              "(unset it to use the default %s)" % (name, v, default))
        sys.exit(E_UNKNOWNGEOM)

def envfloat(name, default):
    v = os.environ.get(name, "")
    try:
        return float(v) if v else default
    except ValueError:
        print("❌ %s='%s' is not a number; refusing to guess a threshold "
              "(unset it to use the default %s)" % (name, v, default))
        sys.exit(E_UNKNOWNGEOM)

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
nan = zero = badnorm = offscale = 0
scale_unestablished = None
if packfmt == "b":
    # int8 STORAGE. The float unit-norm band does not hold for it, and applying
    # it made EVERY vector of a healthy index "off-norm" and the verdict
    # CORRUPTION DETECTED (measured 2026-09-24 on the real 1.25M-vector store:
    # raw L2 norm 428..1312, and max|component| == 127 for every vector, i.e.
    # lumen scales each vector to its own maximum). So the invariant is DERIVED
    # FROM THE DATA instead of assumed: the modal max|component| across the
    # distinct live vectors. If one value covers >= LUMEN_INT8_SCALE_DOMINANCE
    # (default 0.90) of them, a vector on any other scale is a finding
    # ("off-scale"). If none dominates, the scale check is NOT applied and the
    # output says so — it never claims a check it did not run. Duplicates,
    # all-zero and ragged blocks are unaffected. (NaN/Inf cannot exist in int8.)
    import collections
    tops = collections.Counter()
    for v in counts:
        f = struct.unpack("<%d%s" % (DIM, packfmt), v)
        if not any(f):
            zero += 1
            continue
        tops[max(abs(x) for x in f)] += 1
    live = sum(tops.values())
    dom = envfloat("LUMEN_INT8_SCALE_DOMINANCE", 0.90)
    scale_top = envint("LUMEN_INT8_SCALE_TOP", 127)
    min_live = envint("LUMEN_INT8_MIN_VECTORS", 10)
    mode_top, mode_n = tops.most_common(1)[0] if live else (0, 0)
    # The invariant is ESTABLISHED only when all three hold; anything else is
    # COULD NOT DETERMINE (rc 2), never a clean bill — the same principle as the
    # width / no-vector-table cases. Each condition closes a false-negative
    # window that a purely data-derived mode leaves open (measured on
    # specimens): (1) enough vectors to state a scale at all, (2) ONE scale
    # dominates, (3) that scale is the int8 saturation value — max-abs
    # quantisation puts the largest component AT it (127 on the real store,
    # 100% of vectors), so an index whose vectors ALL sit on some other scale,
    # which a modal check alone would call self-consistent, is refused.
    why = None
    if live < min_live:
        why = ("only %d distinct live vector(s); at least %d are needed to state a scale"
               % (live, min_live))
    elif mode_n < dom * live:
        why = ("no single max|component| covers >= %.0f%% of the %d distinct live vectors "
               "(most common: %d at %.1f%%)" % (100 * dom, live, mode_top, 100.0 * mode_n / live))
    elif mode_top != scale_top:
        why = ("the dominant max|component| is %d (%.1f%% of vectors), not the int8 "
               "saturation value %d that max-abs quantisation produces"
               % (mode_top, 100.0 * mode_n / live, scale_top))
    if why is None:
        offscale = live - mode_n
        print("per-vector: NaN/Inf n/a (int8), %d all-zero, %d off-scale (max|component| != %d; "
              "%.2f%% of live vectors share it), %d ragged block(s)"
              % (zero, offscale, mode_top, 100.0 * mode_n / live, ragged))
    else:
        scale_unestablished = why
        print("per-vector: NaN/Inf n/a (int8), %d all-zero, int8 scale invariant not established "
              "(see below), %d ragged block(s)" % (zero, ragged))
else:
    for v in counts:
        f = struct.unpack("<%d%s" % (DIM, packfmt), v)
        if any(math.isnan(x) or math.isinf(x) for x in f): nan += 1; continue
        n = math.sqrt(sum(x*x for x in f))
        if n == 0.0: zero += 1
        elif not (nmin <= n <= nmax): badnorm += 1
    print("per-vector: %d NaN/Inf, %d all-zero, %d off-norm (band %.3f-%.3f), %d ragged block(s)"
          % (nan, zero, badnorm, nmin, nmax, ragged))
if nan or zero or badnorm or offscale or ragged: bad = True

c.close()
for n in notes: print("NOTE: %s" % n)
if bad:
    print("\n❌ CORRUPTION DETECTED")
    print("   Fix the backend first:  ./scripts/ollama-vulkan-remediation.sh --check")
    print("   Then REBUILD (not incremental - affected files have a hash and are skipped):")
    print("     ./scripts/lumen-reindex.sh %s --force" % proj)
    sys.exit(E_CORRUPT)
if scale_unestablished:
    print("\n⚠️  COULD NOT DETERMINE — int8 scale invariant not established: %s." % scale_unestablished)
    print("   Duplicate, all-zero and ragged checks ran and found nothing, but a vector on the wrong")
    print("   scale cannot be ruled out, so this is NOT a clean bill of health. Inspect the index,")
    print("   or set LUMEN_INT8_SCALE_TOP / LUMEN_INT8_SCALE_DOMINANCE if this store legitimately differs.")
    sys.exit(E_UNKNOWNGEOM)
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
