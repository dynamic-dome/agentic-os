# Changelog — Agentic OS

Neueste Eintraege oben. Format: `## [YYYY-MM-DD] Kurztitel`

---

## [2026-06-13] PreToolUse Shell Circuit Breaker

Neuer deterministischer Command-Hook `scripts/pre-tool-use-circuit-breaker.sh`,
registriert in `hooks/hooks.json` fuer `PreToolUse`/`Bash`. Der Hook liest das
Claude-Code-Hook-JSON ueber stdin, prueft gefaehrliche Shell-Muster und blockiert
vor Ausfuehrung mit Exit-Code `2`.

Blockierte Klassen: rekursive Force-Deletes (`rm -rf`,
`Remove-Item -Recurse -Force`, `rmdir /s /q`), destruktive Git-Aktionen
(`git reset --hard`, `git clean -fd/-xdf`, Force-Push), globale Rechte-/
Ownership-Aenderungen, Format-/Blockdevice-Schreiboperationen und
Download-to-Shell-Pipes.

Tests: neue Unit-Tests in `tests/test_pre_tool_use_circuit_breaker.py`.

## [2026-06-13] Refresh Verify Status Wrapper

Neues Python-Artefakt `tools/refresh_verify_status.py` mit `main`: ruft den
Verified-Scanner und den README-Watermark-Generator nacheinander auf. Der
Standardaufruf `python tools/refresh_verify_status.py` scannt `docs/`, nimmt das
aelteste `verified: YYYY-MM-DD` als Watermark-Datum und aktualisiert `README.md`.

`--dry-run` erzeugt eine Diff-Preview ohne Schreibzugriff. Die Exit-Codes sind
dokumentiert: `0` bei Erfolg, `1` bei fatalen Eingabefehlern und `2` bei
recoverable Skip-Faellen wie fehlendem `docs/`, fehlenden Markdown-Dokumenten
oder keinen gueltigen `verified:`-Zeilen. CI-Integration bleibt Folge-Sprint.

Tests: neuer Integrationstest in `tests/test_refresh_verify_status.py` mit
Temp-Repo-Mock fuer README-Update, Dry-Run und recoverable Skip-Faelle.

## [2026-06-13] README-Wasserscheide-Anzeige

Neues Python-Artefakt `tools/generate_watermark.py` mit
`inject_verify_watermark(readme_path, min_date)`: schreibt die README-Konvention
`<!-- Doku verifiziert bis: YYYY-MM-DD -->` als einzelne Watermark-Zeile direkt nach
dem ersten H1-Heading oder, falls kein H1 existiert, am Dateianfang. Bestehende
Watermarks werden ersetzt und Duplikate auf eine kanonische Zeile reduziert.

Tests: neue Python-Unit-Tests in `tests/test_generate_watermark.py` fuer
Idempotenz, Datums-Updates, Duplikat-Bereinigung und README-Dateien ohne H1.

## [2026-06-13] Verified-Frontmatter-Scanner

Neues Python-Artefakt `tools/verified_scanner.py` mit
`find_min_verified_date(docs_root)`: traversiert Markdown-Dokumentation rekursiv,
extrahiert robuste `verified: YYYY-MM-DD`-Varianten, validiert ISO-Daten und gibt
`{"min_date": "...", "entries": [...]}` zurueck. Die Doku-Wurzel kann direkt uebergeben
oder per `VERIFIED_SCANNER_DOCS_ROOT` gesetzt werden; leere Verzeichnisse, fehlende
Treffer, malformed Daten und unlesbare Dateien erzeugen keine Exception.

Tests: neue Python-Unit-Tests in `tests/test_verified_scanner.py`, eingebunden in
`tests/run-all.sh`.

## [2026-06-12] Session-Bracket-Coverage: wrap-up Session-Harvest + Decision-Scan (v3.6.0)

Der minimal unterstuetzte Workflow ist die Zwei-Aufruf-Klammer (bootstrap am Anfang, wrap-up
am Ende, dazwischen nichts). Befund: die Arbeitsphasen-Kette iteration-logger →
pattern-extractor → skill-generator hing komplett an manuellen `/log`-Aufrufen — wer nur die
Klammer nutzt, fuetterte die Pattern-Pipeline NIE (Live-Beweis: 5 Iterationen, 3 Errors,
Quality-Score null nach Monaten). Zwei neue wrap-up-Schritte schliessen das:

