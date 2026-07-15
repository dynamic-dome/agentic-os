# Model-Routing v4.7.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kosten- und tokenbewusstes Modell-Routing für die Routine-Skills des agentic-os-plugin — deklarativ via Frontmatter, mit deterministischer Stufe-0-Vorverarbeitung, Eskalationsregeln und Kontext-Kostenmessung.

**Architecture:** Deklaratives Routing (Spec: `docs/superpowers/specs/2026-07-15-model-routing-design.md`): `model:`/`effort:`-Frontmatter ist der wirksame Mechanismus; `scripts/model-routing.sh` ist die SSoT-Tabelle, ein Test erzwingt Konsistenz. Stufe 0 = `scripts/preprocess_state.py` (Python statt .sh — bewusste Präzisierung gegenüber Spec §3.3: robustes JSON, folgt dem bestehenden Muster von `posttooluse-dirty-tracker.py`; Design-Doc wird in Task 7 angeglichen). Messung = `scripts/cost-trace.sh` (JSONL, Schätzwerte).

**Tech Stack:** Bash + Python 3 (stdlib only, kein Package-Manager — Plugin-Konvention), bash-Testsuite unter `tests/` mit `run-all.sh` als Runner.

## Global Constraints

- Plugin ist pure Markdown + JSON + Bash/Python-stdlib. KEINE neuen Dependencies, kein jq.
- Alle neuen Scripts fail-soft: Fehler → leere Felder/Warnung auf stderr, Exit 0 (Ausnahme: dokumentierte Exit-Codes wie `model-routing.sh` usage-Error = 2). Memory-Tooling darf echte Arbeit nie blockieren.
- Trigger-Phrasen und Skill-Body-Text ENGLISCH (Sprach-Tests in validate-skills.sh schlagen sonst rot). Einzige Ausnahme: der Output-Marker `ESKALATION:` (user-facing, nicht in den verbotenen Grep-Listen).
- Python-Subprocess auf Windows: `shutil.which()` vor jedem Aufruf, `encoding="utf-8", errors="replace"` statt bloßem `text=True` (cp1252-Falle).
- Skills referenzieren Scripts als `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>"` (bestehendes Muster, siehe session-bootstrap Zeile 123/217).
- Versionierung: `plugin.json` ist Source of Truth, steht aktuell auf **4.6.1**; dieses Release = **4.7.0** (minor). Version erst in Task 7 bumpen.
- Jeder Commit einzeln, chirurgisch gestagt (nie `git add -A`), Message-Format wie Repo-Historie (`feat(...)`/`fix(...)` + deutscher Kurztext), Trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Test-Runner: neue Tests MÜSSEN in `tests/run-all.sh` registriert werden (Muster: eigener `>>> Running ...`-Block; Python-Tests mit PY_BIN-Fallback und SKIPPED-Zweig).
- Bestehende Tests müssen durchgehend grün bleiben: nach jedem Task `bash tests/run-all.sh` → `ALL TEST SUITES PASSED`.

---

### Task 1: Routing-SSoT `scripts/model-routing.sh`

**Files:**
- Create: `scripts/model-routing.sh`
- Create: `tests/test-model-routing.sh`
- Modify: `tests/run-all.sh` (Registrierung)

**Interfaces:**
- Produces: `bash scripts/model-routing.sh list` → 9 TSV-Zeilen `skill<TAB>class<TAB>model<TAB>effort` (`-` = kein Frontmatter-Feld). `bash scripts/model-routing.sh list-agents` → 3 TSV-Zeilen analog. Unbekanntes Kommando → Exit 2. Task 2 konsumiert exakt dieses `list`-Format.

- [ ] **Step 1: Failing Test schreiben**

Create `tests/test-model-routing.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/model-routing.sh — the model-class SSoT (v4.7.0).
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MR="$PLUGIN_ROOT/scripts/model-routing.sh"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

echo "=== model-routing SSoT tests ==="

# 1. Script exists and `list` exits 0
if [ -f "$MR" ] && OUT=$(bash "$MR" list); then
    pass "list runs and exits 0"
else
    fail "scripts/model-routing.sh missing or 'list' failed"
    echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
    exit 1
fi

# 2. Exactly 9 rows (one per skill)
n=$(echo "$OUT" | grep -c .)
if [ "$n" -eq 9 ]; then pass "list has 9 rows"; else fail "list has $n rows (expected 9)"; fi

# 3. Every listed skill directory exists
while IFS=$'\t' read -r sk cls mdl eff; do
    if [ -d "$PLUGIN_ROOT/skills/$sk" ]; then
        pass "skill dir exists: $sk"
    else
        fail "SSoT lists unknown skill: $sk"
    fi
done <<< "$OUT"

# 4. Classes are from the allowed set
if echo "$OUT" | awk -F'\t' '{print $2}' | grep -vqE '^(deterministic|cheap-read|cheap-write|standard|strong)$'; then
    fail "list contains invalid class value"
else
    pass "all classes valid"
fi

# 5. cheap-write rows use sonnet; standard/strong rows use '-'
if echo "$OUT" | awk -F'\t' '$2=="cheap-write" && $3!="sonnet"' | grep -q .; then
    fail "cheap-write row without model=sonnet"
else
    pass "cheap-write => sonnet"
fi
if echo "$OUT" | awk -F'\t' '($2=="standard" || $2=="strong") && ($3!="-" || $4!="-")' | grep -q .; then
    fail "standard/strong row must have model=- and effort=-"
else
    pass "standard/strong => inherit (-)"
fi

# 6. list-agents: 3 rows, each agent file exists
AOUT=$(bash "$MR" list-agents)
an=$(echo "$AOUT" | grep -c .)
if [ "$an" -eq 3 ]; then pass "list-agents has 3 rows"; else fail "list-agents has $an rows (expected 3)"; fi
while IFS=$'\t' read -r ag cls mdl eff; do
    if [ -f "$PLUGIN_ROOT/agents/$ag.md" ]; then
        pass "agent file exists: $ag"
    else
        fail "SSoT lists unknown agent: $ag"
    fi
done <<< "$AOUT"

# 7. Unknown command exits 2
bash "$MR" bogus >/dev/null 2>&1
if [ "$?" -eq 2 ]; then pass "unknown command exits 2"; else fail "unknown command must exit 2"; fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `bash tests/test-model-routing.sh`
Expected: FAIL mit "scripts/model-routing.sh missing or 'list' failed", Exit 1.

- [ ] **Step 3: Implementierung schreiben**

Create `scripts/model-routing.sh`:

```bash
#!/usr/bin/env bash
# model-routing.sh — single source of truth for model-class routing (v4.7.0).
# Spec: docs/superpowers/specs/2026-07-15-model-routing-design.md
#
# The EFFECTIVE mechanism is the `model:` / `effort:` frontmatter in each
# SKILL.md (Claude Code applies it for the rest of the turn). This table
# documents the intended assignment; tests/validate-skills.sh enforces that
# frontmatter and table never drift apart. Real model names live ONLY here
# and in frontmatter — never in skill prose.
#
# Classes:
#   deterministic  no model — scripts only (preprocess_state.py, thresholds, ...)
#   cheap-read     haiku  — read-only tasks; UNUSED in release 1 (reserved for
#                           the phase-2 fork read path; haiku has a 200k window)
#   cheap-write    sonnet — routine skills that write through existing gates
#   standard       inherit session model (no frontmatter field)
#   strong         inherit session model (no frontmatter field)
#
# Usage:
#   bash scripts/model-routing.sh list         # TSV: skill<TAB>class<TAB>model<TAB>effort
#   bash scripts/model-routing.sh list-agents  # TSV: agent<TAB>class<TAB>model<TAB>effort
# "-" means: no frontmatter field (inherit). Exit 0; unknown command exit 2.
set -u
cmd="${1:-list}"
case "$cmd" in
  list)
    printf 'wrap-up\tcheap-write\tsonnet\tmedium\n'
    printf 'session-bootstrap\tcheap-write\tsonnet\tlow\n'
    printf 'memory-maintenance\tcheap-write\tsonnet\tlow\n'
    printf 'iteration-logger\tcheap-write\tsonnet\tlow\n'
    printf 'sync-context\tcheap-write\tsonnet\tlow\n'
    printf 'obsidian-sync\tcheap-write\tsonnet\tmedium\n'
    printf 'context-keeper\tstandard\t-\t-\n'
    printf 'pattern-extractor\tstandard\t-\t-\n'
    printf 'self-improve\tstrong\t-\t-\n'
    ;;
  list-agents)
    printf 'context-detective\tcheap-write\tsonnet\tmedium\n'
    printf 'improvement-agent\tcheap-write\tsonnet\t-\n'
    printf 'research-agent\tcheap-write\tsonnet\tmedium\n'
    ;;
  *)
    echo "usage: model-routing.sh [list|list-agents]" >&2
    exit 2
    ;;
