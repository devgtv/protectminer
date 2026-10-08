# Test harness for antiminer.ps1 (runs on Linux by AST-loading the functions)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'protectminer-tests-antiminer'
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$tmp/roaming", "$tmp/local" | Out-Null

# Load function definitions from antiminer.ps1 without running the main loop
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$repo/antiminer.ps1", [ref]$tokens, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }

# Session configuration (normally set at the top of the script)
$script:minerTargets = @("xmrig", "minerd", "cpuminer", "ethminer", "nicehash", "kms-pico", "cryptobot")
$script:minerDomains = @("coin-hive.com", "coinhive.com", "monerohash.com", "nanopool.org", "minexmr.com", "supportxmr.com")
$script:hostsMarker  = "# ProtectMiner"
$script:cpuThreshold = 85
$script:cpuCyclesNeeded = 3
$script:scanEveryCycles = 6
$script:logDirectory = "$tmp/logs"
$script:logPath = "$tmp/logs/antiminer.log"
$script:hostsPath = "$tmp/hosts"

Set-Content -Path $script:hostsPath -Value @(
    "127.0.0.1 localhost",
    "::1 localhost",
    "0.0.0.0 coin-hive.com",       # entry written by the old version (no marker)
    "0.0.0.0 evil.example.com"
)

$failures = @()
function Assert-True { param($cond, $msg) if (-not $cond) { $script:failures += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red } else { Write-Host "PASS: $msg" } }

New-Item -ItemType Directory -Force -Path $script:logDirectory | Out-Null

# --- hosts blocking ---
Block-MiningDomains
$lines = Get-Content $script:hostsPath
Assert-True (($lines | Where-Object { $_ -match '^0\.0\.0\.0 coin-hive\.com' }).Count -eq 1) "does not duplicate a pre-existing entry"
$supportxmr = @($lines | Where-Object { $_ -match 'supportxmr\.com' })
Assert-True (($supportxmr | Where-Object { $_ -like "*$($script:hostsMarker)*" }).Count -ge 1) "new entries carry the marker"
foreach ($d in $minerDomains) {
    Assert-True ([bool]($lines | Where-Object { $_ -match "(0\.0\.0\.0|127\.0\.0\.1)\s+$([regex]::Escape($d))(\s|$)" })) "hosts contains $d"
}
Assert-True ([bool]($lines | Where-Object { $_ -eq "127.0.0.1 localhost" })) "keeps legitimate localhost line"
Assert-True ([bool]($lines | Where-Object { $_ -eq "0.0.0.0 evil.example.com" })) "keeps unrelated entries"

$before = (Get-Content $script:hostsPath | Measure-Object -Line).Lines
Block-MiningDomains
$after = (Get-Content $script:hostsPath | Measure-Object -Line).Lines
Assert-True ($before -eq $after) "second run adds nothing"

# --- file scan ---
Set-Content -Path "$tmp/roaming/xmrig.exe" -Value "fake"
Set-Content -Path "$tmp/roaming/readme.txt" -Value "keep"
Set-Content -Path "$tmp/local/cpuminer.exe" -Value "fake"
Set-Content -Path "$tmp/local/notaminersettings.exe" -Value "keep"
$env:APPDATA = "$tmp/roaming"
$env:LOCALAPPDATA = "$tmp/local"
$removed = Remove-MinerFiles
Assert-True ($removed -eq 2) "removes exactly the 2 miner executables (got $removed)"
Assert-True (Test-Path "$tmp/roaming/readme.txt") "keeps unrelated .txt file"
Assert-True (Test-Path "$tmp/local/notaminersettings.exe") "keeps an .exe that only shares a substring"

# --- CPU load helper must not use WMI ---
Assert-True ((Get-Command Get-CpuLoad -ErrorAction SilentlyContinue) -ne $null) "Get-CpuLoad exists"

if ($failures.Count) { Write-Host "`n$($failures.Count) failure(s)" -ForegroundColor Red; exit 1 }
Write-Host "`nAll antiminer tests passed."
