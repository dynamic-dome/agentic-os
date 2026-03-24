# Argentic OS v2 — 20 Optimization Goals

## Overview

20 concrete optimization targets to bring Argentic OS to world-class level, organized in 5 categories.

---

## A: Automation (5 Goals)

### A1: Auto-Trigger for Iteration Logger
**Problem:** Users must manually call iteration-logger after each piece of work — errors get lost.
**Goal:** Automatically detect completed iterations via PostToolUse hook and trigger logging.
**Implementation:**
- Extend PostToolUse hook: after Write/Edit, check if a meaningful code change occurred
- Track change accumulation (file count, line changes) in a lightweight counter
- When threshold reached (e.g., 3+ files changed or test run completed), prompt user: "Log this iteration?"
- Respect opt-out preference in user.md

### A2: AI-Powered Pattern Recognition
**Problem:** Pattern extraction uses simple heuristics (tag overlap, root_cause matching).
**Goal:** Use semantic similarity to detect patterns that share meaning but differ in wording.
**Implementation:**
- Embed error descriptions and root causes as vectors
- Cluster similar errors using cosine similarity threshold (>= 0.8)
- Surface clusters as pattern candidates even without exact tag matches
- Fallback to current heuristics if embedding unavailable

### A3: Predictive Warnings
**Problem:** Patterns are only surfaced reactively after extraction.
**Goal:** Warn proactively when current work resembles a known anti-pattern.
**Implementation:**
- In UserPromptSubmit hook: compare user's prompt against high-confidence patterns
- If similarity >= 0.7 with an anti-pattern, inject warning into system context
- Include the prevention strategy from the pattern
- Track warning effectiveness: did the user avoid the error?

### A4: Adaptive Skill Parameters
**Problem:** Skills use hardcoded thresholds (e.g., confidence >= 0.7 for skill candidates).
**Goal:** Auto-tune thresholds based on project history and effectiveness.
**Implementation:**
- Track skill effectiveness: did generated skills reduce error recurrence?
- If yes: lower threshold for similar patterns (more aggressive generation)
- If no: raise threshold (more conservative)
- Store adaptive parameters in `.agent-memory/config/adaptive-params.json`

### A5: Context-Aware Prompts
**Problem:** SessionStart briefing is static — always the same format regardless of what happened.
**Goal:** Tailor briefing content to the current situation.
**Implementation:**
- If quality score dropped: emphasize code review findings
- If new regressions detected: highlight failing tests first
- If pattern extracted recently: surface recommendation prominently
- If long gap between sessions: provide more detailed context refresh

---

## B: Robustness (4 Goals)

### B1: Memory Doctor Skill
**Problem:** No validation for corrupt JSON, referential consistency, or stale entries.
**Goal:** New skill that diagnoses and repairs memory integrity issues.
**Implementation:**
- Validate all JSON files (syntax + schema)
- Check referential integrity: pattern evidence IDs exist in errors.json
- Detect orphaned entries (patterns without evidence, skills without patterns)
- Archive stale entries (errors older than 90 days with no recurrence)
- Report health score for the memory system itself

### B2: Crash Recovery
**Problem:** If Stop hook fails, session work can be lost.
**Goal:** Ensure no data loss even when hooks fail or sessions terminate unexpectedly.
**Implementation:**
- Write incremental changes to a `.agent-memory/.journal/` directory
- Each change is a timestamped append-only log entry
- On next SessionStart: replay journal entries that weren't committed to main files
- Journal cleanup after successful session end

### B3: Pattern Confidence Decay
**Problem:** Patterns not seen in 30+ days maintain full confidence.
**Goal:** Auto-reduce confidence for stale patterns.
**Implementation:**
- On each pattern-extractor run: check `last_seen` date for all patterns
- Apply decay: `confidence *= 0.95` for each week since last_seen (min 0.1)
- Patterns below 0.2 confidence: move to archive
- Reactivation: if pattern recurs, restore original confidence + boost

### B4: Versioned Memory Snapshots
**Problem:** No way to roll back memory state if corruption occurs.
**Goal:** Periodic snapshots of the entire `.agent-memory/` state.
**Implementation:**
- On SessionEnd: create compressed snapshot in `.agent-memory/.snapshots/`
- Keep last 10 snapshots (FIFO rotation)
- Snapshot metadata: timestamp, session summary, file checksums
- Restore command: `/agentic-os:restore <snapshot-id>`

---

## C: Developer Experience (5 Goals)

### C1: Onboarding Wizard
**Problem:** `/init` creates boilerplate but doesn't capture user preferences.
**Goal:** Interactive setup that configures soul.md and user.md based on user input.
**Implementation:**
- After `/init`: ask 5 key questions (communication style, quality priorities, work patterns, preferred languages, review strictness)
- Generate customized soul.md and user.md from answers
- Detect existing .editorconfig, .eslintrc, prettier config for style preferences
- Offer preset profiles: "strict", "balanced", "relaxed"

### C2: Rich Dashboard (`/agentic-os:dashboard`)
**Problem:** `/status` shows basic stats but no trends.
**Goal:** Visual dashboard with trend charts, top patterns, quality timeline.
**Implementation:**
- ASCII/Unicode charts for quality score over last 10 sessions
- Top 5 recurring patterns with occurrence counts
- Test health trend (last 10 runs)
- Error frequency by category (bar chart)
- Memory usage (file sizes, entry counts)
- Active warnings and recommendations

### C3: Quality Gate Enforcement
**Problem:** Quality scores are informational only — no enforcement.
**Goal:** Optional blocking gate before commits.
**Implementation:**
- Pre-commit check: run quality-gate agent on staged changes
- Configurable thresholds in `.agent-memory/config/quality-gate.json`
- Default: block if code < 60 OR test health < 70 OR critical findings exist
- Override with `--force` flag
- Track gate pass/fail history for effectiveness analysis

