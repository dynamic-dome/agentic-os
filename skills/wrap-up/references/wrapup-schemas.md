# wrap-up — write-time schemas & templates

Inert JSON schemas and output templates lifted out of `skills/wrap-up/SKILL.md`
under the T-35 redesign rule: **no gate logic leaves the body**. These blocks are
read only when the agent actually WRITES the corresponding artifact — every gate's
trigger and result-contract stay in the body, which points here and loads this file
only at the write step it names.

Design: `memskillredesign.md` / `memevalharness.md` (membrain). The wrap-up gate
inventory (`gate_linkage.py`, 27 gates) and `validate-skills.sh` anchors stay in the
body, never here.

## Learning entry (Step 3b)

Append to `learnings/learnings.json`:

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

## User candidate (Step 6.2)

Enqueue into `working/user-candidates.json` (new observation → new candidate; same
`key` exists → increment `occurrences`, update `last_seen`, raise `status` if warranted):

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

## Consolidation marker (Step 9.5)

Overwrite `.agent-memory/consolidation-marker.json` (single file, no history — git
history preserves older markers):

```json
{
  "last_wrapup": "{ISO timestamp}",
  "consolidated_sessions": ["{session_id}", "..."],
  "iterations_logged": 0,
  "learnings_added": 0,
  "touched_files_seen": 0
}
```

## Local session-summary.md (Step 5)

Overwrite `.agent-memory/session-summary.md` (English headers; **max 30 lines**;
delta-update — rewrite only changed sections):

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

## Handoff Mode (Pre-Compression)

When triggered by long context or explicit handoff request, append to session-summary.md:

```markdown
## Handoff Context
- **Active task**: {what was being worked on right now}
- **Current state**: {done / next}
- **Active patterns**: {top high-confidence patterns}
- **Open questions**: {decisions pending user input}
```
