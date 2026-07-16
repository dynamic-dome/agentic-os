#!/usr/bin/env python3
"""Tests for scripts/bridge_projection.py (T-14 Claude->Codex bridge projection).

Renders approved bridge learnings into a managed block in AGENTS.md.
Run: python tests/test-bridge-projection.py  (exit 0 = pass)
"""
import json
import os
import subprocess
import sys
import tempfile

PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(PLUGIN_ROOT, "scripts", "bridge_projection.py")

FAILURES = []
BEGIN = "<!-- bridge:begin"
END = "<!-- bridge:end -->"


def check(name, cond, detail=""):
    if cond:
        print(f"  PASS: {name}")
    else:
        print(f"  FAIL: {name} {detail}")
        FAILURES.append(name)


def run(args, cwd):
    return subprocess.run(
        [sys.executable, SCRIPT] + args,
        capture_output=True, encoding="utf-8", errors="replace", cwd=cwd,
    )


def learning(lid, date, text, importance=4, bridge=None, superseded=None):
    entry = {
        "id": lid, "date": date, "text": text, "importance": importance,
        "tags": ["bridge"], "layer": "short-term",
        "superseded_by": superseded, "last_relevant": date,
    }
    if bridge is not None:
        entry["bridge_status"] = bridge
    return entry


