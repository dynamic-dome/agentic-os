---
name: self-improve
description: >
  Orchestrates autonomous self-improvement loops: runs up to 4 iterations of
  research, analysis, TDD-based improvement, and validation with circuit breaker,
  NotebookLM research, and git-safe rollback. Replaces the old single-pass
  approach with a multi-iteration loop. Includes scheduling, meta-improvement,
  and all pipeline phases inline.
  Trigger: "self improve", "improve yourself", "run improvement loop",
  "iterate on plugin", "find and fix weaknesses", "improve skills",
  "start improvement cycle", "improve the plugin".
user_invocable: false
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: orchestration
  depends-on:
    - agentic-os:iteration-logger
    - agentic-os:pattern-extractor
    - agentic-os:quality-gate
---

# Self-Improve Orchestrator

Runs up to 4 sequential improvement iterations, each with research, analysis, improvement, and validation phases. All phases are inline — no external skill delegation.

## When to Use

- Scheduled self-improvement task triggers
- User says: "self improve", "improve yourself", "run improvement loop"
- "find and fix weaknesses", "improve skills", "start improvement cycle"

## Prerequisites

- `improvements/state.json` exists with `currentIteration` counter
- `tests/run-all.sh` exists and is executable
- Git repository is clean (no uncommitted changes)

## Constraints

- Max 4 iterations per run
- Max 20% change per skill per iteration
- Never modify `.agent-memory/` files directly (use iteration-logger, pattern-extractor)
- Circuit breaker stops on 2+ consecutive diminishing-returns
- Meta-improve limited to 1x per run (recursion guard)
- Do NOT push automatically — commits stay local until user confirms
- Only fix critical and warning severity weaknesses; log suggestions without fixing
- Skip previously-fixed weaknesses: read `state.json` history and avoid duplicate fixes

## Self-Improve Policy (gehaertet 2026-04-30)

Diese Policy wurde nach dem Plugin-Audit eingefuehrt, um rekursives Chaos zu verhindern.
Sie steht ueber den Constraints — bei Konflikt gewinnt die Policy.

### 1. Single-Cluster-Rule

Pro Self-Improve-Run darf **nur ein Plugin-Cluster** verbessert werden, nicht mehrere
parallel. Cluster-Definition (Stand 2026-04-30):

| Cluster | Plugins |
|---|---|
| `memory-cluster` | `agentic-os`, `agentic-memory` |
| `orchestration-cluster` | `agent-orchestrator-plugin`, `multi-model-orchestrator` (Repo `inception-sandbox`), `devil-advocate-swarms` |
| `workflow-cluster` | `dome-loop`, `agentic-workflow-suite` |
| `creative-cluster` | `crazy-professor` |

Wenn der Run einen anderen Cluster betreten muss (z.B. quality-gate-Fix beruehrt
Konsumenten in zwei Clustern), ABORT mit Hinweis und User-Eingriff anfordern. Das
Risiko-Surface mehrerer Cluster ist zu gross — Rollback-Granularitaet leidet.

### 2. Pattern-Bestaetigung-Schwelle

`pattern-extractor` darf Pattern markieren, aber `skill-generator` erzeugt einen
Skill-Kandidaten erst nach **mindestens zwei bestaetigten Wiederholungen desselben
Patterns** ODER **expliziter User-Freigabe per Slash-Command**. Bestaetigt heisst:
das Pattern wurde in zwei verschiedenen Iterationen, mindestens 24h auseinander, gelogged.

Wenn die Schwelle nicht erreicht: Pattern bleibt im Catalog, aber kein Skill-Build.

### 3. Wrap-Up-Discipline

`obsidian-sync` (Wiki-Schreibpfad) schreibt am Ende eines Self-Improve-Runs **nur
verdichtete Resultate** ins Wiki, nicht die Iteration-Rohdaten. Konkret: pro Run
maximal eine Session-Note unter `wiki/queries/YYYY-MM-DD-self-improve-<cluster>.md`,
keine Auto-Promotions roher Iterations-Logs.

### 4. MCP-Audit als Diagnose-Signal

Wenn in der Session ein MCP-Tool-Audit oder Smoke-Test gelaufen ist, **lies das
Ergebnis als Diagnose** — aber **trigger keinen automatischen Self-Improve-Run**
auf Basis dieser Diagnose. Ein Self-Improve-Run muss explizit vom User oder vom
Scheduler kommen, nicht reaktiv aus einem anderen Tool-Output.

