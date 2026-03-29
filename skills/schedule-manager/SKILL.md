---
name: schedule-manager
description: Creates and manages scheduled tasks for automated self-improvement loop execution. Use when "schedule improvement loop", "set up auto-improve", "manage improvement schedule", "automatische Verbesserung planen", "Schedule erstellen".
metadata:
  author: agentic-os
  version: '2.0'
  part-of: agentic-os
  layer: automation
  depends-on:
    - agentic-os:loop-orchestrator
---

# Schedule Manager

Creates, updates, and manages scheduled tasks for automated self-improvement loop execution using the Scheduled Tasks MCP.

## When to Use This Skill

- User wants to automate the improvement loop
- User wants to change the improvement schedule
- After convergence detection (reduce frequency)
- After new skills are added (trigger immediate run)

## Instructions

### Step 1: Check Existing Tasks

Use `CronList` to list all current scheduled tasks. If `CronList` is not available, fall back to `mcp__scheduled-tasks__list_scheduled_tasks`.

Check if a task with ID `self-improve-loop-v2` already exists.

### Step 2: Create or Update Task

**If task does NOT exist — Create:**

Use `CronCreate` (preferred) or `mcp__scheduled-tasks__create_scheduled_task` (fallback) with:
- `taskId`: `"self-improve-loop-v2"`
- `description`: `"Automated self-improvement loop for plugin skills"`
- `cronExpression`: `"0 3 * * 1"` (Monday 3am, or user-specified)
- `prompt`: The full orchestrator prompt (see below)
- `notifyOnCompletion`: `true`

**If task EXISTS — Update as needed:**

Update the task with the changed fields. Use the same tool that successfully listed the tasks in Step 1.

**If NEITHER tool is available**, report: "SCHEDULE SKIPPED: no scheduling tools available — run the loop manually or set up an external cron job."

### Step 3: Orchestrator Prompt for Scheduled Task

The prompt for the scheduled task should be:

```
Run the self-improvement loop for the plugin at {PLUGIN_DIR}.

Steps:
1. Invoke the Skill tool with skill: "agentic-os:loop-orchestrator"
2. The orchestrator handles all phases: research, analysis, improvement, validation
3. Report results when complete

Target: {PLUGIN_DIR}
Max iterations: 4
Safety: circuit breaker, rollback, dedup enabled
```

### Step 4: Adaptive Scheduling

Read `improvements/state.json` to check convergence:

**If 2+ consecutive "diminishing-returns":**
- Reduce frequency: weekly → biweekly (`"0 3 1,15 * 1"`)
- Use `mcp__scheduled-tasks__update_scheduled_task` to update cronExpression
- Notify user: "Loop converging — reduced to biweekly"

**If new skills are added (skill count increased):**
- Trigger immediate one-shot run
- Use `mcp__scheduled-tasks__create_scheduled_task` with `fireAt` set to 5 minutes from now
- TaskId: `"self-improve-immediate-{timestamp}"`

### Step 5: Enable/Disable

Support user commands:
- "pause auto-improve": Set `enabled: false`
- "resume auto-improve": Set `enabled: true`

### Step 6: Log to Agentic-OS Memory

After any scheduling change (create, update, enable/disable), log the action to agentic-os memory:

Use `Skill` tool to invoke `agentic-os:iteration-logger` with:
- **Type**: `refactor`
- **Summary**: "Schedule manager: {action taken} — task {taskId}, cron: {cronExpression}"
- **Tags**: `schedule-manager`, `automated`, `self-improve-loop`
- **Confidence**: 5
- **Learnings**: Note convergence state or reason for schedule change

This ensures scheduling history is tracked in agentic-os memory and visible to pattern-extractor.

### Step 7: Report

Output:
- Current schedule (cron expression in human-readable form)
- Next run time
- Task status (enabled/disabled)
- Convergence state
