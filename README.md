# Control Center Widget for Windows

A macOS-style Control Center desktop widget for Windows 10/11, built entirely in PowerShell with WinForms.

![Windows 10](https://img.shields.io/badge/Windows-10%2F11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-purple)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Volume Control** — System volume slider via Windows Core Audio COM API. Mute toggle.
- **Brightness Control** — Display brightness slider via WMI.
- **Opacity Control** — Widget transparency (20-100%).
- **Wi-Fi Monitor** — SSID, channel, signal, speed, band, security. Channel congestion heatmap (1-11): green = free, orange = moderate, red = congested.
- **Media Controls** — Play/pause, previous, next track via media key simulation.
- **Privacy Indicators** — Live microphone and camera status (green = active, red = off).
- **Speed Test** — Download/upload speed, ping, jitter. Non-blocking via background process polling.
- **Network Devices** — ARP-based device scanner with trust/untrust. Non-blocking via PowerShell Runspace.
- **Resizable** — Drag from any edge or corner including bottom edge.
- **Expand/Collapse** — Green dot collapses to slim title bar.
- **Dark Theme** — macOS-inspired dark UI with flat layout, no wrapper panels.

## Requirements

- Windows 10 or 11
- PowerShell 5.1 (pre-installed)
- [Ookla Speedtest CLI](https://www.speedtest.net/apps/cli) (optional, for speed test)

## Installation

### Run as Script

```powershell
powershell -ExecutionPolicy Bypass -File wifi-only.ps1
```

### Compile to EXE

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-PS2EXE -InputFile wifi-only.ps1 -OutputFile ControlCenter.exe -NoConsole -IconFile control-center.ico
```

### Speed Test Setup

```powershell
winget install Ookla.Speedtest.CLI
```

The widget looks for `speedtest.exe` in the default winget install path. Update `$speedtestExe` at the top of the script if installed elsewhere.

## Enable on Startup (Auto-launch on Boot)

To have the widget launch automatically when Windows starts:

### Method 1: Startup Folder (Recommended)

1. Press `Win + R`, type `shell:startup`, press Enter
2. Right-click inside the folder → **New** → **Shortcut**
3. Browse to your `ControlCenter.exe` (or `wifi-only.ps1`)
4. Name it **Control Center**, click Finish

### Method 2: Task Scheduler (More Control)

1. Open **Task Scheduler** (`taskschd.msc`)
2. Click **Create Basic Task**
3. Name: `Control Center Widget`, trigger: **When I log on**
4. Action: **Start a program**, browse to `ControlCenter.exe`
5. Check **Open the Properties dialog** → set **Run only when user is logged on**
6. Optional: add a 5-second delay in Triggers → Edit → **Delay task for 5 seconds**

### Method 3: Registry

```powershell
$exePath = "C:\path\to\ControlCenter.exe"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ControlCenter" -Value $exePath
```

To remove: `Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ControlCenter"`

## Trusted Devices

On first run, the widget creates `trusted-devices.json` in the script directory. Right-click any device in the Devices list to trust/untrust. See `trusted-devices.example.json` for the format.

## Customization

| Setting | Location | Notes |
|---------|----------|-------|
| Subnet | `$subnet` variable | Default `192.168.0` |
| Colors | Palette section | `$bg`, `$card`, `$txt`, `$blue`, etc. |
| Refresh interval | `$tmr.Interval` | Milliseconds (default 5000) |
| Default opacity | Opacity slider init | Range 20-100 |
| Window width | `$W` variable | Default 340px |
| Speedtest path | `$speedtestExe` | Auto-detected from winget |

## Architecture

Single-file PowerShell script with inline C# types. See [WIDGET-ANATOMY.md](WIDGET-ANATOMY.md) for full architectural breakdown.

Key design decisions:
- **C# SliderControl** — custom `Control` subclass avoids PowerShell 5.1 `.GetNewClosure()` scope isolation bug
- **Non-blocking I/O** — Timer-polled background processes (speed test) and Runspaces (device scan)
- **DarkForm WndProc** — edge hit-test before `base.WndProc` bypasses rounded region clipping

## License

MIT License. Use it, modify it, ship it.
