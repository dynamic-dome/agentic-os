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

7. **Output summary:**

```
Agentic OS initialized!
  Directories: 8
  Files: 14
  Detected stack: {language} + {framework}

  Next steps:
  1. Review .agent-memory/context/project-context.md
  2. Customize .agent-memory/identity/soul.md if needed
  3. Start coding — iterations will be tracked automatically
```
