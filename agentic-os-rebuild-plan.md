# Agentic OS v3 — Umbauplan

## Zusammenfassung

Das Plugin wird von 15 Skills + 4 Hooks auf **9 Skills + 2 Hooks** reduziert.
Gesamte Skill-Zeilenanzahl sinkt von ~2180 auf ~1400 (geschätzt), bei höherer
Qualität pro Skill. Hook-Overhead sinkt von 135s auf 45s pro Session.

---

## Skill-Mapping: Alt → Neu

### Behalten (überarbeiten)

| # | Skill | Zeilen (alt) | Aktion | Zeilen (Ziel) |
|---|-------|-------------|--------|---------------|
| 1 | **session-bootstrap** | 50 | Heartbeat-Funktionalität einmergen, deutlich ausbauen | ~200 |
| 2 | **iteration-logger** | 73 | Auf v2-Niveau bringen (Duplicate Detection, Tags, Recurrence) | ~180 |
| 3 | **pattern-extractor** | 61 | Clustering-Logik, Confidence-Scoring, Step-by-Step zurückportieren | ~150 |
| 4 | **code-reviewer** | 137 | Leicht straffen, ist solide | ~130 |
| 5 | **test-validator** | 149 | Leicht straffen, ist solide | ~140 |
| 6 | **tdd** | 326 | Unverändert, ist exzellent | 326 |
| 7 | **wrap-up** | 65 | Massiv ausbauen (Detail-Level wie tdd) | ~180 |
| 8 | **skill-generator** | 140 | Leicht anpassen | ~130 |

### Neu erstellen

| # | Skill | Basis | Zeilen (Ziel) |
|---|-------|-------|---------------|
| 9 | **context-keeper** | Aus v2 portieren, decisions.json + project-context.md Owner | ~180 |

### Streichen

| Skill | Grund |
|-------|-------|
| **heartbeat** | Funktionalität in session-bootstrap einmergen. Context-Matrix und Skill-Registry liefern keinen nachweisbaren Mehrwert — Claude kennt die verfügbaren Skills bereits über available_skills. Token-Budgets zu schätzen ist unzuverlässig und führt zu False-Positives. |
| **agent-orchestrator** | Funktioniert nicht zuverlässig in 15s PostToolUse-Hook. Der Agent erkennt selbst wann er loggen sollte — ein Orchestrator der nach jedem Edit feuert ist overhead ohne Gewinn. Stattdessen: CLAUDE.md Regeln. |
| **soul-and-identity** | Init-Logik geht in init-command. Read-Modus ist trivial (einfach Datei lesen). Update-Modus gehört in wrap-up. Kein eigener Skill nötig. |
| **sync-context** | Cross-Project Sync hat Race Conditions, IDs kollidieren, und der Mehrwert ist unklar bis du 3+ aktive Projekte hast. Manuell per Script wenn nötig. |
| **retrospective** | Aggregiert Daten die code-reviewer und test-validator schon einzeln liefern. Der User kann die JSON-Dateien direkt abfragen. Kann als optionaler Skill später dazukommen. |
| **mutation-engine** | Setzt Eval-Infrastruktur voraus die nicht existiert. skill-creator deckt diesen Workflow besser ab. Dead Weight bis 50+ Iterationen geloggt sind. |
| **agent-handoff** | Überlappung mit wrap-up (beide schreiben session-summary.md). PreCompact-Hook ruft es auf, aber wrap-up kann das genauso. Handoff-Briefing = Session-Summary mit mehr Detail → in wrap-up integrieren. |
| **init-memory** | Dupliziert den init-Command. Der Command reicht. |

---

## Hook-Reform

### Alt (135s Overhead)

```
SessionStart:  heartbeat (30s) + superpowers (30s)     = 60s
PostToolUse:   orchestrator (15s) × N Edits             = 15s × N
PreCompact:    agent-handoff (30s)                       = 30s
Stop:          iteration-check + wrap-up (30s)           = 30s
```

