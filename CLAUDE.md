# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agentic OS v4.3.0 — a Claude Code plugin providing a self-improving agent memory system. It installs skills, hooks, agents, and commands that persist project knowledge across sessions in `.agent-memory/`.

## Build & Test

```bash
# Run all tests (plugin structure + skill validation)
bash tests/run-all.sh

# Run only plugin structure validation
bash tests/validate-plugin.sh

# Run only skill validation (frontmatter, triggers, dependencies)
bash tests/validate-skills.sh
```

No build step. No package manager. The plugin is pure Markdown + JSON + Bash.

## Architecture

```
.claude-plugin/plugin.json → Plugin manifest (name, version, description)
hooks/hooks.json           → 6 hooks (SessionStart, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, SessionEnd)
skills/*/SKILL.md          → 9 skills with YAML frontmatter (trigger phrases, descriptions)
agents/*.md                → 1 active agent (context-detective)
commands/*.md              → 5 slash commands (init, status, rollback, auto-commit, memory-audit) — KEIN Command darf einen Skill-Namen tragen (Skill-Tool-Schatten/Loop, L17; Test erzwingt das)
improvements/state.json    → Self-improve loop state tracker
scripts/                   → Hook helpers + SSoT scripts (session-start.sh, mem-schema.sh, memory-thresholds.sh = Threshold-SSoT, model-routing.sh = Modellklassen-SSoT, preprocess_state.py = Stufe-0-Zustandsobjekt, cost-trace.sh = Kontext-Kostentrace, learnings_top.py = Salience-Ranking, pretooluse-shell-circuit-breaker.sh, posttooluse-dirty-tracker.py = Dirty-State-SSoT, apply_wrapup.py = wrap-up Batch-Writer + Tally-SSoT, extract_patterns.py = deterministische Pattern-Detektion + einziger patterns.*-Writer)
```

**Skills (9, layered):**
- **Core** (session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, sync-context, memory-maintenance): Session lifecycle and memory management. pattern-extractor also generates skills from confirmed skill candidates (absorbed skill-generator in v4.0.0). wrap-up Step 6 is the sole producer of identity growth (candidate queues → user.md/soul-candidates.md, mandatory status line); session-bootstrap Step 6.5 is the consumer (explicit `[j/n]` gates).
- **Knowledge** (obsidian-sync): Write-path to the Obsidian wiki
- **Self-improve** (self-improve): Multi-iteration loop with research, analysis, improvement, validation, meta-improve, scheduling — policy-gated (siehe `skills/self-improve/SKILL.md` Self-Improve Policy)

**Removed in v4.0.0:** skills retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (folded into pattern-extractor); agent quality-gate; wrapper commands log, patterns, research, sync, run-loop. Scaling thresholds live ONLY in `scripts/memory-thresholds.sh` (exit 10 = exceeded).

See `skills/DEPENDENCIES.md` for the full dependency graph and data flow.

## Key Conventions