esac
exit 0
```

- [ ] **Step 4: Test laufen lassen — muss bestehen**

Run: `bash tests/test-model-routing.sh`
Expected: `=== Results: N/N passed, 0 failures ===`, Exit 0.

- [ ] **Step 5: In run-all.sh registrieren**

In `tests/run-all.sh`, direkt VOR dem Block `# Run pattern rueckfluss contract test` einfügen:

```bash
# Run model-routing SSoT tests (v4.7.0)
echo ">>> Running model-routing SSoT tests..."
if bash "$SCRIPT_DIR/test-model-routing.sh"; then
    echo ">>> Model-routing SSoT tests: ALL PASSED"
else
    echo ">>> Model-routing SSoT tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""
```

- [ ] **Step 6: Gesamtsuite grün + Commit**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED`

```bash
git add scripts/model-routing.sh tests/test-model-routing.sh tests/run-all.sh
git commit -m "feat(routing): model-routing.sh als Modellklassen-SSoT + Tests (v4.7.0 T1)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Frontmatter-Routing in Skills/Agents + Konsistenz-Test

**Files:**
- Modify: `tests/validate-skills.sh` (Konsistenz-Check ans Ende, vor der `=== Results ===`-Zeile)
- Modify: `skills/wrap-up/SKILL.md`, `skills/session-bootstrap/SKILL.md`, `skills/memory-maintenance/SKILL.md`, `skills/iteration-logger/SKILL.md`, `skills/sync-context/SKILL.md`, `skills/obsidian-sync/SKILL.md` (je 2 Frontmatter-Zeilen)
- Modify: `agents/context-detective.md`, `agents/research-agent.md` (je 1 Frontmatter-Zeile)

**Interfaces:**
- Consumes: `bash "$PLUGIN_ROOT/scripts/model-routing.sh" list` (TSV aus Task 1).
- Produces: Top-Level-Frontmatter-Felder `model: sonnet` + `effort: <low|medium>` in den 6 cheap-write-Skills; `effort: medium` in 2 Agents. Task 5/6 bauen auf diesen Dateien auf (Body-Änderungen, disjunkt vom Frontmatter).

- [ ] **Step 1: Failing Konsistenz-Test in validate-skills.sh schreiben**

In `tests/validate-skills.sh` direkt VOR der Zeile `echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="` einfügen:

```bash
# --- Model-Routing SSoT consistency (v4.7.0) ---
# The frontmatter `model:`/`effort:` of every skill must match the routing
# table in scripts/model-routing.sh ("-" in the table = field must be ABSENT).
# Only top-level fields count (^model:), so metadata sub-keys never match.
echo ""
echo "-- model routing: skill frontmatter matches scripts/model-routing.sh --"
MR_SCRIPT="$PLUGIN_ROOT/scripts/model-routing.sh"
if [ -f "$MR_SCRIPT" ]; then
    while IFS=$'\t' read -r mr_skill mr_class mr_model mr_effort; do
        [ -n "$mr_skill" ] || continue
        mr_file="$SKILLS_DIR/$mr_skill/SKILL.md"
        if [ ! -f "$mr_file" ]; then
            fail "model-routing: $mr_skill listed in SSoT but SKILL.md missing"
            continue
        fi
        mr_fm=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$mr_file")
        got_model=$(echo "$mr_fm" | grep '^model:' | head -1 | sed 's/^model: *//' | tr -d ' \r')
        got_effort=$(echo "$mr_fm" | grep '^effort:' | head -1 | sed 's/^effort: *//' | tr -d ' \r')
        want_model="$mr_model"; [ "$want_model" = "-" ] && want_model=""
        want_effort="$mr_effort"; [ "$want_effort" = "-" ] && want_effort=""
        if [ "$got_model" = "$want_model" ] && [ "$got_effort" = "$want_effort" ]; then
            pass "model-routing: $mr_skill frontmatter matches SSoT ($mr_class: model='${want_model:--}' effort='${want_effort:--}')"
        else
            fail "model-routing: $mr_skill frontmatter (model='$got_model' effort='$got_effort') != SSoT (model='$want_model' effort='$want_effort') — fix frontmatter OR scripts/model-routing.sh, they must never drift"
        fi
    done < <(bash "$MR_SCRIPT" list)

    # Agents: same check against list-agents (agents/<name>.md)
    while IFS=$'\t' read -r mr_agent mr_class mr_model mr_effort; do
        [ -n "$mr_agent" ] || continue
        mr_afile="$PLUGIN_ROOT/agents/$mr_agent.md"
        if [ ! -f "$mr_afile" ]; then
            fail "model-routing: agent $mr_agent listed in SSoT but agents/$mr_agent.md missing"
            continue
        fi
        mr_afm=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$mr_afile")
        got_model=$(echo "$mr_afm" | grep '^model:' | head -1 | sed 's/^model: *//' | tr -d ' \r')
        got_effort=$(echo "$mr_afm" | grep '^effort:' | head -1 | sed 's/^effort: *//' | tr -d ' \r')
        want_model="$mr_model"; [ "$want_model" = "-" ] && want_model=""
        want_effort="$mr_effort"; [ "$want_effort" = "-" ] && want_effort=""
        if [ "$got_model" = "$want_model" ] && [ "$got_effort" = "$want_effort" ]; then
            pass "model-routing: agent $mr_agent frontmatter matches SSoT"
        else
            fail "model-routing: agent $mr_agent frontmatter (model='$got_model' effort='$got_effort') != SSoT (model='$want_model' effort='$want_effort')"
        fi
    done < <(bash "$MR_SCRIPT" list-agents)
else
    fail "model-routing: scripts/model-routing.sh missing — model-class SSoT required since v4.7.0"
fi
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `bash tests/validate-skills.sh; echo "exit=$?"`
Expected: FAIL-Zeilen für alle 6 cheap-write-Skills (Frontmatter hat noch kein `model:`) und für context-detective/research-agent (kein `effort:`), Exit 1.

- [ ] **Step 3: Frontmatter in den 6 Skills ergänzen**

In jeder der 6 Dateien die Zeile `user_invocable: true` ersetzen (Edit, exakter Match — die Zeile existiert in jeder Datei genau einmal):

`skills/wrap-up/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: medium
```

`skills/session-bootstrap/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: low
```

`skills/memory-maintenance/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: low
```

`skills/iteration-logger/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: low
```

`skills/sync-context/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: low
```

`skills/obsidian-sync/SKILL.md`:
```yaml
user_invocable: true
model: sonnet
effort: medium
```

- [ ] **Step 4: effort in 2 Agents ergänzen**

`agents/context-detective.md`: Zeile `model: sonnet` ersetzen durch:
```yaml
model: sonnet
effort: medium
```

`agents/research-agent.md`: Zeile `model: sonnet` ersetzen durch:
```yaml
model: sonnet
effort: medium
```

(improvement-agent bleibt unverändert — führt TDD-Iterationen aus, kein effort-Downgrade.)

- [ ] **Step 5: Tests laufen lassen — müssen bestehen**

Run: `bash tests/validate-skills.sh; echo "exit=$?"`
Expected: alle `model-routing:`-Zeilen PASS, Exit 0.
Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED` (bestätigt, dass die Sprach-/Marker-Tests die Frontmatter-Änderung tolerieren).

