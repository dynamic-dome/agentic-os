---
name: mutation-engine
description: >
  Autonome Skill-Optimierung fuer Claude Code nach dem Auto-Research-Prinzip.
  Definiert binaere Eval-Kriterien pro Skill, benchmarkt gegen Evals und
  mutiert SKILL.md autonom. Nutzt Claude Code Agent-Tool mit Worktree-Isolation
  fuer sichere Mutationstests. Dokumentiert fehlgeschlagene Versuche als
  Research Assets. Trigger: "skill optimieren", "mutation engine", "auto optimize",
  "eval laufen lassen", "skill benchmarken", "ab-test",
  "optimize skill", "run eval", "benchmark skill".
metadata:
  author: agentic-os
  version: '3.0'
  part-of: agentic-os
  layer: evolution
---

# Mutation Engine

## When to Use This Skill

- Skill liefert wiederholt suboptimale Ergebnisse
- Systematische Verbesserung nach Skill-Erstellung
- Retrospektive zeigt Stagnation in einem Bereich
- AB-Test ob eine Skill-Aenderung eine Verbesserung bringt
- Periodisch (monatlich) fuer die wichtigsten Skills

## Dateistruktur

```
.agent-memory/
└── evolution/
    ├── evals/
    │   └── <skill-name>.eval.json   # Eval-Kriterien pro Skill
    ├── mutations/
    │   └── <skill-name>/
    │       ├── mutation-log.json     # Historie aller Mutations-Versuche
    │       ├── v1-original.md        # Backup der Original-SKILL.md
    │       └── failed/              # Research Assets
    │           └── <timestamp>.md
    └── benchmarks.json              # Aggregierte Benchmarks
```

## Instructions

### Schritt 1: Eval-Set definieren

Nutze `Write`-Tool fuer `evals/<skill-name>.eval.json`.
Alle Kriterien muessen binaer (Ja/Nein) sein:

```json
{
  "skill": "<skill-name>",
  "version": 1,
  "created": "<ISO 8601>",
  "criteria": [
    {
      "id": "C1",
      "category": "correctness",
      "question": "<Binaere Frage: Ja/Nein>",
      "weight": 2,
      "example_pass": "<Beispiel fuer Ja>",
      "example_fail": "<Beispiel fuer Nein>"
    },
    {
      "id": "C2",
      "category": "completeness",
      "question": "<Binaere Frage>",
      "weight": 1
    },
    {
      "id": "C3",
      "category": "format",
      "question": "<Binaere Frage>",
      "weight": 1
    },
    {
      "id": "C4",
      "category": "efficiency",
      "question": "<Binaere Frage>",
      "weight": 1
    }
  ],
  "test_scenarios": [
    {
      "id": "S1",
      "description": "<Szenario>",
      "input": "<Simulierter Input>",
      "expected_behavior": "<Was der Skill tun soll>"
    }
  ],
  "pass_threshold": 0.8,
  "max_score": "<Summe aller Weights>"
}
```

### Schritt 2: Baseline-Benchmark

Nutze `Agent`-Tool mit `isolation: "worktree"` fuer sichere Tests:

```
Fuer jedes Szenario S:
  1. Starte Agent mit der aktuellen SKILL.md als Kontext
  2. Gib den simulierten Input
  3. Bewerte jedes Kriterium binaer (1 oder 0)
  4. Berechne Score: Summe(kriterium.passed * kriterium.weight)

baseline_score = mean(scores)
baseline_pass_rate = count(score >= threshold * max) / total
```

Speichere in `benchmarks.json` via `Write`-Tool.

### Schritt 3: Mutations-Strategie waehlen

| Strategie | Beschreibung | Wann |
|-----------|-------------|------|
| `rephrase` | Formulierungen praezisieren | Score nahe am Ziel |
| `restructure` | Reihenfolge aendern (Tipp: `/skill-creator:skill-creator` fuer Best-Practice Struktur nutzen) | Korrekte Inhalte, falsche Reihenfolge |
| `augment` | Beispiele/Edge-Cases hinzufuegen (Tipp: `/superpowers:writing-skills` fuer Qualitaetsbeispiele referenzieren) | Unvollstaendige Abdeckung |
| `constrain` | Strengere Regeln, Guard-Rails | Output zu generisch |
| `simplify` | Ueberfluessiges entfernen | Skill zu komplex, Agent verliert Fokus |

### Schritt 4: Mutation durchfuehren

1. **Backup**: Nutze `Bash`: `cp SKILL.md mutations/<skill>/v<n>-backup.md`
2. **Mutiere**: Nutze `Edit`-Tool, max 20% des Skills pro Mutation
   - Dokumentiere JEDE Aenderung mit Begruendung
3. **Test**: Nutze `Agent`-Tool mit `isolation: "worktree"` fuer den mutierten Skill
4. **Vergleiche**: mutation_score vs. baseline_score

### Schritt 5: Entscheidung

```
WENN mutation_score > baseline_score:
  → Uebernehme Mutation (Edit-Tool fuer SKILL.md)
  → Aktualisiere benchmarks.json
  → Log: accepted

WENN mutation_score == baseline_score:
  → Verwerfe
  → Speichere in failed/ als Research Asset (Write-Tool)

WENN mutation_score < baseline_score:
  → Rollback (Bash: cp backup SKILL.md)
  → Speichere in failed/ mit Analyse
```

### Schritt 6: mutation-log.json aktualisieren

Nutze `Read` + `Write`-Tool:

```json
{
  "mutation_id": "<YYYY-MM-DD-HH-MM>-<strategie>",
  "timestamp": "<ISO 8601>",
  "strategy": "<rephrase|restructure|augment|constrain|simplify>",
  "changes": ["<Was geaendert>"],
  "rationale": "<Warum>",
  "baseline_score": 5.2,
  "mutation_score": 6.1,
  "delta": "+0.9",
  "result": "<accepted|rejected|rollback>",
  "failed_criteria": ["<Noch fehlschlagende Kriterien>"],
  "iteration": 3
}
```

### Schritt 7: Ergebnis ausgeben

```
Mutation Engine — <skill-name>
   Strategie: <strategy>
   Iteration: <n>

   Baseline:  <score>/<max> (Pass-Rate: <rate>%)
   Mutation:  <score>/<max> (Pass-Rate: <rate>%)
   Delta:     <+/- score>

   Ergebnis: ACCEPTED / REJECTED / ROLLBACK

   [Bei ACCEPTED:]
   → SKILL.md aktualisiert
   → Verbesserung bei: <Kriterien>

   [Bei REJECTED:]
   → Research Asset: failed/<timestamp>.md
   → Empfohlene naechste Strategie: <strategy>

   Historie: <n> Mutationen, <n> akzeptiert, bester Score: <score>
```

### Schritt 8: Research Assets pflegen

Fehlgeschlagene Mutationen sind wertvoll:
- Dokumentieren WAS NICHT FUNKTIONIERT
- Zukuenftige Modelle koennen dort ansetzen wo aktuelle stagnieren
- mutation-log.json wird zum Trainingsset fuer bessere Strategien

Pflege `failed/` Ordner pro Skill mit:
- Verworfener SKILL.md Version
- Analyse warum schlechter
- Welche Kriterien fehlschlugen
