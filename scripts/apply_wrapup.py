#!/usr/bin/env python3
"""apply_wrapup.py — single-pass batch writer for the wrap-up skill.

WHY THIS EXISTS
---------------
A measured wrap-up run (2026-07-20) cost $42.87: 70 assistant turns, 28.8M
cache-read + 4.1M cache-write tokens, but only 108k output tokens. 94% of the
cost was context handling, not thinking. Every individual Write/Edit turn
re-reads the whole session context.

This script collapses all of wrap-up's file mutations into ONE call: the model
emits a single write plan, this script applies it and returns the resulting
tallies. Turn count for the write phase drops from ~40 to ~2.

Second benefit: the returned counts are computed from the files actually
written, so the mandatory Step 6.5 identity status line reports measured
numbers instead of a model self-report (see the verify-subagent-tallies rule).

WHAT IT DOES NOT DO
-------------------
No judgment. Deduplication beyond exact-text matching, learning importance,
what counts as an identity observation — all of that stays with the model and
arrives via the plan. This script only applies deterministic rules that are
already written down in skills/wrap-up/SKILL.md.

It also refuses to touch files owned by other skills (errors.json,
patterns.json, decisions.json, iteration-log.md) and never writes soul.md.

USAGE
-----
    python scripts/apply_wrapup.py .agent-memory --session-id <sid> < plan.json
    python scripts/apply_wrapup.py .agent-memory --session-id <sid> --dry-run < plan.json

Plan schema: skills/wrap-up/references/wrapup-schemas.md §Write plan.
Exit codes: 0 = applied, 1 = usage/IO error, 2 = plan rejected (nothing written).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
import tempfile

# Files owned by other skills - writing them here is a hard bug, not a warning.
FORBIDDEN = {
    "iterations/errors.json",         # iteration-logger
    "iterations/iteration-log.md",    # iteration-logger
    "patterns/patterns.json",         # pattern-extractor
    "patterns/patterns.md",           # pattern-extractor
    "context/decisions.json",         # context-keeper
    "identity/soul.md",               # bootstrap [j/n] gate only - never here
}

SECTION_BY_SIGNAL = {
    "preference": "Preferences",
    "communication": "Preferences",
    "workflow": "Work Style",
    "correction": "Known Corrections",
}

SUMMARY_MAX_LINES = 30
REVIEW_AFTER_DAYS = 90


class PlanError(Exception):
    """Plan is malformed - nothing gets written."""


# ---------------------------------------------------------------- io helpers

def _p(mem: str, rel: str) -> str:
    if rel in FORBIDDEN:
        raise PlanError(f"refusing to write {rel}: owned by another skill")
    return os.path.join(mem, rel)


def load_json(mem: str, rel: str, default):
    path = os.path.join(mem, rel)
    if not os.path.exists(path):
        return default
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (json.JSONDecodeError, UnicodeDecodeError):
        # Error Handling contract: quarantine, do not crash the whole wrap-up.
        os.replace(path, path + ".corrupt.bak")
        return default


def write_atomic(mem: str, rel: str, text: str, dry: bool, touched: list) -> None:
    path = _p(mem, rel)
    touched.append(rel)
    if dry:
        return
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def write_json(mem: str, rel: str, data, dry: bool, touched: list) -> None:
    write_atomic(mem, rel, json.dumps(data, indent=2, ensure_ascii=False) + "\n", dry, touched)


def next_id(rows, prefix: str, pad: int = 0) -> str:
    hi = 0
    pat = re.compile(re.escape(prefix) + r"(\d+)$")
    for r in rows:
        m = pat.match(str(r.get("id", "")))
        if m:
            hi = max(hi, int(m.group(1)))
    n = hi + 1
    return f"{prefix}{n:0{pad}d}" if pad else f"{prefix}{n}"


def norm(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "")).strip().lower()


# ------------------------------------------------------------------- steps

def apply_learnings(mem, plan, date, dry, touched, tally):
    items = plan.get("learnings") or []
    rows = load_json(mem, "learnings/learnings.json", [])
    seen = {norm(r.get("text")) for r in rows}
    added = []
    for it in items:
        text = (it.get("text") or "").strip()
        if not text:
            raise PlanError("learning without 'text'")
        if norm(text) in seen:
            tally["learnings_skipped_duplicate"] += 1
            continue
        seen.add(norm(text))
        entry = {
            "id": next_id(rows + added, "L"),
            "date": date,
            "text": text,
            "importance": int(it.get("importance", 3)),
            "tags": list(it.get("tags") or []),
            "layer": "short-term",
            "superseded_by": None,
            "last_relevant": date,
            "derived_from": list(it.get("derived_from") or []),
            "review_after": (
                _dt.date.fromisoformat(date) + _dt.timedelta(days=REVIEW_AFTER_DAYS)
            ).isoformat(),
        }
        added.append(entry)
    if not added:
        return
    rows.extend(added)
    write_json(mem, "learnings/learnings.json", rows, dry, touched)
    tally["learnings_added"] = len(added)
    tally["learning_ids"] = [e["id"] for e in added]
    render_learnings_md(mem, rows, dry, touched)


def render_learnings_md(mem, rows, dry, touched):
    """learnings.md is a pure projection of learnings.json - fully deterministic."""
    out = ["# Learnings", ""]
    for imp in (5, 4, 3, 2, 1):
        bucket = [r for r in rows if int(r.get("importance", 3)) == imp and not r.get("superseded_by")]
        if not bucket:
            continue
        out.append(f"## Importance {imp}")
        out.append("")
        for r in sorted(bucket, key=lambda x: str(x.get("date", "")), reverse=True):
            tags = " ".join(f"#{t}" for t in (r.get("tags") or []))
            out.append(f"- **{r.get('id')}** ({r.get('date')}) {r.get('text')}" + (f"  {tags}" if tags else ""))
        out.append("")
    write_atomic(mem, "learnings/learnings.md", "\n".join(out).rstrip() + "\n", dry, touched)


def apply_user_candidates(mem, plan, date, dry, touched, tally):
    """Step 6.2 enqueue + 6.3 FULL queue re-review. Both rules are deterministic."""
    obs = plan.get("user_candidates") or []
    queue = load_json(mem, "working/user-candidates.json", [])
    by_key = {c.get("key"): c for c in queue}

    for o in obs:
        key = (o.get("key") or "").strip()
        if not key:
            raise PlanError("user candidate without 'key'")
        trust = o.get("trust_source", "conversation")
        if trust != "conversation":
            # Step 6.1 trust boundary - memory-poisoning defense.
            tally["candidates_rejected_trust"] += 1
            continue
        if key in by_key:
            c = by_key[key]
            c["occurrences"] = int(c.get("occurrences", 1)) + 1
            c["last_seen"] = date
            ev = c.setdefault("evidence", [])
            for e in (o.get("evidence") or [f"session {date}"]):
                if e not in ev:
                    ev.append(e)
            if o.get("confirmed") or int(c["occurrences"]) >= 2:
                if c.get("status") in ("observed", "inferred"):
                    c["status"] = "confirmed"
            tally["candidates_updated"] += 1
        else:
            c = {
                "id": next_id(queue, "UC"),
                "key": key,
                "observation": (o.get("observation") or "").strip(),
                "status": "confirmed" if o.get("confirmed") else o.get("status", "observed"),
                "signal_type": o.get("signal_type", "preference"),
                "confidence": float(o.get("confidence", 0.5)),
                "occurrences": 1,
                "evidence": list(o.get("evidence") or [f"session {date}"]),
                "first_seen": date,
                "last_seen": date,
                "trust_source": "conversation",
            }
            queue.append(c)
            by_key[key] = c
            tally["candidates_new"] += 1

    promoted = promote_candidates(mem, queue, date, dry, touched, tally)
    if obs or promoted:
        write_json(mem, "working/user-candidates.json", queue, dry, touched)
    tally["queue_open"] = sum(1 for c in queue if c.get("status") != "promoted")


def promote_candidates(mem, queue, date, dry, touched, tally):
    """Step 6.3: review EVERY candidate, not just this session's."""
    promotable = []
    for c in queue:
        if c.get("status") == "promoted":
            continue
        if c.get("signal_type") == "mood":
            continue  # signal:mood is NEVER promoted
        status = c.get("status")
        occ = int(c.get("occurrences", 1))
        conf = float(c.get("confidence", 0.0))
        if status == "confirmed" or (status == "inferred" and occ >= 2 and conf >= 0.6):
            promotable.append(c)

    if not promotable:
        return []

    changelog = load_json(mem, "identity/user-changelog.json", [])
    user_md = read_user_md(mem)
    now = _dt.datetime.now().astimezone().isoformat(timespec="seconds")

    for c in promotable:
        section = SECTION_BY_SIGNAL.get(c.get("signal_type", "preference"), "Preferences")
        line = f"- {c.get('observation')} ({c.get('id')}, {date})"
        # changelog BEFORE edit - ordering is part of the contract
        changelog.append({
            "ts": now,
            "field": f"user.md/{section}",
            "old_value": None,
            "new_value": c.get("observation"),
            "candidate_id": c.get("id"),
            "evidence": c.get("evidence") or [],
        })
        user_md.setdefault(section, [])
        if line not in user_md[section]:
            user_md[section].append(line)
        c["status"] = "promoted"
        c["status_after_promotion"] = "promoted"

    write_json(mem, "identity/user-changelog.json", changelog, dry, touched)
    write_user_md(mem, user_md, dry, touched)
    tally["candidates_promoted"] = len(promotable)
    tally["promoted_ids"] = [c.get("id") for c in promotable]
    return promotable


