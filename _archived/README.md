# _archived — retired plugin components

Nothing in this directory is loaded by Claude Code: the plugin loader reads
`skills/`, `commands/`, `agents/`, `hooks/` only. Files here are kept so a
revival is a `git mv` instead of an archaeology dig.

| Component | Archived | Why | Revive by |
|---|---|---|---|
| `skills/self-improve/` | 2026-09-08 (v5.0.0) | silent since 2026-06-21; 21 KB policy body with no usage evidence (Gesamtanalyse 2026-09 F6/V5); the eval harness (lever 6) lives on in `tests/eval/` | `git mv` back to `skills/`, add a `strong` row to `scripts/model-routing.sh`, restore its tests from git history (`git log --all -- tests/validate-skills.sh`) |
| `commands/rollback.md` | 2026-09-08 (v5.0.0) | only reverted self-improve commits; never used | `git mv` back to `commands/` |
| `commands/auto-commit.md` | 2026-09-08 (v5.0.0) | only called by self-improve; never used interactively | `git mv` back to `commands/` |
| `improvements/` | 2026-09-08 (v5.0.0) | self-improve loop state (`state.json`, batch logs, clusters) — meaningless without the skill | `git mv` back to the plugin root |

Removed earlier and NOT archived (deleted outright, see `docs/CHANGELOG.md`):
retrospective, research-pipeline, wiki-query, quality-gate, skill-generator (v4.0.0);
improvement-agent, research-agent (4.15.0).
