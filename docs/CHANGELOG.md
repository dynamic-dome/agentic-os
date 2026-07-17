# Changelog — Agentic OS

Neueste Eintraege oben. Format: `## [YYYY-MM-DD] Kurztitel`

---

## [2026-07-17] Release v4.10.0 — T-25 Pivot: offene Tasks in AGENTS.md projizieren

Kern-Erkenntnis aus T-25 (Codex-eigene Session-Transcripts): interaktives Codex
(TUI/Desktop) injiziert SessionStart-Hook-`additionalContext` NICHT — der Marker
fehlt in jedem interaktiven Transcript, waehrend AGENTS.md nachweislich als
user-Message + world_state injiziert und genutzt wird (Codex zitierte L2/L19/L28).
Der Hook-Kanal bedient nur headless `codex exec`. Konsequenz: die dynamische
open-tasks-Info wandert vom Hook in die AGENTS.md-Projektion, den Kanal, den Codex
interaktiv wirklich liest. `bridge_projection.py` rendert jetzt einen zweiten
managed Abschnitt "## Bridge: Offene Tasks" (open/blocked, IDs+Titel, Cap 5) VOR
den Learnings, im selben idempotenten Block; Tasks sind fail-soft (fehlende/korrupte
open-tasks.json -> uebersprungen, nie exit 1; Learnings bleiben kanonisch/exit 1).
Trigger unveraendert: das bestehende wrap-up-Bridge-Gate. Der volatile
Cross-Project-Handoff bleibt bewusst Pointer (globale AGENTS.md), nicht projiziert.
Bridge-Testsuite +6 Faelle (Tasks-only, Tasks+Learnings-Reihenfolge, Cap, korrupt
fail-soft, Idempotenz, Widerruf). Der SessionStart-Hook (4.9.2-4.9.4-Fixes) bleibt
fuer den headless-Pfad aktiv und korrekt.

## [2026-07-17] Release v4.9.4 — T-25 Fix: Codex-Briefing-Hook haengt nicht mehr (stdin)

T-25-Retest (interaktive Codex-TUI in membrain) lieferte via Codex' eigenem
Session-Transcript (~/.codex/sessions/) die harte Evidenz: der SessionStart-Hook
FEUERT interaktiv, aber `SessionStart hook failed: timed out after 5s`. Root-Cause
war eine Regression aus 4.9.3: `PAYLOAD=$(cat)` wartet auf stdin-EOF; interaktives
Codex haelt stdin offen -> `cat` blockiert -> Hook wird nach 5s gekillt -> kein
Briefing (reproduziert: exit 124 gegen offene Pipe). Fix: (a) Normalpfad nutzt
`${CLAUDE_PROJECT_DIR:-$PWD}` (in TUI/`codex exec`/Desktop-im-Projekt ist $PWD =
Projekt) und liest stdin GAR NICHT -> schneller (~2,8s statt Timeout), kein
Hang-Risiko; (b) payload.cwd nur noch als Fallback, wenn dort kein Store liegt, und
dann NICHT-blockierend (`read -r -t 1` statt `cat`). Testsuite 28 Checks (+no-hang
statischer Guard gegen Reintroduktion von `$(cat` + timeout-begrenztes read).
Befund am Rande: Codex Desktop im "neue Aufgabe"-Modus laeuft in einem ephemeren
Pro-Prompt-cwd (Documents\Codex\<slug>) ohne Store — dort ist kein Briefing
moeglich; nur TUI/`codex exec` im Projekt werden bedient.

## [2026-07-17] Release v4.9.3 — T-24/T-25 Fix: Codex-Briefing findet den Store (payload.cwd)

T-25-Sichtpruefung (User, interaktive Codex-Session) falsifizierte die
Interaktiv-Annahme: Codex erhielt KEINEN Kontext (fiel auf globales Wissen
zurueck). Root-Cause: `codex-session-briefing.sh` ermittelte das Projekt via
`${CLAUDE_PROJECT_DIR:-$PWD}` — Codex setzt `CLAUDE_PROJECT_DIR` nicht, und
interaktiv startet der Hook nicht zwingend im Projektverzeichnis, also war
`$PWD` falsch, der Store wurde verfehlt und der Hook fiel in `emit_minimal`
(Ausgabe nur `{"continue": true}`, kein additionalContext). Fix: den vom
SessionStart-Payload getragenen `cwd` (S0-a) auswerten; Vorrang
`CLAUDE_PROJECT_DIR > payload.cwd > $PWD`, Windows-Backslashes normalisiert.
Testsuite 26 Checks (+payload-cwd, +precedence, +win-cwd Backslash-Realfall).
Erklaert, warum headless (dort ist `$PWD` = Projekt) funktionierte, interaktiv
nicht. NOTE: bestaetigt nur die Store-Aufloesung; ob interaktives Codex
additionalContext ueberhaupt ingestiert, bleibt der offene T-25-Retest.

