#!/usr/bin/env python3
"""Gate-linkage check for the skill-redesign harness (T-35).

The core protection against SILENT GATE LOSS during an aggressive body cut. Each
gate is expressed in CNF: a list of CLAUSES that must ALL hold; a clause is a list
of alternative tokens of which at least ONE must be present. So every load-bearing
conjunct of a gate (both trigger conditions AND the action) is mandatory, while a
single clause may offer alternative spellings for legitimate rephrasing.

    single token  -> a required conjunct with one canonical spelling
    [a, b] clause -> a required conjunct that may be phrased as a OR b

If a redesign drops any conjunct of a gate, that gate's clause goes unsatisfied
and this fails — forcing the move back (rule: "no gate logic leaves the body").

    python tests/eval/gate_linkage.py [body.md]   # check a body (default: bootstrap)
    python tests/eval/gate_linkage.py --selftest   # prove every clause has teeth

Substring matching, not regex — tokens contain *, `, <> and must match literally.

Maintenance: this list IS the gate inventory. Add a real gate here when one is
added to bootstrap; remove one here (same commit, stated in the message) when it
is intentionally removed. Derived from the body on 2026-07-18; extended after the
Codex verifier review (CNF + 6 previously-missing gates).

Design: memevalharness.md (membrain).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN_ROOT = os.path.dirname(os.path.dirname(HERE))
BOOTSTRAP = os.path.join(PLUGIN_ROOT, "skills", "session-bootstrap", "SKILL.md")

# gate = {"name", "clauses": [clause, ...]}; clause = [token, ...] (OR within).
# ALL clauses of a gate must be satisfied (AND across clauses).
GATES = [
    {"name": "fast-path", "clauses": [
        ["previous_state_hash == current_state_hash"],   # trigger: hashes equal
        ["changed_files` is empty"],                     # trigger: no dirty work
        ["Memory unchanged since last", "load ONLY"],    # action: slim load
    ]},
    {"name": "recovery-detect", "clauses": [
        ["dirty-*.json"],                                # trigger: crash markers
        ["30 minutes"],                                  # trigger: age grace
        ["RECOVERY"],                                    # action: surface block
        ["wrap-up ausführen"],                           # action: recommend fix
    ]},
    {"name": "recovery-tail-downgrade", "clauses": [
        ["writes_since_consolidation <= 5"],             # trigger: few tail writes
        ["15 minutes"],                                  # trigger: near consolidation
        ["downgrade"],                                   # action: one-line note
    ]},
    {"name": "soul-candidate-gate", "clauses": [
        ["soul-candidates.md"],                          # trigger: candidate queue
        ["explicit `j`"],                                # trigger: user confirmation
        ["user-changelog.json"],                         # action: audit trail
    ]},
    {"name": "user-candidate-gate", "clauses": [
        ["user-candidates.json"],                        # trigger: candidate queue
        ["promotion"],                                   # action: promote to user.md
    ]},
    {"name": "identity-starvation", "clauses": [
        ["2+ sessions old"],                             # trigger: stale scan
        ["Pipeline verhungert"],                         # action: HEALTH warning
    ]},
    {"name": "thresholds", "clauses": [
        ["memory-thresholds.sh"],                        # trigger: SSoT script
        ["Exit 10"],                                     # trigger: scaling signal
        ["THRESHOLD:"],                                  # action: HEALTH lines
    ]},
    {"name": "escalation", "clauses": [
        ["escalations-<session-id>.json"],               # action: append record
        ["ESKALATION:"],                                 # action: visible line
    ]},
    {"name": "rag-learnings", "clauses": [
        ["memory_search_tool"],                          # trigger: Atlas primary
        ["learnings_top.py"],                            # action: heuristic fallback
    ]},
    {"name": "sharepoint-conflict", "clauses": [
        ["_conflicts/"],                                 # trigger: conflict files
        ["STOP"],                                        # action: halt, don't trust
    ]},
    # --- gates added after the Codex verifier review (were missing) ---
    {"name": "missing-memory-stop", "clauses": [
        ["should not happen"],                           # trigger: .agent-memory gone
        ["Memory system not found"],                     # action: stop message
    ]},
    {"name": "staleness-wrap-90d", "clauses": [
        ["90 days"],                                     # trigger: last_relevant age
        ["STALE? last relevant"],                        # action: read-time mark
    ]},
    {"name": "wiki-sync-gate", "clauses": [
        ["sync_enabled` is false"],                      # trigger: config off
        ["skip this step silently"],                     # action: skip, no error
    ]},
    {"name": "json-repair", "clauses": [
        ["rename to"],                                   # trigger: corrupt JSON
        [".corrupt.bak"],                                # action: backup + recreate
    ]},
    {"name": "active-warning-thresholds", "clauses": [
        ["confidence >= 0.7"],                           # trigger: pattern confidence
        ["occurrences >= 3"],                            # trigger: pattern recurrence
    ]},
    {"name": "cost-trace", "clauses": [
        ["cost-trace.sh"],                               # trigger: SSoT script
        ["context-bytes"],                               # action: log run trace
    ]},
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


def clause_satisfied(clause, body):
    return any(tok in body for tok in clause)


def gate_ok(gate, body):
    """True iff every clause of the gate is satisfied."""
    return all(clause_satisfied(c, body) for c in gate["clauses"])


def run_checks(body, label):
    print(f"=== Gate-Linkage — {label} (CNF: every conjunct mandatory) ===")
    for gate in GATES:
        for i, clause in enumerate(gate["clauses"]):
            hit = [t for t in clause if t in body]
            check(len(hit) >= 1,
                  f"{gate['name']}: clause {i} present ({hit or clause})")
    print(f"\n{TESTS - FAILS}/{TESTS} clause checks passed "
          f"({len(GATES)} gates).")


def selftest(body):
    """Prove every clause is load-bearing: removing any single clause's tokens
    must make its gate fail. Guards against the OR-within-gate hole the Codex
    review found."""
    print("=== Gate-Linkage SELFTEST (single-conjunct-loss must be caught) ===")
    global TESTS, FAILS
    for gate in GATES:
        # sanity: gate must pass on the untouched body first
        if not gate_ok(gate, body):
            TESTS += 1
            FAILS += 1
            print(f"  FAIL: {gate['name']}: does not hold on current body")
            continue
        for i, clause in enumerate(gate["clauses"]):
            mutated = body
            for tok in clause:
                mutated = mutated.replace(tok, "<<removed>>")
            TESTS += 1
            if gate_ok(gate, mutated):
                FAILS += 1
                print(f"  FAIL: {gate['name']} clause {i} NOT load-bearing "
                      f"(gate still passes without {clause})")
            else:
                print(f"  PASS: {gate['name']} clause {i} load-bearing")
    print(f"\n{TESTS - FAILS}/{TESTS} selftest checks passed.")


def main():
    args = sys.argv[1:]
    with open(BOOTSTRAP, "r", encoding="utf-8") as f:
        default_body = f.read()

    if args and args[0] == "--selftest":
        selftest(default_body)
    elif args:
        body_path = args[0]
        with open(body_path, "r", encoding="utf-8") as f:
            body = f.read()
        run_checks(body, os.path.basename(os.path.dirname(body_path)))
    else:
        run_checks(default_body, "session-bootstrap")

    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
