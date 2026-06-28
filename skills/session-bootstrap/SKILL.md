---
name: session-bootstrap
description: >
  Bootstraps full project context at session start. Reads session-summary,
  identity files, patterns, and quality scores. Performs health checks on
  the memory system. Produces a compact briefing with warnings and next steps.
  Use at the beginning of every coding session.
  Trigger phrases: "start session", "session bootstrap", "session start",
  "begin work", "what was I working on", "context restore", "new session",
  "project status", "where were we", "what do we know".
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Session Bootstrap

Restore full project context at the start of every coding session.

## When to Use

- Start of every new coding session (auto-triggered by SessionStart hook)
- After context-window reset or long pause
- User asks "Where were we?" or "Project status?"
- Agent switch (Claude Code <-> other)

**Note:** The SessionStart hook now handles Auto-Init automatically. If `.agent-memory/` doesn't exist, the hook creates it before this skill runs. You should never need to suggest `/agentic-os:init` manually anymore.

## Step 0.5: Cross-Project Handoff (SESSION-WORKFLOW)

**Before** reading local project state, read TWO cross-project files. Both are
**read-only** here — the write-side lives in `wrap-up`.

### (a) Central handoff — last session, any project

1. Read `C:\Users\domes\AI\.agent-memory\session-summary.md` (the **central handoff**).
   It is a STACKED file: the most recent session is at the TOP, older sessions are
   preserved below under `# Vorherige Session (...erhalten)` headings (wrap-up Step 7.6a
   prepends, it does NOT blank-overwrite). The TOP block is the last session, possibly
   from a different project — read it; older blocks are history, scan only if needed.
2. Read `C:\Users\domes\AI\SESSION-WORKFLOW.md` **only if** the central handoff references it or if this is the first session in a new project

It tells you:
- Which project was worked on last (may differ from the current project)
- What was accomplished and what's still open
- Which agent wrote it (Claude, Codex, etc.)

### (b) Cross-project status board — all projects at a glance

3. Read `C:\Users\domes\AI\cross-project-status.md` (the **status board**).
   Unlike the central handoff (only the *last* session, often 10+/day), this file
   holds **one section per project**, each updated only when that project is wrapped up.
   Use it to see the current state of every touched project at once — and to surface
   cross-project items flagged as relevant for ALL projects.

**Rules:**
- The central handoff (a) is authoritative for "what happened last". The status board (b) is authoritative for "where does each project currently stand".
- If the central handoff is **newer** than the local `.agent-memory/session-summary.md`, the central handoff takes precedence for the LAST SESSION block in the briefing
- If the central handoff references a **different project** than the current one, note this in the briefing ("Last handoff was from project X — switching context to Y")
- From the status board, pull (i) the section matching the **current** project, if present, and (ii) any `## Cross-Project Notes` block (items relevant for all projects).
- **Next-steps ownership (open-tasks-priority):** the central handoff's "Naechste Schritte"
  section is a POINTER, not a list. The authoritative source for THIS project's next steps
  is the local `context/open-tasks.json` (rendered by the local session-summary). From the
  central handoff, import ONLY items prefixed `[cross-project]`. Never harvest project
  next steps from stacked history blocks — they no longer exist (one block per project).
- If either file does not exist or is unreadable → skip THAT file silently, continue. Never block on a missing cross-project file.
- This step is **read-only** — do not modify either file

## Step 1: Check Memory System Exists

Read `.agent-memory/session-summary.md`:

- If `.agent-memory/` does not exist → this should not happen (SessionStart hook auto-creates it). If it does, output "Memory system not found. This is unexpected — the SessionStart hook should have created it. Try restarting the session." and stop.
- If it exists but `session-summary.md` is missing → note "No previous session found", continue with other files.

**Three cross-project/local sources may exist:**
- **Central handoff** (`~/AI/.agent-memory/session-summary.md`, from Step 0.5a): the cross-project agent-to-agent handoff — authoritative for "what happened last"
- **Status board** (`~/AI/cross-project-status.md`, from Step 0.5b): per-project current state of ALL touched projects — authoritative for "where does each project stand"
- **Local `.agent-memory/session-summary.md`**: project-specific operational state — authoritative for "where THIS project stands"

