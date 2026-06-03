# Changelog — Agentic OS

Neueste Eintraege oben. Format: `## [YYYY-MM-DD] Kurztitel`

---

## [2026-06-03] Memory Growth Engine — user.md + soul.md wachsen mit (v3.3.0)

Sprint #1+#2 aus dem Memory-Audit (`Downloads/agentic-os-memory-audit-2026-06.md`). Behebt, dass `user.md` nach 80 Iterationen noch der Init-Stub war und `soul.md` nicht mitwuchs — ohne die Sicherheits-Boundary zu brechen, dass nichts Untrusted autonom in die Agent-Identität schreibt. Master-Plan: `docs/plans/2026-06-03-memory-growth-engine-master-plan.md`. Durchgehend TDD, bidirektional verifizierte Drift-Tests.

- **Phase 0 — Schema (SSoT):** 3 neue Stores in `scripts/mem-schema.sh`: `working/user-candidates.json` (Präferenz-Queue), `identity/user-changelog.json` (Audit/Rollback), `identity/soul-candidates.md` (soul-Growth-Queue). RED-first via voller Datei-Liste in `validate-plugin.sh`.
- **Phase 1 — user.md Growth (wrap-up Step 6):** Toter "3+ Korrekturen"-Direct-Write ersetzt durch Kandidaten-Queue mit `observed/inferred/confirmed`-Klassifikation. Promotion nur `confirmed` ODER (`inferred` + occ≥2 + conf≥0.6). Schwelle 3→2 gesenkt. `signal:mood` wird NIE promoted. Jede Änderung → `user-changelog.json` VOR dem Write (Atomarität). **Trust-Boundary:** Kandidaten nur aus User-Konversation, nie aus web/docs/NotebookLM/Wiki (Memory-Poisoning-Schutz, Unit-42).
- **Phase 2 — soul.md Growth Stufe B (propose, don't commit):** `wrap-up` Step 6.5 sammelt Identitäts-Kandidaten in `soul-candidates.md` (nie Auto-Write). `session-bootstrap` Step 6.5 zeigt beim Start "SOUL CANDIDATES: n — [j/n]"; soul.md-Write NUR auf explizites `j` (die eine, präzisierte read-only-Ausnahme). `memory-maintenance`: 80-Zeilen-Anti-Bloat-Linter für soul.md.
- **6 neue Drift-Tests** (marker-basiert: `(user-growth)`/`(soul-growth)`/`(trust-boundary)` + Konzept-Phrase). Bidirektional verifiziert (strip→FAIL, restore→PASS); der trust-boundary-Test wurde nach erster zu lockerer Fassung gehärtet (gleiche Lehre wie bei den self-improve-Hebeln). Suiten gruen: validate-plugin 175/175, validate-skills 153/153.
- **DEPENDENCIES.md** nachgezogen (neue Stores + Schreiber + die bedingte bootstrap-Ausnahme).

## [2026-06-03] self-improve-Loop um 5 Haertungs-Hebel erweitert (v3.2.6)

Umsetzung des Wiki-TODO `2026-06-02-self-improve-mechanismus-haerten` (5 Hebel aus der 80-Iterationen-Retro). Reine Spec-/Prozess-Haertung am `self-improve`-SKILL.md-Body, manuell eingebaut (No-Self-Mod-Boundary, Policy 5 — der Loop editiert seinen eigenen Pfad nicht autonom). Jeder Hebel ist mit einem eindeutigen `(lever N)`-Marker im Body verankert und durch einen Drift-Test gepinnt.

- **Hebel 1 (Phase 3, groesster ROI):** Pre-Commit-Grep des gerade gefixten Musters ueber den ganzen Skill/Plugin-Tree — alle Vorkommen in derselben Iteration fixen statt nur die Erst-Fundstelle (haette ~6-8 Iterationen gespart: `tools:`->`allowed_tools:` iter 5/56, DE->EN iter 41/50, "10 skills" iter 32/52).
- **Hebel 2 (Circuit Breaker):** substanz-basierter Stopp — 3 Iterationen in Folge nur kosmetische Fixes (Sprache/Counts, kein funktionaler Bug) -> `SUBSTANCE-CONVERGENCE`-Pause. Plus `functional_fixes`/`cosmetic_fixes` im State-Eintrag. Fix-Count allein feuerte iter 35-54 nie.
- **Hebel 3 (Phase 2):** funktionale Analyse-Lens (Output-Gaps, Gate-Integritaet, Lifecycle-Dead-Ends, Control-Flow) — adressiert dass nur ~8% der Funde echte Logik-Bugs waren und die spaet/doppelt kamen.
- **Hebel 4 (Phase 4):** State<->.md-Atomaritaet — `.md`-Block vor State-Eintrag schreiben, `STATE-MD-DRIFT`-Konsistenz-Check + Backfill (iter 56-80 hatten keinen `.md`-Log).
- **Hebel 5 (Phase 0/4):** absoluter Baseline-Sanity-Check — Test-Zahl 0 oder auf <=Haelfte gefallen -> `BASELINE-SANITY`-Abort/Rollback, nicht nur das Per-Iteration-Delta (iter 64 hatte 0 Plugin-Tests, unbemerkt).
- **5 neue Drift-Tests** in `validate-skills.sh` (marker-basiert, bidirektional verifiziert: strip->5x FAIL, restore->5x PASS). Suiten gruen: validate-plugin 174/174, validate-skills 146/146 (war 141).

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