### 5. No-Self-Mod-Boundary

`self-improve` darf **NICHT seinen eigenen `SKILL.md`-Body modifizieren**
(Meta-Improve mit Recursion-Risk). Wenn der Algorithmus erkennt, dass der eigene
Pfad veraltet ist, schreibt er einen Befund in `improvements/meta-suggestions.md`,
der manuell vom User reviewed werden muss. Kein automatischer Edit der
self-improve-Skill-Datei.

Diese Regel ist die wichtigste Sicherheits-Boundary: vergleichbar mit der
Globalen-CLAUDE.md-Regel "NIEMALS Tests gegen Production-Datenbanken" — analog
nutzt self-improve niemals seinen eigenen Maintainer-Pfad als Self-Mod-Target.

### 6. Rollback-Tightness

Bei jedem Self-Improve-Commit wird ein Git-Tag gesetzt im Format
`self-improve-{cluster}-{iteration}-{ISO-timestamp}`, sodass `/agentic-os:rollback`
zuverlaessig auf den Pre-Run-State zurueck geht. Tag-Persistenz: nach erfolgreichem
User-Push wird der Tag im Remote-Repo persistiert; bei Rollback wird der Tag
geloescht.

---

## Verifikations-Checkliste pro Run

Vor jedem Phase-1-Schritt sicherstellen:

1. Single-Cluster gewaehlt? (Policy 1)
2. Letzter `obsidian-sync`-Eintrag ist verdichtet, nicht roh? (Policy 3 retrospektiv)
3. Pattern-Schwelle fuer alle in diesem Run aktiven Pattern erfuellt? (Policy 2)
4. Self-Improve-Skill ist NICHT in der Target-Plugin-Liste? (Policy 5)
5. Rollback-Tag-Praefix vorbereitet? (Policy 6)

Wenn auch nur eine Antwort "nein" ist: ABORT mit Hinweis und User-Bestaetigung erfragen.

## Batch File Naming

```
batch_start = floor((iteration - 1) / 5) * 5 + 1
batch_end = batch_start + 4
filename = iterations-{batch_start:03d}-{batch_end:03d}.md
```

---

# Phase 0: Setup

## Step 0.1: Read State and Dedup History

Read `improvements/state.json` from the plugin root directory.
- Extract `currentIteration` to calculate the next iteration number
- Extract `history` array — collect all previously fixed weakness names/categories
- If `status` is `"running"`, abort with: "ABORTED: another loop is already running"

Update `state.json` to set `status: "running"` and `lastRun` to current ISO timestamp.

## Step 0.2: Determine Target Plugin

By default, target the plugin directory itself (self-improvement). The user can specify a different plugin path as target.

Read the target plugin's skill files using `Glob` with pattern `skills/*/SKILL.md` in the target directory.

## Step 0.3: Check Git and Baseline

Run in the target plugin directory:
```bash
git status --porcelain
```
If there are uncommitted changes, abort with: "ABORTED: uncommitted changes — commit or stash first".

Run baseline tests:
```bash
bash tests/run-all.sh
```
If tests fail, abort with: "ABORTED: baseline tests already failing".

**Baseline sanity check (lever 5).** Record the absolute baseline test count as
`BASELINE_TEST_COUNT` (total tests reported by `run-all.sh`). Compare it against the
`tests_after` of the most recent `state.json` history entry (`PREV_TEST_COUNT`):

- If `BASELINE_TEST_COUNT == 0`, or it has **dropped to half or less** of
  `PREV_TEST_COUNT`, ABORT with `BASELINE-SANITY: test count collapsed
  ({PREV} -> {BASELINE}) — the suite is broken or not running; refusing to iterate`.
- This is an **absolute** guard. The per-iteration delta check (Phase 4) only catches
  regressions *within* a run; it would not have caught iteration 64's `0` plugin tests,
  which should have raised an alarm. Lever 5 catches that class.

If there is no previous entry to compare against, skip the comparison but still store
`BASELINE_TEST_COUNT` for the Phase 4 per-iteration check.

Record the current commit hash as a safety checkpoint:
```bash
git rev-parse HEAD
```
Store this as `checkpoint_sha`.

---

# Phase 1: Research

