---
name: rollback
description: Rollback the last self-improvement iteration by reverting the most recent self-improve commit.
---

# Self-Improve Rollback

Revert the last self-improvement change.

## Instructions

1. Run `git log --oneline -10` in the plugin directory
2. Find the most recent commit matching `fix(self-improve):*`
3. Show the commit to the user and ask for confirmation
4. If confirmed: `git revert {commit_hash} --no-edit`
5. Update `improvements/state.json`: remove the last history entry
6. Report what was reverted
