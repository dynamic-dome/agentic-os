import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from tools.verified_scanner import find_min_verified_date


class VerifiedScannerTests(unittest.TestCase):
    def test_finds_min_date_across_markdown_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.md").write_text("title\nverified: 2026-06-12\n", encoding="utf-8")
            nested = root / "nested"
            nested.mkdir()
            (nested / "b.md").write_text("  verified:2026-05-01\n", encoding="utf-8")
            (nested / "c.txt").write_text("verified: 2020-01-01\n", encoding="utf-8")

            result = find_min_verified_date(root)

            self.assertEqual(result["min_date"], "2026-05-01")
            self.assertEqual(
                result["entries"],
                [
                    {"file": "a.md", "date": "2026-06-12"},
                    {"file": "nested/b.md", "date": "2026-05-01"},
                ],
            )

    def test_accepts_spacing_variants(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "variants.md").write_text(
                "\n".join(
                    [
                        "verified:2026-02-03",
                        "  verified : 2026-01-02",
                        "\tverified:   2026-03-04",
                    ]
                ),
                encoding="utf-8",
            )

            result = find_min_verified_date(root)

            self.assertEqual(result["min_date"], "2026-01-02")
            self.assertEqual(len(result["entries"]), 3)

    def test_empty_directory_has_no_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = find_min_verified_date(tmp)

            self.assertEqual(result, {"min_date": "", "entries": []})

    def test_no_verified_lines_has_no_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "note.md").write_text("verified by reviewer\n", encoding="utf-8")

            result = find_min_verified_date(root)

            self.assertEqual(result, {"min_date": "", "entries": []})

    def test_malformed_dates_are_ignored_without_exception(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "bad.md").write_text(
                "\n".join(
                    [
                        "verified: yesterday",
                        "verified: 2026-99-99",
                        "verified: 2026-02-30",
                    ]
                ),
                encoding="utf-8",
            )

            result = find_min_verified_date(root)

            self.assertEqual(result, {"min_date": "", "entries": []})

    def test_docs_root_can_come_from_env_var(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "env.md").write_text("verified: 2026-04-05\n", encoding="utf-8")

            with patch.dict("os.environ", {"VERIFIED_SCANNER_DOCS_ROOT": str(root)}):
                result = find_min_verified_date()

            self.assertEqual(result["min_date"], "2026-04-05")
            self.assertEqual(result["entries"], [{"file": "env.md", "date": "2026-04-05"}])


if __name__ == "__main__":
    unittest.main()
