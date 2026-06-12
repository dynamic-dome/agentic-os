# Handoff-Ownership Implementation Plan (lokale vs. globale Übergaben)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Next Steps leben genau einmal — projekt-lokal in `context/open-tasks.json` (SSoT); der zentrale Handoff stapelt pro Projekt nur noch EINEN Block und verweist statt zu kopieren. Damit verschwinden die 2–3-fachen Next-Step-Duplikate strukturell.

**Architecture:** Drei Ebenen mit Ownership-Prinzip: (1) Lokal `context/open-tasks.json` als Single Source of Truth für Next Steps, von wrap-up geschrieben, von session-bootstrap/Hooks gelesen. (2) Zentraler Handoff (`~/AI/.agent-memory/session-summary.md`) behält Prepend+Demote, bekommt aber Ownership-Dedup (max 1 Block pro Projekt) und eine Pointer-Sektion statt Next-Step-Vollkopie. (3) Status-Board und Sharepoint bleiben unverändert. Verfassung (SESSION-WORKFLOW.md) wird zuerst angepasst — mit User-Gate.

**Tech Stack:** Markdown-Skill-Prompts (SKILL.md), Bash-Marker-Tests (`tests/validate-skills.sh`, L11-Stil: strip→FAIL-verifiziert), Python für die Daten-Migration.

**Out of Scope (bewusst, YAGNI):** Claim-Semantik gegen Parallel-Session-Doppelzug (open-tasks-IDs machen das später möglich), Sharepoint-Format (7.6c), Status-Board-Format (7.6b — die eine `Next:`-Zeile ist Dashboard, keine Duplikatsquelle).

**Zwei User-Gates (vom User explizit verlangt):**
- **Gate A (Task 1):** Exakte SESSION-WORKFLOW.md-Änderungen werden VOR dem Schreiben gezeigt → User sagt OK / nicht OK.
- **Gate B (Task 6):** Vorher/Nachher der Live-Daten-Migration des zentralen Handoffs wird VOR dem Schreiben gezeigt.

---

## Kontext für den Implementierer (zero context)

- **Repo:** `C:\Users\domes\Desktop\Claude-Plugins-Skills\agentic-os-plugin` (Plugin-Source). Das laufende Plugin ist eine **Cache-Kopie** unter `~/.claude/plugins/cache/agentic-os-marketplace/agentic-os/3.4.0/` — Repo-Edits wirken erst nach Marketplace-Update + Session-Restart (Learning L5). Deployment ist Task 9.
- **Verfassung:** `C:\Users\domes\AI\SESSION-WORKFLOW.md` (207 Zeilen) definiert den zentralen Handoff. §4.1 verbietet Agenten-Änderungen — der User hat für DIESE Änderung explizit genehmigt (2026-06-12), mit Show-before-write-Gate.
- **Duplikats-Mechanik (Ist):** wrap-up Step 7.6a prependet bei jedem Session-Ende einen vollen Handoff-Block inkl. `## Naechste Schritte` und behält bis zu 5 gestapelte Blöcke. Drei Sessions am selben Projekt = dieselben Next Steps dreimal. Zusätzlich stehen sie lokal in `session-summary.md` und als `Next:`-Zeile im Status-Board.
- **Vorhandene Konsumenten von `context/open-tasks.json`:** SessionEnd-Hook (Task-Persistence-Guard, erwartet `status: open|blocked`), PreCompact-Hook (erwartet `task ID + title`), memory-maintenance (Root-Drift-Check). **Kein Skill schreibt die Datei bisher systematisch** — diese Lücke schließt Task 4.
- **Tests:** `bash tests/run-all.sh` führt `validate-plugin.sh` + `validate-skills.sh` aus. Marker-Tests binden eine Spec-Zusage an einen eindeutigen `(marker)`-String im SKILL.md-Body und greppen mit `grep -A<n>` nur den Marker-Block (Learning L11). Jeder neue Marker-Test MUSS bidirektional verifiziert werden: Marker-Zeile temporär entfernen → Test rot; wiederherstellen → grün.
- **Sprachregeln:** SKILL.md-Bodies Englisch. Der zentrale Handoff (7.6a-Template) ist auf Deutsch — per `awk`-Split in `validate-skills.sh:139-147` von den Englisch-Tests ausgenommen. Marker `(so-wie-dieser)` gehören in die Skill-PROSA, niemals in Templates (sonst landen sie im geschriebenen Artefakt).

