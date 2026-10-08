#Requires -Version 5.1
<#
    ProtectMiner - remove-protections.ps1
    Reverts every change made by the toolkit:
      - deletes the hosts entries added by antiminer.ps1
      - deletes the force-install browser policies added by antiminer-browser.ps1
      - optionally purges the ProtectMiner log directory

    Requires an elevated (Administrator) PowerShell session.
    Use -WhatIf to preview the changes without applying them.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Also delete %ProgramData%\ProtectMiner (all logs)
    [switch]$PurgeLogs
)

# --- INITIAL CONFIGURATION ---
$hostsPath      = "$env:windir\System32\drivers\etc\hosts"
$hostsMarker    = "# ProtectMiner"
$extensionId    = "jfnangjojcioomickmmnfmiadkfhcdmd"
$firefoxAddonUrl = "https://addons.mozilla.org/firefox/downloads/latest/nominer-block-coin-miners/latest.xpi"

# Domains written by older versions of antiminer.ps1 (before the marker existed)
$minerDomains = @("coin-hive.com", "coinhive.com", "monerohash.com", "nanopool.org", "minexmr.com", "supportxmr.com", "://supportxmr.com")

$policyPaths = @(
    @{ Name = "Google Chrome"; Path = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" },
    @{ Name = "Microsoft Edge"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" },
    @{ Name = "Mozilla Firefox"; Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install" }
)

$logDirectory = "$env:ProgramData\ProtectMiner"
$logPath      = "$logDirectory\remove-protections.log"

# --- HELPERS ---
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    if (!(Test-Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (Test-Path $logDirectory) {
        Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    Write-Host $line
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- REMOVAL STEPS ---
function Remove-HostsEntries {
    if (!(Test-Path $hostsPath)) {
        Write-Log "Hosts file not found, nothing to revert."
        return 0
    }

    $lines = @(Get-Content -Path $hostsPath -ErrorAction SilentlyContinue)
    $domainPattern = "^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+(" +
        (($minerDomains | ForEach-Object { [regex]::Escape($_) }) -join "|") +
        ")(\s|$)"

    $kept = @($lines | Where-Object {
        ($_ -notmatch [regex]::Escape($hostsMarker)) -and ($_ -notmatch $domainPattern)
    })

    $removedCount = $lines.Count - $kept.Count
    if ($removedCount -eq 0) {
        Write-Log "No ProtectMiner hosts entries found."
        return 0
    }

    if ($kept.Count -eq 0) {
        $kept = @("127.0.0.1 localhost")
    }

    if ($PSCmdlet.ShouldProcess($hostsPath, "Remove $removedCount ProtectMiner hosts entrie(s)")) {
        Set-Content -Path $hostsPath -Value @($kept) -Encoding ASCII -ErrorAction Stop
        Write-Log "Removed $removedCount hosts entrie(s)."
    }

    return $removedCount
}

function Remove-ExtensionPolicies {
    foreach ($policy in $policyPaths) {
        if (!(Test-Path $policy.Path)) {
            Write-Log "$($policy.Name): no policy key present."
            continue
        }

        $current = Get-ItemProperty -Path $policy.Path -ErrorAction SilentlyContinue
        $values = @($current.PSObject.Properties | Where-Object {
            $_.Name -notlike "PS*" -and (
                $_.Value -like "*$extensionId*" -or $_.Value -eq $firefoxAddonUrl
            )
        })

        if ($values.Count -eq 0) {
            Write-Log "$($policy.Name): no ProtectMiner policy found."
            continue
        }

        foreach ($value in $values) {
            if ($PSCmdlet.ShouldProcess($policy.Path, "Remove value '$($value.Name)'")) {
                Remove-ItemProperty -Path $policy.Path -Name $value.Name -Force -ErrorAction Stop
                Write-Log "$($policy.Name): removed policy value '$($value.Name)'."
            }
        }

        # Delete the key only when this toolkit was the only thing using it.
        $remaining = @(Get-ItemProperty -Path $policy.Path -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notlike "PS*" }
        if (@($remaining).Count -eq 0 -and $PSCmdlet.ShouldProcess($policy.Path, "Remove empty policy key")) {
            Remove-Item -Path $policy.Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "$($policy.Name): removed empty policy key."
        }
    }
}

# --- STARTUP ---
if (!(Test-IsAdministrator)) {
    Write-Host "ProtectMiner must run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and choose 'Run as administrator', then run this script again."
    exit 1
}

Write-Log "Reverting ProtectMiner changes..."

$null = Remove-HostsEntries
Remove-ExtensionPolicies

if ($PurgeLogs) {
    if ($PSCmdlet.ShouldProcess($logDirectory, "Delete ProtectMiner log directory")) {
        Remove-Item -Path $logDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Log directory deleted: $logDirectory"
    }
} else {
    Write-Log "Protection removed. Logs kept at $logDirectory (use -PurgeLogs to delete them)."
}
