#Requires -Version 5.1
<#
    ProtectMiner - antiminer.ps1
    Continuous background monitor that detects, blocks and removes
    cryptocurrency miners from a Windows system.

    Requires an elevated (Administrator) PowerShell session.
#>
[CmdletBinding()]
param(
    # Seconds between protection cycles
    [int]$IntervalSeconds = 300,
    # Run a single protection cycle and exit (useful for scheduled tasks)
    [switch]$Once
)

# --- INITIAL CONFIGURATION ---
$minerTargets  = @("xmrig", "minerd", "cpuminer", "ethminer", "nicehash", "kms-pico", "cryptobot")
$minerDomains  = @("coin-hive.com", "coinhive.com", "monerohash.com", "nanopool.org", "minexmr.com", "supportxmr.com")
$hostsPath     = "$env:windir\System32\drivers\etc\hosts"
$hostsMarker   = "# ProtectMiner"
$logDirectory  = "$env:ProgramData\ProtectMiner"
$logPath       = "$logDirectory\antiminer.log"
$cpuThreshold  = 85   # Percent
$cpuCyclesNeeded = 3  # Consecutive high-CPU cycles before Temp is cleaned
$scanEveryCycles = 6  # Run the AppData scan every N cycles

# --- LOGGING ---
function Initialize-LogDirectory {
    if (!(Test-Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
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

# --- PROTECTION STEPS ---
function Block-MiningDomains {
    # Blocks known mining domains by adding entries to the Windows hosts file.
    if (!(Test-Path $hostsPath)) { return }

    $hostsLines = @(Get-Content -Path $hostsPath -ErrorAction SilentlyContinue)
    $added = 0

    foreach ($domain in $minerDomains) {
        $pattern = "^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+$([regex]::Escape($domain))(\s|$)"
        if ($hostsLines | Where-Object { $_ -match $pattern }) { continue }

        Add-Content -Path $hostsPath -Value "0.0.0.0 $domain $hostsMarker" -ErrorAction Stop
        $hostsLines += "0.0.0.0 $domain $hostsMarker"
        $added++
    }

    if ($added -gt 0) { Write-Log "Blocked $added mining domain(s) in the hosts file." }
}

function Stop-MinerProcesses {
    # Terminates suspicious running processes.
    foreach ($name in $minerTargets) {
        $processes = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        foreach ($process in $processes) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
                Write-Log "Terminated suspicious process: $($process.ProcessName) (PID $($process.Id))" "WARN"
            } catch {
                Write-Log "Could not terminate $($process.ProcessName) (PID $($process.Id)): $_" "ERROR"
            }
        }
    }
}

function Remove-MinerFiles {
    # Searches %APPDATA% and %LOCALAPPDATA% for malicious .exe files and deletes them.
    $appDataPaths = @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path $_) }
    $removed = 0

    foreach ($path in $appDataPaths) {
        foreach ($target in $minerTargets) {
            $foundFiles = @(Get-ChildItem -Path $path -Filter "*$target*.exe" -Recurse -ErrorAction SilentlyContinue)
            foreach ($file in $foundFiles) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $removed++
                    Write-Log "Removed malicious file: $($file.FullName)" "WARN"
                } catch {
                    Write-Log "Could not remove $($file.FullName): $_" "ERROR"
                }
            }
        }
    }

    return $removed
}

function Get-CpuLoad {
    # Get-WmiObject was removed in PowerShell 7; CIM works on 5.1 and 7+.
    $load = (Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue |
             Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $load) { return 0 }
    return [int]$load
}

function Clear-TempFolder {
    # Clears the Temp folder to remove portable miners.
    $removed = 0
    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | ForEach-Object {
        # Never delete this script or the ProtectMiner log directory.
        if ($_.FullName -eq $PSCommandPath) { return }
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            $removed++
        } catch { }
    }
    Write-Log "CPU above $cpuThreshold% for $cpuCyclesNeeded consecutive cycles - Temp cleaned ($removed item(s))." "WARN"
}

function Remove-SuspiciousScheduledTasks {
    # Removes scheduled tasks that point to suspicious AppData locations.
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $task = $_
        $task.TaskName -match "Update" -and @($task.Actions | Where-Object {
            ($_.Execute -and $_.Execute -like "*\AppData\*") -or ($_.Arguments -and $_.Arguments -like "*\AppData\*")
        }).Count -gt 0
    })

    foreach ($task in $tasks) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
            Write-Log "Removed suspicious scheduled task: $($task.TaskName)" "WARN"
        } catch {
            Write-Log "Could not remove scheduled task $($task.TaskName): $_" "ERROR"
        }
    }
}

# --- STARTUP ---
if (!(Test-IsAdministrator)) {
    Write-Host "ProtectMiner must run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and choose 'Run as administrator', then run this script again."
    exit 1
}

Initialize-LogDirectory

Write-Host "Anti-Miner Protection Monitor
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⠶⠀⠀⠀⠀⠀⣈⣿⣦⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠋⠀⠀⠀⠀⠀⠹⣿⣿⡆⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣤⣤⣴⣤⣤⣄⠀⢠⣿⣿⠇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢸⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣾⠋⠈⢻⣿⡝⠀⠀⢻⣿⣿⠋⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⣿⣄⣠⣿⣿⣧⣀⣠⣿⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⡿⠟⠀⣀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣷⡾⠿⠛⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢀⣠⣴⣿⣿⣿⣿⣿⣿⣿⡿⠓⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣀⡀⠀⠀⠀⠀⠀
⠀⠀⣰⡟⠉⣼⣿⠟⣡⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣤⡀⠀
⢠⣿⠀⠀⣿⣿⣾⠿⠛⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⡛⠻⠑⡀
⠈⣿⠀⡼⢿⡏⠀⠀⠀⠹⣿⡆⠉⠻⣿⣿⣿⣿⣿⡻⢿⣿⠷⠞⠁
⠀⠀⢸⠇⠀⠈⡇⠀⠀⠀⠀⠘⢿⡄⠀⠸⡏⠀⠀⠉⡇⠀⠹⢦⡄⠀
⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠸⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀

Log file: $logPath"

Write-Log "Monitor started (interval: $intervalSeconds s)."

$cycle = 0
$highCpuCycles = 0

do {
    try {
        $cycle++

        Block-MiningDomains
        Stop-MinerProcesses

        if ($cycle -eq 1 -or ($cycle % $scanEveryCycles) -eq 0) {
            $null = Remove-MinerFiles
        }

        $cpuLoad = Get-CpuLoad
        if ($cpuLoad -gt $cpuThreshold) {
            $highCpuCycles++
            Write-Log "CPU load at $cpuLoad% ($highCpuCycles/$cpuCyclesNeeded)." "WARN"
            if ($highCpuCycles -ge $cpuCyclesNeeded) {
                Clear-TempFolder
                $highCpuCycles = 0
            }
        } else {
            $highCpuCycles = 0
        }

        Remove-SuspiciousScheduledTasks

        Write-Log "Cycle $cycle completed."
    } catch {
        Write-Log "Error: $_" "ERROR"
    }

    if ($Once) { break }
    Start-Sleep -Seconds $IntervalSeconds
} while ($true)
