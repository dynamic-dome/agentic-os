#!/bin/bash
# Initialize global cross-project memory store
# Location: ~/.claude-memory/global/
# Cross-platform: Use this on macOS/Linux. For Windows, use init-global-memory.ps1

GLOBAL_DIR="$HOME/.claude-memory/global"

mkdir -p "$GLOBAL_DIR"

# Initialize files only if they don't exist
if [ ! -f "$GLOBAL_DIR/patterns.json" ]; then
  echo '[]' > "$GLOBAL_DIR/patterns.json"
fi

if [ ! -f "$GLOBAL_DIR/learnings.json" ]; then
  echo '[]' > "$GLOBAL_DIR/learnings.json"
fi

if [ ! -f "$GLOBAL_DIR/projects.json" ]; then
  echo '{"projects": []}' > "$GLOBAL_DIR/projects.json"
fi

if [ ! -f "$GLOBAL_DIR/agent-profile.json" ]; then
  cat > "$GLOBAL_DIR/agent-profile.json" << 'EOF'
{
  "initialized": null,
  "total_sessions": 0,
  "total_iterations": 0,
  "preferred_patterns": [],
  "common_errors": [],
  "stack_experience": {}
}
EOF
fi

echo "Global memory initialized at $GLOBAL_DIR"
