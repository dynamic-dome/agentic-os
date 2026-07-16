---
name: wrap-up
description: |
  Wraps up a coding session — summarizes work, extracts learnings, grows the
  identity files (user.md/soul-candidates) via gated candidate queues, updates
  session summary + cross-project handoff, suggests a git commit. Use at the end
  of a session, before a context handoff, or when switching projects.

  Trigger phrases (session-specific only):
  "wrap up", "end session", "save session", "session handoff",
  "finish for today", "I'm done for today", "close session".
user_invocable: true
model: sonnet
effort: medium
metadata:
  author: agentic-os
  version: '4.1'
  part-of: agentic-os
  layer: core
---

# Session Wrap-Up

End-of-session sequence. Summarizes work, extracts learnings, grows identity,
prepares the next session.

## Long-Term Memory Routine (long-term-memory-routine)

After every substantial task or session, consolidate durable knowledge into the
central .agent-memory/ knowledge base instead of leaving it in the conversation:

- Work iterations → `iterations/iteration-log.md` via `iteration-logger`
- Reusable learnings → `learnings/learnings.json` + `learnings.md`
- Durable decisions → `context/decisions.json` via `context-keeper`
- Open next steps → `context/open-tasks.json`
- Identity observations → `working/user-candidates.json` → `identity/user.md` / `identity/soul-candidates.md`
- Handoff snapshot → `session-summary.md` + central handoff

Reject trivial facts. Manual-only — no hook triggers this automatically.

## Step 0: Deterministic Preflight (stage0-preprocess)

