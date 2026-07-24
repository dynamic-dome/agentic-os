---
name: self-improve
description: >
  Self-improvement loop over the plugin: up to 4 iterations of research,
  analysis, TDD-based improvement, and validation, with circuit breaker,
  eval-driven acceptance gate, and git-safe rollback.
  Invoke via /agentic-os:self-improve.
disable-model-invocation: true
metadata:
  author: agentic-os
  version: '4.1'
  part-of: agentic-os
  layer: orchestration
  depends-on:
    - agentic-os:iteration-logger
    - agentic-os:pattern-extractor
---

# Self-Improve Orchestrator

Runs up to 4 sequential improvement iterations, each with research, analysis, improvement, and validation phases. All phases are inline — no external skill delegation.

Historical evidence and the rationale behind every hardening rule ("lever"): `improvements/HISTORY.md`. Cluster definitions: `improvements/clusters.json`.

## When to Use

- Explicit user invocation via `/agentic-os:self-improve` (the skill carries
  `disable-model-invocation: true` — runs never start from conversation phrasing)
- Scheduled runs: note that `disable-model-invocation` also blocks scheduled tasks
  that fire with this skill as their prompt (Claude Code v2.1.196+). A scheduler
  must be set up to run the slash command as a user prompt; if that proves
  unreliable, flip the flag back and accept the context cost.

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
- Rollback via commit-hash checkpoint (`git rev-parse HEAD` + `git reset --hard {checkpoint_sha}`); stash-based rollback is forbidden (fragile with untracked files)

## Self-Improve Policy (hardened 2026-04-30)

Introduced after the plugin audit to prevent recursive chaos. The policy OVERRIDES the constraints — on conflict, the policy wins. Background: `improvements/HISTORY.md`.

1. **Single-Cluster-Rule** — Each run may improve exactly ONE plugin cluster. Cluster definitions live in `improvements/clusters.json` (entries with `"scope": "external"` are foreign plugins and never a target of a run in this repo). If the run would have to enter a second cluster (e.g. a fix touches consumers in two clusters), ABORT and request user intervention — the risk surface of multiple clusters degrades rollback granularity.
2. **Pattern-Confirmation-Threshold** — `pattern-extractor` may flag patterns, but `skill-generator` creates a skill candidate only after **two confirmed recurrences of the same pattern** (logged in two different iterations, at least 24h apart) OR explicit user approval via slash command. Below the threshold: pattern stays in the catalog, no skill build.
3. **Wrap-Up-Discipline** — At run end, `obsidian-sync` writes only **condensed results** to the wiki: max one session note per run under `wiki/queries/YYYY-MM-DD-self-improve-<cluster>.md`, no auto-promotion of raw iteration logs.
4. **MCP-Audit-as-Diagnosis-Only** — If an MCP tool audit or smoke test ran this session, read the result as diagnosis, but NEVER auto-trigger a self-improve run from it. Runs must come explicitly from the user or the scheduler.
5. **No-Self-Mod-Boundary** — `self-improve` must NOT modify its own `SKILL.md` body (meta-improve recursion risk). If its own path is outdated, write a finding to `improvements/meta-suggestions.md` for manual user review. This is the most important safety boundary.
6. **Rollback-Tag-Tightness** — Every self-improve commit gets a git tag `self-improve-{cluster}-{iteration}-{ISO-timestamp}` so `/agentic-os:rollback` reliably returns to the pre-run state. After a successful user-confirmed push the tag is persisted to the remote; on rollback the tag is deleted.

### Verification Checklist (before every Phase-1 step)

1. Single cluster chosen? (Policy 1)
2. Last `obsidian-sync` entry condensed, not raw? (Policy 3, checked in hindsight)
3. Pattern threshold met for all patterns active in this run? (Policy 2)
4. Self-improve skill NOT in the target list? (Policy 5)
5. Rollback tag prefix prepared? (Policy 6)

Any "no" → ABORT with a hint and ask for user confirmation.

## Batch File Naming

```
batch_start = floor((iteration - 1) / 5) * 5 + 1
batch_end = batch_start + 4
filename = iterations-{batch_start:03d}-{batch_end:03d}.md
```

