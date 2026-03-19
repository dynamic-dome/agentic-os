---
name: heartbeat
description: >
  Systemweiter Health-Check bei jedem Session-Start in Claude Code. Scannt den
  skills/ Ordner gegen die Skill-Registry, baut die Context-Matrix, prueft
  Token-Budget und Konsistenz. Ersetzt session-bootstrap als Entry-Point und
  ruft diesen intern auf. Trigger: automatisch bei Session-Start, "heartbeat",
  "system check", "health check", "konsistenz pruefen".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: orchestration
---

# Heartbeat

## When to Use This Skill

Wird als ERSTER Skill jeder Session aufgerufen.
Ruft session-bootstrap intern auf nachdem die Systemchecks abgeschlossen sind.

Zusaetzlich manuell bei:
- Verdacht auf inkonsistenten Zustand
- Nach manuellem Hinzufuegen/Entfernen von Skills
- Wenn der Agent sich "komisch" verhaelt (Context-Erosion)
- Alle 10-15 Iterationen als Zwischencheck

## Dateistruktur

```
.agent-memory/
├── identity/
│   ├── soul.md              # → Laden und anwenden
│   └── user.md              # → Laden und anwenden
├── heartbeat/
│   ├── skill-registry.json  # Registrierte Skills + Metadaten
│   ├── context-matrix.json  # Token-Budget, geladene Dateien
│   └── heartbeat-log.md     # Chronologische Health-Checks
└── ...
```

## Instructions

### Schritt 1: Skill-Registry scannen

Nutze `Glob`-Tool um alle Skills zu finden:

```
Scan-Pfade:
1. .claude/skills/                     # Projekt-Skills
2. .agent-memory/generated-skills/     # Auto-generierte Skills
```

Fuer jeden gefundenen Skill, nutze `Read`-Tool fuer Frontmatter und erfasse:

```json
{
  "name": "<skill-name>",
  "path": "<relativer Pfad>",
  "last_modified": "<ISO 8601>",
  "size_bytes": 1234,
  "status": "<active|new|modified|missing|deprecated>"
}
```

### Schritt 2: Registry-Diff

Nutze `Read`-Tool fuer `skill-registry.json` und vergleiche:

| Status | Bedeutung | Aktion |
|--------|-----------|--------|
| `active` | Unveraendert | Keine Aktion |
| `new` | SKILL.md existiert, nicht in Registry | Registrieren |
| `modified` | Inhalt hat sich geaendert | Notieren |
| `missing` | In Registry, Datei fehlt | Warnung |

### Schritt 3: Context-Matrix aufbauen

Nutze `Read`-Tool fuer die Kernfiles und schaetze Token-Budget:

```json
{
  "timestamp": "<ISO 8601>",
  "total_context_tokens_estimate": 0,
  "budget_warning": false,
  "sections": [
    {
      "category": "identity",
      "files": ["soul.md", "user.md"],
      "estimated_tokens": 800,
      "priority": "critical",
      "loaded": true
    },
    {
      "category": "project-context",
      "files": ["project-context.md", "session-summary.md"],
      "estimated_tokens": 1200,
      "priority": "high",
      "loaded": true
    },
    {
      "category": "patterns",
      "files": ["patterns.md"],
      "estimated_tokens": 2000,
      "priority": "medium",
      "loaded": true
    },
    {
      "category": "skills",
      "files": ["<aktive SKILL.md>"],
      "estimated_tokens": 5000,
      "priority": "medium",
      "loaded": false,
      "note": "On-demand, nicht alle gleichzeitig laden"
    }
  ]
}
```

### Schritt 4: Token-Budget-Check

Claude Code Window: 200k Token

```
Safe Zone:    < 80k Token Kontext   → gruen
Warning Zone: 80k - 120k Token     → gelb (Dead Zone naht)
Danger Zone:  > 120k Token         → rot (Context Erosion aktiv)
```

Bei Warning/Danger:
- Empfehle welche Kontexte entladen werden koennen
- Schlage `/save-session` vor fuer Session-Rotation
- Empfehle `self-improving-agent:agent-handoff` fuer Kontext-Sicherung

### Schritt 5: Konsistenz-Checks

Nutze `Read` und `Grep` fuer:

**5.1 CLAUDE.md ↔ Skills**
- Sind alle Skills in CLAUDE.md referenziert?
- Enthaelt CLAUDE.md nicht-existierende Skills?

**5.2 Datei-Integritaet**
- Nutze `Bash`: `python -c "import json; json.load(open('<file>'))"` fuer JSON-Validierung
- Sind alle erwarteten Verzeichnisse vorhanden?

**5.3 Skill-Redundanz**
- Haben Skills ueberlappende Trigger-Woerter?
- Gibt es nie-genutzte Skills (laut orchestrator-log)?

### Schritt 6: Identitaet laden

Rufe `self-improving-agent:soul-and-identity` im `read` Modus auf:
- Lade soul.md → Kommunikationsstil und Prioritaeten anwenden
- Lade user.md → User-Praeferenzen verstehen

### Schritt 7: Session-Bootstrap ausfuehren

Delegiere an `self-improving-agent:session-bootstrap` fuer das Briefing:
- Projektkontext laden
- Letzte Session-Zusammenfassung
- Aktive Warnungen
- Empfohlene naechste Schritte

### Schritt 8: Heartbeat-Report ausgeben

```
HEARTBEAT — <Datum, Uhrzeit>

   SYSTEM STATUS
   Skills registriert: <n> | Neu: <n> | Modifiziert: <n> | Missing: <n>
   Context Budget: <used>/<total>k Token (<zone>)
   Konsistenz: <n> Checks bestanden, <n> Warnungen

   [Falls Warnungen:]
   CLAUDE.md referenziert entfernten Skill: <name>
   Context Budget bei 75% — Session-Rotation empfohlen

   IDENTITAET
   Rolle: <aus soul.md>
   Kuerzze-Level: <n>/5
   Autonomie: <aus soul.md>

   → Weiter mit Session-Briefing...
```

### Initialisierung (Erstmalig)

Falls `.agent-memory/heartbeat/` nicht existiert:
1. Nutze `Bash`: `mkdir -p` fuer Verzeichnisstruktur
2. Scanne Skills → `skill-registry.json` via `Write`-Tool
3. Baue initiale Context-Matrix
4. Falls `identity/` fehlt → Rufe `self-improving-agent:soul-and-identity` init auf
