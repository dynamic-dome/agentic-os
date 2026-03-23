# Agentic OS Plugin — Vollständige Analyse

> Version 2.0.0 | Analysiert am 2026-03-23

---

## 1. Was macht das Plugin?

Agentic OS ist ein **selbstlernendes Agenten-Gedächtnissystem** für Claude Code. Es schafft ein persistentes, projektbezogenes Wissensmanagement über Sessions hinweg.

**Kernidee:** Jede Coding-Session hinterlässt strukturiertes Wissen — Fehler, Patterns, Entscheidungen, Qualitätsmetriken — das in zukünftigen Sessions automatisch verfügbar ist.

### Architektur auf einen Blick

```
SESSION START ──> Bootstrap (read-only) ──> Kontext laden
      │
  ARBEITSPHASE ──> Iteration-Logger, Code-Review, Tests, TDD
      │
SESSION ENDE ──> Wrap-up ──> Pattern-Extraktion ──> Summary schreiben
```

### Komponenten

| Typ | Anzahl | Zweck |
|-----|--------|-------|
| Skills | 10 | Kernlogik (Logging, Patterns, Reviews, TDD, Sync) |
| Hooks | 4 | SessionStart, Stop, PreCompact, SessionEnd |
| Commands | 2 | `/init` (Bootstrap), `/status` (Health-Check) |
| Agents | 1 | context-detective (Stack-Erkennung) |
| Shell-Skripte | 3 | Hook-Implementierungen |

### Memory-Struktur (`.agent-memory/`)

```
identity/          → soul.md, user.md (Wer bin ich? Wer ist der User?)
context/           → project-context.md, decisions.json (Projektstand)
iterations/        → iteration-log.md, errors.json (Was wurde gemacht?)
patterns/          → patterns.json, patterns.md (Was wiederholt sich?)
quality/           → test-results, code-reviews, quality-score (Wie gut?)
learnings/         → learnings.md (Was wurde gelernt?)
generated-skills/  → Auto-generierte Skills aus Patterns
```

---

## 2. Stärken

### 2.1 Durchdachte Architektur

- **DAG-Abhängigkeiten** — Keine zirkulären Abhängigkeiten zwischen Skills. Die Dependency-Matrix ist sauber dokumentiert.
- **Read-Only Bootstrap** — `session-bootstrap` schreibt nie. Keine Seiteneffekte beim Session-Start.
- **Append-Only Decisions** — `decisions.json` wird nie gelöscht, nur superseded. Vollständiger Audit-Trail.
- **Deterministische Confidence-Scores** — Pattern-Confidence wird berechnet (Basis 0.3 + Boosters), nicht geraten.

### 2.2 Minimaler Overhead

- SessionStart + Stop: ~45 Sekunden Gesamtaufwand pro Session
- Kein Auto-Trigger bei jeder Code-Änderung
- User-gesteuerte Aktivierung der meisten Skills

### 2.3 Selbstlernender Kreislauf

Der eigentliche Kern-USP:

```
Fehler loggen → Patterns erkennen → Skills generieren → Fehler vermeiden
```

Das ist ein geschlossener Feedback-Loop:
1. **iteration-logger** erfasst Fehler mit Tags und Root-Cause
2. **pattern-extractor** clustert nach Kategorie + Tags und erkennt Wiederholungen
3. **skill-generator** erzeugt wiederverwendbare Skills aus stabilen Patterns (>=3 Occurrences, Confidence >=0.7)
4. Generierte Skills stehen in künftigen Sessions zur Verfügung

### 2.4 Qualitätssystem

- **6-dimensionaler Code-Review** (Lesbarkeit, Wartbarkeit, Korrektheit, Performance, Security, Testability)
- **Test-Health-Score** mit Regressions-Erkennung (REGRESSION, FIX, GROWTH, FLAKY)
- **TDD-Workflow** mit Red-Green-Refactor und Framework-Erkennung

### 2.5 Gute Skill-Dokumentation

Jeder Skill hat:
- Klare Trigger-Phrases (DE + EN)
- Schritt-für-Schritt-Anweisungen
- Anti-Patterns ("What NOT to Do")
- Concrete Output-Formate

### 2.6 Log-Rotation

Automatische Archivierung bei Überschreitung von Schwellenwerten verhindert, dass JSON-Dateien unbegrenzt wachsen.

### 2.7 Cross-Project Sync (Konzept)

`sync-context` ermöglicht theoretisch Pattern-Transfer zwischen Projekten mit intelligenten Filtern (Stack-Tags, Confidence-Thresholds).

---

## 3. Schwächen

