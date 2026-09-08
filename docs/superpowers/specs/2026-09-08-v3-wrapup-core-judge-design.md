# V3 — wrap-up in Core (Skript) und Judge (≤3 Turns) trennen

*Design-Spec, 2026-09-08. Owner-Freigabe: Ansatz A, Abschnitte 1–3 im Brainstorming bestätigt.*
*Quelle der Vorentscheide: `~/AI/membrain/memgesamtanalyse-2026-09.md` (V3/V4), Wiki-TODO
`2026-09-08-agentic-os-gesamtanalyse-umsetzung.md`. Zielversion: 5.1.0 (MINOR).*

## 1. Problem

wrap-up ist mit 34 KB der größte Skill-Body und läuft als Kette von Modell-Turns, von denen
die meisten reine Mechanik ausführen (Harvest, Summary-Rendering, Handoff-Prepend, Wiki-Note,
Marker). Gemessen: 88 bzw. 102 API-Calls pro Lauf (2026-09-08), Kosten 94 % Kontext-Transport.
Drei Nebenäste rufen weitere Skills auf (obsidian-sync, pattern-extractor) — jede
Skill-Body-Injektion trägt ein 41 %-Risiko eines vollen Prefix-Cache-Rewrites (L34/D-010).
Folge: die wrap-up-Gewohnheit riss im August ab; ohne wrap-up fließt kein Wissen (F3).

## 2. Ziel und Definition of Done

- `/agentic-os:wrap-up` läuft in **≤3 Modell-Turns** (gemessen mit `measure_session_cost.py`,
  Zahl im CHANGELOG gegen die letzten Läufe 88/102 API-Calls).
- Ein modellfreier Skript-Pass (`scripts/wrapup_core.py apply` ohne Plan) erzeugt eine
  **gültige Konsolidierung**: Summary-Delta, zentraler Handoff, Status-Board-Sektion,
  Wiki-Note, Projektionen, Marker. Das ist die V4-Leitplanke (headless aus `session_end.py`).
- Learnings, Decisions und Identity entstehen **ausschließlich** im Judge-Plan — der Core
  erfindet kein Urteil.
- wrap-up ruft **keinen** Skill mehr auf (Test: Delegation-Budget = 0).
- `apply_wrapup.py` und seine 120 Tests bleiben unverändert (Beweis, dass die Store-Writer
  nicht bewegt wurden).

## 3. Scope-Entscheide (Owner, 2026-09-08)

Aus dem wrap-up-Fluss entfernt (kein Turn, kein Skill-Aufruf):

| Ast | heute | neu |
|---|---|---|
| RAG-Dedup je Learning (3a.2) | 1 Atlas-Call pro Kandidat | entfällt; lokaler Exact/Jaccard-Dedup im Applier bleibt, Cross-Projekt-Duplikate zeigt der Atlas-Rebuild |
| NotebookLM-Angebot (Step 7) | konditionales Angebot | entfällt; User-Skill `notebooklm` bleibt manuell |
| Sharepoint-Delta (7.6c) | Handoff-Datei schreiben | entfällt; Core meldet nur `sharepoint_touched: true` im Tally, Schreiben via `/agentic-os:sync-context` oder manuell |
| pattern-extractor-Aufruf (Step 4) | Skill-Injektion bei Skill-Kandidaten | `extract_patterns.py --update` mechanisch im Core; Kandidaten nur als Empfehlungszeile im Bericht |
| obsidian-sync-Aufruf (Step 7.5) | Skill-Injektion | Session-Note ist deterministische Projektion des Core; obsidian-sync bleibt manueller Skill für Entity/Synthese/Decision-Promotion (Narrativ-Verlust akzeptiert, Owner 2026-09-08) |

