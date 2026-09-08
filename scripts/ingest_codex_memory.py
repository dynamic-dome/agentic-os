#!/usr/bin/env python3
"""E1: Codex native memory -> learnings.json candidates (membrain hub spec §1).

Reads ONLY <codex-memories>/memory_summary.md (Codex's own compact projection;
raw_memories.md is episodic and belongs to the Atlas adapter). Sections
'User preferences' -> kind=feedback, 'General Tips' -> kind=learning; only
top-level bullets. Dedupe against learnings.json via apply_wrapup.norm or the
provenance hash; hits only refresh last_relevant. New entries are
bridge_status=candidate with source_agent=codex (never auto-approved; the
wrap-up gate 3d decides). Codex memory is INPUT only - never written.

Usage: python ingest_codex_memory.py <mem-dir> [--codex-memories <dir>] [--dry-run]
Exit: 0 ok (also skipped/no-op) · 1 learnings.json unreadable · 2 usage error.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from apply_wrapup import norm, render_learnings_md  # noqa: E402

SECTIONS = {"user preferences": "feedback", "general tips": "learning"}
ADHOC = "[ad-hoc note]"
REVIEW_AFTER_DAYS = 90


def parse_summary(text):
    """Yield (kind, text, adhoc) for top-level bullets in the mapped sections."""
    kind = None
    for line in text.splitlines():
        if line.startswith("## "):
            kind = SECTIONS.get(line[3:].strip().lower())
            continue
        if line.startswith("#"):
            kind = None
            continue
        if kind and line.startswith("- "):
            body = line[2:].strip()
            adhoc = body.endswith(ADHOC)
            if adhoc:
                body = body[: -len(ADHOC)].strip()
            if body:
                yield kind, body, adhoc


def next_id(rows):
    top = 0
    for r in rows:
        m = re.match(r"^L(\d+)$", str(r.get("id", "")))
        if m:
            top = max(top, int(m.group(1)))
    return f"L{top + 1}"


def load_rows(path):
    if not os.path.isfile(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else data.get("learnings", [])


def write_atomic(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    os.replace(tmp, path)


def main(argv):
    ap = argparse.ArgumentParser(prog="ingest_codex_memory.py")
    ap.add_argument("mem_dir")
    ap.add_argument("--codex-memories", default=os.path.join(os.path.expanduser("~"), ".codex", "memories"))
    ap.add_argument("--dry-run", action="store_true")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 2

    summary = os.path.join(a.codex_memories, "memory_summary.md")
    if not os.path.isfile(summary):
        print(f"codex-ingest: no memory_summary.md at {summary} — skipped")
        return 0
    store = os.path.join(a.mem_dir, "learnings", "learnings.json")
    try:
        rows = load_rows(store)
    except (OSError, ValueError) as exc:
        print(f"codex-ingest: learnings.json unreadable: {exc}", file=sys.stderr)
        return 1
    with open(summary, "r", encoding="utf-8", errors="replace") as f:
        raw = f.read()

    today = dt.date.today().isoformat()
    by_norm = {norm(r.get("text", "")): r for r in rows if isinstance(r, dict)}
    by_hash = {}
    for r in rows:
        for d in (r.get("derived_from") or []):
            if str(d).startswith("codex:memory_summary:"):
                by_hash[d] = r
    new, dup, ignored = [], 0, 0
    for kind, text, adhoc in parse_summary(raw):
        key = norm(text)
        prov = "codex:memory_summary:" + hashlib.sha1(key.encode("utf-8")).hexdigest()[:8]
        hit = by_hash.get(prov) or by_norm.get(key)
        if hit is not None:
            hit["last_relevant"] = today
            dup += 1
            continue
        entry = {
            "id": next_id(rows + new), "date": today, "text": text, "importance": 2,
            "tags": ["codex-native", kind] + (["ad-hoc"] if adhoc else []),
            "layer": "short-term", "superseded_by": None, "last_relevant": today,
            "derived_from": [prov],
            "review_after": (dt.date.today() + dt.timedelta(days=REVIEW_AFTER_DAYS)).isoformat(),
            "bridge_status": "candidate", "source_agent": "codex", "kind": kind,
        }
        new.append(entry)
        by_norm[key] = entry
        by_hash[prov] = entry
    ignored = sum(1 for line in raw.splitlines() if line.startswith("- ")) - len(new) - dup

    if not a.dry_run and (new or dup):
        rows.extend(new)
        write_atomic(store, json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
        if new:
            render_learnings_md(a.mem_dir, rows, False, [])
    print(f"codex-ingest: {len(new)} new, {dup} dup, {max(ignored, 0)} ignored from {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
