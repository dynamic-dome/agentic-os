#!/usr/bin/env bash
# cost-trace.sh — append-only context/cost trace for routed memory tasks (v4.7.0).
# Spec: docs/superpowers/specs/2026-07-15-model-routing-design.md section 3.6
#
# est_input_tokens = context_bytes / 4. This is an ESTIMATE ("estimate":true):
# Claude Code exposes no real per-run token counts to skills; we trace what is
# deterministically measurable (bytes of files actually read, model class,
# escalation flag). Real token baselines require external telemetry (OTEL).
#
# Fail-soft contract: NEVER exits non-zero, never blocks a skill run.
# Usage:
#   bash scripts/cost-trace.sh append --mem .agent-memory --task wrap-up \
#     --class cheap-write --context-bytes 12345 --escalated 0
set -u

cmd="${1:-}"
shift 2>/dev/null || true

MEM=".agent-memory"
TASK="unknown"
CLASS="unknown"
BYTES="0"
ESC="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mem)            MEM="${2:-.agent-memory}"; shift 2 ;;
    --task)           TASK="${2:-unknown}"; shift 2 ;;
    --class)          CLASS="${2:-unknown}"; shift 2 ;;
    --context-bytes)  BYTES="${2:-0}"; shift 2 ;;
    --escalated)      ESC="${2:-0}"; shift 2 ;;
    *) shift ;;
  esac
done

if [ "$cmd" != "append" ]; then
  echo "usage: cost-trace.sh append --mem DIR --task NAME --class CLASS --context-bytes N --escalated 0|1" >&2
  exit 0  # fail-soft: even usage errors must not break a skill run
fi

# sanitize numerics (non-numeric -> 0) and enum-ish strings (strip quotes/backslashes)
case "$BYTES" in (*[!0-9]*|"") BYTES=0 ;; esac
case "$ESC" in (0|1) : ;; (*) ESC=0 ;; esac
TASK=$(printf '%s' "$TASK" | tr -d '"\\' | cut -c1-64)
CLASS=$(printf '%s' "$CLASS" | tr -d '"\\' | cut -c1-32)
TOKENS=$((BYTES / 4))
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

{
  mkdir -p "$MEM/metrics" &&
  printf '{"ts":"%s","task_type":"%s","model_class":"%s","context_bytes":%s,"est_input_tokens":%s,"escalated":%s,"estimate":true}\n' \
    "$TS" "$TASK" "$CLASS" "$BYTES" "$TOKENS" "$ESC" >> "$MEM/metrics/cost-trace.jsonl"
} 2>/dev/null || echo "cost-trace: append skipped (unwritable $MEM)" >&2

exit 0
