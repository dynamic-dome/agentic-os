---
description: Initialize Agentic OS v3 memory system in the current project
argument-hint: "[--force]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# Initialize Agentic OS v3

Bootstrap the `.agent-memory/` knowledge system in the current project directory.

## What to do

1. **Check if `.agent-memory/` already exists.** If it does and `--force` was NOT passed, abort with a message. If `--force` was passed, back up existing `.agent-memory/` to `.agent-memory.bak/`.

2. **Create the full directory structure:**

```
.agent-memory/
├── identity/          # soul.md, user.md
├── heartbeat/         # skill-registry.json, context-matrix.json, heartbeat-log.md
├── orchestrator/      # trigger-rules.json, orchestrator-log.md
├── learnings/         # learnings.md, skill-feedback.json
├── iterations/        # iteration-log.md, errors.json
├── patterns/          # patterns.md, patterns.json
├── context/           # project-context.md, decisions.json
├── generated-skills/
├── quality/           # test-results.json, code-reviews.json, quality-score.json
├── retrospectives/    # metrics.json
├── evolution/evals/
├── evolution/mutations/
├── evolution/         # benchmarks.json
├── transfer/agent-profiles/
└── session-summary.md
```

3. **Initialize all JSON files** with these exact values:
   - `errors.json`, `patterns.json`, `decisions.json`, `test-results.json`, `code-reviews.json`, `skill-feedback.json`, `exportable-patterns.json` → `[]`
   - `benchmarks.json` → `{"skills": {}}`
   - `metrics.json` → `{"last_updated": null, "health_grade": "N/A"}`
   - `quality-score.json` → `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}`
   - `trigger-rules.json` → `{"auto_log_iterations": true, "auto_review_code": true, "auto_run_tests": true, "pattern_check_interval": 5, "min_severity_for_log": "minor", "auto_context_on_decisions": true, "retrospective_interval_sessions": 5, "verbose_orchestrator_log": false}`
   - `skill-registry.json` → `{"last_scan": "<today>", "skills": []}`
   - `context-matrix.json` → `{"last_updated": "<today>", "contexts": []}`

4. **Initialize all Markdown files:**
   - `iteration-log.md` → `# Iteration Log\n\n*Noch keine Einträge.*`
   - `patterns.md` → `# Pattern-Katalog\n\n*Noch keine Patterns erkannt.*`
   - `orchestrator-log.md` → `# Orchestrator Log\n\n*System initialisiert: <today>*`
   - `heartbeat-log.md` → `# Heartbeat Log\n\n*System initialisiert: <today>*`
   - `learnings.md` → `# Learnings\n\n*Noch keine Session-Learnings.*`
   - `session-summary.md` → `# Letzte Session\n\n*Erste Session — System frisch initialisiert.*\n\n## Nächste Schritte\n1. Projektkontext ausfüllen\n2. Erste Coding-Iteration starten`

5. **Create identity files** using the templates from the `init-memory` skill (read `${CLAUDE_PLUGIN_ROOT}/skills/init-memory/SKILL.md` for templates).

6. **Auto-detect project context:**
   - Read `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml` if they exist
   - Detect tech stack, project name, language
   - Write findings to `.agent-memory/context/project-context.md`
   - Ask the user to confirm or supplement the detected context

7. **Sync to global memory (cross-platform):**
   - Ensure `~/.claude-memory/global/` exists (use `mkdir -p` on macOS/Linux, `New-Item -Force` on Windows)
   - Do NOT rely on external shell scripts — create the directory and initialize JSON files inline using the Write tool:
     - `patterns.json` → `[]`
     - `learnings.json` → `[]`
     - `projects.json` → `{"projects": []}`
     - `agent-profile.json` → `{"initialized": null, "total_sessions": 0, "total_iterations": 0, "preferred_patterns": [], "common_errors": [], "stack_experience": {}}`
   - Only create files that don't already exist (check with Read first)
   - Register this project in `~/.claude-memory/global/projects.json`

8. **Output a summary** of what was created (directory count, file count, detected stack).
