#!/usr/bin/env python3
"""Tests for scripts/extract_patterns.py — deterministic half of pattern-extractor.

T-015 delegation rebuild: wrap-up Step 4 no longer injects the pattern-extractor
skill body to get patterns written. The detection heuristics, the confidence
formula, the Jaccard dedup and the patterns.md projection are all spelled out as
exact thresholds in the skill — so they belong in code, where they can be tested.
Only the WORDING of a new pattern (description/recommendation) stays with the
model and arrives through --apply.

Every case runs against a throwaway memory dir. The real .agent-memory is never
touched.

Exit codes: 0 = all pass, 1 = failures found.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "extract_patterns.py")

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


def write(mem, rel, text):
    path = os.path.join(mem, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def put(mem, rel, data):
    write(mem, rel, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def read(mem, rel):
    with open(os.path.join(mem, rel), encoding="utf-8") as fh:
        return fh.read()


def load(mem, rel):
    return json.loads(read(mem, rel))


def err(eid, date, category, tags, root_cause="Ursache X", occ=1, prevention="p"):
    return {
        "id": eid, "date": date, "category": category, "tags": list(tags),
        "trigger": "t", "problem": "p", "root_cause": root_cause, "fix": "f",
        "prevention": prevention, "severity": "major", "occurrences": occ,
        "recurrence_dates": [], "last_seen": date,
    }


def make_mem(errors=None, patterns=None, log=None) -> str:
    mem = tempfile.mkdtemp(prefix="patterns-test-")
    for d in ("iterations", "patterns", "context", "identity"):
        os.makedirs(os.path.join(mem, d), exist_ok=True)
    put(mem, "iterations/errors.json", errors if errors is not None else [])
    put(mem, "patterns/patterns.json", patterns if patterns is not None else [])
    write(mem, "iterations/iteration-log.md", log or "# Iteration Log\n")
    # Files this script must never touch.
    put(mem, "context/decisions.json", [{"id": "D-001"}])
    put(mem, "learnings/learnings.json", [{"id": "L1"}])
    write(mem, "identity/soul.md", "# Soul\n")
    return mem


def run(mem, *extra, plan=None):
    proc = subprocess.run(
        [sys.executable, SCRIPT, mem, *extra],
        input=json.dumps(plan) if plan is not None else "",
        capture_output=True, text=True, encoding="utf-8",
    )
    try:
        return proc.returncode, json.loads(proc.stdout)
    except json.JSONDecodeError:
        return proc.returncode, {"_stdout": proc.stdout, "_stderr": proc.stderr}


print("=== extract_patterns tests ===")

if not os.path.isfile(SCRIPT):
    fail("scripts/extract_patterns.py missing")
    print(f"=== Results: {PASSED}/{TESTS} passed, {ERRORS} failures ===")
    sys.exit(1)
pass_("script exists")

# --- 1. minimum data guard --------------------------------------------------
mem = make_mem(errors=[err("err-001", "2026-07-01", "import", ["python", "a"])])
rc, out = run(mem, "--update")
check(rc == 0, "too little data is not an error")
check(out["ok"] is True and out.get("skipped") == "not-enough-data",
      "with <3 errors and no patterns the run reports not-enough-data")
check(out["proposals"] == [] and out["files_written"] == [],
      "not-enough-data writes nothing and proposes nothing")

# --- 2. tag-overlap cluster becomes a proposal ------------------------------
# err-001/err-002 share a root_cause on purpose (that is the +0.1 booster in
# test 3); err-003 must differ, otherwise it would join a root-cause cluster.
errors = [
    err("err-001", "2026-07-01", "import", ["python", "circular-import", "modules"]),
    err("err-002", "2026-07-05", "import", ["python", "circular-import", "startup"]),
    err("err-003", "2026-07-09", "runtime", ["node", "timeout"], root_cause="Ganz andere Sache"),
]
mem = make_mem(errors=errors)
rc, out = run(mem, "--update")
props = out["proposals"]
check(len(props) == 1, "one cluster proposed (same category + 2 overlapping tags)")
check(sorted(props[0]["evidence"]) == ["err-001", "err-002"],
      "proposal carries the clustered error ids as evidence")
check(props[0]["type"] == "anti-pattern", "error cluster is typed as anti-pattern")
check(props[0]["cluster_key"], "proposal has a stable cluster_key for the --apply round")
check(out["files_written"] == [], "--update proposes new clusters, it does not invent wording")
check("err-003" in out["unmatched_errors"], "unclustered error is reported as unmatched")

# --- 3. confidence formula (exact, from the skill) --------------------------
# base 0.3 + 0.1 per occurrence beyond the first (max +0.3) + 0.1 root_cause
# match + 0.1 same prevention + 0.1 across multiple dates. Two errors, same
# root_cause and prevention, different dates -> 0.3 +0.1 +0.1 +0.1 +0.1 = 0.7
check(abs(props[0]["confidence"] - 0.7) < 1e-9,
      f"confidence computed from the formula, not guessed (got {props[0]['confidence']})")

# --- 4. an error with occurrences >= 3 is a confirmed anti-pattern alone ----
mem = make_mem(errors=[
    err("err-001", "2026-07-01", "config", ["yaml", "path"], occ=4, root_cause="Pfad falsch"),
    err("err-002", "2026-07-02", "runtime", ["node", "x"], root_cause="Timeout fehlt"),
    err("err-003", "2026-07-03", "build", ["docker", "y"], root_cause="Layer kaputt"),
])
rc, out = run(mem, "--update")
solo = [p for p in out["proposals"] if p["evidence"] == ["err-001"]]
check(len(solo) == 1, "a single error with occurrences>=3 is a pattern candidate on its own")
check(solo[0]["occurrences"] == 4, "recurring error carries its own occurrence count")

# --- 5. --apply writes the model's wording onto the measured facts ----------
mem = make_mem(errors=errors)
rc, props_out = run(mem, "--update")
key = props_out["proposals"][0]["cluster_key"]
rc, out = run(mem, "--apply", plan={"patterns": [{
    "cluster_key": key, "description": "Zirkulaere Imports in Python-Modulen",
    "recommendation": "Importe ans Funktionsende ziehen", "severity": "major",
}]})
pats = load(mem, "patterns/patterns.json")
check(rc == 0 and len(pats) == 1, "--apply appends the new pattern")
check(pats[0]["id"] == "P001", "new pattern id follows the P00n sequence")
check(pats[0]["description"] == "Zirkulaere Imports in Python-Modulen",
      "wording comes from the plan")
check(pats[0]["evidence"] == ["err-001", "err-002"] and abs(pats[0]["confidence"] - 0.7) < 1e-9,
      "evidence and confidence come from the MEASUREMENT, not from the plan")
check(pats[0]["lifecycle"] == "active" and pats[0]["implemented_by"] == []
      and pats[0]["validated_at"] is None,
      "new pattern starts with honest empty feedback-loop fields")

# --- 6. plan cannot forge the numbers ---------------------------------------
mem = make_mem(errors=errors)
rc, props_out = run(mem, "--update")
key = props_out["proposals"][0]["cluster_key"]
rc, out = run(mem, "--apply", plan={"patterns": [{
    "cluster_key": key, "description": "d", "recommendation": "r",
    "confidence": 0.99, "occurrences": 99, "evidence": ["erfunden"],
}]})
p = load(mem, "patterns/patterns.json")[0]
check(abs(p["confidence"] - 0.7) < 1e-9 and p["evidence"] == ["err-001", "err-002"],
      "model-supplied confidence/evidence are ignored in favour of the measurement")

# --- 7. unknown cluster_key is rejected -------------------------------------
mem = make_mem(errors=errors)
rc, out = run(mem, "--apply", plan={"patterns": [
    {"cluster_key": "gibt-es-nicht", "description": "d", "recommendation": "r"}]})
check(rc == 2 and out.get("ok") is False, "unknown cluster_key is a plan error")
check(load(mem, "patterns/patterns.json") == [], "rejected plan writes no pattern")

# --- 8. existing pattern is updated, not duplicated -------------------------
existing = [{
    "id": "P001", "type": "anti-pattern",
    "description": "Zirkulaere Imports in Python-Modulen",
    "evidence": ["err-001"], "confidence": 0.4, "severity": "major",
    "tags": ["python", "circular-import"], "source_projects": ["current-project"],
    "first_seen": "2026-07-01", "last_seen": "2026-07-01", "occurrences": 1,
    "recommendation": "Alte Empfehlung", "skill_candidate": False, "lifecycle": "active",
}]
mem = make_mem(errors=errors, patterns=existing)
rc, out = run(mem, "--update")
pats = load(mem, "patterns/patterns.json")
check(len(pats) == 1, "matching cluster updates the existing pattern instead of adding one")
check(sorted(pats[0]["evidence"]) == ["err-001", "err-002"], "evidence arrays are merged")
check(pats[0]["last_seen"] == "2026-07-05" and abs(pats[0]["confidence"] - 0.7) < 1e-9,
      "last_seen and confidence are recomputed on update")
check(pats[0]["recommendation"] == "Alte Empfehlung",
      "the model's wording is never overwritten by an update")
check(out["tally"]["patterns_updated"] == 1 and out["proposals"] == [],
      "an updated cluster is not proposed a second time")

# --- 9. skill_candidate gate (occurrences >= 3 AND confidence >= 0.7) -------
many = [
    err("err-001", "2026-07-01", "import", ["python", "circular-import", "a"]),
    err("err-002", "2026-07-05", "import", ["python", "circular-import", "b"]),
    err("err-003", "2026-07-09", "import", ["python", "circular-import", "c"]),
]
mem = make_mem(errors=many)
rc, out = run(mem, "--update")
key = out["proposals"][0]["cluster_key"]
rc, out = run(mem, "--apply", plan={"patterns": [
    {"cluster_key": key, "description": "d", "recommendation": "r"}]})
p = load(mem, "patterns/patterns.json")[0]
check(p["occurrences"] == 3 and p["confidence"] >= 0.7 and p["skill_candidate"] is True,
      "skill_candidate set when occurrences>=3 AND confidence>=0.7")
check("P001" in out["skill_candidates"], "skill candidates are reported for the Step 6.5 handoff")

# --- 10. legacy entries are normalized in place -----------------------------
# Evidence points at the UNCLUSTERED error on purpose: this case tests the
# shape conversion alone, without an update merging fresh evidence into it.
legacy = [
    {"id": "pattern-001", "title": "Alter Titel", "prevention": "Alte Praevention",
     "error_ids": ["err-003"], "confidence": 0.5, "tags": ["python"], "type": "anti-pattern"},
    {"id": "P002", "name": "Zweiter", "solution": "Loesung", "source_errors": ["err-003"],
     "confidence": 0.5, "tags": ["node"], "type": "anti-pattern"},
]
mem = make_mem(errors=errors, patterns=legacy)
rc, out = run(mem, "--update")
pats = {p["id"]: p for p in load(mem, "patterns/patterns.json")}
check("pattern-001" not in pats, "legacy id is renumbered into the P{n} sequence")
check(any(p.get("previous_id") == "pattern-001" for p in pats.values()),
      "renumbered entry keeps previous_id for provenance")
norm = [p for p in pats.values() if p.get("previous_id") == "pattern-001"][0]
check(norm.get("recommendation") == "Alte Praevention" and "prevention" not in norm,
      "prevention -> recommendation (renamed, value kept)")
check(norm.get("evidence") == ["err-003"] and "error_ids" not in norm,
      "error_ids -> evidence")
check("Alter Titel" in norm.get("description", ""), "title -> description")
check(pats["P002"].get("recommendation") == "Loesung"
      and pats["P002"].get("evidence") == ["err-003"],
      "solution -> recommendation and source_errors -> evidence")
check(out["tally"]["patterns_normalized"] == 2, "tally counts normalized legacy entries")

# --- 11. patterns.md is a pure projection -----------------------------------
mem = make_mem(errors=errors, patterns=existing)
run(mem, "--update")
md = read(mem, "patterns/patterns.md")
check(md.startswith("# Pattern Catalog"), "patterns.md keeps its canonical header")
check("Zirkulaere Imports" in md and "P001" in md, "patterns.md renders the catalog entries")
check("High Confidence" in md, "patterns.md keeps the confidence sections")

# --- 12. this script only ever writes patterns/ -----------------------------
mem = make_mem(errors=errors, patterns=existing)
before = {f: read(mem, f) for f in ("iterations/errors.json", "context/decisions.json",
                                    "learnings/learnings.json", "identity/soul.md",
                                    "iterations/iteration-log.md")}
rc, out = run(mem, "--update")
check(all(read(mem, f) == b for f, b in before.items()),
      "errors.json / decisions.json / learnings.json / soul.md / iteration-log.md untouched")
check(out["files_written"] and all(f.startswith("patterns/") for f in out["files_written"]),
      "files_written never leaves patterns/")

# --- 13. dry-run ------------------------------------------------------------
mem = make_mem(errors=errors, patterns=existing)
before = read(mem, "patterns/patterns.json")
rc, out = run(mem, "--update", "--dry-run")
check(rc == 0 and out["dry_run"] is True, "dry-run exits 0 and says so")
check(read(mem, "patterns/patterns.json") == before, "dry-run leaves patterns.json unchanged")
check(out["tally"]["patterns_updated"] == 1, "dry-run still reports what it would do")

# --- 14. corrupt patterns.json is quarantined, not fatal --------------------
mem = make_mem(errors=errors)
write(mem, "patterns/patterns.json", "{ kaputt")
rc, out = run(mem, "--update")
check(rc == 0, "corrupt patterns.json does not abort the run")
check(os.path.exists(os.path.join(mem, "patterns/patterns.json.corrupt.bak")),
      "corrupt patterns.json quarantined as .corrupt.bak")

# --- 15. --refresh regenerates patterns.md even with nothing to change ------
# Found by running the script against a copy of the real store: 10 errors formed
# no cluster, so --update correctly wrote nothing - which silently broke the
# documented "refresh patterns" request.
mem = make_mem(errors=[err("err-001", "2026-07-01", "x", ["a"])], patterns=existing)
rc, out = run(mem, "--update")
check(out["files_written"] == [],
      "a run that changes nothing writes nothing (routine path stays quiet)")
mem = make_mem(errors=[err("err-001", "2026-07-01", "x", ["a"])], patterns=existing)
rc, out = run(mem, "--refresh")
check(rc == 0 and "patterns/patterns.md" in out["files_written"],
      "--refresh writes patterns.md even when no cluster changed")
check("P001" in read(mem, "patterns/patterns.md"),
      "refreshed patterns.md is projected from patterns.json")

# --- 16. missing memory dir is a usage error --------------------------------
rc, out = run(os.path.join(tempfile.gettempdir(), "gibt-es-nicht-xyz"), "--update")
check(rc == 1 and out.get("ok") is False, "missing memory dir exits 1 with JSON")

print(f"=== Results: {PASSED}/{TESTS} passed, {ERRORS} failures ===")
sys.exit(1 if ERRORS else 0)
