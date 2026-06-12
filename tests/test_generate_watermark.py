import tempfile
import unittest
from pathlib import Path

from tools.generate_watermark import inject_verify_watermark


class GenerateWatermarkTests(unittest.TestCase):
    def test_injects_watermark_after_h1_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text("# Project\n\nBody\n", encoding="utf-8")

            changed_first = inject_verify_watermark(readme, "2026-05-01")
            first_output = readme.read_text(encoding="utf-8")
            changed_second = inject_verify_watermark(readme, "2026-05-01")
            second_output = readme.read_text(encoding="utf-8")

            self.assertTrue(changed_first)
            self.assertFalse(changed_second)
            self.assertEqual(first_output, second_output)
            self.assertEqual(
                first_output,
                "# Project\n<!-- Doku verifiziert bis: 2026-05-01 -->\n\nBody\n",
            )

    def test_updates_existing_watermark_for_different_min_dates(self):
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text("# Project\n<!-- Doku verifiziert bis: 2026-05-01 -->\n\nBody\n", encoding="utf-8")

            changed = inject_verify_watermark(readme, "2026-04-15")
            output = readme.read_text(encoding="utf-8")

            self.assertTrue(changed)
            self.assertIn("<!-- Doku verifiziert bis: 2026-04-15 -->", output)
            self.assertNotIn("2026-05-01", output)
            self.assertEqual(output.count("Doku verifiziert bis:"), 1)

    def test_collapses_duplicate_watermarks_to_single_canonical_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text(
                "\n".join(
                    [
                        "# Project",
                        "<!-- Doku verifiziert bis: 2026-05-01 -->",
                        "",
                        "Body",
                        "<!-- Doku verifiziert bis: 2026-04-01 -->",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            inject_verify_watermark(readme, "2026-03-20")
            output = readme.read_text(encoding="utf-8")

            self.assertEqual(output.count("Doku verifiziert bis:"), 1)
            self.assertEqual(
                output.splitlines()[1],
                "<!-- Doku verifiziert bis: 2026-03-20 -->",
            )

    def test_inserts_at_top_when_readme_has_no_h1(self):
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text("Body\n", encoding="utf-8")

            inject_verify_watermark(readme, "2026-05-01")

            self.assertEqual(
                readme.read_text(encoding="utf-8"),
                "<!-- Doku verifiziert bis: 2026-05-01 -->\nBody\n",
            )

    def test_rejects_non_canonical_date_format(self):
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text("# Project\n", encoding="utf-8")

            with self.assertRaises(ValueError):
                inject_verify_watermark(readme, "20260501")


if __name__ == "__main__":
    unittest.main()
