# Iteration Log

## 2026-03-24 — feat: Self-Improve Loop Infrastructure
- **Type:** feature
- **Tags:** self-improve, tdd, testing, automation, scheduled-task
- **Files created:** tests/validate-plugin.sh, tests/validate-skills.sh, tests/run-all.sh, skills/self-improve/SKILL.md, agents/fix-reviewer.md, commands/auto-commit.md, improvements/state.json
- **Summary:** Built complete self-improvement loop: test suite (130 tests), orchestrator skill, fix-reviewer agent, auto-commit command, scheduled task (hourly). First manual iteration found and fixed 3 weaknesses via TDD.
- **Commits:** ac29136 (infrastructure), 1c1b288 (iteration #1)

## 2026-03-24 — fix: Self-Improve Iteration #1
- **Type:** bugfix
- **Tags:** sync-context, quality-gate, dependencies, self-improve
- **Files changed:** skills/sync-context/SKILL.md, agents/quality-gate.md, skills/DEPENDENCIES.md, tests/validate-plugin.sh
- **Summary:** 3 weaknesses found and fixed: (1) sync-context missing examples section, (2) quality-gate missing plugin-specific review rules, (3) self-improve not documented in DEPENDENCIES.md. Tests went from 117 (1 failing) to 130 (0 failing).
- **Errors encountered:** Test scripts failed on Windows due to `set -e` + bash arithmetic and path quoting with spaces. Fixed by removing `set -e` and using `process.argv` in node.

## 2026-03-30 — refactor: Skill Consolidation v3 (20 → 9 skills)
- **Type:** refactor
- **Tags:** consolidation, architecture, v3
- **Files changed:** skills/self-improve/SKILL.md, skills/quality-gate/SKILL.md, skills/wrap-up/SKILL.md, skills/DEPENDENCIES.md, .claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, tests/validate-plugin.sh, tests/validate-skills.sh
- **Summary:** Consolidated Agentic OS from 20 skills to 9. Merged self-improve pipeline (loop-orchestrator, research-phase, analysis-phase, improvement-phase, validation-phase, meta-improve, schedule-manager → self-improve), quality skills (code-reviewer, test-validator, tdd → quality-gate), and memory-janitor into wrap-up. Version bumped to 3.0.0. All 221 tests pass (114 plugin + 107 skill).
- **Confidence:** 5/5
- **Tests:** passed (221/221)
- **Learnings:** Internal pipeline phases that are never triggered directly by users should be inline sections in the orchestrating skill, not separate skills. The test suite's for-loop over skill dirs made deletion safe — removed dirs simply disappear from test scope.

## 2026-06-12 — feat: Session-Bracket-Coverage (v3.6.0, session-harvest + decision-scan)
- **Type:** feature
- **Tags:** wrap-up, iteration-logger, context-keeper, coverage, tdd, workflow
- **Files changed:** skills/wrap-up/SKILL.md, skills/iteration-logger/SKILL.md, skills/DEPENDENCIES.md, tests/validate-plugin.sh, .claude-plugin/plugin.json, docs/CHANGELOG.md, docs/PROJECT.md, docs/architecture-map.html
- **Summary:** User-Frage "decken bootstrap+wrap-up alle Plugin-Usages ab?" → Befund: die Kette iteration-logger→pattern-extractor→skill-generator verhungerte (5 Iterationen/3 Errors/Quality null nach Monaten), weil sie an manuellen /log-Aufrufen hing. Fix: wrap-up Step 1.5 (session-harvest, Retro-Logging via iteration-logger) + Step 4.5 (decision-scan via context-keeper); DEPENDENCIES.md "Session-Bracket Coverage"-Sektion (covered vs. bewusst on-demand). TDD: 4 Guard-Tests erst rot, dann 185/185 gruen; Codex-Verifier accepted-with-minors → 2 L11-false-green-greps gehaertet (Delegation muss EIN Satz sein; Matrix-Zeile statt whole-file), Strip-Probe rot/gruen, amended. Commit a3b49ac, gepusht, Deploy 3.6.0 (Cache-Ground-Truth ok). NB: dieser Wrap-up ist die erste Live-Ausfuehrung von Step 1.5 (manuell, da Instanz noch 3.5.1-Cache).
- **Confidence:** 5/5
- **Tests:** passed (185 validate-plugin + 165 validate-skills + 19 global-schema)
- **Learnings:** Skill-Coverage gegen den ECHTEN minimalen User-Workflow messen, nicht gegen die Feature-Liste — Skills, die kein realer Aufrufpfad erreicht, sind toter Code (→ L19).

## 2026-06-12 — fix: sharepoint-pull-check.ps1 NULL-Array bei Frontmatter-losen Handoffs
- **Type:** bugfix
- **Tags:** powershell, select-string, null-guard, session-bootstrap, frontmatter
- **Files changed:** skills/session-bootstrap/scripts/sharepoint-pull-check.ps1 (+ Spiegelung in 3.5.1-Cache)
- **Summary:** Live-Fund beim heutigen Bootstrap: Handoff-Dateien ohne target_agent-Frontmatter (INDEX.md) warfen "Index auf NULL-Array" — Direktzugriff ($head | Select-String ...).Matches.Groups[1].Value auf $null. Fix: Get-FmField-Helper (Guard + leerer String als Default, $target-Fallback '?'). Gegen echten Sharepoint verifiziert (kein Fehler, INDEX.md rendert als '-> ?'), byte-identisch in den laufenden 3.5.1-Cache gespiegelt.
- **Confidence:** 5/5
- **Tests:** Live-Lauf gegen echten Sharepoint (Suite deckt PS-Scripts nicht ab)
- **Errors:**
- err-004: Select-String-Direktzugriff ohne Match-Guard

## 2026-06-12 — fix: Command/Skill-Namensschatten entfernt (v3.5.1, T-002/L17)
- **Type:** bugfix
- **Tags:** commands, skill-tool, naming-collision, plugin, tdd
- **Files changed:** commands/wrap-up.md (geloescht), commands/quality-gate.md (geloescht), tests/validate-plugin.sh, CLAUDE.md, docs/PROJECT.md, docs/CHANGELOG.md, docs/architecture-map.html, .claude-plugin/plugin.json
- **Summary:** Die zwei Wrapper-Commands, deren Name mit einem Skill kollidierte, geloescht statt umbenannt — Skills sind direkt slash-invocierbar (ground-truth: session-bootstrap lief heute ohne Wrapper). Neuer L17-Guard-Test verbietet kuenftige Schatten (TDD: rot vor Loeschung mit beiden Funden, gruen danach). 12→10 Commands. Commit 50bdebf (inkl. Verifier-MINOR: Map-Header 12→10/v3.5.1, amended).
- **Confidence:** 5/5
- **Tests:** passed (180 validate-plugin + 165 validate-skills + 19 global-schema)
- **Learnings:** Der Skill-Tool-Namespace mergt Commands und Skills; bei Namensgleichheit gewinnt der Command und ein delegierender Wrapper wird zur Endlos-Indirektion. Wrapper-Commands sind seit direkter Skill-Invocation generell redundant.

## 2026-03-30 — fix: Adversarial Self-Improvement (#68 + #69)
- **Type:** bugfix
- **Tags:** adversarial-swarm, hooks, dead-code, testing, self-improve
- **Files changed:** hooks/hooks.json, commands/run-loop.md, skills/sync-context/SKILL.md, skills/self-improve/SKILL.md, skills/research-pipeline/SKILL.md, tests/validate-plugin.sh, scripts/session-end.sh (deleted), scripts/pre-compact.sh (deleted)
- **Summary:** Devil's Advocate Swarm found 17 issues. Fixed 10: stale refs (SubagentStop matcher, run-loop command), missing dependency (quality-gate), version inconsistency (sync-context), full German→English translation (research-pipeline body), SessionEnd hook streamlined to delegate to wrap-up, 2 dead scripts removed, 14 new regression tests added. Tests: 236→248.
- **Confidence:** 5/5
- **Tests:** passed (248/248)

## 2026-07-06 — refactor: v4.0.0 Skill-Konsolidierung 14→9 (Lösch-Welle)
- **Type:** refactor
- **Tags:** skills, consolidation, dead-code, tests, v4.0.0
- **Files changed:** skills/{quality-gate,retrospective,research-pipeline,wiki-query,skill-generator}/ (gelöscht), skills/pattern-extractor/SKILL.md (Skill-Candidate-Generation gefaltet), agents/quality-gate.md + 5 Wrapper-Commands + tools/-Leichen (gelöscht), tests/validate-{plugin,skills}.sh, run-all.sh
- **Summary:** 4-Agenten-Audit fand 5 Skills ohne einen einzigen Store-Artefakt-Nachweis (quality-score null, retrospectives/ + generated-skills/ + research/ nie erzeugt) bzw. extern doppelt (wiki-MCP, code-reviewer, deep-research). Löschung + Test-Nachzug via Subagent S1; L17-Guard bestehen geblieben.
- **Confidence:** 5/5
- **Tests:** passed (146 validate-plugin + 126 validate-skills + 19 global-schema + 17 circuit-breaker + contract)

## 2026-07-06 — feat: Identity-Growth-Pipeline gehärtet (v4.0.0-Kernfix)
- **Type:** feature
- **Tags:** identity, soul, user-md, wrap-up, session-bootstrap, hooks
- **Files changed:** skills/wrap-up/SKILL.md (Step 6 neu: Harvest-Checkliste, Full-Queue-Re-Review, Pflicht-Statuszeile, Eskalationspfad user→soul), skills/session-bootstrap/SKILL.md (Step 6.5 [j/n]-Gates für soul UND user + Starvation-Warnung), scripts/session-start.sh (user.md-Injektion), hooks/hooks.json (SessionEnd Identity-Verify)
- **Summary:** Diagnose: Identity-Wachstum starb multiplikativ (wrap-up-Ausfälle × stille Skips × enqueue-only-Queue × unerfüllbare soul-Kriterien — 1 Kandidat in 3,5 Monaten, UC4 wartete 3 Wochen promotable). Alle vier Dämpfer einzeln gefixt; Stufe-B-Invariante (soul.md nie autonom) unangetastet.
- **Confidence:** 4/5 (Design verifiziert, Langzeit-Beweis steht aus → T-007)
- **Tests:** passed (Marker-Tests user-growth/trust-boundary/soul-growth bidirektional grün)

## 2026-07-06 — refactor: Token-Diät + Threshold-SSoT (v4.0.0)
- **Type:** refactor
- **Tags:** tokens, efficiency, hooks, thresholds, ssot
- **Files changed:** hooks/hooks.json (UserPromptSubmit 112→41 W., SessionEnd gekürzt), 9 Skill-/3 Agent-Descriptions (−20%), skills/wrap-up (604→344 Z., Handoff-Template → references/), skills/self-improve (691→331 Z.), scripts/memory-thresholds.sh (neu, SSoT), scripts/learnings_top.py (neu), session-bootstrap (Status-Board-Sektion-Extrakt, Wiki-Cap 80 Z.)
- **Summary:** Gemessene Basis: ~25-30k Tokens pro Session-Zyklus + 2,2k permanenter Description-Ballast + 157 Tokens/Prompt UserPromptSubmit. Kürzungen ohne Semantikverlust; Threshold-Widerspruch iteration-logger(500/200) vs. memory-maintenance(100/50) durch ein Skript als einzige Quelle aufgelöst.
- **Confidence:** 5/5
- **Tests:** passed (alle Suiten)

## 2026-07-06 — chore: T-005 geschlossen (Restart-Ground-Truth) + UC7-Queue-Marker (Session-Harvest)
- **Type:** config
- **Tags:** open-tasks, identity, bookkeeping, ground-truth, deploy
- **Files changed:** .agent-memory/context/open-tasks.json, .agent-memory/working/user-candidates.json
- **Summary:** T-005 (v4.0.0-Restart) mit Ground-Truth geschlossen: der Bootstrap selbst lief nachweislich aus Cache .../agentic-os/4.0.1/ (Skill-Base-Dir als Beweis). UC7-Buchhaltungs-Drift gefixt: user.md-Eintrag + Changelog existierten, nur der Queue-Status fehlte → status: promoted (kein Changelog-Duplikat).
- **Confidence:** 5/5
- **Tests:** not applicable

## 2026-07-06 — config: T-006 Owner-Entscheid — save-session archiviert, session-summary bleibt (D-003)
- **Type:** config
- **Tags:** user-skills, deprecation, wrap-up, dead-code, decision
- **Files changed:** ~/.claude/skills/_deprecated/save-session/ (verschoben), ~/.claude/skills/session-summary/SKILL.md, ~/.claude/skills/checkpoint/SKILL.md, .agent-memory/context/decisions.json (D-003)
- **Summary:** save-session war seit v4.0.0 kaputt (Schritt 3 rief den entfernten skill-generator) und redundant zu wrap-up Step 1.5. Owner wählte via AskUserQuestion Option 2 (gegen die Empfehlung "beide"): session-summary bleibt bewusst als Mid-Session-Wiki-Pfad. Dangling-Refs in 2 Nachbar-Skills bereinigt.
- **Confidence:** 5/5
- **Tests:** not applicable
- **Learnings:** User-Level-Orchestrator-Skills, die Plugin-Skills namentlich aufrufen, brechen still bei Plugin-Konsolidierungen — Deprecation-Sweeps müssen ~/.claude/skills/ auf Cross-Referenzen greppen.

## 2026-07-06 — docs: Context-Cache-Refresh auf v4.0.1 + PROJECT.md-Drift-Fix (Session-Harvest)
- **Type:** docs
- **Tags:** context-keeper, docs-drift, cache, regel-13
- **Files changed:** .agent-memory/context/project-context.md (neu geschrieben, war auf v3.6.0-Stand), docs/PROJECT.md (v4.0.0→v4.0.1)
- **Summary:** project-context.md hing drei Major-Umbauten hinterher (v3.7–v4.0.1) — via context-keeper aus docs/ + Git-Ground-Truth neu destilliert. Dabei Docs-Drift gefunden: CHANGELOG hatte 4.0.1, PROJECT.md nicht → nachgezogen. Commits c23009b + 5cbc9fc, gepusht (User).
- **Confidence:** 5/5
- **Tests:** not applicable

## 2026-07-06 — config: SC-4 via [j]-Gate in soul.md gemergt (Session-Harvest)
- **Type:** config
- **Tags:** identity, soul, bootstrap-gate, block-delegation
- **Files changed:** .agent-memory/identity/soul.md, .agent-memory/identity/user-changelog.json, .agent-memory/identity/soul-candidates.md (Stub-Reset)
- **Summary:** Bootstrap Step 6.5a: User bestätigte SC-4 mit [j] — neue Guard Rail "Block-delegated next steps run autonomously end-to-end; interrupt only for genuine owner decisions". Changelog-first, dann Merge, dann Queue-Reset. Commit de1cac5, vom User gepusht. Soul-Queue damit leer.
- **Confidence:** 5/5
- **Tests:** not applicable

## 2026-07-06 — docs: Wiki-Entity agentic-os-plugin.md auf v4.0.1-Ground-Truth (Session-Harvest)
- **Type:** docs
- **Tags:** obsidian-sync, wiki, docs-drift, entity, ground-truth
- **Files changed:** ~/wiki/wiki/entities/agentic-os-plugin.md, ~/wiki/log.md
- **Summary:** Kopf + Sektionen 2-7 der Entity-Seite von v3.8.0- auf v4.0.1-Stand: Version-/Installations-Zeile (Marketplace-Cache statt ~/.claude/plugins/), Surface-Tabellen 14/11/4 → 9 Skills / 5 Commands / 3 Agents (+6 Hooks), Folge-Referenzen auf gestrichene Skills (quality-gate, retrospective, research-pipeline, wiki-query, Perplexity) bereinigt, Test-Zählung auf v4.0.x. Historien-Abschnitte unangetastet, Nachtrag im v4.0.1-Block. Vorab per git status verifiziert: vermeintlicher uncommitted Drift war schon committet (6c8a74a) — Buchhaltungs-Lag, kein echter Drift (G-pattern-005-Bestätigung).
- **Confidence:** 5/5
- **Tests:** not applicable