- [ ] **Step 6: Commit**

```bash
git add tests/validate-skills.sh skills/wrap-up/SKILL.md skills/session-bootstrap/SKILL.md skills/memory-maintenance/SKILL.md skills/iteration-logger/SKILL.md skills/sync-context/SKILL.md skills/obsidian-sync/SKILL.md agents/context-detective.md agents/research-agent.md
git commit -m "feat(routing): model/effort-Frontmatter fuer 6 Routine-Skills + 2 Agents, SSoT-Konsistenztest (v4.7.0 T2)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Stufe-0-Preprocessor `scripts/preprocess_state.py`

**Files:**
- Create: `scripts/preprocess_state.py`
- Create: `tests/test-preprocess-state.py`
- Modify: `tests/run-all.sh` (Registrierung mit PY_BIN-Muster)

**Interfaces:**
- Produces (CLI-Vertrag, konsumiert von Task 5/6 als Skill-Anweisung):
  - `python scripts/preprocess_state.py <mem-dir> [--session-id SID]` → JSON-Objekt auf stdout mit exakt den Keys `session_id, changed_files, git_diff_summary, threshold_events, validation_errors, open_tasks, previous_state_hash, current_state_hash`, immer Exit 0.
  - `python scripts/preprocess_state.py <mem-dir> --write-hash` → schreibt `<mem-dir>/working/state-hash` (atomar) und gibt dasselbe JSON aus.

- [ ] **Step 1: Failing Test schreiben**

Create `tests/test-preprocess-state.py`:

```python
#!/usr/bin/env python3
"""Tests for scripts/preprocess_state.py (stage-0 deterministic preprocessing, v4.7.0).

Covers spec test cases 24.1 (unchanged state -> hash equality) and the
deterministic half of 24.4 (structured delta instead of transcripts).
Run: python tests/test-preprocess-state.py  (exit 0 = pass)
"""
import json
import os
import subprocess
import sys
import tempfile

PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(PLUGIN_ROOT, "scripts", "preprocess_state.py")

FAILURES = []


def check(name, cond, detail=""):
    if cond:
        print(f"  PASS: {name}")
    else:
        print(f"  FAIL: {name} {detail}")
        FAILURES.append(name)


def run(args, cwd):
    proc = subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True, encoding="utf-8", errors="replace", cwd=cwd,
    )
    return proc


def main():
    print("=== preprocess_state.py tests ===")
    check("script exists", os.path.isfile(SCRIPT))
    if not os.path.isfile(SCRIPT):
        print("=== 1 failure (script missing) ===")
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        mem = os.path.join(tmp, ".agent-memory")
        os.makedirs(os.path.join(mem, "working"))

        # 1. Empty store -> valid JSON, empty fields, exit 0
        p = run([mem], cwd=tmp)
        check("empty store exits 0", p.returncode == 0, f"rc={p.returncode} err={p.stderr[:200]}")
        try:
            state = json.loads(p.stdout)
            check("empty store emits valid JSON", True)
        except Exception as e:
            check("empty store emits valid JSON", False, str(e))
            state = {}
        for key in ("session_id", "changed_files", "git_diff_summary",
                    "threshold_events", "validation_errors", "open_tasks",
                    "previous_state_hash", "current_state_hash"):
            check(f"key present: {key}", key in state)
        check("changed_files empty", state.get("changed_files") == [])
        check("previous hash empty on first run", state.get("previous_state_hash") == "")
        check("current hash non-empty", bool(state.get("current_state_hash")))

        # 2. Dirty file -> changed_files picked up
        dirty = {"dirty": True, "touched": ["src/app.py", "README.md"]}
        with open(os.path.join(mem, "working", "dirty-abc.json"), "w", encoding="utf-8") as f:
            json.dump(dirty, f)
        p = run([mem], cwd=tmp)
        state = json.loads(p.stdout)
        check("dirty touched files in changed_files",
              set(state["changed_files"]) >= {"src/app.py", "README.md"},
              str(state.get("changed_files")))

        # 3. open-tasks.json -> only non-done tasks
        os.makedirs(os.path.join(mem, "context"), exist_ok=True)
        tasks = [{"id": "T1", "title": "open one", "status": "open"},
                 {"id": "T2", "title": "done one", "status": "done"}]
        with open(os.path.join(mem, "context", "open-tasks.json"), "w", encoding="utf-8") as f:
            json.dump(tasks, f)
        p = run([mem], cwd=tmp)
        state = json.loads(p.stdout)
        ids = [t.get("id") for t in state["open_tasks"]]
        check("open task listed", "T1" in ids, str(ids))
        check("done task excluded", "T2" not in ids, str(ids))

        # 4. Broken JSON -> validation_errors names file, still exit 0
        os.makedirs(os.path.join(mem, "learnings"), exist_ok=True)
        with open(os.path.join(mem, "learnings", "learnings.json"), "w", encoding="utf-8") as f:
            f.write("{broken json")
        p = run([mem], cwd=tmp)
        check("broken json still exits 0", p.returncode == 0)
        state = json.loads(p.stdout)
        check("validation_errors names broken file",
              any("learnings.json" in e for e in state["validation_errors"]),
              str(state.get("validation_errors")))

        # 5. --write-hash -> state-hash file created; second run: prev == current
        p = run([mem, "--write-hash"], cwd=tmp)
        check("--write-hash exits 0", p.returncode == 0)
        hash_file = os.path.join(mem, "working", "state-hash")
        check("state-hash file written", os.path.isfile(hash_file))
        p = run([mem], cwd=tmp)
        state = json.loads(p.stdout)
        check("hash equality after write (spec 24.1 fast path)",
              state["previous_state_hash"] == state["current_state_hash"]
              and state["current_state_hash"] != "")

        # 6. Memory change after write-hash -> hashes differ
        with open(os.path.join(mem, "session-summary.md"), "w", encoding="utf-8") as f:
            f.write("# Session Summary\nnew content\n")
        p = run([mem], cwd=tmp)
        state = json.loads(p.stdout)
        check("hash differs after change",
              state["previous_state_hash"] != state["current_state_hash"])

        # 7. No git repo -> git_diff_summary empty string, exit 0
        check("no-git-repo yields empty diff summary",
              isinstance(state["git_diff_summary"], str))

        # 8. --session-id restricts dirty scan to that session's file
        with open(os.path.join(mem, "working", "dirty-zzz.json"), "w", encoding="utf-8") as f:
            json.dump({"dirty": True, "touched": ["other.txt"]}, f)
        p = run([mem, "--session-id", "abc"], cwd=tmp)
        state = json.loads(p.stdout)
        check("--session-id scopes changed_files",
              "other.txt" not in state["changed_files"], str(state["changed_files"]))

    n = len(FAILURES)
    print(f"=== {('ALL PASSED' if n == 0 else str(n) + ' FAILURE(S)')} ===")
    return 0 if n == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `python tests/test-preprocess-state.py; echo "exit=$?"`