def read_user_md(mem):
    """Parse user.md into {section: [lines]} preserving unknown sections."""
    path = os.path.join(mem, "identity/user.md")
    sections, current = {}, None
    if os.path.exists(path):
        for raw in open(path, encoding="utf-8"):
            line = raw.rstrip("\n")
            if line.startswith("## "):
                current = line[3:].strip()
                sections.setdefault(current, [])
            elif line.startswith("# "):
                current = None
            elif current is not None and line.strip():
                sections[current].append(line)
    return sections


def write_user_md(mem, sections, dry, touched):
    order = ["Preferences", "Work Style", "Known Corrections"]
    ordered = order + [s for s in sections if s not in order]
    out = ["# User Profile", ""]
    for s in ordered:
        if s not in sections:
            continue
        out.append(f"## {s}")
        out.append("")
        out.extend(sections[s] or [])
        out.append("")
    write_atomic(mem, "identity/user.md", "\n".join(out).rstrip() + "\n", dry, touched)


def apply_soul_candidates(mem, plan, date, dry, touched, tally):
    items = plan.get("soul_candidates") or []
    if not items:
        return
    path = os.path.join(mem, "identity/soul-candidates.md")
    existing = open(path, encoding="utf-8").read() if os.path.exists(path) else "# Soul Candidates\n"
    block = []
    for it in items:
        proposal = (it.get("proposal") or "").strip()
        if not proposal:
            raise PlanError("soul candidate without 'proposal'")
        if norm(proposal) in norm(existing):
            tally["soul_skipped_duplicate"] += 1
            continue
        ev = "; ".join(it.get("evidence") or [])
        block.append(f"\n## {date} — {proposal}\n\n- **Evidence:** {ev or 'n/a'}\n")
        tally["soul_candidates_added"] += 1
    if block:
        write_atomic(mem, "identity/soul-candidates.md",
                     existing.rstrip() + "\n" + "".join(block), dry, touched)