---

### Task 1: SESSION-WORKFLOW.md ändern (USER-GATE A)

**Files:**
- Modify: `C:\Users\domes\AI\SESSION-WORKFLOW.md` (4 Edits)

- [ ] **Step 1: Dem User die folgenden 4 Edits ALS DIFF zeigen und auf explizites OK warten. Bei „nicht OK": Task abbrechen, Feedback einarbeiten, erneut zeigen.**

**Edit 1 — §3 Template, Sektion `## Naechste Schritte` (Zeilen 119–120):**

ALT:
```markdown
## Naechste Schritte
1. ...
```

NEU:
```markdown
## Naechste Schritte
- Projekt-Next-Steps: {lokale Quelle, z.B. <projekt>/.agent-memory/context/open-tasks.json} ({N} offen; Top: {1 Zeile})
- [cross-project] {nur Punkte, die andere Projekte/Geraete betreffen — Zeile weglassen wenn keine}
```

**Edit 2 — §3 „Regeln fuer session-summary.md" (Zeilen 126–130):**

ALT:
```markdown
**Regeln fuer session-summary.md:**
- Eine einzige Datei, NICHT pro Agent eine eigene
- Der schreibende Agent ueberschreibt die vorherige Summary komplett — das ist gewollt
- Alte Session-Details gehoeren ins Projekt (git log, Session-Notes), nicht in die Summary
- Bei komplexem Handoff: Details im Projekt dokumentieren und in der Summary darauf verweisen
```

NEU:
```markdown
**Regeln fuer session-summary.md:**
- Eine einzige Datei, NICHT pro Agent eine eigene
- Schreib-Modus: PREPEND mit Demote — der neue Block steht oben als `# Letzte Session`;
  der bisherige Top-Block wird zu `# Vorherige Session ({Datum} {Projekt}, erhalten)`
  demotet. Kein Blind-Ueberschreiben: die Datei kann die Handoff-Kette eines ANDEREN
  Projekts halten (Datenverlust-Vorfall 2026-06-01).
- Ownership-Dedup: pro Projekt bleibt hoechstens EIN Block erhalten — beim Prepend werden
  aeltere Bloecke DESSELBEN Projekts entfernt. Hard cap: 5 Bloecke gesamt.
- Naechste Schritte gehoeren dem Projekt, nicht dem Handoff: unter `## Naechste Schritte`
  steht ein VERWEIS auf die projekt-lokale Quelle (Anzahl offener Punkte + Top-Punkt,
  1 Zeile) plus AUSSCHLIESSLICH Punkte mit `[cross-project]`-Prefix. Keine Vollkopie
  der Projekt-Next-Steps — die leben ausschliesslich im Projekt.
- Alte Session-Details gehoeren ins Projekt (git log, Session-Notes), nicht in die Summary
- Bei komplexem Handoff: Details im Projekt dokumentieren und in der Summary darauf verweisen
```

**Edit 3 — §7 Abgrenzungs-Tabelle (Zeile 204):**

ALT:
```markdown
| Schreib-Modus | komplettes Ueberschreiben | nur eigener Abschnitt |
```

NEU:
```markdown
| Schreib-Modus | Prepend + Demote (max 1 Block/Projekt, cap 5) | nur eigener Abschnitt |
```

**Edit 4 — Änderungsvermerk ans Dateiende (nach Zeile 208) anhängen:**

```markdown

---

