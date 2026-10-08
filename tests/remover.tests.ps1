# Test harness for remove-protections.ps1 (registry commands are mocked)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'protectminer-tests-remover'
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$repo/remove-protections.ps1", [ref]$tokens, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

# --- session configuration ---
$script:hostsPath = "$tmp/hosts"
$script:hostsMarker = '# ProtectMiner'
$script:extensionId = 'jfnangjojcioomickmmnfmiadkfhcdmd'
$script:firefoxAddonUrl = 'https://addons.mozilla.org/firefox/downloads/latest/nominer-block-coin-miners/latest.xpi'
$script:minerDomains = @('coin-hive.com', 'coinhive.com', 'monerohash.com', 'nanopool.org', 'minexmr.com', 'supportxmr.com', '://supportxmr.com')
$script:policyPaths = @(
    @{ Name = 'Google Chrome'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist' },
    @{ Name = 'Microsoft Edge'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist' },
    @{ Name = 'Mozilla Firefox'; Path = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install' }
)
$script:logDirectory = "$tmp/logs"
$script:logPath = "$tmp/logs/remove-protections.log"

# --- wrappers so $PSCmdlet.ShouldProcess is available inside the functions ---
function Invoke-HostsRemoval { [CmdletBinding(SupportsShouldProcess)] param() Remove-HostsEntries }
function Invoke-PolicyRemoval { [CmdletBinding(SupportsShouldProcess)] param() Remove-ExtensionPolicies }

# --- mock registry ---
$script:reg = @{}

function Test-Path {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -like 'HKLM:*') { return $script:reg.ContainsKey($Path) }
    return Microsoft.PowerShell.Management\Test-Path -Path $Path
}

function Get-Item {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -like 'HKLM:*') {
        if (-not $script:reg.ContainsKey($Path)) { return $null }
        $key = [pscustomobject]@{ Store = $script:reg[$Path] }
        $key | Add-Member -MemberType ScriptMethod -Name GetValueNames -Value { @($this.Store.Keys) }
        $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) $this.Store[$name] }
        return $key
    }
    return Microsoft.PowerShell.Management\Get-Item -Path $Path
}

function Remove-ItemProperty {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name, [switch]$Force)
    if (-not $script:reg.ContainsKey($Path)) { throw "No such key: $Path" }
    $script:reg[$Path].Remove($Name)
}

function Remove-Item {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$Recurse, [switch]$Force, [string]$ItemType)
    if ($Path -like 'HKLM:*') {
        if (-not $script:reg.Remove($Path)) { throw "No such key: $Path" }
        return
    }
    Microsoft.PowerShell.Management\Remove-Item -Path $Path -Recurse:$Recurse -Force:$Force
}

$failures = @()
function Assert-True { param($cond, $msg) if (-not $cond) { $script:failures += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red } else { Write-Host "PASS: $msg" } }

# --- 1. hosts removal ---
Set-Content -Path $script:hostsPath -Value @(
    '127.0.0.1 localhost',
    '::1 localhost',
    "0.0.0.0 coin-hive.com $script:hostsMarker",
    '0.0.0.0 minexmr.com # ProtectMiner',
    '0.0.0.0 ://supportxmr.com',          # written by the old version
    '0.0.0.0 coinhive.com',               # written by the old version
    '0.0.0.0 evil.example.com',
    '0.0.0.0 mybank.internal'
)

$null = Invoke-HostsRemoval
$lines = @(Get-Content $script:hostsPath)
Assert-True (-not ($lines | Where-Object { $_ -match 'ProtectMiner|coin-hive|minexmr|supportxmr|coinhive' })) "all ProtectMiner hosts entries removed"
Assert-True ([bool]($lines | Where-Object { $_ -eq '127.0.0.1 localhost' })) "keeps localhost"
Assert-True ([bool]($lines | Where-Object { $_ -eq '0.0.0.0 evil.example.com' })) "keeps unrelated block entries"
Assert-True ([bool]($lines | Where-Object { $_ -eq '0.0.0.0 mybank.internal' })) "keeps other protected entries"

# --- 2. -WhatIf must not change anything ---
Set-Content -Path $script:hostsPath -Value @(
    '127.0.0.1 localhost',
    "0.0.0.0 coin-hive.com $script:hostsMarker"
)
$null = Invoke-HostsRemoval -WhatIf
$lines = @(Get-Content $script:hostsPath)
Assert-True ($lines.Count -eq 2) "-WhatIf leaves the hosts file untouched"
Assert-True ([bool]($lines | Where-Object { $_ -match 'coin-hive' })) "-WhatIf keeps the entry in place"

# --- 3. browser policies ---
$chromePath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
$edgePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
$firefoxPath = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install'

$script:reg[$chromePath] = @{
    '1' = "$($script:extensionId);https://clients2.google.com/service/update2/crx"
    '2' = 'someoneelse;https://example.com'
}
$script:reg[$firefoxPath] = @{ '1' = $script:firefoxAddonUrl }
$script:reg[$edgePath] = @{}    # present but not written by ProtectMiner

$null = Invoke-PolicyRemoval
Assert-True (-not $script:reg[$chromePath].ContainsKey('1')) "removes the Chrome NoMiner value"
Assert-True ($script:reg[$chromePath]['2'] -eq 'someoneelse;https://example.com') "keeps the unrelated Chrome value"
Assert-True ([bool]$script:reg.ContainsKey($chromePath)) "keeps the Chrome key (still in use)"
Assert-True (-not $script:reg.ContainsKey($firefoxPath)) "deletes the Firefox key once it is empty"
Assert-True ($script:reg.ContainsKey($edgePath)) "leaves an untouched policy key alone"

# --- 4. nothing to do on a machine without ProtectMiner policies ---
$script:reg = @{}
$before = $script:reg.Count
$null = Invoke-PolicyRemoval
Assert-True ($script:reg.Count -eq $before) "no-op when no policy keys exist"

if ($failures.Count) { Write-Host "`n$($failures.Count) failure(s)" -ForegroundColor Red; exit 1 }
Write-Host "`nAll remove-protections tests passed."