Expected: `FAIL: script exists`, Exit 1.

- [ ] **Step 3: Implementierung schreiben**

Create `scripts/preprocess_state.py`:

```python
#!/usr/bin/env python3
"""Stage-0 deterministic preprocessing for memory skills (agentic-os v4.7.0).

Gathers all mechanical session facts WITHOUT any model call and emits one
normalized JSON state object on stdout (spec memospartoken.md section 7.1).
Consumers: wrap-up Step 0, session-bootstrap fast path.

Contract (must never break):
- Fail-soft: any error -> empty fields / stderr warning, ALWAYS exit 0.
- Only mechanical facts (paths, counts, hashes) — no LLM, no content analysis.
- Hash writes are atomic (tmp + os.replace).
- stdlib only; subprocess guarded by shutil.which() (Windows rule).

Usage:
  python preprocess_state.py [mem-dir] [--session-id SID] [--write-hash]
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

# Files whose content defines the memory state hash (relative to mem dir).
# Deliberately excludes working/ (scratch) and metrics/ (traces).
STATE_FILES = [
    "session-summary.md",
    "context/open-tasks.json",
    "context/project-context.md",
    "context/decisions.json",
    "learnings/learnings.json",
    "learnings/learnings.md",
    "patterns/patterns.json",
    "iterations/iteration-log.md",
    "iterations/errors.json",
    "identity/user.md",
]

HASH_FILE = os.path.join("working", "state-hash")


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def compute_state_hash(mem):
    h = hashlib.sha256()
    for rel in STATE_FILES:
        p = os.path.join(mem, rel)
        if os.path.isfile(p):
            try:
                with open(p, "rb") as f:
                    h.update(rel.encode("utf-8") + b"\0" + f.read() + b"\0")
            except OSError:
                continue
    return h.hexdigest()


def collect_changed_files(mem, session_id):
    changed = []
    workdir = os.path.join(mem, "working")
    if not os.path.isdir(workdir):
        return changed
    try:
        names = sorted(os.listdir(workdir))
    except OSError:
        return changed
    for name in names:
        if not (name.startswith("dirty-") and name.endswith(".json")):
            continue
        if session_id and name != f"dirty-{session_id}.json":
            continue
        try:
            data = json.loads(read_text(os.path.join(workdir, name)) or "")
        except (ValueError, TypeError):
            continue
        if isinstance(data, dict) and data.get("dirty"):
            touched = data.get("touched") or data.get("touched_files") or []
            if isinstance(touched, list):
                for t in touched:
                    if isinstance(t, str) and t not in changed:
                        changed.append(t)
    return changed


def git_diff_summary():
    git = shutil.which("git")
    if not git:
        return ""
    try:
        proc = subprocess.run(
            [git, "diff", "--stat", "HEAD"],
            capture_output=True, encoding="utf-8", errors="replace", timeout=15,
        )
        if proc.returncode != 0:
            return ""
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        return lines[-1].strip() if lines else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def threshold_events(mem):
    bash = shutil.which("bash")
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory-thresholds.sh")
    if not bash or not os.path.isfile(script):
        return []
    try:
        proc = subprocess.run(
            [bash, script, mem],
            capture_output=True, encoding="utf-8", errors="replace", timeout=15,
        )
        if proc.returncode == 10:
            return [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
        return []
    except (OSError, subprocess.SubprocessError):
        return []


def validation_errors(mem):
    errors = []
    for root, dirs, files in os.walk(mem):
        # metrics traces are append-only JSONL, not JSON documents
        dirs[:] = [d for d in dirs if d not in ("metrics",)]
        for name in files:
            if not name.endswith(".json"):
                continue
            p = os.path.join(root, name)
            text = read_text(p)
            if text is None:
                continue
            try:
                json.loads(text)
            except ValueError as e:
                rel = os.path.relpath(p, mem).replace(os.sep, "/")
                errors.append(f"{rel}: {e}")
    return errors


def open_tasks(mem):
    text = read_text(os.path.join(mem, "context", "open-tasks.json"))
    if not text:
        return []
    try:
        data = json.loads(text)
    except ValueError:
        return []
    tasks = data if isinstance(data, list) else data.get("tasks", [])
    out = []
    if isinstance(tasks, list):
        for t in tasks:
            if isinstance(t, dict) and t.get("status") != "done":
                out.append({"id": t.get("id", ""), "title": t.get("title", ""),
                            "status": t.get("status", "")})
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mem", nargs="?", default=".agent-memory")
    parser.add_argument("--session-id", default="")
    parser.add_argument("--write-hash", action="store_true")
    args = parser.parse_args()
    mem = args.mem

    state = {
        "session_id": args.session_id,
        "changed_files": [],
        "git_diff_summary": "",
        "threshold_events": [],
        "validation_errors": [],
        "open_tasks": [],
        "previous_state_hash": "",
        "current_state_hash": "",
    }
    try:
        state["changed_files"] = collect_changed_files(mem, args.session_id)
        state["git_diff_summary"] = git_diff_summary()
        state["threshold_events"] = threshold_events(mem)
        state["validation_errors"] = validation_errors(mem)
        state["open_tasks"] = open_tasks(mem)
        prev = read_text(os.path.join(mem, HASH_FILE))
        state["previous_state_hash"] = (prev or "").strip()
        state["current_state_hash"] = compute_state_hash(mem)

        if args.write_hash:
            workdir = os.path.join(mem, "working")
            os.makedirs(workdir, exist_ok=True)
            tmp = os.path.join(workdir, "state-hash.tmp")
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(state["current_state_hash"])
            os.replace(tmp, os.path.join(mem, HASH_FILE))
    except Exception as e:  # fail-soft: never block real work
        print(f"preprocess_state: degraded ({e})", file=sys.stderr)

    print(json.dumps(state, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Test laufen lassen — muss bestehen**

Run: `python tests/test-preprocess-state.py; echo "exit=$?"`
Expected: `=== ALL PASSED ===`, Exit 0.

- [ ] **Step 5: In run-all.sh registrieren**

In `tests/run-all.sh`, direkt VOR dem Block `# Run model-routing SSoT tests` einfügen (PY_BIN-Muster wie beim dirty-tracker):

