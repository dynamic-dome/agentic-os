---
name: code-reviewer
description: >
  Selbstbewertung der Code-Qualitaet nach Aenderungen in Claude Code.
  Reviewed generierten Code auf Lesbarkeit, Wartbarkeit, Security, Performance
  und Einhaltung von Projekt-Konventionen. Erstellt strukturierte Review-Eintraege.
  Trigger: "code reviewen", "review this", "qualitaet pruefen", "selbst-review",
  "code review", "check quality", "self-review".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
---

# Code Reviewer

## When to Use This Skill

- Neuer Code geschrieben oder signifikant geaendert wurde
- Automatisch vom agent-orchestrator nach `code-changed` Signal
- Vor einem Commit
- User fragt: "Ist der Code gut?" / "Was kann verbessert werden?"

## Dateistruktur

```
.agent-memory/
└── quality/
    ├── code-reviews.json     # Alle Reviews
    └── quality-score.json    # Aggregierte Metriken
```

## Instructions

### Schritt 1: Geaenderte Dateien identifizieren

Nutze Claude Code Tools:
- `Bash`: `git diff --name-only HEAD~1` fuer letzte Aenderungen
- `Grep`: Suche nach TODO/FIXME/HACK in geaenderten Dateien
- Oder aus dem Orchestrator-Signal: `files_changed`

### Schritt 2: Konventionen laden

Lies mit dem `Read`-Tool:
- `.agent-memory/context/project-context.md` → Tech-Stack, Konventionen
- `.agent-memory/patterns/patterns.md` → Bekannte Anti-Patterns
- Projektspezifische Config: `pyproject.toml`, `ruff.toml`, `.editorconfig`

### Schritt 3: Review nach 6 Dimensionen

Bewerte jede geaenderte Datei auf einer Skala von 1-5:

1. **Lesbarkeit** — Klare Namen, logische Struktur, konsistenter Stil
2. **Wartbarkeit** — Single Responsibility, keine ueberlangen Funktionen (>50 Zeilen Warnung)
3. **Korrektheit** — Edge Cases, Error Handling, Type Hints
4. **Performance** — Effiziente Datenstrukturen, keine unnuetigen Schleifen
5. **Security** — Keine hardcoded Secrets, Input-Validierung, sichere Pfade
6. **Testbarkeit** — Testbare Funktionen, Dependencies injizierbar, Tests vorhanden

### Schritt 4: Gesamt-Score berechnen

```
# Formel: Dimensionen 1-5, normalisiert auf 0-100
# (mean - 1) / 4 * 100 ergibt Bereich 0-100 (nicht 20-100)
code_quality_score = round(((mean([alle 6 Dimensionen]) - 1) / 4) * 100)
```

| Score | Bewertung | Aktion |
|-------|-----------|--------|
| 90-100 | Excellent | Keine Aenderungen noetig |
| 75-89 | Good | Kleinere Verbesserungen empfohlen |
| 60-74 | Acceptable | Verbesserungen einplanen |
| 40-59 | Needs Work | Vor Commit ueberarbeiten |
| 0-39 | Poor | Grundlegendes Refactoring noetig |

### Schritt 5: code-reviews.json aktualisieren

Nutze `Read` zum Laden und `Edit`/`Write` zum Aktualisieren:

```json
{
  "id": "<YYYY-MM-DD-HH-MM>-review",
  "timestamp": "<ISO 8601>",
  "files_reviewed": ["src/example.py"],
  "trigger": "<orchestrator|manual|pre-commit>",
  "scores": {
    "overall": 82,
    "readability": 4,
    "maintainability": 4,
    "correctness": 5,
    "performance": 4,
    "security": 4,
    "testability": 3
  },
  "findings": [
    {
      "severity": "<critical|warning|suggestion>",
      "file": "src/example.py",
      "line": 45,
      "dimension": "testability",
      "issue": "Beschreibung des Problems",
      "suggestion": "Vorgeschlagene Verbesserung"
    }
  ],
  "summary": "Kurze Zusammenfassung"
}
```

### Schritt 6: Ergebnis ausgeben

```
Code Review: <score>/100 (<bewertung>)
   Dateien: <n> reviewed

   Scores:
   Readability:     <n>/5
   Maintainability: <n>/5
   Correctness:     <n>/5
   Performance:     <n>/5
   Security:        <n>/5
   Testability:     <n>/5

   Findings: <n> (critical: <n>, warning: <n>, suggestion: <n>)
   Top-Empfehlung: <wichtigstes Finding>
```

### Schritt 7: Cross-Referenz mit Patterns

Pruefe ob Findings zu bekannten Patterns aus `patterns.json` passen.
Falls neues wiederkehrendes Issue → markiere als Pattern-Kandidat.

### Schritt 8: Log-Rotation

Wenn `code-reviews.json` mehr als 100 Eintraege enthaelt (konfigurierbar via Plugin-Setting `max_review_entries`):
- Behalte die neuesten 100 Eintraege
- Archiviere aeltere in `code-reviews-archive-<YYYY-MM>.json` im selben Verzeichnis
