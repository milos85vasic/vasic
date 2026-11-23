#!/usr/bin/env python3
"""Private identity fields (email/phone/address) must never reach public output."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import expertise_pages  # noqa: E402
from career import resolve as resolve_mod  # noqa: E402
from career.model import load_model  # noqa: E402
from career.render import html as html_r, latex as latex_r  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
IDENT = yaml.safe_load((REPO / "_content/career/profile.yaml").read_text(encoding="utf-8"))["identity"]
PRIVATE = [str(IDENT[k]) for k in ("email", "phone", "address") if IDENT.get(k)]


class PrivateIdentity(unittest.TestCase):
    def test_private_fields_exist(self):
        self.assertTrue(PRIVATE, "identity.email is the private field under guard")

    def test_not_in_public_expertise_output(self):
        for path, body in expertise_pages.generate().items():
            text = body if isinstance(body, str) else body.decode("utf-8", "ignore")
            for secret in PRIVATE:
                self.assertNotIn(secret, text, path)

    def test_not_in_pdf_sources(self):
        model = load_model()
        for lang in ("en", "de", "ar", "ja"):
            for kind in ("cv", "cover"):
                doc = resolve_mod.resolve(model, "ai-engineering", lang, kind=kind, epoch=0)
                for src in (html_r.render_document(doc), latex_r.render_document(doc)):
                    for secret in PRIVATE:
                        self.assertNotIn(secret, src, f"{lang}/{kind}")

    def test_only_intended_contact_lines(self):
        doc = resolve_mod.resolve(load_model(), "ai-engineering", "en", kind="cv", epoch=0)
        labels = {c["label"] for c in doc["identity"]["contact"]}
        self.assertIn(IDENT["email_public"], labels)
        for secret in PRIVATE:
            self.assertNotIn(secret, labels)


if __name__ == "__main__":
    unittest.main()
