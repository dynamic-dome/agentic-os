---
name: research
description: "Start the token-optimized research pipeline via Perplexity, NotebookLM, and Claude."
user_invocable: true
arguments:
  - name: topic
    description: "Research topic or question"
    required: false
---

# Research Pipeline

Run external research with minimal token cost.

## Instructions

Invoke the `agentic-os:research-pipeline` skill. If a topic argument was provided, pass it as the research query.

Use the Skill tool:
```
Skill: agentic-os:research-pipeline
```
