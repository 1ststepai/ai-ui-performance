[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Check','Speed','Restore')][string]$Mode = 'Check',
    [ValidateSet('Desktop','Codex','Claude','Cursor','Browsers','Gemini','Grok','All')][string]$App = 'Desktop',
    [switch]$IncludeBrowsers
)

$ErrorActionPreference = 'Stop'
$preview = [bool]$WhatIfPreference
# Module imports set aliases; keep their housekeeping out of the profile preview.
$WhatIfPreference = $false
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Apps.ps1')
$stateDirectory = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\performance'
$stateFile = Join-Path $stateDirectory 'profile.json'
$lock = $null
try {
    $catalog = @(Get-UIAppCatalog)
    $selected = @(Select-UIApps $catalog $App)
    if ($Mode -eq 'Speed' -and @($selected | Where-Object Category -eq 'Browser').Count -and !$IncludeBrowsers) { throw 'Browser mode affects shared Chrome, Edge and Brave processes, including unrelated tabs. Use -IncludeBrowsers only when you want this browser-wide profile.' }
    $allowedPaths = @($selected | ForEach-Object Path)
    $inventory = @(
        foreach ($row in @(Get-CimInstance Win32_Process -Property ProcessId,ExecutablePath -Filter "Name='ChatGPT.exe' OR Name='claude.exe' OR Name='Cursor.exe' OR Name='chrome.exe' OR Name='msedge.exe' OR Name='brave.exe'" -ErrorAction Stop)) {
            $installed = @($catalog | Where-Object Path -eq $row.ExecutablePath)
            if (!$installed.Count) { continue }
            try {
                $process = Get-Process -Id $row.ProcessId -ErrorAction Stop
                if ($process.Path -ne $row.ExecutablePath) { continue }
                $role = Get-UIProcessRole $process
                [pscustomobject]@{ App = $installed[0].App; ProcessId = $row.ProcessId; Path = $process.Path; StartTimeTicks = [string]$process.StartTime.ToUniversalTime().Ticks; Role = $role; Priority = [string]$process.PriorityClass; MemoryMiB = [math]::Round($process.WorkingSet64 / 1MB) }
            } catch { Write-Warning "Could not inspect UI process $($row.ProcessId): $($_.Exception.Message)" }
        }
    )
    if ($Mode -eq 'Check') {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $availableGiB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $totalGiB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $top = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | ForEach-Object { @{ Name = $_.ProcessName; MemoryMiB = [math]::Round($_.WorkingSet64 / 1MB) } })
        [pscustomobject]@{
            Mode = 'Check'; Target = $App
            InstalledApps = @($catalog | Select-Object App,Category,Verification,Version)
            DesktopSupport = @('Codex','Claude','Cursor' | ForEach-Object { @{ App = $_; Status = if ($_ -in @($catalog | ForEach-Object App)) { 'Verified installation' } else { 'No verified supported installation found' } } })
            WebSupport = 'Gemini and Grok use the optional Chrome/Edge/Brave profile. It affects shared browser processes, not an isolated AI tab. Browser chat content is not inspected.'
            UIWorkingSetMiB = ($inventory | Measure-Object MemoryMiB -Sum).Sum
            TotalRAMGiB = $totalGiB; AvailableRAMGiB = $availableGiB
            MemoryPressure = if ($availableGiB -lt ($totalGiB * 0.1)) { 'Low available RAM' } else { 'Available RAM above 10 percent' }
            Processes = @($inventory | Select-Object App,ProcessId,Role,Priority,MemoryMiB)
            LargestProcesses = $top; PowerPlan = (@(& powercfg.exe /getactivescheme) -join ' ')
            OwnedRecords = @(Read-PerformanceState $stateFile).Count
            Guidance = 'Speed prioritizes verified active desktop UIs by default. Browser profiles require -IncludeBrowsers. It does not reduce RAM or speed cloud responses. Reapply after app restart; Restore undoes owned changes.'
        } | ConvertTo-Json -Depth 6
    } else {
        if (!@($inventory | Where-Object Path -in $allowedPaths).Count -and $Mode -eq 'Speed') { throw 'No running UI with a verified supported installation was found for this target. Open it and run Check to inspect support.' }
        if (!$preview) {
            if (!$PSCmdlet.ShouldProcess("Verified $App UI processes", "$Mode CPU priority profile")) { return }
            [IO.Directory]::CreateDirectory($stateDirectory) | Out-Null
            try { $lock = [IO.File]::Open((Join-Path $stateDirectory 'profile.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
            catch { throw 'Another performance command is running, or the state directory is unavailable. Retry when it finishes.' }
        }
        $result = Invoke-PerformanceProfile $Mode $inventory $allowedPaths $stateFile $preview
        $result | ConvertTo-Json -Depth 6
        if ($result.Failed) { exit 1 }
    }
} catch {
    [pscustomobject]@{ Mode = $Mode; Status = 'Failed'; Error = $_.Exception.Message } | ConvertTo-Json
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
