# HOW-TO-USE — Agentic OS

Wegweiser fuer User UND Agent. Einstiegspunkt in dieses Repo.

## Was ist das?

Ein Claude-Code-Plugin fuer selbst-verbesserndes Agent-Gedaechtnis. Persistiert
Projektwissen in `.agent-memory/` ueber Sessions hinweg. Details: [docs/PROJECT.md](docs/PROJECT.md).

## Fuer den Agenten: wo steht was?

| Frage | Datei |
|-------|-------|
| Projekt-Regeln & Konventionen | [CLAUDE.md](CLAUDE.md) |
| Was kann das Projekt? | [docs/PROJECT.md](docs/PROJECT.md), [docs/CAPABILITIES.md](docs/CAPABILITIES.md) |
| Wie ist es aufgebaut? | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Was hat sich geaendert? | [docs/CHANGELOG.md](docs/CHANGELOG.md) |
| Skill-Abhaengigkeiten | [skills/DEPENDENCIES.md](skills/DEPENDENCIES.md) |
| Memory-Schema (Source of Truth) | [scripts/mem-schema.sh](scripts/mem-schema.sh) |

**Quellen-Hierarchie fuer Projekt-Kontext:** Die `docs/`-Dateien sind autoritativ
(Source of Truth). `.agent-memory/context/project-context.md` ist ein kompakter
**Cache** davon, den `context-keeper` aus den Docs destilliert. Bei Drift gewinnen
die Docs — nie den Cache als Wahrheit nehmen.

## Build & Test

```bash
bash tests/run-all.sh          # alle Tests
bash tests/validate-plugin.sh  # nur Plugin-Struktur
bash tests/validate-skills.sh  # nur Skill-Validierung
```

Kein Build-Step, kein Package-Manager — reines Markdown/JSON/Bash.

## Wichtigste Slash-Commands

- `/agentic-os:init` — Memory-System im aktuellen Projekt initialisieren
- `/agentic-os:status` — Health/Stand anzeigen
- `/agentic-os:wrap-up` — Session abschliessen (Handoff + Learnings)
- `/agentic-os:run-loop` — Self-Improve-Loop manuell starten

## Gotcha: Cache-Kopie

Die laufende Plugin-Instanz nutzt eine versionierte Kopie unter
`~/.claude/plugins/cache/agentic-os-marketplace/agentic-os/<version>/`. Repo-Edits
greifen erst nach Cache-Spiegelung oder Marketplace-Update. Siehe CHANGELOG.
