function Test-UIAppSignature($Signature, $PublisherPattern) {
    $organization = '(?:^|,\s*)O="?' + $PublisherPattern + '"?(?:,|$)'
    [bool]($Signature.Status -eq 'Valid' -and $Signature.SignerCertificate -and $Signature.SignerCertificate.Subject -match $organization)
}

function Get-UIAppCatalog {
    $catalog = [Collections.Generic.List[object]]::new()
    $packages = @(Get-AppxPackage -ErrorAction Stop)
    foreach ($definition in @(
        @{ App = 'Codex'; Package = 'OpenAI.Codex'; Family = 'OpenAI.Codex_2p2nqsd0c76g0'; Exe = 'ChatGPT.exe' },
        @{ App = 'Claude'; Package = 'Claude'; Family = 'Claude_pzs8sxrjxfjjc'; Exe = 'claude.exe' }
    )) {
        foreach ($package in @($packages | Where-Object { $_.Name -eq $definition.Package -and $_.PackageFamilyName -eq $definition.Family })) {
            $path = Join-Path $package.InstallLocation ('app\' + $definition.Exe)
            if (Test-Path -LiteralPath $path -PathType Leaf) { $catalog.Add([pscustomobject]@{ App = $definition.App; Category = 'Desktop'; Path = $path; Verification = 'Installed MSIX publisher'; Version = [string]$package.Version }) }
        }
    }
    $local = [Environment]::GetFolderPath('LocalApplicationData')
    $program = [Environment]::GetFolderPath('ProgramFiles')
    $program86 = [Environment]::GetFolderPath('ProgramFilesX86')
    foreach ($definition in @(
        @{ App = 'Claude'; Category = 'Desktop'; Publisher = 'Anthropic, PBC'; Relative = 'AnthropicClaude\Claude.exe'; Bases = @($local) },
        @{ App = 'Cursor'; Category = 'Desktop'; Publisher = 'Anysphere(?:,? Inc\.?)?'; Relative = 'Programs\cursor\Cursor.exe'; Bases = @($local) },
        @{ App = 'Cursor'; Category = 'Desktop'; Publisher = 'Anysphere(?:,? Inc\.?)?'; Relative = 'Cursor\Cursor.exe'; Bases = @($program,$program86) },
        @{ App = 'Chrome'; Category = 'Browser'; Publisher = 'Google LLC'; Relative = 'Google\Chrome\Application\chrome.exe'; Bases = @($program,$program86,$local) },
        @{ App = 'Edge'; Category = 'Browser'; Publisher = 'Microsoft Corporation'; Relative = 'Microsoft\Edge\Application\msedge.exe'; Bases = @($program,$program86,$local) },
        @{ App = 'Brave'; Category = 'Browser'; Publisher = 'Brave Software(?:,? Inc\.?)?'; Relative = 'BraveSoftware\Brave-Browser\Application\brave.exe'; Bases = @($program,$program86,$local) }
    )) {
        foreach ($base in $definition.Bases) {
            if (!$base) { continue }
            $path = Join-Path $base $definition.Relative
            if (!(Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $signature = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction Stop
            if (!(Test-UIAppSignature $signature $definition.Publisher)) { Write-Warning "Skipped $($definition.App): publisher signature could not be verified."; continue }
            $catalog.Add([pscustomobject]@{ App = $definition.App; Category = $definition.Category; Path = $path; Verification = 'Valid Authenticode publisher'; Version = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).ProductVersion })
        }
    }
    @($catalog.ToArray() | Sort-Object Path -Unique)
}

function Select-UIApps($Catalog, $App) {
    switch ($App) {
        'Desktop' { @($Catalog | Where-Object Category -eq 'Desktop') }
        'All' { @($Catalog) }
        { $_ -in 'Browsers','Gemini','Grok' } { @($Catalog | Where-Object Category -eq 'Browser') }
        default { @($Catalog | Where-Object App -eq $App) }
    }
}