Run the stage-0 preprocessor FIRST — it gathers every mechanical session fact
without model work:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/preprocess_state.py" .agent-memory --session-id <session-id>
```

Use its JSON output (`changed_files`, `git_diff_summary`, `threshold_events`,
`validation_errors`, `open_tasks`, state hashes) as the PRIMARY data source
for all following steps. If `validation_errors` is non-empty, surface them in
the summary instead of re-validating files by reading them.

(context-diet) Do NOT systematically re-read the session transcript or full
memory files: work from the preprocess state object plus the conversation
context you already hold. Fall back to targeted lookups ONLY for single
unresolved points — never a full re-scan. Track roughly how many bytes of
files you actually read this run; Step 9.5 logs that number.

## Step 1: Gather Session Data

1. `.agent-memory/iterations/iteration-log.md` — entries from today
2. `git diff --stat` + `git log --oneline -5` (if git available)
3. `.agent-memory/quality/test-results.json` — latest entry (if present)
4. `.agent-memory/iterations/errors.json` — entries from today
5. `.agent-memory/working/dirty-*.json` — mechanical dirty-state files written by the
   PostToolUse dirty-tracker hook (`dirty: true` = un-consolidated work; `touched_files`
   is hard evidence of what was edited, independent of conversation memory)

If iteration-log.md has no entries from today: do NOT skip ahead — run Step 1.5 first.
Only if Step 1.5 also yields nothing: note "No iterations in this session", proceed to
Step 5 (skip Steps 2–4). Steps 6/6.x run regardless.

## Step 1.5: Session-Harvest — Retro-Logging (session-harvest)

Users who run ONLY bootstrap + wrap-up never call iteration-logger mid-session —
without this step the pattern pipeline starves.

**Condition:** no iteration-log entry for today AND the session did substantial work
(today's commits in `git log --oneline --since=midnight`, working-tree changes,
`touched_files` in any `working/dirty-*.json` with `dirty: true`, or completed
features/fixes/refactors visible in the conversation).

**Stale-session harvest:** a dirty file whose `session_id` is NOT this session
(crashed or abandoned session) is still evidence — harvest its `touched_files` the
same way, but mark reconstructed iterations with `(recovered from session {id})`.
Do not invent details the files and git history cannot support.

1. Reconstruct 1–5 **distinct iterations** from conversation + git evidence
   (feature/bugfix/refactor/config/docs/test — distinct approaches, not individual edits).
2. For each: **invoke the `iteration-logger` skill** with type, summary, files, errors +
   root cause, test status. iteration-logger **owns all writes** to `iteration-log.md`,
   `errors.json`, `working/current-session.json` — wrap-up never writes those directly.
3. Trivial session (pure lookup/discussion, no artifacts): skip silently.
4. After harvesting, re-run Step 1 so Steps 2–4 see the fresh entries.

## Step 2: Summarize Work Done

- Count: iterations, errors, tests run
- List: files changed (git diff or iteration log)
- Note: quality/test trend if data exists

## Step 3: Extract Learnings

A learning is worth recording if it would prevent a future mistake, reveals something
non-obvious, or documents a decision rationale not in the code. NO trivial facts.

### 3a: Dedup Check

Read `learnings/learnings.json`; normalize new text (lowercase, strip punctuation),
tokenize, Jaccard similarity against existing entries. **>= 0.6 → duplicate**: update
`last_relevant` on the existing entry, skip creation.

### 3a.2: Cross-Session RAG-Check (Atlas)

Before appending a candidate, ask the Atlas memory RAG whether an equivalent learning
already exists across sessions/projects:

- **Load the tool ONCE per wrap-up run** (it is deferred):
  `ToolSearch("select:mcp__agent-memory-atlas__memory_search_tool")` — one call for the
  whole run, never per learning.
- **One query per candidate, capped:** `memory_search_tool("{learning text}",
  source_system="agent-memory", top_k=3, snippet_len=200)`. Never more than one query
  per candidate — wrap-up runs at session end where context is scarce.
- **The duplicate verdict is yours, not the score's:** read the hits; discard the
  candidate ONLY if a hit states the same core insight. Do NOT apply a numeric score
  threshold — the RAG returns ranking scores (RRF), not similarity measures.
- **On a confirmed duplicate:** if the matching entry lives in THIS project's
  `learnings.json`, update its `last_relevant` (same handling as 3a). If the hit comes
  from another project, discard the candidate — it is already knowledge there, and a
  `cross_project` re-capture would be noise.
- **Fail-soft, three layers (never block wrap-up):** (a) ToolSearch does not find the
  tool (project/user without the Atlas MCP) → skip this step silently; the local Jaccard
  check remains the only dedup instance. (b) The FIRST tool call fails (daemon down) →
  fast-skip the RAG check for the REST of the run, no retries (each refused connection
  costs a full socket timeout). (c) Anything else: warn and continue — never block
  wrap-up.
- **Complementary, not redundant:** the RAG index only sees learnings after the next
  index rebuild. Duplicates created earlier in the SAME session are caught only by the
  local Jaccard check (3a). Neither mechanism replaces the other — do not "optimize
  away" 3a because 3a.2 exists.

### 3b: Score and Append

```json
{
  "id": "L{next_number}", "date": "{YYYY-MM-DD}", "text": "{insight with context}",
  "importance": 3, "tags": ["tag1", "tag2"], "layer": "short-term",
  "superseded_by": null, "last_relevant": "{YYYY-MM-DD}",
  "derived_from": ["iteration-{n}", "E{id}"], "review_after": "{YYYY-MM-DD}"
}
```

importance: 5 = prevents data loss/security issue · 4 = prevents multi-attempt debugging ·
3 = non-obvious behavior · 2 = workflow optimization · 1 = trivia.

**`derived_from` (provenance, memideaspec §7.4):** IDs of THIS session's origins —
iteration numbers from `iteration-log.md` (`iteration-{n}`), error IDs from
`errors.json` (`E{n}`), decision IDs (`D{n}`). No traceable origin → `[]`. Never
invent provenance; an honest empty list beats a guessed reference.

**`review_after` (staleness contract):** date when the learning's validity should be
re-checked; default = `date` + 90 days (matches the bootstrap STALE threshold). Set
ONCE at creation — bootstrap and memory-maintenance read it, wrap-up never updates it
on existing entries.

Backward compatibility: entries created before v4.4.0 lack both fields — leave them
as-is (consumers use `.get()`); do NOT backfill.

### 3c: Regenerate learnings.md

Regenerate `learnings.md` from the JSON (header `*Auto-generated from learnings.json —
do not edit directly.*`; entries `- [{id}] ({'*' * importance}) {text}` grouped by date).

### 3d: Bridge candidates gate (bridge-gate, T-14)

Curated Claude→Codex bridge (design: membrain/membridge.md). Canonical store is
learnings.json (`bridge_status`); the AGENTS.md block is a projection.

1. Every learning written this session with `importance >= 4` gets
   `"bridge_status": "candidate"` (additive field; older entries without it are
   untouched, never backfill).
2. If ANY candidates exist store-wide (this session's or earlier declined ones),
   emit ONE line: `BRIDGE CANDIDATES: {n} — nach AGENTS.md projizieren? [j/n]`
   listing id + first ~10 words each.
3. **Only on an explicit `j`** (all) or a listed subset (`j L26 L27`): set those
   entries to `"bridge_status": "approved"`, then run the projection:
   `python scripts/bridge_projection.py .agent-memory --agents-md <project-root>/AGENTS.md`
   (workspace store `~/AI/.agent-memory` → `~/AI/AGENTS.md`). Report its one-line
   output verbatim.
4. On `n`/no answer: candidates stay queued — next wrap-up asks again. Never
   promote silently; every line in AGENTS.md costs Codex context on EVERY start.
5. Rollback: reset `bridge_status`, re-run the projection (block re-renders or
   disappears).

### 3.5: Layer Lifecycle

- short-term older than 30 days: `last_relevant` within 30 days → promote to
  `"long-term"`; otherwise → `layer: "archive-candidate"`.
- Consume `working/current-session.json`: dedup-check each `learnings_draft`, promote
  worthy ones (short-term), discard trivia, reset the file. Promoted drafts get
  `derived_from` pointing at their source iteration if the draft names one, else `[]`.
- New learning contradicts an old one → set `superseded_by` on the old entry.

## Step 4: Pattern Extraction

If 3+ new iterations were logged this session: trigger `pattern-extractor`
(lightweight — analyzes only the new data). Fewer than 3: skip.

## Step 4.5: Decision Scan (decision-scan)

Scan the session for **decisions of record**: new/changed dependencies, architecture
choices, storage/format changes, ownership/policy decisions ("X is SSoT", "no auto-sync").
If found: **invoke `context-keeper`** with the list — it owns `decisions.json` and
`project-context.md`. Trust boundary: conversation + repo evidence only. One-off
implementation details are NOT decisions — when in doubt, skip. None found: skip silently.

## Step 5: Update session-summary.md

(delta-update) Update session-summary.md as a DELTA against the existing
file: rewrite only sections whose content actually changed this session
(added / updated / resolved items) and keep unchanged sections untouched —
do not regenerate the whole file from scratch.

Overwrite `.agent-memory/session-summary.md` (**max 30 lines**):

```markdown
# Last Session

