# Pattern Catalog

*Last updated: 2026-07-15*
*Total patterns: 3 (1 anti-patterns, 2 best practices)*

## High Confidence Warnings

### P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial) — Structured post-implementation revie (confidence: 0.8)
- **Type:** best-practice
- **Evidence:** 4 occurrences
- **Recommendation:** After substantive commits: ask user '[1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]'. Default wenn User nicht explizit antwortet: Verifier only. Spawn background agents with focused scope prompts. For multi-phase packages, do a second Verifier-pass over the full package to catch doc/code
- **Tags:** workflow, review, codex, subagent, quality-gate

### G-pattern-005: Exit-Code 0 / ok-Flag beweist keinen inhaltlichen Erfolg — gegen Ground-Truth verifizieren. Ein Tool/Subprozess kann sau (confidence: 0.92)
- **Type:** best-practice
- **Evidence:** 8 occurrences
- **Recommendation:** Nie dem Exit-Code/status/PASS-Print allein glauben: gegen den echten Zustand prüfen (DB-Row-Counts gegen Vorher-Snapshot, geschriebene Artefakt-Dateien, mtimes, Git-Branch-Inhalt, Event-Stream + permission_denials). Eigene adversariale Fälle gegen das echte Binary statt der bestandenen Suite. Gilt a
- **Tags:** verification, exit-code, ground-truth, honesty, verifikation-vor-aktion, dco, dual-bridge, git, claude-cli

### P011: Robustheits-Vertraege (fail-soft, always-exit-0, JSONL-Integritaet) ohne Randfall-Regressionstests: Happy-Path-Suiten bl (confidence: 0.8)
- **Type:** anti-pattern
- **Evidence:** 4 occurrences
- **Recommendation:** Fuer jedes Script mit Robustheits-Vertrag eine Randfall-Matrix testen: (1) malformed/unbekannte Args -> Exit-Code + stdout-Reinheit, (2) Flag als letztes Token ohne Wert -> Terminierung mit timeout-Test, (3) --help -> reiner Help-Text, (4) Kontrollzeichen/Newline-Injection in Feldwerte -> Record-Int
- **Tags:** fail-soft, cli-contract, edge-cases, testing, windows, arg-parsing

## Skill Candidates

- P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial) — Structured post- — generated: codex-3-role-review
- P011: Robustheits-Vertraege (fail-soft, always-exit-0, JSONL-Integritaet) ohne Randfall-Regressionstests:  — generated: cli-robustness-edge-case-tests