- **Step 1.5 Session-Harvest `(session-harvest)`:** hat iteration-log.md keine heutigen
  Eintraege, rekonstruiert wrap-up die Iterationen der Session (Konversation + git log) und
  delegiert pro Iteration an iteration-logger (1-5 distinct iterations, Counting-Rule).
  Schreibrechte unveraendert: iteration-logger bleibt einziger Writer von iteration-log.md/
  errors.json. Danach Re-Gather, damit Step 4 (pattern-extractor ab 3+) echte Daten sieht.
- **Step 4.5 Decision-Scan `(decision-scan)`:** Architektur-/Stack-/Policy-Entscheidungen
  der Session werden erkannt und an context-keeper delegiert (decisions.json blieb sonst
  leer, weil niemand "record decision" sagt). Trust boundary: conversation+repo only.
- **DEPENDENCIES.md:** Execution-Order + Matrix + Prinzip 4 nachgezogen; neue Sektion
  "Session-Bracket Coverage" dokumentiert, was die Klammer abdeckt und was bewusst
  on-demand bleibt (quality-gate voll, sync-context, self-improve, research-pipeline,
  wiki-query, skill-generator-Erzeugung).
- **Guard-Tests (TDD, erst rot 4×):** validate-plugin.sh bindet beide Marker-Bloecke an die
  Delegation (iteration-logger/context-keeper), die Write-Ownership-Klausel und die
  Graph-Doku (181/185 rot → 185/185 gruen).
- **Bugfix sharepoint-pull-check.ps1:** Handoff-Dateien ohne `target_agent`-Frontmatter
  (z.B. INDEX.md) warfen "Index auf NULL-Array" (live im Bootstrap 2026-06-12). Fix:
  Get-FmField-Guard statt Direktzugriff auf .Matches.Groups; gegen echten Sharepoint
  verifiziert; in den 3.5.1-Cache gespiegelt (byte-diff ok), regulaeres Deploy mit 3.6.0.

Tests gruen: 185 validate-plugin (+4 Bracket-Guards auf Basis 181) +
165 validate-skills + 19 global-schema.

## [2026-06-12] Fix: Command/Skill-Namensschatten entfernt (v3.5.1)

Ein Command mit demselben Namen wie ein Skill beschattet den Skill im Skill-Tool: der Aufruf
`agentic-os:wrap-up` lieferte den COMMAND-Wrapper zurueck (der wiederum "invoke the skill" sagt)
statt des Skill-Bodys — Endlos-Indirektion (L17, live beobachtet 2026-06-12, zwei identische
Versuche). Betroffen waren genau die zwei Wrapper, deren Name mit einem Skill kollidierte:
`commands/wrap-up.md` und `commands/quality-gate.md`.

- **Fix:** beide Wrapper-Commands GELOESCHT (nicht umbenannt). Skills sind direkt
  slash-invocierbar (ground-truth: `/agentic-os:session-bootstrap` laeuft ohne Command-Wrapper)
  — `/agentic-os:wrap-up` und `/agentic-os:quality-gate` funktionieren weiter und treffen jetzt
  direkt den Skill. Umbenennen haette den Schatten nur verschoben.
- **Guard-Test (TDD, erst rot):** validate-plugin.sh prueft, dass KEIN `commands/<name>.md` ein
  `skills/<name>/`-Verzeichnis spiegelt; fing vor der Loeschung beide Kollisionen.
- Doku nachgezogen: CLAUDE.md (10 Commands + Schatten-Verbot), PROJECT.md, CAPABILITIES bleibt
  unveraendert (listete Commands nie), architecture-map.html Sektion 2 (5 Wrapper / 5 Inline /
  8 Skills ohne Command).
- 12 → 10 Slash-Commands. hooks.json (SessionEnd "invoke agentic-os:wrap-up") loest jetzt
  eindeutig zum Skill auf — unveraendert gelassen.

Tests gruen: 180 validate-plugin (−6 Frontmatter-Checks der geloeschten Dateien, +1 Guard) +
165 validate-skills + 19 global-schema.

## [2026-06-12] Handoff-Ownership — lokale vs. globale Uebergaben (v3.5.0)

