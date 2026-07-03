#!/usr/bin/env bash
# PreToolUse circuit breaker for shell commands.
# Exit 2 blocks the tool call in Claude Code.

set -u

payload="$(cat)"

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "Agentic OS PreToolUse circuit breaker: python runtime not found; allowing command." >&2
  exit 0
fi

printf '%s' "$payload" | "$python_bin" -c '
import json
import re
import sys


def extract_command(payload):
    try:
        data = json.loads(payload or "{}")
    except json.JSONDecodeError:
        return None, None

    tool_name = data.get("tool_name") or data.get("tool") or data.get("name")
    tool_input = data.get("tool_input") or data.get("input") or data
    if isinstance(tool_input, dict):
        command = tool_input.get("command") or tool_input.get("cmd")
    else:
        command = None
    return tool_name, command


def normalize(command):
    command = command.replace("\\\n", " ")
    command = command.replace("\r", "\n")
    command = re.sub(r"\s+", " ", command)
    return command.strip()


RULES = [
    (
        "recursive forced deletion",
        re.compile(r"(?i)(^|[;&|]\s*)(sudo\s+)?rm\s+-[A-Za-z-]*r[A-Za-z-]*f[A-Za-z-]*\b"),
    ),
    (
        "PowerShell recursive forced deletion",
        re.compile(r"(?i)\b(remove-item|rm|del|erase|rd|rmdir)\b[^;&|]*-(recurse|r)\b[^;&|]*-(force|fo)\b"),
    ),
    (
        "hard git reset",
        re.compile(r"(?i)(^|[;&|]\s*)git\s+reset\s+--hard\b"),
    ),
    (
        "forced git clean",
        re.compile(r"(?i)(^|[;&|]\s*)git\s+clean\b(?=[^;&|]*-[^\s;&|]*f)(?=[^;&|]*-[^\s;&|]*d)"),
    ),
    (
        "world-writable recursive chmod",
        re.compile(r"(?i)(^|[;&|]\s*)chmod\s+-R\s+777\b"),
    ),
    (
        "recursive ownership change",
        re.compile(r"(?i)(^|[;&|]\s*)(sudo\s+)?chown\s+-R\b"),
    ),
    (
        "remote script pipe execution",
        re.compile(r"(?i)\b(curl|wget)\b[^|;&]*\|\s*(sudo\s+)?(sh|bash)\b"),
    ),
    (
        "PowerShell download cradle execution",
        re.compile(r"(?i)\b(iwr|irm|invoke-webrequest|invoke-restmethod)\b[^|;&]*\|\s*(iex|invoke-expression)\b"),
    ),
    (
        "disk formatting or partitioning",
        # format(?!-...): der DOS-Datentraeger-Befehl `format C:` bleibt geblockt,
        # aber die benignen PowerShell-Ausgabe-Cmdlets Format-Table/List/Wide/
        # Custom/Hex nicht (T-17 False Positive). Format-Volume bleibt geblockt.
        re.compile(r"(?i)(^|[;&|]\s*)(mkfs(\.[A-Za-z0-9_+-]+)?|diskpart|format(?!-(?:table|list|wide|custom|hex)\b))\b"),
    ),
    (
        "raw disk write",
        re.compile(r"(?i)(^|[;&|]\s*)dd\b(?=[^;&|]*\bof=/dev/)"),
    ),
    (
        "system shutdown or reboot",
        re.compile(r"(?i)(^|[;&|]\s*)(shutdown|reboot|halt|poweroff)\b"),
    ),
]


payload = sys.stdin.read()
tool_name, command = extract_command(payload)
if tool_name and str(tool_name).lower() not in {"bash", "shell", "shell_command"}:
    sys.exit(0)

if not isinstance(command, str) or not command.strip():
    sys.exit(0)

normalized = normalize(command)
for label, pattern in RULES:
    if pattern.search(normalized):
        print(
            f"Agentic OS PreToolUse circuit breaker blocked shell command: {label}",
            file=sys.stderr,
        )
        sys.exit(2)

sys.exit(0)
'
