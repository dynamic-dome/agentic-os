# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agentic OS v3.0.0 — a Claude Code plugin providing a self-improving agent memory system. It installs skills, hooks, agents, and commands that persist project knowledge across sessions in `.agent-memory/`.

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
hooks/hooks.json           → 5 lifecycle hooks (SessionStart, UserPromptSubmit, PreCompact, SessionEnd, SubagentStop)
skills/*/SKILL.md          → 13 skills with YAML frontmatter (trigger phrases, descriptions)
agents/*.md                → 4 active agents (context-detective, improvement-agent, quality-gate, research-agent)
commands/*.md              → 10 slash commands (init, status, run-loop, rollback, auto-commit, sync, log, patterns, research, memory-audit) — KEIN Command darf einen Skill-Namen tragen (Skill-Tool-Schatten/Loop, L17; Test erzwingt das)
improvements/state.json    → Self-improve loop state tracker
scripts/                   → Hook helper scripts (session-start.sh — only active command hook)
```

**Skills (13, layered):**
- **Core** (session-bootstrap, iteration-logger, pattern-extractor, context-keeper, wrap-up, skill-generator, sync-context, memory-maintenance): Session lifecycle and memory management
- **Quality** (quality-gate): Code review + test validation + TDD enforcement in one skill
- **Self-improve** (self-improve): Multi-iteration loop with research, analysis, improvement, validation, meta-improve, scheduling — policy-gated (siehe `skills/self-improve/SKILL.md` Self-Improve Policy)
- **Knowledge** (research-pipeline, wiki-query, obsidian-sync): External research via Perplexity/NotebookLM, mid-session wiki-lookup, write-path to Obsidian wiki

See `skills/DEPENDENCIES.md` for the full dependency graph and data flow.

## Key Conventions

- **Language policy:** Trigger phrases in SKILL.md frontmatter MUST be English (tests enforce this). Body text English. User-facing communication in German.
- **SKILL.md format:** YAML frontmatter with `name`, `description` (used for matching — be specific), `type: skill`, trigger phrases. Body is the skill prompt.
- **Memory dir:** Skills read/write `.agent-memory/` in the target project (not this repo). `session-bootstrap` is read-only, with ONE exception: the user-confirmed soul.md candidate gate (Step 6.5) writes soul.md only on an explicit `j` (never autonomously — Stufe-B growth, v3.3.0).
- **Hooks:** Lightweight by design. SessionStart (15s, command) auto-inits + injects context; PreCompact (15s, prompt) outputs survival summary; SessionEnd (15s, prompt) task guard + delegates to wrap-up; UserPromptSubmit (10s, prompt) advisory-only; SubagentStop (10s, prompt) commit suggestion for quality-gate/improvement-agent. (The legacy Stop hook was removed in v3.1.1 — it caused an infinite feedback loop.)
- **Self-improve safety:** Max 20% mutation per skill per iteration. Git revert over git stash pop. Circuit breaker on diminishing returns.
- **Self-Improve Policy (2026-04-30):** 6 hard rules in `skills/self-improve/SKILL.md` — single-cluster-rule, pattern-confirmation-threshold, wrap-up-discipline, MCP-audit-as-diagnosis-only, no-self-mod-boundary, rollback-tag-tightness. The `self-improve` skill MUST NOT modify its own SKILL.md body — meta-suggestions go to `improvements/meta-suggestions.md` for manual review.
- **MCP-Tool-Bridge Policy (2026-04-30):** MCPs have 3 legitimate roles (tool execution, introspection, knowledge access) and 4 hard no-gos: do NOT replace `.agent-memory/`, do NOT replace `~/wiki/`, MCP-output is NEVER auto-truth, no uncontrolled cross-project mutation. Full policy: `~/wiki/wiki/concepts/mcp-tool-bridge-policy.md`. NotebookLM operations always prefer the user-skill `notebooklm` (notebooklm-py CLI) over the plugin-MCP variant — plugin-MCP is fallback for subagent contexts only.
- **No circular dependencies** between skills — strict DAG.
- **Deprecated agents (removed 2026-04-30):** `improvement-scout` and `fix-reviewer` were legacy and have been deleted. Use `improvement-agent` + `self-improve` instead. The `agents/` directory now contains 4 active agents (context-detective, improvement-agent, quality-gate, research-agent).

## Testing Gotchas

- Skill trigger phrases must be English or tests fail
- `description` in SKILL.md frontmatter may use multiline YAML (`>`), so simple grep won't work — use `awk` for extraction
- `validate-skills.sh` checks frontmatter structure, trigger uniqueness, and dependency declarations
- **Agent/Skill deletions must propagate to `validate-plugin.sh`** — several tests reference agent files by name (e.g. `agents/<name>.md`). Deleting a deprecated agent without updating its tests leaves the suite silently red. When removing an agent, grep `tests/` for its name and re-point tests to the successor (2026-05-25: `improvement-scout` → `improvement-agent`/`self-improve`).
