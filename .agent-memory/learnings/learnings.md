# Learnings

*Auto-generated from learnings.json — do not edit directly.*

## 2026-03-30

- Skills that are only called by other skills (never triggered directly by users) should be inline sections, not separate skills. This reduces plugin complexity without losing functionality.
- The test suite's for-loop over `skills/*/` makes skill deletion safe — removed directories simply disappear from test scope, no explicit cleanup needed.
- When consolidating skills, update marketplace.json skill count too — the validate-plugin.sh test checks for count consistency.

## 2026-04-30

- [L1] (*****) Python's Default-Encoding unter Windows ist cp1252 — JSON-Dateien mit Umlauten oder UTF-8-Sonderzeichen werden faelschlich als korrupt markiert wenn man `open(path)` ohne `encoding='utf-8'` aufruft. Sync-Skript haette intakte learnings.json mit 72 Eintraegen beinahe als .corrupt.bak weggeschoben. Konsequenz: Alle JSON-Reads in Maintenance-Skripten muessen explizit `encoding='utf-8'` setzen.
- [L2] (****) Cross-Project-Sync vergleicht aktuell nur Pattern-IDs, nicht Inhalt. Wenn zwei Projekte denselben Pattern unter verschiedenen IDs schreiben (z.B. `pattern-001` lokal vs. `windows-git-bash-compat` global), entstehen Duplikate. Pattern-Extractor erkennt sie ueber Jaccard-Description-Match (>=0.6) — sollte aber idealerweise bereits im sync-context-Skill passieren.
- [L3] (***) obsidian-sync braucht `.agent-memory/config.json` als Pflicht-Voraussetzung. Wenn `/agentic-os:init` nie gelaufen ist, scheitert der erste Wiki-Sync still mit 'No wiki config found'. Minimum-Config (project_id, wiki_root, sync_enabled, project_aliases) kann manuell geschrieben werden — ist 5 Zeilen JSON.
