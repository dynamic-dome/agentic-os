#!/bin/bash
# Agentic OS - PreToolUse circuit breaker.
# Blocks high-risk Bash commands before Claude Code executes them.

set +e

INPUT="$(cat)"

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Blocked dangerous Bash command: Python is required to inspect PreToolUse input." >&2
  exit 2
fi

DECISION="$(
  HOOK_INPUT="$INPUT" "$PYTHON_BIN" - <<'PY'
import json
import os
import re
import sys


def normalized(command):
    return re.sub(r"\s+", " ", command.strip()).lower()


def block_reason(command):
    checks = [
        (r"(^|[;&|(){}\s])rm\s+-(?:[a-z]*r[a-z]*f|[a-z]*f[a-z]*r)\b", "rm -rf"),
        (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
        (r"\bgit\s+clean\s+-[a-z]*[dfx][a-z]*[dfx]", "git clean -fd/-xdf"),
        (r"\bgit\s+push\b.*\s--force(?:-with-lease)?\b", "git push --force"),
        (r"\bchmod\s+(?:-[a-z]*r[a-z]*\s+)?777\b", "chmod 777"),
        (r"\bchown\s+-[a-z]*r[a-z]*\b", "chown -R"),
        (r"\bdd\s+.*\bof=/dev/", "dd to block device"),
        (r"\b(?:mkfs|format)\b", "filesystem format"),
        (r"\bremove-item\b(?=.*\s-recurse\b)(?=.*\s-force\b)", "Remove-Item -Recurse -Force"),
        (r"\b(?:del|erase)\b(?=.*\s/[sq]\b)(?=.*\s/[sq]\b)", "del /s /q"),
        (r"\b(?:rd|rmdir)\b(?=.*\s/s\b)(?=.*\s/q\b)", "rmdir /s /q"),
        (r"\b(?:curl|wget)\b.*\|\s*(?:sh|bash|powershell|pwsh)\b", "download-to-shell pipe"),
    ]
    lowered = normalized(command)
    for pattern, reason in checks:
        if re.search(pattern, lowered):
            return reason
    return ""


try:
    payload = json.loads(os.environ.get("HOOK_INPUT", ""))
except Exception:
    print("BLOCK\tmalformed PreToolUse JSON")
    sys.exit(0)

if payload.get("tool_name") != "Bash":
    print("ALLOW")
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
command = tool_input.get("command")
if not isinstance(command, str) or not command.strip():
    print("BLOCK\tmissing Bash command")
    sys.exit(0)

reason = block_reason(command)
if reason:
    print(f"BLOCK\t{reason}")
else:
    print("ALLOW")
PY
)"

case "$DECISION" in
  BLOCK$'\t'*)
    REASON="${DECISION#BLOCK	}"
    echo "Blocked dangerous Bash command: ${REASON}" >&2
    exit 2
    ;;
  ALLOW)
    exit 0
    ;;
  *)
    echo "Blocked dangerous Bash command: circuit breaker inspection failed." >&2
    exit 2
    ;;
esac