### 3.1 Keine automatische Trigger-Logik

**Problem:** Skills wie `iteration-logger`, `code-reviewer` und `test-validator` werden nur manuell oder über den Stop-Hook ausgelöst. Es gibt keinen Mechanismus, der z.B. nach einem `git commit` automatisch den Logger triggert.

**Auswirkung:** Der User muss aktiv daran denken, Iterationen zu loggen. In der Praxis wird das oft vergessen, wodurch die Pattern-Erkennung unvollständig bleibt.

### 3.2 Stop-Hook als Single Point of Failure

Der `Stop`-Hook übernimmt zu viele Aufgaben:
- Session-Summary schreiben
- Ungeloggte Iterationen nachholen
- Learnings extrahieren
- Pattern-Extraction triggern

Wenn der Hook fehlschlägt oder übersprungen wird (z.B. bei Crash/Timeout), geht die gesamte Session-Arbeit verloren.

### 3.3 Sync-Context ist theoretisch

`sync-context` beschreibt einen bidirektionalen Sync mit `~/.claude-memory/global/`, aber:
- Es gibt keine Validierung, ob die globale Struktur existiert
- Keine Konfliktlösung bei gleichzeitigen Änderungen aus verschiedenen Projekten
- Die `projects.json`-Registry wird referenziert aber nie initialisiert
- Kein Mechanismus, um veraltete globale Patterns zu bereinigen

### 3.4 Fehlende Fehlerbehandlung in Shell-Skripten

Die Hook-Skripte verwenden `set -euo pipefail`, brechen aber bei fehlendem `.agent-memory/` einfach ab (was korrekt ist). Allerdings:
- Keine Prüfung auf beschädigte JSON-Dateien
- `git` wird vorausgesetzt ohne Fallback
- Windows-Kompatibilität ist fragwürdig (bash-Skripte auf Windows benötigen Git Bash oder WSL)

### 3.5 Redundanz zwischen Claude-Memory und Agentic OS

Claude Code hat ein eigenes Memory-System (`~/.claude/projects/.../memory/`). Agentic OS erstellt ein paralleles System in `.agent-memory/`. Das führt zu:
- Doppelter Informationshaltung
- Potenzielle Widersprüche zwischen den Systemen
- Unklarheit, welches System die "Wahrheit" ist

### 3.6 Skalierungsprobleme bei JSON-Dateien

Obwohl Log-Rotation existiert, werden JSON-Dateien bei jedem Schreibvorgang komplett gelesen und geschrieben. Bei 200 Error-Einträgen mit jeweils 15+ Feldern kann das langsam werden.

### 3.7 Keine Validierung der Memory-Integrität

Es gibt keinen Mechanismus, der:
- Beschädigte JSON-Dateien repariert
- Verwaiste Referenzen zwischen Dateien erkennt
- Inkonsistenzen zwischen `patterns.json` und `patterns.md` aufdeckt

### 3.8 soul.md und user.md — Kaltstartproblem

`soul.md` und `user.md` werden mit Templates initialisiert, aber es gibt keinen geführten Onboarding-Prozess. Der User soll sie manuell anpassen, was in der Praxis selten passiert.

---

## 4. Was funktioniert

### Gut funktionierend

| Feature | Warum es funktioniert |
|---------|----------------------|
| `/init` Command | Sauberes Bootstrapping mit Stack-Erkennung via context-detective Agent |
| `/status` Command | Schneller Health-Check, kompakte Ausgabe |
| SessionStart Hook | Zuverlässige Kontext-Injektion mit Git-Status und Memory-Daten |
| session-bootstrap Skill | Read-Only-Garantie, schnelle Ausführung (<15s), kompaktes Briefing |
| iteration-logger | Duplicate-Detection, strukturierte Error-Records, sinnvolle Tag-Taxonomie |
| pattern-extractor | Deterministische Confidence-Berechnung, klare Schwellenwerte |
| code-reviewer | 6 Dimensionen mit konkreten Scoring-Formeln, Findings nach Severity |
| test-validator | Multi-Framework-Erkennung, Regressions-Tracking |
| tdd Skill | Klarer Red-Green-Refactor-Workflow, Framework-agnostisch |
| context-keeper | Saubere Trennung von lebendem Kontext und Entscheidungs-History |

### Teilweise funktionierend

| Feature | Problem |
|---------|---------|
| wrap-up | Zu viele Verantwortlichkeiten, fragiler Hook-Trigger |
| skill-generator | Funktioniert konzeptuell, aber Qualität der generierten Skills ist nicht validierbar |
| PreCompact Hook | Injiziert Kontext, aber ob er nach Kompression tatsächlich genutzt wird, ist nicht garantiert |