Next Steps leben jetzt genau einmal — projekt-lokal in `context/open-tasks.json` (neuer
wrap-up **Step 5.5**, SSoT mit `{id,title,status,created,updated,source,cross_project}`; die Hooks erwarteten das
Schema schon, nur schrieb es bisher kein Skill systematisch). Der zentrale Handoff
(`~/AI/.agent-memory/session-summary.md`) haelt max. **1 Block pro Projekt** (7.6a
Ownership-Dedup, Regel 2.5) und **verweist** auf die lokale Quelle statt Next Steps zu
kopieren — inline nur noch `[cross-project]`-Punkte. session-bootstrap liest die lokale
SSoT zuerst (Step 6 Prioritaet gedreht, Dedup lokal-gewinnt). SESSION-WORKFLOW.md §3/§7
entsprechend angepasst (explizit User-genehmigt 2026-06-12, Aenderungsvermerk im Dokument).
Bestands-Handoff migriert (6 → 3 Bloecke, Gate-B-genehmigt, Backup `.bak-2026-06-12`).
4 neue Marker-Tests (`open-tasks-ssot`, `handoff-dedup`, `next-steps-pointer`,
`open-tasks-priority`), alle bidirektional strip→FAIL-verifiziert (L11).
Behebt: Next-Step-Duplikate (2–3x) durch gestapelte Session-Bloecke desselben Projekts.
Plan: `docs/plans/2026-06-12-handoff-ownership-master-plan.md`.

## [2026-06-03] Fix: qualitative Confidence in 4.A-Migration (v3.4.1)

`migrate-global-schema-4A.sh` stuerzte auf realen globalen Stores mit `ValueError: could not convert string to float: 'low'` ab: Legacy-Patterns tragen qualitative Confidence (`low`/`medium`/`high`) neben numerischen Werten, und die Promotion-Gate-Berechnung rief blind `float(out["confidence"])`. Beobachtet am Live-Store `~/.claude-memory/global/` (23 Patterns, 5 mit String-Confidence).

- **Fix:** `coerce_conf()` mappt `very low`/`low`/`medium`/`high`/`very high` → `0.1`/`0.3`/`0.5`/`0.8`/`0.9` (numerische Strings parsen weiterhin; Unbekanntes → Default `0.5`). `out["confidence"]` wird durchnormalisiert, sodass auch der gespeicherte Wert numerisch ist.
- **Regressionstest:** `test-global-schema.sh` erhaelt einen `confidence: "low"`-Pattern, der ohne Crash migrieren, zu `0.3` coercen und als `candidate` landen muss (4 neue Assertions).

Tests gruen: test-global-schema 19/19 (von 16), run-all ALL PASSED. Migration bleibt idempotent, `--dry-run`-Default, Backups `*.4A.bak`, row-count-invariant (in==out).

## [2026-06-03] Global Memory Layer 4.A — Provenance, Promotion, Decay, Privacy (v3.4.0)

Macht den globalen Cross-Project-Layer (`~/.claude-memory/global/`) von einem flachen Pattern-Store zu einem provenance-grounded, selektiv promotenden, alterungsfaehigen Gedaechtnis. Master-Plan: `Downloads/2026-06-03-global-memory-layer-4A-master-plan.md`. **Architektur-Entscheidung: Hybrid** — pure testbare Logik in `scripts/global-schema.sh` (sourcebar), Orchestrierung im sync-context-Prompt, damit die kritischen Invarianten echte strip→FAIL-Unit-Tests bekommen statt nur Marker-greps (L11). Durchgehend TDD, bidirektional verifiziert.