*Aenderung 2026-06-12 (explizit User-genehmigt): Schreib-Modus des zentralen Handoffs
kodifiziert (Prepend+Demote statt Komplett-Ueberschreiben — gelebte Praxis seit 2026-06-01)
plus Ownership-Prinzip fuer Naechste Schritte (projekt-lokale Quelle ist autoritativ,
zentral nur Verweis + [cross-project]-Punkte, max 1 Block pro Projekt). Grund:
Next-Step-Duplikate durch gestapelte Session-Bloecke desselben Projekts.*
```

- [ ] **Step 2: Nach User-OK die 4 Edits mit dem Edit-Tool anwenden** (exakte Strings von oben; Edit 1 und die §7-Tabellenzeile sind dateiweit eindeutig).

- [ ] **Step 3: Verifizieren**

Run: `grep -n "Ownership-Dedup\|Projekt-Next-Steps\|Prepend + Demote" "C:/Users/domes/AI/SESSION-WORKFLOW.md"`
Expected: 3+ Treffer (Edit 1, 2, 3); danach `grep -c "ueberschreibt die vorherige Summary komplett"` → `0`.

*(Kein Commit — `~/AI` ist der AI-Workspace, kein Git-Pflicht-Repo. Kein Test — externes Dokument.)*

---

### Task 2: Marker-Tests für wrap-up schreiben (TDD rot)

**Files:**
- Modify: `tests/validate-skills.sh` (einfügen nach dem bestehenden wrap-up-Header-Test, hinter Zeile 147)

- [ ] **Step 1: Die drei Marker-Tests einfügen** (Konvention: `pass`/`fail`-Helper, `$SKILLS_DIR`, Marker-Block via `grep -A`):

```bash
# --- Handoff-Ownership (2026-06-12): drei Marker, je strip->FAIL-verifiziert (L11) ---
WU_HO_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU_HO_FILE" ]; then
    # (open-tasks-ssot): wrap-up persistiert Next Steps nach context/open-tasks.json
    OTS_BLOCK=$(grep -A4 "(open-tasks-ssot)" "$WU_HO_FILE")
    if echo "$OTS_BLOCK" | grep -q "context/open-tasks.json" && echo "$OTS_BLOCK" | grep -qi "single source of truth"; then
        pass "wrap-up: (open-tasks-ssot) — Next Steps persisted to context/open-tasks.json as SSoT"
    else
        fail "wrap-up: missing (open-tasks-ssot) block — wrap-up must write Next Steps/Open Items into context/open-tasks.json (SSoT), summary is only a rendering"
    fi

    # (handoff-dedup): 7.6a prepend droppt aeltere Bloecke desselben Projekts
    HD_BLOCK=$(grep -A4 "(handoff-dedup)" "$WU_HO_FILE")
    if echo "$HD_BLOCK" | grep -qi "one block per project" && echo "$HD_BLOCK" | grep -qi "same project"; then
        pass "wrap-up: (handoff-dedup) — central handoff keeps max one block per project"
    else
        fail "wrap-up: missing (handoff-dedup) rule in Step 7.6a — prepend must drop older blocks of the SAME project (kills next-step stacking)"
    fi

    # (next-steps-pointer): zentraler Block verweist statt zu kopieren
    NSP_BLOCK=$(grep -A5 "(next-steps-pointer)" "$WU_HO_FILE")
    if echo "$NSP_BLOCK" | grep -q "open-tasks.json" && echo "$NSP_BLOCK" | grep -q "cross-project"; then
        pass "wrap-up: (next-steps-pointer) — central Naechste Schritte is pointer + [cross-project] items only"
    else
        fail "wrap-up: missing (next-steps-pointer) rule in Step 7.6a — central handoff must point to local open-tasks.json and list only [cross-project] items inline"
    fi
fi
```

- [ ] **Step 2: Suite laufen lassen — die 3 neuen Tests MÜSSEN rot sein**

Run: `cd "C:/Users/domes/Desktop/Claude-Plugins-Skills/agentic-os-plugin" && bash tests/validate-skills.sh 2>&1 | grep -E "FAIL.*(open-tasks-ssot|handoff-dedup|next-steps-pointer)"`
Expected: 3 FAIL-Zeilen (Marker existieren noch nicht in wrap-up).

- [ ] **Step 3: Commit (rote Tests zusammen mit Implementierung in Task 4 committen ist hier NICHT der Stil — dieses Repo committet Test+Fix gemeinsam; daher KEIN Commit jetzt, weiter mit Task 3/4).**

---

### Task 3: Marker-Test für session-bootstrap schreiben (TDD rot)

**Files:**
- Modify: `tests/validate-skills.sh` (direkt unter dem Block aus Task 2)

- [ ] **Step 1: Test einfügen:**

```bash
# (open-tasks-priority): bootstrap liest Next Steps aus der lokalen SSoT, zentral nur [cross-project]
SB_HO_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
if [ -f "$SB_HO_FILE" ]; then
    OTP_BLOCK=$(grep -A4 "(open-tasks-priority)" "$SB_HO_FILE")
    if echo "$OTP_BLOCK" | grep -q "context/open-tasks.json" && echo "$OTP_BLOCK" | grep -qi "cross-project"; then
        pass "session-bootstrap: (open-tasks-priority) — local open-tasks.json is authoritative for next steps"
    else
        fail "session-bootstrap: missing (open-tasks-priority) — recommendations must come from local context/open-tasks.json first; central handoff contributes only [cross-project] items"
    fi