def apply_open_tasks(mem, plan, date, dry, touched, tally):
    spec = plan.get("open_tasks") or {}
    add, close = spec.get("add") or [], set(spec.get("close") or [])
    if not add and not close:
        return
    rows = load_json(mem, "context/open-tasks.json", [])
    # Snapshot BEFORE applying closes: a plan that closes T-n and re-adds the
    # same title in one pass is contradictory - treat it as a duplicate rather
    # than silently creating a second row. Re-opening a task closed in an
    # EARLIER run still works, because it is not in this snapshot.
    open_titles = {norm(r.get("title")) for r in rows if r.get("status") != "closed"}
    for r in rows:
        if r.get("id") in close and r.get("status") != "closed":
            r["status"] = "closed"
            r["updated"] = date
            r["resolution"] = "resolved in wrap-up"
            tally["tasks_closed"] += 1
    for t in add:
        title = (t.get("title") or "").strip()
        if not title:
            raise PlanError("open task without 'title'")
        if norm(title) in open_titles:
            tally["tasks_skipped_duplicate"] += 1
            continue
        open_titles.add(norm(title))
        rows.append({
            "id": next_id(rows, "T-", pad=3),
            "title": title,
            "status": "open",
            "created": date,
            "updated": date,
            "resolution": None,
            "source": t.get("source", "wrap-up"),
            "cross_project": bool(t.get("cross_project", False)),
        })
        tally["tasks_added"] += 1
    write_json(mem, "context/open-tasks.json", rows, dry, touched)


