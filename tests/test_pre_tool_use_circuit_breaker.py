import json
import subprocess
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "pre-tool-use-circuit-breaker.sh"


def bash_path(path):
    path = path.resolve()
    if path.drive:
        drive = path.drive.rstrip(":").lower()
        return f"/mnt/{drive}{path.as_posix()[2:]}"
    return path.as_posix()


def run_hook(tool_name, command):
    payload = {
        "hook_event_name": "PreToolUse",
        "tool_name": tool_name,
        "tool_input": {"command": command},
    }
    return subprocess.run(
        ["bash", bash_path(SCRIPT)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
    )


class PreToolUseCircuitBreakerTests(unittest.TestCase):
    def test_blocks_recursive_force_delete(self):
        result = run_hook("Bash", "rm -rf /tmp/project")

        self.assertEqual(result.returncode, 2)
        self.assertIn("Blocked dangerous Bash command", result.stderr)
        self.assertIn("rm -rf", result.stderr)

    def test_blocks_git_history_destruction(self):
        result = run_hook("Bash", "git reset --hard HEAD~1")

        self.assertEqual(result.returncode, 2)
        self.assertIn("git reset --hard", result.stderr)

    def test_blocks_powershell_recursive_force_delete(self):
        result = run_hook(
            "Bash",
            'powershell -NoProfile -Command "Remove-Item -Recurse -Force C:\\\\tmp\\\\target"',
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("Remove-Item", result.stderr)

    def test_allows_safe_bash_command(self):
        result = run_hook("Bash", "git status --short")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")

    def test_ignores_non_bash_tools(self):
        result = run_hook("Read", "rm -rf /tmp/project")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