fi
```

- [ ] **Step 2: Suite laufen lassen — neuer Test MUSS rot sein**

Run: `bash tests/validate-skills.sh 2>&1 | grep "open-tasks-priority"`
Expected: 1 FAIL-Zeile.

---

### Task 4: wrap-up SKILL.md umbauen (TDD grün, Teil 1)

**Files:**
- Modify: `skills/wrap-up/SKILL.md` (3 Edits: neuer Step 5.5; 7.6a-Algorithmus; 7.6a-Template)

- [ ] **Step 1: Neuen Step 5.5 einfügen** — direkt NACH dem Step-5-Template-Block (endet bei Zeile ~199, vor dem nächsten `## Step`-Heading):

```markdown
## Step 5.5: Persist Next Steps to open-tasks.json (open-tasks-ssot)

`context/open-tasks.json` is the single source of truth for this project's open tasks.
The SessionEnd guard and the PreCompact hook already read it; session-bootstrap Step 6
builds its recommendations from it. The summary's "Next Steps" section (Step 5) is a
RENDERING of this file — never the other way around.

1. Read `context/open-tasks.json` (JSON array; treat as `[]` if missing).
2. For every item in Step 5's "Next Steps" and "Open Items": if no entry with the same
   `title` exists (case-insensitive compare) → append:
   `{"id": "T-{next free number}", "title": "{item}", "status": "open", "created": "{today}", "updated": "{today}", "source": "wrap-up", "cross_project": false}`
   Items described as blocked go in with `"status": "blocked"`.
3. Mark entries as `"status": "done", "updated": "{today}"` when this session completed
   them (compare against Step 2's What-Was-Done list). Never delete entries — done items
   stay for audit; memory-maintenance archives them.
4. Set `"cross_project": true` ONLY for items the user explicitly flagged as relevant
   beyond this project. This flag is the sole feed for the central handoff's inline list
   (Step 7.6a) — everything else stays local.
```

- [ ] **Step 2: 7.6a-Prepend-Algorithmus erweitern** — im „Deterministic prepend algorithm"-Block nach Schritt 2 (Demote, endet „…prevents nested/duplicated `Vorherige Session` wrappers on repeat runs.") einfügen:

```markdown
2.5. **Ownership-Dedup (handoff-dedup):** after demoting, DELETE every older
   `# Vorherige Session (...)` block whose project equals the NEW block's project —
   the file keeps at most one block per project ("one block per project"). A second
   block of the same project is pure duplication: its detail already lives in that
   project's own `.agent-memory/session-summary.md`, so nothing is lost.
