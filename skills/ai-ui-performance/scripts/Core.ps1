Set-StrictMode -Version Latest

function Get-UIProcessRole($Process) {
    if ($Process.MainWindowHandle -ne [IntPtr]::Zero) { return 'main' }
    return 'unknown'
}

function Read-PerformanceState($File) {
    if (!(Test-Path -LiteralPath $File)) { return @() }
    $state = Get-Content -LiteralPath $File -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($state.Version -ne 1) { throw 'Unsupported performance state. Preserve it and inspect before retrying.' }
    foreach ($record in @($state.Records)) {
        if ($record.OriginalPriority -ne 'Normal' -or $record.AppliedPriority -ne 'AboveNormal' -or
            $record.ProcessId -le 0 -or $record.StartTimeTicks -notmatch '^\d+$' -or
            [IO.Path]::GetFileName($record.Path) -notin 'ChatGPT.exe','claude.exe','Cursor.exe','chrome.exe','msedge.exe','brave.exe') { throw 'Invalid performance state; nothing changed.' }
        $record
    }
}

function Save-PerformanceState($File, $Records) {
    $temporary = $File + '.new'
    $json = @{ Version = 1; Records = @($Records) } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
    # Flush the journal before changing a process so interruption still leaves an undo record.
    $stream = [IO.File]::Open($temporary, 'Open', 'ReadWrite', 'None')
    try { $stream.Flush($true) } finally { $stream.Dispose() }
    if ([IO.File]::Exists($File)) { [IO.File]::Replace($temporary, $File, $File + '.previous') }
    else { [IO.File]::Move($temporary, $File) }
}

function Get-VerifiedProcess($Record, $AllowedPaths) {
    if ($Record.Path -notin $AllowedPaths) { return $null }
    try {
        $process = Get-Process -Id $Record.ProcessId -ErrorAction Stop
        if ($process.Path -ne $Record.Path -or [string]$process.StartTime.ToUniversalTime().Ticks -ne $Record.StartTimeTicks) { return $null }
        return $process
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] { return $null }
}

function Set-VerifiedPriority($Process, $Priority, $ExpectedPriority) {
    $Process.Refresh()
    if ($ExpectedPriority -and [string]$Process.PriorityClass -ne $ExpectedPriority) { throw 'The process changed its priority before the write; left unchanged.' }
    $Process.PriorityClass = [Diagnostics.ProcessPriorityClass]::$Priority
    $Process.Refresh()
    if ([string]$Process.PriorityClass -ne $Priority) { throw 'Priority readback did not match the requested value.' }
}

function Invoke-PerformanceProfile($Mode, $Inventory, $AllowedPaths, $StateFile, $Preview) {
    $records = @(Read-PerformanceState $StateFile)
    $results = [Collections.Generic.List[object]]::new()
    $targets = if ($Mode -eq 'Speed') { @($Inventory | Where-Object { $_.Role -eq 'main' -and $_.Priority -eq 'Normal' -and $_.Path -in $AllowedPaths }) } else { @($records | Where-Object { $_.Path -in $AllowedPaths }) }
    foreach ($target in $targets) {
        $record = if ($Mode -eq 'Speed') {
            [pscustomobject]@{ ProcessId = $target.ProcessId; Path = $target.Path; StartTimeTicks = $target.StartTimeTicks; OriginalPriority = 'Normal'; AppliedPriority = 'AboveNormal' }
        } else { $target }
        try {
            $process = Get-VerifiedProcess $record $AllowedPaths
            $expected = if ($Mode -eq 'Speed') { 'Normal' } else { 'AboveNormal' }
            $desired = if ($Mode -eq 'Speed') { 'AboveNormal' } else { 'Normal' }
            if (!$process) { $status = 'SkippedStaleIdentity' }
            elseif ([string]$process.PriorityClass -ne $expected) { $status = 'SkippedChangedPriority' }
            elseif ($Preview) { $status = 'Would' + $Mode }
            else {
                if ($Mode -eq 'Speed') {
                    $existing = @($records | Where-Object { $_.ProcessId -eq $record.ProcessId -and $_.Path -eq $record.Path -and $_.StartTimeTicks -eq $record.StartTimeTicks })
                    if (!$existing.Count) { $records += $record }
                    Save-PerformanceState $StateFile $records
                }
                Set-VerifiedPriority $process $desired $expected
                $status = if ($Mode -eq 'Speed') { 'Applied' } else { 'Restored' }
            }
            if ($Mode -eq 'Restore' -and !$Preview) {
                $records = @($records | Where-Object { !($_.ProcessId -eq $record.ProcessId -and $_.Path -eq $record.Path -and $_.StartTimeTicks -eq $record.StartTimeTicks) })
                Save-PerformanceState $StateFile $records
            }
            $results.Add([pscustomobject]@{ ProcessId = $record.ProcessId; Status = $status })
        } catch {
            $results.Add([pscustomobject]@{ ProcessId = $record.ProcessId; Status = 'Failed'; Error = $_.Exception.Message })
        }
    }
    [pscustomobject]@{ Mode = $Mode; Preview = [bool]$Preview; Results = @($results.ToArray()); Failed = @($results | Where-Object Status -eq 'Failed').Count; OwnedRecords = $records.Count }
}