Gathers best practices and identifies weaknesses before improving skills. Works fully offline with local analysis; optionally enhanced by WebSearch or NotebookLM.

## Step 1.1: Local Analysis (always runs)

1. **Read local sources**: Use `Glob` and `Read` to check for:
   - `{target_dir}/.agent-memory/patterns/patterns.json` — recurring issues
   - `{target_dir}/.agent-memory/iterations/` — recent iteration logs
   - `{target_dir}/improvements/` — previous improvement results
   - `{target_dir}/ARCHITECTURE.md` or `{target_dir}/CLAUDE.md` — project context

2. **Analyze the skill content directly** against this checklist:
   - [ ] Steps are numbered with clear tool calls
   - [ ] Edge cases and error paths are specified
   - [ ] Description contains enough keywords for accurate triggering
   - [ ] Safety guards (rollback, abort conditions) are present
   - [ ] Frontmatter is complete (name, description, metadata)
   - [ ] No circular or broken dependencies
   - [ ] Consistent formatting with other skills in the plugin

3. **Cross-reference with patterns**: If patterns.json exists, check whether the skill exhibits known anti-patterns or misses known best practices.

## Step 1.2: Optional WebSearch Enhancement

If the skill has structural issues that local analysis cannot resolve, use `WebSearch` to find:
- "Claude Code SKILL.md best practices"
- "prompt engineering for agent skills"
- Specific topics related to the identified weaknesses

Skip this step if local analysis already produces 3+ actionable findings.

## Step 1.3: Optional NotebookLM Enhancement

Only if the user has explicitly requested NotebookLM integration OR if a notebook named `self-improve-{plugin-name}` already exists:
- Use the `notebooklm` user-skill (Python API) to query the existing knowledge base
- Do NOT create new notebooks automatically during the loop

## Step 1.4: Persist Research Findings

Write to `{target_dir}/.agent-memory/research/research-cache.json`:

```json
{
  "skill_name": "...",
  "cached_at": "YYYY-MM-DDTHH:MM:SSZ",
  "iteration_number": N,
  "weaknesses": ["..."],
  "best_practices": ["..."],
  "suggestions": [{"change": "...", "reason": "...", "impact": "high|medium|low"}],
  "sources": "local|local+web|local+notebooklm"
}
```

**TTL**: Cache is considered fresh for 7 days.

---

# Phase 2: Analysis

Uses pattern-extractor and iteration history to identify what needs improvement, ranks by severity, and deduplicates against history.

## Step 2.1: Invoke Pattern Extractor

Use the `Skill` tool to invoke `agentic-os:pattern-extractor`:
```
Analyze the plugin at {target_dir}. Focus on skill quality patterns:
- Skill descriptions that are too vague or too specific for triggering
- Missing required sections in SKILL.md files
- Inconsistent formatting across skills
- Missing error handling or safety guards
- Steps that are ambiguous or under-specified
```

If pattern-extractor returns "Not enough data" (fewer than 3 error records), treat as empty result and continue gracefully.

## Step 2.2: Read Iteration History Directly

Use the `Read` tool to load:
- `{target_dir}/.agent-memory/iterations/iteration-log.md` — recent iteration summaries
- `{target_dir}/.agent-memory/iterations/errors.json` — structured error records

Look for recurring errors, false trigger activations, and user feedback.

## Step 2.3: Analyze Skills Directly

Read all `skills/*/SKILL.md` files. Check each for:
1. **Frontmatter completeness**: name, description, metadata (author, version, layer)
2. **Description quality**: Specific enough to trigger correctly? Relevant keywords?
3. **Instructions clarity**: Steps numbered? Tool calls specified? Edge cases handled?
4. **Safety**: Error handling? Rollback guidance?
5. **Consistency**: Same formatting, section names, detail level across skills

## Step 2.3.5: Functional Lens (lever 3)

The historical analysis phase was trained on frontmatter / language / count checks and
was weak on runtime/logic defects: only ~8% of 80 iterations were real logic bugs, and
those surfaced late or twice (iter 30 `knowledge/` dir missing; iter 53 `code-reviewer`
never writes `quality-score.json`; iter 76/80 `quality-gate` ignores regressions).

Before ranking, run a deliberate **functional lens** over every skill — questions that
target behaviour, not surface:

