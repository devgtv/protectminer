# ProtectMiner

[![CI](https://github.com/devgtv/protectminer/actions/workflows/lint.yml/badge.svg)](https://github.com/devgtv/protectminer/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A lightweight PowerShell toolkit to detect, block and remove cryptocurrency miners from Windows systems — at the system level and in the browser.

## Overview

| Script | Purpose |
|--------|---------|
| [`antiminer.ps1`](antiminer.ps1) | Continuous background monitor: blocks mining domains, kills miner processes, deletes miner files, reacts to CPU spikes and removes suspicious scheduled tasks |
| [`antiminer-browser.ps1`](antiminer-browser.ps1) | Force-installs the [NoMiner](https://chromewebstore.google.com/detail/nominer-block-coin-miners/jfnangjojcioomickmmnfmiadkfhcdmd) extension on Chrome, Edge and Firefox through enterprise policy |
| [`remove-protections.ps1`](remove-protections.ps1) | Reverts everything the toolkit changed: hosts entries and browser policies |

All three scripts are self-contained — each one can be copied and pasted on its own, which is what the Power Automate Desktop workflow below expects.

## What `antiminer.ps1` does

Runs a protection cycle every 5 minutes (configurable with `-IntervalSeconds`):

| Step | Action | Cadence |
|------|--------|---------|
| 1 | Blocks known mining domains in the Windows `hosts` file, tagged with a `# ProtectMiner` marker and de-duplicated | Every cycle |
| 2 | Terminates suspicious processes (`xmrig`, `minerd`, `cpuminer`, `ethminer`, `nicehash`, `kms-pico`, `cryptobot`) | Every cycle |
| 3 | Scans `%APPDATA%` and `%LOCALAPPDATA%` for malicious `.exe` files and deletes them | Every 6th cycle (30 min) |
| 4 | Monitors CPU usage — after **3 consecutive cycles** above 85%, clears the Temp folder to remove portable miners | Every cycle |
| 5 | Removes scheduled tasks that run from a suspicious `AppData` location | Every cycle |

The script refuses to start without Administrator rights and logs everything to `%ProgramData%\ProtectMiner\antiminer.log`.

```powershell
.\antiminer.ps1                  # run the monitor (infinite loop)
.\antiminer.ps1 -Once            # run a single protection cycle and exit
.\antiminer.ps1 -IntervalSeconds 60
```

## What `antiminer-browser.ps1` does

Force-installs NoMiner through the enterprise policy registry keys:

| Browser | Policy |
|---------|--------|
| Google Chrome | `HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist` |
| Microsoft Edge | `HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist` |
| Mozilla Firefox | `HKLM\SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install` (real `.xpi` URL from addons.mozilla.org) |

The script is idempotent: it picks the first free registry index, never overwrites an existing policy entry and skips values that are already configured. Requires Administrator rights; logs to `%ProgramData%\ProtectMiner\antiminer-browser.log`.

## What `remove-protections.ps1` does

Undoes the toolkit's changes:

- removes hosts entries tagged `# ProtectMiner` **and** plain entries written by older versions of `antiminer.ps1`
- removes the Chrome / Edge / Firefox NoMiner policies and deletes a policy key only after it is empty, so unrelated policies are never touched

```powershell
.\remove-protections.ps1 -WhatIf      # preview every change without applying it
.\remove-protections.ps1              # revert hosts entries and browser policies
.\remove-protections.ps1 -PurgeLogs   # also delete %ProgramData%\ProtectMiner
```

## Requirements

- **Windows 10/11**
- **PowerShell 5.1+** (also runs on PowerShell 7+)
- **Administrator privileges** — required to modify the `hosts` file, terminate processes and write to `HKLM`

## Usage

### Running manually

```powershell
# Run the system protection monitor as Administrator
.\antiminer.ps1

# Deploy the browser extension (one-time, run as Administrator)
.\antiminer-browser.ps1

# Undo everything (preview first)
.\remove-protections.ps1 -WhatIf
```

### Running via Power Automate Desktop (PAD)

1. In PAD, add the **"Run PowerShell Script"** action.
2. Paste the full script code.
3. In the action's **Advanced** properties, increase or disable the timeout (since `antiminer.ps1` runs in an infinite loop — or use `-Once`).
4. Launch PAD **as Administrator** — otherwise Windows blocks hosts file edits and registry writes.

> **Note:** browser extensions only take effect after every browser window has been closed and reopened. You can force this with:
> ```powershell
> Stop-Process -Name "chrome", "msedge", "firefox" -Force
> ```

## Logs

All activity is appended to timestamped log files under `%ProgramData%\ProtectMiner\`:

| File | Script |
|------|--------|
| `antiminer.log` | `antiminer.ps1` |
| `antiminer-browser.log` | `antiminer-browser.ps1` |
| `remove-protections.log` | `remove-protections.ps1` |

## Development

```powershell
# Run the whole test suite (works on any OS with pwsh)
pwsh -NoProfile -File tests/run-tests.ps1

# Lint the toolkit scripts locally
Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1
```

Every pull request runs **PSScriptAnalyzer** (fails on errors) and the **unit tests** through GitHub Actions. The tests load the script functions through the AST and mock the Windows-only commands, so they run on Linux, macOS and Windows.

## License

[MIT](LICENSE)
