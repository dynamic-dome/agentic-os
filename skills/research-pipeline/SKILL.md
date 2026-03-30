---
name: research-pipeline
description: >
  Token-optimized research pipeline via Perplexity → NotebookLM → Claude.
  Saves ~95% Claude tokens on web research by offloading to specialized tools.
  Trigger: "research", "find sources", "web research", "deep research",
  "search for sources", "gather references", "look up sources".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: research
  depends-on:
    - notebooklm (user-skill, notebooklm-py Python API — prefer over plugin skills)
---

# Research Pipeline Skill

Token-optimized research by offloading to specialized tools.

> **Canonical Location:** This skill lives in agentic-os as a shared skill.
> devil-advocate-swarms, multi-model-orchestrator, and self-improving-agent
> reference this instead of maintaining their own copies.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Phase 1: SEARCH (Perplexity)                 FREE*     │
│  ─────────────────────────────────────────────           │
│  → Open browser → Perplexity search query               │
│  → Extract links + summary                              │
│  → Save locally: research/<topic>-<date>.md             │
├─────────────────────────────────────────────────────────┤
│  Phase 2: INGEST (NotebookLM)                 FREE      │
│  ─────────────────────────────────────────────           │
│  → Load links from Phase 1 into NotebookLM notebook     │
│  → Name notebook by topic                               │
│  → Gemini auto-indexes all sources                      │
├─────────────────────────────────────────────────────────┤
│  Phase 3: ANALYSIS (NotebookLM RAG)           FREE      │
│  ─────────────────────────────────────────────           │
│  → Ask targeted questions to NotebookLM                 │
│  → Extract answers and save locally                     │
│  → Optional: Studio output (mindmap, report, etc.)      │
├─────────────────────────────────────────────────────────┤
│  Phase 4: INTEGRATION (Claude)                ~3K Tok   │
│  ─────────────────────────────────────────────           │
│  → Read saved results (local files)                     │
│  → Integrate into project (code, docs, architecture)    │
│  → Make decisions based on research                     │
└─────────────────────────────────────────────────────────┘
  * Perplexity Pro = flat rate, Free Tier = 5 Pro Searches/day
```

## Token Savings

| Step | Claude Only | With Pipeline |
|------|-----------|--------------|
| Web search | ~10-20K Tokens | 0 (Perplexity) |
| Read sources | ~50-100K Tokens | 0 (NotebookLM) |
| Synthesis | ~5K Tokens | 0 (NotebookLM RAG) |
| Read results | — | ~2-3K Tokens |
| **Total** | **~70-125K** | **~3K** |

**Savings: ~95%**

## Detailed Workflow

### Phase 1: Perplexity Search

1. Open browser → `https://www.perplexity.ai`
2. Formulate search query (specific, with context)
3. Wait for response
4. Extract text + links via `browser_evaluate`
5. Save to `research/<topic>-<YYYY-MM-DD>.md`

**Prompt template for Perplexity:**
```
<Topic> - Focus on:
1) Real-world implementations and GitHub repos
2) Best practices and common patterns
3) Cost/performance tradeoffs
4) Security considerations
```

### Phase 2: NotebookLM Ingest

1. Create notebook: `notebooklm create "Research: <topic>" --json` (parse ID from `id` field)
2. Set notebook context: `notebooklm use <notebook_id>`
3. Add links from Phase 1 as sources: `notebooklm source add "<url>" --json` (note source_id)
4. Wait for indexing: `notebooklm source wait <source_id> -n <notebook_id> --timeout 600` (exit code 2 = timeout → skip source, continue with next)

### Phase 3: NotebookLM Analysis

1. Ask targeted questions via CLI:
   ```bash
   notebooklm ask "What are the concrete use cases for X?" --json
   notebooklm ask "Compare approach A vs B" --json
   notebooklm ask "What are the risks and limitations?" --json
   ```
2. Extract answers from JSON output and save locally
3. Optional: Generate studio outputs (`notebooklm generate report --format briefing-doc`)

### Phase 4: Claude Integration

1. Read local research files (Read tool)
2. Integrate findings into project code/docs
3. Document architecture decisions

## When to Use This Pipeline

**YES — Use pipeline when:**
- Web research on a new topic is needed
- Multiple sources need to be compared
- Deep analysis across 5+ documents/articles
- Recurring research questions on a topic area

**NO — Use Claude directly when:**
- Answer is available in project code/docs
- Simple API doc question (→ context7 MCP)
- Question can be answered from context

## File System Convention

```
research/
├── <topic>-<YYYY-MM-DD>.md          # Perplexity result (raw)
├── <topic>-analysis-<YYYY-MM-DD>.md # NotebookLM analysis
└── <topic>-links.md                 # Extracted links for NotebookLM
```

## Error Handling

### Phase 1: Perplexity Unreachable / Rate Limit

**Problem:** Perplexity returns an error or rate limit (Free Tier: 5 Pro Searches/day) is exhausted.

**Fallback:** Use WebSearch tool directly:
```
→ WebSearch("<topic> best practices site:github.com OR site:stackoverflow.com")
→ Save results manually to research/<topic>-<YYYY-MM-DD>.md
→ Continue with Phase 4 (Phase 2-3 optional)
```

### Phase 2-3: NotebookLM CLI Not Installed

**Problem:** `notebooklm` command not found (`command not found` or `ModuleNotFoundError`).

**Fallback:** Skip Phase 2 and 3, use Perplexity results directly in Phase 4:
```
→ Load research/<topic>-<YYYY-MM-DD>.md with Read tool
→ Continue directly with Claude integration (Phase 4)
→ Token savings reduced, but pipeline remains functional
```

### Phase 2: Notebook Creation Fails

**Problem:** `notebooklm create` returns an error (e.g., API error, network issue).

**Procedure:**
1. Retry once: run `notebooklm create "Research: <topic>"` again
2. If retry also fails → inline research as fallback:
   - Load sources directly via WebSearch or Read tool
   - Save summary locally as `research/<topic>-inline-<YYYY-MM-DD>.md`
   - Continue with Phase 4

### Phase 2: Source Import Timeout

**Problem:** `notebooklm source wait` hangs or source is not indexed within 60s.

**Procedure:**
```
→ Log warning: "⚠ Source <url> timeout — skipping"
→ Continue with successfully imported sources
→ At least 1 source must succeed, otherwise switch to Phase 2 error fallback
```

### Phase 3: RAG Query Returns Empty Result

**Problem:** `notebooklm ask` returns empty answer or "No relevant content found".

**Procedure:**
1. Simplify query and retry:
   ```bash
   # Original (too specific):
   notebooklm ask "What are the concrete implementation details for X in context Y?" --json
   # Simplified:
   notebooklm ask "Explain X" --json
   ```
2. Try alternative phrasing (keywords instead of full question)
3. If result remains empty → fall back to Perplexity raw data (Phase 1 output)

### Authentication Expired

**Problem:** NotebookLM CLI returns `AuthenticationError`, `401 Unauthorized`, or `Token expired`.

**Procedure:**
```
→ Ask user to run: `notebooklm login`
→ Pause pipeline until confirmation
→ Restart from Phase 2 (Phase 1 result remains valid)
```

## Prerequisites

- Perplexity account (Free or Pro)
- Google account for NotebookLM
- `notebooklm-py` CLI installed (`pip install notebooklm-py`)
- Authenticated via `notebooklm login`