def setup(tmp, learnings, agents_body=None):
    mem = os.path.join(tmp, ".agent-memory")
    os.makedirs(os.path.join(mem, "learnings"), exist_ok=True)
    with open(os.path.join(mem, "learnings", "learnings.json"), "w",
              encoding="utf-8") as f:
        json.dump(learnings, f, ensure_ascii=False)
    agents = os.path.join(tmp, "AGENTS.md")
    if agents_body is not None:
        with open(agents, "w", encoding="utf-8") as f:
            f.write(agents_body)
    return mem, agents


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def main():
    print("=== bridge_projection.py tests ===")
    check("script exists", os.path.isfile(SCRIPT))
    if not os.path.isfile(SCRIPT):
        print("=== 1 failure (script missing) ===")
        return 1

    foreign = "# AGENTS.md\n\n## Projekt\nFremder Inhalt bleibt.\n"

    # 1. keine approved -> AGENTS.md byte-identisch, exit 0
    with tempfile.TemporaryDirectory() as tmp:
        mem, agents = setup(tmp, [learning("L1", "2026-07-16", "kein flag")],
                            foreign)
        p = run([mem, "--agents-md", agents], cwd=tmp)
        check("no approved: exit 0", p.returncode == 0, f"rc={p.returncode} err={p.stderr[:200]}")
        check("no approved: file untouched", read(agents) == foreign)

    # 2. approved -> Block angehaengt, Fremdinhalt byte-identisch davor
    with tempfile.TemporaryDirectory() as tmp:
        mem, agents = setup(tmp, [
            learning("L1", "2026-07-15", "altes learning", bridge="approved"),
            learning("L2", "2026-07-16", "neues learning", bridge="approved"),
            learning("L3", "2026-07-16", "nur candidate", bridge="candidate"),
        ], foreign)
        p = run([mem, "--agents-md", agents], cwd=tmp)
        content = read(agents)
        check("approved: exit 0", p.returncode == 0, f"rc={p.returncode} err={p.stderr[:200]}")
        check("approved: foreign prefix preserved", content.startswith(foreign))
        check("approved: block present", BEGIN in content and END in content)
        check("approved: entries rendered", "[L1]" in content and "[L2]" in content)
        check("candidate excluded", "[L3]" not in content)
        check("newest first", content.index("[L2]") < content.index("[L1]"))

        # 3. Idempotenz: zweiter Lauf -> identische Datei
        run([mem, "--agents-md", agents], cwd=tmp)
        check("idempotent", read(agents) == content)

        # 4. Update: Text aendern -> Block aktualisiert, genau EIN Block
        store = json.load(open(os.path.join(mem, "learnings", "learnings.json"),
                               encoding="utf-8"))
        store[1]["text"] = "neues learning ueberarbeitet"
        with open(os.path.join(mem, "learnings", "learnings.json"), "w",
                  encoding="utf-8") as f:
            json.dump(store, f, ensure_ascii=False)
        run([mem, "--agents-md", agents], cwd=tmp)
        content = read(agents)
        check("update: new text rendered", "ueberarbeitet" in content)
        check("update: single block", content.count(BEGIN) == 1)

        # 5. Widerruf: alle Flags weg -> Block entfernt, Fremdinhalt bleibt
        for e in store:
            e.pop("bridge_status", None)
        with open(os.path.join(mem, "learnings", "learnings.json"), "w",
                  encoding="utf-8") as f:
            json.dump(store, f, ensure_ascii=False)
        run([mem, "--agents-md", agents], cwd=tmp)
        check("revoke: block removed", BEGIN not in read(agents))
        check("revoke: foreign preserved", read(agents).startswith("# AGENTS.md"))

    # 6. Cap 10 + sichtbarer Ueberhang
    with tempfile.TemporaryDirectory() as tmp:
        many = [learning(f"L{i}", f"2026-07-{i:02d}", f"text {i}",
                         bridge="approved") for i in range(1, 13)]
        mem, agents = setup(tmp, many, foreign)
        run([mem, "--agents-md", agents], cwd=tmp)
        content = read(agents)
        block = content[content.index(BEGIN):content.index(END)]
        check("cap: 10 entries", block.count("- [L") == 10, f"n={block.count('- [L')}")
        check("cap: overflow visible", "2 ältere" in block, block[-200:])
        check("cap: newest kept", "[L12]" in block and "[L1]" not in block)

    # 7. superseded approved wird ausgeschlossen
    with tempfile.TemporaryDirectory() as tmp:
        mem, agents = setup(tmp, [
            learning("L1", "2026-07-16", "ersetzt", bridge="approved",
                     superseded="L2"),
            learning("L2", "2026-07-16", "ersatz", bridge="approved"),
        ], foreign)
        run([mem, "--agents-md", agents], cwd=tmp)
        content = read(agents)
        check("superseded excluded", "[L1]" not in content and "[L2]" in content)

    # 8. AGENTS.md fehlt + approved -> Datei mit Block angelegt
    with tempfile.TemporaryDirectory() as tmp:
        mem, agents = setup(tmp, [learning("L1", "2026-07-16", "t",
                                           bridge="approved")])
        p = run([mem, "--agents-md", agents], cwd=tmp)
        check("create: exit 0", p.returncode == 0, f"rc={p.returncode} err={p.stderr[:200]}")
        check("create: block present", BEGIN in read(agents))

    # 9. learnings.json fehlt -> No-op exit 0; invalid -> exit 1
    with tempfile.TemporaryDirectory() as tmp:
        mem = os.path.join(tmp, ".agent-memory")
        os.makedirs(os.path.join(mem, "learnings"))
        agents = os.path.join(tmp, "AGENTS.md")
        p = run([mem, "--agents-md", agents], cwd=tmp)
        check("missing store: exit 0", p.returncode == 0, f"rc={p.returncode}")
        check("missing store: no file created", not os.path.exists(agents))
        with open(os.path.join(mem, "learnings", "learnings.json"), "w",
                  encoding="utf-8") as f:
            f.write("{ not json")
        p = run([mem, "--agents-md", agents], cwd=tmp)
        check("invalid store: exit 1", p.returncode == 1, f"rc={p.returncode}")

    # 10. Usage-Fehler
    with tempfile.TemporaryDirectory() as tmp:
        p = run([], cwd=tmp)
        check("usage error: exit 2", p.returncode == 2, f"rc={p.returncode}")

    n = len(FAILURES)
    print(f"=== {n} failure(s) ===" if n else "=== all tests passed ===")
    return 1 if n else 0


if __name__ == "__main__":
    sys.exit(main())
