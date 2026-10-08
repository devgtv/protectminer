# Test harness for antiminer-browser.ps1 (registry commands are mocked)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'protectminer-tests-browser'
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# AST-load the functions without running the script body
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$repo/antiminer-browser.ps1", [ref]$tokens, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

$script:logDirectory = "$tmp/logs"
$script:logPath = "$tmp/logs/antiminer-browser.log"

# --- mock registry ---
$script:reg = @{}

function New-Item {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [string]$ItemType, [switch]$Force, [string]$Name, [object]$Value)
    if ($ItemType -eq 'Directory') { return Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType Directory -Force }
    if (-not $script:reg.ContainsKey($Path)) { $script:reg[$Path] = @{} }
    return $script:reg[$Path]
}

function Get-Item {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not $script:reg.ContainsKey($Path)) { return $null }
    $key = [pscustomobject]@{ Store = $script:reg[$Path] }
    $key | Add-Member -MemberType ScriptMethod -Name GetValueNames -Value { @($this.Store.Keys) }
    $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) $this.Store[$name] }
    return $key
}

function New-ItemProperty {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value, [string]$PropertyType, [switch]$Force)
    if (-not $script:reg.ContainsKey($Path)) { $script:reg[$Path] = @{} }
    $script:reg[$Path][$Name] = $Value
    return $Value
}

$failures = @()
function Assert-True { param($cond, $msg) if (-not $cond) { $script:failures += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red } else { Write-Host "PASS: $msg" } }

$chromePath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
$id = 'jfnangjojcioomickmmnfmiadkfhcdmd'
$updateUrl = 'https://clients2.google.com/service/update2/crx'
$expected = "$id;$updateUrl"

# 1. fresh install lands on index 1
Set-ExtensionPolicy -Path $chromePath -Name 'Google Chrome' -Value $expected
Assert-True ($script:reg[$chromePath]['1'] -eq $expected) "writes the policy at index 1"

# 2. running it again must not create a second entry
Set-ExtensionPolicy -Path $chromePath -Name 'Google Chrome' -Value $expected
Assert-True ($script:reg[$chromePath].Count -eq 1) "is idempotent (still a single value)"

# 3. an unrelated policy at index 1 must be preserved and we move to index 2
$otherPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
$script:reg[$otherPath] = @{}; $script:reg[$otherPath]['1'] = 'otherextension;https://example.com'
Set-ExtensionPolicy -Path $otherPath -Name 'Microsoft Edge' -Value $expected
Assert-True ($script:reg[$otherPath]['1'] -eq 'otherextension;https://example.com') "never overwrites an existing entry"
Assert-True ($script:reg[$otherPath]['2'] -eq $expected) "uses the first free index"

# 4. duplicates are detected even when stored in a later index
$script:reg[$otherPath]['3'] = $expected
$before = $script:reg[$otherPath].Count
Set-ExtensionPolicy -Path $otherPath -Name 'Microsoft Edge' -Value $expected
Assert-True ($script:reg[$otherPath].Count -eq $before) "detects the value in a later index"

# 5. Firefox policy receives a real .xpi URL, not a placeholder
$firefoxPath = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install'
Set-ExtensionPolicy -Path $firefoxPath -Name 'Mozilla Firefox' -Value 'https://addons.mozilla.org/firefox/downloads/latest/nominer-block-coin-miners/latest.xpi'
Assert-True ($script:reg[$firefoxPath]['1'] -like '*.xpi') "Firefox gets a .xpi URL"

if ($failures.Count) { Write-Host "`n$($failures.Count) failure(s)" -ForegroundColor Red; exit 1 }
Write-Host "`nAll browser script tests passed."
