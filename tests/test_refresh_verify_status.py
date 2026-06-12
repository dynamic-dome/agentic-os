import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from tools.refresh_verify_status import EXIT_RECOVERABLE_SKIP, EXIT_SUCCESS, main


def _run_main_silently(args):
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        exit_code = main(args)
    return exit_code, stdout.getvalue(), stderr.getvalue()


class RefreshVerifyStatusTests(unittest.TestCase):
    def test_updates_readme_from_temp_repo_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            docs = repo / "docs"
            docs.mkdir()
            (repo / "README.md").write_text("# Project\n\nBody\n", encoding="utf-8")
            (docs / "a.md").write_text("---\nverified: 2026-06-10\n---\n", encoding="utf-8")
            nested = docs / "nested"
            nested.mkdir()
            (nested / "b.md").write_text("verified: 2026-05-01\n", encoding="utf-8")

            exit_code, _stdout, _stderr = _run_main_silently(
                ["--docs-root", str(docs), "--readme", str(repo / "README.md")]
            )

            self.assertEqual(exit_code, EXIT_SUCCESS)
            self.assertEqual(
                (repo / "README.md").read_text(encoding="utf-8"),
                "# Project\n<!-- Doku verifiziert bis: 2026-05-01 -->\n\nBody\n",
            )

    def test_dry_run_previews_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            docs = repo / "docs"
            docs.mkdir()
            readme = repo / "README.md"
            original = "# Project\n\nBody\n"
            readme.write_text(original, encoding="utf-8")
            (docs / "a.md").write_text("verified: 2026-06-10\n", encoding="utf-8")

            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = main(["--dry-run", "--docs-root", str(docs), "--readme", str(readme)])

            self.assertEqual(exit_code, EXIT_SUCCESS)
            self.assertEqual(readme.read_text(encoding="utf-8"), original)
            self.assertIn("+<!-- Doku verifiziert bis: 2026-06-10 -->", stdout.getvalue())

    def test_missing_docs_is_recoverable_skip(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            readme = repo / "README.md"
            readme.write_text("# Project\n", encoding="utf-8")

            exit_code, _stdout, _stderr = _run_main_silently(
                ["--docs-root", str(repo / "docs"), "--readme", str(readme)]
            )

            self.assertEqual(exit_code, EXIT_RECOVERABLE_SKIP)

    def test_no_verified_lines_is_recoverable_skip(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            docs = repo / "docs"
            docs.mkdir()
            readme = repo / "README.md"
            readme.write_text("# Project\n", encoding="utf-8")
            (docs / "note.md").write_text("not verified yet\n", encoding="utf-8")

            exit_code, _stdout, _stderr = _run_main_silently(
                ["--docs-root", str(docs), "--readme", str(readme)]
            )

            self.assertEqual(exit_code, EXIT_RECOVERABLE_SKIP)


if __name__ == "__main__":
    unittest.main()
