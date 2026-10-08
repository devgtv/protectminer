<#
    ProtectMiner - tests/run-tests.ps1
    Runs every *.tests.ps1 file in its own process so mocked commands from
    one file cannot leak into another. Exits with code 1 when any file fails.

    Usage:
        pwsh -NoProfile -File tests/run-tests.ps1
#>
[CmdletBinding()]
param(
    # Executable used to start each test file (defaults to the current host)
    [string]$PowerShellExe = (Get-Process -Id $PID).Path
)

$script:failed = @()

$testFiles = @(Get-ChildItem -Path $PSScriptRoot -Filter '*.tests.ps1' -File | Sort-Object Name)
if ($testFiles.Count -eq 0) {
    Write-Host "No test files found in $PSScriptRoot" -ForegroundColor Red
    exit 1
}

foreach ($file in $testFiles) {
    Write-Host ""
    Write-Host "=== $($file.Name)" -ForegroundColor Cyan
    & $PowerShellExe -NoProfile -File $file.FullName
    if ($LASTEXITCODE -ne 0) {
        $script:failed += $file.Name
        Write-Host "FAILED: $($file.Name)" -ForegroundColor Red
    }
}

Write-Host ""
if ($script:failed.Count -gt 0) {
    Write-Host "$($script:failed.Count) test file(s) failed: $($script:failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "All $($testFiles.Count) test file(s) passed." -ForegroundColor Green
exit 0
