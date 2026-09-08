# V5 Portfolio Cut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink the agentic-os plugin from 9 skills to 5 by archiving the dead self-improve cluster and converting three mechanical skills into slash commands with script cores, so every remaining SKILL.md carries a real judgment share and no skill body is injected for work a script already does.

**Architecture:** Skills whose descriptions load into every prompt (trigger competition) and whose bodies are Skill-tool-injectable (41 % prefix-cache-rewrite risk, L34/D-010) are reduced to the five with genuine judgment: `session-bootstrap`, `wrap-up`, `pattern-extractor`, `context-keeper`, `obsidian-sync`. `self-improve` + `/rollback` + `/auto-commit` + `improvements/` move to `_archived/` (reversible, git history intact). `memory-maintenance`, `iteration-logger`, `sync-context` become the commands `/agentic-os:maintain`, `/agentic-os:log`, `/agentic-os:sync-context` — slash-only, not model-invocable, each wrapping the scripts that already own the writes (`memory-thresholds.sh`, `gc_dirty_markers.py`, `native_memory_audit.py`, `review_sweep.py`, `extract_patterns.py`, `apply_wrapup.py`, `global-schema.sh`). wrap-up stops invoking `memory-maintenance` (it prints the `THRESHOLD:` lines and recommends the command). Every task leaves `bash tests/run-all.sh` green.

**Tech Stack:** Markdown (SKILL.md / commands), JSON (manifests), Bash + Python tests (`tests/validate-plugin.sh`, `tests/validate-skills.sh`, `tests/test-model-routing.sh`, `tests/run-all.sh`). No build step, no package manager. Git Bash on Windows (use forward slashes, `python` not `python3` in ad-hoc commands).

**Spec:** `~/AI/membrain/memgesamtanalyse-2026-09.md` §5 V5 (table "Portfolio schrumpfen") + Owner decisions 2026-09-08 recorded in `~/wiki/wiki/todos/2026-09-08-agentic-os-gesamtanalyse-umsetzung.md` (archive self-improve/rollback/auto-commit; order V5 → V3 → V4).

## Global Constraints

