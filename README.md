# ProtectMiner

A lightweight PowerShell toolkit to detect, block, and remove cryptocurrency miners from Windows systems.

## Overview

ProtectMiner provides two scripts that work together to protect your machine from unwanted crypto-mining activity — both at the system level and in your browser.

## Scripts

### `antiminer.ps1` — System Protection

Runs as a continuous background monitor and performs the following checks every 5 minutes:

| Step | Action |
|------|--------|
| 1 | Blocks known mining domains by adding entries to the Windows `hosts` file |
| 2 | Terminates suspicious processes (xmrig, minerd, cpuminer, ethminer, nicehash, kms-pico, cryptobot) |
| 3 | Scans `%APPDATA%` and `%LOCALAPPDATA%` for malicious `.exe` files and deletes them |
| 4 | Monitors CPU usage — if above 85%, clears the Temp folder to remove portable miners |
| 5 | Removes scheduled tasks that point to suspicious `AppData` locations |

### `nocoinnavegador.ps1` — Browser Extension Deployment

Force-installs the [NoMiner](https://chrome.google.com/webstore/detail/nominer/jfnangjojcioomickmmnfmiadkfhcdmd) browser extension on:

- **Google Chrome** — via Group Policy registry key
- **Microsoft Edge** — via Group Policy registry key
- **Mozilla Firefox** — via policy registry key

## Requirements

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges** (required to modify the `hosts` file, kill system processes, and write to `HKLM` registry)

## Usage

### Running manually

```powershell
# Run the system protection script as Administrator
.\antiminer.ps1

# Deploy browser extensions (one-time, run as Administrator)
.\nocoinnavegador.ps1
```

### Running via Power Automate Desktop (PAD)

1. In PAD, add the **"Run PowerShell Script"** action.
2. Paste the full script code.
3. In the action's **Advanced** properties, increase or disable the timeout (since `antiminer.ps1` runs in an infinite loop).
4. Launch PAD **as Administrator** — otherwise Windows will block host file edits and registry writes.

> **Note:** Browser extensions only take effect after all browser windows are closed and reopened. You can force this by running:
> ```powershell
> Stop-Process -Name "chrome", "msedge", "firefox" -Force
> ```

## License

MIT