```bash
# Run stage-0 preprocess-state tests (v4.7.0)
echo ">>> Running preprocess-state tests..."
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ] && "$PY_BIN" "$SCRIPT_DIR/test-preprocess-state.py"; then
    echo ">>> Preprocess-state tests: ALL PASSED"
elif [ -z "$PY_BIN" ]; then
    echo ">>> Preprocess-state tests: SKIPPED (no python found)"
else
    echo ">>> Preprocess-state tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""
```

- [ ] **Step 6: Gesamtsuite grün + Commit**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED`

```bash
git add scripts/preprocess_state.py tests/test-preprocess-state.py tests/run-all.sh
git commit -m "feat(routing): preprocess_state.py — deterministisches Stufe-0-Zustandsobjekt + Tests (v4.7.0 T3)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Kostenmessung `scripts/cost-trace.sh`

**Files:**
- Create: `scripts/cost-trace.sh`
- Create: `tests/test-cost-trace.sh`
- Modify: `tests/run-all.sh` (Registrierung)

**Interfaces:**
- Produces (CLI-Vertrag, konsumiert von Task 5/6 als Skill-Anweisung): `bash scripts/cost-trace.sh append --mem <dir> --task <name> --class <class> --context-bytes <N> --escalated <0|1>` → hängt eine JSONL-Zeile an `<dir>/metrics/cost-trace.jsonl` mit Keys `ts, task_type, model_class, context_bytes, est_input_tokens, escalated, estimate`. Immer Exit 0 (fail-soft).

- [ ] **Step 1: Failing Test schreiben**

Create `tests/test-cost-trace.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/cost-trace.sh — append-only context/cost trace (v4.7.0).
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CT="$PLUGIN_ROOT/scripts/cost-trace.sh"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

echo "=== cost-trace tests ==="

if [ ! -f "$CT" ]; then
    fail "scripts/cost-trace.sh missing"
    echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
    exit 1
fi
pass "script exists"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MEM="$TMP/.agent-memory"
mkdir -p "$MEM"

# 1. append creates metrics/cost-trace.jsonl with one line
bash "$CT" append --mem "$MEM" --task wrap-up --class cheap-write --context-bytes 8000 --escalated 0
if [ "$?" -eq 0 ]; then pass "append exits 0"; else fail "append must exit 0"; fi
TRACE="$MEM/metrics/cost-trace.jsonl"
if [ -f "$TRACE" ]; then pass "trace file created"; else fail "trace file missing"; fi
n=$(wc -l < "$TRACE" | tr -d ' ')
if [ "$n" -eq 1 ]; then pass "one line after first append"; else fail "expected 1 line, got $n"; fi

# 2. line carries the contract fields (est_input_tokens = bytes/4 = 2000)
LINE=$(head -1 "$TRACE")
for fieldcheck in '"task_type":"wrap-up"' '"model_class":"cheap-write"' '"context_bytes":8000' '"est_input_tokens":2000' '"escalated":0' '"estimate":true' '"ts":"'; do
    if echo "$LINE" | grep -qF "$fieldcheck"; then
        pass "field present: $fieldcheck"
    else
        fail "field missing: $fieldcheck in: $LINE"
    fi
done

# 3. line is valid JSON (python optional, else skip)
PY_BIN=""
command -v python3 > /dev/null 2>&1 && PY_BIN="python3"
[ -z "$PY_BIN" ] && command -v python > /dev/null 2>&1 && PY_BIN="python"
if [ -n "$PY_BIN" ]; then
    if echo "$LINE" | "$PY_BIN" -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
        pass "line is valid JSON"
    else
        fail "line is not valid JSON: $LINE"
    fi
fi

# 4. second append appends (2 lines)
bash "$CT" append --mem "$MEM" --task session-bootstrap --class cheap-write --context-bytes 999 --escalated 1
n=$(wc -l < "$TRACE" | tr -d ' ')
if [ "$n" -eq 2 ]; then pass "two lines after second append"; else fail "expected 2 lines, got $n"; fi
if tail -1 "$TRACE" | grep -qF '"escalated":1'; then pass "escalated=1 recorded"; else fail "escalated flag lost"; fi

# 5. non-numeric context-bytes -> coerced to 0, still exit 0
bash "$CT" append --mem "$MEM" --task x --class standard --context-bytes abc --escalated 0
if [ "$?" -eq 0 ] && tail -1 "$TRACE" | grep -qF '"context_bytes":0'; then
    pass "non-numeric bytes coerced to 0"
else
    fail "non-numeric bytes must coerce to 0 and exit 0"
fi

# 6. fail-soft: unwritable mem dir -> exit 0, warning only
bash "$CT" append --mem "$TMP/does/not/exist/deep" --task x --class standard --context-bytes 1 --escalated 0 2>/dev/null
if [ "$?" -eq 0 ]; then pass "fail-soft exit 0 on bad mem dir"; else fail "must never exit non-zero (fail-soft)"; fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
```

Hinweis: Fall 6 nutzt einen Pfad, dessen Elternverzeichnis erzeugbar wäre — der Fail-soft-Zweig greift, weil `mkdir -p` dort zwar gelingt, aber der Test bleibt gültig: entscheidend ist Exit 0 in jedem Fall.

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `bash tests/test-cost-trace.sh; echo "exit=$?"`
Expected: `FAIL: scripts/cost-trace.sh missing`, Exit 1.

- [ ] **Step 3: Implementierung schreiben**

Create `scripts/cost-trace.sh`:

```bash
#!/usr/bin/env bash
# cost-trace.sh — append-only context/cost trace for routed memory tasks (v4.7.0).
# Spec: docs/superpowers/specs/2026-07-15-model-routing-design.md section 3.6
#
# est_input_tokens = context_bytes / 4. This is an ESTIMATE ("estimate":true):
# Claude Code exposes no real per-run token counts to skills; we trace what is
# deterministically measurable (bytes of files actually read, model class,
# escalation flag). Real token baselines require external telemetry (OTEL).
#
# Fail-soft contract: NEVER exits non-zero, never blocks a skill run.
# Usage:
#   bash scripts/cost-trace.sh append --mem .agent-memory --task wrap-up \
#     --class cheap-write --context-bytes 12345 --escalated 0
set -u

cmd="${1:-}"
shift 2>/dev/null || true

MEM=".agent-memory"
TASK="unknown"
CLASS="unknown"
BYTES="0"
ESC="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mem)            MEM="${2:-.agent-memory}"; shift 2 ;;
    --task)           TASK="${2:-unknown}"; shift 2 ;;
    --class)          CLASS="${2:-unknown}"; shift 2 ;;
    --context-bytes)  BYTES="${2:-0}"; shift 2 ;;
    --escalated)      ESC="${2:-0}"; shift 2 ;;
    *) shift ;;
  esac
done

if [ "$cmd" != "append" ]; then
  echo "usage: cost-trace.sh append --mem DIR --task NAME --class CLASS --context-bytes N --escalated 0|1" >&2
  exit 0  # fail-soft: even usage errors must not break a skill run
fi

# sanitize numerics (non-numeric -> 0) and enum-ish strings (strip quotes/backslashes)
case "$BYTES" in (*[!0-9]*|"") BYTES=0 ;; esac
case "$ESC" in (0|1) : ;; (*) ESC=0 ;; esac
TASK=$(printf '%s' "$TASK" | tr -d '"\\' | cut -c1-64)
CLASS=$(printf '%s' "$CLASS" | tr -d '"\\' | cut -c1-32)
TOKENS=$((BYTES / 4))
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

{
  mkdir -p "$MEM/metrics" &&
  printf '{"ts":"%s","task_type":"%s","model_class":"%s","context_bytes":%s,"est_input_tokens":%s,"escalated":%s,"estimate":true}\n' \
    "$TS" "$TASK" "$CLASS" "$BYTES" "$TOKENS" "$ESC" >> "$MEM/metrics/cost-trace.jsonl"
} 2>/dev/null || echo "cost-trace: append skipped (unwritable $MEM)" >&2

exit 0
```

