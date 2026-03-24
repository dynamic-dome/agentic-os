---
description: Initialize Agentic OS v2 memory system in the current project
argument-hint: "[--force]"
allowed_tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# Initialize Agentic OS

Bootstrap the `.agent-memory/` knowledge system in the current project directory.

## What to do

1. **Check if `.agent-memory/` already exists.** If it does and `--force` was NOT passed, abort with: "Memory system already exists. Use `--force` to reinitialize (backs up existing)." If `--force` was passed, rename existing `.agent-memory/` to `.agent-memory.bak-{YYYY-MM-DD}/`.

2. **Create the directory structure:**

```
.agent-memory/
├── identity/
│   ├── soul.md
│   └── user.md
├── context/
│   ├── project-context.md
│   └── decisions.json
├── iterations/
│   ├── iteration-log.md
│   └── errors.json
├── patterns/
│   ├── patterns.md
│   └── patterns.json
├── quality/
│   ├── test-results.json
│   ├── code-reviews.json
│   └── quality-score.json
├── learnings/
│   └── learnings.md
├── knowledge/
│   └── notebook-registry.md
├── generated-skills/
└── session-summary.md
```

3. **Initialize JSON files** with these defaults:
   - `errors.json` → `[]`
   - `patterns.json` → `[]`
   - `decisions.json` → `[]`
   - `test-results.json` → `[]`
   - `code-reviews.json` → `[]`
   - `quality-score.json` → `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}`

4. **Initialize Markdown files:**
   - `iteration-log.md` → `# Iteration Log\n\n*Noch keine Eintraege.*`
   - `patterns.md` → `# Pattern-Katalog\n\n*Noch keine Patterns erkannt.*`
   - `learnings.md` → `# Learnings\n\n*Noch keine Session-Learnings.*`
   - `session-summary.md` → `# Letzte Session\n\n*Erste Session — System frisch initialisiert.*\n\n## Naechste Schritte\n1. Projektkontext ausfuellen\n2. Erste Coding-Iteration starten`
   - `knowledge/notebook-registry.md` → see below

   **notebook-registry.md** (Knowledge Base Registry):
   ```markdown
   # NotebookLM Knowledge Base Registry

   > Zentrales Register aller NotebookLM-Notebooks. Agents pruefen diese Datei
   > bevor sie Wissensfragen beantworten. Siehe CLAUDE.md fuer den Workflow.

   ## Aktive Notebooks

   ### Claude Code Hooks & Context Injection Mastery
   - **Thema:** Hooks-System, Context Injection, PreToolUse/PostToolUse Patterns
   - **Staerken:** Tiefes Wissen ueber Claude Code Hook-Architektur und Context Injection
   - **Stichwörter:** hooks, context injection, PreToolUse, PostToolUse, automation, prompt-based hooks

   ### Geplante Aufgaben: Ideen, Best Practices & Kreative Ansaetze
   - **Thema:** Scheduled Tasks, Cron-Jobs, zeitgesteuerte Automatisierung
   - **Staerken:** Kreative Ideen und Best Practices fuer geplante Aufgaben
   - **Stichwörter:** scheduled tasks, cron, automation, zeitgesteuert, timer

   ### Claude Code: Scheduled Tasks, Automation & Kreative Ideen
   - **Thema:** Automation-Patterns, kreative Anwendungsfaelle fuer Claude Code
   - **Staerken:** Praxisnahe Automations-Szenarien und kreative Workflows
   - **Stichwörter:** automation, scheduled tasks, workflows, kreativ, use cases

   ### Claude Code Docs (DE)
   - **Thema:** Offizielle Claude Code Dokumentation auf Deutsch
   - **Staerken:** Referenz fuer alle Claude Code Features, APIs, Konfiguration
   - **Stichwörter:** claude code, dokumentation, referenz, features, API, settings, permissions

   ### Claude Code: Workflows, Skills und Automatisierung mit KI-Agenten
   - **Thema:** Skills-Entwicklung, Workflow-Design, Agenten-Orchestrierung
   - **Staerken:** Best Practices fuer Skills, Plugins, Multi-Agent-Workflows
   - **Stichwörter:** skills, workflows, plugins, agenten, orchestrierung, SKILL.md, plugin.json

   ### Agentic AI & Self-Improving Workflows
   - **Thema:** Selbstverbessernde KI-Systeme, Agentic Patterns, Lernschleifen
   - **Staerken:** Fortgeschrittene Konzepte fuer autonome KI-Agenten
   - **Stichwörter:** agentic AI, self-improving, learning loops, autonome agenten, feedback loops

   ## Wann NotebookLM konsultieren?
   - Bei Fragen zu Themen die in einem der Notebooks abgedeckt sind
   - Bei Bedarf an Expertenwissen, Best Practices, Recherche-Ergebnissen
   - Wenn mehrere Quellen verglichen oder zusammengefasst werden sollen
   - Wenn der Agent unsicher ist und eine zweite Meinung aus gesammelten Quellen braucht

   ## Registry aktualisieren
   Nach dem Erstellen neuer Notebooks oder Hinzufuegen wichtiger Quellen:
   1. Neuen Eintrag hier hinzufuegen (Name, Thema, Staerken, Stichwörter)
   2. Bei grossen Aenderungen bestehende Eintraege aktualisieren
   ```