### Neu (45s Overhead, kein per-Edit Overhead)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Read .agent-memory/session-summary.md and .agent-memory/identity/soul.md silently. Apply the identity settings. Only report to the user if there are warnings (declining quality scores, unresolved critical patterns). Keep the briefing under 10 lines.",
            "timeout": 15
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if meaningful work was done this session. If yes: update .agent-memory/session-summary.md with completed work, open items, and next steps (max 30 lines). If coding iterations were completed but not logged, log them to iteration-log.md. If nothing meaningful was done, skip silently.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Gestrichen:**
- `PostToolUse` — Hauptquelle von Latenz und Rekursionsrisiko. Stattdessen: CLAUDE.md Regeln die den Agent anweisen, nach einem Fix iteration-logger zu nutzen.
- `PreCompact` — wrap-up im Stop-Hook deckt das ab. Für explizite Handoffs: User sagt "wrap up".
- `SessionStart[1]` (superpowers) — gehört nicht in dieses Plugin.

---

## Verzeichnisstruktur-Reform

### Alt (13 Verzeichnisse, 25+ Dateien)

```
.agent-memory/
├── identity/          (2 Dateien)
├── heartbeat/         (3 Dateien)      ← streichen
├── orchestrator/      (2 Dateien)      ← streichen
├── iterations/        (2 Dateien)
├── patterns/          (2 Dateien)
├── context/           (2 Dateien)
├── quality/           (3 Dateien)
├── learnings/         (2 Dateien)
├── generated-skills/                   ← behalten, aber leer starten
├── retrospectives/    (2 Dateien)      ← streichen
├── evolution/         (3+ Dateien)     ← streichen
├── transfer/          (3 Dateien)      ← streichen
└── session-summary.md
```

### Neu (6 Verzeichnisse, 14 Dateien)

```
.agent-memory/
├── identity/
│   ├── soul.md
│   └── user.md
├── context/
│   ├── project-context.md
│   └── decisions.json
├── iterations/
│   ├── iteration-log.md
│   └── errors.json
├── patterns/
│   ├── patterns.md
│   └── patterns.json
├── quality/
│   ├── test-results.json
│   ├── code-reviews.json
│   └── quality-score.json
├── learnings/
│   └── learnings.md
├── generated-skills/
└── session-summary.md
```

**Was in identity/soul.md integriert wird** (statt separater Dateien):
- trigger-rules → Soul-Abschnitt "Arbeitsverhalten"
- skill-feedback → entfällt (zu dünn genutzt)

---

## Skill-Umbau im Detail

### 1. session-bootstrap (50 → ~200 Zeilen)

**Einmergen aus heartbeat:**
- JSON-Validierung der Kerndateien (aber keine Context-Matrix, keine Skill-Registry)
- Konsistenz-Check: CLAUDE.md ↔ .agent-memory/ (existieren die referenzierten Dateien?)

**Neu hinzufügen:**
- Scaling Guard (aus v2): Warn bei errors.json > 200 Einträge, decisions.json > 50 aktiv
- Detailliertes Briefing-Format (aus v2) mit Statistiken
- Empfohlene nächste Schritte basierend auf Session-Summary + Pattern-Warnings

**Behalten aus alt:**
- Lese-Reihenfolge der Dateien
- Error Handling (fehlende Dateien, korruptes JSON)
- Verweis auf init-Command wenn .agent-memory/ nicht existiert

**Streichen:**
- Context-Matrix / Token-Budget-Schätzung
- Skill-Registry-Scan
- sync-context Aufruf

### 2. iteration-logger (73 → ~180 Zeilen)

**Zurückportieren aus v2:**
- Duplicate Detection (gleiche Kategorie + ≥2 überlappende Tags → Recurrence statt neuer Eintrag)
- Strukturiertes JSON-Schema mit allen Feldern (trigger, problem, root_cause, solution, failed_approaches, attempts, severity)
- Tag-Guidelines (konsistente lowercase Tags für Clustering)
- 5-Schritt-Prozess (Analyze → Duplicate Check → Write JSON → Write MD → Confirm)
- Counting-Regel: Zähle distinct Approaches, nicht einzelne Edits

