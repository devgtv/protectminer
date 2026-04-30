# --- CONFIGURAÇÃO DAS EXTENSÕES (IDs Oficiais) ---
# Chrome/Edge ID para NoMiner: jfnangjojcioomickmmnfmiadkfhcdmd
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
# O Firefox usa um sistema de arquivos ou registro diferente para políticas
$pathFirefox = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
if (!(Test-Path $pathFirefox)) { New-Item -Path $pathFirefox -Force }
# Link direto para o .xpi do NoMiner no Firefox
$firefoxAddonUrl = "https://mozilla.org"
Set-ItemProperty -Path $pathFirefox -Name "1" -Value "$firefoxAddonUrl"

Write-Host "Extensões anti-mineração configuradas com sucesso!"

