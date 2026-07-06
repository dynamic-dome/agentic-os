# Learnings

*Auto-generated from learnings.json — do not edit directly.*

## L1 (2026-04-30) — importance 5/5 [long-term]

Python's Default-Encoding unter Windows ist cp1252 — JSON-Dateien mit Umlauten oder UTF-8-Sonderzeichen werden faelschlich als korrupt markiert wenn man `open(path)` ohne `encoding='utf-8'` aufruft. Sync-Skript haette intakte learnings.json mit 72 Eintraegen beinahe als .corrupt.bak weggeschoben. Konsequenz: Alle JSON-Reads in Maintenance-Skripten muessen explizit `encoding='utf-8'` setzen.

*Tags: windows, python, encoding, json, data-loss-risk, agentic-os*

## L2 (2026-04-30) — importance 4/5 [archive-candidate]

Cross-Project-Sync vergleicht aktuell nur Pattern-IDs, nicht Inhalt. Wenn zwei Projekte denselben Pattern unter verschiedenen IDs schreiben (z.B. `pattern-001` lokal vs. `windows-git-bash-compat` global), entstehen Duplikate. Pattern-Extractor erkennt sie ueber Jaccard-Description-Match (>=0.6) — sollte aber idealerweise bereits im sync-context-Skill passieren.

*Tags: agentic-os, sync-context, deduplication, patterns*

## L3 (2026-04-30) — importance 3/5 [archive-candidate]

obsidian-sync braucht `.agent-memory/config.json` als Pflicht-Voraussetzung. Wenn `/agentic-os:init` nie gelaufen ist, scheitert der erste Wiki-Sync still mit 'No wiki config found'. Minimum-Config (project_id, wiki_root, sync_enabled, project_aliases) kann manuell geschrieben werden — ist 5 Zeilen JSON.

*Tags: agentic-os, obsidian-sync, config, onboarding*

## L4 (2026-05-26) — importance 4/5 [short-term]

Agentic OS hat zwei divergierende Init-Pfade: der SessionStart-Hook (scripts/session-start.sh, realer Init seit /init-Ersatz) erzeugte WENIGER Dateien als commands/init.md — konkret fehlten learnings/learnings.json, context/open-tasks.json und working/current-session.json. Folge: wrap-up-Dedup/Scoring, bootstrap-Salience und der SessionEnd-Task-Guard liefen ins Leere, Working-Memory war toter Code. Fix: fehlende Dateien im Auto-Init PLUS idempotenter Phase-2-Backfill (heilt Bestandsprojekte beim naechsten Start). Lehre: Wenn ein Hook einen Command als Init-Pfad ersetzt, muessen beide dieselbe Dateimenge produzieren — sonst brechen alle Konsumenten still.

*Tags: agentic-os, session-flow, hooks, init, session-start, wrap-up*

## L5 (2026-06-01) — importance 4/5 [short-term]

