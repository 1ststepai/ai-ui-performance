[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('Check','Speed','Restore')][string]$Mode = 'Check')
& (Join-Path $PSScriptRoot '..\..\ai-ui-performance\scripts\AI-UI-Performance.ps1') -Mode $Mode -App Codex -WhatIf:$WhatIfPreference
if (!$?) { exit 1 }
