"""Scan Markdown documentation for verified frontmatter dates."""

from __future__ import annotations

import os
import re
from datetime import date
from pathlib import Path
from typing import Any


DOCS_ROOT_ENV = "VERIFIED_SCANNER_DOCS_ROOT"
VERIFIED_RE = re.compile(r"^\s*verified\s*:\s*(\d{4}-\d{2}-\d{2})\b", re.MULTILINE)


def _resolve_docs_root(docs_root: str | os.PathLike[str] | None) -> Path:
    if docs_root is not None:
        return Path(docs_root)
    return Path(os.environ.get(DOCS_ROOT_ENV, "docs"))


def _valid_iso_date(value: str) -> bool:
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


def find_min_verified_date(docs_root: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    """Return the oldest verified date and all Markdown file/date entries.

    `docs_root` may be provided directly or via VERIFIED_SCANNER_DOCS_ROOT. Missing
    directories, unreadable files, files without matches, and malformed dates yield
    no entries instead of raising.
    """

    root = _resolve_docs_root(docs_root)
    if not root.is_dir():
        return {"min_date": "", "entries": []}

    entries: list[dict[str, str]] = []

    for markdown_file in sorted(root.rglob("*.md")):
        if not markdown_file.is_file():
            continue
        try:
            content = markdown_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        for match in VERIFIED_RE.finditer(content):
            verified_date = match.group(1)
            if not _valid_iso_date(verified_date):
                continue
            relative_file = markdown_file.relative_to(root).as_posix()
            entries.append({"file": relative_file, "date": verified_date})

    min_date = min((entry["date"] for entry in entries), default="")
    return {"min_date": min_date, "entries": entries}