5. **Create identity files:**

   **soul.md:**
   ```markdown
   # Agent Identity

   ## Communication
   - Language: de (switch to en if user writes in English)
   - Brevity: 3/5 (balanced — concise but explain when needed)
   - Proactivity: 3/5 (suggest when relevant, don't overdo)

   ## Guard Rails
   - Confirm before deleting files (accidental deletion is hard to undo)
   - Justify new dependencies (every dependency is a maintenance burden)
   - For changes spanning many files: write a brief plan first
   - No architecture decisions without discussion (show options with pros/cons)

   ## Priorities
   1. Correctness over speed
   2. Simplicity over cleverness
   3. Working code over perfect code
   ```

   **user.md:**
   ```markdown
   # User Profile

   *Initialized: {date}*

   ## Preferences
   - (Will be populated through observed patterns)

   ## Work Style
   - (Will be populated through session observations)

   ## Known Corrections
   - (Recorded when user corrects agent behavior 3+ times)
   ```

6. **Auto-detect project context:**
   - Read `README.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod` if they exist
   - Detect: project name, language, framework, test runner
   - Write findings to `.agent-memory/context/project-context.md` using the context-keeper format
   - Ask the user to confirm or supplement the detected context

7. **Ensure CLAUDE.md contains Knowledge Base section:**

   Check if a `CLAUDE.md` exists in the project root. If not, create one. If it exists, check if it already has a "Knowledge Base" section. If not, append the following section:

   ```markdown
   ## Knowledge Base (NotebookLM) — PFLICHT fuer alle Agents

   Dieses Projekt verfuegt ueber eine kuratierte Wissensbasis in Google NotebookLM.
   Die Registry unter `.agent-memory/knowledge/notebook-registry.md` listet alle
   verfuegbaren Notebooks mit Themen und Stichwörtern.

   **WICHTIG — Anweisung fuer JEDEN Agent (Claude Code, Subagents, Scheduled Tasks):**
   Du MUSST vor jeder Antwort auf Fachfragen die Registry pruefen.
   Wenn ein passendes Notebook existiert, nutze `notebooklm:chat` um die Wissensbasis
   zu befragen und baue das Ergebnis in deine Antwort ein.
   Antworte NICHT aus dem Kopf wenn die Registry ein Notebook zum Thema hat.

   **Wann NotebookLM konsultieren (PFLICHT):**
   - Fachfragen zu Themen die in Notebooks abgedeckt sind
   - Best Practices, Referenzmaterial oder Expertenwissen benoetigt
   - Unsicherheit ueber die richtige Vorgehensweise bei Claude Code Features
   - User fragt nach "Expertenwissen", "was sagen die Quellen", "recherchiere"
   - Architekturentscheidungen die von gesammeltem Wissen profitieren

   **Wann NICHT konsultieren:**
   - Reine Code-Aenderungen ohne Wissensbedarf
   - Einfache Befehle wie "erstelle Datei X" oder "fix diesen Bug"
   - Themen die kein Notebook in der Registry abdeckt

   **Workflow:**
   1. Registry lesen: `.agent-memory/knowledge/notebook-registry.md`
   2. Passendes Notebook anhand der Stichwörter identifizieren
   3. `notebooklm:chat` — Frage direkt stellen (Notebook-Name im Prompt nennen)
   4. Ergebnis in die Antwort einbauen
   ```

8. **Output summary:**

```
Agentic OS initialized!
  Directories: 9
  Files: 15
  Detected stack: {language} + {framework}
  Knowledge Base: notebook-registry.md created

  Next steps:
  1. Review .agent-memory/context/project-context.md
  2. Customize .agent-memory/identity/soul.md if needed
  3. Review .agent-memory/knowledge/notebook-registry.md
  4. Start coding — iterations will be tracked automatically
```