## [2026-07-17] Release v4.9.2 — T-24 Fix: Codex-Briefing UTF-8 (Windows-Mojibake)

Pre-Flight zu T-25 (User-Sichtpruefung) deckte auf: `codex-session-briefing.sh`
lieferte auf Windows durchgaengig Mojibake — der JSON-Escaping-Schritt las stdin
per `sys.stdin.read()` mit cp1252 statt utf-8, wodurch alle Umlaute/Sonderzeichen
(ä/ö/ü/ß, Em-Dash, Pfeil) doppelt kodiert in `additionalContext` landeten
(genau die Windows-Subprocess-Falle aus der globalen CLAUDE.md). Fix: Bytes
explizit als utf-8 dekodieren (`sys.stdin.buffer.read().decode('utf-8','replace')`);
`print()` bleibt ASCII-safe, weil `json.dumps` per Default ensure_ascii ausgibt.
Testsuite auf 22 Checks erweitert (fixture-freier UTF-8-Integritaetstest gegen
den statischen Em-Dash-Header). Betrifft nur den Codex-Briefing-Pfad;
Claude-Verhalten unveraendert.

## [2026-07-16] Release v4.9.1 — T-24 Hotfix: Codex-Briefing-Ausgabeschema

Rollout-Verifikation zeigte: Codex ingestiert bei SessionStart-Hooks NUR
`hookSpecificOutput.additionalContext` (oder rohen stdout) — `systemMessage`
wird ignoriert. codex-session-briefing.sh auf additionalContext umgestellt
(Claude-kompatibel), Testsuite auf 21 Checks erweitert.

S0-e-Korrektur aus dem 4.9.0-Deploy: der Trust-Hash wird ueber die
UNAUFGELOESTE Hook-Definition gebildet — Plugin-Updates brechen den Trust nur,
wenn sich hooks.json selbst aendert. codex-hook-trust.py bleibt trotzdem
idempotenter Deploy-Check ("Nichts zu tun" kostet nichts).

---

## [2026-07-16] Release v4.9.0 — T-24 Codex-Session-Lifecycle

Interaktive (und headless) Codex-Sessions bekommen Bootstrap-Briefing +
Dirty-Tracking ueber dieselben Plugin-Hooks wie Claude. Design + S0-Findings:
membrain/memcodexlifecycle.md.

- **scripts/codex-session-briefing.sh (neu):** schmales Codex-Briefing
  (zentraler Handoff, open-tasks, Atlas-Hinweis); KEIN Auto-Init, exit immer 0,
  stderr leer; Escape-Hatch `AGENTIC_OS_CODEX_HEADLESS=1`.
- **session-start.sh:** Routing-Zweig — liegt das Skript unter `/.codex/`
  (Codex-Plugin-Cache), wird nur das Codex-Briefing gefahren; Claude-Pfad
  unveraendert (Testsuite).
- **posttooluse-dirty-tracker.py:** `agent`-Feld (codex/claude via Skriptpfad);
  `apply_patch` getrackt — Pfade aus dem Patch-Text geparst (Codex liefert kein
  file_path); hooks.json-Matcher entsprechend erweitert.
- **session-bootstrap SKILL.md:** RECOVERY-Zeile traegt Codex-Praefix bei
  `agent: "codex"`.
- **scripts/codex-hook-trust.py (neu, Deploy-Werkzeug):** trusted + enabled
  die 2 agentic-os-Hooks in Codex via app-server (`hooks/list` +
  `config/batchWrite`). NACH JEDEM PLUGIN-UPDATE AUSFUEHREN — der versionierte
  Cache-Pfad im Hook-Command bricht den Trust bei jedem Update (S0-e).
- Tests: test-codex-session-briefing.sh (20 Checks, in run-all.sh verdrahtet),
  dirty-tracker-Suite auf 20 Checks erweitert.

