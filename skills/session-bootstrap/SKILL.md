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
  version: '3.1'
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

### (b) Cross-project status board — section extract only

3. From `C:\Users\domes\AI\cross-project-status.md` (the **status board**) load ONLY
   two sections — do **NOT** read the full file (it grows with every project and costs
   thousands of tokens): use Grep with context (`-A 6`) to extract (i) the
   `## {current project}` section and (ii) the `## Cross-Project Notes` block.
   Other projects' sections are irrelevant for this session's briefing.

**Rules:**
- The central handoff (a) is authoritative for "what happened last". The status board (b) is authoritative for "where does each project currently stand".
- If the central handoff is **newer** than the local `.agent-memory/session-summary.md`, the central handoff takes precedence for the LAST SESSION block in the briefing
- If the central handoff references a **different project** than the current one, note this in the briefing ("Last handoff was from project X — switching context to Y")
- From the status board, only the two extracted sections matter: the **current** project's section and `## Cross-Project Notes`.
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
6. Learnings — via RAG-Hybrid retrieval below (do NOT full-read learnings.json)
7. **`iterations/errors.json`** — last 3 entries only (tail, not full load)
8. **`working/current-session.json`** — if exists, resume working memory from interrupted session
9. **`context/open-tasks.json`** — open/blocked tasks (SSoT for next steps; feeds Step 6)

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

Do NOT read learnings.json into context (it can be 2k+ words). Run the deterministic
ranking script instead and use its ≤10 output lines directly:

```
python "${CLAUDE_PLUGIN_ROOT}/scripts/learnings_top.py" .agent-memory/learnings/learnings.json --top 10 --tags {stack-keywords,comma-separated}
```

(Formula inside the script: `importance*0.4 + recency*0.3 + tag_overlap*0.3`, skips
superseded entries.) Prefix the briefing section header with `(heuristic fallback)`.
If python is unavailable: read only the LAST 15 entries of learnings.json and pick by
importance.

**Staleness wrap (staleness-wrap) — display only, never a write.** Entries with
`now − last_relevant > 90 days` are annotated `[STALE? last relevant {date}] {text}` —
a read-time annotation that only marks, never mutates. Do NOT decay/write confidence
or last_relevant — that is memory-maintenance's job; bootstrap is strictly read-only.

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
   - **Read at most the first 80 lines** of the entity page (frontmatter + summary +
     patterns) — entity pages are uncapped in length and can cost 2k+ tokens full-read
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

Missing files → warn user, suggest which skill creates them.

### JSON Validity Check
For each JSON file loaded: if parse fails → rename to `{file}.corrupt.bak`, create fresh with default (`[]` or `{}`), warn user.

### Scaling Guards (delegated to threshold SSoT)
Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-thresholds.sh" .agent-memory`. Exit 10 →
include its `THRESHOLD:` lines under HEALTH in the briefing. Exit 0 → no scaling warnings.
(Thresholds live ONLY in that script — shared with wrap-up Step 9 and memory-maintenance.)

### Recovery Detection (recovery-detect) — read-only

Detect sessions that ended WITHOUT consolidation (crash, closed window, skipped
wrap-up). Sources: `working/dirty-*.json` (PostToolUse dirty-tracker hook) and
`consolidation-marker.json` (wrap-up Step 9.5).

1. List `working/dirty-*.json` with `dirty: true`.
2. Ignore files whose `updated` is younger than **30 minutes** — that is most likely a
   session running in parallel RIGHT NOW, not a crash. Never flag it.
3. Every remaining dirty file is an **un-consolidated session**. For each, extract:
   `session_id` (short), `updated`, `write_count`, up to 3 `touched_files`.
4. Cross-check `consolidation-marker.json`: if its `last_wrapup` is NEWER than the
   dirty file's `updated`, downgrade to a one-line note (work probably consolidated
   by a later session's wrap-up; the flag survived a crash between edit and marker).
4b. **Tail-write downgrade (wrap-up's own late writes):** if the dirty file carries
   `last_consolidated_at` (hook preserves the consolidation fact on re-dirty) AND
   `writes_since_consolidation <= 5` AND `updated` is within **15 minutes** of
   `last_consolidated_at` AND the `session_id` appears in the marker's
   `consolidated_sessions`, downgrade to a one-line note: the session WAS wrapped
   up; the flag was re-set by the wrap-up's own post-marker writes (native memory,
   handoff files). The note MUST still name the count and the tail-written files
   (`{n} Writes nach Konsolidierung, z.B. {file}`) — downgraded, never silent.
   More writes, or a larger gap between consolidation and last write (= real work
   after wrap-up, possibly crashed), → keep the full RECOVERY block.
5. Output a RECOVERY block in the briefing (Step 4) and recommend the fix:

```
RECOVERY
  Unkonsolidierte Session {sid-8} vom {updated}: {write_count} Writes,
  z.B. {file1}, {file2}
  → Empfehlung: wrap-up ausführen (Step 1.5 harvestet aus touched_files + git)
```

This step is strictly read-only: bootstrap NEVER resets dirty flags, never deletes
dirty files, never writes the marker — that is wrap-up Step 9.5's job. If the user
declines recovery, the dirty files simply stay and are re-reported next session.

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

STATISTICS
  Iterations: {n} | Patterns: {n} | Errors: {n} | Learnings: {n}

HEALTH
  {any missing files or THRESHOLD lines}
  {identity starvation warning from Step 6.5, if any}

RECOVERY
  {un-consolidated sessions from Recovery Detection, with wrap-up recommendation}
  {omit this block entirely if nothing was flagged}
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

## Step 6.5: Identity Gates + Starvation Check

`wrap-up` grows identity via queues (`working/user-candidates.json`,
`identity/soul-candidates.md`) but never writes `soul.md` autonomously (Stufe B). This
step surfaces both queues and detects a starving pipeline.

### (a) Soul candidate gate (the single write exception)

1. Read `identity/soul-candidates.md`. Missing or empty stub
   (`*Keine offenen Kandidaten.*`) → skip silently.
2. Open candidates → ONE briefing line: `SOUL CANDIDATES: {n} warten — übernehmen? [j/n]`
3. **Only on an explicit `j`**: merge candidates into `soul.md` in a single write, append
   a `field: soul` entry to `identity/user-changelog.json` (audit/rollback), reset
   `soul-candidates.md` to the empty stub.
4. On `n`/no answer/anything else: do nothing — candidates stay queued.

This confirmed soul.md write is the **only** exception to bootstrap's read-only rule:
user-triggered, never autonomous, touches only soul.md + changelog + queue.

### (b) User candidate fallback gate

Read `working/user-candidates.json`. If any candidate meets wrap-up's promotion gate
(status `confirmed`, or `inferred` with occurrences >= 2 and confidence >= 0.6) but is
not yet `promoted` — wrap-up apparently missed it. Add ONE briefing line:
`USER CANDIDATES: {n} promotable (z.B. {id}: {key}) — jetzt übernehmen? [j/n]`
On explicit `j`: perform wrap-up Step 6.3's promotion (changelog first, then user.md,
then mark `promoted`). Same audit trail, same trust rules.

### (c) Identity starvation warning (read-only)

Compare `max(last_seen)` across user-candidates.json with the local session-summary
date. If the last identity observation is 2+ sessions old (or the file is empty while
sessions exist), add to HEALTH:
`Identity-Scan zuletzt {date} — Pipeline verhungert, wrap-up Step 6 prüfen`

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