*Date: {YYYY-MM-DD HH:MM}*
*Agent: Claude Code*

## What Was Done
- {completed work, max 10 bullets}

## Open Items
- {unfinished work, blockers}

## Next Steps
1. {highest priority} 2. {second} 3. {third}

## Statistics
- Iterations: {n} | Errors: {n} | New Patterns: {n}

## Active Warnings
- {high-confidence patterns / declining trends, if any}
```

## Step 5.5: Persist Next Steps to open-tasks.json (open-tasks-ssot)

`context/open-tasks.json` is the single source of truth (SSoT) for this project's
open tasks; Step 5's "Next Steps" is a RENDERING of it, never the reverse.

1. Read it (treat missing as `[]`).
2. Every Step-5 Next-Step/Open-Item without a same-title entry (case-insensitive) →
   append `{"id": "T-{next}", "title", "status": "open"|"blocked", "created", "updated",
   "source": "wrap-up", "cross_project": false}`.
3. Items this session completed → `"status": "done", "updated": today`. Never delete —
   memory-maintenance archives.
4. `"cross_project": true` ONLY for items the user explicitly flagged — sole feed for
   the central handoff's `[cross-project]` lines.

## Step 6: Identity Growth (user.md + soul candidates)

The identity pipeline starves when this step is skipped or runs silently — it is the
ONLY producer of identity observations in the whole system. It is therefore mandatory,
checklist-driven, and always reports (Step 6.6).

### 6.1 Harvest — checklist scan (identity-harvest) (user-growth)

Scan the WHOLE session against this concrete checklist (do not do a vague "scan"):

- [ ] Did the user **correct** the agent's behavior or output style? (what, how often?)
- [ ] Did the user state an explicit **preference or rule** ("ich will", "immer", "nie",
      "mach das künftig so")?
- [ ] Did the user reveal a **workflow habit** (delegation style, review rituals,
      commit/push conventions, tool choices)?
- [ ] Did the user **confirm** a non-obvious approach the agent proposed?
- [ ] Did the user express a **communication demand** (brevity, language, tone,
      begründungspflicht)?

Distinguish stable signals from `signal:mood` (frustration, one-off reactions) — moods
are observed but NEVER promoted.

**Trust boundary (hard) (trust-boundary):** candidates may ONLY originate from the
user's direct conversation. NEVER from web/docs/NotebookLM/Wiki content —
`trust_source` must be `conversation`; anything else is discarded (memory-poisoning defense).

### 6.2 Enqueue into `working/user-candidates.json`

New observation → new candidate; same `key` exists → increment `occurrences`, update
`last_seen`, raise `status` if warranted. Schema:

```json
{
  "id": "UC{n}", "key": "kebab-case-key",
  "observation": "{1-line observed preference}",
  "status": "observed", "signal_type": "preference",
  "confidence": 0.5, "occurrences": 1,
  "evidence": ["session {YYYY-MM-DD}"],
  "first_seen": "{date}", "last_seen": "{date}",
  "trust_source": "conversation"
}
```

Classification: observed / inferred / confirmed — **observed** = seen once (queue-only),
**inferred** = agent-derived (uncertain), **confirmed** = explicitly confirmed by the
user OR the same signal repeated 2×.

### 6.3 Promote to user.md — FULL queue re-review (queue-re-review)

Review **every** candidate in `user-candidates.json`, not only ones touched this
session (an enqueue-only queue is how promotions starved for weeks). Promote when
**confirmed** OR (**inferred** AND `occurrences >= 2` AND `confidence >= 0.6`):

1. FIRST append an audit entry to `identity/user-changelog.json`
   (`{ts, field, old_value, new_value, candidate_id, evidence}`) — changelog before edit.
2. Then edit the matching user.md section (Preferences / Work Style / Known Corrections).
3. Set candidate `status: "promoted"`.

`signal:mood` is NEVER promoted. One-off corrections stay `observed`.

### 6.4 Soul candidates — two feeder paths (soul-growth)

Never write `soul.md` here (Stufe B: propose, don't commit — the write happens
only via session-bootstrap's explicit `[j/n]` gate). Append proposals (proposal +
evidence + date) to `identity/soul-candidates.md` from EITHER path:

- **Direct:** stable identity signals — hard "won't" lines, changed communication
  defaults, guard rails the user demands repeatedly.
- **Escalation from user.md (escalation-path):** a promoted user.md entry that (a) was
  re-confirmed in 2+ later sessions after promotion, OR (b) belongs to the categories
  communication style / guard rail / decision-authority — these describe how the AGENT
  should behave and belong in soul.md, not the user profile.

Same trust boundary as 6.1. Anti-bloat: if soul.md is near its 80-line cap, note it in
the candidate so the user can prune on merge.

### 6.5 Identity status line — MANDATORY (identity-visible)

Identity growth never skips silently (same rule as wiki-sync-visible — the silent skip
is how the pipeline starved unnoticed for months). Emit exactly ONE line in EVERY
wrap-up, even when nothing was found:

`Identity: {n} beobachtet, {m} → user.md promotet, {k} soul-candidates; Queue: {q} offen{, ältester promotable: {id}}`

## Step 7: Optional NotebookLM Sync

If `.agent-memory/knowledge/notebook-registry.md` lists a notebook AND 3+ meaningful
learnings were extracted: offer sync via the `notebooklm` user-skill. Otherwise skip.

## Step 7.5: Obsidian Wiki Sync (Conditional)

Delegates to the `obsidian-sync` skill — do NOT duplicate its logic.

### Trigger Conditions (wiki-sync-gate)
1. **Hard gate:** `.agent-memory/config.json` exists AND `sync_enabled: true`.
2. **Substantial:** ANY of — 1+ iteration logged/harvested today, OR today's commits
   exist (`git log --oneline --since=midnight` non-empty), OR a learning with
   importance >= 4, OR a new decision landed. A single real iteration or any commit
   today already warrants a note; pure lookup/discussion sessions are not substantial.

Both hold → invoke `obsidian-sync` (it owns all wiki writes).

**Always report (wiki-sync-visible)** — wiki sync never skips silently; emit exactly
ONE status line in every case:
- `Wiki-Sync: Note geschrieben → wiki/queries/{file} ({n} pages touched)`
- `Wiki-Sync: übersprungen — sync_enabled false oder keine config.json`
- `Wiki-Sync: übersprungen — Session nicht substanziell`
- Failure: `Wiki-Sync fehlgeschlagen: {reason}. Session data is safe in .agent-memory/.`
  (warn and continue — never block wrap-up).

## Step 7.6: Central Cross-Project Handoff (SESSION-WORKFLOW)

Write BOTH cross-project files following **`references/handoff-template.md`** (SSoT for
the prepend algorithm, dedup rules, hard cap, and both templates — read it before
writing):

**Read-then-write guard (T-19, mandatory for 7.6a/7.6b):** both files are shared
with parallel sessions and other agents — guard every read-modify-write cycle with
`scripts/handoff_write_guard.py` (plugin root):

1. Right after READING a surface:
   `python scripts/handoff_write_guard.py snapshot "<file>" --state .agent-memory/working/handoff-guard-<session-id>.json`
   (session-id from Step 0 preprocess; both files may go in ONE snapshot call)
2. Immediately BEFORE writing it: same command with `check`.
   - Exit 0 → write.
   - Exit 20 (DRIFT — someone wrote in between) → re-read the file, MERGE your block
     into the new content (never overwrite the foreign change), re-snapshot, then write.
   - Exit 21 (no snapshot) → you skipped the read; read + snapshot first.
3. Guard failures are never silent: report one line per drift
   (`Handoff-Guard: Drift auf {file} — re-read+merge ausgeführt`).

- **7.6a Central handoff** `C:\Users\domes\AI\.agent-memory\session-summary.md`:
  PREPEND new block, demote old TOP. **Ownership-dedup (handoff-dedup):** delete older
  blocks of the SAME project — the file keeps at most one block per project; hard cap
  5 blocks total. **Pointer rule (next-steps-pointer):** Naechste Schritte carries ONE
  pointer to the local open-tasks.json (open count + top item) plus ONLY
  `[cross-project]`-flagged items — never a copy of project next steps. Directory
  missing → skip silently.
- **7.6b Status board** `C:\Users\domes\AI\cross-project-status.md`: replace ONLY this
  project's section (~5 lines), never touch other sections.
- **7.6c Sharepoint delta** (only if this session touched
  `G:\Meine Ablage\dynamic-AI\dynamic_sharepoint`): frontmatter-check new MD files
  (Manifest §4), hygiene-sweep (§7), INDEX.md update, ONE delta-handoff under
  `01_HANDOFFS/`, one `Sharepoint touched`-line in 7.6a's Wichtige Pfade. Not
  touched/not mounted → skip silently, no empty handoff.

## Step 8: Suggest Git Commits (Optional)

If there are uncommitted changes:

1. `git status --short` — stage surgically, never `git add -A` (foreign drift stays out).
2. Suggest TWO separate commits where applicable:
   - **Code commit** — conventional message (feat/fix/refactor/test/chore).
   - **Memory commit** — `.agent-memory/` changes (`chore(memory): session {date}`).
     The auto-commit command excludes `.agent-memory/` by design; without this offer,
     memory growth silently accumulates as uncommitted drift for weeks.
3. Show the user what would be committed; **wait for confirmation** — never commit
   without explicit approval.

## Step 9: Memory Maintenance (Delegated)

Run `bash scripts/memory-thresholds.sh` (plugin root; threshold SSoT shared with
memory-maintenance). Exit 10 (thresholds exceeded) or explicit user request ("clean
memory", "prune patterns") → invoke the `memory-maintenance` skill after Step 8; it
owns its own report and error handling. Exit 0 → skip entirely.

## Step 9.5: Consolidation Marker + Dirty Reset (consolidation-marker)

This step makes consolidation VERIFIABLE: bootstrap and session-start.sh detect
crashed sessions by "dirty file exists but no matching marker". It is mandatory
and runs LAST — only after Steps 1–8 actually completed.

1. Read all `.agent-memory/working/dirty-*.json` with `dirty: true` (their
   `touched_files` were already used as evidence in Steps 1/1.5).
2. Overwrite `.agent-memory/consolidation-marker.json` (single file, no history —
   git history preserves older markers):

```json
{
  "last_wrapup": "{ISO timestamp}",
  "consolidated_sessions": ["{session_id}", "..."],
  "iterations_logged": 0,
  "learnings_added": 0,
  "touched_files_seen": 0
}
```

3. For EVERY dirty file consumed: set `dirty: false`, `consolidated_at: {ISO timestamp}`,
   `consolidated_by: "wrap-up"`. Do NOT delete the files — `memory-maintenance` archives
   consolidated dirty files older than 7 days.
4. **Self-healing rule (parallel sessions):** if a consumed dirty file belonged to a
   session that is still running in parallel, its next Write/Edit simply re-sets
   `dirty: true` via the hook — consolidating it here is harmless. Never try to guess
   which sessions are "still alive". Re-dirtying preserves the consolidation fact
   (`last_consolidated_at/by` + `writes_since_consolidation`), so post-marker tail
   writes of THIS wrap-up (native memory, handoff files) never masquerade as a
   crashed session in the next bootstrap.
5. On any failure in Steps 1–8: do NOT write the marker and do NOT reset dirty flags —
   an honest dirty state is exactly what recovery needs.

(cost-trace) Finally, log the run trace and refresh the state hash (both
fail-soft, never blocking):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cost-trace.sh" append --mem .agent-memory \
  --task wrap-up --class cheap-write \
  --context-bytes <approx bytes of files read this run> --escalated <0|1>
python "${CLAUDE_PLUGIN_ROOT}/scripts/preprocess_state.py" .agent-memory --write-hash > /dev/null
```

