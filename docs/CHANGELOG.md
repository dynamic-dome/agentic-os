# Changelog — Agentic OS

Neueste Eintraege oben. Format: `## [YYYY-MM-DD] Kurztitel`

---

## [2026-06-02] DEPENDENCIES.md gegen Skill-Realitaet korrigiert + Inter-Skill-Call-Test (v3.2.5)

- `skills/DEPENDENCIES.md` vollstaendig gegen die 13 SKILL.md + 4 Agents neu gefasst: fehlende Reads/Writes ergaenzt (session-bootstrap Cross-Project + learnings.json + working/; wrap-up obsidian-sync-Aufruf Step 7.5 + Cross-Project-Handoff; context-keeper docs-als-SoT + Wiki-Writeback; obsidian-sync patterns.json promotion_status)
- Design-Prinzip 4 korrigiert: Invoker sind wrap-up/self-improve/memory-maintenance (NICHT quality-gate — dessen pattern-extractor/context-keeper stehen nur in toten depends-on-Metadaten); Prinzip 10 (docs-als-SoT) ergaenzt
- Neuer Test (validate-plugin.sh #41b): prueft, dass jeder Skill mit echtem Body-Aufruf eines anderen Skills in Prinzip 4 gelistet ist (depends-on-Metadaten ausgenommen). In beide Richtungen verifiziert; fand sofort einen falschen quality-gate-Invoker-Claim in der Neufassung
- Prio-3-Carry-over: self-improve-Haertungs-TODO im Wiki festgehalten (5 Hebel aus 80-Iterationen-Retro)

## [2026-06-02] Reference-Docs gegen SSoT korrigiert + Drift-Test (v3.2.4)

- `references/memory-structure.md` gegen die SSoT (`scripts/mem-schema.sh`) korrigiert: fehlende Store-Files ergaenzt (`learnings/learnings.json`, `context/open-tasks.json`, `working/current-session.json`); Archiving-Schwellen gegen `memory-maintenance` Step 3/4 berichtigt (iteration-log 500->100, errors 200->50, patterns `last_seen >60d OR confidence <0.3`); SSoT-Source-Header
- `references/skill-template.md`: Layer-Guide gegen die echten 13 Skills (geloeschte `code-reviewer`/`test-validator`/`tdd` -> `quality-gate`), v2->v3
- Neuer Drift-Guard in `validate-plugin.sh`: jeder in `memory-structure.md` dokumentierte Store-Pfad muss real von der SSoT erzeugt werden (doc subset of real); in beide Richtungen verifiziert (173/173)
- Codex-Verifier-Runde: 2 MINOR behoben (patterns-Schwelle vollstaendig, mktemp-Guard robuster)
- PROJECT.md-Version 3.2.2 -> 3.2.4 nachgezogen (war beim 3.2.3-Bump nicht mitgezogen)

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
