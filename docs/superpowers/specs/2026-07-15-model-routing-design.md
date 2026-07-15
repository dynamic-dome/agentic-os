# Design: Kosten- und tokenbewusstes Modell-Routing (v4.6.0)

**Datum:** 2026-07-15
**Status:** Freigegeben (Brainstorming-Dialog, 3 Design-Abschnitte einzeln bestätigt)
**Quellen:** `C:\Users\domes\AI\membrain\memospartoken.md` (GPT-5.6-Spec), eigene Recherche (Claude-Code-Doku-Verifikation Skill-`model:`-Frontmatter, Pricing Stand 2026-06), Atlas-Records `cost-aware-distillation`, `session-end-memory-distillation`.

## 1. Zweck & Scope

Erste Umsetzung der Spec-Prioritäten **P1–P4 in abgespeckter, Claude-Code-nativer Form**: Messbarkeit (soweit möglich), deterministische Vorverarbeitung, günstiges Modell für Routine-Skills, Eskalationsregeln. **Nicht in diesem Release** (bewusst, Spec-Artefakt 15): Delta-Schreibplan als eigener Mechanismus (P5), Batch-Verarbeitung, Prompt-Cache-Umbau (P6), Provider-Adapter, Live-Shadow-Mode, Kontextbudget-Enforcement.

## 2. Abweichungen von der Spec (geprüft gegen realen Bestand)

| Spec | Realität | Entscheidung |
|---|---|---|
| Programmatischer Router (§8) mit Confidence, Provider-Adapter | Plugin ist Markdown+Bash ohne API-Zugriff; Claude Code routet nativ über Frontmatter | Router = deklarative Konvention: `model:`/`effort:`-Frontmatter + Routing-SSoT + Konsistenz-Test |
| Echte input/output_tokens pro Lauf (§21) | Claude Code exponiert Skills keine Token-Zahlen | cost-trace mit deterministischer Kontext-Schätzung (bytes/4), als Schätzung markiert |
| `memory-bootstrap` als Komponente (§28) | Existiert nicht; nur `session-bootstrap` | Ignoriert |
| Stop-Hook anpassen (§28) | Stop-Hook in v3.1.1 entfernt (Feedback-Loop) | Ignoriert; SessionEnd-Hook bleibt unverändert |
| Live-Shadow-Mode (§23 Phase 2) | Doppelte Läufe = doppelte Kosten | Ersetzt durch Fixture-Vergleichstests + Begrenzung auf niedrige Risikoklassen |
| Kleines Modell = Haiku (§7.2) | Haiku hat 200k-Fenster; lange Fable-Sessions sprengen das beim wrap-up; schreibende Skills brauchen Verlässlichkeit | cheap-write = **Sonnet**; Haiku als Klasse `cheap-read` reserviert (Phase 2 Fork-Lesepfad), in Release 1 unbelegt |
| Schreibplan-Pflicht für kleines Modell (§9/§13) | Bestehende Gates (Identity `[j/n]`, Pre-Run Commit, Snapshots, Threshold-SSoT) decken das Risiko | Keine neue Schreibplan-Maschinerie; bestehende Gates gelten als Schreibschutz |

## 3. Architektur: Deklaratives Routing

### 3.1 Routing-SSoT — `scripts/model-routing.sh` (neu)

Analog `memory-thresholds.sh`: definiert Task-Klassen und Zuordnung, maschinenlesbare Ausgabe (`model-routing.sh list` → TSV `skill<TAB>class<TAB>model<TAB>effort`). Reale Modellnamen stehen NUR hier und im Frontmatter, nie in Skill-Prosa.

Klassen: `deterministic` (kein Modell — Scripts), `cheap-read` (haiku, read-only, Release 1 unbelegt), `cheap-write` (sonnet), `standard` (inherit), `strong` (inherit).

### 3.2 Frontmatter-Zuordnung

| Skill | Klasse | `model:` | `effort:` |
|---|---|---|---|
| wrap-up | cheap-write | sonnet | medium |
| session-bootstrap | cheap-write | sonnet | low |
| memory-maintenance | cheap-write | sonnet | low |
| iteration-logger | cheap-write | sonnet | low |
| sync-context | cheap-write | sonnet | low |
| obsidian-sync | cheap-write | sonnet | medium |
| context-keeper | standard | *(kein Feld)* | — |
| pattern-extractor | standard | *(kein Feld)* | — |
| self-improve | strong | *(kein Feld)* | — |

Agents (bereits `model: sonnet`): `effort: medium` für research-agent und context-detective ergänzen; improvement-agent bleibt ohne effort-Feld (führt TDD-Iterationen aus).

Begründungen: wrap-up braucht Gesprächsverlauf (kein Fork) und 1M-Fenster (kein Haiku); session-bootstrap läuft am Session-Start, wo der Kontext klein ist → Modellwechsel kostet praktisch keinen Cache; pattern-extractor bleibt konservativ auf inherit, weil Skill-Generierung folgenreich ist (Downgrade erst nach Messdaten, P7).

### 3.3 Stufe 0 — `scripts/preprocess-state.sh` (neu)

Deterministisches Zustandsobjekt ohne Modellaufruf, JSON auf stdout:

```json
{
  "session_id": "...",
  "changed_files": [],          // aus working/dirty-<sid>.json
  "git_diff_summary": "...",    // git diff --stat HEAD (fail-soft ohne Repo)
  "threshold_events": [],       // memory-thresholds.sh (exit 10 → Event)
  "validation_errors": [],      // mem-schema.sh
  "open_tasks": [],             // aus session-summary.md (strukturierter Abschnitt)
  "previous_state_hash": "...", // aus working/state-hash
  "current_state_hash": "..."   // Hash über die relevanten Memory-Dateien
}
```

Fail-soft wie der dirty-tracker: fehlende Quellen → leere Felder, Exit 0.

### 3.4 Skill-Umbauten (Kontextdiät)

**wrap-up:** Neuer Step 0 ruft `preprocess-state.sh`; Kandidaten-Extraktion arbeitet auf Zustandsobjekt + Gesprächskontext; explizite Anweisung, das Transkript nicht systematisch nachzulesen (nur gezielte Rückgriffe auf einzelne ungeklärte Punkte, Spec §13.2). session-summary wird per Delta aktualisiert (added/updated/resolved), nicht neu geschrieben. Am Ende `cost-trace.sh append` und `state-hash` schreiben.

**session-bootstrap:** Preprocess zuerst; bei `previous_state_hash == current_state_hash` nur bestehendes Briefing laden statt aller Memory-Dateien (Spec-Testfall 24.1); sonst nur veränderte Bereiche + `learnings_top.py`-Salience. Step-6.5-Gate (`[j/n]`) bleibt unverändert im Hauptloop.

### 3.5 Eskalations-Konvention (Spec §11)

Fester Block „Escalation Rules" in wrap-up- und session-bootstrap-SKILL.md. Bedingungen: Widerspruch aktiver Quellen · Identitäts-/Präferenzänderung · Ablösung einer aktiven Decision · Pattern→Skill-Promotion · schwer reversible Änderung · fehlende Quellen. Verhalten: Fall NICHT selbst lösen; Eintrag nach `working/escalations-<sid>.json` (`{ts, task, reason, detail}`); sichtbarer `ESKALATION:`-Vermerk im Output; Folge-Turn auf Session-Modell entscheidet. Identity bleibt zusätzlich hinter den bestehenden Gates.

### 3.6 Messung — `scripts/cost-trace.sh` (neu)

`cost-trace.sh append --task <type> --class <class> --context-bytes N --escalated 0|1` → JSONL-Zeile nach `.agent-memory/metrics/cost-trace.jsonl` mit `ts, task_type, model_class, context_bytes, est_input_tokens (bytes/4, geschätzt), escalated`. Fail-soft, blockiert nie. Aufrufer in Release 1: wrap-up, session-bootstrap.

## 4. Tests (TDD, bash)

1. **Routing-Konsistenz:** `validate-skills.sh` prüft `model:`/`effort:` jedes SKILL.md gegen `model-routing.sh list` (awk-Extraktion wegen Multiline-YAML).
2. **preprocess-state.sh:** Fixtures — dirty-file vorhanden/fehlt, kein Git-Repo, Threshold überschritten, Hash-Gleichheit (deckt Spec 24.1/24.4 deterministisch).
3. **cost-trace.sh:** JSONL-Format valide, fail-soft bei fehlendem Verzeichnis.
4. **Struktur-Assertions:** wrap-up/session-bootstrap enthalten Escalation-Rules-Block + preprocess-Aufruf; Spec 24.5/24.6 (modellabhängiges Verhalten) als dokumentierte manuelle Eval-Checkliste in `docs/`, nicht als vorgetäuschte Verhaltenstests.

## 5. Rollout, Risiken, Rollback

- **Ein Release v4.6.0** (minor; plugin.json = Source of Truth, VERSIONING.md-Mapping).
- Begrenzung auf niedrige Risikoklassen = Phase-3-Entsprechung der Spec; kein Live-Shadow.
- **Risiken dokumentiert:** Haiku-Kontextfenster (deshalb unbelegt); Cache-Invalidierung bei Mid-Session-Modellwechsel (wrap-up am Session-Ende = unkritisch; mid-session getriggerte cheap-Skills zahlen einmalig uncached Input auf Sonnet — bei $2/MTok verschmerzbar, dokumentiert); Frontmatter-`model:` wird von Org-Allowlists ggf. ignoriert (Fallback = Session-Modell, sicher).
- **Rollback:** `git revert` des Release-Commits; keine Datenmigration, keine Breaking Changes.

## 6. Erwartete Wirkung (Planungswerte, nach Messphase zu validieren)

- Routine-Skill-Läufe: Output-Kosten −80 % (Fable $50 → Sonnet $10/MTok Intro), Gesamtlauf −50–70 %.
- Kontextdiät wrap-up/bootstrap: geschätzt −30–60 % Input je Lauf (messbar via cost-trace ab Release).
- Anteil an Gesamt-Session-Kosten: einstellig bis ~15 % — der größere Hebel (Session-Modellwahl) liegt außerhalb dieses Plugins und ist dokumentiert.