---

## Escalation Rules (escalation-rules)

This skill runs on the cheap-write model class (SSoT:
`scripts/model-routing.sh`). The following cases must NOT be resolved by this
skill run itself. When one occurs:

1. Append `{"ts": "...", "task": "wrap-up", "reason": "...", "detail": "..."}`
   to `.agent-memory/working/escalations-<session-id>.json` (create as JSON
   array if missing).
2. Emit a visible `ESKALATION: <reason>` line in the output.
3. Leave the decision itself to the next turn on the session model.

Escalate when:
- two active sources contradict each other,
- a change would touch identity or stable user preferences (identity writes
  additionally stay behind the existing [j/n] gates),
- an active decision record would be replaced,
- a pattern would be promoted into a skill or Agentic-OS rule,
- a change is difficult to reverse,
- required sources are missing.

# Handoff Mode (Pre-Compression)

When triggered by long context or explicit handoff request, append to session-summary.md:

```markdown
## Handoff Context
- **Active task**: {what was being worked on right now}
- **Current state**: {done / next}
- **Active patterns**: {top high-confidence patterns}
- **Open questions**: {decisions pending user input}
```

## Error Handling

- `iteration-log.md` missing: create it, note "No previous iterations"
- JSON parse error: rename to `{file}.corrupt.bak`, create fresh, warn user
- `.agent-memory/` missing: suggest `/agentic-os:init`

## What NOT to Do

- Do NOT write `errors.json` (iteration-logger), `patterns.json` (pattern-extractor),
  or `decisions.json` (context-keeper) directly
- Do NOT write soul.md — ever (candidates only; the write is bootstrap's [j/n] gate)
- Do NOT skip Step 6 or its status line — identity growth must be visible
- Do NOT write session-summary.md longer than 30 lines
- Do NOT commit without user confirmation
- Do NOT log trivial "learnings"; do NOT prune skill_candidate patterns
- Do NOT run memory maintenance during an active self-improve loop
  (`improvements/state.json` → `status: "running"`)
- Do NOT delete `working/dirty-*.json` (Step 9.5 flips flags; memory-maintenance
  archives) and do NOT write the consolidation marker when the wrap-up was incomplete