---

## [2026-07-15] Release v4.6.1 — Verifier-Findings an der Rueckfluss-Bruecke

Codex-Verifier-Review von 3fa7751: FAIL, 5 Major + 1 Minor — alle eingearbeitet
(P2 bestaetigt sich 6/6; erster Lauf des rueckfluss-delta-gates auf sich selbst).

- **Major 1 (Writer-Widerspruch):** pattern-extractor-Kanon von "only writer"
  auf "sole creator + schema owner" praezisiert; autorisierte Field-GAIN-Writer
  explizit benannt (obsidian-sync: promotion_status/promotion_scope; Haupt-
  Session: implemented_by/validated_by + Daten per Step 6.6). DEPENDENCIES-
  Matrix beide Zeilen nachgezogen.
- **Major 2 (Store-Ownership):** Step 6.6 schreibt Delta-Entwuerfe nur noch
  nach open-tasks.json (Authority-Trias: Tasks darf jeder Agent schreiben);
  Architektur-Entscheide routen ueber context-keeper, decisions.json wird nie
  direkt geschrieben.
- **Major 3 (Zeitregel unpruefbar):** implemented_at/validated_at (ISO, null-
  Default) neben den Ref-Listen kanonisiert; Vergleichsregel: validated_at
  darf implemented_at nicht vorausgehen + Evidenz aus anderer Session.
- **Major 4 (Idempotenz):** Step 6.6 prueft delta_task_id VOR jedem Draft und
  markiert Patterns mit delta_task_id + delta_drafted_at (analog Step 6.5
  generated_skill); vager Trigger ("clearly implies") gestrichen — nur noch
  explizit benannte Komponenten, sonst Unmatched.
- **Major 5 (Taxonomie erreichte Report nicht):** memory-audit Step-4-Template
  um FINDINGS-Block mit GAP-CLASS-Spalte ergaenzt.
- **Minor 1 (Test zu lasch):** Contract-Test section-scoped (awk-Extraktion je
  Step), Kopplungs-Checks (Scope-Bedingungen beidseitig, Idempotenz-Marker,
  Ownership-Routing, GAP CLASS im Report), Template-Bindung der neuen Felder.

## [2026-07-15] Release v4.6.0 — Rueckfluss-Bruecke Pattern→Verhaltensaenderung (membrain T-15/T-17)

Loop-8-Ernte (membrain memloop8harvest.md, Rosinen 1+3+4): schliesst die letzte
grosse Luecke des Gedaechtnis-Kreislaufs — vom bestaetigten Pattern zur
validierten Aenderung an BESTEHENDEN Komponenten.

- **pattern-extractor (3.1):** kanonisches Schema um `implemented_by` +
  `validated_by` erweitert (ehrliche Leerlisten, Legacy-Eintraege ohne Felder
  bleiben gueltig — gleicher Kontrakt wie derived_from/review_after in v4.4.0).
  Neuer Step 6.6 (rueckfluss-delta-gate): Patterns mit conf>=0.7, deren
  recommendation eine bestehende Komponente betrifft, erzeugen einen
  4-Zeilen-Delta-Entwurf (Affected component / Observed problem / Proposed
  change / Acceptance check) als Task/Decision — NIE eine Auto-Aenderung.
  implemented_by erst nach gelandetem Change; validated_by nur aus Evidenz,
  die NACH implemented_by datiert (die implementierende Session validiert
  sich nie selbst). Herkunftskette geschlossen: iteration → learning
  (derived_from) → pattern (evidence) → change (implemented_by) → effect
  (validated_by).
- **obsidian-sync (1.4), Scope-Gate:** promotion_status "ready" traegt jetzt
  `promotion_scope` — "global" nur bei source_projects >= 2, sonst "project"
  (Haeufigkeit allein beweist keine Uebertragbarkeit); Wiki-Promotion muss
  den Scope respektieren (projektgebundene Notiz statt Konzeptseite).
- **memory-audit (Command), Luecken-Taxonomie:** Step 3.5 klassifiziert jeden
  Befund in 7 Klassen (knowledge/capture/index/retrieval/link/usage/
  feedback-loop-gap) + Diagnose-Regel "zero-hit nach spaetem Filter beweist
  keine Wissensluecke" (L23-Fehlerklasse).
