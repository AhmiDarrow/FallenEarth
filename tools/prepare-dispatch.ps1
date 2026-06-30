# prepare-dispatch.ps1
# Optional helper. Normally Remedy performs all this automatically by writing files.
# Usage example (if you ever want to trigger manually):
#   pwsh tools/prepare-dispatch.ps1 -Target claude -Task "Implement X" -HandoffPath "memory/SESSION_NOTES/....md"

param(
    [string]$Target = "claude",
    [string]$Task,
    [string]$HandoffPath
)

$base = Split-Path $PSScriptRoot -Parent
$dispatchDir = Join-Path $base "memory\dispatches\$Target"
New-Item -ItemType Directory -Force $dispatchDir | Out-Null

$ts = Get-Date -Format "yyyy-MM-dd_HHmm"
$dispatchFile = Join-Path $dispatchDir "DISPATCH_$ts.md"

$content = @"
# AUTOMATIC DISPATCH FOR $Target.ToUpper()

**Generated:** $ts
**Atomic Task:** $Task

## Instructions for Receiving Agent
Read this file completely.
Then read the referenced LATEST_HANDOFF and only the minimal supporting files.
Complete ONLY the atomic task.
When finished, write a proper handoff into SESSION_NOTES/ and update LATEST_HANDOFF.md.

## Linked Handoff
$HandoffPath

## Next Steps After Completion
Return to Remedy (Hermes). Remedy will auto-ingest.
"@

Set-Content -Path $dispatchFile -Value $content
Write-Host "Dispatch prepared: $dispatchFile"
Write-Host "Remedy normally does this for you automatically."
