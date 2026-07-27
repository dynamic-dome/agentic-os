# Pattern Catalog

*Last updated: 2026-07-27*
*Total patterns: 3 (1 anti-patterns, 2 best practices)*

## High Confidence Warnings

### P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial) — Structured post-implementation review with 3 Codex subagent roles: (1) Verifier against spec — diff vs stated contract, finds missing parts / param-order / typos; (2) Security — injection / SSRF / path-traversal / privacy-leak review; (3) Quality-Fixer — reads findings from 1+2 and applies within budget (<=3 files, (confidence: 0.8)
- **Type:** best-practice
- **Evidence:** 4 occurrences
- **Recommendation:** After substantive commits: ask user '[1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]'. Default wenn User nicht explizit antwortet: Verifier only. Spawn background agents with focused scope prompts. For multi-phase packages, do a second Verifier-pass over the full package to catch doc/code drift that per-phase review misses
- **Tags:** workflow, review, codex, subagent, quality-gate

### G-pattern-005: Exit-Code 0 / ok-Flag beweist keinen inhaltlichen Erfolg — gegen Ground-Truth verifizieren. Ein Tool/Subprozess kann sauber mit Exit 0 / status:done enden, obwohl die Arbeit inhaltlich fehlschlug ODER nur behauptet wurde. (a) agent_smoke --live-external gab EXIT 0, aber Ergebnis-JSON sagte ok:false / worker_timeout. (b) Dual-Bridge Stage-1-Result meldete status:done + Commit-Hash — der Beweis kam  (confidence: 0.92)
- **Type:** best-practice
- **Evidence:** 10 occurrences
- **Recommendation:** Nie dem Exit-Code/status/PASS-Print allein glauben: gegen den echten Zustand prüfen (DB-Row-Counts gegen Vorher-Snapshot, geschriebene Artefakt-Dateien, mtimes, Git-Branch-Inhalt, Event-Stream + permission_denials). Eigene adversariale Fälle gegen das echte Binary statt der bestandenen Suite. Gilt auch für Beweis-Skripte und Subagent-Reports. Verwandt mit Verifikation-vor-Aktion (CLAUDE.md §4) und
- **Tags:** verification, exit-code, ground-truth, honesty, verifikation-vor-aktion, dco, dual-bridge, git, claude-cli

### P011: Robustheits-Vertraege (fail-soft, always-exit-0, JSONL-Integritaet) ohne Randfall-Regressionstests: Happy-Path-Suiten bleiben gruen, waehrend kaputte Args (argparse sys.exit), trailing Flags (bash shift-Endlosschleife), Kontrollzeichen (JSONL-Zeilenriss) und Non-ASCII auf Windows-cp1252-stdout den Vertrag brechen (confidence: 0.8)
- **Type:** anti-pattern
- **Evidence:** 4 occurrences
- **Recommendation:** Fuer jedes Script mit Robustheits-Vertrag eine Randfall-Matrix testen: (1) malformed/unbekannte Args -> Exit-Code + stdout-Reinheit, (2) Flag als letztes Token ohne Wert -> Terminierung mit timeout-Test, (3) --help -> reiner Help-Text, (4) Kontrollzeichen/Newline-Injection in Feldwerte -> Record-Integritaet (Whitelist-Sanitization), (5) Non-ASCII-Inhalt bei gepipetem stdout auf Windows -> UTF-8-re
- **Tags:** fail-soft, cli-contract, edge-cases, testing, windows, arg-parsing

## Skill Candidates

- P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial) — Structured post-implementation revie

- P011: Robustheits-Vertraege (fail-soft, always-exit-0, JSONL-Integritaet) ohne Randfall-Regressionstests: Happy-Path-Suiten bl
