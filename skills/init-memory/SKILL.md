---
name: init-memory
description: >
  Initializes the .agent-memory/ knowledge system in any project.
  Use when bootstrapping Agentic OS in a new repository.
  Trigger phrases: "init memory", "bootstrap agent", "setup agentic os",
  "initialize memory system", "Speicher initialisieren", "Memory aufsetzen",
  "Memory-System einrichten".

metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Init Memory Skill

## When to Use

When setting up Agentic OS v3 in a new project for the first time.

## Identity Templates

### soul.md Template

```markdown
# Soul — Agenten-Identität

*Initialisiert: {date}*

## Kernidentität
- **Rolle**: Senior Developer und Architektur-Berater
- **Expertise-Level**: Production-Grade
- **Sprache**: Deutsch für Kommunikation, Englisch für Code

## Kommunikationsstil
- **Kürze**: 3/5 (kompakt, aber mit Kontext)
- **Proaktivität**: Ja, eigenständige Vorschläge erwünscht
- **Rückfragen**: Bei Architektur-Entscheidungen und unklaren Requirements
- **Ton**: Sachlich-technisch, direkte Empfehlungen

## Arbeitsverhalten
- **Änderungsgröße**: Max 1 Feature / 1 Bug-Fix pro Iteration
- **Tests**: Immer. "Fertig" = "Tests grün"
- **Git-Stil**: Conventional Commits

## Prioritäten
1. Korrektheit vor Performance
2. Lesbarkeit vor Cleverness
3. Tests vor Features

## Verbotene Aktionen
- Nie Dateien löschen ohne Bestätigung
- Nie Dependencies hinzufügen ohne Begründung
- Nie Architektur-Entscheidungen ohne Rückfrage
- Nie mehr als 3 Dateien gleichzeitig ändern ohne Plan
```

### user.md Template

```markdown
# User-Profil

*Initialisiert: {date}*

## Person
- **Rolle**: (wird beim Init erfragt)
- **Erfahrung**: (wird beim Init erfragt)
- **Sprache**: Deutsch (primär), Englisch (Code)

## Arbeitsstil
- **Session-Länge**: Fokussierte 1-2h Sessions
- **Autonomie-Präferenz**: Hohe Autonomie, Rückfrage bei Architektur

## Technische Präferenzen
- (wird automatisch aus Projektkontext befüllt)

## Häufige Fehlerquellen (automatisch befüllt)
(wird vom wrap-up Skill aktualisiert)
```

## Global Memory Structure

```
~/.claude-memory/global/
├── patterns.json          # Cross-project patterns
├── learnings.json         # Cross-project learnings
├── agent-profile.json     # Accumulated user work style
└── projects.json          # Registry of all initialized projects
```

### projects.json Schema

```json
{
  "projects": [
    {
      "name": "project-name",
      "path": "/absolute/path",
      "stack": ["python", "opencv", "fastapi"],
      "initialized": "2026-03-19",
      "last_sync": "2026-03-19",
      "total_iterations": 0
    }
  ]
}
```

## Instructions

### Step 1: Check existing state
- Use `Glob` to check if `.agent-memory/` already exists
- If it exists: warn the user, ask before overwriting (backup existing to `.agent-memory.bak/`)

### Step 2: Create directory tree
Use `Bash` to create all directories:
```
.agent-memory/identity/
.agent-memory/heartbeat/
.agent-memory/orchestrator/
.agent-memory/iterations/
.agent-memory/patterns/
.agent-memory/context/
.agent-memory/quality/
.agent-memory/learnings/
.agent-memory/generated-skills/
.agent-memory/retrospectives/
.agent-memory/evolution/evals/
.agent-memory/evolution/mutations/
.agent-memory/transfer/agent-profiles/
```

### Step 3: Initialize JSON files with defaults
Use `Write` tool for each:
- `iterations/errors.json` → `[]`
- `patterns/patterns.json` → `[]`
- `context/decisions.json` → `[]`
- `quality/test-results.json` → `[]`
- `quality/code-reviews.json` → `[]`
- `quality/quality-score.json` → `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}`
- `learnings/skill-feedback.json` → `[]`
- `evolution/benchmarks.json` → `{"skills": {}}`
- `retrospectives/metrics.json` → `{"last_updated": null, "health_grade": "N/A"}`
- `heartbeat/skill-registry.json` → `[]`
- `heartbeat/context-matrix.json` → `{"timestamp": null, "total_context_tokens_estimate": 0, "sections": []}`
- `orchestrator/trigger-rules.json` → `{"auto_log_iterations": true, "auto_review_code": true, "auto_run_tests": true, "pattern_check_interval": 5}`

### Step 4: Create identity files
- Use `Write` to create `identity/soul.md` from the soul.md template above, replacing `{date}` with current date
- Use `Write` to create `identity/user.md` from the user.md template above, replacing `{date}` with current date
- Ask the user for their role and experience level to fill in user.md

### Step 5: Create Markdown scaffold files
- `session-summary.md` → "# Letzte Session\n\n*System frisch initialisiert*"
- `heartbeat/heartbeat-log.md` → "# Heartbeat Log\n"
- `orchestrator/orchestrator-log.md` → "# Orchestrator Log\n"
- `iterations/iteration-log.md` → "# Iteration Log\n"
- `patterns/patterns.md` → "# Pattern Catalog\n"
- `learnings/learnings.md` → "# Learnings\n"
- `context/project-context.md` → (populated in Step 6)
- `transfer/handoff-briefing.md` → "# Handoff Briefing\n\n*Noch kein Handoff durchgefuehrt.*"

### Step 6: Auto-detect project context
Use `Glob` and `Read` to scan for:
- `README.md`, `CLAUDE.md` → project description
- `package.json` → Node.js stack, dependencies
- `pyproject.toml`, `requirements.txt`, `setup.py` → Python stack
- `Cargo.toml` → Rust stack
- `go.mod` → Go stack
- `pom.xml`, `build.gradle` → Java stack

Write findings to `context/project-context.md` with tech stack table.

### Step 7: Set up global memory
- Check if `~/.claude-memory/global/` exists; create if not
- Initialize `patterns.json`, `learnings.json`, `agent-profile.json` with `[]` or `{}`
- Register project in `projects.json` with name, path, detected stack, date

### Step 8: Output summary
Display a table of all created files and directories with status indicators.
