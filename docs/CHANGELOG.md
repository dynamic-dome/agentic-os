# Changelog — Agentic OS

Neueste Eintraege oben. Format: `## [YYYY-MM-DD] Kurztitel`

---

## [2026-06-01] Docs-als-SoT durchgezogen + Codex-Verifier-Fixes (v3.2.2)

- Veraltete `docs/plugin-documentation.md` (v2-Stand, nannte geloeschte Agents) entfernt — die Regel-13-Docs decken den Inhalt aktueller ab
- Divergenz-Pfade geschlossen: context-detective + /init lesen jetzt die Docs ZUERST, bevor sie project-context.md schreiben
- Neuer Konsistenz-Test: alle project-context.md-Schreiber muessen Docs-als-SoT referenzieren
- context-keeper: partial-doc-fallback, Retrieval-Mode liest Docs zuerst, Quellenliste konsistent
- PROJECT.md-Version 3.2.1 -> 3.2.2 korrigiert; Hook-Layout um `*Last updated*`-Zeile ergaenzt

## [2026-06-01] Projekt-Dokumentation + Docs-als-Source-of-Truth

- Regel-13-Skelett angelegt: PROJECT.md, CAPABILITIES.md, ARCHITECTURE.md, CHANGELOG.md, HOW-TO-USE.md
- context-keeper liest jetzt die Docs als primaere Quelle fuer project-context.md (Docs = Source of Truth, project-context.md = Cache)
- Hook-Init schreibt das volle 7-Sektionen-Layout (Format-Drift behoben)

## [2026-06-01] Schema Single Source of Truth (v3.2.0/3.2.1)

- `.agent-memory/`-Schema in `scripts/mem-schema.sh` extrahiert; Hook + /init konsumieren dieselbe Quelle (L4-Drift beseitigt)
- Phase-2-Backfill heilt partielle Stores vollstaendig; negativer Drift-Guard im Test
- Codex-Verifier: 5 MAJOR + 2 MINOR behoben

## [2026-06-01] Cross-Project-Handoff gehaertet (v3.1.8/3.1.9)

- Pfad-Fix (~/AI/.agent-memory/session-summary.md), Schreib-Luecke geschlossen
- Status-Board `cross-project-status.md` eingefuehrt; zentraler Handoff auf prepend (Datenverlust-Schutz)
