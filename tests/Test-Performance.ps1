$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\ai-ui-performance\scripts\Core.ps1')
. (Join-Path $PSScriptRoot '..\skills\ai-ui-performance\scripts\Apps.ps1')
$checks = 0
function Assert($Condition, $Message) {
    if (!$Condition) { throw $Message }
    $script:checks++
}
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-performance-test-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$child = $null
try {
    $signature = [pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Subject='CN=Google LLC, O=Google LLC, C=US'}}
    Assert (Test-UIAppSignature $signature 'Google LLC') 'Valid publisher rejected'
    $signature.SignerCertificate.Subject = 'CN=Google LLC, O=Fake Google LLC, C=US'
    Assert (!(Test-UIAppSignature $signature 'Google LLC')) 'Publisher substring spoof accepted'
    $signature.SignerCertificate.Subject = 'CN=Google LLC, O=Unrelated Company, C=US'
    Assert (!(Test-UIAppSignature $signature 'Google LLC')) 'Common-name spoof accepted'
    $signature.SignerCertificate.Subject = 'CN="Brave Software, Inc.", O="Brave Software, Inc.", C=US'
    Assert (Test-UIAppSignature $signature 'Brave Software(?:,? Inc\.?)?') 'Quoted publisher organization rejected'
    $signature.Status = 'NotSigned'
    Assert (!(Test-UIAppSignature $signature 'Brave Software(?:,? Inc\.?)?')) 'Unsigned executable accepted'
    $executable = Join-Path $PSHOME 'powershell.exe'
    $child = Start-Process -FilePath $executable -ArgumentList '-NoProfile -NonInteractive -Command Start-Sleep -Seconds 45' -WindowStyle Hidden -PassThru
    $child.PriorityClass = 'Normal'
    $identity = [pscustomobject]@{ ProcessId = $child.Id; Path = $child.Path; StartTimeTicks = [string]$child.StartTime.ToUniversalTime().Ticks }
    Assert ($null -eq (Get-VerifiedProcess $identity @('C:\wrong\ChatGPT.exe'))) 'Wrong executable allowed'
    $wrongStart = [pscustomobject]@{ ProcessId = $child.Id; Path = $child.Path; StartTimeTicks = '1' }
    Assert ($null -eq (Get-VerifiedProcess $wrongStart @($executable))) 'PID reuse allowed'
    $verified = Get-VerifiedProcess $identity @($executable)
    Assert ($null -ne $verified) 'Real child identity was not verified'
    Set-VerifiedPriority $verified 'AboveNormal'
    Assert ([string]$verified.PriorityClass -eq 'AboveNormal') 'Real priority apply failed'
    Set-VerifiedPriority $verified 'Normal'
    Assert ([string]$verified.PriorityClass -eq 'Normal') 'Real priority restore failed'
    $caught = $false
    try { Set-VerifiedPriority $verified 'AboveNormal' 'Idle' } catch { $caught = $true }
    Assert ($caught -and [string]$verified.PriorityClass -eq 'Normal') 'Priority changed after a conflicting read'
    $child.Kill()
    $child.WaitForExit()
    Assert ($null -eq (Get-VerifiedProcess $identity @($executable))) 'Exited process was not skipped'

    # Mock only OS handles; use the real journal and profile logic for deterministic edge cases.
    $script:handles = @{}
    $script:deny = $false
    function Get-VerifiedProcess($Record, $AllowedPaths) {
        if ($Record.Path -notin $AllowedPaths) { return $null }
        $handle = $script:handles[[int]$Record.ProcessId]
        if (!$handle -or $handle.StartTimeTicks -ne $Record.StartTimeTicks) { return $null }
        $handle
    }
    function Set-VerifiedPriority($Process, $Priority) {
        if ($script:deny) { throw 'Simulated access denied' }
        $Process.PriorityClass = $Priority
    }
    $app = 'C:\fixture\OpenAI.Codex\app\ChatGPT.exe'
    $file = Join-Path $temporaryRoot 'profile.json'
    function New-Fixture($Number, $Role, $Priority, $Path = $app) {
        $script:handles[$Number] = [pscustomobject]@{ PriorityClass = $Priority; StartTimeTicks = [string]$Number }
        [pscustomobject]@{ ProcessId = $Number; Path = $Path; StartTimeTicks = [string]$Number; Role = $Role; Priority = $Priority }
    }
    $inventory = @((New-Fixture 1 'main' 'Normal'), (New-Fixture 2 'renderer' 'Idle'), (New-Fixture 3 'gpu-process' 'Normal'), (New-Fixture 4 'renderer' 'Normal' 'C:\other\ChatGPT.exe'))
    $preview = Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $true
    Assert ($preview.Results.Count -eq 1 -and $preview.Results[0].Status -eq 'WouldSpeed') 'Preview selection failed'
    Assert (!(Test-Path -LiteralPath $file) -and $handles[1].PriorityClass -eq 'Normal') 'Preview changed state'
    $applied = Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $false
    Assert ($applied.Results.Count -eq 1 -and $applied.Results[0].Status -eq 'Applied') 'Active UI selection failed'
    Assert ($handles[2].PriorityClass -eq 'Idle' -and $handles[3].PriorityClass -eq 'Normal' -and $handles[4].PriorityClass -eq 'Normal') 'Unrelated or idle process changed'
    $repeat = Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $false
    $journal = @(Read-PerformanceState $file)
    Assert ($journal.Count -eq 1 -and $journal[0].OriginalPriority -eq 'Normal') 'Repeated apply lost original priority'
    $restored = Invoke-PerformanceProfile 'Restore' @() @($app) $file $false
    Assert ($restored.Results[0].Status -eq 'Restored' -and $handles[1].PriorityClass -eq 'Normal') 'Restore failed'
    Assert (@(Read-PerformanceState $file).Count -eq 0) 'Restored journal not retired'

    Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $false | Out-Null
    $handles[1].PriorityClass = 'Idle'
    $conflict = Invoke-PerformanceProfile 'Restore' @() @($app) $file $false
    Assert ($conflict.Results[0].Status -eq 'SkippedChangedPriority' -and $handles[1].PriorityClass -eq 'Idle') 'Later app priority overwritten'
    $handles[1].PriorityClass = 'Normal'
    Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $false | Out-Null
    $handles[1].StartTimeTicks = '99'
    $stale = Invoke-PerformanceProfile 'Restore' @() @($app) $file $false
    Assert ($stale.Results[0].Status -eq 'SkippedStaleIdentity') 'Reused PID restored'
    $handles[1].StartTimeTicks = '1'
    $handles[1].PriorityClass = 'Normal'
    $script:deny = $true
    $denied = Invoke-PerformanceProfile 'Speed' $inventory @($app) $file $false
    Assert ($denied.Failed -eq 1 -and @(Read-PerformanceState $file).Count -eq 1) 'Failed apply lost undo journal'
    $script:deny = $false
    $badFile = Join-Path $temporaryRoot 'missing\profile.json'
    $writeFailure = Invoke-PerformanceProfile 'Speed' $inventory @($app) $badFile $false
    Assert ($writeFailure.Failed -eq 1 -and $handles[1].PriorityClass -eq 'Normal') 'Journal failure still mutated process'
    $claudePath = 'C:\fixture\Claude\app\claude.exe'
    $cursorPath = 'C:\fixture\Cursor\Cursor.exe'
    $browserPath = 'C:\fixture\Chrome\chrome.exe'
    $catalog = @(
        [pscustomobject]@{App='Claude';Category='Desktop';Path=$claudePath},
        [pscustomobject]@{App='Cursor';Category='Desktop';Path=$cursorPath},
        [pscustomobject]@{App='Chrome';Category='Browser';Path=$browserPath}
    )
    Assert (@(Select-UIApps $catalog 'Desktop').Count -eq 2) 'Desktop selection included browsers'
    Assert (@(Select-UIApps $catalog 'Gemini')[0].Path -eq $browserPath) 'Gemini browser alias failed'
    Assert (@(Select-UIApps $catalog 'Grok')[0].Path -eq $browserPath) 'Grok browser alias failed'
    Assert (@(Select-UIApps $catalog 'Codex').Count -eq 0) 'Missing app selected another app'
    $multi = @((New-Fixture 5 'main' 'Normal' $claudePath),(New-Fixture 6 'renderer' 'Normal' $cursorPath),(New-Fixture 7 'renderer' 'Normal' $browserPath))
    $multiFile = Join-Path $temporaryRoot 'multi.json'
    $desktopPaths = @(Select-UIApps $catalog 'Desktop' | ForEach-Object Path)
    $multiApply = Invoke-PerformanceProfile 'Speed' $multi $desktopPaths $multiFile $false
    Assert ($multiApply.Results.Count -eq 2 -and $handles[7].PriorityClass -eq 'Normal') 'Browser changed without desktop scope permission'
    $scopedRestore = Invoke-PerformanceProfile 'Restore' @() @($claudePath) $multiFile $false
    Assert ($scopedRestore.Results.Count -eq 1 -and $handles[5].PriorityClass -eq 'Normal' -and $handles[6].PriorityClass -eq 'AboveNormal' -and @(Read-PerformanceState $multiFile).Count -eq 1) 'Scoped restore discarded another app record'
    $browserApply = Invoke-PerformanceProfile 'Speed' $multi @($browserPath) $multiFile $false
    Assert ($browserApply.Results.Count -eq 1 -and $handles[7].PriorityClass -eq 'AboveNormal') 'Explicit browser apply failed'
    $allRestore = Invoke-PerformanceProfile 'Restore' @() @($claudePath,$cursorPath,$browserPath) $multiFile $false
    Assert ($allRestore.Results.Count -eq 2 -and @(Read-PerformanceState $multiFile).Count -eq 0) 'Combined restore failed'
    [IO.File]::WriteAllText($file, '{"Version":1,"Records":[{"OriginalPriority":"High"}]}')
    $caught = $false
    try { Read-PerformanceState $file | Out-Null } catch { $caught = $true }
    Assert $caught 'Invalid state accepted'
    $lockPath = Join-Path $temporaryRoot 'profile.lock'
    $firstLock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $caught = $false
    try { $secondLock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None'); $secondLock.Dispose() } catch { $caught = $true }
    finally { $firstLock.Dispose() }
    Assert $caught 'Concurrent profile lock accepted'
    [pscustomobject]@{ Status = 'PASS'; Checks = $checks; RealChildPriorityCycle = 'Normal -> AboveNormal -> Normal'; TemporaryFilesRemoved = $true } | ConvertTo-Json
} finally {
    if ($child -and !$child.HasExited) { $child.Kill(); $child.WaitForExit() }
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
