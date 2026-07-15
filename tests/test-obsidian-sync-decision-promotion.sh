#!/bin/bash
# Contract test: obsidian-sync Step 4.5 Decision Promotion (v4.5.0).
#
# decisions.json is the LEADING store; the wiki only receives a projection.
# The promotion marker (wiki_ref + promoted_at) must be documented on BOTH
# writers (obsidian-sync batch path, context-keeper live path) — otherwise
# the same decision gets projected twice.

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OBSIDIAN_SYNC="$ROOT_DIR/skills/obsidian-sync/SKILL.md"
CONTEXT_KEEPER="$ROOT_DIR/skills/context-keeper/SKILL.md"

fail() {
    echo "FAIL: $1"
    exit 1
}

grep -q "Step 4.5: Decision Promotion" "$OBSIDIAN_SYNC" \
    || fail "obsidian-sync must carry a Step 4.5 Decision Promotion section"

for token in \
    "wiki_ref" \
    "promoted_at" \
    "architecture-decision" \
    "stack-change" \
    "scope-decision" \
    "wiki/entities/{project_id}.md" \
    "Architecture Decisions" \
    "supersedes"
do
    grep -q -- "$token" "$OBSIDIAN_SYNC" \
        || fail "obsidian-sync decision promotion must mention $token"
done

# Leading-store direction must be stated (projection, never reverse).
# Token kept single-line safe: SKILL.md prose wraps lines, grep is line-based.
grep -qi "only ever receives a projection" "$OBSIDIAN_SYNC" \
    || fail "obsidian-sync must state the projection direction (decisions.json leads)"

# Stale reference from pre-1.2 must be gone (context-keeper has no Step 4.5)
grep -q "context-keeper Step 4.5" "$OBSIDIAN_SYNC" \
    && fail "obsidian-sync still references non-existent context-keeper Step 4.5"

# The live-path counterpart must document the shared marker
grep -q "wiki_ref" "$CONTEXT_KEEPER" \
    || fail "context-keeper Step 3.5 must document the wiki_ref promotion marker"
grep -q "obsidian-sync Step 4.5" "$CONTEXT_KEEPER" \
    || fail "context-keeper must cross-reference obsidian-sync Step 4.5"

echo "Obsidian-sync decision promotion contract passed."
