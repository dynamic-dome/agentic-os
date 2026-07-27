#!/usr/bin/env python3
"""Tests for scripts/apply_wrapup.py — batch writer for the wrap-up skill.

Every case runs against a throwaway memory dir under tempfile.mkdtemp().
The real .agent-memory is never touched.

Exit codes: 0 = all pass, 1 = failures found.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "apply_wrapup.py")

TESTS = PASSED = ERRORS = 0


def pass_(msg):
    global TESTS, PASSED
    TESTS += 1
    PASSED += 1
    print(f"  PASS: {msg}")


def fail(msg):
    global TESTS, ERRORS
    TESTS += 1
    ERRORS += 1
    print(f"  FAIL: {msg}")


def check(cond, msg):
    pass_(msg) if cond else fail(msg)


def make_mem() -> str:
    mem = tempfile.mkdtemp(prefix="wrapup-test-")
    for d in ("learnings", "working", "identity", "context"):
        os.makedirs(os.path.join(mem, d), exist_ok=True)
    put(mem, "learnings/learnings.json", [{
        "id": "L1", "date": "2026-01-01", "text": "Bestehendes Learning",
        "importance": 4, "tags": ["x"], "layer": "short-term",
        "superseded_by": None, "last_relevant": "2026-01-01",
    }])
    put(mem, "working/user-candidates.json", [
        {"id": "UC1", "key": "reif", "observation": "Reifer Kandidat", "status": "inferred",
         "signal_type": "preference", "confidence": 0.7, "occurrences": 2,
         "evidence": ["s1"], "first_seen": "2026-07-01", "last_seen": "2026-07-01",
         "trust_source": "conversation"},
        {"id": "UC2", "key": "unreif", "observation": "Unreifer Kandidat", "status": "inferred",
         "signal_type": "preference", "confidence": 0.3, "occurrences": 1,
         "evidence": ["s1"], "first_seen": "2026-07-01", "last_seen": "2026-07-01",
         "trust_source": "conversation"},
    ])
    put(mem, "context/open-tasks.json", [{
        "id": "T-001", "title": "Alte Aufgabe", "status": "open", "created": "2026-07-01",
        "updated": "2026-07-01", "resolution": None, "source": "x", "cross_project": False,
    }])
    put(mem, "identity/user-changelog.json", [])
    write(mem, "identity/user.md",
          "# User Profile\n\n## Preferences\n\n- Handgeschriebene Zeile\n\n"
          "## Work Style\n\n## Known Corrections\n")
    # Files owned by OTHER skills - must stay byte-identical.
    put(mem, "iterations/errors.json", [{"id": "E1"}])
    put(mem, "patterns/patterns.json", [{"id": "P1"}])
    put(mem, "context/decisions.json", [{"id": "D1"}])
    write(mem, "identity/soul.md", "# Soul\n\n- unantastbar\n")
    put(mem, "working/dirty-sess-A.json", {
        "session_id": "sess-A", "agent": "main", "dirty": True,
        "started": "2026-07-27T10:00:00", "updated": "2026-07-27T11:00:00",
        "touched_files": ["a.py", "b.py"], "write_count": 2,
        "consolidated_at": None, "consolidated_by": None,
    })
    return mem


def put(mem, rel, data):
    write(mem, rel, json.dumps(data, indent=2) + "\n")


def write(mem, rel, text):
    path = os.path.join(mem, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def read(mem, rel):
    with open(os.path.join(mem, rel), encoding="utf-8") as fh:
        return fh.read()


def load(mem, rel):
    return json.loads(read(mem, rel))


def run(mem, plan, *extra):
    proc = subprocess.run(
        [sys.executable, SCRIPT, mem, "--session-id", "sess-A", *extra],
        input=json.dumps(plan), capture_output=True, text=True, encoding="utf-8",
    )
    try:
        return proc.returncode, json.loads(proc.stdout)
    except json.JSONDecodeError:
        return proc.returncode, {"_stdout": proc.stdout, "_stderr": proc.stderr}


print("=== apply_wrapup tests ===")

if not os.path.isfile(SCRIPT):
    fail("scripts/apply_wrapup.py missing")
    print(f"=== Results: {PASSED}/{TESTS} passed, {ERRORS} failures ===")
    sys.exit(1)
pass_("script exists")

# --- 1. learnings: append, dedup, projection --------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "learnings": [
    {"text": "Neues Learning", "importance": 5, "tags": ["t"]},
    {"text": "  bestehendes   LEARNING ", "importance": 2},
]})
check(rc == 0, "exit 0 on a valid plan")
check(out["tally"]["learnings_added"] == 1, "new learning appended")
check(out["tally"]["learnings_skipped_duplicate"] == 1,
      "duplicate learning skipped (whitespace/case-insensitive)")
rows = load(mem, "learnings/learnings.json")
new = [r for r in rows if r["id"] == "L2"][0]
check(new["review_after"] == "2026-10-25", "review_after = date + 90 days")
check(new["layer"] == "short-term" and new["superseded_by"] is None,
      "learning defaults match the schema")
md = read(mem, "learnings/learnings.md")
check("L2" in md and "L1" in md, "learnings.md is a full projection of learnings.json")
check(md.index("## Importance 5") < md.index("## Importance 4"),
      "learnings.md sorted by importance descending")

# --- 2. trust boundary + mood block -----------------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "user_candidates": [
    {"key": "aus-web", "observation": "Von einer Webseite", "trust_source": "web"},
    {"key": "laune", "observation": "War genervt", "signal_type": "mood", "confirmed": True},
]})
check(out["tally"]["candidates_rejected_trust"] == 1,
      "trust_source != conversation is rejected (poisoning defense)")
keys = {c["key"] for c in load(mem, "working/user-candidates.json")}
check("aus-web" not in keys, "rejected candidate never reaches the queue")
laune_id = [c["id"] for c in load(mem, "working/user-candidates.json") if c["key"] == "laune"][0]
check(laune_id not in out["tally"]["promoted_ids"],
      "signal_type=mood is never promoted, even when confirmed")
laune = [c for c in load(mem, "working/user-candidates.json") if c["key"] == "laune"][0]
check(laune["status"] == "confirmed", "mood candidate is still recorded, just not promoted")

# --- 3. promotion rule + changelog ordering ---------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "user_candidates": []})
promoted = {c["key"]: c["status"] for c in load(mem, "working/user-candidates.json")}
check(promoted["reif"] == "promoted",
      "inferred + occurrences>=2 + confidence>=0.6 promotes")
check(promoted["unreif"] == "inferred",
      "inferred + occurrences=1 + low confidence does NOT promote")
check(out["tally"]["candidates_promoted"] == 1, "full queue re-review runs without new input")
log = load(mem, "identity/user-changelog.json")
check(len(log) == 1 and log[0]["candidate_id"] == "UC1", "changelog entry written for promotion")
check(log[0]["field"] == "user.md/Preferences", "changelog names the target section")
user_md = read(mem, "identity/user.md")
check("Handgeschriebene Zeile" in user_md, "pre-existing user.md content is preserved")
check("Reifer Kandidat" in user_md, "promoted candidate lands in user.md")
check(user_md.count("## Preferences") == 1, "user.md sections are not duplicated")

# --- 4. occurrence increment escalates status -------------------------------
mem = make_mem()
run(mem, {"date": "2026-07-27", "user_candidates": [
    {"key": "unreif", "observation": "Unreifer Kandidat", "signal_type": "preference"},
]})
q = {c["key"]: c for c in load(mem, "working/user-candidates.json")}
check(q["unreif"]["occurrences"] == 2, "repeat observation increments occurrences")
check(q["unreif"]["status"] == "promoted",
      "repeated 2x -> confirmed -> promoted in the same run")

# --- 5. other skills' files are untouchable ---------------------------------
mem = make_mem()
before = {f: read(mem, f) for f in ("iterations/errors.json", "patterns/patterns.json",
                                    "context/decisions.json", "identity/soul.md")}
run(mem, {"date": "2026-07-27", "learnings": [{"text": "irgendwas", "importance": 3}],
          "soul_candidates": [{"proposal": "Ein Vorschlag", "evidence": ["e"]}]})
check(all(read(mem, f) == b for f, b in before.items()),
      "errors.json / patterns.json / decisions.json / soul.md stay byte-identical")
check(os.path.exists(os.path.join(mem, "identity/soul-candidates.md")),
      "soul proposals go to soul-candidates.md, never soul.md")

# --- 6. open tasks -----------------------------------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "open_tasks": {
    "add": [{"title": "Neue Aufgabe"}, {"title": "Alte Aufgabe"}], "close": ["T-001"]}})
tasks = {t["title"]: t for t in load(mem, "context/open-tasks.json")}
check(out["tally"]["tasks_added"] == 1 and out["tally"]["tasks_skipped_duplicate"] == 1,
      "duplicate open task title is skipped")
check(tasks["Alte Aufgabe"]["status"] == "closed", "close list closes the task")
check(tasks["Neue Aufgabe"]["id"] == "T-002", "new task id keeps the T-00n format")

# --- 7. consolidation marker + dirty reset ----------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "consolidate": True, "iterations_logged": 3})
marker = load(mem, "consolidation-marker.json")
check(marker["consolidated_sessions"] == ["sess-A"], "marker records the consolidated session")
check(marker["touched_files_seen"] == 2, "marker counts touched files from the dirty file")
check(marker["iterations_logged"] == 3, "marker carries iterations_logged from the plan")
d = load(mem, "working/dirty-sess-A.json")
check(d["dirty"] is False and d["consolidated_by"] == "wrap-up", "dirty flag flipped, file kept")

# --- 8. failure => no marker, honest dirty state ----------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27",
                    "learnings": [{"text": "", "importance": 3}], "consolidate": True})
check(rc == 2, "malformed plan exits 2")
check(out.get("ok") is False, "malformed plan reports ok=false")
check(not os.path.exists(os.path.join(mem, "consolidation-marker.json")),
      "no consolidation marker written when a step failed")
check(load(mem, "working/dirty-sess-A.json")["dirty"] is True,
      "dirty state stays honest after a failure")

# --- 9. dry-run writes nothing ----------------------------------------------
mem = make_mem()
before = read(mem, "learnings/learnings.json")
rc, out = run(mem, {"date": "2026-07-27", "learnings": [{"text": "Nur ein Test", "importance": 3}],
                    "consolidate": True}, "--dry-run")
check(rc == 0 and out["dry_run"] is True, "dry-run exits 0 and reports dry_run=true")
check(read(mem, "learnings/learnings.json") == before, "dry-run leaves files unchanged")
check(out["tally"]["learnings_added"] == 1, "dry-run still reports what it would do")

# --- 10. status line reports measured numbers -------------------------------
mem = make_mem()
rc, out = run(mem, {"date": "2026-07-27", "user_candidates": [
    {"key": "neu", "observation": "Neue Beobachtung", "signal_type": "workflow"}]})
line = out["identity_status_line"]
check(line.startswith("Identity: ") and "user.md promotet" in line,
      "identity status line matches the mandatory Step 6.5 format")
check("1 → user.md promotet" in line, "status line numbers come from the applied writes")

# --- 11. corrupt JSON is quarantined, not fatal -----------------------------
mem = make_mem()
write(mem, "learnings/learnings.json", "{ this is not json")
rc, out = run(mem, {"date": "2026-07-27", "learnings": [{"text": "Nach Korruption", "importance": 3}]})
check(rc == 0, "corrupt input file does not abort the run")
check(os.path.exists(os.path.join(mem, "learnings/learnings.json.corrupt.bak")),
      "corrupt file quarantined as .corrupt.bak")
check(load(mem, "learnings/learnings.json")[0]["id"] == "L1",
      "fresh file created after quarantine")

for tmp in []:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"=== Results: {PASSED}/{TESTS} passed, {ERRORS} failures ===")
sys.exit(1 if ERRORS else 0)