- **Language policy:** Trigger phrases in SKILL.md frontmatter MUST be English (tests enforce this). Body text English. User-facing communication in German.
- **SKILL.md format:** YAML frontmatter with `name`, `description` (used for matching — be specific), `type: skill`, trigger phrases. Body is the skill prompt.
- **Memory dir:** Skills read/write `.agent-memory/` in the target project (not this repo). `session-bootstrap` is read-only, with ONE exception: the user-confirmed soul.md candidate gate (Step 6.5) writes soul.md only on an explicit `j` (never autonomously — Stufe-B growth, v3.3.0).
- **Hooks:** Lightweight by design. SessionStart (15s, command) auto-inits + injects context; PreToolUse (5s, command, Bash matcher) blocks known dangerous shell commands with exit code 2 before execution; PostToolUse (5s, command, Write/Edit matcher) mechanically tracks un-consolidated work in working/dirty-<sid>.json (fail-soft, never blocks); PreCompact (15s, prompt) outputs survival summary; SessionEnd (15s, prompt) task guard + delegates to wrap-up; UserPromptSubmit (10s, prompt) advisory-only. (The legacy Stop hook was removed in v3.1.1 — infinite feedback loop; SubagentStop removed in 4.15.0 — it only matched the deleted improvement-agent.)
- **Self-improve safety:** Max 20% mutation per skill per iteration. Git revert over git stash pop. Circuit breaker on diminishing returns.
- **Self-Improve Policy (2026-04-30):** 6 hard rules in `skills/self-improve/SKILL.md` — single-cluster-rule, pattern-confirmation-threshold, wrap-up-discipline, MCP-audit-as-diagnosis-only, no-self-mod-boundary, rollback-tag-tightness. The `self-improve` skill MUST NOT modify its own SKILL.md body — meta-suggestions go to `improvements/meta-suggestions.md` for manual review.
- **MCP-Tool-Bridge Policy (2026-04-30):** MCPs have 3 legitimate roles (tool execution, introspection, knowledge access) and 4 hard no-gos: do NOT replace `.agent-memory/`, do NOT replace `~/wiki/`, MCP-output is NEVER auto-truth, no uncontrolled cross-project mutation. Full policy: `~/wiki/wiki/concepts/mcp-tool-bridge-policy.md`. NotebookLM operations always prefer the user-skill `notebooklm` (notebooklm-py CLI) over the plugin-MCP variant — plugin-MCP is fallback for subagent contexts only.
- **Model-Routing Policy (v4.7.0, status 2026-07-27):** Routine skills *declare* the cheap-write class (`model: sonnet` frontmatter), but **the frontmatter is a measured no-op** — Claude Code (2.1.215 and 2.1.220) keeps the session model when a skill is invoked via the Skill tool. Never assume a skill "ran on sonnet" when reasoning about cost or safety. Evidence + probe procedure: header of `scripts/model-routing.sh` and `docs/model-routing-eval-checklist.md`. The class table lives ONLY in `scripts/model-routing.sh` (SSoT — the validate-skills test enforces frontmatter↔table consistency, which by construction cannot detect the no-op). wrap-up/session-bootstrap run stage-0 preprocessing (`scripts/preprocess_state.py`) first and obey the (context-diet)/(bootstrap-fast-path) rules; conflicts, identity changes, decision replacements, and pattern-to-skill promotions are never resolved on the cheap class — they escalate via `working/escalations-<sid>.json` + `ESKALATION:` marker to the session model. Run costs are traced to `.agent-memory/metrics/cost-trace.jsonl` (estimates). Design: `docs/superpowers/specs/2026-07-15-model-routing-design.md`, manual evals: `docs/model-routing-eval-checklist.md`.
- **wrap-up write path (4.16.0, widened 4.18.0):** every file mutation goes through `scripts/apply_wrapup.py` — one write plan in, measured tally out — never one Write/Edit turn per file. The script owns the deterministic rules (id assignment, exact-text dedup, the promotion rule, changelog-before-edit ordering, `learnings.md` regeneration, consolidation marker, dirty flags) and enforces the conversation-only trust boundary on enqueue **and** on promotion. It skips the marker on any failure so a crashed run stays visibly dirty. Plan schema: `skills/wrap-up/references/wrapup-schemas.md` §Write plan.
- **Delegation rebuild (T-015, 4.18.0):** wrap-up no longer invokes `iteration-logger`, `context-keeper` or `pattern-extractor` on the routine path — a skill-body injection was followed by a full prefix-cache rewrite in 41% of measured cases (L34/D-010), and those bodies were almost entirely mechanical rules. They now live in code: `iterations`/`decisions` are plan sections of `apply_wrapup.py`, and pattern detection is `scripts/extract_patterns.py` (`--update` applies what is determined and proposes unnamed clusters; `--apply` takes wording only — evidence/occurrences/confidence come from the measurement and cannot be set by the caller). **Ownership moved, it did not loosen:** `iteration-log.md`, `errors.json`, `current-session.json` and `decisions.json` are reachable only through their named applier (`APPLIER_OWNED`), `patterns.*` and `soul.md` stay refused. The three skills remain the entry point when called directly. The DoD is the *skill-invocation budget per wrap-up run*: declared invokes 5 → 3 (pattern-extractor conditional, obsidian-sync, memory-maintenance conditional), and on a typical run 4 → 1 because only obsidian-sync fires unconditionally. Enforced by the `wrap-up delegation budget` test in `validate-plugin.sh` — not the rewrite count, whose expected effect (~1.2) is smaller than the run-to-run noise.
- **ID formats are detected, never assumed:** the real stores drifted from their documented templates (`err-007` vs. the promised `E{n}`, `D-008` vs. `D{n}`, `## {date} — {type}: {title}` vs. the promised `## Iteration #{n}`). Both scripts continue the dominant on-disk format instead of the template, so a single outlier (`G-pattern-005` among `P0nn`) cannot fork the sequence.
- **Cost reasoning (measured 2026-07-20/27):** a wrap-up run cost $15.50 over 28 API calls — 94% context transport, 6% output. The model is stateless, so cost is the SUM of context length over calls; each extra turn buys another full resend. When measuring from transcripts, `usage` is per API response but records are per content block — **deduplicate by `message.id`** or you overcount ~2.8x.
- **No circular dependencies** between skills — strict DAG.
- **Deprecated agents:** `improvement-scout`/`fix-reviewer` (removed 2026-04-30), `quality-gate` (v4.0.0), `improvement-agent`/`research-agent` (4.15.0 — self-improve runs all phases inline; a validate-plugin test enforces their absence). The `agents/` directory contains 1 active agent (context-detective).

## Testing Gotchas

- Skill trigger phrases must be English or tests fail
- `description` in SKILL.md frontmatter may use multiline YAML (`>`), so simple grep won't work — use `awk` for extraction
- `validate-skills.sh` checks frontmatter structure, trigger uniqueness, and dependency declarations
- **Agent/Skill deletions must propagate to `validate-plugin.sh`** — several tests reference agent files by name (e.g. `agents/<name>.md`). Deleting a deprecated agent without updating its tests leaves the suite silently red. When removing an agent, grep `tests/` for its name and re-point tests to the successor (2026-05-25: `improvement-scout` → `improvement-agent`/`self-improve`).