Das installierte Agentic-OS-Plugin laeuft aus einer Cache-Kopie unter ~/.claude/plugins/cache/agentic-os-marketplace/agentic-os/<version>/ — das ist KEIN Git-Repo (git remote -v -> fatal) und vom Repo-Source (~/Desktop/Claude-Plugins-Skills/agentic-os-plugin/) getrennt. Folge: Edits am Repo wirken NICHT in der laufenden Session, bis ein Plugin-Update den Cache neu zieht. Bei dringenden Fixes beide Stellen editieren: autoritativ im Repo committen UND identisch in die versionierte Cache-Kopie spiegeln, damit der Fix sofort greift. FALLSTRICK Cache-Ordnername (verifiziert 2026-06-01): das manuelle Spiegeln ueberschreibt zwar die DATEIEN inkl. plugin.json (Inhalt = z.B. 3.2.3), aber der CACHE-ORDNERNAME bleibt auf der alten Versionsnummer (z.B. .../agentic-os/3.1.6/) — er wird NICHT mitumbenannt. installed_plugins.json zeigt weiter auf den alten Pfadnamen. Konsequenz: Wer nach einem /3.2.3/-Ordner sucht, findet nichts und schliesst faelschlich 'Cache nicht gespiegelt'. Ground-Truth ist die plugin.json IM Ordner (version-Feld) + ein byte-diff Repo<->Cache der Kerndateien, NICHT der Ordnername. Genau dieser Trugschluss (P006/L6: Pfad-Claim aus Handoff blind vertraut) drohte beim 3.2.3-Verify. ERWEITERUNG 2026-06-03: Der Ordnername-Fallstrick gilt NUR fuers manuelle Datei-Spiegeln. Ein echtes `claude plugin marketplace update <mp>` + `claude plugin update <plugin>@<mp>` legt einen KORREKT benannten neuen Versions-Ordner an (verifiziert: nach 3.2.5->3.3.1-Update existierte ein frischer .../agentic-os/3.3.1/-Ordner mit plugin.json version 3.3.1, neben den Alt-Ordnern 3.1.6/ [Inhalt 3.2.3, manuelle Leiche] und 3.2.5/). `plugin list` zeigte 3.3.1, Cache-plugin.json zeigte 3.3.1 — beide konsistent. Lehre: Marketplace-Update ist sauber (Ordnername=Inhalt), manuelles Spiegeln ist der unsaubere Pfad. Trotzdem nach jedem Update Ground-Truth via plugin.json-version IM Cache-Ordner pruefen, nicht nur dem CLI-Erfolgstext trauen. Restart noetig, damit die laufende Session den neuen Cache laedt.

*Tags: agentic-os, plugin, cache, marketplace, deployment, windows, verification, ground-truth*

## L6 (2026-06-01) — importance 4/5 [short-term]

Cross-Project-Handoff war Lese-/Schreib-asymmetrisch: session-bootstrap Step 0.5 LAS einen vollen 'wer/was/offen'-Handoff, aber wrap-up Step 7.6 SCHRIEB nur eine Sharepoint-Statuszeile — der erwartete Handoff entstand nie deterministisch. Zusaetzlich zeigte Commit 1a9c547 beide Seiten auf den nicht-existenten Pfad ~/AI/session-summary.md, waehrend die reale Datei laut SESSION-WORKFLOW.md unter ~/AI/.agent-memory/session-summary.md liegt. Lehre: Bei jedem Read/Write-Paar pruefen, dass die Schreib-Seite wirklich das Format/den Pfad produziert, den die Lese-Seite erwartet — und Pfad-Claims aus Commit-Messages gegen die maszgebliche Spec (hier: Verfassungs-Dokument) verifizieren, nicht der Message trauen.

*Tags: agentic-os, session-bootstrap, wrap-up, handoff, read-write-symmetry, verification*

## L7 (2026-06-01) — importance 3/5 [short-term]

Zielkonflikt Plugin-Konvention vs. externe Spec: ein Test erzwang englische Section-Header in ALLEN wrap-up-Templates, aber der zentrale Handoff MUSS deutschen SESSION-WORKFLOW.md-Headern folgen (die Verfassung verbietet eigene Handoff-Formate, §4.3). Richtige Loesung war NICHT das korrekte Template zu verbiegen, sondern den Test zu verschaerfen (nur das LOKALE Step-5-Template pruefen, zentralen Handoff per awk-Split ausnehmen). Lehre: Wenn ein Test eine global-richtige Konvention erzwingt, eine hoeher-prioritaere externe Spec aber lokal das Gegenteil verlangt, den Test praeziser scopen — nicht die Spec-konforme Stelle anpassen.

*Tags: agentic-os, testing, session-workflow, conventions, priority-conflict*

## L8 (2026-06-01) — importance 4/5 [short-term]

Doppel-Definitionen sind Driftquellen, die nur ein Test dauerhaft schliesst. Das .agent-memory/-Schema war in session-start.sh UND init.md definiert (L4-Drift 2026-05-26). Loesung: EINE sourcebare Bash-SSoT (scripts/mem-schema.sh) mit create_memory_structure(), die Hook UND /init konsumieren — plus ein NEGATIVER Drift-Test, der inline Schema-Writes ausserhalb der SSoT faengt. Aber: Refactor war zunaechst nur halb durchgezogen (Init nutzte SSoT, aber Fallback/Backfill/project-context.md duplizierten weiter Fragmente) — Codex-Verifier fand 5 MAJOR. Lehre: Beim Extrahieren einer SSoT ALLE Konsumpfade umstellen (Init, Backfill, Fallback), nicht nur den offensichtlichen; und den negativen Drift-Test in BEIDE Richtungen verifizieren (gruen bei sauber, rot bei injiziertem Leak).

