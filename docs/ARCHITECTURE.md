# Architektur — Agentic OS

## Ueberblick

Das Plugin installiert Skills, Hooks, Agents und Commands, die Projektwissen in einem `.agent-memory/`-Store persistieren. Der Store hat ein striktes Schema (eine Single Source of Truth) und eine DAG-Schreibordnung: jede Datei hat genau einen schreibberechtigten Skill.

## Komponentendiagramm

```
SessionStart-Hook (session-start.sh)
  └─ sourct scripts/mem-schema.sh → create_memory_structure()  [Init + Backfill]
       └─ .agent-memory/  (identity, context, iterations, patterns, quality, learnings, working, ...)

session-bootstrap (read-only)  →  WORK PHASE  →  wrap-up (Handoff + Learnings)
        ▲ liest Store + zentralen Handoff           │ schreibt session-summary, learnings,
                                                     │ zentralen Handoff (prepend), Status-Board
   Skills schreiben je EINE Datei:
   iteration-logger→iterations/  context-keeper→context/  quality-gate→quality/
   pattern-extractor→patterns/   skill-generator→generated-skills/
```

## Kernkomponenten

### Schema Single Source of Truth
- **Datei(en):** `scripts/mem-schema.sh`
- **Aufgabe:** Definiert die komplette `.agent-memory/`-Struktur + Defaults in `create_memory_structure()`. Idempotent.
- **Abhaengigkeiten:** Konsumiert von `scripts/session-start.sh` (Hook) und `commands/init.md` (`/init`).

### SessionStart-Hook
- **Datei(en):** `scripts/session-start.sh`, `hooks/hooks.json`
- **Aufgabe:** Phase 0 sourct die SSoT; Phase 1 = Auto-Init bei fehlendem Store; Phase 2 = Backfill (heilt partielle Stores) + Kontext-Injection.
- **Abhaengigkeiten:** `mem-schema.sh`. Schreibt `project-context.md` selbst (Inline-Stack-Detection — bewusst ausserhalb der SSoT).

### Skills (14, geschichtet)
- **Datei(en):** `skills/*/SKILL.md`
- **Aufgabe:** Session-Lifecycle + Memory-Management. Genau ein Schreiber pro Store-Datei.
- **Abhaengigkeiten:** Strikt azyklisch (`skills/DEPENDENCIES.md`).

## Datenfluss

1. SessionStart-Hook sourct `mem-schema.sh`, erzeugt/heilt `.agent-memory/`, injiziert Kontext.
2. `session-bootstrap` liest Store + zentralen Handoff (read-only), produziert Briefing.
3. Work Phase: User/CLAUDE.md-getrieben rufen Skills, die je ihre Store-Datei schreiben.
4. `wrap-up` schreibt session-summary, Learnings, zentralen Handoff (prepend) + Status-Board.

## Persistenz

| Speicher | Typ | Pfad | Inhalt |
|----------|-----|------|--------|
| Memory-Store | Dateien | `.agent-memory/` | Identity, Context, Iterations, Patterns, Quality, Learnings, Working |
| Zentraler Handoff | Markdown | `~/AI/.agent-memory/session-summary.md` | Cross-Project, gestapelt (prepend) |
| Status-Board | Markdown | `~/AI/cross-project-status.md` | Ein Abschnitt pro Projekt |

## Sicherheit

Self-improve ist policy-gated (single-cluster, no-self-mod, rollback-tagged). Max 20% Mutation pro Skill/Iteration. Git-revert statt stash-pop. `.agent-memory/` von Commits ausgeschlossen.

## Deployment

Reines Markdown/JSON/Bash, kein Build. Installation via `claude plugin install`. Laufende Instanz nutzt eine versionierte Cache-Kopie unter `~/.claude/plugins/cache/...` — Repo-Edits greifen erst nach Cache-Spiegelung oder Marketplace-Update.