All are valid. The briefing merges them (see Step 4).

## Step 2: Load Knowledge Files

Read files in this priority order. Skip any that don't exist:

1. **`session-summary.md`** — this project's last session state (complements central handoff)
2. **`identity/soul.md`** — agent behavior settings, guard rails
3. **`identity/user.md`** — user preferences and work style
4. **`context/project-context.md`** — tech stack, architecture, constraints
5. **`patterns/patterns.md`** — known patterns and anti-patterns (scan for high-confidence only)
6. **`learnings/learnings.json`** — structured learnings with salience metadata (see Salience Retrieval below)
7. **`quality/quality-score.json`** — test health + code quality trends
8. **`iterations/errors.json`** — last 3 entries only (tail, not full load)
9. **`working/current-session.json`** — if exists, resume working memory from interrupted session
10. **`context/open-tasks.json`** — open/blocked tasks (SSoT for next steps; feeds Step 6)

Apply identity settings from `soul.md` silently (communication style, guard rails).

### Learnings Retrieval (RAG-Hybrid)

**Primary path — Atlas MCP (when available):**

1. Build a query from `context/open-tasks.json`: concat the titles of the top 3 open/blocked
   tasks, e.g. `"Relevante Learnings für: T-3-opt Writeback; RAG-Hybrid-Bootstrap; ..."`.
   If no open tasks exist, use the project name + stack keywords as fallback query.
2. Call `mcp__agent-memory-atlas__memory_search_tool` with:
   - `query`: the task-title query
   - `top_k`: 5
   - `source_system`: `"agent-memory"`
3. Filter out entries where `superseded_by` is not null.
4. Include the ≤5 results as KEY LEARNINGS. Prefix the section header with `(RAG)`.
5. On any MCP error or empty result → fall through to heuristic fallback.

**Fallback path — heuristic rank (when MCP unavailable or empty):**

Read `learnings/learnings.json` directly. Sort by salience score; include top 10:

```
score = importance * 0.4 + recency * 0.3 + tag_overlap * 0.3

recency = max(0, 1 - (days_since_last_relevant / 90))
tag_overlap = matching_tags / total_tags  (match against project-context.md stack keywords)
```

- Skip entries where `superseded_by` is not null
- Prefer `layer: "long-term"` over `"short-term"` at equal scores
- Prefix the section header with `(heuristic fallback)`.
- Do NOT update `last_relevant` here — bootstrap is strictly read-only.

**Staleness wrapping — display only, never a write.** When an entry has
`now − last_relevant > 90 days`, annotate visually: `[STALE? last relevant {date}] {text}`.
Do NOT write back confidence or last_relevant — that is memory-maintenance's job.

## Step 2.5: Wiki Context Loading (optional)

Load relevant context from the Obsidian Wiki if configured.

### Prerequisites
Read `.agent-memory/config.json`. If it does not exist or `sync_enabled` is false → **skip this step silently**. No error, no warning.

### Resolution Order
1. Extract `wiki_root`, `project_id`, `project_aliases`, `default_entrypoints` from config.json
2. Validate wiki: check if `$WIKI_ROOT/CLAUDE.md` exists. If not → skip silently.
3. **Project Entity Resolution** — find the project's wiki page:
   - Try `$WIKI_ROOT/wiki/entities/{project_id}.md`
   - If not found: try each alias in `project_aliases` as filename
   - If not found: try Grep for `project_id` in entity filenames
   - If still not found: skip entity, continue with other steps
4. **Entry Points** — load pages from `default_entrypoints`:
   - For each path: check if file exists at `$WIKI_ROOT/{path}`
   - **Skip non-existing entry points silently** (no error — they may be planned for later sprints)
   - Read only existing entry points
5. **Last 3 Session Notes** — find recent sessions for this project:
   - Glob: `$WIKI_ROOT/wiki/queries/*session*{project_id}*.md` OR match `project_aliases`
   - Sort by date (filename prefix), take last 3
   - Read only frontmatter + first 10 lines of body (not full content)
