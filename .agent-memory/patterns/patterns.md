# Pattern-Katalog

## Anti-Patterns

### pattern-001: Windows/Git Bash Compatibility (confidence: 0.7)
Shell scripts fail on Windows due to bash arithmetic with set -e, path spaces in string interpolation, and git pathspec syntax differences. Prevention: Use $((VAR + 1)), pass paths via process.argv, test on Windows.
