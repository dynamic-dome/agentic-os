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

## 2026-07-15 — docs: Design + Implementierungsplan Modell-Routing v4.7.0 (Session-Harvest)
- **Type:** docs
- **Tags:** model-routing, brainstorming, writing-plans, spec-konsolidierung
- **Files changed:** docs/superpowers/specs/2026-07-15-model-routing-design.md, docs/superpowers/plans/2026-07-15-model-routing.md
- **Summary:** GPT-5.6-Spec (memospartoken.md) gegen realen Bestand konsolidiert (7 dokumentierte Abweichungen, u.a. kein Code-Router, Sonnet statt Haiku, kein Live-Shadow), Design in 3 freigegebenen Abschnitten, Plan mit 7 TDD-Tasks und vollstaendigem Soll-Code. Commits a215de8, b0e1014, fa94da0.
- **Confidence:** 5/5
- **Tests:** not applicable

## 2026-07-15 — feature: Routing-Kern — Modellklassen-SSoT + Frontmatter (Session-Harvest)
- **Type:** feature
- **Tags:** model-routing, ssot, frontmatter, validate-skills
- **Files changed:** scripts/model-routing.sh, tests/test-model-routing.sh, tests/validate-skills.sh, skills/{wrap-up,session-bootstrap,memory-maintenance,iteration-logger,sync-context,obsidian-sync}/SKILL.md, agents/{context-detective,research-agent}.md
- **Summary:** model-routing.sh als Modellklassen-SSoT (TSV list/list-agents), model: sonnet + effort-Frontmatter in 6 Routine-Skills + effort in 2 Agents, bidirektionaler Konsistenztest (Frontmatter<->SSoT und Datei<->Row). Commits bbc20e0, 91fcb6f.
- **Confidence:** 5/5
- **Tests:** passed (Suite gruen)

## 2026-07-15 — feature: Stufe-0-Preprocessor + Kostentrace mit 4 Review-Fixes (Session-Harvest)
- **Type:** feature
- **Tags:** model-routing, preprocess, cost-trace, fail-soft, tdd, windows
- **Files changed:** scripts/preprocess_state.py, scripts/cost-trace.sh, tests/test-preprocess-state.py, tests/test-cost-trace.sh, tests/run-all.sh
- **Summary:** Deterministisches Stufe-0-Zustandsobjekt (8-Key-JSON, Hash-Fast-Path-Grundlage) + append-only JSONL-Kostentrace. Reviews fanden 4 echte Fail-soft-Bugs (err-005..err-007), alle mit Regressionstests gefixt (29/29, 19/19). Commits 9888bf2, 445add7, 8e829d1, ca960ee, a92e6e5.
- **Confidence:** 5/5
- **Tests:** passed (29/29 + 19/19, Suite gruen)
- **Errors:** err-005, err-006, err-007

## 2026-07-15 — feature: Skill-Verdrahtung wrap-up + session-bootstrap (Session-Harvest)
- **Type:** feature
- **Tags:** model-routing, wrap-up, session-bootstrap, escalation, context-diet
- **Files changed:** skills/wrap-up/SKILL.md, skills/session-bootstrap/SKILL.md, tests/validate-skills.sh
- **Summary:** wrap-up: Step-0-Preflight, (context-diet), (delta-update), (escalation-rules), (cost-trace); session-bootstrap: Hash-Fast-Path, Eskalation, Trace — alle Marker mit Struktur-Assertions (TDD). Plan-Anker "## Handoff Context" lag in einem Template-Fence, Platzierung begruendet abgewichen (Review approved). Commits c17cb49, 42bb9e9.
- **Confidence:** 5/5
- **Tests:** passed (143/143 validate-skills, Suite gruen)

