#!/usr/bin/env python3
"""Claude->Codex bridge projection (T-14, membrain membridge.md §3.3).

Renders learnings with bridge_status=approved into a managed block in the
project's AGENTS.md so standalone Codex sessions get them unconditionally.
learnings.json stays canonical; the block is a projection — regenerate any
time, never edit by hand. Read-modify-write happens inside ONE process with
an atomic replace, so there is no agent-level race window (T-19 class).

Usage:
  python bridge_projection.py <mem-dir> --agents-md <path>

Exit codes: 0 ok (also no-op) · 1 learnings.json unreadable · 2 usage error.
"""
import argparse
import json
import os
import sys

BEGIN = ("<!-- bridge:begin — generiert von agentic-os bridge_projection, "
         "NICHT von Hand editieren -->")
END = "<!-- bridge:end -->"
BEGIN_PREFIX = "<!-- bridge:begin"
CAP = 10


def load_approved(mem_dir):
    """Approved, non-superseded learnings, newest first. None = store invalid."""
    path = os.path.join(mem_dir, "learnings", "learnings.json")
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as exc:
        print(f"bridge: learnings.json unreadable: {exc}", file=sys.stderr)
        return None
    entries = data if isinstance(data, list) else data.get("learnings", [])
    approved = [e for e in entries if isinstance(e, dict)
                and e.get("bridge_status") == "approved"
                and not e.get("superseded_by")]
    approved.sort(key=lambda e: (str(e.get("date", "")),
                                 int(e.get("importance", 0))), reverse=True)
    return approved


def render_block(approved):
    lines = [BEGIN, "## Bridge: Learnings von Claude (kuratiert)"]
    for e in approved[:CAP]:
        lines.append(f"- [{e.get('id')}] ({e.get('date')}) {e.get('text')}")
    overflow = len(approved) - CAP
    if overflow > 0:
        lines.append(f"({overflow} ältere: learnings.json)")
    lines.append(END)
    return "\n".join(lines) + "\n"


def strip_block(text):
    """Remove an existing managed block; returns text unchanged if absent."""
    lines = text.split("\n")
    out, inside, found = [], False, False
    for line in lines:
        if not inside and line.startswith(BEGIN_PREFIX):
            inside, found = True, True
            continue
        if inside:
            if line.strip() == END:
                inside = False
            continue
        out.append(line)
    if not found:
        return text
    result = "\n".join(out)
    while result.endswith("\n\n"):
        result = result[:-1]
    return result


def write_atomic(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    os.replace(tmp, path)


def main(argv):
    parser = argparse.ArgumentParser(prog="bridge_projection.py")
    parser.add_argument("mem_dir")
    parser.add_argument("--agents-md", required=True)
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        return 2

    approved = load_approved(args.mem_dir)
    if approved is None:
        return 1

    exists = os.path.isfile(args.agents_md)
    current = ""
    if exists:
        with open(args.agents_md, "r", encoding="utf-8") as f:
            current = f.read()

    if not approved:
        if exists and BEGIN_PREFIX in current:
            write_atomic(args.agents_md, strip_block(current))
            print(f"bridge: 0 approved — block removed from {args.agents_md}")
        else:
            print("bridge: no approved learnings, nothing to do")
        return 0

    block = render_block(approved)
    base = strip_block(current) if exists else ""
    if base and not base.endswith("\n"):
        base += "\n"
    new = base + ("\n" if base else "") + block
    if exists and new == current:
        print(f"bridge: {len(approved)} approved — block up to date")
        return 0
    write_atomic(args.agents_md, new)
    capped = f", capped at {CAP}" if len(approved) > CAP else ""
    print(f"bridge: {len(approved)} approved -> {args.agents_md}{capped}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