- [ ] **Step 4: Test laufen lassen — muss bestehen**

Run: `bash tests/test-cost-trace.sh; echo "exit=$?"`
Expected: `=== Results: N/N passed, 0 failures ===`, Exit 0.

- [ ] **Step 5: In run-all.sh registrieren**

In `tests/run-all.sh`, direkt NACH dem in Task 1 eingefügten model-routing-Block:

```bash
# Run cost-trace tests (v4.7.0)
echo ">>> Running cost-trace tests..."
if bash "$SCRIPT_DIR/test-cost-trace.sh"; then
    echo ">>> Cost-trace tests: ALL PASSED"
else
    echo ">>> Cost-trace tests: FAILURES DETECTED"
    ((TOTAL_ERRORS++))
fi

echo ""
```

- [ ] **Step 6: Gesamtsuite grün + Commit**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED`

```bash
git add scripts/cost-trace.sh tests/test-cost-trace.sh tests/run-all.sh
git commit -m "feat(routing): cost-trace.sh — deterministische Kontext-Kostenmessung als JSONL + Tests (v4.7.0 T4)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: wrap-up-Umbau (Stufe 0, Kontextdiät, Delta, Eskalation, Trace)

**Files:**
- Modify: `tests/validate-skills.sh` (Struktur-Assertions, vor der `=== Results ===`-Zeile)
- Modify: `skills/wrap-up/SKILL.md` (Frontmatter aus Task 2 NICHT anfassen; nur Body)

**Interfaces:**
- Consumes: CLI-Verträge aus Task 3 (`preprocess_state.py`) und Task 4 (`cost-trace.sh`), exakt wie dort definiert.
- Produces: Marker `(stage0-preprocess)`, `(context-diet)`, `(delta-update)`, `(escalation-rules)`, `(cost-trace)` im wrap-up-Body; Task 6 verwendet dieselben Escalation-Regeln per Verweis-Formulierung, Task 7 dokumentiert die Marker.

- [ ] **Step 1: Failing Struktur-Assertions schreiben**

In `tests/validate-skills.sh` direkt VOR der Zeile `echo "=== Results: ..."` (nach dem Task-2-Block) einfügen:

```bash
# --- Model-Routing v4.7.0: wrap-up stage-0 + context diet + escalation + trace ---
echo ""
echo "-- wrap-up: stage-0 preprocess, context diet, delta update, escalation, cost trace --"
WU_MR_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU_MR_FILE" ]; then
    if grep -q "(stage0-preprocess)" "$WU_MR_FILE" && grep -q "preprocess_state.py" "$WU_MR_FILE"; then
        pass "wrap-up: (stage0-preprocess) — deterministic preflight via preprocess_state.py"
    else
        fail "wrap-up: missing (stage0-preprocess) — Step 0 must run scripts/preprocess_state.py and use its JSON as primary data source"
    fi
    CD_BLOCK=$(grep -A4 "(context-diet)" "$WU_MR_FILE")
    if echo "$CD_BLOCK" | grep -qi "NOT systematically re-read" && echo "$CD_BLOCK" | grep -qi "targeted"; then
        pass "wrap-up: (context-diet) — no systematic transcript re-read, targeted lookups only"
    else
        fail "wrap-up: missing (context-diet) — must forbid systematic transcript/full-memory re-reads (state object + held context first, targeted lookups only)"
    fi
    DU_BLOCK=$(grep -A4 "(delta-update)" "$WU_MR_FILE")
    if echo "$DU_BLOCK" | grep -qi "delta" && echo "$DU_BLOCK" | grep -qi "unchanged sections"; then
        pass "wrap-up: (delta-update) — session-summary updated as delta, unchanged sections untouched"
    else
        fail "wrap-up: missing (delta-update) — Step 5 must update session-summary.md as a delta (only changed sections), not rewrite the whole file"
    fi
    ER_BLOCK=$(grep -A20 "(escalation-rules)" "$WU_MR_FILE")
    if echo "$ER_BLOCK" | grep -q "escalations-" \
       && echo "$ER_BLOCK" | grep -q "ESKALATION:" \
       && echo "$ER_BLOCK" | grep -qi "contradict" \
       && echo "$ER_BLOCK" | grep -qi "identity" \
       && echo "$ER_BLOCK" | grep -qi "difficult to reverse"; then
        pass "wrap-up: (escalation-rules) — conditions + escalations log + visible marker"
    else
        fail "wrap-up: missing/incomplete (escalation-rules) — must log to working/escalations-<sid>.json, emit ESKALATION: line, and name the conditions (contradiction, identity, decision replacement, pattern promotion, hard-to-reverse, missing sources)"
    fi
    CT_BLOCK=$(grep -A8 "(cost-trace)" "$WU_MR_FILE")
    if echo "$CT_BLOCK" | grep -q "cost-trace.sh" && echo "$CT_BLOCK" | grep -q "cheap-write"; then
        pass "wrap-up: (cost-trace) — run cost logged via cost-trace.sh"
    else
        fail "wrap-up: missing (cost-trace) — end of run must call scripts/cost-trace.sh append with class cheap-write"
    fi
fi
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `bash tests/validate-skills.sh | grep -A1 "stage-0\|context diet\|delta\|escalation\|cost trace" ; bash tests/validate-skills.sh >/dev/null; echo "exit=$?"`
Expected: 5 neue FAIL-Zeilen, Exit 1.

- [ ] **Step 3: wrap-up-Body erweitern**

**(a)** Direkt VOR der Zeile `## Step 1: Gather Session Data` einfügen:

```markdown
## Step 0: Deterministic Preflight (stage0-preprocess)

Run the stage-0 preprocessor FIRST — it gathers every mechanical session fact
without model work:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/preprocess_state.py" .agent-memory --session-id <session-id>
```

Use its JSON output (`changed_files`, `git_diff_summary`, `threshold_events`,
`validation_errors`, `open_tasks`, state hashes) as the PRIMARY data source
for all following steps. If `validation_errors` is non-empty, surface them in
the summary instead of re-validating files by reading them.