Identity-Harvest: **im Plan-Turn mit striktem Schema** (kein eigener Turn, Pflicht-Sektion,
Pflicht-Statuszeile — UC7 „nie skippen" wird mechanisch erzwungen, siehe §5).

Einstiegspunkt: Skill-Name bleibt `wrap-up`, sein Body IST der Judge. Core ist
`scripts/wrapup_core.py`. Kein Rename, kein zusätzlicher Command.

## 4. Architektur (Ansatz A)

`scripts/wrapup_core.py` ist ein eigenes Modul, das `apply_wrapup.py` als Bibliothek
importiert. Verworfen: (B) apply_wrapup.py um Handoff/Wiki/Harvest erweitern — Datei wächst
auf ~1500 Zeilen mit drei fremden Domänen außerhalb von `.agent-memory/`, der
`APPLIER_OWNED`-Kanonisierer müsste aufgeweicht werden; (C) Bash-Orchestrator — kein geteilter
Zustand (Tally, Guard-Snapshots, Abbruch vor dem Marker), Windows-Subprocess-Fallen, V4 müsste
aus Python Bash starten.

```
/agentic-os:wrap-up  (Skill-Body = Judge, ≤3 Turns)
  Turn 1  bash: python wrapup_core.py pre --session-id <sid>        → brief.json (read-only)
  Turn 2  Judge: Konversation + brief → EIN Plan
          bash: python wrapup_core.py apply --session-id <sid> <<PLAN  → tally.json
  Turn 3  Bericht aus dem Tally (Identity-Zeile verbatim, Commit-Vorschlag, THRESHOLD-Zeilen)
```

### 4.1 Module

| Modul | Aufgabe | Quelle heute |
|---|---|---|
| `wrapup_core.py` | CLI (`pre`/`apply`), Reihenfolge, Tally, Fehlerpolitik | Steps 0, 0.6, 8.5/7.4, 9, 9.5 |
| `wrapup_core/harvest.py` | Iterationen aus `git log --since=midnight` + dirty-`touched_files`; Typ aus Commit-Präfix `feat/fix/refactor/docs/test/chore`, unkommittierte dirty-Dateien → Typ `config` mit `(uncommitted)` | Step 1.5 (Prosa) |
| `wrapup_core/handoff.py` | zentraler Handoff (Prepend, Demote, Ownership-Dedup, Cap 5, Pointer-Regel) + Status-Board-Sektion, beide über `handoff_write_guard` snapshot/check in-process | Step 7.6a/b + `references/handoff-template.md` |
| `wrapup_core/wikinote.py` | Session-Note als Projektion nach `<wiki_root>/wiki/queries/YYYY-MM-DD-session-<project>-<slug>.md` + index/log-Zeile; Gate `config.sync_enabled` + `session_note_threshold` | obsidian-sync Step 3/7 |
| bestehend | `preprocess_state`, `apply_wrapup`-Applier, `extract_patterns --update`, `bridge_projection`, `memory_index_projection`, `memory-thresholds.sh`, `review_sweep`, `measure_session_cost` | unverändert |

`apply_wrapup.py` bleibt der einzige Writer für die Store-Dateien (`APPLIER_OWNED`,
`patterns.*`/`soul.md` weiterhin verweigert). `handoff.py` und `wikinote.py` schreiben
ausschließlich außerhalb von `.agent-memory/` (Cross-Project-Dateien, Wiki).

### 4.2 Reihenfolge von `apply` (ein Prozess)

1. `preprocess_state` → Session-Fakten (changed_files, git_diff_summary, threshold_events)
2. `harvest` → Iterationen, **nur wenn der Plan keine `iterations` enthält** (Judge-Rekonstruktion
   aus der Konversation gewinnt; headless gibt es nur den Harvest)
3. Applier: iterations → decisions → learnings → user_candidates → soul → open_tasks →
   session_summary
4. `extract_patterns --update`
5. `handoff` → zentraler Handoff, Status-Board
6. `wikinote` → Session-Note + index/log
7. `bridge_projection`, `memory_index_projection`
8. `memory-thresholds`, `review_sweep` → nur Report-Zeilen im Tally
9. `apply_consolidation` (Marker + Dirty-Reset), dann `measure_session_cost --append-trace`
   und `preprocess_state --write-hash`

Der Marker ist der letzte Write desselben Passes. Die 5.0.1-Trennung (Batch-Write in 7.4,
Marker-Call in 9.5) wird damit gegenstandslos: Wiki-Note und Handoff entstehen VOR dem Marker,
Tail-Writes gibt es nicht mehr.

`pre` schreibt nichts (Test: mtime aller Dateien unverändert). Der Plan kommt wie bei
`apply_wrapup.py` über stdin; `apply --headless` (kein Plan, stdin ignoriert) ist der V4-Pfad: Schritte 1–9 mit
Harvest-Iterationen, ohne Learnings/Decisions/Identity; Identity-Statuszeile lautet dann
`Identity: headless — kein Harvest`.

## 5. Schnittstellen

### 5.1 `pre` → brief.json (read-only)

```json
{"session_id": "…", "date": "2026-09-08",
 "iterations_harvested": [{"type": "fix", "title": "<Commit-Subject>", "files": ["…"],
                           "source": "git|dirty", "commit": "<sha>|null"}],
 "errors_today": ["err-015"],
 "open_tasks": [{"id": "T-028", "title": "…", "status": "open"}],
 "last_summary": {"date": "…", "active_task": "…"},
 "identity": {"queue_open": 12, "last_seen": "2026-09-08"},
 "threshold_events": [], "validation_errors": []}
```

### 5.2 Plan (Judge → `apply`)

Bestehendes Write-Plan-Schema (`skills/wrap-up/references/wrapup-schemas.md` §Write plan)
plus:

- `summary`: `{"what_was_done": ["…"], "open_questions": ["…"], "active_task": "…"}` —
  Urteilszeilen; Statistik, Open Items aus open-tasks, Warnings rendert der Core.
- `identity` — **Pflicht**: `{"candidates": [<User candidate>…], "none_because": "<Satz>"}`.
  `candidates` leer UND `none_because` leer → `PlanError`, Exit 2, nichts geschrieben.
  Trust-Grenze unverändert: `trust_source: "conversation"` auf Enqueue und Promote.
- `learnings`: Cap über `--learnings-cap N` (Default 3). Überschüssige Einträge werden nach
  `importance` absteigend verworfen; Tally `learnings_dropped_by_cap` + Warning. Kein Reject.
- `iterations`: optional (§4.2 Punkt 2).
- `consolidate` wird ignoriert — der Core setzt den Marker selbst.

### 5.3 `apply` → tally.json

Bestehende Zähler aus `apply_wrapup.py` (unverändert) plus:

```json
{"harvest_used": false, "learnings_dropped_by_cap": 0,
 "handoff": {"central": "written|drift-merged|skipped(<reason>)|failed(<reason>)",
             "board": "written|skipped(<reason>)|failed(<reason>)"},
 "wiki_note": "<path>|skipped(<reason>)|failed(<reason>)",
 "projections": {"bridge": "ok|failed(<reason>)", "index": "ok|failed(<reason>)"},
 "reports": {"threshold_lines": ["…"], "review_sweep_line": "…"},
 "sharepoint_touched": false, "marker_written": true,
 "identity_status_line": "Identity: … (verbatim)"}
```

Der Judge zählt nichts von Hand; der Bericht in Turn 3 ist eine Projektion des Tallys.

### 5.4 Fehlerpolitik

| Schritt | Fehler | Wirkung |
|---|---|---|
| Plan-Validierung | Schema, fehlende `identity`, Trust | Exit 2, kein Write |
| 1–4 (Store) | `PlanError`/`OSError` | Exit 2, **kein Marker**, Dirty bleibt ehrlich |
| 5–8 (Handoff, Wiki, Projektionen, Reports) | jeder Fehler | fail-soft: `failed(<reason>)` im Tally, Lauf geht weiter, **Marker wird gesetzt** — der lokale Store ist konsolidiert, genau das bezeugt der Marker |
| 9 (Marker) | IO | Exit 2, Marker fehlt (Rule 5) |

Handoff-Drift (Guard Exit 20): Datei neu lesen, eigenen Block in den neuen Inhalt mergen,
erneut snapshot, schreiben; Tally `drift-merged`.

## 6. Skill-Body nach V3

`skills/wrap-up/SKILL.md` von 34 KB auf 6–8 KB. **Bleibt:** Frontmatter/Trigger,
`long-term-memory-routine`-Kopfabsatz (Test-Anker), das 3-Turn-Protokoll mit beiden
Bash-Aufrufen, Urteilsregeln (Learning-Definition + Importance-Skala, Decision-Definition,
Identity-Kurzliste: die 8 Signale als Stichworte), Plan-Schema als Verweis auf
`wrapup-schemas.md`, Eskalationsregeln, Bericht-Format, „What NOT to Do".
**Verschwindet:** jede Mechanik-Prosa (Steps 0, 0.6, 1, 1.5, 3a.2, 3e-Mechanik, 4-Aufruf, 5,
5.5, 7, 7.4–7.6, 8, 9, 9.5). `references/handoff-template.md` wird auf den Block-Template-Teil
reduziert und vom `handoff`-Modul referenziert; der Prepend-Algorithmus lebt im Code.

Codex-Ingest (3e) und Bridge-Gate (3d) bleiben: Ingest ist `ingest_codex_memory.py` (Core
Schritt 3, mechanisch), das Bridge-Gate ist ein Urteil und bleibt Plan-Feld
(`bridge_approved`) im Judge.

## 7. Tests (TDD — Tests zuerst, rot)

`tests/test-wrapup-core.py` — Fixture-Store + Wegwerf-Git-Repo in tmp (`git init`, 3 Commits
mit Präfixen, 1 dirty-file), Fake-`wiki_root` und Fake-`~/AI`-Pfade per CLI-Flag/Env
(`--central-dir`, `--wiki-root`), damit nie echte Cross-Project-Dateien berührt werden:

1. `pre` schreibt nichts (mtime-Vergleich aller Dateien vor/nach)
2. `apply` ohne Plan (headless) → Summary, Handoff, Board, Wiki-Note, Marker vorhanden;
   Learnings/Decisions/user.md unverändert; Identity-Zeile `headless`
3. Plan ohne `identity` → Exit 2, keine Datei verändert
4. Plan mit 5 Learnings, Cap 3 → 3 geschrieben, `learnings_dropped_by_cap: 2`, Warning
5. Plan mit `iterations` → Harvest nicht benutzt (`harvest_used: false`); ohne → benutzt
6. Wiki-Schritt wirft (nicht schreibbares wiki_root) → `wiki_note: failed(...)`, Marker gesetzt
7. Learnings-Applier wirft (kaputte learnings.json) → Exit 2, kein Marker, Dirty unverändert
8. Handoff-Drift: Datei zwischen snapshot und check ändern → `drift-merged`, fremder Block erhalten
9. Idempotenz: denselben Plan zweimal → alle Store-Dateien byte-identisch (L35)
10. Pfad-Guard: `handoff`/`wikinote` verweigern Ziele unter `.agent-memory/` (L36)

`validate-skills.sh` / `validate-plugin.sh` — Anker-Umbau **im selben Commit wie der
Body-Umbau** (Commit 5), sonst ist die Suite zwischen den Commits rot (membrain/L43: die
Anker sind exakte Strings im Body):
- Delegation-Budget-Test → wrap-up ruft 0 Skills
- Wiki-Sync-Tests (visible/gate) → ersetzt durch „Body enthält keinen obsidian-sync-Aufruf"
  + „Body nennt `wrapup_core.py pre` und `apply`"
- Ordnungstests 7.4/9.5 (5.0.1) entfallen
- `test-wrap-up-long-term-memory-contract.sh` bleibt (Kopfabsatz bleibt)
- DEPENDENCIES-Genauigkeitstest (41b): wrap-up nicht mehr als Invoker von obsidian-sync

`test-apply-wrapup.py` (120) bleibt unangetastet.

## 8. Doku, Version, Messung

- Version **5.1.0** (MINOR: neue Fähigkeit headless-fähiger Core; kein Skill entfällt,
  Hook-Kontrakt und Store-Format unverändert). Skill-Metadaten wrap-up `4.5 → 5.0`.
- `obsidian-sync/SKILL.md`: „von wrap-up Step 7.5 aufgerufen" raus; Session-Note als
  „projiziert von wrapup_core" markiert; Skill bleibt für Entity/Synthese/Decision-Promotion.
- `DEPENDENCIES.md`, `CLAUDE.md` (Architektur-Block, Hooks-Absatz, Delegation-Absatz),
  `docs/CAPABILITIES.md`, `docs/ARCHITECTURE.md`, Briefing-Text in `scripts/session-start.sh`.
- Messung als DoD-Beleg: ein echter Lauf mit `measure_session_cost.py --locate <sid>`,
  API-Calls und USD im CHANGELOG neben 88/102 (Wirkung, nicht Deklaration — L33).

## 9. Nicht in V3

- `session_end.py`-Anbindung (V4) — der Core ist dafür vorbereitet (`--headless`).
- user.md-Jaccard-Dedup gegen Bestand (V7) — Core bekommt nur den Aufrufpunkt.
- Modellklasse/Frontmatter-Wirkung (V8).
- Wiki-Entity- und Synthese-Updates — bleiben obsidian-sync (manuell).

## 10. Umsetzungsreihenfolge (5–6 Commits)

1. `tests/test-wrapup-core.py` (rot; die validate-Anker bleiben bis Commit 5 unverändert, damit
   die Suite zwischen den Commits nie rot ist)
2. `harvest.py` grün
3. `handoff.py` + `wikinote.py` grün
4. `wrapup_core.py` (pre/apply, Tally, Fehlerpolitik) grün, Headless-Pfad
5. Skill-Body + Test-Anker + obsidian-sync-Absatz in einem Commit
6. Doku, Version 5.1.0, CHANGELOG mit Messlauf; Release-Zweischritt
