# Last Session

*Date: 2026-07-06 23:15*
*Agent: Claude Code (Fable 5)*

## What Was Done
- Erste Session auf v4.0.1-Instanz (Restart-Beweis: Bootstrap lief aus Cache 4.0.1) — T-005 mit Ground-Truth geschlossen
- T-006 Owner-Entscheid (D-003): User-Skill save-session archiviert (~/.claude/skills/_deprecated/, rief entfernten skill-generator); session-summary bleibt bewusst; Dangling-Refs in session-summary+checkpoint bereinigt
- project-context.md-Cache via context-keeper von v3.6.0-Stand auf v4.0.1 neu geschrieben; docs/PROJECT.md-Drift (v4.0.0→v4.0.1) gefixt
- UC7-Queue-Marker korrigiert (war promotet, Marker fehlte); Identity-Pipeline v4: Harvest lief real (UC5 4. Vorkommen, SC-4 Eskalation)
- Learnings L23 (User-Skill-Cross-Refs bei Plugin-Deprecation) + L24 (Skill-Base-Dir = Restart-Ground-Truth); Layer-Lifecycle: 4 long-term, 9 archive-candidates
- Commits c23009b (docs) + 5cbc9fc (memory), vom User gepusht

## Open Items
- T-007: Identity-Pipeline weiter beobachten (Session 1/2-3: Pflicht-Zeile emittiert, Kandidaten real — positiv)
- docs/PROJECT.md: künftige Patch-Releases direkt mitziehen (Regel-13)

## Next Steps
1. T-007 Beobachtung fortsetzen  2. SC-4 im nächsten Bootstrap [j/n] entscheiden  3. Normale Projektarbeit (Plugin ist konsolidiert + deployt)

## Statistics
- Iterations: 3 (Harvest) | Errors: 0 | New Patterns: 0 (1 Update) | Learnings: +2 (L23, L24)

## Active Warnings
- G-pattern-005 (0.92, occ 8): Exit-Code/Buchhaltung ≠ Ground-Truth — gegen Live-Zustand prüfen