*Tags: agentic-os, single-source-of-truth, drift, session-start, init, testing, refactor*

## L9 (2026-06-01) — importance 4/5 [short-term]

Cache-vs-Source-of-Truth nur einfuehren, wenn ALLE Schreiber der Cache-Seite die SoT respektieren — sonst driftet sie still weiter. project-context.md driftete (nannte 2026-04-30 geloeschte Agents), weil es eine eigenstaendige Quelle war, die niemand pflegte. Fix: docs/ (Regel-13-Skelett) wird SoT, project-context.md wird Cache. ABER Codex fand: context-detective UND /init schrieben den Cache weiter OHNE die Docs zu lesen, und eine vorbestehende plugin-documentation.md (v2-Stand) widersprach den neuen Docs. Lehre: Bei Cache/SoT-Trennung (a) JEDEN Cache-Schreiber auf 'SoT zuerst lesen' umstellen, (b) konkurrierende Alt-Doku entfernen/markieren, (c) einen Test ergaenzen, der erzwingt dass alle Schreiber die SoT referenzieren — sonst ist das SoT-Versprechen wertlos.

*Tags: agentic-os, context-keeper, source-of-truth, documentation, drift, regel-13, verification*

## L10 (2026-06-02) — importance 4/5 [short-term]

'Alles gepusht' im session-summary/Handoff ist KEIN Beweis, dass der Remote synchron ist. 2026-06-02 meldete der Handoff fuer agentic-os-plugin 'alle gepusht', aber `git log origin/main..main` zeigte 6 ungepushte Commits (origin stand auf 1a9c547, lokal auf 4717b8e) — der vorige Push war nie passiert oder schlug still fehl. Erst der Push `1a9c547..d9369f2` brachte sie hoch. Konkrete Anti-Pattern-Quelle: ein kombinierter Bash-Befehl, der read-only-Inspektion UND `git push` mischt, wurde vom Permission-Layer als Ganzes abgelehnt — Push muss als isolierter Befehl laufen (sonst blockiert die Ablehnung auch die harmlosen Teile, und es ist unklar ob gepusht wurde). Lehre (verlaengert L6/P006): Push-Claims aus Handoffs IMMER gegen `git log origin/<branch>..<branch>` verifizieren, nicht der Buchhaltung trauen; und `git push` nie mit read-Befehlen in einer Bash-Zeile buendeln.

*Tags: agentic-os, git, push, verification, handoff, ground-truth, bash-permission*

## L11 (2026-06-03) — importance 5/5 [short-term]

Marker-basierte Drift-Tests (grep auf SKILL.md-Body) sind nur dann echte Tests, wenn man sie bidirektional gegenprueft: strip die Haertung -> Test MUSS rot werden, restore -> gruen. Mehrfach in dieser Session blieb ein Test faelschlich gruen nach dem Strip, weil seine grep-Alternation (`a|b|c`) noch von UNVERWANDTEM Text in derselben Datei getroffen wurde (z.B. trust-boundary-Test matchte 'NotebookLM' aus einem voellig anderen Step-7-Sync-Abschnitt; recency-Test matchte 'pause'/'runtime' aus Nachbarregeln). Codex-Verifier fand dieselbe Klasse als 3 MAJOR ('Test pinnt das Konzept, aber nicht jede Spec-Zusage'). Fix-Muster: (a) jeden Hebel mit einem EINDEUTIGEN Marker im Body verankern `(lever-N)`/`(trust-boundary)`/`(pattern-schema-canon)`, (b) den Test an diesen Marker UND eine konzept-spezifische Phrase binden, (c) bei datei-weiten Vorkommen den Marker-BLOCK isolieren (`grep -A2 marker`), nicht die ganze Datei greppen. Lehre: ein gruener marker-Test beweist nichts ohne die strip->FAIL-Gegenprobe.

*Tags: agentic-os, testing, drift-test, tdd, grep, verification, false-green, codex-review*