**Streichen aus alt:**
- Cross-Project Push (gehört nicht in den Logger)

### 3. pattern-extractor (61 → ~150 Zeilen)

**Zurückportieren aus v2:**
- Detaillierte Detection Heuristics mit konkreten Schwellenwerten
- Confidence-Scoring-Methodik
- Tag-Overlap-Analyse für Clustering
- "Potential new pattern" Flagging für Fehler die keinem Pattern zugeordnet sind
- Empfehlung zur Skill-Generierung bei 3+ Occurrences

### 4. wrap-up (65 → ~180 Zeilen)

**Ausbauen:**
- Detaillierte Datensammlung (git diff --stat, Conversation History, Test-Status)
- Strukturiertes session-summary.md Format mit Pflichtfeldern
- Learnings-Logik: nur echte Insights loggen, keine trivialen Fakten
- user.md Update-Logik: nur bei wiederholtem Signal (≥3x gleiche Korrektur)
- Git-Commit-Logik: zeigen was committed wird, erst nach Bestätigung
- "What NOT to Do" Abschnitt (keine Modification von errors.json, patterns.json, decisions.json)

**Einmergen aus agent-handoff:**
- Bei PreCompact oder explizitem Handoff: erweitertes Summary mit Quality-State und aktiven Patterns

### 5. context-keeper (neu, ~180 Zeilen)

**Portieren aus v2:**
- Dual-File-Verantwortung: project-context.md (overwrite) + decisions.json (append-only)
- Klassifikation: stack-change, architecture-decision, constraint-update, dependency-note, status-update
- Konsistenz-Checks: Contradiction, Constraint, Open Questions, Tag Consistency
- Retrieval-Modus: Suche in decisions.json bei "Warum haben wir X gewählt?"

### 6. soul.md Template-Reform

**Alt ("Verbotene Aktionen"):**
```
- Nie Dateien löschen ohne Bestätigung
- Nie Dependencies hinzufügen ohne Begründung
- Nie mehr als 3 Dateien gleichzeitig ändern ohne Plan
```

**Neu ("Guard Rails" mit Kontext):**
```
## Guard Rails
- Confirm before deleting files (accidental deletion is hard to undo)
- Justify new dependencies (every dependency is a maintenance burden)
- For changes spanning many files: write a brief plan first
  (a rename across 5 files is fine; a new module structure needs a plan)
- No architecture decisions without discussion
  (the user wants to see options with pros/cons)
```

---

## Plugin-Struktur: Alt → Neu

### Alt

```
agentic-os/
├── .claude-plugin/plugin.json
├── commands/init.md, status.md, sync.md
├── hooks/hooks.json
├── agents/context-detective.md, memory-keeper.md
├── references/memory-structure.md, skill-template.md
├── scripts/init-global-memory.sh, .ps1
└── skills/ (15 Skills)
```

### Neu

```
agentic-os/
├── .claude-plugin/plugin.json
├── commands/
│   ├── init.md                    # Initialisierung (vereinfacht)
│   └── status.md                  # Status-Anzeige (unverändert)
├── hooks/hooks.json               # Nur SessionStart + Stop
├── agents/
│   └── context-detective.md       # Projekt-Autodetection (unverändert)
├── references/
│   ├── memory-structure.md        # Aktualisiert auf neue Struktur
│   └── skill-template.md          # Unverändert
└── skills/
    ├── DEPENDENCIES.md            # Aktualisiert
    ├── session-bootstrap/         # Startup + Health Check
    ├── iteration-logger/          # Iteration Logging (v2-Qualität)
    ├── pattern-extractor/         # Pattern Recognition (v2-Qualität)
    ├── context-keeper/            # Project Context + Decisions (neu)
    ├── code-reviewer/             # Code Review (leicht gestrafft)
    ├── test-validator/             # Test Validation (leicht gestrafft)
    ├── tdd/                       # TDD Workflow (unverändert)
    ├── wrap-up/                   # Session End + Handoff (ausgebaut)
    └── skill-generator/           # Skill Generation (leicht angepasst)
```

