#Requires -Version 5.1
<#
    ProtectMiner - antiminer-browser.ps1
    Force-installs the NoMiner browser extension through enterprise policy
    on Google Chrome, Microsoft Edge and Mozilla Firefox.

    Requires an elevated (Administrator) PowerShell session.
    Browsers must be fully closed and reopened for the extension to appear.
#>
[CmdletBinding()]
param()

# --- INITIAL CONFIGURATION ---
# Chrome/Edge NoMiner extension ID (Chrome Web Store)
$extensionId = "jfnangjojcioomickmmnfmiadkfhcdmd"
$chromeUpdateUrl = "https://clients2.google.com/service/update2/crx"

# Firefox add-on install URL (addons.mozilla.org serves the current .xpi)
$firefoxAddonUrl = "https://addons.mozilla.org/firefox/downloads/latest/nominer-block-coin-miners/latest.xpi"

# Enterprise policy registry roots
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
$edgePolicyPath   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
$firefoxPolicyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"

$logDirectory = "$env:ProgramData\ProtectMiner"
$logPath      = "$logDirectory\antiminer-browser.log"

# --- HELPERS ---
function Write-ProtectionLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-ExtensionPolicy {
    <#
        Adds a policy value to the first free registry index and never
        overwrites entries that are already configured.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $current = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $current) { $current = New-Object PSObject }

    $duplicated = $current.PSObject.Properties |
        Where-Object { $_.Name -notlike "PS*" -and $_.Value -eq $Value }
    if ($duplicated) {
        Write-ProtectionLog "$Name already configured (value stored in '$($duplicated.Name)')."
        return
    }

    $index = 1
    while ($current.PSObject.Properties | Where-Object { $_.Name -eq "$index" }) {
        $index++
    }

    New-ItemProperty -Path $Path -Name $index -Value $Value -PropertyType String -Force | Out-Null
    Write-ProtectionLog "$Name configured at registry index $index."
}

# --- STARTUP ---
if (!(Test-IsAdministrator)) {
    Write-Host "ProtectMiner must run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and choose 'Run as administrator', then run this script again."
    exit 1
}

if (!(Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

Write-ProtectionLog "Configuring NoMiner force-install policies..."

# 1. GOOGLE CHROME
Set-ExtensionPolicy -Path $chromePolicyPath -Name "Google Chrome" -Value "$extensionId;$chromeUpdateUrl"

# 2. MICROSOFT EDGE
Set-ExtensionPolicy -Path $edgePolicyPath -Name "Microsoft Edge" -Value "$extensionId;$chromeUpdateUrl"

# 3. MOZILLA FIREFOX (policy: Extensions > Install, requires a full .xpi URL)
Set-ExtensionPolicy -Path $firefoxPolicyPath -Name "Mozilla Firefox" -Value $firefoxAddonUrl

Write-ProtectionLog "NoMiner policies configured successfully."
Write-Host ""
Write-Host "Next step: close every browser window and reopen them." -ForegroundColor Yellow
Write-Host "To force a restart:" -ForegroundColor Yellow
Write-Host '  Stop-Process -Name "chrome", "msedge", "firefox" -Force'