## L12 (2026-06-03) — importance 4/5 [short-term]

Ein externes Audit/Dossier kann den CODE-Stand korrekt zitieren (hier: commit 02562a52) und trotzdem einen VERALTETEN Daten-Stand gemessen haben. Das Memory-Audit las einen alten Clone von .agent-memory/ (3 statt 10 learnings, 55 statt 80 Iterationen) und leitete daraus zwei 'Hoch'-Gaps ab (Layer-Rot, learnings-nie-promoted), die sich bei Ground-Truth-Pruefung in Luft aufloesten (wrap-up Layer-Promotion existiert und lief). Lehre (verlaengert P006/L10): Bevor man die Empfehlungen eines fremden Reports umsetzt, die zentralen Mess-Claims gegen die LIVE-Dateien gegenpruefen, nicht gegen den vom Report behaupteten Zustand. Konkretes Gegenmittel gebaut: /memory-audit-Command (read-only), der den Ist-Zustand jederzeit frisch misst — damit kann genau dieser Fehler nie wieder unbemerkt durchgehen. Severity-Einstufungen aus fremden Reports sind besonders verdaechtig, weil sie auf der (potenziell veralteten) Daten-Messung beruhen.

*Tags: agentic-os, audit, ground-truth, verification, stale-data, memory-audit, external-report*

## L13 (2026-06-03) — importance 5/5 [short-term]

Plugin-Skill-Logik mit harten Invarianten (Privacy-Filter, Promotion-Gate, Decay-Floor, nie-Loeschen) gehoert in ein sourcebares Skript (scripts/global-schema.sh) mit ECHTEN Unit-Tests, NICHT nur in den SKILL.md-Prompt-Text. Begruendung (Hybrid-Architektur 4.A): Ein Prompt-beschriebener Mechanismus ist nur so verlaesslich wie der Agent, der ihn im Moment interpretiert — bei Daten-Integritaet/Datenschutz zu schwach. Eine Funktion is_denied(['api_key'])==denied ist bidirektional beweisbar (strip Deny-Array -> Leak -> Test FAILt); ein grep auf 'MEM_GLOBAL_DENY_TAGS im Prompt' beweist nichts (L11). Trennung: pure testbare Funktionen ins Skript, Orchestrierung/Entscheidung bleibt im Prompt (Skills SIND Prompts). Diese Session live demonstriert: beim manuellen Sync musste ich die Dedup/Provenance-Logik ohnehin ad-hoc in Python schreiben — also gleich getestet im Skript verankern.

*Tags: agentic-os, architecture, hybrid, testing, skill-vs-script, invariants, global-memory, tdd*

## L14 (2026-06-03) — importance 5/5 [short-term]

Eine Schema-Migration, die Bestands-Daten mit einem Default-Wert backfillt, muss die SPAETER eingefuehrte Validierungs-Regel SCHON beim Backfill anwenden — sonst erzeugt sie Eintraege, die die eigene Regel verletzen. 4.A: die Migration stempelte alle 44 Alt-Eintraege lifecycle:'active' (Default), aber das Promotion-Gate verlangt fuer 'active' |source_projects|>=2 -> 35 sofortige 'promotion-gate violations' (3 Patterns + alle 32 Learnings mit 1 Projekt). Gefangen NICHT von Tests, sondern vom ersten LIVE-Lauf des neuen /memory-audit GLOBAL-View — das Tool zeigte beim Debuet auf den eigenen Migrations-Default. Fix: lifecycle = passes_promotion_gate(...) ? active : candidate beim Backfill, Re-Apply aus den *.4A.bak-Originalen. Lehre: Migrations-Default und nachgelagerte Invariante muessen konsistent sein; ein read-only Audit-Tool gegen die Live-Daten ist die beste Versicherung gegen genau solche selbst erzeugten Inkonsistenzen (verlaengert L12).

*Tags: agentic-os, migration, schema, invariant-consistency, memory-audit, ground-truth, global-memory, verification*

## L15 (2026-06-03) — importance 4/5 [short-term]

