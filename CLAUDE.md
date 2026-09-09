# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agentic OS v5.0.2 — a Claude Code plugin providing a persistent agent memory system. It installs skills, hooks, agents, and commands that persist project knowledge across sessions in `.agent-memory/`.

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
hooks/hooks.json           → 2 command hooks (SessionStart briefing via additionalContext, PostToolUse dirty-tracker) — no prompt hooks (4.21.0)
skills/*/SKILL.md          → 5 skills with YAML frontmatter (trigger phrases, descriptions)
agents/*.md                → 1 active agent (context-detective)
commands/*.md              → 6 slash commands (init, status, memory-audit, maintain, log, sync-context) — KEIN Command darf einen Skill-Namen tragen (Skill-Tool-Schatten/Loop, L17; Test erzwingt das)
_archived/                 → retired components (self-improve, rollback, auto-commit, improvements/) — not loaded; revive via git mv
scripts/                   → Hook helpers + SSoT scripts (session-start.sh, mem-schema.sh, memory-thresholds.sh = Threshold-SSoT, model-routing.sh = Modellklassen-SSoT, preprocess_state.py = Stufe-0-Zustandsobjekt, cost-trace.sh = Kontext-Kostentrace, learnings_top.py = Salience-Ranking, pretooluse-shell-circuit-breaker.sh, posttooluse-dirty-tracker.py = Dirty-State-SSoT, apply_wrapup.py = wrap-up Batch-Writer + Tally-SSoT, extract_patterns.py = deterministische Pattern-Detektion + einziger patterns.*-Writer)
```

**Skills (5, layered):**
- **Core** (session-bootstrap, wrap-up, context-keeper): Session lifecycle, decisions of record. wrap-up Step 6 is the sole producer of identity growth (candidate queues → user.md/soul-candidates.md, mandatory status line); session-bootstrap Step 6.5 is the consumer (explicit `[j/n]` gates).
- **Analysis** (pattern-extractor): pattern catalog via `scripts/extract_patterns.py`; generates skills from confirmed skill candidates (absorbed skill-generator in v4.0.0).
- **Knowledge** (obsidian-sync): Write-path to the Obsidian wiki

**Commands with a script core (v5.0.0):** `/agentic-os:maintain` (ex memory-maintenance), `/agentic-os:log` (ex iteration-logger), `/agentic-os:sync-context` (ex sync-context) — slash-only via `disable-model-invocation: true` (a command file is otherwise Skill-tool-resolvable and its description loads into every prompt; a validate-plugin test enforces the flag), never called from wrap-up.

**Removed in v4.0.0:** skills retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (folded into pattern-extractor); agent quality-gate; wrapper commands log, patterns, research, sync, run-loop. Scaling thresholds live ONLY in `scripts/memory-thresholds.sh` (exit 10 = exceeded). **Archived in v5.0.0:** self-improve, rollback, auto-commit, improvements/ → `_archived/`.

See `skills/DEPENDENCIES.md` for the full dependency graph and data flow.

## Key Conventions

- **Language policy:** Trigger phrases in SKILL.md frontmatter MUST be English (tests enforce this). Body text English. User-facing communication in German.
- **SKILL.md format:** YAML frontmatter with `name`, `description` (used for matching — be specific), `type: skill`, trigger phrases. Body is the skill prompt.
- **Memory dir:** Skills read/write `.agent-memory/` in the target project (not this repo). `session-bootstrap` is read-only, with ONE exception: the user-confirmed soul.md candidate gate (Step 6.5) writes soul.md only on an explicit `j` (never autonomously — Stufe-B growth, v3.3.0).
- **Hooks (4.21.0):** two command hooks only. SessionStart (15s) auto-inits and injects the briefing as `hookSpecificOutput.additionalContext` — a top-level `systemMessage` is user-only and the model never saw it (measured 2.1.263; the briefing was invisible for months). PostToolUse (5s, Write/Edit matcher) mechanically tracks un-consolidated work in working/dirty-<sid>.json (fail-soft, never blocks). The prompt hooks were removed because they could not act: SessionEnd hooks cannot invoke skills, PreCompact output is compacted away, UserPromptSubmit prompt hooks cost a model call per prompt and inject nothing on approve. A skipped wrap-up surfaces as a RECOVERY line at the next SessionStart (which also fires after `/compact`). (Legacy Stop hook removed v3.1.1; SubagentStop 4.15.0; PreToolUse circuit breaker 4.19.0 → user-level block_destructive.)
- **Invocation path decides the model (measured 2026-09-08, 2.1.263, 4 transcripts):** `/agentic-os:wrap-up` as a slash command runs the skill's calls on the declared class (`claude-sonnet-5`, 2/2); `Skill(agentic-os:wrap-up)` via the Skill tool keeps the session model (`claude-fable-5-1`, 2/2). D-009 ("frontmatter is a no-op") holds only for the Skill-tool path. Always invoke the bracket skills via slash commands; the SessionStart briefing says so.
- **MCP-Tool-Bridge Policy (2026-04-30):** MCPs have 3 legitimate roles (tool execution, introspection, knowledge access) and 4 hard no-gos: do NOT replace `.agent-memory/`, do NOT replace `~/wiki/`, MCP-output is NEVER auto-truth, no uncontrolled cross-project mutation. Full policy: `~/wiki/wiki/concepts/mcp-tool-bridge-policy.md`. NotebookLM operations always prefer the user-skill `notebooklm` (notebooklm-py CLI) over the plugin-MCP variant — plugin-MCP is fallback for subagent contexts only.
- **Model-Routing Policy (v4.7.0, status 2026-07-27):** Routine skills *declare* the cheap-write class (`model: sonnet` frontmatter), but **the frontmatter is a measured no-op** — Claude Code (2.1.215 and 2.1.220) keeps the session model when a skill is invoked via the Skill tool. Never assume a skill "ran on sonnet" when reasoning about cost or safety. Evidence + probe procedure: header of `scripts/model-routing.sh` and `docs/model-routing-eval-checklist.md`. The class table lives ONLY in `scripts/model-routing.sh` (SSoT — the validate-skills test enforces frontmatter↔table consistency, which by construction cannot detect the no-op). wrap-up/session-bootstrap run stage-0 preprocessing (`scripts/preprocess_state.py`) first and obey the (context-diet)/(bootstrap-fast-path) rules; conflicts, identity changes, decision replacements, and pattern-to-skill promotions are never resolved on the cheap class — they escalate via `working/escalations-<sid>.json` + `ESKALATION:` marker to the session model. Run costs are traced to `.agent-memory/metrics/cost-trace.jsonl` (estimates). Design: `docs/superpowers/specs/2026-07-15-model-routing-design.md`, manual evals: `docs/model-routing-eval-checklist.md`.
- **wrap-up write path (4.16.0, widened 4.18.0):** every file mutation goes through `scripts/apply_wrapup.py` — one write plan in, measured tally out — never one Write/Edit turn per file. The script owns the deterministic rules (id assignment, exact-text dedup, the promotion rule, changelog-before-edit ordering, `learnings.md` regeneration, consolidation marker, dirty flags) and enforces the conversation-only trust boundary on enqueue **and** on promotion. It skips the marker on any failure so a crashed run stays visibly dirty. Plan schema: `skills/wrap-up/references/wrapup-schemas.md` §Write plan.
- **Delegation rebuild (T-015, 4.18.0):** wrap-up no longer invokes `iteration-logger`, `context-keeper` or `pattern-extractor` on the routine path — a skill-body injection was followed by a full prefix-cache rewrite in 41% of measured cases (L34/D-010), and those bodies were almost entirely mechanical rules. They now live in code: `iterations`/`decisions` are plan sections of `apply_wrapup.py`, and pattern detection is `scripts/extract_patterns.py` (`--update` applies what is determined and proposes unnamed clusters; `--apply` takes wording only — evidence/occurrences/confidence come from the measurement and cannot be set by the caller). **Ownership moved, it did not loosen:** `iteration-log.md`, `errors.json`, `current-session.json` and `decisions.json` are reachable only through their named applier (`APPLIER_OWNED`), `patterns.*` and `soul.md` stay refused. The three skills remain the entry point when called directly. The DoD is the *skill-invocation budget per wrap-up run*: declared invokes 5 → 3 (pattern-extractor conditional, obsidian-sync, memory-maintenance conditional), and on a typical run 4 → 1 because only obsidian-sync fires unconditionally. Enforced by the `wrap-up delegation budget` test in `validate-plugin.sh` — not the rewrite count, whose expected effect (~1.2) is smaller than the run-to-run noise. Since v5.0.0 memory-maintenance is not invoked either — wrap-up Step 9 only recommends `/agentic-os:maintain`.
- **ID formats are detected, never assumed:** the real stores drifted from their documented templates (`err-007` vs. the promised `E{n}`, `D-008` vs. `D{n}`, `## {date} — {type}: {title}` vs. the promised `## Iteration #{n}`). Both scripts continue the dominant on-disk format instead of the template, so a single outlier (`G-pattern-005` among `P0nn`) cannot fork the sequence.
- **Cost reasoning (measured 2026-07-20/27):** a wrap-up run cost $15.50 over 28 API calls — 94% context transport, 6% output. The model is stateless, so cost is the SUM of context length over calls; each extra turn buys another full resend. When measuring from transcripts, `usage` is per API response but records are per content block — **deduplicate by `message.id`** or you overcount ~2.8x.
- **No circular dependencies** between skills — strict DAG.
- **Deprecated agents:** `improvement-scout`/`fix-reviewer` (removed 2026-04-30), `quality-gate` (v4.0.0), `improvement-agent`/`research-agent` (4.15.0; a validate-plugin test enforces their absence). The `agents/` directory contains 1 active agent (context-detective).

## Testing Gotchas

- Skill trigger phrases must be English or tests fail
- `description` in SKILL.md frontmatter may use multiline YAML (`>`), so simple grep won't work — use `awk` for extraction
- `validate-skills.sh` checks frontmatter structure, trigger uniqueness, and dependency declarations
- **Agent/Skill deletions must propagate to `validate-plugin.sh`** — several tests reference agent files by name (e.g. `agents/<name>.md`). Deleting a deprecated agent without updating its tests leaves the suite silently red. When removing an agent, grep `tests/` for its name and re-point tests to the successor (2026-05-25: `improvement-scout` → `improvement-agent`/`self-improve`).
