#!/usr/bin/env bash
# model-routing.sh — single source of truth for model-class routing (v4.7.0).
# Spec: docs/superpowers/specs/2026-07-15-model-routing-design.md
#
# The EFFECTIVE mechanism is the `model:` / `effort:` frontmatter in each
# SKILL.md (Claude Code applies it for the rest of the turn). This table
# documents the intended assignment; tests/validate-skills.sh enforces that
# frontmatter and table never drift apart. Real model names live ONLY here
# and in frontmatter — never in skill prose.
#
# Classes:
#   deterministic  no model — scripts only (preprocess_state.py, thresholds, ...)
#   cheap-read     haiku  — read-only tasks; UNUSED in release 1 (reserved for
#                           the phase-2 fork read path; haiku has a 200k window)
#   cheap-write    sonnet — routine skills that write through existing gates
#   standard       inherit session model (no frontmatter field)
#   strong         inherit session model (no frontmatter field)
#
# Usage:
#   bash scripts/model-routing.sh list         # TSV: skill<TAB>class<TAB>model<TAB>effort
#   bash scripts/model-routing.sh list-agents  # TSV: agent<TAB>class<TAB>model<TAB>effort
# "-" means: no frontmatter field (inherit). Exit 0; unknown command exit 2.
set -u
cmd="${1:-list}"
case "$cmd" in
  list)
    printf 'wrap-up\tcheap-write\tsonnet\tmedium\n'
    printf 'session-bootstrap\tcheap-write\tsonnet\tlow\n'
    printf 'memory-maintenance\tcheap-write\tsonnet\tlow\n'
    printf 'iteration-logger\tcheap-write\tsonnet\tlow\n'
    printf 'sync-context\tcheap-write\tsonnet\tlow\n'
    printf 'obsidian-sync\tcheap-write\tsonnet\tmedium\n'
    printf 'context-keeper\tstandard\t-\t-\n'
    printf 'pattern-extractor\tstandard\t-\t-\n'
    printf 'self-improve\tstrong\t-\t-\n'
    ;;
  list-agents)
    printf 'context-detective\tcheap-write\tsonnet\tmedium\n'
    ;;
  *)
    echo "usage: model-routing.sh [list|list-agents]" >&2
    exit 2
    ;;
esac
exit 0
