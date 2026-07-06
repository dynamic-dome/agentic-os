# Self-Improve — Historical Evidence & Rule Rationales

> **Provenance:** extrahiert aus `skills/self-improve/SKILL.md` bei der v4.0.0-Kürzung (2026-07-06).
> Dieses Dokument ist Referenz/Hintergrund, KEIN Prompt-Text. Die operativen Regeln selbst
> stehen weiterhin (gestrafft) im SKILL.md; hier steht das *Warum* mit Iterations-Evidenz.

## Policy-Härtung 2026-04-30

Die 6-Punkte-Self-Improve-Policy wurde nach dem Plugin-Audit vom 2026-04-30 eingeführt,
um rekursives Chaos zu verhindern. Sie steht über den Constraints — bei Konflikt gewinnt
die Policy. Die ursprüngliche Cluster-Tabelle (Stand 2026-04-30) wurde bei der
v4.0.0-Kürzung nach `improvements/clusters.json` verschoben (inkl. der plugin-fremden
Einträge wie `dome-loop`, `crazy-professor`, dort mit `"scope": "external"` markiert).

**Policy 5 (No-Self-Mod-Boundary) — Einordnung:** Diese Regel ist die wichtigste
Sicherheits-Boundary, vergleichbar mit der globalen CLAUDE.md-Regel "NIEMALS Tests gegen
Production-Datenbanken" — analog nutzt self-improve niemals seinen eigenen
Maintainer-Pfad als Self-Mod-Target.

## Lever 1 — Global-Fix vor Commit (Pattern-Erschöpfung)

Der historische Loop verschwendete ~6–8 Iterationen damit, dasselbe Pattern in einer
zweiten Datei einen Run später erneut zu fixen:

- `sync-context` DE→EN-Trigger in **iter 41** → derselbe Fix im Body erst in **iter 50**
- `tools:` → `allowed_tools:` in **iter 5** → erneut in **iter 56**
- "10 skills" in `plugin.json` **iter 32** → dieselbe stale Zahl in `marketplace.json` erst **iter 52**

Konsequenz: Nach einem Minimal-Fix wird eine Grep-Signatur des Patterns über den GANZEN
Plugin-Tree gezogen und alle Vorkommen in derselben Iteration gefixt. Ein Pattern, das in
einer Datei gefixt, aber in drei anderen belassen wird, ist eine garantierte zukünftige
Duplikat-Iteration.

## Lever 2 — Substanz-Klassifikation (functional vs. cosmetic)

Der fix-count allein ist ein schlechtes Konvergenz-Signal: der count-basierte Exit
(eingeführt in **iteration 18**) feuerte über die **Iterationen 35–54** NIE, obwohl der
Loop dort fast nur Übersetzungen / Konsistenz-Edits (`[warning]`) produzierte. Von ~80
historischen Iterationen waren die meisten kosmetisch. Daher der zusätzliche
Substanz-Breaker: 3 aufeinanderfolgende Iterationen mit ausschließlich kosmetischen
Fixes → `SUBSTANCE-CONVERGENCE`-Stop.

## Lever 3 — Functional Lens (Analyse-Blindstelle Runtime/Logik)

Die historische Analyse-Phase war auf Frontmatter-/Sprach-/Count-Checks trainiert und
schwach bei Runtime-/Logik-Defekten: nur **~8% von 80 Iterationen** waren echte
Logik-Bugs, und die tauchten spät oder doppelt auf:

- **iter 30:** `knowledge/`-Verzeichnis fehlte (Lifecycle-Dead-End, init/backfill-Mismatch)
- **iter 53:** `code-reviewer` schrieb das deklarierte `quality-score.json` nie (Output-Gap)
- **iter 76/80:** `quality-gate` ignorierte Regressionen im WARN-Verdikt (Gate-Integrity)

Daraus entstand die verpflichtende Functional-Lens-Prüfung (Output-Gaps, Gate-Integrity,
Lifecycle-Dead-Ends cf. L4, Read/Write-Asymmetrie cf. L6, Control-Flow) vor dem Ranking.
(Hinweis: `quality-gate` und `code-reviewer`/`retrospective` existieren seit v4.0.0 nicht
mehr als eigene Skills — die Beispiele bleiben als historische Evidenz gültig.)

## Lever 4 — State↔.md-Atomizität

Im historischen Record hatte **ein Drittel der Iterationen 56–80** KEINEN
`.md`-Log-Block, und **iter 29** fehlte komplett — der `.md`-Write und der
`state.json`-History-Append waren auseinandergedriftet. Daher: beide Writes als atomare
Einheit (`.md`-Block ZUERST, dann `state.json`) plus Invariant-Check am Run-Ende
(`STATE-MD-DRIFT`-Report + Backfill).

## Lever 5 — Baseline-Sanity (absoluter Test-Count-Guard)

Der per-Iteration-Delta-Check fängt nur Regressionen *innerhalb* eines Runs. Er hätte
**iteration 64** nicht gefangen, in der die Suite **0 Plugin-Tests** meldete — "0 failures
of 0 tests" wurde als Erfolg interpretiert, obwohl der Harness schlicht keine Tests mehr
entdeckte. Daher der absolute Guard: Baseline-Count == 0 oder Einbruch auf ≤ 50% des
letzten `tests_after` aus der History → `BASELINE-SANITY`-Abort bzw. Mid-Run-Rollback.

## Lever 6 — Eval-Driven Acceptance Gate

Phase 4.2 allein war zu weich — "keine Sections entfernt, sieht nicht schlechter aus"
ließ Mutationen passieren, die einen Skill still schwächten, solange die Suite grün
blieb. Das binäre Eval-Set pro Skill ist die fehlende Hälfte des historischen Loops:
Lever 5 schützt die *Suite*, Lever 6 den *Contract des Skills selbst*. Historisches
Beispiel für ein skill-spezifisches Kriterium: quality-gate — "Does the WARN verdict
still check regressions?" (der Bug aus iter 76/80).

## Meta-Improve Recursion Guard — Timestamp statt Datum

Der timestamp-basierte 120-Minuten-Cooldown ersetzt den älteren "same date"-Check, der
legitime Re-Runs am selben Tag fälschlich blockierte und Back-to-Back-Runs über
Mitternacht hinweg erlaubte.
