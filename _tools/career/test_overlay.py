#!/usr/bin/env python3
"""Overlay tests (TDD red-first). Fake placeholder values only.

Run: python3 -m unittest discover -s _tools/career -p 'test_overlay*.py'
"""
from __future__ import annotations

import io
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from career import overlay, resolve, model, vault  # noqa: E402

FAKE_PHONE = "+00 555 0100 ZQX"
FAKE_ADDR = "99 Zqx Placeholder Lane"
OVERLAY_YAML = f"""schema: career.overlay.v1
phone: "{FAKE_PHONE}"
address: "{FAKE_ADDR}"
salary_expectation: "ZQX 1234"
referees:
  - name: "Zqx Referee"
    contact: "zqx@example.invalid"
private_notes: "zqx note"
"""


def make_dir(text: str = OVERLAY_YAML) -> tempfile.TemporaryDirectory:
    td = tempfile.TemporaryDirectory()
    (Path(td.name) / "overlay.yaml").write_text(text, encoding="utf-8")
    return td


class LoadTests(unittest.TestCase):
    def test_unset_means_no_overlay(self):
        self.assertIsNone(overlay.load_overlay(env={}))

    def test_loads_valid(self):
        with make_dir() as d:
            ov = overlay.load_overlay(env={overlay.ENV: d})
            self.assertEqual(ov["phone"], FAKE_PHONE)

    def test_unknown_key_rejected_without_values(self):
        with make_dir(OVERLAY_YAML + 'bogus_key: "SECRETVALUE9"\n') as d:
            with self.assertRaises(overlay.OverlayError) as cm:
                overlay.load_overlay(env={overlay.ENV: d})
            msg = str(cm.exception)
            self.assertIn("bogus_key", msg)
            self.assertNotIn("SECRETVALUE9", msg)
            self.assertNotIn(FAKE_PHONE, msg)

    def test_bad_type_error_has_no_value(self):
        with make_dir('phone: ["' + FAKE_PHONE + '"]\n') as d:
            with self.assertRaises(overlay.OverlayError) as cm:
                overlay.load_overlay(env={overlay.ENV: d})
            self.assertNotIn(FAKE_PHONE, str(cm.exception))

    def test_dir_set_but_file_missing_is_error(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(overlay.OverlayError):
                overlay.load_overlay(env={overlay.ENV: d})

    def test_deep_merge(self):
        self.assertEqual(overlay.deep_merge({"a": {"b": 1, "c": 2}}, {"a": {"b": 9}}),
                         {"a": {"b": 9, "c": 2}})


SCORING_YAML = """schema: career.overlay.v1
salary_min: 12345
salary_currency: ZZZ
salary_period: month
tz_window:
  start_utc: 6
  end_utc: 14
allowed_onsite_cities: ["Zqxville"]
blocked_companies: ["Zqx Blocked Co"]
eligible_countries: ["ZZ", "QX"]
"""


WA_LANG_YAML = """schema: career.overlay.v1
work_auth_countries: ["ZZ", "QX"]
languages: ["zz", "qx"]
"""


class WorkAuthLanguagesTests(unittest.TestCase):
    """JSK-T177: work_auth_countries (ISO 3166 alpha-2) and languages (ISO 639-1)."""

    def load(self, text):
        with make_dir(text) as d:
            return overlay.load_overlay(env={overlay.ENV: d})

    def err(self, text):
        with make_dir(text) as d:
            with self.assertRaises(overlay.OverlayError) as cm:
                overlay.load_overlay(env={overlay.ENV: d})
            return str(cm.exception)

    def test_accepts_both_keys(self):
        ov = self.load(WA_LANG_YAML)
        self.assertEqual(ov["work_auth_countries"], ["ZZ", "QX"])
        self.assertEqual(ov["languages"], ["zz", "qx"])
        for k in ("work_auth_countries", "languages"):
            self.assertIn(k, overlay.ALLOWED)
            self.assertIn(k, overlay.SCORING_KEYS)

    def test_empty_work_auth_means_none_and_is_accepted(self):
        ov = self.load("schema: career.overlay.v1\nwork_auth_countries: []\n")
        self.assertEqual(ov["work_auth_countries"], [])

    def test_rejects_bad_values_without_echo(self):
        bad = {
            'work_auth_countries: ["zz"]': "work_auth_countries",
            'work_auth_countries: ["ZZZ"]': "work_auth_countries",
            'work_auth_countries: "ZZ"': "work_auth_countries",
            "languages: []": "languages",
            'languages: ["ZZ"]': "languages",
            'languages: ["zzz"]': "languages",
            'languages: "zz"': "languages",
            "languages: [1]": "languages",
        }
        for line, key in bad.items():
            msg = self.err("schema: career.overlay.v1\n" + line + "\n")
            self.assertIn(key, msg, line)
            for v in ("zzz", "ZZZ"):
                self.assertNotIn(v, msg, line)

    def test_not_merged_into_identity(self):
        merged = overlay.apply_identity({"name": "x"}, self.load(WA_LANG_YAML))
        self.assertNotIn("work_auth_countries", merged)
        self.assertNotIn("languages", merged)


class ScoringKeysTests(unittest.TestCase):
    """JSK-T011: scoring keys for the job_seeker overlay reader (synthetic values only)."""

    def load(self, text):
        with make_dir(text) as d:
            return overlay.load_overlay(env={overlay.ENV: d})

    def err(self, text):
        with make_dir(text) as d:
            with self.assertRaises(overlay.OverlayError) as cm:
                overlay.load_overlay(env={overlay.ENV: d})
            return str(cm.exception)

    def test_all_scoring_keys_allowed(self):
        ov = self.load(SCORING_YAML)
        for k in ("salary_min", "salary_currency", "salary_period", "tz_window",
                  "allowed_onsite_cities", "blocked_companies", "eligible_countries"):
            self.assertIn(k, ov)
            self.assertIn(k, overlay.ALLOWED)

    def test_unknown_key_still_rejected_alongside_scoring_keys(self):
        msg = self.err(SCORING_YAML + 'salary_maxx: 99999\n')
        self.assertIn("salary_maxx", msg)
        self.assertNotIn("99999", msg)
        self.assertNotIn("12345", msg)

    def test_bad_types_rejected_without_values(self):
        bad = {
            'salary_min: "12345"': "salary_min",          # str not int
            "salary_min: true": "salary_min",             # bool is not int
            "salary_min: -5": "salary_min",               # negative
            'salary_currency: "usd1"': "salary_currency", # not 3 upper letters
            'salary_period: "week"': "salary_period",
            "tz_window: [1, 2]": "tz_window",
            "tz_window: {start_utc: 25, end_utc: 3}": "tz_window",
            "tz_window: {start_utc: 1}": "tz_window",
            "tz_window: {start_utc: 1, end_utc: 2, x: 3}": "tz_window",
            'allowed_onsite_cities: "Zqxville"': "allowed_onsite_cities",
            "allowed_onsite_cities: [1]": "allowed_onsite_cities",
            'blocked_companies: "Zqx"': "blocked_companies",
            "blocked_companies: [{a: b}]": "blocked_companies",
            'eligible_countries: ["zz"]': "eligible_countries",
            'eligible_countries: ["ZZZ"]': "eligible_countries",
            'eligible_countries: "ZZ"': "eligible_countries",
        }
        for line, key in bad.items():
            msg = self.err("schema: career.overlay.v1\n" + line + "\n")
            self.assertIn(key, msg, line)
            for v in ("12345", "usd1", "Zqxville", "Zqx"):
                self.assertNotIn(v, msg, line)

    def test_scoring_keys_not_merged_into_identity(self):
        ov = self.load(SCORING_YAML + 'phone: "' + FAKE_PHONE + '"\n')
        merged = overlay.apply_identity({"name": "x"}, ov)
        self.assertEqual(merged["phone"], FAKE_PHONE)
        for k in overlay.SCORING_KEYS:
            self.assertNotIn(k, merged)

    def test_no_personal_values_in_public_source(self):
        src = Path(overlay.__file__).read_text(encoding="utf-8")
        self.assertNotIn("Zqx", src)
        # the allow-list is names and kinds only: no digits-bearing default values
        self.assertEqual(set(overlay.SCORING_KEYS) - set(overlay.ALLOWED), set())

    def test_leak_scan_covers_scoring_strings(self):
        ov = self.load(SCORING_YAML)
        vals = overlay._values(ov)
        self.assertIn("Zqx Blocked Co", vals)
        self.assertIn("Zqxville", vals)


class ResolveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = model.load_model()
        cls.area = model.load_areas()[0].id

    def test_default_has_no_overlay_keys(self):
        doc = resolve.resolve(self.m, self.area, "en", epoch=1)
        self.assertNotIn("phone", doc["identity"])
        self.assertNotIn(FAKE_PHONE, repr(doc))

    def test_overlay_merged_into_identity(self):
        with make_dir() as d:
            ov = overlay.load_overlay(env={overlay.ENV: d})
        doc = resolve.resolve(self.m, self.area, "en", epoch=1, overlay=ov)
        self.assertEqual(doc["identity"]["phone"], FAKE_PHONE)
        self.assertEqual(doc["identity"]["name"],
                         resolve.resolve(self.m, self.area, "en", epoch=1)["identity"]["name"])

    def test_resolve_ignores_env(self):
        with make_dir() as d, mock.patch.dict(os.environ, {overlay.ENV: d}):
            doc = resolve.resolve(self.m, self.area, "en", epoch=1)
        self.assertNotIn("phone", doc["identity"])


class PublicPagesUnaffected(unittest.TestCase):
    def test_expertise_pages_byte_identical(self):
        from career import expertise_pages as ep
        base = ep.generate()
        with make_dir() as d, mock.patch.dict(os.environ, {overlay.ENV: d}):
            with_ov = ep.generate()
        self.assertEqual(base, with_ov)
        self.assertFalse(any(FAKE_PHONE.encode() in (v if isinstance(v, bytes) else v.encode()) or FAKE_ADDR.encode() in (v if isinstance(v, bytes) else v.encode()) for v in with_ov.values()))


class OutdirGuard(unittest.TestCase):
    def setUp(self):
        self.repo = Path(overlay.REPO_ROOT)

    def test_public_tree_refused(self):
        for p in (self.repo / "milosvasic.ru" / "downloads", self.repo / "docs", self.repo / "_tools"):
            with self.assertRaises(overlay.OverlayError):
                overlay.assert_safe_outdir(p, private_dir=None)

    def test_cache_allowed(self):
        overlay.assert_safe_outdir(self.repo / ".cache-career", private_dir=None)

    def test_outside_tree_requires_private(self):
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            with self.assertRaises(overlay.OverlayError):
                overlay.assert_safe_outdir(Path(t), private_dir=Path(pd))
            overlay.assert_safe_outdir(Path(pd) / "vault", private_dir=Path(pd))


class VaultToPrivate(unittest.TestCase):
    def test_default_out(self):
        with tempfile.TemporaryDirectory() as pd:
            self.assertEqual(overlay.vault_out_dir(env={overlay.ENV: pd}), Path(pd) / "vault")
        with self.assertRaises(overlay.OverlayError):
            overlay.vault_out_dir(env={})

    def test_seal_all_to_private_unset_fails(self):
        err = io.StringIO()
        with redirect_stderr(err), mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop(overlay.ENV, None)
            rc = vault.main(["seal-all", "--to-private"])
        self.assertEqual(rc, 2)


class VaultScript(unittest.TestCase):
    def test_script_run_unset_rc2_with_message(self):
        env = {k: v for k, v in os.environ.items() if k != overlay.ENV}
        r = subprocess.run([sys.executable, str(Path(vault.__file__)), "seal-all", "--to-private"],
                           capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 2)
        self.assertIn("CAREER_PRIVATE_DIR is not set", r.stderr)


class PrivateCheck(unittest.TestCase):
    def _tree(self, leak: bool):
        td = tempfile.TemporaryDirectory()
        r = Path(td.name)
        subprocess.run(["git", "init", "-q", str(r)], check=True)
        (r / "a.txt").write_text(("x " + FAKE_PHONE if leak else "clean") + "\n")
        (r / "docs").mkdir()
        (r / "docs" / "n.md").write_text("see " + "career" + "_private\n")
        (r / "code.py").write_text("x = 1\n")
        subprocess.run(["git", "-C", str(r), "add", "--", "a.txt", "docs/n.md", "code.py"], check=True)
        return td

    def test_leak_reports_paths_only(self):
        with self._tree(True) as t, make_dir() as d:
            ov = overlay.load_overlay(env={overlay.ENV: d})
            hits = overlay.find_value_leaks(ov, Path(t))
            self.assertEqual(hits, ["a.txt"])
            self.assertNotIn(FAKE_PHONE, repr(hits))

    def test_clean(self):
        with self._tree(False) as t, make_dir() as d:
            ov = overlay.load_overlay(env={overlay.ENV: d})
            self.assertEqual(overlay.find_value_leaks(ov, Path(t)), [])

    def test_reference_outside_docs_flagged(self):
        with self._tree(False) as t:
            (Path(t) / "code.py").write_text("p='" + "career" + "_private'\n")
            subprocess.run(["git", "-C", t, "add", "--", "code.py"], check=True)
            self.assertEqual(overlay.find_private_refs(Path(t)), ["code.py"])

    def test_visibility(self):
        self.assertEqual(overlay.visibility_rc("private"), 0)
        self.assertEqual(overlay.visibility_rc("public"), 1)
        self.assertEqual(overlay.visibility_rc(None), 2)


if __name__ == "__main__":
    unittest.main()