- **Test:** tests/test-pattern-rueckfluss-contract.sh (TDD, RED verifiziert),
  in run-all.sh registriert.

## [2026-07-15] Release v4.5.1 — Verifier-Findings am Decision-Promotion-Release

Codex-Verifier-Review von 9a3dbc3: FAIL, 2 Major + 2 Minor — alle eingearbeitet
(P2 bestaetigt sich 5/5).

- **context-keeper (3.2), Major 1:** zwei Regel-Widersprueche aufgeloest, die den
  Marker-Writeback regelkonform verhinderbar machten — decisions.json-Modus ist
  jetzt "Append + field-extend" (Records duerfen Felder nur GEWINNEN:
  status/wiki_ref/promoted_at), und die "nur context/"-Verbotsregel nennt den
  Step-3.5-Wiki-Writeback als dokumentierte Ausnahme.
- **obsidian-sync (1.3), Major 2:** Idempotenz-Fehlerfenster geschlossen —
  Duplicate guard vor jedem Append (existiert schon ein `### {id}:`-Block, wird
  nicht erneut angehaengt, sondern nur der fehlende Marker nachgetragen;
  self-healing fuer den Fall Wiki-Write ok / Marker-Write fail).
- **Contract-Test, Minor 3+4:** Step-4.5-Checks auf die Sektion gescoped (awk),
  promoted_at + "must NOT set the marker" + successful-Write-Bindung auch fuer
  context-keeper geprueft, neue Tokens (Duplicate guard, self-healing,
  status active, entity-creation exception), Stale-Ref-Negativ-Check
  whitespace-normalisiert (tr) gegen Zeilenumbruch-Maskierung.

## [2026-07-15] Release v4.5.0 — Decision-Promotion (decisions.json → Wiki-Projektion)

membrain Schnitt 5 (T-3): `context/decisions.json` bleibt der fuehrende
Entscheidungsspeicher; das Wiki erhaelt erstmals eine mechanisch idempotente
Batch-Projektion.

- **obsidian-sync (1.2), neuer Step 4.5 Decision Promotion:** promotet
  architekturrelevante Decisions (`architecture-decision`/`stack-change`,
  status active, ohne `wiki_ref`) als Kompakt-Bloecke in die Sektion
  `## Architecture Decisions` des Projekt-Entities; legt bei Bedarf ein
  minimales Entity an (einzige Entity-Erzeugungs-Ausnahme, wird im Report
  ausgewiesen). Idempotenz via Write-back-Marker `wiki_ref` + `promoted_at`
  im decisions.json-Record (reine Feld-Erweiterung). Supersede-Pflege:
  Status-Zeile im Wiki wird markiert, nie geloescht. Stalen Verweis
  "context-keeper Step 4.5" in Step 4 korrigiert (real: Step 3.5).
- **context-keeper (3.1), Step 3.5:** setzt beim Live-Writeback denselben
  Marker, damit Batch- und Live-Pfad sich nicht doppeln; fehlgeschlagener
  Wiki-Write setzt nie einen Marker.
- **Tests:** neuer Contract-Test `test-obsidian-sync-decision-promotion.sh`
  (beide Writer, Marker-Felder, Typ-Filter, Projektion-Richtung, Stale-Ref-Guard);
  in run-all.sh registriert.

## [2026-07-15] Release v4.4.1 — Recovery-Falsch-Positiv nach Wrap-up-Tail-Writes behoben

Organischer T-1-Befund (membrain): Nach einem sauberen wrap-up schrieben Session-Ende-
Writes AUSSERHALB von `.agent-memory/` (native Claude-Memory, Handoff-Dateien) das
Dirty-File erneut — der Hook clobberte dabei `consolidated_at` auf `null`, und der
naechste Bootstrap meldete die laengst konsolidierte Session als RECOVERY-Kandidat.

- **Hook (`posttooluse-dirty-tracker.py`):** Re-Dirty bewahrt die Konsolidierungs-
  Tatsache — `consolidated_at/by` wandern nach `last_consolidated_at/by`, neuer
  Zaehler `writes_since_consolidation`. 3 neue Tests (J/K/L, jetzt 15).
- **session-bootstrap (recovery-detect, neue Regel 4b):** Dirty-File mit
  `last_consolidated_at`, `writes_since_consolidation <= 5` und session_id im
  Marker → Downgrade auf Ein-Zeilen-Notiz statt RECOVERY-Block. >5 Writes seit
  Konsolidierung = echte Arbeit nach wrap-up → weiterhin voller Block.