---

# Phase 0: Setup

## Step 0.1: Read State and Dedup History

Read `improvements/state.json` (plugin root). Extract `currentIteration` (next iteration number) and `history` (previously fixed weakness names/categories for dedup). If `status` is `"running"`, abort: "ABORTED: another loop is already running". Then set `status: "running"` and `lastRun` (ISO timestamp).

## Step 0.2: Determine Target Plugin

Default target: the plugin directory itself. The user can specify a different plugin path. Read the target's skill files via `Glob` `skills/*/SKILL.md`.

## Step 0.3: Check Git and Baseline

In the target directory: `git status --porcelain` — if uncommitted changes exist, abort: "ABORTED: uncommitted changes — commit or stash first". Run `bash tests/run-all.sh` — if it fails, abort: "ABORTED: baseline tests already failing".

**Baseline sanity check (lever 5).** Record the absolute test count as `BASELINE_TEST_COUNT`. Compare against `tests_after` of the most recent `state.json` history entry (`PREV_TEST_COUNT`). If `BASELINE_TEST_COUNT == 0` or it dropped to **half or less** of `PREV_TEST_COUNT`, ABORT: `BASELINE-SANITY: test count collapsed ({PREV} -> {BASELINE}) — the suite is broken or not running; refusing to iterate`. This absolute guard catches a suite that silently stopped discovering tests — something the per-iteration delta check (Phase 4) cannot see. No previous entry → skip the comparison but still store `BASELINE_TEST_COUNT`.

Record the current commit hash as safety checkpoint: `git rev-parse HEAD` → `checkpoint_sha`.

## Step 0.4: Load or Initialize Eval Sets (lever 6 setup)

Before mutating anything, every target skill gets a **binary eval set** — the hard acceptance contract Phase 4.2b scores against (objective, pre-declared criteria instead of "looks no worse"). Lever 5 guards the *suite*; lever 6 guards the *skill's own contract*.

For every skill selected this run, read `improvements/evals/{skill-name}.eval.json`. If missing, create it from the skill's declared contract (frontmatter promises + outputs/guards its body claims). Schema — **binary criteria only**, each strictly yes/no:

```json
{
  "skill": "{skill-name}",
  "version": 1,
  "criteria": [
    {"id": "C1", "category": "correctness",  "question": "Does every declared output (file / JSON key / verdict) have a step that writes it?", "weight": 2},
    {"id": "C2", "category": "safety",       "question": "Are all abort/rollback paths reachable and the safety guards intact?", "weight": 2},
    {"id": "C3", "category": "completeness", "question": "Is the frontmatter complete (name, description, metadata) and are trigger phrases English?", "weight": 1},
    {"id": "C4", "category": "format",       "question": "Consistent section/step structure with the other skills?", "weight": 1}
  ],
  "pass_threshold": 0.8
}
```

Add **skill-specific** binary criteria where a skill has an invariant worth pinning (e.g. sync-context: "Does the privacy pre-filter still run before the gate?"; session-bootstrap: "Is the soul.md write still gated on explicit user confirmation?"). No scales, no 1-5 ratings. `max_score` = sum of weights.

---

# Phase 1: Research

Works fully offline; optionally enhanced by WebSearch or NotebookLM.

## Step 1.1: Local Analysis (always runs)

1. **Read local sources** via `Glob`/`Read`: `{target_dir}/.agent-memory/patterns/patterns.json`, `.agent-memory/iterations/`, `improvements/`, `ARCHITECTURE.md` or `CLAUDE.md`.
2. **Analyze skill content** against this checklist: steps numbered with clear tool calls; edge cases and error paths specified; description keyword-rich enough for accurate triggering; safety guards (rollback, abort) present; frontmatter complete; no circular/broken dependencies; consistent formatting with other skills.
3. **Cross-reference patterns**: if patterns.json exists, check for known anti-patterns / missed best practices.

## Step 1.2: Optional WebSearch

Only if local analysis cannot resolve structural issues: search "Claude Code SKILL.md best practices", "prompt engineering for agent skills", or topics tied to the identified weaknesses. Skip if local analysis already yields 3+ actionable findings.