```

…und im bisherigen Schritt 4 (Hard cap) den ersten Satz ersetzen:

ALT: `4. **Hard cap (mandatory, not optional):** keep at most **5** session blocks total`
NEU: `4. **Hard cap (mandatory, not optional):** keep at most **5** session blocks total — after rule 2.5 these are 5 DISTINCT projects`

- [ ] **Step 3: 7.6a Pointer-Regel + Template ändern.** VOR dem Template-Block („Use the SESSION-WORKFLOW.md template…") diesen Absatz einfügen:

```markdown
**Naechste Schritte = pointer, not copy (next-steps-pointer):** the central block does
NOT replicate the project's next steps. It carries ONE pointer line to the local source
(`{project}/.agent-memory/context/open-tasks.json` — open count + top item) plus ONLY
entries with `cross_project: true` from Step 5.5, each prefixed `[cross-project]`.
Project-specific steps live exclusively in the local store (ownership principle, per
SESSION-WORKFLOW.md §3 as amended 2026-06-12).
```

…und im Template selbst:

ALT:
```markdown
## Naechste Schritte
1. {highest priority}
```

NEU:
```markdown
## Naechste Schritte
- Projekt-Next-Steps: {project}/.agent-memory/context/open-tasks.json ({N} offen; Top: {1 Zeile})
- [cross-project] {items with cross_project=true — omit this line entirely if none}
```

- [ ] **Step 4: wrap-up-Tests laufen lassen — die 3 Marker-Tests MÜSSEN grün sein**

Run: `bash tests/validate-skills.sh 2>&1 | grep -E "(open-tasks-ssot|handoff-dedup|next-steps-pointer)"`
Expected: 3 PASS-Zeilen, 0 FAIL.

- [ ] **Step 5: Strip-Gegenprobe (L11, pro Marker einmal):** Marker-String temporär aus `skills/wrap-up/SKILL.md` entfernen (z.B. `(handoff-dedup)` → `(handoff-dedupX)`), Suite → FAIL erwartet; zurückdrehen, Suite → PASS. Für alle 3 Marker wiederholen.

- [ ] **Step 6: Commit**

```bash
git add tests/validate-skills.sh skills/wrap-up/SKILL.md
git commit -m "feat(handoff): ownership-prinzip — open-tasks.json SSoT + one-block-per-project + pointer statt next-step-kopie (wrap-up)"
```

---

### Task 5: session-bootstrap SKILL.md umbauen (TDD grün, Teil 2)

**Files:**
- Modify: `skills/session-bootstrap/SKILL.md` (4 Edits: Step-0.5-Regel, Step-2-Leseliste, Step-4-Briefing, Step-6-Priorität)

- [ ] **Step 1: Step 0.5 „Rules"-Liste ergänzen** — neuer Bullet vor „If either file does not exist…":

```markdown
- **Next-steps ownership (open-tasks-priority):** the central handoff's "Naechste Schritte"
  section is a POINTER, not a list. The authoritative source for THIS project's next steps
  is the local `context/open-tasks.json` (rendered by the local session-summary). From the
  central handoff, import ONLY items prefixed `[cross-project]`. Never harvest project
  next steps from stacked history blocks — they no longer exist (one block per project).
```

- [ ] **Step 2: Step-2-Leseliste ergänzen** — nach Eintrag 9 (`working/current-session.json`):

```markdown
10. **`context/open-tasks.json`** — open/blocked tasks (SSoT for next steps; feeds Step 6)
```

- [ ] **Step 3: Step-4-Briefing anpassen** — im `LAST SESSION (this project)`-Block:

ALT: `  Next steps: {numbered list from summary}`
NEU: `  Next steps: {open/blocked items from context/open-tasks.json; fallback: summary "Next Steps" if the file is missing/empty}`

- [ ] **Step 4: Step 6 (Recommend Next Steps) umstellen:**

ALT:
```markdown
RECOMMENDED NEXT STEPS
  1. {from central handoff open items, if they apply to this project}
  2. {from local session summary open items}
  3. {from pattern warnings or quality alerts}

  Ready — was steht heute an?
```

NEU:
```markdown
RECOMMENDED NEXT STEPS
  1. {open/blocked tasks from context/open-tasks.json — highest priority first}
  2. {[cross-project] items from the central handoff that apply to this project}
  3. {from pattern warnings or quality alerts}

  Ready — was steht heute an?
```

…und den Prioritäts-Satz darunter:

ALT: `**Priority:** Central handoff open items that reference THIS project come first. Then local open items. Then system-level warnings.`
NEU: `**Priority:** Local `context/open-tasks.json` comes first — it owns this project's next steps. Then `[cross-project]` items from the central handoff. Then system-level warnings. Deduplicate: if an item appears both locally and centrally, show it ONCE (local wording wins).`

- [ ] **Step 5: Test grün prüfen + Strip-Gegenprobe für `(open-tasks-priority)`**

Run: `bash tests/validate-skills.sh 2>&1 | grep "open-tasks-priority"`
Expected: PASS. Danach Marker temporär verfremden → FAIL → restaurieren → PASS.

- [ ] **Step 6: Commit**

```bash
git add skills/session-bootstrap/SKILL.md
git commit -m "feat(handoff): bootstrap liest next steps aus open-tasks.json (SSoT), zentral nur [cross-project] (open-tasks-priority)"
```

---

### Task 6: Live-Daten-Migration des zentralen Handoffs (USER-GATE B)

**Files:**
- Create: `C:\Users\domes\Desktop\Claude-Plugins-Skills\agentic-os-plugin\.agent-memory\working\migrate-central-handoff.py` (Wegwerf-Skript, Regel §10.6: .py-Datei statt Inline-Python)
- Modify: `C:\Users\domes\AI\.agent-memory\session-summary.md` (nach User-OK)

