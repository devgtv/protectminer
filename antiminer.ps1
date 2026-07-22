# --- INITIAL CONFIGURATION ---
$minerTargets = @("xmrig", "minerd", "cpuminer", "ethminer", "nicehash", "kms-pico", "cryptobot")
$minerDomains = @("coin-hive.com", "monerohash.com", "nanopool.org", "minexmr.com", "://supportxmr.com")
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$intervalSeconds = 300 # Check every 5 minutes

Write-Host "Anti-Miner Protection Monitor
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠶⠀⠀⠀⠀⠀⣈⣿⣦⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠋⠀⠀⠀⠀⠀⠹⣿⣿⡆⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣤⣤⣴⣤⣤⣄⠀⢠⣿⣿⠇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢸⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣾⠋⠈⢻⣿⡝⠀⠀⢻⣿⣿⠋⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⣿⣄⣠⣿⣿⣧⣀⣠⣿⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⡿⠟⠀⣀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣷⡾⠿⠛⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⣠⣴⣿⣿⣿⣿⣿⣿⣿⡿⠓⠀⠀⠀⠀⠀⠀⠀
⠀⠀⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⡀⠀⠀⠀⠀⠀
⠀⣰⡟⠉⣼⣿⠟⣡⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⡀⠀
⢠⣿⠀⠀⣿⣿⣾⠿⠛⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⡛⠻⠑⡀
⠈⣿⠀⡼⢿⡏⠀⠀⠀⠹⣿⡆⠉⠻⣿⣿⣿⣿⣿⡻⢿⣿⠷⠞⠁
⠀⢸⠇⠀⠈⡇⠀⠀⠀⠀⠘⢿⡄⠀⠸⡏⠀⠀⠉⡇⠀⠹⢦⡄⠀
⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠸⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀

Started..."

while ($true) {
    try {
        # 1. Block mining domains via HOSTS file
        foreach ($domain in $minerDomains) {
            if (!(Select-String -Path $hostsPath -Pattern $domain -Quiet)) {
                Add-Content -Path $hostsPath -Value "0.0.0.0 $domain" -ErrorAction SilentlyContinue
            }
        }

        # 2. Kill suspicious running processes
        foreach ($proc in $minerTargets) {
            Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
        }

        # 3. SCAN %APPDATA% (Local and Roaming)
        # Search for .exe files with known miner names in AppData folders
        $appDataPaths = @($env:APPDATA, $env:LOCALAPPDATA)
        foreach ($path in $appDataPaths) {
            foreach ($target in $minerTargets) {
                $foundFiles = Get-ChildItem -Path $path -Filter "*$target*.exe" -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $foundFiles) {
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "Malicious file removed from AppData: $($file.FullName)"
                }
            }
        }

        # 4. Check for high CPU usage (> 85%)
        $cpuLoad = (Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($cpuLoad -gt 85) {
            # Clear Temp folder if CPU is spiking
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 5. Remove suspicious scheduled tasks
        Get-ScheduledTask | Where-Object { $_.TaskName -match "Update" -and $_.Actions -match "AppData" } | 
            Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    } catch {
        Write-Host "Error: $_"
    }

    Start-Sleep -Seconds $intervalSeconds
}
