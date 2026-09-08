#!/usr/bin/env bash
# session-start.sh must never auto-init a .agent-memory INSIDE an existing .agent-memory.
# cost-trace.sh must likewise refuse to create metrics/ inside a nested .agent-memory cwd.
set -uo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
mkdir -p "$TMP/proj/.agent-memory/working"
cd "$TMP/proj/.agent-memory/working"
# session-start.sh derives PROJECT_DIR from $CLAUDE_PROJECT_DIR (NOT from stdin
# JSON's "cwd" field, which the script never reads) — set it explicitly to the
# real second start path (session-start.sh line 19) so the test hits the actual
# derivation instead of the unused "." default.
echo '{"cwd":"'"$TMP/proj/.agent-memory/working"'","session_id":"t"}' | \
  CLAUDE_PROJECT_DIR="$TMP/proj/.agent-memory/working" bash "$DIR/scripts/session-start.sh" > "$TMP/out.txt" 2>&1
RC=$?
FAIL=0
if [ -d "$TMP/proj/.agent-memory/working/.agent-memory" ] || [ -d "$TMP/proj/.agent-memory/.agent-memory" ]; then
  echo "  FAIL: nested .agent-memory created"; FAIL=1
else
  echo "  PASS: no nested .agent-memory"
fi
if [ "$RC" -eq 0 ]; then echo "  PASS: exit 0 (fail-soft)"; else echo "  FAIL: exit $RC"; FAIL=1; fi

# Second case: cost-trace.sh run from a cwd inside .agent-memory must not create
# a nested metrics/ dir (controller ruling: this is the actual origin of the
# nested stores found in hygiene 2026-09, not session-start.sh).
cd "$TMP/proj/.agent-memory/working"
bash "$DIR/scripts/cost-trace.sh" append --mem .agent-memory --task test --class cheap-write --context-bytes 100 --escalated 0 > "$TMP/ct-out.txt" 2>&1
if [ -d "$TMP/proj/.agent-memory/working/.agent-memory" ]; then
  echo "  FAIL: cost-trace.sh created nested .agent-memory/metrics"; FAIL=1
else
  echo "  PASS: cost-trace.sh created no nested .agent-memory"
fi

rm -rf "$TMP"
exit $FAIL
