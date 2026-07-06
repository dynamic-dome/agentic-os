# Pattern Catalog

*Last updated: 2026-07-06 (pattern-extractor lightweight: G-pattern-005 Occurrence-Update 7→8 aus Harvest-Iterationen)*
*Total patterns: 2 (1 best-practice, 1 best-practice/global)*

## High Confidence Warnings

### G-pattern-005: Exit-Code 0 / ok-Flag beweist keinen inhaltlichen Erfolg
- **Type:** best-practice (global, lifecycle: active, gepullt 2026-06-12)
- **Confidence:** 0.92
- **Occurrences:** 8 (zuletzt 2026-07-06: T-005-Base-Dir-Beweis, UC7-Changelog-first, Docs-Drift-Check)
- **Tags:** verification, exit-code, ground-truth, honesty, verifikation-vor-aktion
- **Description:** Ein Tool/Subprozess kann sauber mit Exit 0 / status:done enden, obwohl die Arbeit inhaltlich fehlschlug oder nur behauptet wurde (Beispiele: agent_smoke ok:false bei Exit 0; Bridge-Result status:done ohne Merge; Hook-Canary ueberlebte ohne dass der Hook blockte; git-Bypass-Luecken nur im Live-Spotcheck).
- **Recommendation:** Nie dem Exit-Code/status/PASS-Print allein glauben — gegen den echten Zustand pruefen (Row-Counts, Artefakt-Dateien, mtimes, Git-Branch-Inhalt, permission_denials). Verwandt mit CLAUDE.md §4 (Verifikation vor Aktion).

### P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial)
- **Type:** best-practice
- **Confidence:** 0.8
- **Occurrences:** 4
- **Tags:** workflow, review, codex, subagent, quality-gate
- **Description:** Structured post-implementation review with 3 Codex subagent roles: (1) Verifier against spec; (2) Security; (3) Quality-Fixer applies findings within budget. Verifier + Security parallel, Quality-Fixer serial. Skip Quality-Fixer for trivial scopes.
- **Recommendation:** After substantive commits: ask user '[1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]'. Default: Verifier only.

## Medium Confidence

*(none)*

## Low Confidence

*(none)*

## Skill Candidates

- P010: Three-role Codex code review — already generated as `codex-3-role-review`

## Archiv

- 2026-06: P001 (Windows Subprocess PATH), P002 (Windows UTF-8 Subprocess Encoding), P003 (Windows/Git-Bash Shell-Kompatibilitaet) — alle last_seen >60d, abrufbar in `patterns-archive-2026-06.json`. Inhaltlich bleiben die Regeln ueber CLAUDE.md §10 (Windows-Subprocess-Familie) abgedeckt.
