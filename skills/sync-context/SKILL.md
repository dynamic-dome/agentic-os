---
name: sync-context
description: >
  Manual cross-project sync between local .agent-memory/ and the global
  ~/.claude-memory/global/ store (privacy filter + promotion gate).
  Invoke via /agentic-os:sync-context.
disable-model-invocation: true
model: sonnet
effort: low
metadata:
  author: agentic-os
  version: '3.1'
  part-of: agentic-os
  layer: utility
---

# Cross-Project Sync (Optional, Manual Only)

Bidirectional sync between local `.agent-memory/` and `~/.claude-memory/global/`.

**This skill is never auto-triggered** — `disable-model-invocation: true` enforces it
mechanically: the model cannot invoke it and its description never loads into context.
It runs only via `/agentic-os:sync-context`.

## Prerequisites (Auto-Setup)

Before any sync operation, ensure the global memory infrastructure exists.
This MUST run automatically — do not require the user to set it up manually.

**Required structure:**
```
~/.claude-memory/global/
├── patterns.json    (initialize as [])
├── learnings.json   (initialize as [])
└── projects.json    (initialize as {"projects": []})
```

**Auto-creation logic (run at skill start, before Step 1):**
1. Check if `~/.claude-memory/global/` exists
2. If not, create the directory and all three JSON files with their defaults
3. If directory exists but files are missing, create only the missing files
4. If directory creation fails (permissions) → warn user with exact error, abort gracefully
5. For each existing JSON file, attempt `JSON.parse`:
   - If corrupt (parse fails) → rename to `<filename>.corrupt.bak`, reinitialize with default, warn user
   - Example: `patterns.json` fails → move to `patterns.json.corrupt.bak`, create fresh `[]`

## When to Use

- User wants to import patterns from other projects
- User wants to share this project's learnings globally
- Switching between projects and wanting accumulated knowledge
- User has 3+ active projects and wants to leverage cross-project patterns

## Architecture

```
Project A (.agent-memory/)  ──push──>  ~/.claude-memory/global/  <──push──  Project B
                            <──pull──                            ──pull──>
```

## Step 1: Check Minimum Project Count

Before any sync, verify there are at least 2 projects registered globally:

1. Read `~/.claude-memory/global/projects.json` (create if missing — see Prerequisites)
2. Count entries in the `projects` array
3. If fewer than 2 projects exist → abort with: "SYNC SKIPPED: cross-project sync requires at least 2 projects. Currently only {n} project(s) registered. Run sync again after a second project has been set up."

## Step 2: Determine Direction

From user intent:
- "pull" / "import" / "get" → pull only
- "push" / "share" / "export" → push only
- "sync" / "both" / no direction → bidirectional (pull then push)

## Step 3: Ensure Global Memory Exists (with Error Handling)

Run the auto-setup from Prerequisites:
1. Create `~/.claude-memory/global/` if missing
2. For each of `patterns.json`, `learnings.json`, `projects.json`:
   - If missing → create with default (`[]`, `[]`, `{"projects": []}`)
   - If exists → validate JSON parse
   - If corrupt → backup as `<file>.corrupt.bak`, reinitialize, warn user:
     `"WARNING: ~/.claude-memory/global/<file> was corrupt. Backed up as <file>.corrupt.bak and reinitialized."`
3. If `mkdir` or `write` fails → print error, abort:
   `"ERROR: Cannot create global memory dir: <error>. Sync aborted. Check permissions on ~/.claude-memory/."`

## Step 4: Pull (if applicable)

1. Read project's stack from `.agent-memory/context/project-context.md`
2. Read `~/.claude-memory/global/patterns.json`
3. Filter by matching `stack_tags` (only pull relevant patterns)
4. **Lifecycle filter (pull-lifecycle-filter): pull ONLY entries with `lifecycle: active`.**
   Skip `candidate`, `superseded`, and `archived` entries entirely — a held candidate, a
   recency-superseded fact, or a decayed-out entry must never re-enter a local store.
5. Only pull patterns with `confidence >= 0.5`
6. Merge into local `patterns.json`. Distinguish a **merge** (same fact, more evidence) from
   a **conflict** (contradicting fact in the same scope) — they are resolved differently:

   **Merge (same fact):**
   - Same `id`, compatible content → keep higher confidence, merge `source_projects` and `evidence`.
   - Same description (fuzzy ≥0.6) but different `id` → deduplicate into one entry.
   - Never overwrite local with lower-confidence global for a non-conflicting same fact.

   **Conflict — resolve by recency, NOT confidence (recency-supersession):**
   The scope of a fact is `(type, normalized description/tags)`. There may be at most **one
   `active` entry per scope**. When a new entry **contradicts** an existing active one in the
   same scope (e.g. "use pytest" vs "use unittest" for the same tag-scope):
   - The **newer** entry (by `last_seen` timestamp) wins and stays `active`; the older one is
     marked `lifecycle: "superseded"` with `superseded_by: <new id>` and `superseded_at`.
   - **Never delete** the superseded entry — it stays for audit / "what did we believe before?"
     queries. Resolution happens at **write time**, so reads only ever see one `active` per scope.
   - Confidence does NOT decide a conflict: a stale high-confidence fact must not beat a newer
     one (Mem0 interference). Confidence only ranks NON-conflicting same-fact merges (above).
   - Log every supersession in the Step 6 report.

