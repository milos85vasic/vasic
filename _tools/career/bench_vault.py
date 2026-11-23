#!/usr/bin/env python3
"""Vault benchmark: machine-readable JSON + regression gate (constitution 11.4.85 / 11.4.169 'benchmark').

  bench_vault.py --out /path/result.json [--browser] [--quick]
        measure, write JSON (never into the repo unless you pass such a path), print a one-line summary.
  bench_vault.py --check [--out PATH] [--browser]
        measure, then assert the regression thresholds below; exit 0 pass, 1 regression, 2 could-not-measure.

Measured: PBKDF2-HMAC-SHA256 600k derive time (python), AES-256-GCM seal/unseal throughput through the vault's
own seal_blob/unseal_blob for 100 KiB / 1 MiB / 10 MiB (median of repeats), an end-to-end on-disk
seal_items+verify of 10 MiB, and (with --browser) the in-Chromium PBKDF2 derive, full console unlock and
download-decrypt times using the real vault.js.

THRESHOLDS are set from the baseline measured on this host (see BASELINE_NOTE) with GENEROUS margins (cold CPU,
shared host).  The PBKDF2 test has a LOWER bound too: a derive that gets *faster* than the floor means the
iteration count was weakened -- a security regression, not a speed-up.  Wall-clock is only ever asserted here,
never in the unit/chaos/fuzz suites.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import secrets
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import vault  # noqa: E402

HERE = Path(__file__).resolve().parent
PW_LIB = HERE.parents[1] / "_tests" / "node_modules" / "playwright-core"
KIB, MIB = 1024, 1024 * 1024

BASELINE_NOTE = ("baseline 2026-11-23, 16-cpu x86_64 dev host, python 3.14.4, chromium (playwright-core 1.61): pbkdf2 python 149 ms, "
                 "browser derive 107 ms, seal 1.0-2.1 GiB/s, unseal 1.6-2.9 GiB/s, e2e 10 MiB seal+verify 0.40 s, "
                 "console unlock 418 ms, download-decrypt 195 ms; thresholds are 5-10x looser than baseline")
THRESHOLDS = {
    "pbkdf2_python_s": {"min": 0.05, "max": 1.0},           # min: guards against weakened iteration count
    "gcm_seal_MiBps": {"100KiB": {"min": 100}, "1MiB": {"min": 200}, "10MiB": {"min": 200}},
    "gcm_unseal_MiBps": {"100KiB": {"min": 100}, "1MiB": {"min": 200}, "10MiB": {"min": 200}},
    "e2e_10MiB_seal_verify_s": {"max": 4.0},
    "browser_derive_ms": {"min": 20, "max": 2000},
    "browser_unlock_ms": {"max": 5000},
    "browser_download_ms": {"max": 3000},
}


def timeit(fn, repeat):
    ts = []
    for _ in range(repeat):
        t = time.perf_counter(); fn(); ts.append(time.perf_counter() - t)
    return statistics.median(ts)


def measure(browser: bool, quick: bool) -> dict:
    r = {"schema": 1, "host": {"python": platform.python_version(), "machine": platform.machine(),
                               "cpus": os.cpu_count()}, "baseline_note": BASELINE_NOTE}
    salt = bytes(range(16))
    r["pbkdf2_iterations"] = vault.PBKDF2_ITERS
    r["pbkdf2_python_s"] = timeit(lambda: vault.derive_key("bench-passphrase", salt), 3 if quick else 5)
    key = vault.derive_key("bench-passphrase", salt)
    sealS, unsealS = {}, {}
    for label, n, rep in (("100KiB", 100 * KIB, 15), ("1MiB", MIB, 9), ("10MiB", 10 * MIB, 5)):
        data = os.urandom(n)
        kw = dict(key=key, salt=vault.b64(salt), slot="b/en/cv", name="b.pdf", mime="application/pdf")
        box = {}
        sealS[label] = n / MIB / timeit(lambda: box.update(x=vault.seal_blob(data, **kw)), rep)
        rec, blob = box["x"]
        unsealS[label] = n / MIB / timeit(lambda: vault.unseal_blob(blob, rec, key=key, salt=kw["salt"], slot=kw["slot"]), rep)
    r["gcm_seal_MiBps"] = sealS
    r["gcm_unseal_MiBps"] = unsealS
    pw = " ".join("".join(secrets.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(7)) for _ in range(7))
    data = os.urandom(10 * MIB)
    with tempfile.TemporaryDirectory() as d:
        root = Path(d) / "v"
        def e2e():
            vault.seal_items([("b/en/cv", "b.pdf", "application/pdf", data)], passphrase=pw, out_root=root)
            vault.verify_vault(pw, root)
        r["e2e_10MiB_seal_verify_s"] = timeit(e2e, 2 if quick else 3)
        if browser:
            r.update(browser_measure(pw, root))
    return r


def browser_measure(pw: str, root: Path) -> dict:
    if not (shutil.which("node") and PW_LIB.is_dir()):
        return {"browser_error": "node/playwright missing -- browser benchmark CANNOT run"}
    p = subprocess.run(["node", str(HERE / "bench_vault_browser.js")], capture_output=True, text=True, timeout=600,
                       env=dict(os.environ, VAULT_DIR=str(root), VAULT_PW=pw, REPEAT="3"))
    try:
        o = json.loads(p.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"browser_error": f"no JSON from node rc={p.returncode}: {p.stderr[-300:]}"}
    if o.get("error"):
        return {"browser_error": o["error"][:300]}
    med = statistics.median
    return {"browser_derive_ms": med(o["derive_ms"]), "browser_unlock_ms": med(o["unlock_ms"]),
            "browser_download_ms": med(o["download_ms"]), "browser_samples": o}


def check(result: dict, want_browser: bool):
    """Return (failures, undetermined) lists."""
    fails, undet = [], []

    def one(name, val, lim):
        if "min" in lim and val < lim["min"]:
            fails.append(f"{name}={val:.4g} < min {lim['min']}")
        if "max" in lim and val > lim["max"]:
            fails.append(f"{name}={val:.4g} > max {lim['max']}")

    for k, lim in THRESHOLDS.items():
        if k.startswith("browser_"):
            if not want_browser:
                continue
            if k not in result:
                undet.append(f"{k}: not measured ({result.get('browser_error', 'no browser data')})")
                continue
        if isinstance(next(iter(lim.values())), dict):
            for sub, l2 in lim.items():
                one(f"{k}[{sub}]", result[k][sub], l2)
        else:
            one(k, result[k], lim)
    if result.get("pbkdf2_iterations") != 600_000:
        fails.append(f"pbkdf2_iterations={result.get('pbkdf2_iterations')} != 600000")
    return fails, undet


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", type=Path, help="write the JSON result here (use a scratch path)")
    ap.add_argument("--check", action="store_true", help="assert regression thresholds (exit 1 on regression, 2 if undetermined)")
    ap.add_argument("--browser", action="store_true", help="also measure in-Chromium derive/unlock/download")
    ap.add_argument("--quick", action="store_true", help="fewer repeats")
    ap.add_argument("--prove-failure", action="store_true", help="paired proof: the --check gate catches seeded regressions")
    ns = ap.parse_args(argv)
    if ns.prove_failure:
        good = {"pbkdf2_iterations": 600000, "pbkdf2_python_s": 0.15, "e2e_10MiB_seal_verify_s": 0.4,
                "gcm_seal_MiBps": {"100KiB": 1700, "1MiB": 2000, "10MiB": 1000},
                "gcm_unseal_MiBps": {"100KiB": 1500, "1MiB": 2400, "10MiB": 2800}}
        muts = {"slow-pbkdf2": dict(good, pbkdf2_python_s=3.0), "weakened-iterations": dict(good, pbkdf2_iterations=1000, pbkdf2_python_s=0.001),
                "slow-gcm": dict(good, gcm_unseal_MiBps={"100KiB": 1500, "1MiB": 2400, "10MiB": 20}),
                "slow-e2e": dict(good, e2e_10MiB_seal_verify_s=60)}
        ok = not check(good, False)[0] and all(check(m, False)[0] for m in muts.values())
        print("prove-failure:", "PASS (control green, %d mutations caught)" % len(muts) if ok else "FAIL")
        return 0 if ok else 1
    if not ns.out and not ns.check:
        ap.error("give --out PATH and/or --check")
    res = measure(ns.browser, ns.quick)
    if ns.out:
        ns.out.parent.mkdir(parents=True, exist_ok=True)
        ns.out.write_text(json.dumps(res, indent=1, sort_keys=True), encoding="utf-8")
    print(f"pbkdf2={res['pbkdf2_python_s']*1000:.0f}ms seal10MiB={res['gcm_seal_MiBps']['10MiB']:.0f}MiB/s "
          f"unseal10MiB={res['gcm_unseal_MiBps']['10MiB']:.0f}MiB/s e2e10MiB={res['e2e_10MiB_seal_verify_s']:.2f}s"
          + (f" browser_derive={res.get('browser_derive_ms', float('nan')):.0f}ms unlock={res.get('browser_unlock_ms', float('nan')):.0f}ms"
             if ns.browser else ""))
    if ns.check:
        fails, undet = check(res, ns.browser)
        for f in fails:
            print("REGRESSION", f, file=sys.stderr)
        for u in undet:
            print("CANNOT DETERMINE", u, file=sys.stderr)
        if fails:
            return 1
        if undet:
            return 2
        print("bench check: all thresholds met")
    return 0


if __name__ == "__main__":
    sys.exit(main())
