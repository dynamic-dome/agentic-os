# Model-Routing v4.7.0 — Manual Eval Checklist

> **Status 2026-07-27: E0 FAILS.** The `model:` frontmatter does not switch
> the main-loop model (CC 2.1.215 + 2.1.220). Run E0 first — while it fails,
> E1–E5 test the *behaviour* of the skills but say nothing about which model
> executed them. Details: header of `scripts/model-routing.sh`.
>
> **Update 2026-09-09 (CC 2.1.263 + 2.1.266):** the routing is PATH-dependent.
> Slash invocation (`/agentic-os:wrap-up`, `/agentic-os:session-bootstrap`) DOES
> switch the request model to `claude-sonnet-5` for the skill's turns and reverts
> afterwards (transcript `message.model`). Skill-tool invocation still does NOT
> switch the request model — only the system-prompt identity text changes
> ("powered by Sonnet 5"), the assistant message keeps the session model
> (probe 2026-09-09, membrain session 10f7252d). Cost savings therefore require
> the slash path; the Agent tool needs an explicit `model:` at the call site.

The spec's model-dependent test cases (memospartoken.md section 24) cannot be
asserted by bash tests without faking model behavior. They are checked
manually after release, one real session each. Record results as an
iteration-log entry.

## E0 — Does the routing fire at all? (transcript probe)

The `validate-skills.sh` routing test only proves frontmatter and SSoT table
agree. It cannot prove the runtime honours either. This probe can:

1. Create `~/.claude/skills/model-routing-probe/SKILL.md` with frontmatter
   `model: sonnet`, `effort: low` and a body that says "do nothing, return
   immediately".
2. In a session running on a NON-sonnet model, invoke the probe via the
   Skill tool.
3. Make one more tool call (the transcript is flushed one message behind),
   then read
   `~/.claude/projects/<project-slug>/<session-id>.jsonl` and compare the
   `message.model` field of the assistant messages before and after the
   Skill result.
4. Delete the probe skill afterwards.

Pass: messages after the Skill result carry `claude-sonnet-*`.
Fail: they keep the session model — the frontmatter is inert.

The same probe works for agents; their transcripts live under
`~/.claude/projects/<project-slug>/<session-id>/subagents/*.jsonl`. Prefer
passing `model` explicitly at the Agent call site over trusting frontmatter.

## E1–E5 — Behavioural cases

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