6. **Optional: Rolling Synthesis** — if `$WIKI_ROOT/wiki/synthesis/agent-learnings-aktuell.md` exists, read last 20 lines

### Limits
- **Max 5 pages total** loaded in this step (entity + entry points + sessions + synthesis)
- No brute-force search over the whole vault
- No deep source pages unless explicitly listed as entry point
- This step must complete in < 3 seconds

### Briefing Extension
Add a `WIKI CONTEXT` block to the briefing output (Step 4):

```
WIKI CONTEXT
  Entity: [[wiki/entities/{slug}]] (updated: {date})
  Sessions: {n} (last: {date} — {summary})
  Patterns: {list of high-confidence patterns from entity page}
  Docs: {count} Claude Code Sources available
```

If wiki is not configured or unreachable: omit this block entirely. Do NOT output "Wiki not found" — just skip.

### Cross-Vault-Enrichment (RAG, optional)

After loading the wiki pages above, query the Atlas MCP for cross-vault ideas relevant to today's tasks:

1. Use the same task-title query built for Learnings Retrieval (Step 2).
2. Call `mcp__agent-memory-atlas__memory_search_tool` with:
   - `query`: task-title query
   - `top_k`: 2
   - `scope`: `"project:agent-lab"`
3. On success: append to the WIKI CONTEXT block:
   `  Ideas: {title1}; {title2} (agent-lab)`
4. On error or empty result: skip silently.

If Atlas MCP is unavailable: skip the entire Cross-Vault-Enrichment silently.

## Step 3: Health Checks

Validate the memory system integrity:

### File Existence Check
Verify these core files exist:
- `session-summary.md`
- `identity/soul.md`
- `identity/user.md`
- `context/project-context.md`
- `iterations/iteration-log.md`
- `iterations/errors.json`
- `patterns/patterns.json`
- `quality/quality-score.json`

Missing files → warn user, suggest which skill creates them.

### JSON Validity Check
For each JSON file loaded: if parse fails → rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user.

### Scaling Guards
- `errors.json` > 50 entries → warn: "Error log is large ({n} entries). Consider archiving with iteration-logger."
- `learnings/learnings.json` > 100 entries → warn: "Learnings log is large ({n} entries). Consider pruning during wrap-up."
- `decisions.json` > 50 active entries → warn: "Many active decisions ({n}). Review for superseded entries."
- `iteration-log.md` > 100 entries → warn: "Iteration log is very long. Archive recommended."

## Step 3.5: Sharepoint-Pull (Cross-Device)

If the Google-Drive Sharepoint is mounted (`G:\Meine Ablage\dynamic-AI\dynamic_sharepoint`), run a read-only pull-check to surface what other agents/devices changed:

```
powershell -File "${CLAUDE_PLUGIN_ROOT}/skills/session-bootstrap/scripts/sharepoint-pull-check.ps1" -Since "<last-session-timestamp>"
```

Use the timestamp from the last `session-summary.md` as `-Since`; omit `-Since` to default to the last 3 days. Fold the finding (conflict-files, changed files, open handoffs from other agents, index-drift) into the briefing in 1-3 lines.

- **Conflict-files found** → STOP, point to `00_INBOX/_conflicts/`, do NOT read them as truth.
- **Path not mounted** (script exits with "STOP: Sharepoint-Pfad nicht gefunden") → skip this step silently, no error.

This is read-only. The matching push-side lives in `wrap-up`.

## Step 4: Produce Briefing

Output format (adapt content, keep structure concise):

