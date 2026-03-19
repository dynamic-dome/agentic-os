---
name: agent-handoff
description: >
  Ermoeglicht sauberen Kontextwechsel zwischen Claude Code Sessions oder
  vor Context-Komprimierung. Konvertiert den aktuellen Projektkontext,
  aktive Warnungen und Session-State in ein kompaktes Briefing.
  Trigger: "kontext sichern", "session handoff", "agent handoff",
  "context fuer naechste session", "agent wechsel".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: transfer
---

# Agent Handoff

## When to Use This Skill

- Vor Context-Komprimierung in langer Claude Code Session
- Beim Wechsel zwischen Claude Code Sessions
- Wenn ein neuer Agent den Projektkontext braucht
- User sagt: "Kontext sichern" / "Session handoff"

## Dateistruktur

```
.agent-memory/
├── session-summary.md          # Kompaktes Session-Briefing
└── transfer/
    └── handoff-briefing.md     # Detailliertes Handoff-Dokument
```

## Instructions

### Schritt 1: Aktuellen State sammeln

Nutze `Read`-Tool fuer alle relevanten `.agent-memory/` Dateien:

```yaml
Handoff-Paket:
  session_summary: <aus session-summary.md>
  project_context: <aus project-context.md>
  active_patterns: <Top-10 aus patterns.json mit confidence: high>
  recent_errors: <Letzte 5 aus errors.json>
  quality_state:
    test_health: <aus quality-score.json>
    code_quality: <aus quality-score.json>
  open_questions: <aus project-context.md>
  current_task: <Was gerade in Arbeit ist>
```

### Schritt 2: Session-Summary aktualisieren

Nutze `Write`-Tool fuer `.agent-memory/session-summary.md`:

```markdown
# Session-Zusammenfassung

*Session: <Datum und Uhrzeit>*

## Was wurde gemacht
- <Zusammenfassung>

## Offene Punkte
- <Was noch zu tun ist>

## Naechste Schritte
1. <Empfehlung>
2. <Empfehlung>

## Aktive Warnungen
- <Pattern-Warnungen>
- <Offene Fehler>
```

### Schritt 3: Handoff-Briefing erstellen

Nutze `Write`-Tool fuer `.agent-memory/transfer/handoff-briefing.md`:

```markdown
# Handoff-Briefing — <Datum>

## Projekt-Kontext (kompakt)
<Aus project-context.md: Projektziel, Tech-Stack>

## Aktueller Status
<Was gerade in Arbeit ist, was fertig ist>

## Bekannte Patterns (WICHTIG)
<Top-5 Best Practices aus patterns.json>

## Anti-Patterns (VERMEIDEN)
<Top-5 Anti-Patterns>

## Quality State
- Test-Health: <score>/100
- Code-Quality: <score>/100
- Letzte Regressions: <Liste>

## Offene Fragen
<Aus project-context.md>

## Memory-System
Dieses Projekt nutzt `.agent-memory/` fuer persistentes Wissen.
Starte naechste Session mit `self-improving-agent:session-bootstrap`.
```

### Schritt 4: Handoff-Log

Haenge an `session-summary.md` an:

```markdown
## Handoff: <Datum>
- Grund: <Warum der Handoff>
- Offene Arbeit: <Was nicht fertig wurde>
- Naechster Schritt: <Konkrete erste Aufgabe>
```

### Schritt 5: Ergebnis ausgeben

```
Agent Handoff erstellt

   Generierte Dateien:
   - session-summary.md (aktualisiert)
   - transfer/handoff-briefing.md (aktualisiert)

   Kontext gesichert:
   - Projektstatus: <kurz>
   - Aktive Patterns: <n>
   - Offene Fragen: <n>

   Naechste Session starten mit:
   → self-improving-agent:session-bootstrap
```