## Step 1.3: Optional NotebookLM

Only if the user explicitly requested it OR a notebook `self-improve-{plugin-name}` already exists: query via the `notebooklm` user-skill. Never create notebooks automatically during the loop.

## Step 1.4: Persist Research Findings

Write `{target_dir}/.agent-memory/research/research-cache.json`:

```json
{
  "skill_name": "...", "cached_at": "YYYY-MM-DDTHH:MM:SSZ", "iteration_number": N,
  "weaknesses": ["..."], "best_practices": ["..."],
  "suggestions": [{"change": "...", "reason": "...", "impact": "high|medium|low"}],
  "sources": "local|local+web|local+notebooklm"
}
```

**TTL**: cache is fresh for 7 days.

---

# Phase 2: Analysis

## Step 2.1: Invoke Pattern Extractor

Invoke `agentic-os:pattern-extractor` via the `Skill` tool: "Analyze the plugin at {target_dir}. Focus on skill quality patterns: vague/over-specific descriptions, missing required SKILL.md sections, inconsistent formatting, missing error handling or safety guards, ambiguous steps." If it returns "Not enough data" (<3 error records), treat as empty and continue.

## Step 2.2: Read Iteration History

Read `{target_dir}/.agent-memory/iterations/iteration-log.md` and `errors.json`. Look for recurring errors, false trigger activations, user feedback.

## Step 2.3: Analyze Skills Directly

Read all `skills/*/SKILL.md`. Check: (1) frontmatter completeness (name, description, metadata); (2) description quality for triggering; (3) instruction clarity (numbered steps, tool calls, edge cases); (4) safety (error handling, rollback guidance); (5) consistency across skills.

## Step 2.3.5: Functional Lens (lever 3)

Surface checks alone miss runtime/logic defects (evidence: `improvements/HISTORY.md`, lever 3). Before ranking, run a deliberate **functional lens** over every skill:

1. **Output gaps:** does the skill declare an output (file, JSON key, verdict) that no Step actually produces? Grep the declared path/key and confirm a Step writes it.
2. **Gate integrity:** does a gate/verdict step or validator ignore a condition it should fail on (e.g. a WARN verdict that skips regressions)?
3. **Lifecycle dead-ends:** does a Step read a file no skill in the DAG creates (init/backfill mismatch)? Does a consumer expect a format the writer never emits (read/write asymmetry)?
4. **Control flow:** abort/rollback paths that can never be reached; success paths that skip the safety guard.

Findings from this lens are **functional** weaknesses (lever 2 classification) and rank above cosmetic ones in Step 2.5.

## Step 2.4: Cross-Reference with Research

Compare against Phase 1 findings. If research includes `agentic_os_context` with `open_issues_from_memory`, treat each as an additional weakness candidate.

## Step 2.5: Rank and Deduplicate

Classify: **critical** (missing required sections, broken logic, security) / **warning** (suboptimal triggers, missing edge cases, inconsistencies) / **suggestion** (style, nice-to-haves). **Dedup** against `dedup_history` by name and category; skip exact or near matches. If 0 actionable items remain: "DIMINISHING RETURNS: no actionable weaknesses found".

---

# Phase 3: Improvement

Modifies SKILL.md files via TDD (RED/GREEN/REFACTOR) with commit-hash checkpoint rollback. Max 20% change per skill per iteration.

## Step 3.1: TDD Cycle per Weakness (critical and warning only)

**RED:** Append a test case to `tests/validate-skills.sh` that fails with the current skill; run `bash tests/validate-skills.sh` to confirm it fails.

**GREEN:** Apply the minimal fix via `Edit`. Mutation strategies: rephrase (trigger accuracy), restructure (clarity), augment (missing sections), constrain (guardrails), simplify (redundancy). **Constraint:** max 20% of the file's lines per iteration.