## Step 5: Push (if applicable)

Source the helpers once: `. scripts/global-schema.sh` and `. scripts/mem-schema.sh`
(the latter provides the `MEM_GLOBAL_DENY_TAGS` denylist that `is_denied()` reads).

1. Read local `.agent-memory/patterns/patterns.json`
2. **Privacy pre-filter (privacy-filter) — runs BEFORE the threshold and gate.** Drop any
   entry where `is_denied(tag)` returns true for ANY of its `tags`, OR whose `signal_type`
   is `"mood"`. These never reach the global store. Count them as `Denied (privacy)`.
   Privacy is checked first on purpose: a denied fact must not survive on the strength of a
   high confidence or occurrence count.
3. **Promotion gate (promotion-gate) — `passes_promotion_gate(confidence, occurrences, |source_projects|)`.**
   An entry is promoted to `lifecycle: active` in the global store ONLY if all three hold:
   `confidence >= 0.6` (the existing push threshold, unchanged) AND `occurrences >= 3`
   (the existing +0.1-boost trigger, now a hard requirement) AND `|source_projects| >= 2`
   (NEW — keeps single-project quirks out of the global layer). An entry that fails the
   gate stays `lifecycle: candidate` (written/kept as candidate, never `active`, and the
   pull-lifecycle-filter never serves it). Report passes as `Promoted` and fails as
   `Candidates held`.
4. **Stamp the global provenance schema (provenance-schema) on every entry written to
   `~/.claude-memory/global/patterns.json`:**
   ```json
   {
     "id": "G-<fact_type>-<3-digit>",          // e.g. G-pattern-001; fact_type ∈ {pattern,learning,preference}
     "value": "<normalized-cleartext description>",
     "fact_type": "pattern",
     "source_project": "<this project>",
     "source_projects": ["<this project>", ...],
     "source_evidence": ["E12", "P003"],        // local evidence/error/pattern ids this came from
     "confidence": 0.72,                          // 0.0..1.0
     "occurrences": 4,
     "first_seen": "<iso>",
     "last_relevant": "<iso>",
     "valid_from": "<= first_seen>",              // valid_until=null ⇔ lifecycle active
     "valid_until": null,
     "lifecycle": "active",                       // ∈ {candidate,active,superseded,archived}
     "scope": "<compute_scope(fact_type, tags)>", // conflict key — max 1 active per scope
     "superseded_by": null,
     "tags": ["windows", "shell"]
   }
   ```
   Build `id` from `fact_type` + next free 3-digit counter; `scope = compute_scope(fact_type, tags)`;
   `valid_from = first_seen`; `value = normalize(description)`. Learnings carry `source_projects`
   (a list) — never the legacy singular `source_project` alone.
5. Merge into `~/.claude-memory/global/patterns.json`:
   - Increment `occurrences` on merge
   - Merge `source_projects` arrays
   - Patterns with `occurrences >= 3` across projects get confidence boost (+0.1)
   - Conflict resolution is the v3.3.1 recency-supersession (Step 4) — do NOT duplicate it here.
6. Push generalizable learnings from `.agent-memory/learnings/learnings.md` to global,
   under the same privacy pre-filter and provenance schema.

## Step 6: Update Registry

Update `~/.claude-memory/global/projects.json` with:
- Project name and path
- Last sync timestamp
- Pattern count

## Step 7: Report

```
Cross-Project Sync Complete:
  Direction: {pull|push|bidirectional}
  Pulled: {n} patterns (from {n} projects)
  Pushed: {n} patterns, {n} learnings
  Promoted: {n} (passed the promotion gate → active)
  Candidates held: {n} (failed gate — kept as candidate, not active)
  Denied (privacy): {n} (denylist tag or signal_type mood — never pushed)
  Skipped: {n} (below threshold)
  Merges: {n} (same fact, confidence-ranked)
  Superseded: {n} (conflicts resolved by recency — older entry kept as superseded)
```

## What NOT to Do

- Do NOT auto-trigger this skill from hooks or other skills
- Do NOT sync patterns with confidence < 0.5 (pull) or < 0.6 (push)
- Do NOT overwrite local patterns with lower-confidence global ones
- Do NOT sync if fewer than 2 projects exist globally (nothing to cross-pollinate)
