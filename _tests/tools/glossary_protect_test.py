#!/usr/bin/env python3
"""Unit tests for _tools/translate/glossary_protect.py (§11.4.140 mandate:
NON-TRANSLATABLE terms preserved verbatim through LLM translation).

Runs the REAL glossary_protect.py CLI (protect | restore) as a subprocess —
never re-implements it — and asserts:

  * protect -> restore is an identity roundtrip (verbatim preservation) when the
    sentinels survive untouched;
  * restore is tolerant to the case mutations an LLM introduces
    (z9term001z9 -> original term);
  * whole-token matching does NOT protect the acronym "AI" inside "email";
  * longest-term-first: "Model Context Protocol" wins over "MCP";
  * restore FAILS LOUD (exit 1) on an unknown/leftover sentinel token.

Usage:  python3 -m unittest _tests/tools/glossary_protect_test.py   (from repo root)
        or:   python3 _tests/tools/glossary_protect_test.py
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SCRIPT = os.path.join(REPO, "_tools", "translate", "glossary_protect.py")
GLOSSARY = os.path.join(REPO, "_tools", "translate", "glossary.json")


def _protect(text):
    """Run `protect`; return (protected_text, map_dict, map_path)."""
    fd, map_path = tempfile.mkstemp(suffix=".map.json")
    os.close(fd)
    proc = subprocess.run(
        [sys.executable, SCRIPT, "protect", "--glossary", GLOSSARY, "--map", map_path],
        input=text, capture_output=True, text=True,
    )
    assert proc.returncode == 0, f"protect failed: {proc.stderr}"
    with open(map_path, encoding="utf-8") as f:
        m = json.load(f)
    return proc.stdout, m, map_path


def _restore(text, map_path):
    proc = subprocess.run(
        [sys.executable, SCRIPT, "restore", "--map", map_path],
        input=text, capture_output=True, text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


class GlossaryProtectTest(unittest.TestCase):
    def test_roundtrip_identity(self):
        original = (
            "HelixTrack is built in Go with PostgreSQL and Redis. "
            "It speaks the Model Context Protocol (MCP) over HTTP/3."
        )
        protected, m, map_path = _protect(original)
        try:
            # Glossary terms are replaced by sentinels (text actually changed).
            self.assertNotIn("HelixTrack", protected)
            self.assertIn("Z9TERM", protected)
            # Sentinels survive untouched -> restore reproduces the original verbatim.
            code, restored, err = _restore(protected, map_path)
            self.assertEqual(code, 0, err)
            self.assertEqual(restored, original)
        finally:
            os.remove(map_path)

    def test_restore_tolerates_llm_case_mutation(self):
        original = "HelixTrack ships today."
        protected, m, map_path = _protect(original)
        try:
            # Simulate an LLM lower-casing the sentinel token.
            mutated = protected.replace("Z9TERM", "z9term").replace("Z9 ", "z9 ")
            code, restored, err = _restore(mutated, map_path)
            self.assertEqual(code, 0, err)
            self.assertIn("HelixTrack", restored)
        finally:
            os.remove(map_path)

    def test_whole_token_case_sensitive_no_false_positive(self):
        # "AI" is a glossary term but must NOT match inside "email"/"available",
        # and lowercase "ai" must not match the uppercase acronym.
        original = "Please email me when it is available."
        protected, m, map_path = _protect(original)
        try:
            self.assertEqual(protected, original, "no glossary term should match")
            self.assertNotIn("AI", m["matched"])
        finally:
            os.remove(map_path)

    def test_longest_term_first(self):
        original = "We use the Model Context Protocol here."
        protected, m, map_path = _protect(original)
        try:
            # The multi-word term must win; "MCP" must not have been used to
            # partially chew the phrase.
            self.assertIn("Model Context Protocol", m["matched"])
            code, restored, err = _restore(protected, map_path)
            self.assertEqual(code, 0, err)
            self.assertEqual(restored, original)
        finally:
            os.remove(map_path)

    def test_restore_fails_loud_on_unknown_sentinel(self):
        original = "HelixTrack."
        protected, m, map_path = _protect(original)
        try:
            # Inject a sentinel number that is NOT in the map.
            poisoned = protected + " Z9TERM999Z9"
            code, restored, err = _restore(poisoned, map_path)
            self.assertEqual(code, 1, "restore must FAIL LOUD on unknown sentinel")
            self.assertIn("unknown", err.lower() + restored.lower())
        finally:
            os.remove(map_path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
