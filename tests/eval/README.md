# Skill-Redesign Eval Harness (T-35)

Proves that an aggressive body cut of `session-bootstrap` (and later `wrap-up`)
preserves behavior — that no gate silently stops firing. Rationale and design:
`memevalharness.md` in the membrain repo.

**This harness is NOT part of the running memory system.** It only runs to verify
a redesign. Memory works without it.

## The redesign rule this harness enforces

> No gate logic leaves the body. Only inert material (JSON schemas, "why" prose,
> verbose detail) may move to `references/`. Every gate's trigger AND result
> contract stay in the body.

Under this rule, behavior preservation is provable deterministically (Schicht 1),
so the expensive LLM layer (Schicht 2) is optional.

## Two layers

### Schicht 1 — deterministic (CI, in `run-all.sh`)

| File | Role |
|---|---|
| `make_fixtures.py` | Generates the 5 fixture stores (run on purpose after content drift; keeps the fast-path hash correct-by-construction). |
| `fixtures/<scenario>/` | Committed `.agent-memory` stores that really trigger a gate. |
| `eval_signals.py` | Stages each fixture to a temp dir, backdates crash markers, runs the REAL scripts, asserts the gate-triggering signals. |
| `gate_linkage.py` | For each known bootstrap gate: asserts the body carries BOTH a trigger and an action token. The core anti-silent-loss check. Accepts an optional body path to check a candidate SKILL.md. |
| `run-eval.sh` | CI entry point: runs the above + the staleness notice. |

### Schicht 2 — behavioral, break-glass (on-demand, NOT in CI)

| File | Role |
|---|---|
| `capture_protocol.md` | Runbook: run the candidate body in an isolated subagent against a fixture, emit a normalized side-effect signature. |
| `check_sideeffects.py` | Diffs a captured signature against `baseline/<scenario>.json` (exact match on gates/files/questions, set match on briefing blocks). |
| `baseline/<scenario>.json` | Frozen golden signatures. Currently hand-authored (`_provenance`); replace with a real capture when first needed. |
| `staleness_check.py` | Non-fatal notice when a baseline no longer matches the current body (`_body_sha256`). |

## Scenarios

`fresh` · `fast-path` · `recovery` (stale un-consolidated codex marker) ·
`identity` (promotable user + soul candidate) · `conflict` (contradictory records).

Currently seeded for `session-bootstrap` only; `wrap-up` scenarios get added when
wrap-up is redesigned.

## Usage

```bash
bash tests/eval/run-eval.sh                 # Schicht 1 + gate-linkage + staleness
python tests/eval/make_fixtures.py          # regenerate fixtures (on purpose)
python tests/eval/gate_linkage.py <body.md> # check a candidate body before swap
# Schicht 2 (manual, before an aggressive deploy):
python tests/eval/check_sideeffects.py <scenario> <captured.json>
```

## Maintenance

- Add a real gate to bootstrap → add it to `GATES` in `gate_linkage.py` (same commit).
- Change `STATE_FILES` in `preprocess_state.py` → mirror it in `make_fixtures.py`
  (guarded by `eval_signals.py`) and regenerate fixtures.
- Intentionally change bootstrap behavior → re-capture the affected baseline.
