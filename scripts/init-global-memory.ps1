# Initialize global cross-project memory store
# Location: ~/.claude-memory/global/
# Cross-platform: Use this on Windows. For macOS/Linux, use init-global-memory.sh

$GlobalDir = Join-Path $env:USERPROFILE ".claude-memory" "global"

if (-not (Test-Path $GlobalDir)) {
    New-Item -ItemType Directory -Path $GlobalDir -Force | Out-Null
}

$files = @{
    "patterns.json"       = "[]"
    "learnings.json"      = "[]"
    "projects.json"       = '{"projects": []}'
    "agent-profile.json"  = @'
{
  "initialized": null,
  "total_sessions": 0,
  "total_iterations": 0,
  "preferred_patterns": [],
  "common_errors": [],
  "stack_experience": {}
}
'@
}

foreach ($file in $files.GetEnumerator()) {
    $path = Join-Path $GlobalDir $file.Key
    if (-not (Test-Path $path)) {
        Set-Content -Path $path -Value $file.Value -Encoding UTF8
    }
}

Write-Host "Global memory initialized at $GlobalDir"