- [ ] **Step 1: Backup anlegen**

Run: `cp "C:/Users/domes/AI/.agent-memory/session-summary.md" "C:/Users/domes/AI/.agent-memory/session-summary.md.bak-2026-06-12"`

- [ ] **Step 2: Migrations-Skript schreiben (Dry-Run-Modus zuerst):**

```python
# migrate-central-handoff.py — Ownership-Dedup einmalig auf den Bestands-Handoff anwenden.
# Modus: ohne Argument = DRY-RUN (zeigt nur Vorher/Nachher); mit "apply" = schreiben.
import re
import sys

PATH = r"C:/Users/domes/AI/.agent-memory/session-summary.md"

with open(PATH, encoding="utf-8") as f:
    content = f.read()

# Blöcke an Top-Level-Headings splitten ('# Letzte Session' / '# Vorherige Session (...)')
parts = re.split(r"(?m)^(?=# (?:Letzte|Vorherige) Session)", content)
blocks = [p for p in parts if p.strip()]

def project_of(block):
    m = re.search(r"\*Projekt:\s*(.+?)\*", block)
    if m:
        return m.group(1).strip()
    m = re.search(r"^# Vorherige Session \(.*?\s(\S+), erhalten\)", block)
    return m.group(1).strip() if m else "UNBEKANNT"

kept, seen = [], set()
for b in blocks:  # Reihenfolge = neueste zuerst (Prepend-Datei)
    proj = project_of(b)
    if proj in seen:
        continue  # älterer Block desselben Projekts -> Duplikat, fällt weg
    seen.add(proj)
    kept.append((proj, b))
kept = kept[:5]  # Hard cap

print("VORHER:", len(blocks), "Bloecke |", [project_of(b) for b in blocks])
print("NACHHER:", len(kept), "Bloecke |", [p for p, _ in kept])

if len(sys.argv) > 1 and sys.argv[1] == "apply":
    with open(PATH, "w", encoding="utf-8") as f:
        f.write("".join(b for _, b in kept))
    print("GESCHRIEBEN.")
else:
    print("DRY-RUN — nichts geschrieben. Mit 'apply' ausfuehren.")
```

- [ ] **Step 3: Dry-Run ausführen und dem User Vorher/Nachher zeigen (Gate B) — auf OK warten.**

Run: `python .agent-memory/working/migrate-central-handoff.py`
Expected: `VORHER: N Bloecke […] / NACHHER: M Bloecke […]` mit M ≤ N, ein Block pro Projekt.

- [ ] **Step 4: Nach User-OK anwenden + Ground-Truth-Check**

Run: `python .agent-memory/working/migrate-central-handoff.py apply && grep -c "^# " "C:/Users/domes/AI/.agent-memory/session-summary.md"`
Expected: Anzahl Headings = M; erster Heading bleibt `# Letzte Session`.

*(Vorsicht Parallel-Session-Drift, CLAUDE.md §4: unmittelbar vor dem apply die mtime der Datei prüfen — wenn sie sich seit dem Dry-Run geändert hat, Dry-Run wiederholen.)*

---

### Task 7: Doku + Version

**Files:**
- Modify: `skills/DEPENDENCIES.md` (wrap-up-Zeile + session-bootstrap-Zeile der Matrix)
- Modify: `docs/CHANGELOG.md` (neuer Eintrag oben)
- Modify: `.claude-plugin/plugin.json` (`"version": "3.4.0"` → `"3.5.0"`)

- [ ] **Step 1: DEPENDENCIES.md Matrix aktualisieren.** In der wrap-up-Zeile bei „Writes To" ergänzen: `context/open-tasks.json (Step 5.5, SSoT)`; den Step-7.6-Teil ergänzen um `(one block per project, next steps as pointer + [cross-project] only)`. In der session-bootstrap-Zeile bei „Reads From" ergänzen: `context/open-tasks.json`.

- [ ] **Step 2: CHANGELOG-Eintrag schreiben:**