1. **Output gaps:** Does the skill declare or promise an output (a file it writes, a
   JSON key it updates, a return verdict) that no Step actually produces? Grep the
   declared output path/key and confirm a Step writes it.
2. **Gate integrity:** Does a gate/verdict skill (quality-gate, validators) ignore a
   condition it should fail on — e.g. a WARN verdict that does not check regressions?
3. **Lifecycle dead-ends:** Does a Step read a file that no skill in the DAG creates
   (init/backfill mismatch, cf. L4)? Does a consumer expect a format the writer never
   emits (read/write asymmetry, cf. L6)?
4. **Control flow:** Abort/rollback paths that can never be reached, or success paths
   that skip the safety guard.

Findings from this lens are **functional** weaknesses (lever 2 classification) and
should be ranked above cosmetic ones in Step 2.5.

## Step 2.4: Cross-Reference with Research

Compare skills against best practices from Phase 1. If research findings include `agentic_os_context` with `open_issues_from_memory`, treat each as an additional weakness candidate.

## Step 2.5: Rank and Deduplicate

Classify each finding:
- **critical**: Missing required sections, broken logic, security issues
- **warning**: Suboptimal triggers, missing edge cases, inconsistencies
- **suggestion**: Style improvements, nice-to-haves

**Dedup**: Compare each finding against `dedup_history` by name and category. Skip exact or near matches.

If 0 actionable items remain after dedup, report: "DIMINISHING RETURNS: no actionable weaknesses found"

---

# Phase 3: Improvement

Modifies SKILL.md files using a TDD approach (RED/GREEN/REFACTOR) with commit-hash checkpoint rollback. Max 20% change per skill per iteration.

## Step 3.1: TDD Cycle for Each Weakness

For each weakness (critical and warning only):

**RED — Write a test that catches the weakness:**
Append a test case to `tests/validate-skills.sh` that would fail with the current skill.
Run the test to confirm it fails:
```bash
bash tests/validate-skills.sh
```

**GREEN — Apply the minimal fix:**
Use the `Edit` tool to modify the SKILL.md file.

Mutation strategies (informed by research findings):
- **Rephrase**: Improve description for better trigger accuracy
- **Restructure**: Reorganize steps for clarity
- **Augment**: Add missing sections (error handling, edge cases)
- **Constrain**: Add guardrails and safety checks
- **Simplify**: Remove redundant or confusing instructions

**Constraint**: Max 20% of the file's lines may change per iteration.

**GLOBAL — Fix all occurrences of the pattern before commit (lever 1):**
After the minimal fix, do NOT stop at the first occurrence. The historical loop
wasted ~6–8 iterations re-fixing the same pattern in a second file one run later
(e.g. `sync-context` DE→EN trigger in iter 41 → body in iter 50; `tools:` →
`allowed_tools:` in iter 5 → again in iter 56; "10 skills" in `plugin.json` iter 32
→ `marketplace.json` in iter 52). Prevent this:

1. Derive a literal or regex signature for the weakness you just fixed (e.g. the old
   string `tools:`, a DE trigger phrase, a stale skill count `10 skills`).
2. `Grep` that signature across the WHOLE skill/plugin tree
   (`skills/`, `agents/`, `commands/`, `.claude-plugin/`, top-level manifests),
   not just the file you started in.
3. Apply the same fix to every remaining occurrence in the SAME iteration, still
   respecting the per-file 20% constraint (if a file would exceed it, log the
   remainder as a follow-up finding rather than splitting the pattern across runs).
4. Record the grep signature + occurrence count in the iteration's state entry so a
   later run can confirm the pattern is exhausted.

A pattern fixed in one file but left in three others is NOT done — it is a
guaranteed future duplicate iteration.

**REFACTOR — Clean up:**
Ensure consistent formatting. Run all tests:
```bash
bash tests/run-all.sh
```

## Step 3.2: Handle Test Results

**If tests PASS:** Continue to next weakness.

**If tests FAIL:** Rollback to checkpoint:
```bash
cd {target_dir} && git reset --hard {checkpoint_sha}
```
Report: "ROLLBACK: fixes caused test failures — iteration aborted"

## Step 3.3: Commit (No Push)

```bash
cd {target_dir} && git add -A -- ':!.agent-memory'
git commit -m "fix(self-improve): {summary} (iteration #{N})"
```

