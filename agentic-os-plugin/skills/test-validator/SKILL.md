---
name: test-validator
description: >
  Fuehrt nach Codeaenderungen Tests aus, bewertet Ergebnisse und protokolliert
  Test-Trends. Erkennt Regressionen, fehlende Tests und Flaky Tests.
  Trigger: "tests laufen lassen", "validate", "test results", "regression check",
  "run tests", "check tests", "Tests ausfuehren".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: quality
---

# Test Validator

## When to Use This Skill

- Code geaendert wurde und Tests laufen sollen
- Vor einem Commit / Push
- Nach einem Refactoring
- User fragt: "Funktioniert alles?" / "Regression?"

## Dateistruktur

```
.agent-memory/
└── quality/
    ├── test-results.json     # Historische Test-Ergebnisse
    └── quality-score.json    # Aggregierte Metriken
```

## Instructions

### Schritt 1: Test-Framework erkennen

Nutze `Glob` und `Read` um das Test-Setup zu identifizieren:

| Indikator | Framework | Befehl |
|-----------|-----------|--------|
| `conftest.py`, `pyproject.toml [tool.pytest]` | pytest | `python -m pytest --tb=short -q` |
| `package.json` mit `jest`/`vitest` | Jest/Vitest | `npm test` |
| `Makefile` mit `test` Target | Custom | `make test` |
| `go.mod` oder `*_test.go` | Go | `go test ./...` |
| `Cargo.toml` oder `tests/` (Rust) | Cargo | `cargo test` |
| `CMakeLists.txt` mit `ctest` | CTest | `ctest --output-on-failure` |

Pruefe auch CLAUDE.md fuer projektspezifische Test-Befehle.

### Schritt 2: Tests ausfuehren

Nutze das `Bash`-Tool:

```bash
python -m pytest --tb=short -q 2>&1
```

Erfasse: passed, failed, errors, skipped, duration, warnings.

### Schritt 3: Health Score berechnen (0-100)

```
base_score = (passed / total) * 100
Penalties:
  - Jeder failed Test: -5
  - Jeder error: -10
  - Keine Tests: Score = 0
  - Duration > 60s: -5
  - >20% Warnungen: -5

health_score = max(0, base_score - penalties)
```

| Score | Bewertung |
|-------|-----------|
| 90-100 | Excellent |
| 70-89 | Good |
| 50-69 | Warning |
| 0-49 | Critical — Fixes priorisieren |

### Schritt 4: Regressions-Check

Lies vorherige `test-results.json` mit `Read`-Tool und vergleiche:
- **REGRESSION**: Vorher passed, jetzt failed
- **FIX**: Vorher failed, jetzt passed
- **GROWTH**: Neue Tests
- **FLAKY**: Wechselt zwischen passed/failed

### Schritt 5: test-results.json aktualisieren

```json
{
  "id": "<YYYY-MM-DD-HH-MM>",
  "timestamp": "<ISO 8601>",
  "trigger": "<manual|orchestrator|pre-commit>",
  "framework": "<pytest|jest|custom>",
  "results": {
    "total": 42,
    "passed": 40,
    "failed": 1,
    "errors": 0,
    "skipped": 1,
    "duration_seconds": 12.3
  },
  "health_score": 88,
  "regressions": [],
  "fixes": [],
  "new_tests": [],
  "flaky_suspects": [],
  "failed_details": []
}
```

### Schritt 6: Ergebnis ausgeben

```
Test-Ergebnis: <health_score>/100 (<bewertung>)
   Passed: <n> | Failed: <n> | Errors: <n> | Skipped: <n>
   Duration: <n>s

   Regressions: <n>
   Neue Tests: <n>
   Trend: <improving|stable|declining>

   [Falls failed > 0:]
   → Empfehlung: Zuerst <test_name> fixen (Regression!)
```

### Schritt 7: Eskalation bei Critical

Wenn health_score < 50:
- Blockiere weitere Feature-Arbeit (Empfehlung)
- Liste fehlende/fehlgeschlagene Tests priorisiert auf
- Schlage "Test-First" Reihenfolge vor

## Coverage-Tracking (optional)

```bash
python -m pytest --cov=src --cov-report=term -q 2>&1
```

Coverage > 80%: +5 Bonus | Coverage < 40%: -10 Penalty

## Log-Rotation

Wenn `test-results.json` mehr als 100 Eintraege enthaelt (konfigurierbar via Plugin-Setting `max_test_result_entries`):
- Behalte die neuesten 100 Eintraege
- Archiviere aeltere in `test-results-archive-<YYYY-MM>.json` im selben Verzeichnis