**Gestrichen:**
- `commands/sync.md` — Global Sync entfällt
- `agents/memory-keeper.md` — War Wrapper um Skills, kein Mehrwert
- `scripts/` — Global Memory entfällt, Init läuft über Command
- `skills/heartbeat/` — In session-bootstrap
- `skills/agent-orchestrator/` — In CLAUDE.md Regeln
- `skills/soul-and-identity/` — In init + wrap-up
- `skills/sync-context/` — Entfällt
- `skills/retrospective/` — Entfällt (vorerst)
- `skills/mutation-engine/` — Entfällt (skill-creator nutzen)
- `skills/agent-handoff/` — In wrap-up
- `skills/init-memory/` — Im init-Command

---

## Umsetzungsreihenfolge

### Phase 1: Kern-Skills (erst funktionsfähig machen)

1. **iteration-logger** — Auf v2-Qualität bringen
2. **pattern-extractor** — Auf v2-Qualität bringen
3. **context-keeper** — Aus v2 portieren
4. **wrap-up** — Ausbauen inkl. Handoff-Logik

### Phase 2: Session-Lifecycle

5. **session-bootstrap** — Heartbeat einmergen, Briefing ausbauen
6. **hooks.json** — Auf 2 Hooks reduzieren
7. **commands/init.md** — Vereinfachen (neue Verzeichnisstruktur)

### Phase 3: Aufräumen

8. **code-reviewer** — Leicht straffen
9. **test-validator** — Leicht straffen
10. **skill-generator** — Anpassen
11. **DEPENDENCIES.md** — Aktualisieren
12. **references/memory-structure.md** — Aktualisieren
13. Gestrichene Skills + Dateien entfernen

### Phase 4: Verifikation

14. Plugin paketieren
15. Init-Command in leerem Repo testen
16. Session-Lifecycle durchspielen (Start → Arbeit → Wrap-Up)

---

## CLAUDE.md Template (aktualisiert)

```markdown
# CLAUDE.md — Agentic OS

## Project
<1-2 Sätze aus project-context.md>

## Session Lifecycle
1. **Start**: session-bootstrap liest .agent-memory/ und gibt Briefing
2. **Work**: Regeln unten befolgen
3. **End**: wrap-up (Summary + Learnings + Git Commit)

## Work Rules
- After fixing a bug: log with iteration-logger
- On architecture decisions: record with context-keeper
- After code changes: run tests
- Small, focused changes per iteration
- Check patterns/patterns.md for known pitfalls before starting

## Identity
See .agent-memory/identity/soul.md and user.md

## Known Patterns
<auto-populated by pattern-extractor>

## Open Questions
<from project-context.md>
```

---

## Risiken und Annahmen

**Assumption:** Der Agent befolgt CLAUDE.md Regeln zuverlässig genug, dass kein
PostToolUse-Hook nötig ist. Basiert auf Erfahrung dass Claude Code CLAUDE.md
bei jeder Interaktion liest.

**Risiko:** Ohne Orchestrator könnte das Iteration-Logging vergessen werden.
Mitigation: Stop-Hook prüft auf ungeloggte Iterationen.

**Assumption:** Global Memory (cross-project sync) liefert derzeit keinen
nachweisbaren Mehrwert. Kann später als optionaler Skill nachgerüstet werden.

**Risiko:** Die gestrafften Skills könnten zu wenig Guidance geben.
Mitigation: Jeder Skill wird auf mindestens 130 Zeilen ausgebaut mit
konkreten Schemas, Beispielen und Anti-Patterns.