- **Phase 0 — Denylist + Helper (SSoT):** `MEM_GLOBAL_DENY_TAGS` in `mem-schema.sh` (credentials/pii/secrets); 5 pure Helfer in `scripts/global-schema.sh` (`normalize`, `compute_scope`, `passes_promotion_gate`, `apply_decay`, `is_denied`) mit echten Unit-Tests in neuer `tests/test-global-schema.sh` (in run-all.sh; final 16 nach dem Gate-Konsistenz-Fix).
- **Phase 1 — Provenance-Schema + Privacy-Pre-Filter:** sync-context Push stempelt `G-<type>-<n>`, `scope`, `valid_from`, `source_evidence`, `lifecycle`, `source_projects`. Privacy-Filter laeuft VOR dem Gate (denied tags / `signal_type:mood` erreichen den globalen Store nie). `migrate-global-schema-4A.sh` (idempotent, `--dry-run`-Default, Backups `*.4A.bak`).
- **Phase 2 — Promotion-Gate + Pull-Filter + Migration angewandt:** Promotion zu `active` nur bei `confidence≥0.6 ∧ occurrences≥3 ∧ |source_projects|≥2` (0.6-Schwelle woertlich erhalten); Pull serviert nur `lifecycle:active`. **Migration real angewandt:** 44 Eintraege (12 Patterns + 32 Learnings) → 44, 0 Verlust, alle Provenance-Felder gesetzt, `schema_version:4A`.
- **Phase 3 — Decay + Staleness-Wrap:** memory-maintenance Step 4b: globaler Decay −0.1/90 Tage ohne Recall, Floor 0.3, `lifecycle:archived` ab 365d (nie hartes Loeschen). session-bootstrap: read-only `[STALE? …]`-Anzeige >90d (kein Write — Decay bleibt Maintenance-Job).
- **Phase 4 — /memory-audit GLOBAL-Sicht:** read-only Report ueber un-migrierte Eintraege, promotion-gate-Verstoesse, decay-due — nennt den heilenden Skill, mutiert nie.

Tests gruen: validate-plugin 185/185, validate-skills 161/161, test-global-schema 16/16 (von 183/155). Boundaries gewahrt: sync-context manuell, bootstrap read-only, nie hartes Loeschen, Privacy-vor-Gate. Codex-Verifier-MINOR (Doku-Test-Count 14→16, durch den Gate-Konsistenz-Fix) behoben; Live-/memory-audit fand 35 promotion-gate-violations aus dem Migrations-Default → gate-konsistente lifecycle-Zuweisung nachgezogen.

## [2026-06-03] Memory-Audit restliche Hebel #3–#6 (v3.3.1)

Die nach Ground-Truth-Verifikation real verbliebenen Hebel aus dem Memory-Audit (nach Sprint #1+#2). Wiki-TODO: `2026-06-03-agentic-os-memory-growth-restliche-hebel`. Durchgehend TDD, marker-basierte bidirektional verifizierte Drift-Tests.

- **#3 patterns.json-Schema vereinheitlicht:** 3 divergierende Schemata → Kanon = `pattern-extractor` (der einzige Schreiber): `description`/`recommendation`/`evidence` + `severity`. Legacy-Normalisierungs-Tabelle im Skill (`solution`/`prevention`→`recommendation`, `source_errors`/`error_ids`→`evidence`, `name`/`title`→`description`, `pattern-001`→`P{n}`+`previous_id`) + Re-Dedup. Reale 4 Bestands-Einträge lokal mit-normalisiert.
- **#4 Recency-Supersession in sync-context:** Konflikt-Auflösung von Confidence-only auf Write-Time-Supersession umgestellt — neuerer Eintrag bleibt `active`, älterer → `lifecycle:superseded`+`superseded_by` (nie gelöscht), max 1 `active` pro `(type, scope)`. Behebt die Mem0-Interferenz (stale-high-confidence schlägt neu). Confidence rankt nur noch nicht-widersprechende Merges. `lifecycle`-Feld im pattern-extractor-Schema.
- **#5 `/memory-audit`-Command:** read-only Drift/Staleness/Provenance-Report über `.agent-memory/`. Verhindert genau die veraltete-Daten-Panne, die das manuelle Audit hatte (es maß 3 statt 10 learnings → Phantom-Gaps). Meldet nur, mutiert nie, nennt den heilenden Skill. 11 → 12 Slash-Commands.
- **#6 open-tasks-Drift-Trigger:** Heal-Mechanismus existierte (`memory-maintenance` Step 8.2), war aber threshold-gated → lief nie. Fix: Schritt 1.5 im SessionEnd-Hook (liest `context/open-tasks.json` ohnehin) erkennt stray Root-Datei, merged, löscht. Alt-Root-Datei (leer, seit 25. Mai) entfernt.

Tests gruen: validate-plugin 181/181, validate-skills 155/155. Codex-Verifier: durch.

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