def apply_session_summary(mem, plan, dry, touched, tally):
    s = plan.get("session_summary")
    if not s:
        return
    st = s.get("statistics") or {}
    now = _dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    out = [
        "# Last Session", "",
        f"*Date: {now}*", "*Agent: Claude Code*", "",
        "## What Was Done", "",
    ]
    out += [f"- {x}" for x in (s.get("what_was_done") or [])[:10]] or ["- (nothing recorded)"]
    out += ["", "## Open Items", ""]
    out += [f"- {x}" for x in (s.get("open_items") or [])] or ["- none"]
    out += ["", "## Next Steps", ""]
    out += [f"{i}. {x}" for i, x in enumerate((s.get("next_steps") or [])[:3], 1)] or ["1. none"]
    out += ["", "## Statistics", "",
            f"- Iterations: {st.get('iterations', 0)} | Errors: {st.get('errors', 0)} "
            f"| New Patterns: {st.get('new_patterns', 0)}"]
    warn = s.get("warnings") or []
    if warn:
        out += ["", "## Active Warnings", ""] + [f"- {x}" for x in warn]
    if s.get("handoff"):
        h = s["handoff"]
        out += ["", "## Handoff Context", "",
                f"- **Active task**: {h.get('active_task', '')}",
                f"- **Current state**: {h.get('current_state', '')}",
                f"- **Active patterns**: {h.get('active_patterns', '')}",
                f"- **Open questions**: {h.get('open_questions', '')}"]
    body = "\n".join(out).rstrip() + "\n"
    n = len(body.splitlines())
    if n > SUMMARY_MAX_LINES and not s.get("handoff"):
        tally["warnings"].append(f"session-summary.md is {n} lines (contract: max {SUMMARY_MAX_LINES})")
    write_atomic(mem, "session-summary.md", body, dry, touched)
    tally["session_summary_lines"] = n