- **session-start.sh:** mechanischer Check ueberspringt Dirty-Files mit
  `writes_since_consolidation <= 5` (sed-Extraktion, Feld existiert nur nach
  Konsolidierung).
- **wrap-up Step 9.5:** Self-Healing-Regel dokumentiert die bewahrte Historie.

**T-9-Rest — Pre-Run Commit (backup light):** memory-maintenance (1.2) und
obsidian-sync (1.1) haben einen neuen Step 0: Ist `.agent-memory/` git-versioniert,
wird der Store VOR jedem mutierenden Lauf chirurgisch committet
(`git add .agent-memory`, nie `-A`) — Ein-Kommando-Rollback via
`git checkout {hash} -- .agent-memory`. Fail-open: fehlender Snapshot blockt nie.

**Codex-Verifier-Fixes (Review nach Erst-Commit, 2 Major + 2 Minor):**

- Regel 4b verschaerft: Downgrade zusaetzlich nur bei `updated` <= 15 min nach
  `last_consolidated_at` (echte Nacharbeit mit wenigen Writes + Crash bleibt
  voller RECOVERY-Block); Downgrade-Notiz muss Zaehler + Tail-Dateien nennen.
- session-start.sh: Skip verlangt jetzt auch `last_consolidated_at`-Praesenz —
  ein einsamer Zaehler in korruptem State verschluckt keine Recovery mehr.
- Hook: `_safe_count()` fuer writes_since_consolidation UND write_count — ein
  korrupter Zaehlerwert ("kaputt", Liste) legte das Tracking sonst dauerhaft
  still (int() warf, Fail-soft-Catch schluckte, jeder Folge-Aufruf scheiterte
  erneut; gleiche Fehlerklasse wie E4/P3). Test M (jetzt 16).

---

## [2026-07-14] Release v4.3.0 — Crash-sichere Konsolidierung: Dirty-Tracker, Marker, Recovery

Erster Schnitt aus der membrain-Gedaechtnis-Spezifikation (Realitaets-Abgleich
`membrain/memrealitycheck.md`): Der Uebergang Session → Abschluss → naechster Start
haengt nicht mehr allein an Disziplin bzw. Best-Effort-Prompt-Hooks.

**Neu — PostToolUse Dirty-State-Tracker (Hook 7, `posttooluse-dirty-tracker.py`):**

- Schreibt nach jedem erfolgreichen Write/Edit/MultiEdit/NotebookEdit ausserhalb von
  `.agent-memory/` mechanisch `working/dirty-<session_id>.json` (`dirty: true`,
  `touched_files` max 200, `write_count`, Timestamps). Kein LLM, rein mechanisch.
- Fail-soft-Kontrakt: jeder Fehler → stiller No-op, immer Exit 0; atomare Writes
  (tmp + `os.replace`); Skips: `.agent-memory/`-Pfade, Claude-Scratchpad
  (`AppData/Local/Temp/claude/`), `.git/`. Session-Dateien pro session_id →
  parallele Sessions kollidieren nicht.
- 12 Tests in `tests/test-posttooluse-dirty-tracker.py` (in run-all.sh eingehaengt):
  create, dedup, Skips absolut/relativ/case-insensitiv, relativer Work-Pfad, no-store,
  korrupte Datei, garbage stdin, fremdes Tool, Re-Dirty-Self-Healing, Scratchpad-Skip.

**Codex-Verifier-Fixes (Review nach Erst-Commit):** Skip-Marker greifen jetzt auch bei
relativen Pfaden + case-insensitiv (Windows); session-start.sh nutzt while-read statt
unquoted for-loop (Projektpfade mit Leerzeichen); README/CLAUDE.md auf 7 Hooks/v4.3.0
aktualisiert (Design-Prinzip ehrlich angepasst: einziger Per-Edit-Hook ist der
mechanische Dirty-Tracker).

**wrap-up 4.0 → 4.1 — Konsolidierungsmarker (`consolidation-marker`):**

- Step 1 liest `working/dirty-*.json` als harte Evidenz; Step 1.5 harvestet auch
  fremde/verwaiste Dirty-Sessions (`recovered from session {id}`), erfindet nichts.
