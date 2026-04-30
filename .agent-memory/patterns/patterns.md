# Pattern Catalog

*Last updated: 2026-04-30*
*Total patterns: 4 (3 anti-patterns, 1 best practices)*

## High Confidence Warnings

### pattern-001: Windows/Git Bash path and shell compatibility
- **Type:** anti-pattern
- **Confidence:** 0.7
- **Occurrences:** 3
- **Tags:** bash, windows, paths, compatibility
- **Description:** Shell scripts fail on Windows/Git Bash due to: (1) set -e + arithmetic, (2) paths with spaces in string interpolation, (3) git pathspec syntax differences
- **Recommendation:** Always use $((VAR + 1)) instead of ((VAR++)), pass file paths via process.argv not interpolation, test scripts on Windows before committing

### P001: Windows Subprocess PATH Resolution
- **Type:** anti-pattern
- **Confidence:** 0.8
- **Occurrences:** 1
- **Tags:** windows, subprocess, path
- **Description:** subprocess.run findet CLI-Tools nicht, weil uvicorn/Service-Prozesse einen anderen PATH haben als die User-Shell
- **Recommendation:** Immer shutil.which() für absolute Pfadauflösung vor subprocess.run verwenden

### P002: Windows UTF-8 Subprocess Encoding
- **Type:** anti-pattern
- **Confidence:** 0.8
- **Occurrences:** 1
- **Tags:** windows, subprocess, encoding, utf8
- **Description:** CLI-Argumente auf Windows mangeln UTF-8 Zeichen (Umlaute, Sonderzeichen) — Ausgabe wird korrupt
- **Recommendation:** Text via input= (stdin) statt als CLI-Argument übergeben, encoding='utf-8' explizit setzen

### P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial)
- **Type:** best-practice
- **Confidence:** 0.8
- **Occurrences:** 4
- **Tags:** workflow, review, codex, subagent, quality-gate
- **Description:** Structured post-implementation review with 3 Codex subagent roles: (1) Verifier against spec — diff vs stated contract, finds missing parts / param-order / typos; (2) Security — injection / SSRF / path-traversal / privacy-leak review; (3) Quality-Fixer — reads findings from 1+2 and applies within budget (<=3 files, no new imports, no API/schema changes). Verifier + Security run in parallel as background agents; Quality-Fixer waits for both to consolidate. Skip Quality-Fixer when the fix scope is trivial (e.g. 2 string edits) — direct main-model edit is cheaper than subagent overhead
- **Recommendation:** After substantive commits: ask user '[1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]'. Default wenn User nicht explizit antwortet: Verifier only. Spawn background agents with focused scope prompts. For multi-phase packages, do a second Verifier-pass over the full package to catch doc/code drift that per-phase review misses


## Medium Confidence

*(none)*


## Low Confidence

*(none)*


## Skill Candidates

- P010: Three-role Codex code review (Verifier + Security parallel, Quality-Fixer serial) — already generated as `codex-3-role-review`
