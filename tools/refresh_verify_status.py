"""Refresh the README documentation verification watermark.

This wrapper runs the verified-frontmatter scanner and then the README
watermark generator:

1. scan Markdown files under `docs/` for `verified: YYYY-MM-DD`
2. use the oldest verified date as the README watermark date
3. update `README.md`, unless `--dry-run` is set

Exit codes:
- 0: refresh succeeded; README was updated or already current
- 1: fatal input error, for example missing README
- 2: recoverable skip, for example missing docs directory, no Markdown docs, or
  no valid verified lines

`--dry-run` prints a unified diff preview and never writes to the target README.
CI integration is intentionally out of scope; this script is meant to be run
manually for now.
"""

from __future__ import annotations

import argparse
import difflib
import sys
import tempfile
from pathlib import Path

try:
    from tools.generate_watermark import inject_verify_watermark
    from tools.verified_scanner import find_min_verified_date
except ModuleNotFoundError:  # pragma: no cover - supports `python tools/...py`
    from generate_watermark import inject_verify_watermark
    from verified_scanner import find_min_verified_date


EXIT_SUCCESS = 0
EXIT_FATAL = 1
EXIT_RECOVERABLE_SKIP = 2


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Refresh README verification watermark from docs frontmatter.")
    parser.add_argument("--dry-run", action="store_true", help="Preview README changes without writing.")
    parser.add_argument("--docs-root", default="docs", help="Documentation root to scan. Default: docs")
    parser.add_argument("--readme", default="README.md", help="README path to update. Default: README.md")
    return parser


def _markdown_count(docs_root: Path) -> int:
    if not docs_root.is_dir():
        return 0
    return sum(1 for path in docs_root.rglob("*.md") if path.is_file())


def _render_preview(readme_path: Path, min_date: str) -> str:
    original = readme_path.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as tmp:
        preview_path = Path(tmp) / readme_path.name
        preview_path.write_text(original, encoding="utf-8")
        inject_verify_watermark(preview_path, min_date)
        updated = preview_path.read_text(encoding="utf-8")

    if updated == original:
        return "README already current; no changes.\n"

    return "".join(
        difflib.unified_diff(
            original.splitlines(keepends=True),
            updated.splitlines(keepends=True),
            fromfile=str(readme_path),
            tofile=f"{readme_path} (refreshed)",
        )
    )


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    docs_root = Path(args.docs_root)
    readme_path = Path(args.readme)

    if not readme_path.is_file():
        print(f"ERROR: README not found: {readme_path}", file=sys.stderr)
        return EXIT_FATAL

    if not docs_root.is_dir():
        print(f"WARNING: docs directory not found, skipping: {docs_root}", file=sys.stderr)
        return EXIT_RECOVERABLE_SKIP

    if _markdown_count(docs_root) == 0:
        print(f"WARNING: no Markdown docs found under {docs_root}, skipping.", file=sys.stderr)
        return EXIT_RECOVERABLE_SKIP

    scan_result = find_min_verified_date(docs_root)
    min_date = scan_result["min_date"]
    entries = scan_result["entries"]

    if not min_date:
        print(f"WARNING: no valid verified lines found under {docs_root}, skipping.", file=sys.stderr)
        return EXIT_RECOVERABLE_SKIP

    if args.dry_run:
        print(f"DRY-RUN: scanned {len(entries)} verified line(s); min_date={min_date}")
        print(_render_preview(readme_path, min_date), end="")
        return EXIT_SUCCESS

    changed = inject_verify_watermark(readme_path, min_date)
    status = "updated" if changed else "already current"
    print(f"README {status}: {readme_path} (min_date={min_date}, verified_lines={len(entries)})")
    return EXIT_SUCCESS


if __name__ == "__main__":
    raise SystemExit(main())
