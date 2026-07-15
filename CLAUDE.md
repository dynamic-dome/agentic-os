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
hooks/hooks.json           → 7 hooks (SessionStart, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, SessionEnd, SubagentStop)
skills/*/SKILL.md          → 9 skills with YAML frontmatter (trigger phrases, descriptions)
agents/*.md                → 3 active agents (context-detective, improvement-agent, research-agent)
commands/*.md              → 5 slash commands (init, status, rollback, auto-commit, memory-audit) — KEIN Command darf einen Skill-Namen tragen (Skill-Tool-Schatten/Loop, L17; Test erzwingt das)
improvements/state.json    → Self-improve loop state tracker
scripts/                   → Hook helpers + SSoT scripts (session-start.sh, mem-schema.sh, memory-thresholds.sh = Threshold-SSoT, model-routing.sh = Modellklassen-SSoT, preprocess_state.py = Stufe-0-Zustandsobjekt, cost-trace.sh = Kontext-Kostentrace, learnings_top.py = Salience-Ranking, pretooluse-shell-circuit-breaker.sh, posttooluse-dirty-tracker.py = Dirty-State-SSoT)
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
- **Hooks:** Lightweight by design. SessionStart (15s, command) auto-inits + injects context; PreToolUse (5s, command, Bash matcher) blocks known dangerous shell commands with exit code 2 before execution; PostToolUse (5s, command, Write/Edit matcher) mechanically tracks un-consolidated work in working/dirty-<sid>.json (fail-soft, never blocks); PreCompact (15s, prompt) outputs survival summary; SessionEnd (15s, prompt) task guard + delegates to wrap-up; UserPromptSubmit (10s, prompt) advisory-only; SubagentStop (10s, prompt) commit suggestion for improvement-agent. (The legacy Stop hook was removed in v3.1.1 — it caused an infinite feedback loop.)
- **Self-improve safety:** Max 20% mutation per skill per iteration. Git revert over git stash pop. Circuit breaker on diminishing returns.
- **Self-Improve Policy (2026-04-30):** 6 hard rules in `skills/self-improve/SKILL.md` — single-cluster-rule, pattern-confirmation-threshold, wrap-up-discipline, MCP-audit-as-diagnosis-only, no-self-mod-boundary, rollback-tag-tightness. The `self-improve` skill MUST NOT modify its own SKILL.md body — meta-suggestions go to `improvements/meta-suggestions.md` for manual review.
- **MCP-Tool-Bridge Policy (2026-04-30):** MCPs have 3 legitimate roles (tool execution, introspection, knowledge access) and 4 hard no-gos: do NOT replace `.agent-memory/`, do NOT replace `~/wiki/`, MCP-output is NEVER auto-truth, no uncontrolled cross-project mutation. Full policy: `~/wiki/wiki/concepts/mcp-tool-bridge-policy.md`. NotebookLM operations always prefer the user-skill `notebooklm` (notebooklm-py CLI) over the plugin-MCP variant — plugin-MCP is fallback for subagent contexts only.
- **Model-Routing Policy (v4.7.0):** Routine skills run on the cheap-write class (`model: sonnet` frontmatter); the class table lives ONLY in `scripts/model-routing.sh` (SSoT — a validate-skills test enforces frontmatter consistency). wrap-up/session-bootstrap run stage-0 preprocessing (`scripts/preprocess_state.py`) first and obey the (context-diet)/(bootstrap-fast-path) rules; conflicts, identity changes, decision replacements, and pattern-to-skill promotions are never resolved on the cheap class — they escalate via `working/escalations-<sid>.json` + `ESKALATION:` marker to the session model. Run costs are traced to `.agent-memory/metrics/cost-trace.jsonl` (estimates). Design: `docs/superpowers/specs/2026-07-15-model-routing-design.md`, manual evals: `docs/model-routing-eval-checklist.md`.
- **No circular dependencies** between skills — strict DAG.
- **Deprecated agents:** `improvement-scout` and `fix-reviewer` (removed 2026-04-30) and `quality-gate` (removed in v4.0.0). Use `improvement-agent` + `self-improve` instead. The `agents/` directory contains 3 active agents (context-detective, improvement-agent, research-agent).

## Testing Gotchas

- Skill trigger phrases must be English or tests fail
- `description` in SKILL.md frontmatter may use multiline YAML (`>`), so simple grep won't work — use `awk` for extraction
- `validate-skills.sh` checks frontmatter structure, trigger uniqueness, and dependency declarations
- **Agent/Skill deletions must propagate to `validate-plugin.sh`** — several tests reference agent files by name (e.g. `agents/<name>.md`). Deleting a deprecated agent without updating its tests leaves the suite silently red. When removing an agent, grep `tests/` for its name and re-point tests to the successor (2026-05-25: `improvement-scout` → `improvement-agent`/`self-improve`).
