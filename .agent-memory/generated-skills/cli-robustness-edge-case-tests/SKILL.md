---
name: cli-robustness-edge-case-tests
description: >
  Edge-case test matrix for scripts with robustness contracts (fail-soft,
  always-exit-0, JSONL integrity). Use when writing or reviewing a CLI script
  that promises graceful degradation, when adding a fail-soft contract, or
  before trusting a green happy-path suite. Trigger phrases: "fail-soft test",
  "cli robustness", "edge case matrix", "test the contract", "robustness check".
type: skill
---

# CLI Robustness Edge-Case Tests

## When to Use

A script declares a robustness contract (never exits non-zero, always emits
parseable output, never hangs) and the existing tests only cover happy paths.
Evidence base: 4 real contract-breaking bugs in one release (err-005..err-008,
agentic-os v4.7.0, single-session evidence — re-confirm across sessions).

## Steps

1. Malformed/unknown args: assert exit code AND stdout purity (argparse calls
   sys.exit(2) and prints help BEFORE SystemExit(0) on -h — handle e.code 0 vs non-zero).
2. Trailing flag without value: assert termination via a timeout-wrapped call
   (bash `shift 2` with 1 remaining arg consumes nothing -> infinite loop; guard
   with [ "$#" -ge 2 ] && shift 2 || shift).
3. --help: assert pure help text, no data output mixed into stdout.
4. Control-char/newline injection into field values: assert record integrity
   (whitelist sanitization `tr -cd 'A-Za-z0-9._:-'`, never blacklist).
5. Non-ASCII content with piped stdout on Windows: assert no UnicodeEncodeError
   (sys.stdout.reconfigure(encoding="utf-8") at entry; test in bytes mode so
   errors="replace" cannot mask the crash).

## What NOT to Do

- Do NOT trust a green suite whose fixtures are ASCII-only happy paths.
- Do NOT sanitize JSONL fields with a blacklist (control chars pass through).
- Do NOT use unguarded `shift 2` in bash arg loops.
- Do NOT catch SystemExit without distinguishing the help path (e.code 0).