```
SESSION BRIEFING — {project name}
{date}
---

HANDOFF (central)
  {Agent}: {project} — {date}
  {1-2 lines: what was done, key outcome}
  {if different project: "Context switch: last work was in {project}, now in {current project}"}
  {omit this block entirely if central handoff doesn't exist or is older than local summary}

CROSS-PROJECT (status board)
  This project: {1-line current state from the matching section in cross-project-status.md}
  Notes: {any "Cross-Project Notes" items relevant for ALL projects}
  {omit this block entirely if cross-project-status.md doesn't exist or has nothing relevant}

LAST SESSION (this project)
  {2-3 lines from LOCAL .agent-memory/session-summary.md}
  Next steps: {open/blocked items from context/open-tasks.json; fallback: summary "Next Steps" if the file is missing/empty}
  {if no local summary exists: "No previous session in this project."}

PROJECT STATUS
  {1-2 lines from project-context.md}
  Stack: {compact tech stack}

KEY LEARNINGS (top 5 via RAG · fallback: top 10 heuristic)
  {(RAG) or (heuristic fallback) results — show [ID] importance text}
  {omit if no learnings available}

ACTIVE WARNINGS
  {high-confidence patterns (confidence >= 0.7, occurrences >= 3)}
  {last 3 unresolved errors}
  {quality score trends: improving/declining/stable}

STATISTICS
  Iterations: {n} | Patterns: {n} | Errors: {n}
  Test Health: {score}/100 | Code Quality: {score}/100

HEALTH
  {any missing files or scaling warnings}
---
```

**Keep the briefing under 15 lines.** Do NOT dump file contents — summarize.

## Step 5: Identify Active Warnings

Scan `patterns.json` for patterns that need attention:

- `confidence >= 0.7` AND `occurrences >= 3` → include in ACTIVE WARNINGS
- Anti-patterns whose `tags` overlap with the current project's stack → highlight
- Last 3 errors from `errors.json` that don't match any pattern → flag as "Potential new pattern"

## Step 6: Recommend Next Steps

Based on the briefing, suggest 2-3 concrete actions:

```
RECOMMENDED NEXT STEPS
  1. {open/blocked tasks from context/open-tasks.json — highest priority first}
  2. {[cross-project] items from the central handoff that apply to this project}
  3. {from pattern warnings or quality alerts}

  Ready — was steht heute an?
```

**Priority:** Local `context/open-tasks.json` comes first — it owns this project's next steps. Then `[cross-project]` items from the central handoff. Then system-level warnings. Deduplicate: if an item appears both locally and centrally, show it ONCE (local wording wins).

## Step 6.5: Soul Candidate Gate (the single read-only exception)

`wrap-up` proposes identity changes into `identity/soul-candidates.md` but never writes
`soul.md` autonomously (Stufe B). This step surfaces those proposals for a one-line gate.

1. Read `identity/soul-candidates.md`. If it is missing or only the empty stub
   (`*Keine offenen Kandidaten.*`) → skip silently, nothing to show.
2. If it has open candidates, add ONE line to the briefing:
   `SOUL CANDIDATES: {n} warten — übernehmen? [j/n]`
3. **Only on an explicit `j`** from the user: merge the candidates into `soul.md` in a single
   write, append a `field: soul` entry to `identity/user-changelog.json` (audit/rollback), and
   reset `soul-candidates.md` to the empty stub.
4. On `n`, no answer, or anything else: do nothing — candidates stay queued for next time.

This confirmed soul.md write is the **one and only** exception to bootstrap's read-only rule.
It is user-triggered (gated on `j`), never autonomous, and only touches `soul.md` +
`user-changelog.json` + the candidate queue — nothing else. The briefing read-path itself
stays strictly read-only.

## Error Handling

- Missing `session-summary.md`: "No previous session found" — continue
- Missing `soul.md` or `user.md`: trigger `/agentic-os:init` suggestion
- Corrupt JSON: backup + recreate + warn
- Missing `.agent-memory/`: suggest `/agentic-os:init`

## What NOT to Do

- Do NOT dump full file contents to the user
- Do NOT write to any files (bootstrap is read-only) — the SINGLE exception is the
  user-confirmed soul.md write in Step 6.5, which happens only on an explicit `j`
- Do NOT scan skill registries or build context matrices (Claude already knows available skills)
- Do NOT estimate token budgets (unreliable, leads to false warnings)
- Do NOT call sync-context (removed — no auto-sync on start)
- Do NOT take more than 15 seconds for the entire bootstrap
