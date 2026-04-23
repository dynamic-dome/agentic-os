---
name: init
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
│   ├── learnings.md
│   └── learnings.json
├── knowledge/
│   └── notebook-registry.md
├── generated-skills/
├── config.json              (optional, created by Wiki Integration step)
└── session-summary.md
```

3. **Initialize JSON files** with these defaults:
   - `errors.json` → `[]`
   - `patterns.json` → `[]`
   - `decisions.json` → `[]`
   - `test-results.json` → `[]`
   - `code-reviews.json` → `[]`
   - `quality-score.json` → `{"last_updated": null, "test_health": {"current_score": null, "trend": "unknown"}, "code_quality": {"current_score": null, "trend": "unknown"}}`
   - `context/open-tasks.json` → `[]`  **(MANDATORY — Task Persistence Guard, canonical location is context/, NOT root)**
   - `learnings/learnings.json` → `[]`  **(MANDATORY — wrap-up dedup/scoring and session-bootstrap salience retrieval depend on this)**

4. **Initialize Markdown files:**
   - `iteration-log.md` → `# Iteration Log\n\n*No entries yet.*`
   - `patterns.md` → `# Pattern Catalog\n\n*No patterns detected yet.*`
   - `learnings.md` → `# Learnings\n\n*No session learnings yet.*`
   - `session-summary.md` → `# Last Session\n\n*First session — system freshly initialized.*\n\n## Next Steps\n1. Fill in project context\n2. Start first coding iteration`
   - `knowledge/notebook-registry.md` → see below

   **notebook-registry.md** (Knowledge Base Registry):
   ```markdown
   # NotebookLM Knowledge Base Registry

   *No notebooks registered yet. Add entries here as you create NotebookLM knowledge bases.*

   ## Active Notebooks

   (none)

   ## When to consult NotebookLM
   - For expert knowledge on topics covered by a notebook
   - When best practices or reference material is needed
   - When uncertain about the right approach
   - When comparing or summarizing multiple sources

   ## How to update this registry
   After creating a new notebook or adding important sources:
   1. Add a new entry here (name, topic, strengths, keywords)
   2. Update existing entries when major changes are made
   ```

5. **Create identity files:**

   **soul.md:**
   ```markdown
   # Agent Identity

   ## Communication
   - Language: en (switch to de if user writes in German)
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

7. **Optional: Wiki Integration (config.json)**

   Ask the user: "Soll dieses Projekt mit dem Obsidian Wiki verbunden werden? (Pfad zum Wiki angeben oder 'nein')"

   - If user says no or skips → do NOT create config.json, continue to step 8.
   - If user provides a wiki path:
     1. Validate: check if `{wiki_path}/CLAUDE.md` exists. If not → warn "Wiki not found at this path." and ask again or skip.
     2. Auto-detect `project_id` from the current directory name (kebab-case)
     3. **Idempotent write**: If `.agent-memory/config.json` already exists, **merge** new values into existing config (do NOT overwrite). If it does not exist, create it.
     4. Write/merge `.agent-memory/config.json`:
        ```json
        {
          "wiki_root": "{validated_wiki_path}",
          "project_id": "{auto_detected_id}",
          "project_aliases": ["{directory_name}"],
          "sync_enabled": true,
          "session_note_threshold": 2,
          "default_entrypoints": []
        }
        ```
     5. `default_entrypoints` is left empty by default. The user can add entry points later when the corresponding wiki pages exist.
     6. If the project has an entity page at `{wiki_path}/wiki/entities/{project_id}.md`, add it to `default_entrypoints` automatically.

   **Idempotency rule**: If config.json already has `wiki_root` set and `--force` was not passed, skip this step with: "Wiki already configured (wiki_root: {path}). Use --force to reconfigure."

8. **Ensure CLAUDE.md contains Knowledge Base section:**

   Check if a `CLAUDE.md` exists in the project root. If not, create one. If it exists, check if it already has a "Knowledge Base" section. If not, append the following section:

   ```markdown
   ## Knowledge Base (NotebookLM) — Required for all Agents

   This project has a curated knowledge base in Google NotebookLM.
   The registry at `.agent-memory/knowledge/notebook-registry.md` lists all
   available notebooks with their topics and keywords.

   **IMPORTANT — Instruction for EVERY Agent (Claude Code, Subagents, Scheduled Tasks):**
   You MUST check the registry before answering expert questions.
   If a matching notebook exists, open NotebookLM in the browser to query the knowledge base
   and incorporate the result into your answer.
   Do NOT answer from memory when the registry has a notebook on the topic.

   **When to consult NotebookLM:**
   - Expert questions on topics covered by notebooks
   - Best practices, reference material, or expert knowledge needed
   - Uncertainty about the right approach for Claude Code features
   - User asks for "expert knowledge", "what do the sources say", "research this"
   - Architecture decisions that benefit from collected knowledge

   **When NOT to consult:**
   - Pure code changes without knowledge requirements
   - Simple commands like "create file X" or "fix this bug"
   - Topics not covered by any notebook in the registry

   **Workflow:**
   1. Read registry: `.agent-memory/knowledge/notebook-registry.md`
   2. Identify matching notebook by keywords
   3. Open NotebookLM in browser — ask question directly (mention notebook name in prompt)
   4. Incorporate result into the answer
   ```

9. **Output summary:**

```
Agentic OS initialized!
  Directories: 9
  Files: 15
  Detected stack: {language} + {framework}
  Knowledge Base: notebook-registry.md created
  Wiki: {connected to ~/wiki/ | not configured}

  Next steps:
  1. Review .agent-memory/context/project-context.md
  2. Customize .agent-memory/identity/soul.md if needed
  3. Review .agent-memory/knowledge/notebook-registry.md
  4. Start coding — iterations will be tracked automatically
```
