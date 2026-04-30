# --- CONFIGURAÇÃO INICIAL ---
$minerTargets = @("xmrig", "minerd", "cpuminer", "ethminer", "nicehash", "kms-pico", "cryptobot")
$minerDomains = @("coin-hive.com", "monerohash.com", "nanopool.org", "minexmr.com", "://supportxmr.com")
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
$intervaloSegundos = 300 # Verifica a cada 5 minutos

Write-Host "Monitoramento Anti-Minerador Full
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠶⠀⠀⠀⠀⠀⣈⣿⣦⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠋⠀⠀⠀⠀⠀⠹⣿⣿⡆⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣤⣤⣴⣤⣤⣄⠀⢠⣿⣿⠇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢸⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣾⠋⠈⢻⣿⡝⠁⠀⢻⣿⣿⠋⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⣿⣄⣠⣿⣿⣧⣀⣠⣿⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⡿⠟⠀⣀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣷⡾⠿⠛⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⡿⠓⠀⠀⠀⠀⠀⠀⠀
⠀⠀⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⡀⠀⠀⠀⠀⠀
⠀⣰⡟⠉⣼⣿⠟⣡⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⡀⠀
⢠⣿⠀⠀⣿⣿⣾⠿⠛⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡛⠻⠑⡀
⠈⣿⠀⡼⢿⡏⠀⠀⠀⠹⣿⡆⠉⠻⣿⣿⣿⣿⣿⡻⢿⣿⠷⠞⠁
⠀⢸⠇⠀⠈⡇⠀⠀⠀⠀⠘⢿⡄⠀⠸⡏⠀⠀⠉⡇⠀⠹⢦⡄⠀
⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠸⠁⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀

Iniciado..."

while ($true) {
    try {
        # 1. Bloqueio de Rede via arquivo HOSTS
        foreach ($domain in $minerDomains) {
            if (!(Select-String -Path $hostsPath -Pattern $domain -Quiet)) {
                Add-Content -Path $hostsPath -Value "0.0.0.0 $domain" -ErrorAction SilentlyContinue
            }
        }

        # 2. Encerrar Processos Suspeitos em execução
        foreach ($proc in $minerTargets) {
            Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
        }

        # 3. VARREDURA EM %APPDATA% (Local e Roaming)
        # Procura por arquivos .exe com nomes de mineradores conhecidos nas pastas AppData
        $appDataPaths = @($env:APPDATA, $env:LOCALAPPDATA)
        foreach ($path in $appDataPaths) {
            foreach ($target in $minerTargets) {
                # Procura arquivos que contenham o nome do minerador
                $foundFiles = Get-ChildItem -Path $path -Filter "*$target*.exe" -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $foundFiles) {
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    Write-Host "Arquivo malicioso removido em AppData: $($file.FullName)"
                }
            }
        }

        # 4. Verificar Uso de CPU Elevado (> 85%)
        $cpuLoad = (Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($cpuLoad -gt 85) {
            # Limpa Temp se a CPU estiver gritando
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 5. Remover Tarefas Agendadas Suspeitas
        Get-ScheduledTask | Where-Object { $_.TaskName -match "Update" -and $_.Actions -match "AppData" } | 
            Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    } catch {
        Write-Host "Erro: $_"
    }

    Start-Sleep -Seconds $intervaloSegundos
}