- Neuer Step 9.5: schreibt `.agent-memory/consolidation-marker.json`
  (last_wrapup, consolidated_sessions, Zaehler), setzt konsumierte Dirty-Files auf
  `dirty: false` + `consolidated_at/by`. Loescht nie (Archivierung ist
  memory-maintenance). Bei unvollstaendigem wrap-up: kein Marker, kein Reset —
  ehrlicher Dirty-State ist die Recovery-Grundlage. Self-Healing-Regel: konsolidierte
  Parallel-Session re-dirtied sich beim naechsten Write selbst.

**session-bootstrap 3.0 → 3.1 — Recovery Detection (`recovery-detect`, read-only):**

- Dirty-Files mit `dirty: true` und `updated` aelter als 30 Minuten → RECOVERY-Block
  im Briefing (Session-ID, Writes, Beispieldateien, wrap-up-Empfehlung). Juengere
  Dateien = vermutlich laufende Parallel-Session, nie flaggen. Marker-Cross-Check
  gegen False Positives. Bootstrap bleibt strikt read-only.

**session-start.sh v3 → v4:** mechanischer Grep-Check derselben Bedingung direkt im
SessionStart-Hook — die RECOVERY-Zeile erscheint auch, wenn niemand session-bootstrap
aufruft. Live getestet (alte Dirty-Datei erkannt, frische ignoriert).

**memory-maintenance:** archiviert nur konsolidierte Dirty-Files (`dirty: false`,
aelter 7 Tage); `dirty: true` ist Recovery-Evidenz und wird NIE geloescht.

Suite: 49 PreToolUse-Tests + wrap-up-Memory-Contract weiterhin gruen.

---

## [2026-07-06] Release v4.0.0 — Konsolidierung: 9 Skills, Identity-Growth-Fixes, Token-Diaet, Threshold-SSoT

**BREAKING — Komponenten entfernt:**

- **5 Skills geloescht:** `retrospective` (Trend-Report ohne Konsumenten), `research-pipeline`
  (User-Level-Skills decken das besser), `wiki-query` (Wiki-MCP/direktes Read reicht),
  `quality-gate` (Review/TDD wandert zu User-Level-Skills + Test-Suite),
  `skill-generator` (in `pattern-extractor` Step 6.5 gefaltet — der alleinige
  patterns.json-Writer generiert jetzt selbst die Skills seiner Kandidaten). 14 → 9 Skills.
- **1 Agent geloescht:** `quality-gate`. 4 → 3 Agents (context-detective, improvement-agent, research-agent).
- **5 Wrapper-Commands geloescht:** `/log`, `/patterns`, `/research`, `/sync`, `/run-loop` —
  duenne Wrapper um direkt invocierbare Skills (Schatten-Risiko L17). 10 → 5 Commands
  (init, status, rollback, auto-commit, memory-audit).

**Identity-Growth-Fixes (Pipeline verhungerte monatelang still):**

- wrap-up Step 6.5: **Pflicht-Statuszeile** `(identity-visible)` — Identity-Growth skippt nie
  mehr still; jede wrap-up-Ausgabe enthaelt genau eine Identity-Zeile.
- Step 6.3 **Queue-Re-Review** `(queue-re-review)`: JEDER Kandidat in user-candidates.json wird
  reviewt, nicht nur die dieser Session (enqueue-only liess Promotions wochenlang liegen).
- Step 6.1 **Harvest-Checkliste** `(identity-harvest)`: konkreter 5-Punkte-Scan (Korrekturen,
  explizite Regeln, Workflow-Gewohnheiten, bestaetigte Ansaetze, Kommunikations-Anforderungen)
  statt vagem "scan the session".
- Step 6.4 **Eskalationspfad** `(escalation-path)`: promotete user.md-Eintraege, die 2+ Sessions
  re-bestaetigt wurden oder Agent-Verhalten beschreiben, eskalieren nach soul-candidates.md.
- SessionStart-Hook injiziert jetzt **identity/user.md** in den Session-Kontext.

**Token-Diaet (Descriptions/Prompts landen permanent in jedem System-Prompt):**

- Hook-Prompts gestrafft; Skill-/Agent-Descriptions auf ~50-60 Woerter gekuerzt
  (`<example>`-Bloecke raus, Trigger auf die 5-6 wichtigsten reduziert, Englisch erhalten).