### C4: Metrics Export
**Problem:** All data is locked in JSON files — no way to analyze externally.
**Goal:** Export metrics in multiple formats for external analysis.
**Implementation:**
- `/agentic-os:export` command with format options: CSV, JSON, Markdown
- Export categories: quality trends, error frequency, pattern catalog, decision log
- Date range filtering: `--from 2026-01-01 --to 2026-03-24`
- Optional: generate a standalone HTML report with embedded charts

### C5: Multi-Language Support
**Problem:** All output is English only.
**Goal:** Support German and other languages for prompts and output.
**Implementation:**
- Locale setting in `.agent-memory/config/locale.json`
- Translate skill output templates (briefings, summaries, findings)
- Keep technical terms (JSON keys, file names) in English
- User-facing text (descriptions, recommendations) in configured language

---

## D: Scaling (4 Goals)

### D1: Cross-Project Sync (Complete sync-context)
**Problem:** sync-context is documented but unfinished.
**Goal:** Fully functional cross-project pattern sharing.
**Implementation:**
- Create `~/.claude-memory/global/` infrastructure on first sync
- `projects.json` registry with project metadata
- Push: export patterns with confidence >= 0.6 and `generalizable: true`
- Pull: import patterns with confidence >= 0.5 and matching stack_tags
- Conflict resolution: keep higher confidence, merge evidence lists
- Discovery mode: list available projects and their top patterns

### D2: Claude-Memory Bridge
**Problem:** Plugin creates parallel memory system alongside Claude Code's native memory.
**Goal:** Integrate with Claude Code's native memory for identity and preferences.
**Implementation:**
- Migrate soul.md → Claude Code memory (agent identity)
- Migrate user.md → Claude Code memory (user preferences)
- Keep project-specific data (patterns, errors, decisions) in `.agent-memory/`
- Sync on SessionStart: read from Claude memory, merge with local identity files
- Benefit: identity persists across projects without manual sync

### D3: Team Mode
**Problem:** Single-user only — no way to share patterns or decisions across a team.
**Goal:** Team-aware memory sharing via git-based sync.
**Implementation:**
- `.agent-memory/shared/` directory committed to git (team-visible)
- `.agent-memory/private/` directory in .gitignore (individual)
- Shared: patterns, decisions, quality baselines
- Private: user.md, soul.md, session-summary.md
- Merge strategy: append-only for shared files, no overwrites
- Team dashboard: aggregate quality scores across team members

### D4: Windows Compatibility
**Problem:** Bash scripts assume Unix paths — Windows untested.
**Goal:** Full Windows support (PowerShell, Git Bash, WSL).
**Implementation:**
- Create PowerShell variants of all bash scripts
- Platform detection in SessionStart hook
- Path normalization (forward/backward slashes)
- Test on: native Windows (PowerShell), Git Bash, WSL2
- CI pipeline with Windows runner for regression testing

---

## E: Meta (2 Goals)

### E1: Effectiveness Tracking
**Problem:** No way to measure if the plugin actually helps.
**Goal:** Track concrete effectiveness metrics over time.
**Implementation:**
- Track: error recurrence rate (should decrease), time-to-fix (should decrease), pattern-to-skill conversion rate, quality score trends
- Compare: first 10 sessions vs. last 10 sessions
- Generate monthly effectiveness report
- Key metric: "errors prevented" = patterns with prevention strategies that match avoided errors
- Store in `.agent-memory/metrics/effectiveness.json`

### E2: Plugin Marketplace Readiness
**Problem:** Plugin is monolithic — hard to share individual skills.
**Goal:** Make skills individually installable and shareable.
**Implementation:**
- Each skill as a standalone package with metadata (dependencies, version, compatibility)
- Plugin manifest (`plugin.json`) lists installed skills with versions
- Install command: `/agentic-os:install <skill-name>`
- Publish command: `/agentic-os:publish <skill-name>`
- Registry: GitHub-based skill catalog with search and ratings
- Versioning: semver for skills, dependency resolution

---

## Priority Matrix

| Priority | Goal | Impact | Effort |
|----------|------|--------|--------|
| **P0 (Critical)** | B1: Memory Doctor | High | Low |
| **P0 (Critical)** | B2: Crash Recovery | High | Medium |
| **P0 (Critical)** | D1: Cross-Project Sync | High | Medium |
| **P1 (High)** | A1: Auto-Trigger | High | Low |
| **P1 (High)** | A3: Predictive Warnings | High | Medium |
| **P1 (High)** | B3: Pattern Decay | Medium | Low |
| **P1 (High)** | C2: Rich Dashboard | Medium | Medium |
| **P2 (Medium)** | A5: Context-Aware Prompts | Medium | Low |
| **P2 (Medium)** | B4: Versioned Snapshots | Medium | Medium |
| **P2 (Medium)** | C1: Onboarding Wizard | Medium | Medium |
| **P2 (Medium)** | C3: Quality Gate | Medium | Medium |
| **P2 (Medium)** | D2: Claude-Memory Bridge | Medium | High |
| **P2 (Medium)** | E1: Effectiveness Tracking | Medium | Medium |
| **P3 (Low)** | A2: AI Pattern Recognition | High | High |
| **P3 (Low)** | A4: Adaptive Parameters | Medium | High |
| **P3 (Low)** | C4: Metrics Export | Low | Low |
| **P3 (Low)** | C5: Multi-Language | Low | Medium |
| **P3 (Low)** | D3: Team Mode | High | High |
| **P3 (Low)** | D4: Windows Compatibility | Medium | Medium |
| **P3 (Low)** | E2: Plugin Marketplace | High | High |