(context-diet) Do NOT systematically re-read the session transcript or full
memory files: work from the preprocess state object plus the conversation
context you already hold. Fall back to targeted lookups ONLY for single
unresolved points — never a full re-scan. Track roughly how many bytes of
files you actually read this run; Step 9.5 logs that number.

```

**(b)** In `## Step 5: Update session-summary.md`: direkt NACH der Step-5-Überschriftszeile einfügen:

```markdown
(delta-update) Update session-summary.md as a DELTA against the existing
file: rewrite only sections whose content actually changed this session
(added / updated / resolved items) and keep unchanged sections untouched —
do not regenerate the whole file from scratch.

```

**(c)** Direkt VOR der Zeile `## Handoff Context` einfügen:

```markdown
## Escalation Rules (escalation-rules)

This skill runs on the cheap-write model class (SSoT:
`scripts/model-routing.sh`). The following cases must NOT be resolved by this
skill run itself. When one occurs:

1. Append `{"ts": "...", "task": "wrap-up", "reason": "...", "detail": "..."}`
   to `.agent-memory/working/escalations-<session-id>.json` (create as JSON
   array if missing).
2. Emit a visible `ESKALATION: <reason>` line in the output.
3. Leave the decision itself to the next turn on the session model.

Escalate when:
- two active sources contradict each other,
- a change would touch identity or stable user preferences (identity writes
  additionally stay behind the existing [j/n] gates),
- an active decision record would be replaced,
- a pattern would be promoted into a skill or Agentic-OS rule,
- a change is difficult to reverse,
- required sources are missing.

```

**(d)** In `## Step 9.5: Consolidation Marker + Dirty Reset (consolidation-marker)`: ans ENDE der Step-9.5-Sektion (vor der nächsten `##`-Überschrift) anfügen:

```markdown
(cost-trace) Finally, log the run trace and refresh the state hash (both
fail-soft, never blocking):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cost-trace.sh" append --mem .agent-memory \
  --task wrap-up --class cheap-write \
  --context-bytes <approx bytes of files read this run> --escalated <0|1>
python "${CLAUDE_PLUGIN_ROOT}/scripts/preprocess_state.py" .agent-memory --write-hash > /dev/null
```

```

- [ ] **Step 4: Tests laufen lassen — müssen bestehen**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED` — auch die bestehenden wrap-up-Sprach-/Marker-Tests (die neuen Texte sind englisch; `ESKALATION:` steht nicht in den verbotenen Grep-Listen).

- [ ] **Step 5: Commit**

```bash
git add tests/validate-skills.sh skills/wrap-up/SKILL.md
git commit -m "feat(routing): wrap-up — Stufe-0-Preflight, Kontextdiaet, Delta-Update, Eskalationsregeln, Cost-Trace (v4.7.0 T5)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: session-bootstrap-Umbau (Fast Path, Eskalation, Trace)

**Files:**
- Modify: `tests/validate-skills.sh` (Struktur-Assertions, vor der `=== Results ===`-Zeile)
- Modify: `skills/session-bootstrap/SKILL.md` (nur Body)

**Interfaces:**
- Consumes: CLI-Verträge aus Task 3/4; Marker-Konvention aus Task 5.
- Produces: Marker `(bootstrap-fast-path)`, `(escalation-rules)`, `(cost-trace)` im bootstrap-Body.

- [ ] **Step 1: Failing Struktur-Assertions schreiben**

In `tests/validate-skills.sh` direkt VOR der `=== Results ===`-Zeile (nach dem Task-5-Block) einfügen:

```bash
# --- Model-Routing v4.7.0: session-bootstrap fast path + escalation + trace ---
echo ""
echo "-- session-bootstrap: fast path, escalation, cost trace --"
SB_MR_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
if [ -f "$SB_MR_FILE" ]; then
    FP_BLOCK=$(grep -A16 "(bootstrap-fast-path)" "$SB_MR_FILE")
    if echo "$FP_BLOCK" | grep -q "preprocess_state.py" \
       && echo "$FP_BLOCK" | grep -q "previous_state_hash" \
       && echo "$FP_BLOCK" | grep -qi "skip the full knowledge load" \
       && echo "$FP_BLOCK" | grep -qi "health checks.*still run"; then
        pass "session-bootstrap: (bootstrap-fast-path) — hash short-circuit skips full load, health checks kept"
    else
        fail "session-bootstrap: missing/incomplete (bootstrap-fast-path) — must run preprocess_state.py, compare previous_state_hash == current_state_hash, skip the full knowledge load on equality while health checks still run"
    fi
    SB_ER_BLOCK=$(grep -A12 "(escalation-rules)" "$SB_MR_FILE")
    if echo "$SB_ER_BLOCK" | grep -q "escalations-" && echo "$SB_ER_BLOCK" | grep -q "ESKALATION:"; then
        pass "session-bootstrap: (escalation-rules) — escalations log + visible marker"
    else
        fail "session-bootstrap: missing (escalation-rules) — conflicts/stale states found during bootstrap must be logged to working/escalations-<sid>.json and flagged with ESKALATION:, not resolved by this run"
    fi
    SB_CT_BLOCK=$(grep -A8 "(cost-trace)" "$SB_MR_FILE")
    if echo "$SB_CT_BLOCK" | grep -q "cost-trace.sh" && echo "$SB_CT_BLOCK" | grep -q "session-bootstrap"; then
        pass "session-bootstrap: (cost-trace) — run cost logged via cost-trace.sh"
    else
        fail "session-bootstrap: missing (cost-trace) — end of briefing must call scripts/cost-trace.sh append --task session-bootstrap"
    fi
fi
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `bash tests/validate-skills.sh >/dev/null; echo "exit=$?"`
Expected: Exit 1 (3 neue FAILs).

- [ ] **Step 3: session-bootstrap-Body erweitern**

**(a)** Direkt VOR der Zeile `## Step 2: Load Knowledge Files` einfügen:

```markdown
## Step 1.5: Deterministic Preflight + Fast Path (bootstrap-fast-path)

Run the stage-0 preprocessor:

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/preprocess_state.py" .agent-memory
```

FAST PATH: if `previous_state_hash == current_state_hash` (both non-empty)
AND `changed_files` is empty, the memory store is unchanged since the last
consolidated wrap-up. Then load ONLY `session-summary.md` and
`context/open-tasks.json`, skip the full knowledge load of Step 2, and state
in the briefing: "Memory unchanged since last session — briefing served from
existing state." Health checks (Step 3) still run in both paths.

Otherwise continue with Step 2 normally, preferring the files named in
`changed_files` and surfacing `validation_errors` / `threshold_events` from
the preprocess output instead of re-deriving them.

```

**(b)** Direkt VOR der Zeile `## Error Handling` einfügen:

```markdown
## Escalation Rules (escalation-rules)

This skill runs on the cheap-write model class (SSoT:
`scripts/model-routing.sh`). If the bootstrap surfaces contradicting active
records, an unresolvable stale state, or anything from the wrap-up escalation
list, do NOT resolve it in this run: append `{"ts", "task": "session-bootstrap",
"reason", "detail"}` to `.agent-memory/working/escalations-<session-id>.json`,
emit a visible `ESKALATION: <reason>` line in the briefing, and leave the
decision to the next turn on the session model.

(cost-trace) After the briefing is produced, log the run trace (fail-soft):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cost-trace.sh" append --mem .agent-memory \
  --task session-bootstrap --class cheap-write \
  --context-bytes <approx bytes of files read this run> --escalated <0|1>
```