### Nicht funktionierend / Ungetestet

| Feature | Problem |
|---------|---------|
| sync-context | Globale Infrastruktur wird nie erstellt, keine reale Nutzung möglich |
| quality-score.json Aggregation | Wird von code-reviewer und test-validator referenziert, aber die Aggregationslogik ist unklar |
| SessionEnd Hook | Empfehlungen werden ausgegeben, aber ob sie tatsächlich ausgeführt werden, hängt vom User ab |

---

## 5. Erweiterungsvorschläge

### 5.1 PostToolUse-Hook für automatisches Logging

**Problem lösen:** Kein manuelles Logging mehr vergessen.

```json
{
  "event": "PostToolUse",
  "matcher": { "toolName": "Bash" },
  "hooks": [{
    "type": "prompt",
    "prompt": "If a test just failed or a significant error occurred, log it with iteration-logger."
  }]
}
```

### 5.2 Memory-Integrity-Check

Ein neuer Skill `memory-doctor`, der:
- JSON-Dateien auf Validität prüft
- Referenzielle Integrität zwischen patterns.json und errors.json checkt
- Veraltete Einträge markiert (älter als 90 Tage ohne Aktualisierung)
- Automatisch beim SessionStart laufen kann

### 5.3 Integration mit Claude-Memory

Statt ein paralleles System zu betreiben:
- `soul.md` und `user.md` → in Claudes eigenes `memory/` System migrieren
- `.agent-memory/` nur für projektspezifische, strukturierte Daten nutzen (iterations, patterns, quality)
- Bridge-Skill, der relevante Agentic-OS-Patterns in Claude-Memory spiegelt

### 5.4 Dashboard-Command

`/agentic-os:dashboard` — eine reichhaltigere Ansicht als `/status`:
- Trend-Grafiken (ASCII) für Quality-Score über Zeit
- Top-5-Patterns mit Confidence
- Letzte 10 Iterationen als Timeline
- Offene Entscheidungen

### 5.5 Git-Integration

- **Pre-Commit Hook**: Automatisch `code-reviewer` und `test-validator` vor jedem Commit
- **Post-Merge Hook**: `context-keeper` nach Branch-Merges triggern
- Commit-Messages automatisch mit Iteration-Referenzen anreichern

### 5.6 Pattern-Decay

Patterns, die lange nicht aufgetreten sind, sollten automatisch an Confidence verlieren:
```
decay = 0.05 * months_since_last_seen
adjusted_confidence = confidence - decay
```
Unter 0.2 → automatisch archivieren.

### 5.7 Onboarding-Wizard

Statt `soul.md` und `user.md` mit Templates zu initialisieren:
- Interaktiver Fragebogen beim ersten `/init`
- "Wie erfahren bist du mit [erkanntem Stack]?"
- "Welche Coding-Konventionen nutzt du?"
- "Was sind deine Prioritäten? (Speed / Quality / Learning)"

### 5.8 Quality-Gate

Ein neuer Skill, der als Gate vor Commits funktioniert:
- Blockiert Commits bei Quality-Score < 60
- Warnt bei Test-Health < 70
- Erzwingt Review bei Security-Findings (Severity: critical)

### 5.9 Metriken-Export

Export der Quality-Daten als:
- CSV für Trendanalysen
- JSON-API für externe Dashboards
- Markdown-Report für Team-Meetings

### 5.10 Windows-Kompatibilität

- Shell-Skripte durch plattformunabhängige Prompt-basierte Hooks ersetzen
- Oder PowerShell-Varianten der Skripte bereitstellen
- Pfade mit Forward-Slashes normalisieren

---

## 6. Fazit

**Agentic OS ist ein ambitioniertes und architektonisch durchdachtes Plugin**, das einen echten Mehrwert für langlebige Projekte bieten kann. Der selbstlernende Kreislauf (Fehler → Patterns → Skills) ist die zentrale Innovation.

**Die Stärken überwiegen:** Saubere Architektur, minimaler Overhead, deterministische Algorithmen, gute Dokumentation.

**Die Hauptschwächen** liegen in der praktischen Nutzbarkeit: Zu viel hängt von manuellem Triggern ab, der Sync ist unfertig, und die Koexistenz mit Claudes eigenem Memory-System ist ungeklärt.

**Empfehlung:** Die nächsten Schritte sollten sein:
1. PostToolUse-Hooks für automatisches Logging (größter Impact)
2. Memory-Doctor für Integrität
3. Windows-Kompatibilität sicherstellen
4. sync-context entweder richtig implementieren oder entfernen
