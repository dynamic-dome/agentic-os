#!/usr/bin/env python3
"""Gate-linkage check for the skill-redesign harness (T-35).

The core protection against SILENT GATE LOSS during an aggressive body cut. For
each known bootstrap gate it asserts the body carries BOTH a trigger token AND an
action token — not just a bare anchor. If a redesign moves a gate's decision
logic out of the body, either its trigger or its action token disappears and this
fails, forcing the move back (the redesign rule: "no gate logic leaves the body").

This complements validate-skills.sh (bare string anchors) and eval_signals.py
(script signals). Substring matching, not regex — tokens contain *, `, <> on
purpose and must match literally.

    python tests/eval/gate_linkage.py          # exit 0 = all pass, 1 = failure

Maintenance: this list IS the gate inventory. When a real gate is added to
bootstrap, add it here; when one is intentionally removed, remove it here in the
same commit (and say so in the message). Derived from the body on 2026-07-18.

Design: memevalharness.md (membrain).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN_ROOT = os.path.dirname(os.path.dirname(HERE))
BOOTSTRAP = os.path.join(PLUGIN_ROOT, "skills", "session-bootstrap", "SKILL.md")

# Each gate: at least ONE trigger token AND at least ONE action token must be
# present in the body. Tokens are load-bearing literals (file names, exit codes,
# gate keywords) chosen to survive legitimate rephrasing but die if the gate's
# mechanic is extracted.
GATES = [
    {
        "name": "fast-path",
        "triggers": ["previous_state_hash == current_state_hash",
                     "changed_files` is empty"],
        "actions": ["Memory unchanged since last", "load ONLY"],
    },
    {
        "name": "recovery-detect",
        "triggers": ["dirty-*.json", "30 minutes"],
        "actions": ["RECOVERY", "wrap-up ausführen"],
    },
    {
        "name": "recovery-tail-downgrade",
        "triggers": ["writes_since_consolidation <= 5", "15 minutes"],
        "actions": ["downgrade"],
    },
    {
        "name": "soul-candidate-gate",
        "triggers": ["soul-candidates.md", "explicit `j`"],
        "actions": ["user-changelog.json"],
    },
    {
        "name": "user-candidate-gate",
        "triggers": ["user-candidates.json"],
        "actions": ["promotion"],
    },
    {
        "name": "identity-starvation",
        "triggers": ["2+ sessions old"],
        "actions": ["Pipeline verhungert"],
    },
    {
        "name": "thresholds",
        "triggers": ["memory-thresholds.sh", "Exit 10"],
        "actions": ["THRESHOLD:"],
    },
    {
        "name": "escalation",
        "triggers": ["escalations-<session-id>.json"],
        "actions": ["ESKALATION:"],
    },
    {
        "name": "rag-learnings",
        "triggers": ["memory_search_tool"],
        "actions": ["learnings_top.py"],
    },
    {
        "name": "sharepoint-conflict",
        "triggers": ["_conflicts/"],
        "actions": ["STOP"],
    },
]

TESTS = 0
FAILS = 0


def check(cond, label):
    global TESTS, FAILS
    TESTS += 1
    if cond:
        print(f"  PASS: {label}")
    else:
        FAILS += 1
        print(f"  FAIL: {label}")


def main():
    # Optional body-path override: lets the redesign flow point the check at a
    # candidate SKILL.md before it replaces the live one.
    body_path = sys.argv[1] if len(sys.argv) > 1 else BOOTSTRAP
    print(f"=== Gate-Linkage — {os.path.basename(os.path.dirname(body_path))} "
          f"(trigger AND action co-presence) ===")
    with open(body_path, "r", encoding="utf-8") as f:
        body = f.read()

    for gate in GATES:
        name = gate["name"]
        trig_hits = [t for t in gate["triggers"] if t in body]
        act_hits = [a for a in gate["actions"] if a in body]
        check(len(trig_hits) >= 1,
              f"{name}: trigger present ({trig_hits or gate['triggers']})")
        check(len(act_hits) >= 1,
              f"{name}: action present ({act_hits or gate['actions']})")

    print(f"\n{TESTS - FAILS}/{TESTS} checks passed ({len(GATES)} gates).")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