- Branch: `feat/v5-portfolio-cut` (already created from `main` @ 31649a1). Never commit on `main` directly.
- Version bump: **5.0.0** — `docs/VERSIONING.md` maps "Skill entfaellt/umbenannt" to MAJOR. Bump lands in the FIRST commit of the release (rule 1) together with the CHANGELOG entry (rule 2); later tasks extend that entry, never add a second one.
- `metadata.version` in every edited SKILL.md gets a minor bump (VERSIONING rule 3): wrap-up 4.3 → 4.4, session-bootstrap (read current value, +0.1), pattern-extractor 3.3 → 3.4.
- **No command may share a name with a skill directory** (L17 shadow guard in `tests/validate-plugin.sh` "command/skill name shadowing"). A skill directory MUST be removed in the same task that creates the same-named command.
- **Model-routing SSoT:** every `skills/*/` dir needs a row in `scripts/model-routing.sh list` and vice versa; `tests/test-model-routing.sh` pins the row count (currently 9). Each task that removes a skill decrements that count AND the `"N skills"` figure in `.claude-plugin/marketplace.json` (test "marketplace.json skill count accuracy"). Sequence: 9 → 8 (Task 1) → 7 (Task 2) → 6 (Task 3) → 5 (Task 4).
- Command frontmatter: `name:` mandatory; `allowed_tools:` (underscore) or omitted; never `allowed-tools:`; never `user_invocable:`. Follow `commands/status.md` / `commands/init.md`.
- Language policy: command/skill bodies English; user-facing chat German. Frontmatter trigger phrases English.
- Never touch `.agent-memory/` files in commits (they are the target project's store). Stage files by name — never `git add -A` / `git add .`.
- Run the FULL suite after every task: `bash tests/run-all.sh` (takes ~2–3 min; the circuit-breaker suite is slow). Expected final line: `ALL TEST SUITES PASSED`.
- Do NOT push. Do NOT run `claude plugin update`. Task 6 stops at the release gate for the owner.

---

### Task 1: Archive the self-improve cluster, bump 5.0.0, write CHANGELOG

**Files:**
- Move (git mv): `skills/self-improve/` → `_archived/skills/self-improve/`
- Move: `commands/rollback.md` → `_archived/commands/rollback.md`
- Move: `commands/auto-commit.md` → `_archived/commands/auto-commit.md`
- Move: `improvements/` → `_archived/improvements/`
- Create: `_archived/README.md`
- Modify: `.claude-plugin/plugin.json` (version), `.claude-plugin/marketplace.json` (skill count 9 → 8)
- Modify: `docs/CHANGELOG.md` (new top entry)
- Modify: `scripts/model-routing.sh:56` (drop `self-improve` row)
- Modify: `tests/test-model-routing.sh:26-27` (9 → 8)
- Modify: `tests/validate-plugin.sh` (delete self-improve/auto-commit/improvements blocks; shrink MANUAL_SKILL loop)
- Modify: `tests/validate-skills.sh` (delete self-improve blocks + wrap-up state.json block)
- Modify: `skills/wrap-up/SKILL.md:640-641` (drop self-improve loop rule), frontmatter version
- Modify: `skills/pattern-extractor/SKILL.md:7` (description), frontmatter version
- Modify: `commands/status.md` (drop section 3 "Self-Improvement Loop")

**Interfaces:**
- Produces: `_archived/` convention (README explains revival = `git mv` back + re-add model-routing row + tests). Later tasks add nothing there.
- Produces: CHANGELOG entry `## [2026-09-08] Release v5.0.0 — Portfolio-Schnitt ...` that Tasks 2–5 may extend but never duplicate.

- [ ] **Step 1: Confirm clean starting state**

Run: `git status --short | grep -v '^?? \.' ; git branch --show-current`
Expected: no `M`/`A` lines for tracked plugin files (untracked `.agent-memory/...`, `.codegraph/`, `.pi-glla/` are fine); branch `feat/v5-portfolio-cut`.

- [ ] **Step 2: Move the four archive candidates**

```bash
mkdir -p _archived/skills _archived/commands
git mv skills/self-improve _archived/skills/self-improve
git mv commands/rollback.md _archived/commands/rollback.md
git mv commands/auto-commit.md _archived/commands/auto-commit.md
git mv improvements _archived/improvements
```

Run: `ls skills commands _archived _archived/skills _archived/commands _archived/improvements | head -40`
Expected: `skills/` has 8 dirs (no self-improve), `commands/` has `init.md memory-audit.md status.md`, `_archived/improvements/` contains `state.json`, `HISTORY.md`, `clusters.json`, `iterations-*.md`.

- [ ] **Step 3: Write `_archived/README.md`**

```markdown
# _archived — retired plugin components

Nothing in this directory is loaded by Claude Code: the plugin loader reads
`skills/`, `commands/`, `agents/`, `hooks/` only. Files here are kept so a
revival is a `git mv` instead of an archaeology dig.

| Component | Archived | Why | Revive by |
|---|---|---|---|
| `skills/self-improve/` | 2026-09-08 (v5.0.0) | silent since 2026-06-21; 21 KB policy body with no usage evidence (Gesamtanalyse 2026-09 F6/V5); the eval harness (lever 6) lives on in `tests/eval/` | `git mv` back to `skills/`, add a `strong` row to `scripts/model-routing.sh`, restore its tests from git history (`git log --all -- tests/validate-skills.sh`) |
| `commands/rollback.md` | 2026-09-08 (v5.0.0) | only reverted self-improve commits; never used | `git mv` back to `commands/` |
| `commands/auto-commit.md` | 2026-09-08 (v5.0.0) | only called by self-improve; never used interactively | `git mv` back to `commands/` |
| `improvements/` | 2026-09-08 (v5.0.0) | self-improve loop state (`state.json`, batch logs, clusters) — meaningless without the skill | `git mv` back to the plugin root |

Removed earlier and NOT archived (deleted outright, see `docs/CHANGELOG.md`):
retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (v4.0.0);
improvement-agent, research-agent (4.15.0).
```

- [ ] **Step 4: Bump version and marketplace count**

Edit `.claude-plugin/plugin.json`: `"version": "4.21.0"` → `"version": "5.0.0"`.

Edit `.claude-plugin/marketplace.json`: `"Self-improving agent memory system with 9 skills. Tracks iterations, extracts patterns, and generates skills from recurring workflows."` → `"Agent memory system with 8 skills. Tracks iterations, extracts patterns, and generates skills from recurring workflows."` (the word "Self-improving" goes now; the count is decremented again in Tasks 2–4).

Also edit the top-level marketplace `"description": "Self-improving agent memory system for Claude Code"` → `"Agent memory system for Claude Code"`.

- [ ] **Step 5: Drop the self-improve row from the routing SSoT and fix the pinned count**

Edit `scripts/model-routing.sh`: delete the line `    printf 'self-improve\tstrong\t-\t-\n'`.

Edit `tests/test-model-routing.sh`:
```bash
# 2. Exactly 8 rows (one per skill)
n=$(echo "$OUT" | grep -c .)
if [ "$n" -eq 8 ]; then pass "list has 8 rows"; else fail "list has $n rows (expected 8)"; fi
```

- [ ] **Step 6: Remove the self-improve / auto-commit / improvements test blocks from `tests/validate-plugin.sh`**

Delete these blocks WHOLE (each starts at its `# N.` comment or the blank `echo ""` above the `echo "-- ... --"` header and ends before the next block's comment). Locate by header string, not by line number (numbers shift as you delete):

1. `-- Improvements state --` (the `# 6. improvements/state.json` block)
2. `-- auto-commit co-author portability --` (`# 13.`)
3. `-- self-improve co-author portability --`
4. `-- self-improve no-auto-push policy --` (`# 16.`)
5. `-- auto-commit no-auto-push consistency --` (`# 17.`)
6. `-- self-improve state history entry completeness --`
7. `-- self-improve rollback command specificity --`
8. `-- self-improve pre-fix safety checkpoint --`
9. `-- self-improve history dedup guidance --`
10. `-- self-improve severity filter and diminishing returns --`
11. `-- self-improve severity label consistency --`
12. `-- self-improve step 2 no duplicate numbering --`
13. `-- self-improve batch formula uses floor --`
14. `-- self-improve step 7 report uses correct batch placeholder --`
15. `-- DEPENDENCIES.md self-improve batch filename accuracy --` (`# 41.`)
16. `-- improvement-agent: no stale git-stash safety rule --`
17. `-- improvement-agent: no stale phase-skill references --`

Then in the block `-- invocation contract (no dead user_invocable; manual-only skills disabled) --` change
`for MANUAL_SKILL in sync-context self-improve; do` → `for MANUAL_SKILL in sync-context; do`.

Leave `-- dead loop agents removed (self-improve runs inline) --` in place (it guards the ABSENCE of two agent files and stays valid).

Verify: `grep -n "self-improve\|auto-commit\|improvements/" tests/validate-plugin.sh`
Expected: only the `dead loop agents` block lines (fail/pass messages) remain.

- [ ] **Step 7: Remove the self-improve test blocks from `tests/validate-skills.sh`**

Delete WHOLE blocks (header + body):

1. `-- self-improve: research findings persistence --`
2. `-- self-improve: metadata block present --`
3. `-- self-improve: consistent rollback strategy (no git stash) --`
4. `-- wrap-up: state.json path specified for self-improve loop check --`
5. The entire `# --- self-improve hardening levers ...` section: its comment header, `SI_HARDEN_FILE=...`, and the six lever blocks `-- self-improve: lever 1 ... --` through `-- self-improve: lever 6 ... --`.

Also delete the comment line `# research-phase test removed — merged into self-improve in v3` and `# analysis-phase tests removed — merged into self-improve in v3`.

Verify: `grep -n "self-improve\|SI_" tests/validate-skills.sh`
Expected: no output.

- [ ] **Step 8: Remove self-improve coupling from the remaining skills and the status command**

`skills/wrap-up/SKILL.md` — in "What NOT to Do" delete the two lines:
```
- Do NOT run memory maintenance during an active self-improve loop
  (`improvements/state.json` → `status: "running"`)
```
and bump frontmatter `version: '4.3'` → `version: '4.4'`.

`skills/pattern-extractor/SKILL.md` — description line `(invoked by wrap-up or self-improve), or on "extract patterns" /` → `(invoked by wrap-up), or on "extract patterns" /`; bump `version: '3.3'` → `version: '3.4'`.

`commands/status.md` — delete section `3. **Self-Improvement Loop:**` (all five sub-bullets) and renumber `4. **Format**` → `3. **Format**`.

Verify: `grep -rn "self-improve\|improvements/" skills commands hooks scripts --include=*.md --include=*.sh --include=*.py --include=*.json | grep -v "^skills/DEPENDENCIES.md"`
Expected: no output (DEPENDENCIES.md is handled in Task 5).

- [ ] **Step 9: Write the CHANGELOG entry**

Insert directly below the `---` line that follows the header of `docs/CHANGELOG.md` (above `## [2026-09-08] Release v4.21.0 ...`):

```markdown
## [2026-09-08] Release v5.0.0 — Portfolio-Schnitt: 9 Skills → 5, mechanische Skills werden Commands

Owner-Entscheid aus der Gesamtanalyse (`~/AI/membrain/memgesamtanalyse-2026-09.md`, F6/V5),
Reihenfolge V5 → V3 → V4 (V5 raeumt V3 den Tisch frei). MAJOR laut VERSIONING: Skills entfallen.

- **Archiviert nach `_archived/` (reversibel, `git mv`):** `skills/self-improve` (still seit
  2026-06-21, 21 KB Policy ohne Nutzungsnachweis), `commands/rollback`, `commands/auto-commit`
  (nur von self-improve gerufen), `improvements/` (Loop-State). Der Eval-Harness (Lever 6)
  lebt in `tests/eval/` weiter. 17 validate-plugin- und 10 validate-skills-Bloecke entfernt.
- **`memory-maintenance` → `/agentic-os:maintain`:** Command mit Skript-Kern
  (`memory-thresholds.sh`, `gc_dirty_markers.py`, `native_memory_audit.py`, `review_sweep.py`,
  `extract_patterns.py --refresh`). wrap-up Step 9 ruft den Skill nicht mehr auf, sondern druckt
  die `THRESHOLD:`-Zeilen und empfiehlt den Command (L34/D-010: jede Skill-Body-Injektion
  riskiert einen vollen Prefix-Cache-Rewrite).
- **`iteration-logger` → `/agentic-os:log "<summary>"`:** baut einen `iterations`-Plan und
  schreibt ueber `apply_wrapup.py` (einziger Writer seit 4.16.0). Trigger-Phrasen entfallen —
  der Body war 70 % Mechanik.
- **`sync-context` → `/agentic-os:sync-context [pull|push|sync]`:** war schon
  `disable-model-invocation: true`; jetzt ein Command, dessen Regeln (Privacy-Filter,
  Promotion-Gate, Provenance, Recency-Supersession, Pull-Lifecycle) unveraendert getestet werden.
- **Bleiben Skills (echter Urteilsanteil):** session-bootstrap, wrap-up, pattern-extractor
  (Steps 6.5/6.6), context-keeper, obsidian-sync. `scripts/model-routing.sh` fuehrt genau
  diese fuenf.
- Commands jetzt 6: init, status, memory-audit, maintain, log, sync-context.
- Doku nachgezogen: README, CLAUDE.md, CAPABILITIES, DEPENDENCIES (Lifecycle, Matrix,
  Prinzipien 4/5/6/8/9), references/skill-template + memory-structure, plugin.json-Description.
```

- [ ] **Step 10: Run the full suite**

Run: `bash tests/run-all.sh 2>&1 | tail -25`
Expected: `ALL TEST SUITES PASSED`. If `validate-plugin` fails on `DEPENDENCIES.md completeness`, that means a skill dir still exists that is not in DEPENDENCIES.md — it should not (we only removed). If `model-routing` fails with "SSoT lists unknown skill: self-improve", Step 5 was skipped.

- [ ] **Step 11: Commit**

```bash
git add _archived .claude-plugin/plugin.json .claude-plugin/marketplace.json docs/CHANGELOG.md \
  scripts/model-routing.sh tests/test-model-routing.sh tests/validate-plugin.sh tests/validate-skills.sh \
  skills/wrap-up/SKILL.md skills/pattern-extractor/SKILL.md commands/status.md
git status --short | grep -v '^?? '   # review: only the files above, plus the renames (R)
git commit -m "$(cat <<'EOF'
feat(portfolio)!: archive self-improve cluster, bump 5.0.0 (V5 step 1/4)

self-improve, /rollback, /auto-commit and improvements/ move to _archived/
(silent since 2026-06-21, no usage evidence — Gesamtanalyse 2026-09 F6/V5).
MAJOR per VERSIONING (skill removed). Tests that pinned the archived bodies
are removed; the dead-agent absence guard stays.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `memory-maintenance` → `/agentic-os:maintain`

**Files:**
- Create: `commands/maintain.md`
- Delete: `skills/memory-maintenance/` (git rm -r)
- Modify: `scripts/model-routing.sh:50` (drop row), `tests/test-model-routing.sh` (8 → 7), `.claude-plugin/marketplace.json` (8 → 7)
- Modify: `tests/validate-skills.sh` (`MM_GROW_FILE`, `MM_FILE` → command path)
- Modify: `tests/validate-plugin.sh` (`OTHER_SKILLS`, `CALLED_SKILL` loop)
- Modify: `skills/wrap-up/SKILL.md` (Step 9, lines ~208, ~347, ~538-540, ~561-562, ~642)
- Modify: `skills/session-bootstrap/SKILL.md:157,207` + frontmatter version
- Modify: `commands/memory-audit.md:14,27,66,157` (healer name)

**Interfaces:**
- Consumes: `bash scripts/memory-thresholds.sh <mem>` (exit 10 + `THRESHOLD:` lines), `python scripts/gc_dirty_markers.py <mem> [--apply]`, `python scripts/native_memory_audit.py` (exit 0/1/2, prints `**Summary:**` line), `python scripts/review_sweep.py <mem> --native-memory <dir> --report <path>`, `python scripts/memory_index_projection.py --print-native-dir .`, `python scripts/extract_patterns.py <mem> --refresh`, `. scripts/global-schema.sh` (`apply_decay <conf> <age_days>`).
- Produces: the command name `maintain` that wrap-up Step 9, session-bootstrap and memory-audit refer to as `/agentic-os:maintain`.

- [ ] **Step 1: Create `commands/maintain.md`**

```markdown
---
name: maintain
description: Compacts, archives and integrity-checks the .agent-memory/ store. Script core (memory-thresholds.sh, gc_dirty_markers.py, native_memory_audit.py, review_sweep.py, extract_patterns.py --refresh); prose only where a threshold is exceeded. Run on demand or when wrap-up / the SessionStart briefing print THRESHOLD lines.
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

# Memory Maintenance

Compacts and verifies `.agent-memory/`. Never part of the end-of-session flow — wrap-up
prints the `THRESHOLD:` lines and recommends this command; it does not run it.

## Preconditions

- `.agent-memory/` exists — otherwise print "Memory system not initialized — run
  `/agentic-os:init` first" and stop.
- Snapshot first (this run mutates the store): follow
  `${CLAUDE_PLUGIN_ROOT}/references/pre-run-commit.md` with commit message
  `chore(memory): pre-run snapshot vor maintain`.

## Step 1: Mechanical pass (scripts own these — run, do not re-derive)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-thresholds.sh" .agent-memory; echo "thresholds exit=$?"
python "${CLAUDE_PLUGIN_ROOT}/scripts/gc_dirty_markers.py" .agent-memory            # preview
python "${CLAUDE_PLUGIN_ROOT}/scripts/gc_dirty_markers.py" .agent-memory --apply    # delete safe markers
python "${CLAUDE_PLUGIN_ROOT}/scripts/native_memory_audit.py"; echo "audit exit=$?"
python "${CLAUDE_PLUGIN_ROOT}/scripts/review_sweep.py" .agent-memory \
  --native-memory "$(python "${CLAUDE_PLUGIN_ROOT}/scripts/memory_index_projection.py" --print-native-dir .)" \
  --report .agent-memory/working/review-sweep.md
python "${CLAUDE_PLUGIN_ROOT}/scripts/extract_patterns.py" .agent-memory --refresh   # regenerate patterns.md
```

- `memory-thresholds.sh`: exit 0 → nothing to archive, skip Step 3. Exit 10 → each
  `THRESHOLD:` line names file, count, limit and action; Step 3 acts on exactly those.
- `gc_dirty_markers.py`: removes a `working/dirty-*.json` only when it is safe
  (`dirty: false` / `consolidated_at` set, or `updated` older than
  `consolidation-marker.last_wrapup`). It never touches a file with mtime < 30 min
  (live session) or an un-consolidated session without a later wrap-up (recovery
  evidence). Carry the removed count into the report. Never hand-pick these files.
- `native_memory_audit.py`: exit 0 → copy its `**Summary:**` line verbatim into the
  report. Exit 2 (usage/path) or 1 (crash) → one line "native audit failed: …" and
  continue. This is a REPORTER: it never rotates, deletes or edits native stores;
  `warn`/`critical` injection warnings are surfaced, not fixed.
- `review_sweep.py`: emit its one-line result verbatim; any count > 0 → name the report
  path. Keep / supersede / retire are owner decisions taken in Step 5.
- `extract_patterns.py --refresh`: rewrites `patterns/patterns.md` from
  `patterns/patterns.json` (sole writer of both). Do not regenerate it by hand.

## Step 2: JSON integrity

For `iterations/errors.json`, `patterns/patterns.json`, `context/decisions.json`,
`context/open-tasks.json`, `learnings/learnings.json`, `working/current-session.json`,
`working/user-candidates.json`, `identity/user-changelog.json`: attempt to parse. On
failure rename to `{file}.corrupt.bak` (if that exists already: `{file}.corrupt-{YYYYMMDDHHMMSS}.bak`),
recreate with the default (`[]`, or `{}` for `current-session.json`), and report path + parse
error. Count repairs for the report.

## Step 3: Archive what the thresholds flagged (only on exit 10)

For every flagged store file (`iterations/iteration-log.md`, `iterations/errors.json`,
`learnings/learnings.json`, `session-summary.md`, `learnings/learnings.md`): keep the newest
entries within the script's limit, move the rest to `{filename}-archive-{YYYY-MM}.{ext}` in
the same directory (append if this month's archive exists). For `session-summary.md` /
`learnings.md` compress instead of cut: keep the date header, top 5 "What Was Done"
bullets, ALL "Open Items", top 3 "Next Steps", the stats footer; `learnings.md` keeps the
last 12 months and is deduplicated by normalized text (lowercase, stripped punctuation,
collapsed whitespace).

Also delete files directly in `working/` matching `*.py`, `*.tmp`, `*.bak` older than the
`working/` staleness window in `memory-thresholds.sh` (7 days). Never delete
`working/current-session.json`, `working/user-candidates.json`, or any `dirty-*.json`
(Step 1's collector owns those).

## Step 4: Prune stale patterns and superseded decisions

- `patterns/patterns.json`: entries with `last_seen` older than 60 days OR
  `confidence < 0.3` → move to `patterns/patterns-archive-{YYYY-MM}.json`. **Never prune
  `skill_candidate: true`.** Then rerun `extract_patterns.py --refresh` (Step 1 command).
- `context/decisions.json`: archive `status: "superseded"` entries older than 90 days to
  `context/decisions-archive-{YYYY-MM}.json`. Keep every `status: "active"` entry.

## Step 4b: Decay the global layer (global-decay)

Only when `~/.claude-memory/global/` exists. This is the **only** place confidence decays —
never on the read path (session-bootstrap stays read-only). `. "${CLAUDE_PLUGIN_ROOT}/scripts/global-schema.sh"`,
then for each entry in the global `patterns.json` / `learnings.json`:

1. `new_confidence = apply_decay(confidence, days_since(last_relevant))` — **−0.1 per full
   90-day step without recall, floored at 0.3**. Write it back.
2. Decayed `confidence <= 0.3` AND `days_since(last_relevant) > 365` → set
   `lifecycle: "archived"` (the pull-lifecycle filter stops serving it).
3. **Never hard-delete** — archived entries stay for audit, exactly like `superseded` ones.

`last_relevant` is bumped only by a genuine recall, never by this pass and never by a read.

## Step 5: Consistency

1. `.agent-memory/open-tasks.json` at the ROOT must not exist (canonical:
   `context/open-tasks.json`). If both exist: merge into `context/`, delete the root copy.
2. `learnings/learnings.md` header must contain "Auto-generated from learnings.json";
   otherwise regenerate it from `learnings.json`.
3. **soul.md anti-bloat:** if `identity/soul.md` exceeds **80 lines**, warn
   "soul.md is {n} lines (cap 80) — condense; an overlong identity file dilutes its
   effect". Never edit soul.md here (user-owned).
4. `review-sweep.md` counts > 0: list them and ask the owner per item — keep / supersede /
   retire. Apply only what the owner confirms; a supersede goes through the `decisions`
   plan section of `apply_wrapup.py`, never by hand.

## Step 6: Report

```
Memory Maintenance:
  JSON Integrity: {n}/{total} valid ({n_repaired} repaired)
  Thresholds: {ok | n exceeded → archived: {iterations} iterations, {errors} errors, {learnings} learnings}
  Dirty markers GC: {n_removed} removed
  Patterns pruned: {n_stale} stale, {n_low_conf} low-confidence
  Decisions archived: {n}
  Global decay: {n_decayed} decayed, {n_archived} archived | (no global store)
  Native stores: {verbatim **Summary:** line | native audit failed: ...}
  Review sweep: {verbatim one-liner}
  Consistency: {n_issues} issues found, {n_fixed} fixed
```

Stop after the report. Do NOT suggest a commit — the store is not versioned by the target
project; the pre-run snapshot in Preconditions is the rollback point.

## What NOT to Do

- Do NOT modify `identity/soul.md` or `identity/user.md`
- Do NOT prune patterns with `skill_candidate: true`
- Do NOT delete archive files (they are history)
- Do NOT delete `working/dirty-*.json` by hand — `gc_dirty_markers.py` owns the safety rule
- Do NOT write `patterns.md` by hand — `extract_patterns.py --refresh` owns it
- Do NOT combine with wrap-up into one call — wrap-up only recommends this command
```

- [ ] **Step 2: Remove the skill directory and the SSoT row, fix the pinned counts**

```bash
git rm -r skills/memory-maintenance
```

Edit `scripts/model-routing.sh`: delete `    printf 'memory-maintenance\tcheap-write\tsonnet\tlow\n'`.

Edit `tests/test-model-routing.sh`: `-eq 8` / `"list has 8 rows"` / `(expected 8)` → 7.

Edit `.claude-plugin/marketplace.json`: `8 skills` → `7 skills`.

- [ ] **Step 3: Re-point the two memory-maintenance tests in `tests/validate-skills.sh`**

Line `MM_GROW_FILE="$SKILLS_DIR/memory-maintenance/SKILL.md"` → `MM_GROW_FILE="$PLUGIN_ROOT/commands/maintain.md"`.
Line `MM_FILE="$SKILLS_DIR/memory-maintenance/SKILL.md"` → `MM_FILE="$PLUGIN_ROOT/commands/maintain.md"`.
In the two blocks' `echo "-- memory-maintenance: ..."` headers and pass/fail texts replace `memory-maintenance:` with `maintain:` (cosmetic; keeps the output honest).

The pinned tokens the new body MUST keep (verify with the grep below): `soul.md` + `80-line`; `(global-decay)`, `apply_decay`, `90-day step`, `floored at 0.3`, `never hard-delete`.

Run: `grep -c "(global-decay)\|apply_decay\|90-day step\|floored at 0.3\|never hard-delete\|80-line\|80 lines" commands/maintain.md`
Expected: `≥ 6`.

- [ ] **Step 4: Update `tests/validate-plugin.sh`**

In `-- DEPENDENCIES.md inter-skill-call accuracy (Principle 4) --`:
`OTHER_SKILLS="pattern-extractor obsidian-sync memory-maintenance context-keeper iteration-logger"` → `OTHER_SKILLS="pattern-extractor obsidian-sync context-keeper iteration-logger"`.

In `-- invocation contract ... --`:
`for CALLED_SKILL in iteration-logger context-keeper pattern-extractor obsidian-sync memory-maintenance; do` → `for CALLED_SKILL in iteration-logger context-keeper pattern-extractor obsidian-sync; do`.

- [ ] **Step 5: wrap-up stops invoking memory-maintenance**

`skills/wrap-up/SKILL.md`, Step 9 — replace the paragraph

```
Run `bash scripts/memory-thresholds.sh` (plugin root; threshold SSoT shared with
memory-maintenance). Exit 10 (thresholds exceeded) or explicit user request ("clean
memory", "prune patterns") → invoke the `memory-maintenance` skill after Step 8; it
owns its own report and error handling. Exit 0 → skip entirely.
```
with
```
Run `bash scripts/memory-thresholds.sh` (plugin root; threshold SSoT shared with
`/agentic-os:maintain`). Exit 10 → print its `THRESHOLD:` lines in the wrap-up report
and add one line `→ run /agentic-os:maintain` (a command with a script core; never
invoked from here — a skill-body injection risks a full prefix-cache rewrite, L34/D-010).
Exit 0 → no line.
```

Same file, four more prose fixes (search each old string; it occurs once):
- `bootstrap and memory-maintenance read it` → `bootstrap and /agentic-os:maintain read it`
- `Never delete —\n   memory-maintenance archives.` → `Never delete —\n   /agentic-os:maintain archives.`
- `(keep / supersede / retire) are the owner's and happen via memory-maintenance,\nnever here.` → `(keep / supersede / retire) are the owner's and happen via /agentic-os:maintain,\nnever here.`
- `Do NOT delete the files here — \`memory-maintenance\`\n   garbage-collects them later via` → `Do NOT delete the files here — \`/agentic-os:maintain\`\n   garbage-collects them later via`
- In "What NOT to Do": `(Step 9.5 flips flags; memory-maintenance\n  GCs them via gc_dirty_markers.py)` → `(Step 9.5 flips flags; /agentic-os:maintain\n  GCs them via gc_dirty_markers.py)`

Verify: `grep -n "memory-maintenance" skills/wrap-up/SKILL.md`
Expected: no output.

- [ ] **Step 6: session-bootstrap and memory-audit prose**

`skills/session-bootstrap/SKILL.md`:
- `Do NOT decay/write confidence or last_relevant — that is memory-maintenance's job;` → `Do NOT decay/write confidence or last_relevant — that is /agentic-os:maintain's job;`
- `(Thresholds live ONLY in that script — shared with wrap-up Step 9 and memory-maintenance.)` → `(Thresholds live ONLY in that script — shared with wrap-up Step 9 and /agentic-os:maintain.)`
- frontmatter `metadata.version`: read the current value and add 0.1.

`commands/memory-audit.md`: replace every `memory-maintenance` with `/agentic-os:maintain` (4 occurrences: lines ~14, ~27, ~66, ~157). Keep the surrounding text.

Verify: `grep -rn "memory-maintenance" skills commands scripts hooks tests/*.sh | grep -v "^skills/DEPENDENCIES.md\|^tests/validate-skills.sh"`
Expected: no output. (DEPENDENCIES.md → Task 5; validate-skills pass/fail texts were renamed in Step 3 — if any remain they are cosmetic.)

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run-all.sh 2>&1 | tail -25`
Expected: `ALL TEST SUITES PASSED`. Watch specifically for: `no command shadows a skill name` PASS (skill dir gone), `maintain: soul.md 80-line cap present` PASS, `maintain: global decay present` PASS, `list has 7 rows` PASS, `wrap-up: (pattern-extraction) calls the deterministic extractor script` PASS (unchanged block).

- [ ] **Step 8: Commit**

```bash
git add commands/maintain.md scripts/model-routing.sh tests/test-model-routing.sh \
  .claude-plugin/marketplace.json tests/validate-skills.sh tests/validate-plugin.sh \
  skills/wrap-up/SKILL.md skills/session-bootstrap/SKILL.md commands/memory-audit.md
git status --short | grep -v '^?? '   # expect the D lines for skills/memory-maintenance/* plus the files above
git commit -m "$(cat <<'EOF'
feat(portfolio)!: memory-maintenance becomes /agentic-os:maintain (V5 step 2/4)

Command with a script core (thresholds, dirty-marker GC, native audit,
review sweep, patterns.md refresh). wrap-up Step 9 no longer invokes the
skill — it prints the THRESHOLD lines and recommends the command (L34/D-010).
Pinned rules (soul.md 80-line cap, global decay) move with the body; their
tests now read commands/maintain.md.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `iteration-logger` → `/agentic-os:log`

**Files:**
- Create: `commands/log.md`
- Delete: `skills/iteration-logger/` (git rm -r)
- Modify: `scripts/model-routing.sh:51` (drop row), `tests/test-model-routing.sh` (7 → 6), `.claude-plugin/marketplace.json` (7 → 6)
- Modify: `tests/validate-plugin.sh` (`IL_FILE` path; `OTHER_SKILLS`; `CALLED_SKILL` loop)
- Modify: `tests/validate-skills.sh` (delete `-- iteration-logger trigger language consistency --`)
- Modify: `tests/test-wrap-up-long-term-memory-contract.sh:25` (token)
- Modify: `README.md` Long-Term Memory Routine paragraph (token the contract test greps)
- Modify: `skills/wrap-up/SKILL.md` (lines ~27-28, ~76-80, ~104, ~122-123)
- Modify: `skills/pattern-extractor/SKILL.md:22`
- Modify: `commands/init.md:57`

**Interfaces:**
- Consumes: `python scripts/apply_wrapup.py <mem> [--session-id <sid>] [--dry-run]` reading a JSON plan on stdin with an `iterations` array (schema: `skills/wrap-up/references/wrapup-schemas.md` §Write plan); returns JSON with `tally.iterations_logged`, `tally.iterations_skipped_duplicate`, `tally.errors_added`, `tally.errors_recurred`.
- Produces: command name `log`; README token `agentic-os:log` that the contract test requires.

- [ ] **Step 1: Create `commands/log.md`**

```markdown
---
name: log
description: Log one coding iteration (feature, bugfix, refactor, config, docs, test) with its errors, tags and learnings into .agent-memory/iterations/ through scripts/apply_wrapup.py — the single writer of iteration-log.md, errors.json and working/current-session.json.
argument-hint: "[one-line summary of the iteration]"
allowed_tools: ["Read", "Bash", "Glob", "Grep"]
---

# Log Iteration

Mid-session logging of ONE unit of work. Not for session end — wrap-up Step 1.5 harvests
unlogged work into its own write plan and does not call this command.

## Step 1: Gather the iteration (judgment part)

From `$ARGUMENTS` (the summary, if given) and the conversation:

1. **type**: `feature` | `bugfix` | `refactor` | `config` | `docs` | `test`
2. **title**: one line (from `$ARGUMENTS` when present)
3. **files_changed**: `git diff --name-only HEAD` plus untracked files you created
   (`git status --porcelain | awk '$1=="??"{print $2}'`); if not a git repo, list from the
   conversation
4. **tags**: at least 2, lowercase — language/framework · domain · error type · pattern.
   Reuse tags already present in `.agent-memory/iterations/errors.json`
   (`grep -o '"tags": \[[^]]*\]' .agent-memory/iterations/errors.json | sort | uniq -c | sort -rn | head`).
5. **confidence**: 1–5 (how sure the change is correct); **tests**: `passed (n/n)` |
   `failed` | `skipped` | `not applicable`
6. **errors** (only if any occurred): one object per DISTINCT error with `category`
   (`runtime|test|build|config|logic|import|type`), `tags`, `trigger`, `problem`,
   `root_cause`, `fix`, `failed_approaches` (list), `prevention`, `severity`
   (`critical|major|minor`), `attempts`, `confidence`. Do NOT set `id`, `date`,
   `occurrences`, `recurrence_dates`, `last_seen` — the script owns them.
7. **learnings**: one non-obvious insight or empty string (wrap-up promotes or discards it)

**Counting rule:** distinct approaches, not edits. Three failed fixes before the right one
= ONE iteration with `attempts: 3`. Skip trivia (typos, whitespace) unless part of a
larger iteration.

## Step 2: Write through the script (mechanical part)

Session id: the tracker file of THIS session is the newest `.agent-memory/working/dirty-*.json`
whose `updated` is within the last 30 minutes — take `<sid>` from its filename. If there is
none, omit `--session-id`.

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/apply_wrapup.py" .agent-memory --session-id <sid> <<'PLAN'
{"date": "YYYY-MM-DD",
 "iterations": [{"type": "bugfix", "title": "...", "tags": ["python", "import-error"],
                 "files_changed": ["a.py"], "summary": "...", "confidence": 4,
                 "tests": "passed (12/12)", "learnings": "", "commits": "",
                 "errors": []}]}
PLAN
```

The script assigns ids in the format already on disk (`err-00n`), applies the recurrence
rule (same `category` AND ≥ 2 overlapping `tags` → `occurrences++` on the existing error
instead of a new entry), renders the `## {date} — {type}: {title}` block, and appends new
error ids to `working/current-session.json`. An identical header on a re-run is skipped,
so applying the same plan twice is safe. Use `--dry-run` first when unsure.

## Step 3: Confirm

From the returned JSON:

```
Iteration logged: {type} — {title}
  Files: {len(files_changed)} | Errors: +{tally.errors_added} new, {tally.errors_recurred} recurrence(s) | Confidence: {confidence}/5
  Tags: {tags}
```

`tally.iterations_logged == 0` with `iterations_skipped_duplicate == 1` → say "already
logged (identical header)". Exit code 2 → print the script's JSON error verbatim; nothing
was written.

Then: `n=$(grep -c '^## ' .agent-memory/iterations/iteration-log.md)` — if `n % 5 == 0`,
suggest `python "${CLAUDE_PLUGIN_ROOT}/scripts/extract_patterns.py" .agent-memory --update`
(wrap-up Step 4 runs it anyway). If an error recurred for the 3rd+ time, say so — it is an
anti-pattern candidate for pattern-extractor.

## What NOT to Do

- Do NOT write `iteration-log.md`, `errors.json` or `current-session.json` with Write/Edit
- Do NOT modify `patterns.json` (`scripts/extract_patterns.py`) or `decisions.json`
  (`context-keeper` via the `decisions` plan section)
- Do NOT push to global memory (`/agentic-os:sync-context`)
- Do NOT count individual file saves as attempts
```

- [ ] **Step 2: Remove the skill directory and the SSoT row, fix the pinned counts**

```bash
git rm -r skills/iteration-logger
```

Edit `scripts/model-routing.sh`: delete `    printf 'iteration-logger\tcheap-write\tsonnet\tlow\n'`.
Edit `tests/test-model-routing.sh`: 7 → 6 (three places in the block).
Edit `.claude-plugin/marketplace.json`: `7 skills` → `6 skills`.

- [ ] **Step 3: Tests**

`tests/validate-plugin.sh`:
- `-- iteration-logger phantom plugin settings reference --`: `IL_FILE="$PLUGIN_ROOT/skills/iteration-logger/SKILL.md"` → `IL_FILE="$PLUGIN_ROOT/commands/log.md"`; in the header and the three messages replace `iteration-logger:` with `log:`; the final `fail "iteration-logger: SKILL.md not found"` → `fail "log: commands/log.md not found"`.
- `OTHER_SKILLS="pattern-extractor obsidian-sync context-keeper iteration-logger"` → `OTHER_SKILLS="pattern-extractor obsidian-sync context-keeper"`.
- `for CALLED_SKILL in iteration-logger context-keeper pattern-extractor obsidian-sync; do` → `for CALLED_SKILL in context-keeper pattern-extractor obsidian-sync; do`.
- Leave `for FORBIDDEN_CALLEE in iteration-logger context-keeper` in the delegation-budget test unchanged: it asserts wrap-up prescribes zero invocations of that name, which stays true (and meaningful as a regression guard).

`tests/validate-skills.sh`: delete the whole block `-- iteration-logger trigger language consistency --` (header, `IL_FILE=...`, if/fi).

`tests/test-wrap-up-long-term-memory-contract.sh`: in the README token list replace `"iteration-logger" \` with `"agentic-os:log" \`.

- [ ] **Step 4: README Long-Term Memory Routine**

In `README.md` section `## Long-Term Memory Routine` replace
`` `iteration-logger` records distinct work iterations in `.agent-memory/iterations/iteration-log.md` `` with
`` `/agentic-os:log` records distinct work iterations in `.agent-memory/iterations/iteration-log.md` ``.
(The rest of the README is rewritten in Task 5; this line alone keeps the contract test green now.)

- [ ] **Step 5: wrap-up, pattern-extractor, init prose**

`skills/wrap-up/SKILL.md` (each old string occurs once):
- `(write plan, Step 1.5 —\n  the \`iteration-logger\` skill stays the entry point for mid-session logging)` → `(write plan, Step 1.5 —\n  \`/agentic-os:log\` is the entry point for mid-session logging)`
- `The same arithmetic is why this skill no longer invokes \`iteration-logger\`,\n\`context-keeper\` or \`pattern-extractor\`:` → `The same arithmetic is why this skill no longer invokes \`context-keeper\` or\n\`pattern-extractor\` (mid-session logging is the \`/agentic-os:log\` command):`
- `The\nskills remain the entry point when a user calls them directly.` → `The\nskill and the command remain the entry points when a user calls them directly.`
- `Users who run ONLY bootstrap + wrap-up never call iteration-logger mid-session —` → `Users who run ONLY bootstrap + wrap-up never run \`/agentic-os:log\` mid-session —`
- `Do **NOT** invoke the\n   \`iteration-logger\` skill for this and do NOT write` → `Do **NOT** run\n   \`/agentic-os:log\` for this and do NOT write`

`skills/pattern-extractor/SKILL.md`: `- Every 5 iterations (suggested by iteration-logger)` → `- Every 5 iterations (suggested by /agentic-os:log)`.

`commands/init.md`: `working/current-session.json\` — iteration-logger Step 4b appends, wrap-up Step 3.5 consumes + resets` → `working/current-session.json\` — /agentic-os:log appends (via apply_wrapup.py), wrap-up Step 3.5 consumes + resets`.

Verify: `grep -rn "iteration-logger" skills commands scripts hooks README.md tests/*.sh | grep -v "^skills/DEPENDENCIES.md\|FORBIDDEN_CALLEE\|does not invoke\|still prescribes\|1543\|1550"`
Expected: only the delegation-budget test lines (comment block + `FORBIDDEN_CALLEE` loop) in `tests/validate-plugin.sh`. DEPENDENCIES.md → Task 5.

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run-all.sh 2>&1 | tail -25`
Expected: `ALL TEST SUITES PASSED`; specifically `Wrap-up long-term memory contract passed.`, `log: does not reference phantom plugin settings`, `list has 6 rows`, `wrap-up: does not invoke iteration-logger`.

- [ ] **Step 7: Commit**

```bash
git add commands/log.md scripts/model-routing.sh tests/test-model-routing.sh .claude-plugin/marketplace.json \
  tests/validate-plugin.sh tests/validate-skills.sh tests/test-wrap-up-long-term-memory-contract.sh \
  README.md skills/wrap-up/SKILL.md skills/pattern-extractor/SKILL.md commands/init.md
git status --short | grep -v '^?? '
git commit -m "$(cat <<'EOF'
feat(portfolio)!: iteration-logger becomes /agentic-os:log (V5 step 3/4)

The body was 70% mechanics that apply_wrapup.py already owns; as a command
its description no longer competes in every prompt and its body cannot be
Skill-tool-injected. Judgment (type, tags, counting rule) stays in the
command; ids, recurrence and rendering stay in the script.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `sync-context` → `/agentic-os:sync-context` (command)

**Files:**
- Move: `skills/sync-context/SKILL.md` → `commands/sync-context.md` (git mv, then edit frontmatter + trim)
- Delete: the now-empty `skills/sync-context/` dir (git mv removes it; verify)
- Modify: `scripts/model-routing.sh:52` (drop row), `tests/test-model-routing.sh` (6 → 5), `.claude-plugin/marketplace.json` (6 → 5)
- Modify: `tests/validate-plugin.sh` (two `SYNC_SKILL` paths; delete `-- sync-context version consistency --`; delete the `MANUAL_SKILL` loop)
- Modify: `tests/validate-skills.sh` (delete trigger-language block; re-point `SC_BODY_FILE`, `SC_SUP_FILE`)
- Modify: `README.md:12` (bullet "Optional Cross-Project Sync")

**Interfaces:**
- Consumes: `. scripts/global-schema.sh` (`normalize`, `compute_scope <fact_type> <tags-csv>`, `passes_promotion_gate <conf> <occ> <n_projects>`, `apply_decay`, `is_denied <tag>`), `. scripts/mem-schema.sh` (`MEM_GLOBAL_DENY_TAGS`).
- Produces: command name `sync-context`; body keeps every pinned marker: `(pull-lifecycle-filter)`, `(recency-supersession)`, `(privacy-filter)`, `(promotion-gate)`, `(provenance-schema)`, `is_denied`, `MEM_GLOBAL_DENY_TAGS`, `passes_promotion_gate`, `compute_scope`, `G-<fact_type>-<3-digit>`, `lifecycle: active`, `superseded_by`, `.corrupt.bak`.

- [ ] **Step 1: Move and re-head the file**

```bash
git mv skills/sync-context/SKILL.md commands/sync-context.md
rmdir skills/sync-context 2>/dev/null; ls skills
```
Expected: `skills/` = `DEPENDENCIES.md context-keeper obsidian-sync pattern-extractor session-bootstrap wrap-up`.

Replace the frontmatter of `commands/sync-context.md` (everything between the first two `---` lines) with:

```yaml
---
name: sync-context
description: Manual cross-project sync between local .agent-memory/ and the global ~/.claude-memory/global/ store — privacy pre-filter, promotion gate, provenance schema, recency supersession, pull serves lifecycle:active only. Never auto-triggered.
argument-hint: "[pull|push|sync]"
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---
```

Then in the body:
- Replace the paragraph
  ```
  **This skill is never auto-triggered** — `disable-model-invocation: true` enforces it
  mechanically: the model cannot invoke it and its description never loads into context.
  It runs only via `/agentic-os:sync-context`.
  ```
  with
  ```
  **Never auto-triggered.** This is a command: it runs only when the user types
  `/agentic-os:sync-context [pull|push|sync]`; no skill or hook may call it.
  ```
- Delete the `## Architecture` section (heading + the ASCII diagram) and the `## When to Use` section — the argument decides the direction; the "3+ projects" motivation is not procedure.
- In `## Step 2: Determine Direction` prepend: `From \`$ARGUMENTS\` first (\`pull\` / \`push\` / \`sync\`); only when empty, from user intent:`.
- Replace `(run at skill start, before Step 1)` with `(run at command start, before Step 1)`.
- In `## What NOT to Do`: `- Do NOT auto-trigger this skill from hooks or other skills` → `- Do NOT auto-trigger this command from hooks or skills`.
- Everything else (Prerequisites, Steps 1, 3–7 with all markers) stays byte-for-byte.

Verify markers: `grep -c "(pull-lifecycle-filter)\|(recency-supersession)\|(privacy-filter)\|(promotion-gate)\|(provenance-schema)\|is_denied\|MEM_GLOBAL_DENY_TAGS\|passes_promotion_gate\|compute_scope\|corrupt.bak\|AskUserQuestion" commands/sync-context.md`
Expected: `≥ 10` and `grep -c AskUserQuestion commands/sync-context.md` → `0`.

- [ ] **Step 2: SSoT row and pinned counts**

Edit `scripts/model-routing.sh`: delete `    printf 'sync-context\tcheap-write\tsonnet\tlow\n'`. The `list` case now prints exactly: wrap-up, session-bootstrap, obsidian-sync, context-keeper, pattern-extractor.
Edit `tests/test-model-routing.sh`: 6 → 5 (three places).
Edit `.claude-plugin/marketplace.json`: `6 skills` → `5 skills`.

- [ ] **Step 3: Tests**

`tests/validate-plugin.sh`:
- `-- sync-context error handling --`: `SYNC_SKILL="$PLUGIN_ROOT/skills/sync-context/SKILL.md"` → `SYNC_SKILL="$PLUGIN_ROOT/commands/sync-context.md"`; `fail "sync-context: SKILL.md not found"` → `fail "sync-context: commands/sync-context.md not found"`.
- `-- sync-context no phantom AskUserQuestion tool --`: same two replacements.
- Delete the whole block `-- sync-context version consistency --` (`# 63.` comment through `fi`) — commands carry no `metadata.version`.
- In `-- invocation contract ... --` delete the entire `for MANUAL_SKILL in sync-context; do ... done` loop (no manual-only SKILLS remain; manual-only is now structural = command).

`tests/validate-skills.sh`:
- Delete the whole block `-- sync-context trigger language consistency --` (header, `SC_FILE=...`, if/fi).
- `SC_BODY_FILE="$SKILLS_DIR/sync-context/SKILL.md"` → `SC_BODY_FILE="$PLUGIN_ROOT/commands/sync-context.md"`.
- `SC_SUP_FILE="$SKILLS_DIR/sync-context/SKILL.md"` → `SC_SUP_FILE="$PLUGIN_ROOT/commands/sync-context.md"` (the five 4.A blocks that follow reuse this variable).

Verify: `grep -n "skills/sync-context\|SKILLS_DIR/sync-context" tests/*.sh`
Expected: no output.

- [ ] **Step 4: README bullet**

`README.md`: `- **Optional Cross-Project Sync**: Manual pattern sharing via \`sync-context\` skill` → `- **Optional Cross-Project Sync**: Manual pattern sharing via the \`/agentic-os:sync-context\` command`.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run-all.sh 2>&1 | tail -25`
Expected: `ALL TEST SUITES PASSED`; specifically `list has 5 rows`, `sync-context: has error handling guidance`, `sync-context: does not reference nonexistent AskUserQuestion tool`, `sync-context: privacy pre-filter present and ordered before the gate`, `sync-context: promotion gate present`, `sync-context: pull lifecycle filter present`, `sync-context: global provenance schema present`, `sync-context: recency supersession present`, `no command shadows a skill name`.

- [ ] **Step 6: Commit**

```bash
git add commands/sync-context.md scripts/model-routing.sh tests/test-model-routing.sh \
  .claude-plugin/marketplace.json tests/validate-plugin.sh tests/validate-skills.sh README.md
git status --short | grep -v '^?? '   # expect R skills/sync-context/SKILL.md -> commands/sync-context.md
git commit -m "$(cat <<'EOF'
feat(portfolio)!: sync-context becomes a command (V5 step 4/4)

It was already disable-model-invocation; as a command the manual-only
contract is structural. All 4.A rules (privacy filter, promotion gate,
provenance, recency supersession, pull lifecycle) move with the body and
keep their tests. model-routing.sh now lists exactly the five judgment
skills.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Documentation sweep

**Files:**
- Modify: `README.md` (Commands table, Skills table + heading, "Removed" paragraph)
- Modify: `CLAUDE.md` (Architecture block, Skills paragraph, Removed paragraph, Key Conventions bullets on self-improve, Deprecated agents bullet)
- Modify: `docs/CAPABILITIES.md:26-39`
- Modify: `skills/DEPENDENCIES.md` (lifecycle diagram, matrix, agents table, Skills section, principles, bracket table)
- Modify: `references/skill-template.md:76-83`, `references/memory-structure.md:77-78`, `references/bootstrap-wrapup-rationale.md:34`, `references/pre-run-commit.md:4`
- Modify: `.claude-plugin/plugin.json` (description)
- Modify: `docs/ARCHITECTURE.md:42` (one token), `docs/PROJECT.md:17` (one token) — minimal; the full T-009 refresh stays a separate task

**Interfaces:**
- Consumes: final component set — skills `session-bootstrap, wrap-up, pattern-extractor, context-keeper, obsidian-sync`; commands `init, status, memory-audit, maintain, log, sync-context`; agent `context-detective`.
- Produces: docs that tests read: `skills/DEPENDENCIES.md` must still mention every remaining skill name (completeness test) and its Principle-4 line must still list `` `wrap-up` `` (inter-skill-call test); `README.md` must keep `Long-Term Memory Routine`, `agentic-os:log`, `context-keeper`, `wrap-up` and the five `.agent-memory/...` tokens (contract test).

- [ ] **Step 1: README**

Replace the `## Commands` table with:

```markdown
| Command | Description |
|---------|-------------|
| `/agentic-os:init` | Bootstrap `.agent-memory/` in current project |
| `/agentic-os:status` | Show memory system health |
| `/agentic-os:memory-audit` | Read-only drift/provenance/staleness report over `.agent-memory/` |
| `/agentic-os:maintain` | Compaction, archiving, dirty-marker GC, native-store audit, decay report (script core) |
| `/agentic-os:log "<summary>"` | Log one iteration through `apply_wrapup.py` (mid-session) |
| `/agentic-os:sync-context [pull\|push\|sync]` | Manual cross-project sync with privacy filter + promotion gate |
```

Replace `## Skills (9)` heading + table with:

```markdown
## Skills (5)

| # | Skill | Layer | Purpose |
|---|-------|-------|---------|
| 1 | `session-bootstrap` | core | Restores context at session start, health checks, briefing, identity gates |
| 2 | `wrap-up` | core | Session end: summary, learnings, identity growth, handoff |
| 3 | `pattern-extractor` | analysis | Extracts recurring patterns; generates skills from confirmed skill candidates |
| 4 | `context-keeper` | core | Maintains project context and architecture decisions |
| 5 | `obsidian-sync` | knowledge | Writes session results into the Obsidian wiki (sessions, entities, patterns) |
```

Replace the paragraph starting `Removed in v4.0.0 (never exercised or externally duplicated):` with:

```markdown
Converted to commands in v5.0.0 (mechanics, no judgment share): `memory-maintenance` →
`/agentic-os:maintain`, `iteration-logger` → `/agentic-os:log`, `sync-context` →
`/agentic-os:sync-context`. Archived in v5.0.0 under `_archived/` (reversible):
`self-improve`, `/rollback`, `/auto-commit`. Removed in v4.0.0: `quality-gate`,
`retrospective`, `research-pipeline`, `wiki-query`, `skill-generator` (folded into
pattern-extractor). See `skills/DEPENDENCIES.md` for the dependency graph.
```

Also in the feature bullets (top of README) delete any bullet that describes a self-improvement loop, if present (`grep -n -i "self-improv" README.md`).

- [ ] **Step 2: CLAUDE.md**

- `# Agentic OS v4.3.0 — a Claude Code plugin providing a self-improving agent memory system.` → `# Agentic OS v5.0.0 — a Claude Code plugin providing a persistent agent memory system.`
- Architecture block: `skills/*/SKILL.md → 9 skills with YAML frontmatter (trigger phrases, descriptions)` → `skills/*/SKILL.md → 5 skills with YAML frontmatter (trigger phrases, descriptions)`; `commands/*.md → 5 slash commands (init, status, rollback, auto-commit, memory-audit) — KEIN Command darf ...` → `commands/*.md → 6 slash commands (init, status, memory-audit, maintain, log, sync-context) — KEIN Command darf ...`; delete the line `improvements/state.json → Self-improve loop state tracker`; add `_archived/ → retired components (self-improve, rollback, auto-commit, improvements/) — not loaded, revive via git mv`.
- `**Skills (9, layered):**` paragraph → `**Skills (5, layered):**` with bullets: `- **Core** (session-bootstrap, wrap-up, context-keeper): ...` (keep the wrap-up Step 6 / bootstrap 6.5 sentences), `- **Analysis** (pattern-extractor): ...`, `- **Knowledge** (obsidian-sync): ...`; delete the `- **Self-improve** (self-improve): ...` bullet. Add: `**Commands with a script core (v5.0.0):** /agentic-os:maintain (ex memory-maintenance), /agentic-os:log (ex iteration-logger), /agentic-os:sync-context (ex sync-context) — slash-only, never model-invoked, never called from wrap-up.`
- `**Removed in v4.0.0:** ...` → keep, append `**Archived in v5.0.0:** self-improve, rollback, auto-commit, improvements/ → \`_archived/\`.`
- Delete the bullets `**Self-improve safety:** ...` and `**Self-Improve Policy (2026-04-30):** ...`.
- `**Deprecated agents:** ... (4.15.0 — self-improve runs all phases inline; a validate-plugin test enforces their absence)` → `**Deprecated agents:** \`improvement-scout\`/\`fix-reviewer\` (removed 2026-04-30), \`quality-gate\` (v4.0.0), \`improvement-agent\`/\`research-agent\` (4.15.0; a validate-plugin test enforces their absence). The \`agents/\` directory contains 1 active agent (context-detective).`
- In `**Hooks (4.21.0):**` nothing changes. In the Delegation-rebuild bullet: `They now live in code: ...` stays; append one sentence: `Since v5.0.0 memory-maintenance is no longer invoked either — wrap-up Step 9 recommends \`/agentic-os:maintain\`.`

- [ ] **Step 3: docs/CAPABILITIES.md**

Replace lines from `## Skills (9)` through the `## Commands (5)` paragraph with:

```markdown
## Skills (5)

Core: session-bootstrap, wrap-up, context-keeper. Analysis: pattern-extractor (inkl. Skill-Candidate-Generation). Knowledge: obsidian-sync.

Zu Commands mit Skript-Kern gemacht in v5.0.0: memory-maintenance → maintain, iteration-logger → log, sync-context → sync-context. Archiviert in v5.0.0 (`_archived/`): self-improve. Entfernt in v4.0.0: retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (gefaltet in pattern-extractor).

## Agents (1)

context-detective. (improvement-agent, research-agent entfernt 4.15.0; quality-gate v4.0.0.)

## Commands (6)

init, status, memory-audit, maintain, log, sync-context. (rollback, auto-commit archiviert v5.0.0; log, patterns, research, sync, run-loop entfernt in v4.0.0 — `log` kehrt als echter Command mit Skript-Kern zurueck, nicht als Wrapper.)
```

- [ ] **Step 4: skills/DEPENDENCIES.md**

- Header line 1: `# Skill Dependency Graph — Agentic OS v4` → `— Agentic OS v5`; blockquote `> Reflects v4.0.0.` → `> Reflects v5.0.0.`; `(threshold SSoT — read by session-bootstrap Step 3, wrap-up Step 9, memory-maintenance Step 3)` → `(threshold SSoT — read by session-bootstrap Step 3, wrap-up Step 9, /agentic-os:maintain Step 1)`.
- Lifecycle diagram, WORK PHASE: replace the `iteration-logger (after fixes/features)` subtree with
  ```
  ├── /agentic-os:log (command, mid-session, on request)
  │     └── writes via scripts/apply_wrapup.py (`iterations` plan section — never by hand):
  │           iteration-log.md, errors.json, working/current-session.json
  ```
  replace the `sync-context (MANUAL ONLY, explicit request)` subtree header with `├── /agentic-os:sync-context (command, MANUAL ONLY)` (keep its one child line); delete the whole `└── self-improve (...)` subtree and turn the preceding `├── obsidian-sync` into `└── obsidian-sync`.
- Lifecycle diagram, wrap-up Step 9 line: `│  └── Step 9   → runs scripts/memory-thresholds.sh; exit 10 or explicit request\n  │        → invokes memory-maintenance` → `│  └── Step 9   → runs scripts/memory-thresholds.sh + review_sweep.py; exit 10\n  │        → prints THRESHOLD lines and recommends /agentic-os:maintain (never invoked)`.
- Dependency Matrix: delete the rows `iteration-logger`, `memory-maintenance`, `sync-context`, `self-improve`. In the `wrap-up` row's Invokes cell: `pattern-extractor (Step 4, ONLY for skill/rueckfluss candidates), obsidian-sync (Step 7.5), memory-maintenance (Step 9, threshold-script exit 10 or explicit request). Step 1.5 ...` → `pattern-extractor (Step 4, ONLY for skill/rueckfluss candidates), obsidian-sync (Step 7.5). Step 9 only recommends /agentic-os:maintain. Step 1.5 ...`. Add below the matrix:
  ```markdown
  ### Commands with a script core (v5.0.0)

  | Command | Script core | Writes |
  |---|---|---|
  | /agentic-os:maintain | memory-thresholds.sh, gc_dirty_markers.py, native_memory_audit.py, review_sweep.py, extract_patterns.py --refresh, global-schema.sh (apply_decay) | archives/*, repaired JSON, compacted session-summary.md + learnings.md, working/ scratch cleanup, global decayed confidence + lifecycle:archived (never hard-delete) |
  | /agentic-os:log | apply_wrapup.py (`iterations` section) | iteration-log.md, errors.json, working/current-session.json |
  | /agentic-os:sync-context | global-schema.sh (is_denied, compute_scope, passes_promotion_gate), mem-schema.sh (MEM_GLOBAL_DENY_TAGS) | local + ~/.claude-memory/global/{patterns,learnings,projects}.json with provenance schema; privacy-filter before gate; pull serves lifecycle:active only |
  ```
- Agents table: delete the `improvement-agent` and `research-agent` rows.
- `## Skills (v4.0.0)` → `## Skills (v5.0.0)`; `9 active skills` → `5 active skills`; table rows → `| core | session-bootstrap, wrap-up, context-keeper | |`, `| analysis | pattern-extractor | absorbed skill-generator (Step 6.5) in v4.0.0 |`, `| knowledge | obsidian-sync | write-path to the Obsidian wiki |`. Add `### Converted to commands / archived in v5.0.0` with the three conversions and the archive list (one line each, reason from the CHANGELOG entry). Fix `5 commands remain (init, status, rollback, auto-commit, memory-audit)` → `commands now: init, status, memory-audit, maintain, log, sync-context`. `Removed agents (2026-04-30): ... → use \`improvement-agent\` + \`self-improve\`.` → `Removed agents: improvement-scout, fix-reviewer (2026-04-30); improvement-agent, research-agent (4.15.0).`
- Key Design Principles: 4 → `**Skills that invoke other skills:** \`wrap-up\` (pattern-extractor only for skill/rueckfluss candidates, obsidian-sync — iteration-logger/context-keeper are NOT invoked since T-015, memory-maintenance not since v5.0.0). All other skills are leaf nodes.`; 5 → `**/agentic-os:sync-context is manual-only** — a command, no auto-sync.`; delete 6, 8, 9 and renumber; 12 stays.
- Session-Bracket Coverage: `Wiki sync, central handoff, status board, maintenance trigger | wrap-up Steps 7-9 (...)` → `Wiki sync, central handoff, status board, maintenance recommendation | wrap-up Steps 7-9 (...)`. Deliberately-on-demand table: `sync-context` row → `/agentic-os:sync-context`; delete `self-improve` row; `memory-maintenance (full run)` → `/agentic-os:maintain`; `/memory-audit, /rollback, /status` → `/memory-audit, /status, /log`.

Verify: `grep -n "self-improve\|iteration-logger\|memory-maintenance\|improvement-agent\|research-agent\|rollback\|auto-commit" skills/DEPENDENCIES.md`
Expected: only the historical lines ("NOT invoked since T-015", "Converted to commands / archived", "Removed agents").

- [ ] **Step 5: references + manifests + ARCHITECTURE/PROJECT tokens**

- `references/skill-template.md` Layer Guide: `| core | ... | session-bootstrap, iteration-logger, pattern-extractor, context...` → list `session-bootstrap, wrap-up, context-keeper`; delete the `| self-improve | ... |` row; add `| analysis | Pattern detection, skill generation | pattern-extractor |` if not present; the note `\`fix-reviewer\` were removed (2026-04-30) — use \`improvement-agent\` + \`self-improve\`.` → `\`fix-reviewer\` were removed (2026-04-30); \`improvement-agent\`/\`research-agent\` 4.15.0; \`self-improve\` archived v5.0.0.`
- `references/memory-structure.md:77-78`: `> **Authoritative source:** \`skills/memory-maintenance/SKILL.md\` Step 3.\n> Archiving runs only when \`memory-maintenance\` is invoked` → `> **Authoritative source:** \`commands/maintain.md\` Step 3.\n> Archiving runs only when \`/agentic-os:maintain\` is run`.
- `references/bootstrap-wrapup-rationale.md:34`: `memory-maintenance's job` → `/agentic-os:maintain's job`.
- `references/pre-run-commit.md:4`: `(memory-maintenance, obsidian-sync)` → `(/agentic-os:maintain, obsidian-sync)`.
- `.claude-plugin/plugin.json` description: after `deterministic scripts for every store write,` insert `five judgment skills plus three commands with a script core (maintain, log, sync-context),`. Do NOT write "N skills" anywhere in plugin.json (would activate the count test — fine either way, but keep the description count-free).
- `docs/ARCHITECTURE.md:42`: `wrap-up (Step 9), memory-maintenance (Step 3)` → `wrap-up (Step 9), /agentic-os:maintain (Step 1)`.
- `docs/PROJECT.md:17`: `9 Skills (core + knowledge +` → `5 Skills + 6 Commands (v5.0.0; core + analysis + knowledge +`.

Verify (whole repo, excluding archive/history): `grep -rn "self-improve\|iteration-logger\|memory-maintenance\|sync-context skill\|/rollback\|auto-commit" --include=*.md --include=*.json --include=*.sh --include=*.py . | grep -v "^./_archived\|^./docs/CHANGELOG.md\|^./docs/superpowers\|^./\.agent-memory\|^./tests/eval/baseline\|^./\.codegraph\|^./\.pi-glla\|NOT invoked since T-015\|Converted to commands\|Removed agents\|dead loop agents\|FORBIDDEN_CALLEE\|does not invoke\|still prescribes\|^./docs/model-routing-eval-checklist.md\|^./docs/optimization-goals.md\|^./improvements"`
Expected: no output. (`docs/model-routing-eval-checklist.md` and `docs/optimization-goals.md` are historical records; leave them.)

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run-all.sh 2>&1 | tail -25`
Expected: `ALL TEST SUITES PASSED`; specifically every remaining skill `documented in DEPENDENCIES.md`, `DEPENDENCIES.md Principle 4 lists every skill that invokes another skill`, `Wrap-up long-term memory contract passed.`

- [ ] **Step 7: Commit**

```bash
git add README.md CLAUDE.md docs/CAPABILITIES.md skills/DEPENDENCIES.md references/skill-template.md \
  references/memory-structure.md references/bootstrap-wrapup-rationale.md references/pre-run-commit.md \
  .claude-plugin/plugin.json docs/ARCHITECTURE.md docs/PROJECT.md
git status --short | grep -v '^?? '
git commit -m "$(cat <<'EOF'
docs(portfolio): README, CLAUDE.md, CAPABILITIES, DEPENDENCIES on the 5-skill / 6-command surface

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Verification and release gate (STOP for the owner)

**Files:** none modified unless verification finds a defect.

- [ ] **Step 1: Cold verification of the installed-vs-source surface**

```bash
bash tests/run-all.sh 2>&1 | tail -8
ls skills commands agents _archived/skills _archived/commands
bash scripts/model-routing.sh list
git log --oneline main..HEAD
git diff --stat main...HEAD | tail -1
```
Expected: `ALL TEST SUITES PASSED`; `skills/` = 5 dirs + DEPENDENCIES.md; `commands/` = `init.md log.md maintain.md memory-audit.md status.md sync-context.md`; routing list = 5 rows; 5 commits ahead of main.

- [ ] **Step 2: Smoke the three new commands' bash blocks against the repo's own store (read-only variants only)**

```bash
bash scripts/memory-thresholds.sh .agent-memory; echo "exit=$?"
python scripts/gc_dirty_markers.py .agent-memory            # preview only — do NOT pass --apply here
python scripts/native_memory_audit.py | grep -m1 "Summary"
python scripts/extract_patterns.py .agent-memory --refresh --dry-run
python scripts/apply_wrapup.py .agent-memory --dry-run <<'PLAN'
{"date": "2026-09-08", "iterations": [{"type": "refactor", "title": "smoke: /agentic-os:log dry-run", "tags": ["plugin", "smoke"], "files_changed": [], "summary": "dry-run only", "confidence": 5, "tests": "not applicable", "learnings": "", "commits": "", "errors": []}]}
PLAN
```
Expected: every command exits 0 (thresholds may exit 10 — that is a valid result, not a failure); the apply_wrapup dry-run prints a JSON tally with `"iterations_logged": 1` and touches no file (`git status --short .agent-memory` unchanged vs. before).

- [ ] **Step 3: Offer the Codex review per convention and STOP**

Report to the owner (German): commit list, test result line, the smoke results, and the release gate. Offer `[1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]` (default Verifier). Do NOT push, do NOT merge to main, do NOT run `claude plugin update` — VERSIONING rule 4's deploy two-step (`git push origin main` → `claude plugin update agentic-os` → verify installPath content, not `gitCommitSha`) is the owner's release decision. After release, the Wiki-TODO `2026-09-08-agentic-os-gesamtanalyse-umsetzung.md` gets V5 ticked and V3 becomes "next".

---

## Self-review (done while writing)

- **Spec coverage:** V5 table rows — self-improve+rollback+auto-commit archive (Task 1), memory-maintenance → maintain with the four named scripts (Task 2), iteration-logger → log via apply_wrapup.py (Task 3), sync-context → command with global-schema.sh core (Task 4), remaining five skills unchanged as skills (verified by the routing list in Task 6). Owner decision "archive, don't delete" honored via `_archived/`. "Eval-Harness lebt in tests/eval weiter": nothing in `tests/eval/` references `improvements/` or `self-improve` (grep-verified 2026-09-08).
- **Count note:** the analysis wrote "5 Commands → 3"; the end state is 6 commands (−2 archived, +3 converted). The CHANGELOG entry states 6 explicitly.
- **Type/name consistency:** command names `maintain`, `log`, `sync-context` used identically in Tasks 2–5, the CHANGELOG (Task 1) and README/DEPENDENCIES (Task 5). Pinned test tokens listed per task match the bodies written here.
- **Version pin sequence:** test-model-routing.sh and marketplace.json go 9→8→7→6→5 in Tasks 1–4; each task runs the suite.
- **Placeholders:** none — every new file's content is in this document; every edit names the exact old and new string.

## Amendment after Codex Verifier review (2026-09-08, verdict FAIL → fixed)

- **Wrong premise in this plan:** a command file is NOT structurally slash-only — the Skill tool resolves command names and their descriptions load into every prompt (the plugin's own `init`/`status`/`memory-audit` appear in the model's skill list). "Manual-only" is mechanical only via `disable-model-invocation: true`. All three new commands now carry the flag; the invocation-contract test in `validate-plugin.sh` enforces it.
- `/agentic-os:log` Step 3 wrongly claimed "exit 2 → nothing written". `apply_wrapup.py` reports `files_written` on `io error`; only `plan rejected` writes nothing. Text corrected.
- `apply_wrapup.py` ran `apply_user_candidates` for every plan, so an iterations-only `/agentic-os:log` plan could promote queued candidates into `user.md` (pre-existing behaviour of the iteration-logger path, violates Principle 8). `main()` now runs the identity applier only for plans with a `user_candidates` key or `consolidate: true`; test 32 in `tests/test-apply-wrapup.py` pins it.
- README title and `docs/ARCHITECTURE.md` "Skills (9)" block were still v4; fixed.
