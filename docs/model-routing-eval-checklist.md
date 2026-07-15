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
