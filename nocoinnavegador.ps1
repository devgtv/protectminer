# --- BROWSER EXTENSION CONFIGURATION (Official IDs) ---
# Chrome/Edge NoMiner Extension ID: jfnangjojcioomickmmnfmiadkfhcdmd
$extensionID_Chromium = "jfnangjojcioomickmmnfmiadkfhcdmd"
$updateURL = "https://clients2.google.com/service/update2/crx"

# 1. GOOGLE CHROME
$pathChrome = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
if (!(Test-Path $pathChrome)) { New-Item -Path $pathChrome -Force }
Set-ItemProperty -Path $pathChrome -Name "1" -Value "$extensionID_Chromium;$updateURL"

# 2. MICROSOFT EDGE
$pathEdge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
if (!(Test-Path $pathEdge)) { New-Item -Path $pathEdge -Force }
Set-ItemProperty -Path $pathEdge -Name "1" -Value "$extensionID_Chromium;$updateURL"

# 3. MOZILLA FIREFOX
# Firefox uses a different file system or registry structure for policies
$pathFirefox = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
if (!(Test-Path $pathFirefox)) { New-Item -Path $pathFirefox -Force }
# Direct link to the NoMiner .xpi for Firefox
$firefoxAddonUrl = "https://mozilla.org"
Set-ItemProperty -Path $pathFirefox -Name "1" -Value "$firefoxAddonUrl"

Write-Host "Anti-mining extensions configured successfully!"