- session-bootstrap: Read-Deckelung (Learnings via RAG/`scripts/learnings_top.py` statt
  Full-Read, errors.json nur Tail, Entity-Seiten max 80 Zeilen).

**Neue SSoT-Skripte:**

- `scripts/memory-thresholds.sh` — EINZIGE Definition aller Skalierungs-Schwellen
  (exit 10 bei Ueberschreitung). Konsumiert von session-bootstrap Step 3, wrap-up Step 9,
  memory-maintenance Step 3. Skill-Bodies nennen keine Zahlen mehr (iteration-loggers
  widerspruechliche 500/200er-Rotation entfernt).
- `scripts/learnings_top.py` — deterministisches Salience-Ranking
  (`importance*0.4 + recency*0.3 + tag_overlap*0.3`) fuer den Bootstrap-Fallback.
- `skills/wrap-up/references/handoff-template.md` — SSoT fuer den Cross-Project-Handoff
  (Prepend-Algorithmus, Dedup, Hard-Cap, Templates), von wrap-up Step 7.6 gelesen.
- memory-maintenance Step 3b: raeumt `working/`-Leichen auf (*.py/*.tmp/*.bak aelter 7 Tage;
  current-session.json + user-candidates.json ausgenommen) — bisher fuehlte sich kein Skill
  zustaendig.

Doku nachgezogen: plugin.json (4.0.0, 9 Skills), CLAUDE.md, DEPENDENCIES.md (v4-Datenfluss +
Removed-Begruendungen), PROJECT/CAPABILITIES/ARCHITECTURE.

## [2026-06-27] Release v3.9.0 — Wiki-Session-Summary-Auto-Sync gehaertet

Die Auto-Wiki-Session-Zusammenfassung (SessionEnd-Hook → wrap-up Step 7.5 → obsidian-sync)
existierte vollstaendig, feuerte aber unzuverlaessig: bei normal beendeten Sessions verfehlte
das Gate einzelne reale Iterationen, und ein nicht erfuelltes Gate fuehrte zu einem **stillen
Skip ohne jede Ausgabe** — wodurch sich das Feature "kaputt" anfuehlte (agentic-os-plugin
selbst hatte seit 2026-06-12 keine Wiki-Note mehr, obwohl mehrere Releases dazwischenlagen).
Drei Haertungs-Hebel, alle innerhalb der bestehenden Kette, je strip→FAIL-verifiziert (L11):

- **(wiki-sync-visible):** wrap-up Step 7.5 und obsidian-sync skippen nie mehr still — in
  jedem Fall eine sichtbare Status-Zeile (`Note geschrieben → …` / `übersprungen — {Grund}` /
  `fehlgeschlagen — …`). Der stille Skip war die Hauptursache des "passiert nichts"-Eindrucks.
- **(wiki-sync-gate):** Substanzialitaets-Gate gelockert von `>= session_note_threshold (2)`
  auf "ANY: >= 1 Iteration heute ODER heutige Commits ODER importance≥4-Learning ODER neue
  Decision". Eine einzelne echte Iteration / ein Commit rechtfertigt bereits eine Note;
  in wrap-up UND obsidian-sync identisch verankert.
- **(sessionend-wiki-verify):** Der SessionEnd-Hook ist jetzt Backstop — bei sync-enabled +
  substanzieller Session prueft er, ob eine heutige `wiki/queries/{date}-session-{project}*`-Note
  existiert, und ruft sonst obsidian-sync nach. Bleibt reine Delegation (keine dupl. Schreiblogik).

**Bekannte Grenze (bewusst):** Eine plugin-interne Haertung greift NICHT bei hart
abgebrochenen Sessions (Crash) oder headless-Laeufen mit `disableAllHooks` (autonome
Bridge-Runs) — dort feuert kein Hook. Das deckte ein optionaler deterministischer
command-Hook mit git-Fallback-Stub ab (nicht umgesetzt, bewusst verworfen).

Tests: +5 Marker-Tests (4 in validate-skills.sh, 1 in validate-plugin.sh), alle Suiten gruen.

## [2026-06-24] Release v3.8.0 — Eval-driven self-improve (lever 6) + retrospective skill (14.)

Zwei Mechanismen aus der v1.0-"self-improving-agent"-Urgeneration ins aktuelle Plugin
ueberfuehrt (die anderen fuenf Urvaeter-Skills waren bereits — oft moderner — aufgegangen):

- **self-improve lever 6 (Eval-Driven Acceptance Gate):** Phase 0.4 legt pro Ziel-Skill ein
  binaeres Eval-Set an (`improvements/evals/<skill>.eval.json`); Phase 4.2b scort die Mutation
  vor/nach gegen dieses Set und rollbackt bei `EVAL-REGRESSION` (gesunkener Eval-Score) —
  unabhaengig davon, ob die Test-Suite gruen ist. Haertet die bisher weiche, subjektive
  Phase-4.2-Quality-Pruefung (lever 5 schuetzt die Suite, lever 6 den Skill-Kontrakt).
  Verworfene Mutationen landen als Research Asset in `improvements/evals/failed/`.
- **retrospective (14. Skill, quality-Layer):** Multi-Session-Trend-Metriken (Effizienz,
  Qualitaet, Lernen, Wachstum), Blind-Spot-Analyse und Health-Grade, read-only ueber den
  Store, schreibt nur `retrospectives/`. In die bootstrap+wrap-up-Klammer eingehaengt
  (wrap-up Step 10, periodisch: Metriken >7d alt ODER 5+ neue Iterationen) — sonst toter
  Code mit gruener Suite (L19).

Beide TDD-abgesichert (RED→GREEN, Marker `(lever 6)` / `(periodic-retrospective)`,
bidirektional verifiziert, L11). Skill-Count 13→14 ueber alle Manifeste/Doku gezogen
(plugin.json, marketplace.json, README, CLAUDE.md, ARCHITECTURE, CAPABILITIES,
skill-template, DEPENDENCIES). Versions-Bump `3.7.0` → `3.8.0`.

## [2026-06-21] Release v3.7.0 — Skill-Datenfluss-Fixes + Versions-Bump

Versions-Bump `3.6.0` → `3.7.0`. Buendelt die seit 3.6.0 angesammelte Feature-Arbeit
(PreToolUse Shell-Circuit-Breaker-Hook, die `verified_scanner`/`generate_watermark`/
`refresh_verify_status`-Tool-Pipeline, quality-gate-Tool-Signal, wrap-up Long-Term-Memory-
Routine) zu einem Release und ergaenzt zwei funktionale Skill-Fixes aus Self-Improve-
Iteration #81:

- **skill-generator** liest jetzt die kanonischen Pattern-Felder `evidence`/`recommendation`
  statt der Legacy-Namen `error_ids`/`recommended_action`/`avoid`, die pattern-extractor
  (alleiniger Writer) wegnormalisiert — repariert die Pattern→Skill-Generierungs-Pipeline.
- **obsidian-sync** Rolling-Synthesis gated jetzt auf `importance >= 4` (learnings.json-
  Schema, wie wrap-ups eigener Trigger) statt auf das nie geschriebene Feld `salience`.

Beide mit RED→GREEN-Tests in `validate-skills.sh` abgesichert.

## [2026-06-13] PreToolUse Shell-Circuit-Breaker

Neuer command-basierter `PreToolUse`-Hook fuer `Bash`: `scripts/pretooluse-shell-circuit-breaker.sh`
liest das Claude-Code-Hook-Payload von stdin, extrahiert den Shell-Befehl und blockiert
bekannte Hochrisiko-Aktionen deterministisch mit Exit-Code `2`. Abgedeckt sind unter
anderem rekursives Forced-Delete, `git reset --hard`, `git clean -fd*`, Remote-Script-Pipes,
PowerShell-Download-Cradles, Disk-/Shutdown-Kommandos sowie rekursive Rechte-/Owner-Aenderungen.

`hooks/hooks.json`, README, Scripts-Doku und `docs/CAPABILITIES.md` dokumentieren die neue
sechste Hook-Flaeche. Neuer Funktionstest `tests/test-pretooluse-shell-circuit-breaker.sh`
prueft Allow-/Block-Faelle inklusive Exit-Code `2` und ist in `tests/run-all.sh` eingebunden.

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

## [4.0.1] - 2026-07-06

### Fixed
- Codex-Verifier-Runde (§9): memory-thresholds.sh Doppel-Null-Bug bei grep -c ohne Treffer; memory-maintenance Step 6/7 Zeilen-Limits an Threshold-SSoT delegiert; optimization-goals C3 als obsolet markiert; architecture-map.html Historik-Banner.