**GLOBAL — fix all occurrences before commit (lever 1):** Do NOT stop at the first occurrence — a pattern fixed in one file but left in others is a guaranteed future duplicate iteration (evidence: HISTORY.md, lever 1).
1. Derive a literal/regex signature for the fixed weakness (old string, DE trigger phrase, stale count).
2. `Grep` it across the WHOLE tree (`skills/`, `agents/`, `commands/`, `.claude-plugin/`, top-level manifests).
3. Fix every remaining occurrence in the SAME iteration, still respecting the per-file 20% limit (would a file exceed it, log the remainder as a follow-up finding).
4. Record signature + occurrence count in the iteration's state entry.

**REFACTOR:** Ensure consistent formatting; run `bash tests/run-all.sh`.

## Step 3.2: Handle Test Results

Tests PASS → next weakness. Tests FAIL → `cd {target_dir} && git reset --hard {checkpoint_sha}`, report "ROLLBACK: fixes caused test failures — iteration aborted".

## Step 3.3: Commit (No Push)

```bash
cd {target_dir} && git add -A -- ':!.agent-memory'
git commit -m "fix(self-improve): {summary} (iteration #{N})"
```

Do NOT push — the final push happens after all iterations.

---

# Phase 4: Validation

## Step 4.1: Run Test Suite

`cd {target_dir} && bash tests/run-all.sh` — capture total/passed/failed/errors.

**Baseline sanity re-check (lever 5).** If this iteration's total count is `0` or dropped to half or less of `BASELINE_TEST_COUNT`, treat as broken suite, not a pass: rollback to `checkpoint_sha`, report `BASELINE-SANITY: test count collapsed mid-run ({BASELINE} -> {now}) — rollback applied`. Never interpret "0 failures of 0 tests" as success.

## Step 4.2: Evaluate Quality

If NotebookLM is available with a notebook for this plugin: compare original vs modified, score 1-10 on clarity, trigger accuracy, safety, completeness. Otherwise evaluate locally: (1) no sections removed without replacement; (2) changes address the claimed weakness; (3) formatting consistent; (4) reduced clarity or removed safety guards → treat as "WORSE" and rollback.

## Step 4.2b: Eval-Driven Acceptance Gate (lever 6)

Step 4.2 alone is too soft; the eval set from Step 0.4 is the HARD gate on top of the test suite:

1. **Baseline:** score the ORIGINAL skill against `improvements/evals/{skill}.eval.json` (each binary criterion 0/1; `baseline_eval = Σ(passed × weight)`); record as `eval_before` (done at Step 0.4 time, pre-mutation).
2. **Mutated score:** score the mutated skill the same way → `eval_after`.
3. **Gate:**
   - `eval_after > eval_before` AND tests pass → **ACCEPT**.
   - `eval_after == eval_before` AND tests pass → ACCEPT only if the fix addressed a real **functional** weakness; a cosmetic edit holding the eval flat counts as no-progress.
   - `eval_after < eval_before` → **EVAL-REGRESSION**: rollback to `checkpoint_sha`, report `EVAL-REGRESSION: {skill} eval {before}->{after}, criteria lost: {ids}`. A green suite NEVER overrides a dropped eval score.
4. **Failed mutation as research asset:** on EVAL-REGRESSION or rollback, append the discarded skill body + lost-criteria analysis to `improvements/evals/failed/{skill}-{iteration}.md` so no later run re-tries the same dead end.

## Step 4.3: Handle Results

All tests pass AND quality BETTER/SAME → record results, report "VALIDATION PASSED". Tests fail OR quality WORSE → `git reset --hard {checkpoint_sha}`, report "VALIDATION FAILED — rollback applied".

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
- Functional fixes: F | Cosmetic fixes: C
### Verdict: PASSED / FAILED
```

**State↔.md atomicity (lever 4):** the `.md` block and the `state.json` history append are ONE atomic unit — write the `.md` block FIRST, then the state entry; never record an iteration in `state.json` without its `.md` block. Before finishing the run (Step F.2), assert: every `history[*].iteration` has a matching `## Iteration {N}` heading in some `improvements/iterations-*.md`. If not: report `STATE-MD-DRIFT: iteration(s) {list} missing .md block` and backfill from the state entry before reporting success.

---

# Iteration Loop and Circuit Breaker

