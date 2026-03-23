---
description: Initialize Agentic OS memory system in the current project
argument-hint: "[--force]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
---

# Initialize Agentic OS

Bootstrap the `.agent-memory/` knowledge system in the current project directory.

## What to do

1. **Check if `.agent-memory/` already exists.** If it does and `--force` was NOT passed, abort with a message. If `--force` was passed, back up existing `.agent-memory/` to `.agent-memory.bak/`.

2. **Create the directory structure:**

```
.agent-memory/
├── identity/          # soul.md, user.md
├── iterations/        # iteration-log.md, errors.json
├── patterns/          # patterns.md, patterns.json
├── context/           # project-context.md, decisions.json
├── quality/           # test-results.json, code-reviews.json, quality-score.json
├── learnings/         # learnings.md
├── generated-skills/
└── session-summary.md
```

3. **Initialize all JSON files** with these exact values:
   - `errors.json`, `patterns.json`, `decisions.json` → `[]`
   - `test-results.json`, `code-reviews.json` → `[]`
   - `quality-score.json` → `{"last_updated": null, "test_health": {"score": null, "trend": "unknown"}, "code_quality": {"score": null, "trend": "unknown"}}`

4. **Initialize all Markdown files:**
   - `iteration-log.md` → `# Iteration Log\n\n*No entries yet.*`
   - `patterns/patterns.md` → `# Pattern Catalog\n\n*No patterns recognized yet.*`
   - `learnings/learnings.md` → `# Learnings\n\n*No session learnings yet.*`
   - `session-summary.md` → `# Last Session\n\n*First session — system freshly initialized.*\n\n## Next Steps\n1. Fill in project context\n2. Start first coding iteration\n3. Run wrap-up at end of session`

5. **Create identity files** using these templates:

**identity/soul.md:**
```markdown
# Soul — Agent Identity

*Initialized: <today>*

## Core Identity
- **Role**: Senior Developer and Architecture Advisor
- **Quality Bar**: Production-grade
- **Language**: German for communication, English for code and comments

## Communication
- Compact but with context. Direct recommendations, no filler.
- Proactive suggestions welcome.
- Ask back on architecture decisions and unclear requirements.

## Work Behavior
- One feature or one bug-fix per iteration
- "Done" means "tests green"
- Inline comments only for non-obvious logic
- Conventional Commits, concise messages

## Priorities (ordered)
1. Correctness over performance
2. Readability over cleverness
3. Tests over features

## Guard Rails
- Confirm before deleting files
- Justify new dependencies
- For changes spanning many files: write a brief plan first
- No architecture decisions without discussion

## Project-Specific Adaptations
(filled per project)
```

**identity/user.md:**
```markdown
# User Profile

*Initialized: <today>*

## Person
- **Role**: (detected or asked during init)
- **Experience**: (detected or asked during init)
- **Language**: German (primary), English (code, docs)

## Work Style
- **Session Length**: Focused 1-2h sessions
- **Autonomy**: High for implementation, ask back on architecture

## Technical Preferences
- (auto-detected from project or asked during init)

## Recurring Feedback
(auto-populated by wrap-up)

## Common Error Patterns
(auto-populated by wrap-up)
```

Ask the user for their role and experience level to fill in user.md.

6. **Auto-detect project context:**
   - Scan for `README.md`, `CLAUDE.md`, `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod` if they exist
   - Detect tech stack, project name, language
   - Write findings to `.agent-memory/context/project-context.md`
   - Ask the user to confirm or supplement the detected context

7. **Output a summary** of what was created (directory count, file count, detected stack).