```markdown
## [3.5.0] — 2026-06-12

### Changed
- **Handoff-Ownership:** Next Steps leben jetzt genau einmal — lokal in
  `context/open-tasks.json` (neuer wrap-up Step 5.5, SSoT). Der zentrale Handoff
  haelt max. 1 Block pro Projekt (7.6a Ownership-Dedup) und verweist auf die lokale
  Quelle statt Next Steps zu kopieren; inline nur noch `[cross-project]`-Punkte.
  session-bootstrap empfiehlt aus der lokalen SSoT (Step 6 Prioritaet gedreht).
  SESSION-WORKFLOW.md §3/§7 entsprechend angepasst (User-genehmigt 2026-06-12).
  Behebt: Next-Step-Duplikate (2–3x) ueber gestapelte Session-Bloecke.
```

- [ ] **Step 3: Versions-Querverweise prüfen** (Tests pinnen teils Zähler/Versionen):

Run: `grep -rn "3\.4\.0" tests/ .claude-plugin/ docs/PROJECT.md 2>/dev/null`
Expected: Nur plugin.json-Treffer ändern; falls ein Test die Version pinnt, dort mitziehen.

- [ ] **Step 4: Commit**

```bash
git add skills/DEPENDENCIES.md docs/CHANGELOG.md .claude-plugin/plugin.json
git commit -m "docs(handoff): 3.5.0 — ownership-prinzip dokumentiert (DEPENDENCIES, CHANGELOG, version bump)"
```

---

### Task 8: Volle Suite + Abschluss-Verifikation

- [ ] **Step 1: Komplette Suite**

Run: `bash tests/run-all.sh`
Expected: 0 FAIL (Stand vorher: 185 + 161 + 16 PASS; jetzt +4 neue Tests → 366 gesamt).

- [ ] **Step 2: Konsistenz-Dreieck prüfen (Read/Write-Symmetrie, L6):** die drei Formate müssen zusammenpassen —

Run: `grep -n "open-tasks.json" skills/wrap-up/SKILL.md skills/session-bootstrap/SKILL.md hooks/hooks.json | grep -ci "context/open-tasks"`
Expected: alle Treffer verwenden `context/open-tasks.json` (kein Root-Pfad).

- [ ] **Step 3: Push (isolierter Befehl, nie mit Reads gebündelt — L10) + Verifikation**

```bash
git push
git log origin/main..main --oneline
```
Expected: zweiter Befehl leer (alles oben).

---

### Task 9: Deployment in die laufende Instanz (L5)

- [ ] **Step 1: Marketplace + Plugin updaten**

```bash
claude plugin marketplace update agentic-os-marketplace
claude plugin update agentic-os@agentic-os-marketplace
```

- [ ] **Step 2: Ground-Truth statt CLI-Erfolgstext (L5):** prüfen, dass ein neuer Cache-Ordner `.../agentic-os/3.5.0/` existiert und dessen `plugin.json` `"version": "3.5.0"` enthält.

Run: `python -c "import json; print(json.load(open(r'C:/Users/domes/.claude/plugins/cache/agentic-os-marketplace/agentic-os/3.5.0/.claude-plugin/plugin.json', encoding='utf-8'))['version'])"`
Expected: `3.5.0`

- [ ] **Step 3: User informieren: Session-Restart nötig, damit die laufende Session den neuen Cache lädt.**

- [ ] **Step 4 (Regel 9): Codex-Review anbieten:** „Codex-Review? [1] Verifier [2] Security [3] Quality-Fixer [alle] [keine]" — Default Verifier.

---

## Self-Review (gegen die Spec)

- **Verfassung zuerst, mit Gate:** Task 1 ✓ (4 exakte Edits, Show-before-write).
- **Beide Seiten gleichzeitig (L6):** Schreibseite Task 4, Leseseite Task 5, Konsistenz-Check Task 8 Step 2 ✓.
- **Doppelungs-Mechanik abgeschafft, nicht kuriert:** one-block-per-project (Task 4 Step 2) + Pointer statt Kopie (Task 4 Step 3) + Bestandsdaten-Migration (Task 6) ✓.
- **SSoT-Lücke geschlossen:** open-tasks.json bekommt erstmals einen systematischen Schreiber (Task 4 Step 1); Schema `{id,title,status,…}` ist konsistent mit dem, was SessionEnd-/PreCompact-Hooks heute schon erwarten ✓.
- **L11 erfüllt:** 4 neue Marker-Tests, alle mit strip→FAIL-Gegenprobe ✓.
- **Status-Board und Sharepoint unangetastet** (Out of Scope) ✓.
