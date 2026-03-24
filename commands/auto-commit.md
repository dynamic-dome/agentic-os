---
description: "Stages all changed files (excluding .agent-memory/), creates a descriptive commit, and pushes to the current branch. Used by the self-improvement loop for automated commits."
user_invocable: true
arguments:
  - name: message
    description: "Commit message (optional, auto-generated if omitted)"
    required: false
---

# Auto-Commit & Push

## Procedure

1. **Check preconditions**:
   - Verify we're in a git repository: `git rev-parse --git-dir`
   - Check there are changes to commit: `git status --porcelain`
   - If no changes: report "Nothing to commit" and exit

2. **Run tests** (safety gate):
   - Execute `bash tests/run-all.sh` if the file exists
   - If tests FAIL: abort with "Tests failing, commit blocked"

3. **Stage files**:
   ```bash
   git add -A -- ':!.agent-memory'
   ```
   This stages everything EXCEPT the `.agent-memory/` directory.

4. **Create commit**:
   - If `$message` argument provided: use it as commit message
   - If not: auto-generate from `git diff --cached --stat`:
     ```
     chore(auto): update {primary_changed_area}

     Changed files: {file_count}
     {brief_summary_of_changes}

     Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
     ```

5. **Push**:
   ```bash
   git push
   ```
   - If push fails (no upstream): `git push -u origin $(git branch --show-current)`
   - If push still fails: report error but keep the local commit

6. **Report**:
   ```
   Committed: {hash} "{message}"
   Pushed to: {branch}
   Files changed: {count}
   ```