def apply_consolidation(mem, plan, session_id, dry, touched, tally):
    """Step 9.5 - runs LAST and only when everything above succeeded."""
    if not plan.get("consolidate"):
        return
    work = os.path.join(mem, "working")
    dirty_files, sessions, seen_files = [], [], 0
    if os.path.isdir(work):
        for name in sorted(os.listdir(work)):
            if not (name.startswith("dirty-") and name.endswith(".json")):
                continue
            d = load_json(mem, f"working/{name}", None)
            if not isinstance(d, dict) or not d.get("dirty"):
                continue
            dirty_files.append((name, d))
            sessions.append(d.get("session_id", name))
            seen_files += len(d.get("touched_files") or [])

    now = _dt.datetime.now().astimezone().isoformat(timespec="seconds")
    write_json(mem, "consolidation-marker.json", {
        "last_wrapup": now,
        "consolidated_sessions": sessions or ([session_id] if session_id else []),
        "iterations_logged": int(plan.get("iterations_logged", 0)),
        "learnings_added": tally["learnings_added"],
        "touched_files_seen": seen_files,
    }, dry, touched)

    for name, d in dirty_files:
        d["dirty"] = False
        d["consolidated_at"] = now
        d["consolidated_by"] = "wrap-up"
        d["last_consolidated_at"] = now
        d["last_consolidated_by"] = "wrap-up"
        d["writes_since_consolidation"] = 0
        write_json(mem, f"working/{name}", d, dry, touched)
    tally["dirty_files_consolidated"] = len(dirty_files)
    tally["touched_files_seen"] = seen_files


# -------------------------------------------------------------------- main

def main() -> int:
    # Windows default stdout is cp1252; the identity status line contains "→".
    # Without this the whole run dies AFTER the files were written.
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

    ap = argparse.ArgumentParser(description="Apply a wrap-up write plan in one pass.")
    ap.add_argument("mem", nargs="?", default=".agent-memory")
    ap.add_argument("--session-id", default="")
    ap.add_argument("--plan", default="-", help="plan JSON file, '-' for stdin")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(args.mem):
        print(json.dumps({"ok": False, "error": f"memory dir not found: {args.mem}"}))
        return 1

    try:
        raw = sys.stdin.read() if args.plan == "-" else open(args.plan, encoding="utf-8").read()
        plan = json.loads(raw)
        if not isinstance(plan, dict):
            raise PlanError("plan must be a JSON object")
    except (json.JSONDecodeError, OSError) as e:
        print(json.dumps({"ok": False, "error": f"unreadable plan: {e}"}))
        return 2

    date = plan.get("date") or _dt.date.today().isoformat()
    session_id = args.session_id or plan.get("session_id", "")

    tally = {
        "learnings_added": 0, "learnings_skipped_duplicate": 0, "learning_ids": [],
        "candidates_new": 0, "candidates_updated": 0, "candidates_promoted": 0,
        "candidates_rejected_trust": 0, "promoted_ids": [], "queue_open": 0,
        "soul_candidates_added": 0, "soul_skipped_duplicate": 0,
        "tasks_added": 0, "tasks_closed": 0, "tasks_skipped_duplicate": 0,
        "session_summary_lines": 0, "dirty_files_consolidated": 0,
        "touched_files_seen": 0, "warnings": [],
    }
    touched: list = []

    try:
        apply_learnings(args.mem, plan, date, args.dry_run, touched, tally)
        apply_user_candidates(args.mem, plan, date, args.dry_run, touched, tally)
        apply_soul_candidates(args.mem, plan, date, args.dry_run, touched, tally)
        apply_open_tasks(args.mem, plan, date, args.dry_run, touched, tally)
        apply_session_summary(args.mem, plan, args.dry_run, touched, tally)
        # LAST: marker only after everything else succeeded (Step 9.5 rule 5)
        apply_consolidation(args.mem, plan, session_id, args.dry_run, touched, tally)
    except PlanError as e:
        print(json.dumps({"ok": False, "error": str(e), "files_written": touched,
                          "note": "consolidation marker NOT written - dirty state stays honest"},
                         ensure_ascii=False))
        return 2

    identity_line = (
        f"Identity: {tally['candidates_new'] + tally['candidates_updated']} beobachtet, "
        f"{tally['candidates_promoted']} → user.md promotet, "
        f"{tally['soul_candidates_added']} soul-candidates; "
        f"Queue: {tally['queue_open']} offen"
    )
    print(json.dumps({
        "ok": True,
        "dry_run": args.dry_run,
        "date": date,
        "session_id": session_id,
        "files_written": touched,
        "tally": tally,
        "identity_status_line": identity_line,
    }, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
