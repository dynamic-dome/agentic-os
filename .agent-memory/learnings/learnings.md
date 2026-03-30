# Learnings

## 2026-03-30

- Skills that are only called by other skills (never triggered directly by users) should be inline sections, not separate skills. This reduces plugin complexity without losing functionality.
- The test suite's for-loop over `skills/*/` makes skill deletion safe — removed directories simply disappear from test scope, no explicit cleanup needed.
- When consolidating skills, update marketplace.json skill count too — the validate-plugin.sh test checks for count consistency.
