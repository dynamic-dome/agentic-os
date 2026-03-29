# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agentic OS v2.0.0 — a Claude Code plugin providing a self-improving agent memory system. It installs skills, hooks, agents, and commands that persist project knowledge across sessions in `.agent-memory/`.

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
plugin.json              → Plugin manifest (name, version, description)
hooks/hooks.json         → 5 lifecycle hooks (SessionStart, UserPromptSubmit, Stop, PreCompact, SessionEnd, SubagentStop)
skills/*/SKILL.md        → 20 skills with YAML frontmatter (trigger phrases, descriptions)
agents/*.md              → 6 agents (context-detective, quality-gate, improvement-agent, etc.)
commands/*.md            → 5 slash commands (init, status, run-loop, rollback, auto-commit)
improvements/state.json  → Self-improve loop state tracker
scripts/                 → Hook helper scripts (session-start.sh, session-end.sh, pre-compact.sh)
```

**Skill layers:**
- **Core** (session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, skill-generator, sync-context): Session lifecycle and memory management
- **Quality** (code-reviewer, test-validator, tdd): Code quality enforcement
- **Self-improve** (self-improve, loop-orchestrator, research-phase, analysis-phase, improvement-phase, validation-phase, meta-improve, schedule-manager, research-pipeline, memory-janitor): Autonomous improvement loop

See `skills/DEPENDENCIES.md` for the full dependency graph and data flow.

## Key Conventions

- **Language policy:** Trigger phrases in SKILL.md frontmatter MUST be English (tests enforce this). Body text English. User-facing communication in German.
- **SKILL.md format:** YAML frontmatter with `name`, `description` (used for matching — be specific), `type: skill`, trigger phrases. Body is the skill prompt.
- **Memory dir:** Skills read/write `.agent-memory/` in the target project (not this repo). `session-bootstrap` is strictly read-only.
- **Hooks:** Lightweight by design. SessionStart (15s) reads silently; Stop (15s) logs iterations; PreCompact outputs survival summary; SessionEnd (30s) updates session-summary; UserPromptSubmit is advisory-only (never blocks).
- **Self-improve safety:** Max 20% mutation per skill per iteration. Git revert over git stash pop. Circuit breaker on diminishing returns.
- **No circular dependencies** between skills — strict DAG.
- **Deprecated agents:** `improvement-scout` and `fix-reviewer` are legacy — prefer `improvement-agent` + `validation-phase`.

## Testing Gotchas

- Skill trigger phrases must be English or tests fail
- `description` in SKILL.md frontmatter may use multiline YAML (`>`), so simple grep won't work — use `awk` for extraction
- `validate-skills.sh` checks frontmatter structure, trigger uniqueness, and dependency declarations
