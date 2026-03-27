---
name: skill-generator
description: >
  Turns recurring workflows into reusable skills. Use when you notice you keep
  doing the same multi-step process, when pattern-extractor flags a skill candidate,
  or when you want to automate a workflow you just did manually. Reads the pattern
  catalog and generates properly structured SKILL.md files that can be used by
  any Claude Code agent.
  Trigger: "generate skill", "make this a skill", "create skill",
  "I keep doing this", "I keep repeating this", "this is repetitive",
  "can we automate this", "same thing over and over", "automate this workflow".
user_invocable: true
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: core
---

# Skill Generator

Generate new skills from recurring patterns and save them to `.agent-memory/generated-skills/`.

## When to Use

- Pattern-extractor identified a `skill_candidate: true` pattern
- User wants to save a recurring workflow as a reusable skill
- User explicitly requests skill generation from a pattern or workflow description

## Step 1: Identify Source

Determine the basis for the new skill:

**Option A: From Pattern Catalog**
- Read `.agent-memory/patterns/patterns.json`
- Find entries with `skill_candidate: true`
- Load associated `error_ids` from `.agent-memory/iterations/errors.json` for details

**Option B: From Current Workflow**
- Analyze the conversation history of the current session
- Identify the steps of the workflow to be saved as a skill

**Option C: From User Description**
- The user describes the desired workflow
- Supplement with context from `project-context.md` and `patterns.json`

## Step 2: Derive Skill Structure

Extract from the source:

1. **Name**: Short, descriptive slug (lowercase, hyphens)
   - Derive from pattern title: "Lazy Imports for Circular Dependencies" -> `fix-circular-imports`
   - Max 64 characters, no special characters except hyphens

2. **Description**: When should the skill be activated?
   - Include concrete trigger words and situations
   - Max 1024 characters

3. **Steps**: Derive from the pattern's `recommended_action` and iteration details

4. **Anti-Patterns**: From the `avoid` field — what should the agent NOT do

## Step 3: Generate SKILL.md

Create the file using this template:

```markdown
---
name: <skill-name>
description: >
  <Description with trigger words for when the skill should be used>
user_invocable: true
---

# <Skill Title>

## When to Use
<Situations where the skill should be activated>

## Prerequisites
<What must be in place before the skill is executed>

## Instructions

### Step 1: <Title>
<Instruction>

### Step 2: <Title>
<Instruction>

...

## Avoid (Anti-Patterns)
- Do not: <what not to do>
- Do not: <what not to do>

## Example
<Concrete example with input and expected output>
```

## Step 4: Quality Check

Verify the generated skill:

- [ ] Name is valid (lowercase, hyphens, 1-64 chars, no leading/trailing hyphen)
- [ ] Name is unique — check `.agent-memory/generated-skills/` and `patterns.json` for duplicate `generated_skill` fields; if a skill with the same name already exists, append a version suffix (e.g. `-v2`) or abort and inform the user
- [ ] Description contains trigger words
- [ ] Steps are clear and executable without additional context
- [ ] Anti-patterns are included (if available)
- [ ] At least one concrete example
- [ ] Content is actionable and specific
- [ ] Confidence threshold met — only generate a skill if the source pattern has `confidence >= 0.5` or `occurrences >= 2`; skip low-confidence candidates and inform the user

## Step 5: Save

1. Save the SKILL.md to `.agent-memory/generated-skills/<skill-name>/SKILL.md`
2. Update the pattern entry in `patterns.json`:
   ```json
   "generated_skill": "<skill-name>",
   "skill_generated_at": "<ISO 8601>"
   ```

## Step 6: Confirmation

Output:
```
New skill generated: "<skill-name>"
  Source: Pattern "<pattern-title>" (<n> occurrences)
  Steps: <n>
  Anti-patterns: <n>

  Saved: .agent-memory/generated-skills/<skill-name>/SKILL.md

  Next steps:
  - Review skill and adjust if needed
  - Skill is now available as reference in future sessions
```

## Example: Generated Skill from Pattern

From a pattern with `id: lazy-import-for-circular-deps`, the generated skill would:
- Be saved as `.agent-memory/generated-skills/fix-circular-imports/SKILL.md`
- Contain steps: 1) Identify import chain, 2) Apply lazy import, 3) Verify
- Include anti-patterns: Don't manipulate import order in __init__.py, Don't use TYPE_CHECKING as runtime fix
