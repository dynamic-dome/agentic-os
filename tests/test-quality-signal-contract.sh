#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/quality-gate/SKILL.md"

grep -q "analysis/quality_signal.py" "$SKILL"
grep -q "schema_v 1" "$SKILL"
grep -q "success_rate" "$SKILL"
grep -q "failures" "$SKILL"
grep -qi "fail-soft" "$SKILL"