Do NOT push — the final push happens after all iterations.

---

# Phase 4: Validation

Tests improved skills, evaluates quality, and handles rollback if changes are worse.

## Step 4.1: Run Test Suite

```bash
cd {target_dir} && bash tests/run-all.sh
```

Capture: total tests, passed, failed, error output.

**Baseline sanity re-check (lever 5).** Compare this iteration's total test count
against `BASELINE_TEST_COUNT` from Phase 0. If it is `0` or has dropped to half or less,
treat it as a broken suite, not a passing run: rollback to `checkpoint_sha` and report
`BASELINE-SANITY: test count collapsed mid-run ({BASELINE} -> {now}) — rollback applied`.
A shrinking absolute count means the harness stopped discovering tests; never interpret
"0 failures of 0 tests" as success.

## Step 4.2: Evaluate Quality

**If NotebookLM is available** and a notebook exists for this plugin, use it to compare original vs modified content and score 1-10 on clarity, trigger accuracy, safety, and completeness.

**If NotebookLM is NOT available**, evaluate locally:
1. Check no existing sections were removed without replacement
2. Verify changes address the claimed weakness
3. Confirm formatting consistency
4. If changes reduce clarity or remove safety guards, treat as "WORSE" and trigger rollback

## Step 4.3: Handle Results

**All tests pass AND quality is BETTER/SAME:** Record results, report "VALIDATION PASSED"

**Tests fail OR quality is WORSE:** Rollback:
```bash
cd {target_dir} && git reset --hard {checkpoint_sha}
```
Report: "VALIDATION FAILED — rollback applied"

## Step 4.4: Document Results

Write to `improvements/iterations-{batch_start:03d}-{batch_end:03d}.md`:
```markdown
## Iteration {N} — {date}
### Test Results
- Plugin tests: X/Y passed
- Skill tests: A/B passed
### Quality Score
- Fixes/Findings ratio: X/Y
- False alarm rate: Z%
- Functional fixes: F | Cosmetic fixes: C   <!-- lever 2 substance classification -->
### Verdict: PASSED / FAILED
```

### State<->.md atomicity (lever 4)

In the historical record one third of iterations (56–80) had NO `.md` log block, and
iter 29 was missing entirely — the `.md` write and the `state.json` history append had
drifted apart. They must move together:

1. **Couple the two writes.** Treat "append history entry to `state.json`" and "write
   the `## Iteration {N}` block to the batch `.md`" as one atomic unit per iteration —
   write the `.md` block FIRST, then the `state.json` entry. Never record an iteration
   in `state.json` without its `.md` block.
2. **Consistency check (Step F.2 / wrap-up).** Before finishing the run, assert the
   invariant: *every* `history[*].iteration` in `state.json` has a matching
   `## Iteration {N}` heading in some `improvements/iterations-*.md` file. If any entry
   has no `.md` block, report `STATE-MD-DRIFT: iteration(s) {list} missing .md block`
   and backfill the missing block from the state entry before reporting success.

---

# Iteration Loop and Circuit Breaker

For each iteration (1 to 4), run Phases 1-4 sequentially.

**Before each iteration (except the first), apply the circuit breaker:**
- If previous iteration reported **"diminishing-returns"**: skip remaining iterations
- If previous iteration reported **"rollback"**: skip remaining iterations
- If 2+ consecutive iterations reported "diminishing-returns": note convergence and stop

## Substance-based diminishing-returns stop (lever 2)

The fix-count alone is a poor convergence signal: in the historical retro the
count-based exit (added in iteration 18) NEVER fired across iterations 35–54, even
though the loop there ran almost only translations / consistency edits (`[warning]`).
Add a **substance** criterion on top of the count criterion.

Classify every fix applied in an iteration as either:
- **functional** — fixes a runtime/logic defect (a step that never writes a declared
  output, a gate that ignores regressions, a missing directory, broken control flow), or
- **cosmetic** — language (DE→EN), wording, count/version strings, formatting,
  frontmatter tidy-ups.

Then, in addition to the count-based breaker:
- If **3 consecutive iterations** produced **only cosmetic fixes** (zero functional
  fixes), STOP the loop and report `SUBSTANCE-CONVERGENCE: N iterations of only
  language/count fixes — pausing for review`. Do not keep grinding cosmetic edits.
