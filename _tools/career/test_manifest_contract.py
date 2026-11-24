#!/usr/bin/env python3
"""Contract tests: the manifest the REAL writer emits vs the REAL job_seeker validator.

Run:  python3 -m unittest discover -s _tools/career -p 'test_manifest_contract.py'

JSK-T172 (umbrella half) / JSK-T160 (cover metadata).  job_seeker refuses live approval
unless the template manifest carries ``epoch``, ``overlay_sha``, per-file ``gate:"pass"``
and per-cover ``cover_date``/``company``/``role`` (``internal/templates``, ``internal/draft``).
These tests build a small real sample (real LuaLaTeX/WeasyPrint render, real gates, real
writer) and then run job_seeker's own Go code over the result: ``templates.Open`` +
``Store.Check`` (freshness policy) + ``Resolve``, and ``draft``'s cover check.  The Go side
is compiled with ``go run -overlay`` so NOTHING is written into the job_seeker checkout.
No manifest in this file is hand-made as evidence: negative cases MUTATE a real manifest.

Skips (never passes) when go, job_seeker, LuaLaTeX or pdftotext are missing: an undetermined
check is not a pass.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import buildlib, sample_build  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def _find_job_seeker() -> Path | None:
    for base in (REPO, *REPO.parents):
        for cand in (base / "job_seeker", base / "vasic" / "job_seeker"):
            if (cand / "internal" / "templates" / "templates.go").is_file():
                return cand
    return None


JS = _find_job_seeker()

PROBE_MAIN = r'''package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/vasic-digital/job_seeker/internal/draft"
	"github.com/vasic-digital/job_seeker/internal/templates"
)

// zz contract probe: runs job_seeker's own freshness policy and cover check over a manifest directory.
func main() {
	dir, overlay, nowS, company, role := os.Args[1], os.Args[2], os.Args[3], os.Args[4], os.Args[5]
	now, err := time.Parse(time.RFC3339, nowS)
	if err != nil {
		fmt.Println(`{"error":"bad now"}`)
		os.Exit(2)
	}
	out := map[string]any{}
	st, err := templates.Open(dir)
	if err != nil {
		out["open"] = err.Error()
		json.NewEncoder(os.Stdout).Encode(out)
		return
	}
	out["open"] = "ok"
	out["count"] = st.Count()
	pol := templates.Policy{MaxAge: draft.DefaultTemplateMaxAge, OverlaySHA: overlay, RequireOverlay: true, RequireGate: true}
	if err := st.Check(pol, now); err != nil {
		cause := "unknown"
		if se, ok := err.(*templates.StaleError); ok {
			cause = se.Cause
		}
		out["check"] = cause
	} else {
		out["check"] = "ok"
	}
	var files []templates.File
	resolved := 0
	for _, a := range st.Areas() {
		for _, l := range []string{"en", "ru", "ar"} {
			for _, k := range templates.Kinds {
				f, err := st.Resolve(k, a, l)
				if err != nil {
					out["resolve_"+k+"_"+l] = err.Error()
					continue
				}
				resolved++
				files = append(files, f)
			}
		}
	}
	out["resolved"] = resolved
	out["cover"] = draft.ProbeCheckCover(now, company, role, files)
	json.NewEncoder(os.Stdout).Encode(out)
}
'''

PROBE_DRAFT = r'''package draft

import (
	"time"

	"github.com/vasic-digital/job_seeker/internal/templates"
)

// ProbeCheckCover exposes the unexported cover check (JSK-T160/T161) to the umbrella contract test only.
func ProbeCheckCover(now time.Time, company, role string, files []templates.File) string {
	s := &Service{Now: func() time.Time { return now }}
	if r := s.checkCover(files, postingRow{Company: company, Title: role}); r != nil {
		if c, ok := r.evidence["cause"].(string); ok {
			return c
		}
		return "refused"
	}
	return "ok"
}
'''


def go_probe(manifest_dir: Path, overlay_sha: str, now: datetime, company="", role="") -> dict:
    assert JS is not None
    with tempfile.TemporaryDirectory(prefix="jsk-probe-") as td:
        td = Path(td)
        (td / "main.go").write_text(PROBE_MAIN, encoding="utf-8")
        (td / "probe.go").write_text(PROBE_DRAFT, encoding="utf-8")
        ov = {"Replace": {str(JS / "cmd" / "zz_contract_probe" / "main.go"): str(td / "main.go"),
                          str(JS / "internal" / "draft" / "zz_contract_probe.go"): str(td / "probe.go")}}
        (td / "overlay.json").write_text(json.dumps(ov), encoding="utf-8")
        r = subprocess.run(["go", "run", "-overlay", str(td / "overlay.json"), "./cmd/zz_contract_probe",
                            str(manifest_dir), overlay_sha, now.strftime("%Y-%m-%dT%H:%M:%SZ"), company, role],
                           cwd=JS, capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        raise RuntimeError(f"go probe failed rc={r.returncode}: {r.stderr[-800:]}")
    return json.loads(r.stdout)


TOOLS = shutil.which("go") and JS is not None and sample_build.have_toolchain()


@unittest.skipUnless(TOOLS, "go, job_seeker checkout, lualatex or pdftotext missing: cannot determine")
class ManifestContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.td, cls.out, cls.priv = sample_build.scratch_pair()
        cls.sample = sample_build.build_sample(cls.out, cls.priv)
        cls.epoch = sample_build.EPOCH
        cls.day = datetime.fromtimestamp(cls.epoch, tz=timezone.utc)
        cls.manifest = json.loads((cls.out / "manifest.json").read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def test_sample_gates_all_pass(self):
        self.assertEqual([r for r in self.sample["results"] if r["rc"] != 0], [])

    def test_top_level_fields(self):
        m = self.manifest
        self.assertEqual(m["epoch"], self.epoch)
        self.assertRegex(m["overlay_sha"], r"^[0-9a-f]{64}$")
        self.assertEqual(m["overlay_sha"], self.sample["overlay_sha"])

    def test_per_file_fields(self):
        for name, e in self.manifest["files"].items():
            if name.endswith(".pdf"):
                self.assertEqual(e["gate"], "pass", name)
            else:
                self.assertNotIn("gate", e, name)
            if name.startswith("cover-") and name.endswith(".pdf"):
                self.assertEqual((e["cover_date"], e["company"], e["role"]),
                                 (self.day.date().isoformat(), "", ""), name)
            else:
                self.assertNotIn("cover_date", e, name)

    def test_real_validator_accepts_fresh_set(self):
        got = go_probe(self.out, self.sample["overlay_sha"], self.day)
        self.assertEqual(got["open"], "ok")
        self.assertEqual(got["check"], "ok", got)
        self.assertEqual(got["resolved"], 6, got)
        self.assertEqual(got["cover"], "ok", got)

    def test_real_validator_refuses_other_day_cover(self):
        later = self.day.replace(day=self.day.day + 1)
        self.assertEqual(go_probe(self.out, self.sample["overlay_sha"], later)["cover"], "date_stale")

    def test_real_validator_refuses_foreign_overlay(self):
        got = go_probe(self.out, "0" * 64, self.day)
        self.assertEqual(got["check"], "overlay", got)

    def _mutated(self, mutate) -> Path:
        d = Path(tempfile.mkdtemp(prefix="mut-", dir=self.td.name))
        for p in self.out.iterdir():
            if p.suffix == ".pdf":
                (d / p.name).symlink_to(p)
        m = json.loads(json.dumps(self.manifest))
        mutate(m)
        (d / "manifest.json").write_text(json.dumps(m), encoding="utf-8")
        return d

    def test_validator_refuses_failed_gate_stamp(self):
        def mut(m):
            m["files"]["cv-ai-engineering-en.pdf"]["gate"] = "fail"
        self.assertEqual(go_probe(self._mutated(mut), self.sample["overlay_sha"], self.day)["check"], "gate")

    def test_validator_refuses_missing_epoch(self):
        def mut(m):
            del m["epoch"]
        self.assertEqual(go_probe(self._mutated(mut), self.sample["overlay_sha"], self.day)["check"], "epoch_missing")

    def test_validator_refuses_mismatching_company(self):
        def mut(m):
            for n, e in m["files"].items():  # the check inspects the last cover of the resolved set
                if n.startswith("cover-") and n.endswith(".pdf"):
                    e["company"] = "Other Co"
        self.assertEqual(go_probe(self._mutated(mut), self.sample["overlay_sha"], self.day, "Acme", "Eng")["cover"], "company")


class WriterUnit(unittest.TestCase):
    """The writer is deterministic and fail-closed without a verdict (no PDFs needed)."""

    def _dir(self):
        td = tempfile.TemporaryDirectory()
        (Path(td.name) / "cv-a-en.pdf").write_bytes(b"x")
        (Path(td.name) / "cover-a-en.pdf").write_bytes(b"y")
        (Path(td.name) / "cv-a-en.tex").write_bytes(b"z")
        return td

    def test_no_verdict_is_unknown_not_pass(self):
        with self._dir() as d:
            m = json.loads(buildlib.manifest_bytes(Path(d), ["cv-a-en.pdf", "cv-a-en.tex"], 1_795_000_000))
            self.assertEqual(m["files"]["cv-a-en.pdf"]["gate"], "unknown")
            self.assertEqual(m["overlay_sha"], "")

    def test_verdict_mapping_and_determinism(self):
        with self._dir() as d:
            names = ["cv-a-en.pdf", "cover-a-en.pdf", "cv-a-en.tex"]
            rc = {"cv-a-en": 0, "cover-a-en": 2}
            a = buildlib.manifest_bytes(Path(d), names, 1_795_000_000, overlay_sha="ab", gate_rc=rc)
            self.assertEqual(a, buildlib.manifest_bytes(Path(d), names, 1_795_000_000, overlay_sha="ab", gate_rc=rc))
            m = json.loads(a)
            self.assertEqual(m["files"]["cv-a-en.pdf"]["gate"], "pass")
            self.assertEqual(m["files"]["cover-a-en.pdf"]["gate"], "undetermined")
            self.assertNotIn("gate", m["files"]["cv-a-en.tex"])


if __name__ == "__main__":
    unittest.main()