## 2026-07-15 — config: Release v4.7.0 + Final-Review-Fixes + Codex-VERIFIED (Session-Harvest)
- **Type:** config
- **Tags:** release, model-routing, codex-verifier, utf-8, windows
- **Files changed:** docs/model-routing-eval-checklist.md, CLAUDE.md, .claude-plugin/plugin.json, docs/superpowers/specs/2026-07-15-model-routing-design.md, scripts/preprocess_state.py, tests/*
- **Summary:** Eval-Checkliste E1-E5, Model-Routing-Policy-Bullet, Versions-Bump 4.6.1->4.7.0. Final-Whole-Branch-Review fand cp1252-stdout-Crash (err-008) + JSON-Literal-Typo + einseitige Drift-Checks — alle gefixt. Codex-Verifier: VERIFIED (alle 7 Kern-Behauptungen PASS). Push durch User, Plugin-Update auf 4.7.0. Commits a691994, e2a454c.
- **Confidence:** 5/5
- **Tests:** passed (Suite komplett, Controller-ground-truth-verifiziert)
- **Errors:** err-008

## 2026-07-27 — fix: skill `model:`-Frontmatter als gemessener No-Op dokumentiert (Session-Harvest, recovered from session 587b9ab4)
- **Type:** bugfix
- **Tags:** model-routing, docs-drift, measurement, claude-code, ground-truth
- **Files changed:** scripts/model-routing.sh, CLAUDE.md, docs/model-routing-eval-checklist.md, docs/superpowers/specs/2026-07-15-model-routing-design.md, tests/validate-skills.sh
- **Summary:** Transkript-Probe (Claude Code 2.1.215/2.1.220) zeigt: beim Skill-Aufruf via Skill-Tool bleibt das Session-Modell aktiv — das `model:`-Frontmatter wirkt NICHT. Statt die Frontmatter zu entfernen wurde der No-Op an der SSoT (scripts/model-routing.sh Header) + CLAUDE.md + Eval-Checkliste (E0-Probe) dokumentiert, inkl. der Einsicht, dass der Konsistenztest den No-Op konstruktionsbedingt nicht sehen kann. Commit b3c802d.
- **Confidence:** 5/5
- **Tests:** passed (Suite gruen)

## 2026-07-27 — feature: wrap-up Batch-Writer scripts/apply_wrapup.py + Trust-Boundary-Fix (Session-Harvest, recovered from session 587b9ab4)
- **Type:** feature
- **Tags:** wrap-up, batch-writer, trust-boundary, identity, tdd, python
- **Files changed:** scripts/apply_wrapup.py, tests/test-apply-wrapup.py, tests/run-all.sh, skills/wrap-up/SKILL.md, skills/wrap-up/references/wrapup-schemas.md
- **Summary:** Alle Datei-Mutationen des wrap-up laufen jetzt ueber EINEN Schreibplan -> ein Skript-Pass mit gemessenem Tally (statt ein Write/Edit-Turn pro Datei). Das Skript besitzt die deterministischen Regeln (ID-Vergabe, Dedup, Promotion-Gate, Changelog-vor-Edit, learnings.md-Regeneration, Marker, Dirty-Flags) und ueberspringt den Marker bei jedem Fehler. Review fand einen Trust-Boundary-Bypass: die Full-Queue-Re-Review promotete Alt-Kandidaten ohne `trust_source: conversation` — Grenze jetzt auch auf dem Promotion-Pfad erzwungen. 55 Tests. Commits a698707, 2c29b62.
- **Confidence:** 5/5
- **Tests:** passed (55/55, Suite gruen)
- **Errors:** err-009

## 2026-07-27 — config: Kosten-Zahlen korrigiert (2.77x Zaehlfehler) + Release 4.16.0 (Session-Harvest, recovered from session 587b9ab4)
- **Type:** config
- **Tags:** release, cost-analysis, measurement, transcript, docs
- **Files changed:** docs/superpowers/specs/2026-07-15-model-routing-design.md, scripts/apply_wrapup.py, skills/wrap-up/SKILL.md, skills/wrap-up/references/wrapup-schemas.md, CLAUDE.md, .claude-plugin/plugin.json
- **Summary:** Die Zahlen, die den Batch-Writer begruendeten, waren um 2.77x aufgeblaeht: `usage` wird pro API-Response berichtet, das Transkript schreibt aber einen Record pro Content-Block (text/thinking/tool_use) mit demselben usage-Objekt. Korrigiert per Dedup auf `message.id`: 28 API-Calls statt 70 Turns, $15.50 statt $42.87 — Richtung (94% Kontext-Transport) haelt, die erwartete Ersparnis schrumpft. Danach Versions-Bump 4.15.0 -> 4.16.0 und beide Konventionen (wrap-up-Schreibpfad, Kosten-Reasoning) in CLAUDE.md verankert. Commits a735be2, 9cd82c9.
- **Confidence:** 5/5
- **Tests:** passed (Suite gruen)
- **Errors:** err-010

## 2026-07-27 — feature: Gemessene Session-Kosten statt Schaetzungen (measure_session_cost.py, 4.17.0)
- **Type:** feature
- **Tags:** cost-analysis, measurement, prompt-cache, tdd, python, metrics
- **Files changed:** scripts/measure_session_cost.py, tests/test-measure-session-cost.py, tests/run-all.sh, scripts/cost-trace.sh, .claude-plugin/plugin.json
- **Summary:** cost-trace.sh schrieb Schaetzungen (context_bytes/4); ein realer Lauf tracete 96k Bytes bei tatsaechlich 6,6M transportierten Kontext-Tokens — keine Ungenauigkeit, sondern eine andere Einheit. Neues Skript liest das Transkript, dedupliziert auf message.id (err-010-Regression) und meldet cache_creation-Events einzeln statt sie wegzumitteln. TDD: 14 Tests rot -> gruen, Randfall-Matrix nach P011 (fehlende/leere/kaputte Eingabe, --help-stdout-Reinheit, Trailing-Flag, Non-ASCII, fail-soft Trace-Write). Gegenprobe am echten Transkript reproduziert die Handmessung exakt. Commit 56513c2.
- **Confidence:** 5/5
- **Tests:** passed (14/14 neu, volle Suite gruen)

## 2026-07-27 — refactor: Kostenhebel neu bestimmt — D-005 supersediert, Trigger empirisch identifiziert
- **Type:** refactor
- **Tags:** cost-analysis, model-routing, decision, measurement, prompt-cache
- **Files changed:** .agent-memory/context/decisions.json, .agent-memory/context/open-tasks.json, .agent-memory/learnings/learnings.json
- **Summary:** D-005 (deklaratives Modell-Routing) auf superseded, D-010 angelegt: die Modellklasse ist kein Kostenhebel (opus $15.50/28 Calls vs sonnet $15.16/66 Calls). Erste Hypothese (Skill-Delegationsketten) war nach einer Auswertung PRO SESSION scheinbar widerlegt — eine Session mit 0 Skills hatte 5 Rewrites. Erst die Normalisierung auf GELEGENHEITEN ueber 7 Transkripte/~1300 Calls zeigte den Effekt: Skill 41% (9/22), ToolSearch 26% (5/19) gegen Bash 0,5% (3/618) und Edit 0% (0/233). TTL-Confound widerlegt (5 von 6 Rewrites nach Pausen <60s). L34 haelt Befund UND Methodenfehler fest. Commit c5d4d84.
- **Confidence:** 4/5
- **Tests:** n/a (Analyse, kein Produktionscode)

## 2026-07-27 — feature: Delegations-Umbau T-015: 3 Skill-Injektionen durch Skripte ersetzt (4.18.0) (recovered from session 814b8dd0)
- **Type:** feature
- **Tags:** wrap-up, cost-analysis, refactor, python, delegation
- **Files changed:** scripts/apply_wrapup.py, scripts/extract_patterns.py, tests/test-apply-wrapup.py, tests/test-extract-patterns.py, tests/validate-plugin.sh, skills/wrap-up/SKILL.md, skills/iteration-logger/SKILL.md, skills/context-keeper/SKILL.md, skills/pattern-extractor/SKILL.md, skills/DEPENDENCIES.md, CLAUDE.md
- **Summary:** Konsequenz aus L34/D-010 (Skill-Aufruf = 41% Prefix-Rewrite): wrap-up ruft iteration-logger/context-keeper/pattern-extractor auf dem Routinepfad nicht mehr auf. apply_wrapup.py bekam die Plan-Sektionen iterations+decisions (ID-Fortschreibung im On-Disk-Format, Recurrence-Regel, Append-only, Supersede-Flip); extract_patterns.py (neu) uebernimmt Detektion/Confidence/Jaccard/patterns.md, --apply nimmt nur Sprache, Zahlen kommen aus der Messung. Ownership verschoben statt aufgeweicht (APPLIER_OWNED). validate-plugin.sh: Delegations-Budget-Test ersetzt den false-green Vorgaenger-Grep. DoD erfuellt: deklarierte Invokes 5->3, typischer Lauf 4->1. Commit 1e5c504.
- **Confidence:** 5/5
- **Tests:** passed (apply-wrapup 55->90, extract-patterns 49 neu, Suite gruen)

## 2026-07-27 — bugfix: Codex-Verifier-Befunde zum Delegations-Umbau behoben (14 Befunde, Verdikt rejected) (recovered from session 814b8dd0)
- **Type:** bugfix
- **Tags:** wrap-up, code-review, idempotency, security, python
- **Files changed:** scripts/apply_wrapup.py, tests/test-apply-wrapup.py, scripts/extract_patterns.py
- **Summary:** Review von 1e5c504 war 'rejected' mit 14 Befunden; 2 selbst reproduziert vor Uebernahme, 1 entstand erst durch den Fix und wurde vom Smoke-Lauf gegen eine Store-Kopie gefunden. Kern: (a) Header-Dedup lief NACH der Fehlerverarbeitung - wiederholter Plan zaehlte denselben Fehler jedes Mal als Recurrence (occurrences 2->3->4); (b) Decision-Identitaet jetzt (title, supersedes) statt Titel-only; (c) validate_plan prueft alle Pflichtfelder vorab, sonst hinterliess ein spaet scheiternder Plan ein halb geschriebenes iteration-log; (d) canon(): 'iterations/../iterations/errors.json' passierte den Ownership-Check. Commit af647fc.
- **Confidence:** 5/5
- **Tests:** passed (Suite gruen nach Fix)
- **Errors:** err-011

## 2026-07-27 — bugfix: T-014 Projektlabel-Fix + T-017 ToolSearch-Buendelung verankert (4.18.1)
- **Type:** bugfix
- **Tags:** bridge, cost-analysis, python, skill-doc
- **Files changed:** scripts/bridge_projection.py, tests/test-bridge-projection.py, skills/session-bootstrap/SKILL.md, .claude-plugin/plugin.json
- **Summary:** bridge_projection.py schrieb '(membrain)' hart kodiert in jedes AGENTS.md - Label kommt jetzt aus config.json project_id mit Fallback Projektordner-Name, fail-soft, 2 Regressionstests (inkl. Fallback-Fall). session-bootstrap schreibt den Atlas-Tool-Load auf EXAKT EINEN ToolSearch-Call pro Lauf fest (26% Rewrite je Call, L34); wrap-up 3a.2 hatte die Regel schon. Live verifiziert: AGENTS.md traegt '(agentic-os-plugin)'. Commit c083663.
- **Confidence:** 5/5
- **Tests:** passed (bridge-Tests + volle Suite gruen)
- **Commits:** c083663

## 2026-07-27 — config: Kosten-Circuit-Breaker + Pattern-Starvation-Guard verankert (4.18.2)
- **Type:** config
- **Tags:** governance, cost-analysis, pattern-pipeline, skill-doc
- **Files changed:** skills/wrap-up/SKILL.md, .claude-plugin/plugin.json
- **Summary:** Bewertung des Delegations-Umbaus als Entscheidung festgehalten (D-012): Hauptgewinn ist Determinismus, Kostenersparnis ~$1.50-3/Lauf, Amortisation nach 10-15 Laeufen - weitere Mikro-Optimierung (T-018/T-021) beendet. Als Gegenmassnahme zum realen Informationsverlust (extract_patterns.py sieht nur die fehlerbasierte Haelfte, T-019) traegt wrap-up Step 4 jetzt den pattern-starvation-guard: ~5 Sessions mit Iterationen aber 0 neuen Patterns/Proposals -> einmal voller pattern-extractor-Lauf als bewusster Tiefenblick. T-020-Finalmessung: 48 Calls, $20.66, 4 Rewrites gegen Baseline 54/$25.10/6 bei deutlich groesserem Sessionumfang; Skill-Invokes im wrap-up-Lauf 1 statt 4 - DoD erfuellt.
- **Confidence:** 4/5
- **Tests:** passed (validate-plugin 159/159, validate-skills 154/154)

## Luecke 2026-07-16..2026-07-24 — bewusst als verloren markiert (T-012)

Die Sessions der Releases 4.8–4.15 (~20 Commits) haben nie ein wrap-up gefahren;
ihre Iterationen wurden nicht geloggt. Owner-Entscheid 2026-07-27: NICHT aus git log
rekonstruieren — Learnings/Decisions dieser Phase sind separat konsolidiert
(L-Eintraege, D-Records, CLAUDE.md), ein Nachtrag waere Buchhaltung ohne
Konversations-Ground-Truth. Konsequenz: Datei-Hotspot-Heuristiken (T-019) sehen
diese Commits nicht. Absichtlich kein Datums-Header — Parser ueberspringt den Block.

## 2026-07-27 — feature: T-013 bridge_status=candidate deterministisch in apply_wrapup.py (4.18.3)
- **Type:** feature
- **Tags:** wrap-up, bridge, trust-boundary, python, tdd
- **Files changed:** scripts/apply_wrapup.py, tests/test-apply-wrapup.py, skills/wrap-up/SKILL.md, skills/wrap-up/references/wrapup-schemas.md
- **Summary:** Step 3d.1 aus Prosa in den Applier verlegt: bridge_status wird aus importance>=4 abgeleitet, plan-gelieferte Werte verworfen (approved nur via [j/n]-Gate), tally.bridge_candidates liefert store-weite Kandidaten fuer die 3d.2-Promptzeile. Altbestand ohne Feld wird nie backfilled.
- **Confidence:** 5/5
- **Tests:** passed (115/115 test-apply-wrapup + volle Suite)
- **Commits:** cf9d23a

## 2026-07-27 — feature: T-016 gemessener Kostentrace am wrap-up-Ende via --locate
- **Type:** feature
- **Tags:** cost-analysis, python, wrap-up, tdd
- **Files changed:** scripts/measure_session_cost.py, tests/test-measure-session-cost.py, skills/wrap-up/SKILL.md, tests/validate-skills.sh
- **Summary:** measure_session_cost.py findet das eigene Transkript per --locate <session-id> (Ein-Ebenen-Glob unter ~/.claude/projects, juengste mtime bei Kollision, --projects-root fuer Tests). wrap-up (cost-trace) misst zuerst, cost-trace.sh-Schaetzung nur noch Fallback. validate-skills-Contract nachgezogen.
- **Confidence:** 5/5
- **Tests:** passed (18/18 + volle Suite)
- **Errors:** err-012
- **Commits:** a35461d

## 2026-07-27 — feature: T-019 strukturierte Iterations-Heuristiken in extract_patterns.py (4.18.4)
- **Type:** feature
- **Tags:** patterns, parser, python, heuristics, tdd
- **Files changed:** scripts/extract_patterns.py, tests/test-extract-patterns.py, skills/pattern-extractor/SKILL.md
- **Summary:** iteration-log.md-Parser (gepinntes 4.18.0-Renderformat, Prosa-Bloecke werden uebersprungen) + 3 Heuristiken: Datei-Hotspots (>=3 Iterationen), wiederholte erfolgreiche Ansaetze (best-practice), fragile Testbereiche (anti-pattern). Cold-Start-Guard zaehlt Iterationen mit (Starvation-Fix). Typ-Gate in match_existing: Ground-Truth-Probe zeigte 11 stille typfremde Merges, danach 0.
- **Confidence:** 5/5
- **Tests:** passed (77/77 + volle Suite)
- **Commits:** d9445fb

## 2026-07-27 — bugfix: Codex-Verifier-Fixrunde: 4 P0 + 2 P1 + BOM in den drei neuen Write-Paths
- **Type:** bugfix
- **Tags:** review, codex, parser, input-validation, tdd
- **Files changed:** scripts/extract_patterns.py, scripts/measure_session_cost.py, scripts/apply_wrapup.py, tests/test-extract-patterns.py, tests/test-measure-session-cost.py, tests/test-apply-wrapup.py
- **Summary:** Alle Befunde vor dem Fixen selbst reproduziert, dann TDD. Begruendet abgelehnt: type/severity bleiben plan-setzbar (Klassifikation ist Urteil, Typ-Gate schuetzt Merges). '0 failed'-Semantik, importance-Validierung vor erstem Write, utf-8-sig.
- **Confidence:** 5/5
- **Tests:** passed (82/82 + 117/117 + 20 + volle Suite)
- **Errors:** err-013, err-014
- **Commits:** 083d304
