---
name: agent-orchestrator
description: >
  Zentrale Steuerungslogik des Self-Improving Agent Systems fuer Claude Code.
  Analysiert nach jeder Interaktion den Output und triggert automatisch passende
  Skills (iteration-logger, test-validator, code-reviewer,
  pattern-extractor). Trigger: "orchestrate", "auto-improve", "system steuern",
  oder implizit nach jeder signifikanten Code-Aenderung.
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: orchestration
---

# Agent Orchestrator

## When to Use This Skill

Dieser Skill laeuft nach jeder signifikanten Agent-Interaktion.

Explizite Trigger:
- "orchestrate" / "auto-improve" / "system steuern"
- Am Ende jeder signifikanten Coding-Iteration
- **Automatisch via PostToolUse Hook** auf `Write|Edit` — der Hook sendet ein `code-changed` Signal bei substantiven Code-Aenderungen

## Dateistruktur

```
.agent-memory/
└── orchestrator/
    ├── trigger-rules.json    # Konfigurierbare Trigger-Regeln
    └── orchestrator-log.md   # Log der automatischen Aktionen
```

## Instructions

### Schritt 1: Output klassifizieren

Analysiere den Output der gerade abgeschlossenen Interaktion:

| Signal | Erkennungsmuster | Aktion |
|--------|-----------------|--------|
| `error-fixed` | Fehlermeldung → Fix → "funktioniert jetzt" | → iteration-logger |
| `decision-made` | "Ich verwende X statt Y" / Architektur-Aenderung | → iteration-logger |
| `code-changed` | Dateien erstellt/geaendert, neue Funktionen, Refactoring | → code-reviewer, test-validator |
| `test-result` | Tests liefen, Ergebnisse sichtbar | → test-validator |
| `pattern-threshold` | errors.json hat 5+ neue Eintraege seit letzter Analyse | → pattern-extractor |
| `skill-candidate` | pattern-extractor meldet skill_candidate: true | → skill-generator |
| `session-end` | User beendet Session / "fertig fuer heute" | → session-summary updaten |
| `no-action` | Einfache Frage/Antwort ohne Code-Aenderung | → nichts loggen |

Mehrere Signale koennen gleichzeitig auftreten.

### Schritt 2: Trigger-Regeln pruefen

Lies `trigger-rules.json` (oder erstelle mit Defaults):

```json
{
  "auto_log_iterations": true,
  "auto_review_code": true,
  "auto_run_tests": true,
  "pattern_check_interval": 5,
  "min_severity_for_log": "minor",
  "auto_context_on_decisions": true,
  "retrospective_interval_sessions": 5,
  "verbose_orchestrator_log": false
}
```

### Schritt 3: Skills ausloesen

Nutze das Claude Code `Skill`-Tool um die passenden Skills aufzurufen:

**Bei `error-fixed`:**
- Rufe `agentic-os:iteration-logger` auf
- Falls auto_review_code: Rufe `agentic-os:code-reviewer` auf

**Bei `decision-made`:**
- Rufe `agentic-os:iteration-logger` auf

**Bei `code-changed`:**
- Falls auto_run_tests: Rufe `agentic-os:test-validator` auf
- Falls auto_review_code: Rufe `agentic-os:code-reviewer` auf

**Bei `pattern-threshold`:**
- Zaehle neue Eintraege in errors.json seit letztem pattern-extractor Lauf
- Falls >= pattern_check_interval: Rufe `agentic-os:pattern-extractor` auf

### Schritt 4: Orchestrator-Log aktualisieren

Haenge an `orchestrator-log.md` an (nutze `Edit`-Tool):

```markdown
## [<Datum> <Uhrzeit>] Orchestrator-Aktion

**Erkannte Signale:** <signal1>, <signal2>
**Ausgeloeste Skills:** <skill1>, <skill2>
**Uebersprungen:** <skill3> (Grund: <regel deaktiviert / kein Bedarf>)

---
```

### Schritt 5: Bestaetigung

```
Orchestrator: <n> Signal(e) erkannt, <n> Skill(s) ausgeloest
   [error-fixed] → iteration-logger
   [code-changed] → test-validator, code-reviewer
```

## Konfiguration anpassen

Der User kann jederzeit sagen:
- "Schalte auto-review ab" → `auto_review_code: false`
- "Teste nicht automatisch" → `auto_run_tests: false`
- "Pattern-Check alle 10 Iterationen" → `pattern_check_interval: 10`
- "Zeig mir was der Orchestrator tut" → `verbose_orchestrator_log: true`
