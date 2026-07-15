# User Profile

*Initialized: 2026-03-23*
*First grown: 2026-06-03 (via wrap-up candidate queue)*

## Preferences
- **Begründung bei jeder Bewertung** — egal ob Zustimmung oder Ablehnung, immer mit nachvollziehbarer Begründung (explizit gefordert, 2026-06-03). [UC1, confirmed]
- **Ground-Truth vor Aktion** — Behauptungen aus Reports/Handoffs/Subagenten gegen die Live-Realität prüfen, nicht der Buchhaltung trauen. [UC2, confirmed]
- **Identity-Wachstum hat hohe Priorität** — soul.md/user.md sollen im Normal-Flow zuverlässig mit beobachteten Agent- und User-Eigenschaften gefüllt werden; Identity-Steps nie skippen, Statuszeile zeigen (expliziter Kernauftrag 2026-07-06). [UC7, confirmed]

## Work Style
- **Rückfragen bei echten Entscheidungen** statt stiller Annahmen (Pattern-Kanon, soul-Stufe wurden so geklärt); hinterfragt selbst aktiv und erwartet, dass der Agent eigene Einschätzungen revidiert, wenn das Nachhaken berechtigt ist. [UC3, inferred]
- **Block-Delegation:** überträgt die Recommended Next Steps aus dem Bootstrap als Block zur autonomen Abarbeitung ("arbeite die next steps zu Ende aus"); Zwischenfragen nur bei echten Entscheidungen. [UC5, confirmed 2×]
- **Zwei-Aufruf-Klammer als realer Workflow:** nutzt nur session-bootstrap am Start und wrap-up am Ende, sonst fast nichts — Plugin-Features müssen über diese Klammer erreichbar sein (führte zu v3.6.0 Session-Bracket-Coverage). [UC6, confirmed explizit]
- Schätzt TDD mit bidirektional verifizierten Tests und Codex-Verifier nach substanziellen Änderungen.
- **Subagent-Modellwahl nach Komplexität** — so viele Subagenten wie nötig, jeweils mit dem kleinsten ausreichenden Modell (Implementer/Reviewer sonnet, mechanische Fixes haiku, Fable nie ungefragt); bestätigt durch den v4.7.0-Modell-Routing-Auftrag, der genau diese Präferenz ins Plugin gießt. [UC8, confirmed 2×]
- Push erfolgt durch den User selbst (per `!`-Befehl); Agent committet, pusht nicht autonom.
- **Verfassungs-/Workflow-Dokumente nur mit Show-before-write** — exakten Diff zeigen und auf OK warten, bevor SESSION-WORKFLOW.md o.Ä. geändert wird (explizite Anweisung 2026-06-12; promotet 2026-07-06 via Queue-Re-Review). [UC4, confirmed]

## Known Corrections
- (Recorded when user corrects agent behavior 2+ times — threshold lowered from 3 in v3.3.0)
