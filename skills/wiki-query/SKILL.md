---
name: wiki-query
description: |
  Mid-session lookup in the Obsidian Wiki. Searches for relevant wiki pages
  by topic, concept, or question. Uses authority-aware retrieval for
  source/query/synthesis pages. Returns concise answers with wiki-link
  references. Falls back gracefully when no pages are found.
  Trigger phrases: "check wiki", "wiki lookup", "was sagt das wiki",
  "nachschlagen", "wie funktioniert X in Claude Code", "wiki query",
  "look up in wiki", "what does the wiki say about", "search wiki".

  <example>
  Context: User asks about a Claude Code feature during implementation
  user: "wie funktioniert MCP in Claude Code?"
  assistant: "Laut [[wiki/concepts/mcp-in-claude-code]]: MCP verbindet Claude Code mit externen Tools..."
  <commentary>
  User needs reference information from the wiki. Query the wiki and return
  a concise answer with source links.
  </commentary>
  </example>
user_invocable: true
metadata:
  author: agentic-os
  version: '1.0'
  part-of: agentic-os
  layer: core
---

# Wiki Query

Mid-session lookup in the Obsidian Wiki for reference information, patterns, and project context.

## When to Use

- User asks "how does X work?" about a topic covered in the wiki
- User needs reference information during implementation
- Explicit trigger: "check wiki", "nachschlagen", "wiki lookup"
- When you need context about a Claude Code feature, pattern, or project

## When NOT to Use

- Simple code questions answerable from the current codebase
- When the wiki is not configured (no config.json)
- For writing to the wiki (use obsidian-sync instead)

## Step 1: Read Config

Read `.agent-memory/config.json`:
- Extract `wiki_root`, `project_id`
- If config.json does not exist → output "Wiki not configured for this project." and stop.
- Validate: check if `$WIKI_ROOT/CLAUDE.md` exists. If not → output "Wiki not reachable at configured path." and stop.

## Step 2: Analyze Query

Determine the search strategy based on the user's question:

| Query Type | Target Directories | Example |
|------------|-------------------|---------|
| "How does X work?" | concepts/, sources/claude-code/ | "wie funktioniert MCP?" |
| "What pattern for Y?" | concepts/ (tag: agent-pattern) | "pattern fuer Windows Git Bash?" |
| "Project status Z?" | entities/ | "was ist der Stand bei Sparfuchs?" |
| "What did we learn about W?" | synthesis/, queries/ | "was haben wir ueber Hooks gelernt?" |
| General / unclear | index.md scan | "nachschlagen: Checkpointing" |

## Step 3: Search the Wiki

Execute searches in this order. Stop as soon as you have enough results (max 3 pages):

### 3a: Targeted Search (Filename + Tags)
1. **Concepts**: Glob `$WIKI_ROOT/wiki/concepts/*{query_terms}*.md`
2. **Claude Code Sources**: Glob `$WIKI_ROOT/wiki/sources/claude-code/*{query_terms}*.md`
3. **Entities**: Glob `$WIKI_ROOT/wiki/entities/*{query_terms}*.md`
4. **Synthesis**: Glob `$WIKI_ROOT/wiki/synthesis/*{query_terms}*.md`

Concepts and Entities do NOT have an `authority` field — do not filter by authority on these page types.

### 3b: Tag Search (if 3a yields < 2 results)
Grep across `$WIKI_ROOT/wiki/` for frontmatter tags matching query terms:
```
Grep pattern: "^tags:" then scan following lines for query keywords
```
Limit to 5 file matches.

### 3c: Index Fallback (if 3a + 3b yield 0 results)
Read `$WIKI_ROOT/index.md` and scan for lines containing query terms.
Return matching index entries as **recommendations only** — do not read the full pages.

### 3d: Zero Results
If no pages found at all, output:
"Keine Wiki-Seite zu diesem Thema gefunden. Moechtest du NotebookLM abfragen?"

**Do NOT** fall back to aggressive full-text search over the entire vault.

## Step 4: Read and Synthesize

For each found page (max 3):
1. Read the page content
2. Extract the relevant section(s) that answer the query

### Authority-Aware Prioritization
When multiple pages are found, prioritize by authority — but **only for pages that HAVE the authority field** (sources, queries, synthesis):

1. `authority: official` — prefer these
2. `authority: primary` — second choice
3. `authority: derived` — third choice
4. `authority: inferred` — only if nothing else available

Concepts and Entities have no authority field. They are always considered relevant and are NOT deprioritized.

## Step 5: Output

Format the answer as:
- Concise answer synthesized from found pages
- Source references as `[[wiki/...]]` links
- If contradictions exist between pages: note them explicitly
- If the query is only partially answered: note what's missing

```
{Concise answer}

Quellen:
- [[wiki/concepts/mcp-in-claude-code]] — MCP-Grundlagen
- [[wiki/sources/claude-code/claude-code-mit-tools-ueber-mcp-verbinden]] — offizielle MCP-Doku

{Optional: Contradictions or missing context}
```

## Step 6: Optional Query Persistence

If the query and answer have **lasting value** (would be useful in future sessions):
- Ask user: "Soll ich diese Antwort als Query-Seite im Wiki speichern?"
- If yes: create page in `$WIKI_ROOT/wiki/queries/` with authority: derived
- If no: done

Do NOT auto-save queries. Always ask first.

## Error Handling

- Config missing → "Wiki not configured." Stop gracefully.
- Wiki unreachable → "Wiki path not found." Stop gracefully.
- No results → Suggest NotebookLM. Do NOT search harder.
- Page read fails → Skip that page, continue with others.

## Limits

- Max 3 pages loaded per query
- No full-vault grep as default behavior
- No recursive link-following (don't chase [[links]] inside found pages)
- This skill is read-only — it never writes to the wiki (except Step 6 with user consent)