Der Codex-Verifier (Regel 9, Agent 1) laeuft in einer policy-restringierten Sandbox, die `bash tests/run-all.sh` und dynamische Marker-strip-Checks BLOCKEN kann -> er gibt dann ein PROZEDURALES 'VERDICT: rejected' (nicht weil er einen Bug fand, sondern weil ihm Laufzeit-Evidenz fehlt). Das ist KEIN echter Reject. Richtiger Umgang: (a) den prozeduralen Blocker erfuellen, indem das Main-Model die Laufzeit-Evidenz selbst liefert (Suite-Lauf + Marker-strip-Stichprobe pro Kategorie: strip->rot, restore->gruen), (b) die ECHTEN statischen Funde des Verifiers trotzdem ernst nehmen — hier ein berechtigter MINOR (Doku-Test-Count 14 statt 16 nach einem spaeteren Fix-Commit). Lehre: Codex-'rejected' immer danach klassifizieren, ob es prozedural (Sandbox-Limit) oder substanziell (echter Spec-Bruch) ist; nur letzteres blockiert. Wiederholter Befund (mehrere Sessions).

*Tags: agentic-os, codex-review, verifier, sandbox, false-reject, verification, workflow*

## L16 (2026-06-04) — importance 4/5 [short-term]

Das 4.A-Promotion-Gate ist FERTIG, getestet (16/16) und LIVE aktiv — nicht 'wartend'. Live-Stand am 2026-06-04: 3 globale Patterns active (G-005/009/012, alle erfuellen conf>=0.6 & occ>=3 & >=2 Projekte), 9 candidate, JEDER scheitert nachvollziehbar an einer konkreten Bedingung (meist occ<3). Der wiederholte Handoff-Satz 'Gate wartet auf 2. cross-project-Push' war IRREFUEHREND: das Gate hat bereits geschaltet (Migration L14 + fruehere Syncs), und es wartet nicht auf einen Schalt-AKT, sondern auf echte EVIDENZ (ein Pattern, das real in >=2 Projekten >=3x auftritt) — die entsteht durch normale Projektarbeit, nicht durch manuelles Eingreifen. KRITISCH: G-010/G-011 haben conf>=0.6 & >=2 Projekte, scheitern nur an occ=1; sie zu promoten haette occurrences (ein Evidenz-Zaehler) von 1 auf 3 faelschen muessen — abgelehnt, weil das genau die Integritaet zerstoert, die das Gate schuetzt. Lehre (verlaengert L12/L14): Bevor man einen 'offenen Thread' aus einem Handoff abarbeitet, gegen die Live-Daten pruefen, ob er ueberhaupt noch offen IST — hier war das Feature fertig und der vermeintliche Rest waere Daten-Faelschung gewesen. 'Wartet auf X' in einem Handoff praezise formulieren: wartet es auf eine Aktion oder auf einen natuerlichen Daten-Zustand?

*Tags: agentic-os, global-memory, promotion-gate, ground-truth, verification, data-integrity, handoff*

## L17 (2026-06-12) — importance 3/5 [short-term] [superseded by L18]

Wenn ein Slash-Command und ein Skill denselben Namen tragen (wrap-up: commands/wrap-up.md delegiert an skills/wrap-up/SKILL.md), kann das Skill-Tool in einen Loop geraten: der Aufruf 'agentic-os:wrap-up' liefert den COMMAND-Wrapper zurueck (der wiederum 'invoke the skill' sagt) statt des Skill-Bodys — beobachtet 2026-06-12, zwei identische Versuche, dann manueller spec-treuer Lauf als Fallback. Konsequenz: bei gleichnamigen Command/Skill-Paaren pruefen, was das Skill-Tool tatsaechlich laedt; ggf. Command-Wrapper umbenennen oder den Skill-Body direkt ausfuehren. Der Wrapper-Indirektion-Nutzen (Argument-Doku) ist gegen das Loop-Risiko abzuwaegen.

*Tags: agentic-os, plugin, skill-tool, commands, naming-collision*

## L18 (2026-06-12) — importance 3/5 [short-term]

