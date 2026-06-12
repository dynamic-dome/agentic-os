"""Inject the documentation verification watermark into README files.

Convention: the README watermark is exactly one HTML comment line,
`<!-- Doku verifiziert bis: YYYY-MM-DD -->`, placed directly after the first
Markdown H1 heading. Existing watermark lines are replaced, so repeated runs
with the same date leave the file unchanged.
"""

from __future__ import annotations

import re
from datetime import date
from pathlib import Path


WATERMARK_RE = re.compile(r"^<!-- Doku verifiziert bis: \d{4}-\d{2}-\d{2} -->\r?$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _validate_min_date(min_date: str) -> str:
    if not ISO_DATE_RE.fullmatch(min_date):
        raise ValueError("min_date must use YYYY-MM-DD format")
    date.fromisoformat(min_date)
    return min_date


def _detect_newline(content: str) -> str:
    if "\r\n" in content:
        return "\r\n"
    return "\n"


def inject_verify_watermark(readme_path: str | Path, min_date: str) -> bool:
    """Insert or update the single README verification watermark line.

    The watermark format is `<!-- Doku verifiziert bis: YYYY-MM-DD -->` and its
    canonical position is directly after the first Markdown H1 heading. If no H1
    exists, the line is inserted at the top. The function is idempotent: it only
    writes the README when the rendered content changes.

    Returns True when the file was changed, otherwise False.
    """

    verified_date = _validate_min_date(min_date)
    path = Path(readme_path)
    original = path.read_text(encoding="utf-8")
    newline = _detect_newline(original)
    watermark = f"<!-- Doku verifiziert bis: {verified_date} -->"

    trailing_newline = original.endswith(("\n", "\r\n"))
    lines = original.splitlines()
    lines = [line for line in lines if not WATERMARK_RE.match(line)]

    insert_at = 0
    for index, line in enumerate(lines):
        if line.startswith("# "):
            insert_at = index + 1
            break

    lines.insert(insert_at, watermark)
    rendered = newline.join(lines)
    if trailing_newline or original == "":
        rendered += newline

    if rendered == original:
        return False

    path.write_text(rendered, encoding="utf-8")
    return True
