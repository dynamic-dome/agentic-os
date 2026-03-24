#!/bin/bash
set -euo pipefail

# Agentic OS — SessionEnd Hook
# Instructs Claude to perform wrap-up including learnings, pattern extraction, and skill generation.
# Only active when .agent-memory/ exists in the project.

MEMORY_DIR="${CLAUDE_PROJECT_DIR:-.}/.agent-memory"

# No .agent-memory? → Exit silently
if [ ! -d "$MEMORY_DIR" ]; then
  cat <<'EOF'
{
  "continue": true,
  "suppressOutput": true
}
EOF
  exit 0
fi

# Gather statistics (tr -d for Windows compatibility)
iteration_count=$(grep -c "^## Iteration" "$MEMORY_DIR/iterations/iteration-log.md" 2>/dev/null | tr -d '[:space:]' || echo "0")
error_count=$(grep -c '"id"' "$MEMORY_DIR/iterations/errors.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
pattern_count=$(grep -c '"id"' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
skill_candidates=$(grep -c '"skill_candidate": true' "$MEMORY_DIR/patterns/patterns.json" 2>/dev/null | tr -d '[:space:]' || echo "0")

# Build systemMessage
msg="[Agentic OS] Session is ending. Perform wrap-up now:\n\n"
msg="${msg}1. Update session-summary.md (max 30 lines: what was done, open items, next steps)\n"
msg="${msg}2. Log all unlogged iterations to iteration-log.md\n"
msg="${msg}3. Extract learnings to learnings.md (genuine insights only, no trivial facts)\n"

if [ "${iteration_count:-0}" -ge 3 ] 2>/dev/null || [ "${error_count:-0}" -ge 3 ] 2>/dev/null; then
  msg="${msg}4. Run pattern extraction (agentic-os:pattern-extractor) — ${error_count} errors, ${iteration_count} iterations available\n"
fi

if [ "${skill_candidates:-0}" -gt 0 ] 2>/dev/null; then
  msg="${msg}5. There are ${skill_candidates} skill candidates — check whether new skills should be generated (agentic-os:skill-generator)\n"
fi

msg="${msg}\nStatistics: ${iteration_count} iterations, ${error_count} errors, ${pattern_count} patterns, ${skill_candidates} skill candidates"

# Escape for JSON
escaped_msg=$(echo -e "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"[Agentic OS] Session ended. Please perform wrap-up.\"")

cat <<EOJSON
{
  "continue": true,
  "systemMessage": $escaped_msg
}
EOJSON
