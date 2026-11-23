"""Career document engine: profile -> DocumentModel -> six output formats.

The pipeline is a straight line with one contract at each end:

    profile.yaml + areas/*.yaml + locales/*.yaml      (content, human-editable)
        -> model.py      load + strictly validate
        -> resolve.py    career.document.v1 DocumentModel (fully resolved)
        -> render/*      LaTeX, HTML, Markdown, DOCX, JSON Resume, plain text
        -> gates.py      prove the output is what it claims to be
        -> vault.py      seal for admin-only delivery

No renderer reads ``profile.yaml`` and no renderer contains content. That is
what makes the five formats agree by construction rather than by maintenance.
"""

from __future__ import annotations

__all__ = ["__version__"]

__version__ = "1.0.0"