For each iteration (1 to 4), run Phases 1-4 sequentially. Before each iteration except the first:

- Previous iteration reported **"diminishing-returns"** → skip remaining iterations
- Previous iteration reported **"rollback"** → skip remaining iterations
- 2+ consecutive "diminishing-returns" → note convergence and stop

**Substance-based stop (lever 2):** fix-count alone is a poor convergence signal (evidence: HISTORY.md, lever 2). Classify every applied fix as **functional** (runtime/logic defect: unwritten declared output, gate ignoring a condition, missing directory, broken control flow) or **cosmetic** (language, wording, count/version strings, formatting, frontmatter tidy-ups). If **3 consecutive iterations** produced **only cosmetic fixes**, STOP: `SUBSTANCE-CONVERGENCE: N iterations of only language/count fixes — pausing for review`. Record `functional_fixes` and `cosmetic_fixes` in each iteration's state entry so this breaker is evaluable from history. Independent of the count breaker.

**Important:** in acceptEdits mode subagents may lack Bash access — run iterations inline so git and test commands can execute.

---

# Final Steps

## Step F.1: Final Push

`git log --oneline {BASELINE_SHA}..HEAD` — no new commits → skip push, report "no changes to push". Otherwise: `git push || echo "PUSH FAILED — changes committed locally but not pushed"`.

## Step F.2: Update State

Update `improvements/state.json`: `status: "idle"`; increment `currentIteration` by completed iterations; add history entries per fixed weakness; record quality scores. Run the lever-4 state↔.md consistency check (Step 4.4).

## Step F.3: Report

Output a summary table `| Iteration | Status | Fixes | False Alarms | Quality Score |`. If converging: "Loop is converging — consider reducing frequency or expanding scope."

## State History Entry Format

```json
{
  "iteration": 55, "fixes": 2, "date": "YYYY-MM-DD",
  "weaknesses": ["name-1", "name-2"], "false_alarm_count": 0, "quality_score": 1.0,
  "tests_before": 171, "tests_after": 173, "tests_plugin": 73, "tests_skill": 100,
  "eval_before": 5, "eval_after": 6
}
```

---

# Optional: Meta-Improve (1x per run)

Same Phase 1-4 pipeline, targeting the agentic-os plugin itself.

**Recursion guard:** read `metaHistory` in `improvements/state.json`. Empty/missing → allow. Otherwise take the most recent entry's `timestamp` (ISO-8601 UTC; if missing/unparseable, fall back to legacy `date`; if that is also missing, allow). If less than **7200 seconds (120 minutes)** elapsed, abort: `META-GUARD: last meta-improve ran {mm} minutes ago; cooldown is 120 minutes`.

**Procedure:** run ONE iteration targeting `{PLUGIN_ROOT}`, focused on: trigger accuracy of descriptions, instruction clarity/completeness, loop lifecycle efficiency, comprehensiveness of safety mechanisms. Policy 5 applies — never edit this skill's own SKILL.md. After meta-improvement run all tests; on failure rollback entirely. Update `metaHistory` with `timestamp` (ISO-8601 UTC) AND `date` (legacy fallback), changes made, quality score.

---

# Optional: Schedule Management

**Create/update:** use `CronCreate` (preferred) or `mcp__scheduled-tasks__create_scheduled_task` (fallback) with `taskId: "self-improve-loop-v2"`, `cronExpression: "0 3 * * 1"` (Monday 3am, or user-specified), `notifyOnCompletion: true`. Neither available → "SCHEDULE SKIPPED: no scheduling tools available — run manually."

**Adaptive scheduling:** read `improvements/state.json` for convergence. 2+ consecutive "diminishing-returns" → reduce weekly to biweekly (`"0 3 1,15 * 1"`), notify "Loop converging — reduced to biweekly". New skills added (skill count increased) → trigger immediate one-shot run.

**Enable/disable:** "pause auto-improve" → `enabled: false`; "resume auto-improve" → `enabled: true`. Log scheduling changes via `agentic-os:iteration-logger` with tags `schedule-manager`, `automated`, `self-improve-loop`.
