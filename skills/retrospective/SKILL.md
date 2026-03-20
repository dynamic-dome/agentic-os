---
name: retrospective
description: >
  Tiefenanalyse ueber mehrere Sessions hinweg. Aggregiert Daten aus allen
  Skills und berechnet Langzeit-Metriken: Wird der Agent besser? Wo sind
  blinde Flecken? Periodisch aufrufen (alle 5 Sessions oder woechentlich).
  Trigger: "retrospektive", "metriken zeigen", "fortschritt", "wie entwickeln wir uns",
  "retrospective", "show metrics", "progress report", "how are we doing".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
---

# Retrospective

## When to Use This Skill

- Periodisch: Alle 5 Sessions oder einmal pro Woche
- User will Gesamt-Bewertung ("Wie laeuft's?")
- Vor neuem Projekt-Meilenstein
- Wenn das Gefuehl entsteht, dass sich nichts verbessert

## Dateistruktur

```
.agent-memory/
└── retrospectives/
    ├── retro-<YYYY-MM-DD>.md   # Einzelne Retrospektive
    └── metrics.json             # Langzeit-Metriken
```

## Instructions

### Schritt 1: Alle Datenquellen laden

Nutze `Read`-Tool fuer alle `.agent-memory/` Dateien:

| Quelle | Datei | Was extrahieren |
|--------|-------|----------------|
| Iterationen | `iterations/errors.json` | Fehleranzahl, Kategorien, Versuche |
| Patterns | `patterns/patterns.json` | Neue Patterns, Confidence-Trend |
| Tests | `quality/test-results.json` | Health-Score-Verlauf |
| Reviews | `quality/code-reviews.json` | Qualitaets-Trend pro Dimension |
| Kontext | `context/decisions.json` | Anzahl Entscheidungen |
| Orchestrator | `orchestrator/orchestrator-log.md` | Skill-Nutzung |

### Schritt 2: Kern-Metriken berechnen

**Effizienz:**
- `avg_attempts_per_fix` — sinkt = Agent wird effizienter
- `first_try_success_rate` — steigt = weniger Trial-and-Error

**Qualitaet:**
- `code_quality_trend` — aus letzten 10 Reviews
- `test_health_trend` — aus letzten 10 Runs
- `regression_rate` — Regressionen / total Runs

**Lernen:**
- `repeat_error_rate` — sinkt = Agent wiederholt weniger Fehler
- `patterns_recognized` — Patterns mit confidence: high

### Schritt 3: Blinde-Flecken-Analyse

Identifiziere mit `Grep`/`Glob`:
- Ungetestete Module (geaendert aber nie in Tests)
- Haeufige Fehlerkategorien mit steigender Frequenz
- Review-Dimensionen konstant < 3/5
- Patterns mit `skill_candidate: true` aber kein generierter Skill

### Schritt 4: metrics.json aktualisieren

```json
{
  "last_updated": "<ISO 8601>",
  "efficiency": { "avg_attempts_per_fix": 2.3, "first_try_success_rate": 45 },
  "quality": { "code_quality_avg": 82, "test_health_avg": 88, "regression_rate": 5.2 },
  "learning": { "patterns_total": 12, "repeat_error_rate": 15 },
  "blind_spots": ["Beschreibung"],
  "health_grade": "B+"
}
```

**Health Grade:** A+ (alle improving) → D (alle declining)

### Schritt 5: Retrospektive-Bericht schreiben

Nutze `Write`-Tool fuer `retrospectives/retro-<datum>.md`:

```markdown
# Retrospektive — <Datum>

## Zusammenfassung
**Health Grade: <grade>** | Projekt-Tag: <n>

## Kern-Metriken
| Metrik | Aktuell | Trend | Letzte Woche |
|--------|---------|-------|-------------|
| Versuche pro Fix | 2.3 | improving | 3.1 |
| Code-Qualitaet | 82/100 | stable | 81/100 |
| Test-Health | 88/100 | improving | 82/100 |

## Was laeuft gut
- <Positive Trends>

## Was braucht Aufmerksamkeit
- <Blinde Flecken>

## Empfehlungen
1. <Konkrete Empfehlung>
```

### Schritt 6: Ergebnis ausgeben

```
RETROSPEKTIVE — <Datum>
   Health Grade: <grade>
   Iterationen: <n> | Tests: <n> | Patterns: <n>

   Effizienz:       <trend>
   Code-Qualitaet:  <trend>
   Test-Health:     <trend>
   Lernfortschritt: <trend>

   Top-3 Empfehlungen:
   1. <Empfehlung>
   2. <Empfehlung>
   3. <Empfehlung>
```
