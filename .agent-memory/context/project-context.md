# Project Context

## Project
- **Name:** agentic-os-plugin
- **Type:** Claude Code Plugin
- **Language:** Markdown (skills/agents/commands), JSON (config/state), Bash (tests/hooks)
- **Framework:** Claude Code Plugin System v2
- **Package Manager:** none (no runtime deps)
- **Repository:** https://github.com/willneverusegit/argentic-os.git

## Architecture
- 4-Layer system: Identity, Core (7 skills), Quality (3 skills), Evolution (generated)
- 4 agents: context-detective, quality-gate, improvement-scout, fix-reviewer
- 3 commands: init, status, auto-commit
- 6 lifecycle hooks (prompt-based + 1 shell script)
- DAG-based skill dependencies (no circular deps)
- Self-improvement loop via scheduled task (hourly)

## Test Infrastructure
- 130 tests in bash (validate-plugin.sh, validate-skills.sh)
- Checks: JSON validity, frontmatter, skill sections, description quality, dependency completeness, reviewer rules

## Constraints
- Windows/Git Bash environment (path spaces, bash arithmetic quirks)
- No runtime dependencies (pure markdown/JSON/bash)
- .agent-memory/ excluded from git commits
- Append-only decisions.json (never delete, only supersede)

## Current Status
- v2.0.0 with self-improvement loop active
- 130/130 tests passing
- 1 self-improvement iteration completed
- Scheduled task running hourly
- 1 anti-pattern identified (Windows/bash compatibility)