```

- [ ] **Step 4: Tests laufen lassen — müssen bestehen**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED` (inkl. der bestehenden bootstrap-Tests: staleness-wrap, soul-gate, Sprach-Checks — neue Texte sind englisch und read-only-konform).

- [ ] **Step 5: Commit**

```bash
git add tests/validate-skills.sh skills/session-bootstrap/SKILL.md
git commit -m "feat(routing): session-bootstrap — Hash-Fast-Path, Eskalationsregeln, Cost-Trace (v4.7.0 T6)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Doku, Eval-Checkliste, Versions-Bump, Release

**Files:**
- Create: `docs/model-routing-eval-checklist.md`
- Modify: `CLAUDE.md` (Architecture-Block + Key Conventions)
- Modify: `.claude-plugin/plugin.json` (Version + Description)
- Modify: `docs/superpowers/specs/2026-07-15-model-routing-design.md` (Script-Namens-Abgleich)

**Interfaces:**
- Consumes: alle Artefakte aus Task 1–6 (fertig und grün).
- Produces: Release-Zustand v4.7.0.

- [ ] **Step 1: Eval-Checkliste anlegen**

Create `docs/model-routing-eval-checklist.md`:

```markdown
# Model-Routing v4.7.0 — Manual Eval Checklist

The spec's model-dependent test cases (memospartoken.md section 24) cannot be
asserted by bash tests without faking model behavior. They are checked
manually after release, one real session each. Record results as an
iteration-log entry.

| # | Spec case | Procedure | Pass criterion |
|---|---|---|---|
| E1 | 24.3 short wrap-up | Run wrap-up after a small session (1-2 file edits, no conflicts) | Handoff + candidates produced WITHOUT any `ESKALATION:` line; `metrics/cost-trace.jsonl` gained one wrap-up row |
| E2 | 24.5 contradicting decisions | Seed two active, contradicting decision records, run wrap-up | wrap-up does NOT resolve the conflict; `working/escalations-<sid>.json` has an entry; visible `ESKALATION:` line |
| E3 | 24.6 identity candidate | State a plausible stable preference in-session, run wrap-up | Preference lands ONLY in `working/user-candidates.json` (queue), never directly in `identity/user.md` |
| E4 | 24.1 unchanged bootstrap | wrap-up (writes state-hash), then new session, run session-bootstrap without touching memory | Briefing says "Memory unchanged since last session"; full knowledge load skipped; health checks still ran |
| E5 | 24.4 long wrap-up | Run wrap-up after a long session with large tool outputs | Summary quality unchanged vs. pre-4.7.0 sessions; no full transcript re-scan observable; `context_bytes` in trace clearly below total transcript size |

Quality gate (spec section 22): if E1-E5 show information loss vs. the
previous flow (missing decisions, lost open tasks, wrong classifications),
revert the model downgrade for the affected skill in BOTH
`scripts/model-routing.sh` and the skill frontmatter (consistency test keeps
them honest) and record the finding as a learning.
```

- [ ] **Step 2: CLAUDE.md aktualisieren**

**(a)** Im Architecture-Codeblock die `scripts/`-Zeile ersetzen:

Alt:
```
scripts/                   → Hook helpers + SSoT scripts (session-start.sh, mem-schema.sh, memory-thresholds.sh = Threshold-SSoT, learnings_top.py = Salience-Ranking, pretooluse-shell-circuit-breaker.sh, posttooluse-dirty-tracker.py = Dirty-State-SSoT)
```

Neu:
```
scripts/                   → Hook helpers + SSoT scripts (session-start.sh, mem-schema.sh, memory-thresholds.sh = Threshold-SSoT, model-routing.sh = Modellklassen-SSoT, preprocess_state.py = Stufe-0-Zustandsobjekt, cost-trace.sh = Kontext-Kostentrace, learnings_top.py = Salience-Ranking, pretooluse-shell-circuit-breaker.sh, posttooluse-dirty-tracker.py = Dirty-State-SSoT)
```

**(b)** In `## Key Conventions` als neuen Bullet (nach dem MCP-Tool-Bridge-Policy-Bullet) einfügen:

```markdown
- **Model-Routing Policy (v4.7.0):** Routine skills run on the cheap-write class (`model: sonnet` frontmatter); the class table lives ONLY in `scripts/model-routing.sh` (SSoT — a validate-skills test enforces frontmatter consistency). wrap-up/session-bootstrap run stage-0 preprocessing (`scripts/preprocess_state.py`) first and obey the (context-diet)/(bootstrap-fast-path) rules; conflicts, identity changes, decision replacements, and pattern-to-skill promotions are never resolved on the cheap class — they escalate via `working/escalations-<sid>.json` + `ESKALATION:` marker to the session model. Run costs are traced to `.agent-memory/metrics/cost-trace.jsonl` (estimates). Design: `docs/superpowers/specs/2026-07-15-model-routing-design.md`, manual evals: `docs/model-routing-eval-checklist.md`.
```

- [ ] **Step 3: Design-Doc-Abgleich (Script-Name)**

In `docs/superpowers/specs/2026-07-15-model-routing-design.md` alle Vorkommen von `preprocess-state.sh` durch `preprocess_state.py` ersetzen (Abschnitte 3.3/3.4/4.2) und in §3.3 den Klammerzusatz ergänzen: `(Python statt Bash — robustes JSON, Muster posttooluse-dirty-tracker.py)`.

- [ ] **Step 4: plugin.json auf 4.7.0 bumpen**

`.claude-plugin/plugin.json`: `"version": "4.6.1"` → `"version": "4.7.0"` und in der Description nach `scaling thresholds live in one SSoT script.` einfügen: `Cost-aware model routing: routine skills declare model/effort frontmatter (class SSoT in model-routing.sh), stage-0 preprocessing + escalation rules keep quality, cost-trace.jsonl records context estimates.`

- [ ] **Step 5: Gesamtsuite + Abschluss-Commit**

Run: `bash tests/run-all.sh`
Expected: `ALL TEST SUITES PASSED`

```bash
git add docs/model-routing-eval-checklist.md CLAUDE.md .claude-plugin/plugin.json docs/superpowers/specs/2026-07-15-model-routing-design.md
git commit -m "feat(routing): Release v4.7.0 — Doku, Eval-Checkliste, Versions-Bump (T7)

Kosten-/tokenbewusstes Modell-Routing: deklaratives Routing via Frontmatter
(SSoT model-routing.sh), Stufe-0-Preprocessing, Eskalationsregeln, Cost-Trace.
Spec-Basis: memospartoken.md (P1-P4 abgespeckt), Design-Doc im Repo.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Verifikation Release-Zustand**

Run: `git log --oneline -8 && grep '"version"' .claude-plugin/plugin.json && bash scripts/model-routing.sh list | head -3`
Expected: 7 Task-Commits sichtbar, Version 4.7.0, TSV-Ausgabe beginnt mit `wrap-up	cheap-write	sonnet	medium`.
