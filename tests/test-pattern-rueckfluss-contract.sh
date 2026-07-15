#!/bin/bash
# Contract test (v4.6.0, membrain T-15/T-17 — Loop-8 Rosinen 1, 3, 4):
# the pattern feedback loop ("Rueckfluss") must be documented end-to-end:
#   1. pattern-extractor: canonical schema carries implemented_by/validated_by
#      + a delta-draft gate for changes to EXISTING components (no auto-change).
#   2. obsidian-sync Step 6: promotion_scope (project|global) derived from
#      source_projects — scope gate before any wiki promotion.
#   3. memory-audit: findings labeled with the gap taxonomy (7 classes)
#      + the late-filter diagnosis rule.

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRACTOR="$ROOT_DIR/skills/pattern-extractor/SKILL.md"
OBSIDIAN="$ROOT_DIR/skills/obsidian-sync/SKILL.md"
AUDIT="$ROOT_DIR/commands/memory-audit.md"

fail() {
    echo "FAIL: $1"
    exit 1
}

# --- 1. pattern-extractor: schema fields + delta-draft gate -----------------

grep -q '"implemented_by"' "$EXTRACTOR" \
    || fail "pattern-extractor template must carry implemented_by"

grep -q '"validated_by"' "$EXTRACTOR" \
    || fail "pattern-extractor template must carry validated_by"

grep -q 'rueckfluss-delta-gate' "$EXTRACTOR" \
    || fail "pattern-extractor must carry the rueckfluss-delta-gate anchor"

for token in \
    "Affected component" \
    "Observed problem" \
    "Proposed change" \
    "Acceptance check"
do
    grep -q "$token" "$EXTRACTOR" \
        || fail "pattern-extractor delta draft must contain field: $token"
done

# Gate semantics: never auto-modify, implemented_by only after the change landed,
# validated_by only from evidence AFTER implementation (effect check).
grep -qi "do NOT modify the target component" "$EXTRACTOR" \
    || fail "pattern-extractor gate must forbid auto-modifying existing components"

grep -q "only after the change has landed" "$EXTRACTOR" \
    || fail "pattern-extractor must bind implemented_by to a landed change"

grep -q "dated AFTER implemented_by" "$EXTRACTOR" \
    || fail "pattern-extractor must bind validated_by to post-implementation evidence"

# Provenance chain must be stated (closes the loop from iteration to validation)
grep -q "derived_from.*evidence.*implemented_by.*validated_by" "$EXTRACTOR" \
    || fail "pattern-extractor must document the full provenance chain"

# --- 2. obsidian-sync: promotion scope gate ---------------------------------

grep -q '"promotion_scope"' "$OBSIDIAN" \
    || fail "obsidian-sync Step 6 must set promotion_scope"

grep -q '"promotion_scope": "global"' "$OBSIDIAN" \
    || fail "obsidian-sync must define the global promotion scope"

grep -q '"promotion_scope": "project"' "$OBSIDIAN" \
    || fail "obsidian-sync must define the project promotion scope"

grep -q 'source_projects >= 2.*"promotion_scope": "global"' "$OBSIDIAN" \
    || fail "obsidian-sync must bind global scope to source_projects >= 2"

# --- 3. memory-audit: gap taxonomy (Loop-8 Rosine 3) ------------------------

grep -q 'gap-taxonomy' "$AUDIT" \
    || fail "memory-audit must carry the gap-taxonomy anchor"

for gap in \
    "knowledge-gap" \
    "capture-gap" \
    "index-gap" \
    "retrieval-gap" \
    "link-gap" \
    "usage-gap" \
    "feedback-loop-gap"
do
    grep -q "$gap" "$AUDIT" \
        || fail "memory-audit gap taxonomy must contain class: $gap"
done

grep -qi "late filter" "$AUDIT" \
    || fail "memory-audit must state the late-filter diagnosis rule"

echo "PASS: pattern rueckfluss contract (extractor fields + delta gate, promotion scope, gap taxonomy)"