Aufloesung von L17 (Command/Skill-Namensschatten): Der Skill-Tool-Namespace mergt Commands und Skills; bei Namensgleichheit gewinnt der COMMAND — ein delegierender Wrapper ('invoke the skill') wird damit zur Endlos-Indirektion. Der richtige Fix ist LOESCHEN, nicht Umbenennen: Skills sind direkt slash-invocierbar (ground-truth: /agentic-os:session-bootstrap lief ohne Command-Wrapper), also bleibt die UX identisch und der Schatten verschwindet statt sich zu verschieben. Umgesetzt in v3.5.1 (commands/wrap-up.md + commands/quality-gate.md geloescht, 12->10 Commands) mit Guard-Test in validate-plugin.sh (kein commands/<name>.md darf skills/<name>/ spiegeln; TDD bidirektional rot/gruen). WICHTIG fuers Deployment-Fenster: bis zum Session-Restart liefert der ALTE Cache den Wrapper weiter aus — /agentic-os:wrap-up lief in der laufenden 3.5.0-Instanz erneut in den Wrapper; Fallback ist, den Skill-Body aus dem Repo zu lesen und manuell spec-treu auszufuehren.

*Tags: agentic-os, plugin, skill-tool, commands, naming-collision, deployment, cache*

## L19 (2026-06-12) — importance 4/5 [short-term]

Skill-Coverage gegen den ECHTEN minimalen User-Workflow messen, nicht gegen die Feature-Liste. Der reale Workflow war die Zwei-Aufruf-Klammer (bootstrap am Start, wrap-up am Ende, sonst nichts) — damit hing die komplette Kette iteration-logger -> pattern-extractor -> skill-generator an manuellen /log-Aufrufen, die nie kamen: nach Monaten standen 5 Iterationen, 3 Errors und Quality-Score null im Store, obwohl die Skills alle existierten und getestet waren. Ein Skill ohne realen Aufrufpfad ist toter Code mit gruener Testsuite. Gegenmittel (v3.6.0): die Klammer selbstversorgend machen — wrap-up Step 1.5 (session-harvest) rekonstruiert ungeloggte Iterationen und delegiert an iteration-logger, Step 4.5 (decision-scan) delegiert erkannte Entscheidungen an context-keeper; Schreibrechte bleiben bei den Owner-Skills. Bewusst NICHT in die Klammer: quality-gate (teuer), sync-context/self-improve (policy-gated), research/wiki-query (reaktiv). Live-Daten des eigenen Stores sind der billigste Coverage-Detektor: leere Zaehler nach Monaten = ein Pfad, der nie feuert.

*Tags: agentic-os, workflow, coverage, wrap-up, iteration-logger, dead-path, design*

## L20 (2026-07-06) — importance 3/5 [short-term]

Anker-Tests als Semantik-Waechter: validate-skills pinnt parenthesierte Marker ((user-growth), (trust-boundary), (wiki-sync-visible) ...) plus Schluesselphrasen im selben Grep-Fenster. Bei jedem Skill-Rewrite ZUERST tests/ nach dem Skill-Namen greppen und die Marker mitfuehren — sonst reisst die Suite trotz intaktem Verhalten (8 FAILs beim wrap-up-Rewrite, alle Marker-Misses).

*Tags: testing, skills, refactor, agentic-os*

## L21 (2026-07-06) — importance 4/5 [short-term]

Description-Frontmatter aller Skills/Commands/Agents ist PERMANENTER System-Prompt-Ballast in jeder Session jedes Projekts (~2.170 Tokens bei 28 Eintraegen, gemessen); Skill-BODIES laden lazy, Descriptions nicht. Konsequenz: Descriptions <=60 Woerter, keine <example>-Bloecke, Trigger auf 5-6 Kernphrasen.

*Tags: tokens, efficiency, plugin, agentic-os*

## L22 (2026-07-06) — importance 4/5 [short-term]

Eine Memory-Pipeline stirbt multiplikativ, nicht an einer Stelle: skip-erlaubte Steps x enqueue-only-Queues x unerfuellbare Schwellen x fehlende Laufzeit-Injektion — jede Stufe wirkt einzeln 'fast ok', das Produkt ist ~0 (Identity-Wachstum: 1 soul-Kandidat in 3,5 Monaten). Gegenmittel: Pflicht-Statuszeile (visible-Muster), Full-Queue-Re-Review, Checklisten statt vager Scans, Starvation-Selbstanzeige im Bootstrap.

*Tags: memory, identity, design, agentic-os*