- Record `functional_fixes` and `cosmetic_fixes` counts in each iteration's state entry
  so this breaker is evaluable from history, not just in-memory.

This is independent of the count breaker: a run can have a healthy fix count and still
be cosmetically converged — that is exactly the failure mode lever 2 catches.

**Important:** If running in acceptEdits mode, subagents may lack Bash access. In that case, run iterations inline to ensure git and test commands can execute.

---

# Final Steps

## Step F.1: Final Push

Check if any commits were made:
```bash
cd {target_dir} && git log --oneline {BASELINE_SHA}..HEAD
```

If no new commits, skip push and report "no changes to push".

Otherwise push (handle failure gracefully):
```bash
cd {target_dir} && git push || echo "PUSH FAILED — changes committed locally but not pushed"
```

## Step F.2: Update State

Update `improvements/state.json`:
- Set `status: "idle"`
- Increment `currentIteration` by the number of completed iterations
- Add history entries for each fixed weakness
- Record quality scores

## Step F.3: Report

Output a summary table:

```
| Iteration | Status | Fixes | False Alarms | Quality Score |
|-----------|--------|-------|--------------|---------------|
| N         | ...    | ...   | ...          | ...           |
```

If converging, note: "Loop is converging — consider reducing frequency or expanding scope."

---

# State History Entry Format

Each iteration records an entry in `state.json` history:

```json
{
  "iteration": 55,
  "fixes": 2,
  "date": "YYYY-MM-DD",
  "weaknesses": ["name-1", "name-2"],
  "false_alarm_count": 0,
  "quality_score": 1.0,
  "tests_before": 171,
  "tests_after": 173,
  "tests_plugin": 73,
  "tests_skill": 100
}
```

---

# Optional: Meta-Improve (1x per run)

The loop improves its own skills. Uses the same Phase 1-4 pipeline but targets the agentic-os plugin itself.

## Recursion Guard

Read `improvements/state.json` and inspect the `metaHistory` array.

- If `metaHistory` is empty or missing → allow the run.
- Otherwise, take the most recent entry and read its `timestamp` field (ISO-8601 UTC string, e.g. `2026-04-23T14:07:31Z`).
- If `timestamp` is missing or unparseable → fall back to the legacy `date` field; if that is also missing, allow the run.
- Compute seconds elapsed since that timestamp (`now_utc - timestamp`).
- If less than **7200 seconds (2 hours / 120 minutes)** have passed, abort with: `META-GUARD: last meta-improve ran {mm} minutes ago; cooldown is 120 minutes`.
- Otherwise allow the run.

This timestamp-based cooldown replaces the older "same date" check, which incorrectly blocked legitimate re-runs on the same day and permitted back-to-back runs across midnight.

## Procedure

Run ONE iteration targeting `{PLUGIN_ROOT}` with focus on:
1. Are skill descriptions triggering accurately?
2. Are instructions clear and complete?
3. Is the loop lifecycle efficient?
4. Are safety mechanisms comprehensive?

After meta-improvement, run all tests. If tests fail, rollback entirely.

Update `improvements/state.json` `metaHistory` with `timestamp` (ISO-8601 UTC) and `date`, changes made, quality score. Both fields are written so the legacy `date` fallback in the recursion guard remains functional.

---

# Optional: Schedule Management

Creates and manages scheduled tasks for automated execution.

## Create or Update Schedule

Use `CronCreate` (preferred) or `mcp__scheduled-tasks__create_scheduled_task` (fallback):
- `taskId`: `"self-improve-loop-v2"`
- `cronExpression`: `"0 3 * * 1"` (Monday 3am, or user-specified)
- `notifyOnCompletion`: `true`

If neither tool is available: "SCHEDULE SKIPPED: no scheduling tools available — run manually."

## Adaptive Scheduling

Read `improvements/state.json` to check convergence:

**If 2+ consecutive "diminishing-returns":**
- Reduce frequency: weekly to biweekly (`"0 3 1,15 * 1"`)
- Notify user: "Loop converging — reduced to biweekly"

**If new skills are added (skill count increased):**
- Trigger immediate one-shot run

## Enable/Disable

- "pause auto-improve": Set `enabled: false`
- "resume auto-improve": Set `enabled: true`

Log scheduling changes via `agentic-os:iteration-logger` with tags: `schedule-manager`, `automated`, `self-improve-loop`.
