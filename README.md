# Control Center Widget for Windows

A macOS-style Control Center desktop widget for Windows 10/11, built entirely in PowerShell with WinForms.

![Windows 10](https://img.shields.io/badge/Windows-10%2F11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-purple)
![License](https://img.shields.io/badge/License-MIT-green)

![Control Center Widget](Wifi%20controller.png)

## Features

- **Wi-Fi Monitor** - SSID, channel, signal strength, speed, band, and security. Visual channel congestion map (channels 1-11) with color coding: green (free), orange (moderate), red (congested).
- **Volume Control** - System volume slider synced via Windows Core Audio API. Includes mute toggle.
- **Brightness Control** - Display brightness slider via WMI.
- **Opacity Control** - Adjust widget transparency (20-100%).
- **Media Controls** - Play/pause, previous, next track buttons with rounded pill-shaped buttons.
- **Privacy Indicators** - Live microphone and camera status (green = active, red = off) via Windows registry.
- **Speed Test** - Two-column dashboard layout with large download/upload numbers, colored arrow indicators, and ping/jitter stats. Powered by Ookla Speedtest CLI.
- **Network Devices** - Scans local network for connected devices with colored dot status indicators. Trust/untrust devices with right-click. Scan button for quick network discovery.
- **Resizable** - Drag from any edge or corner to resize. Drag the title bar to move.
- **Expand/Collapse** - Green traffic-light button collapses the widget to a slim title bar.
- **Rounded Cards** - Each section has rounded corner panels with polished dark theme styling.

## Requirements

- Windows 10 or 11
- PowerShell 5.1 (pre-installed on Windows 10+)
- [Ookla Speedtest CLI](https://www.speedtest.net/apps/cli) (optional, for speed test feature)

## Installation

### Run as Script

```powershell
powershell -ExecutionPolicy Bypass -File wifi-monitor.ps1
```

### Compile to EXE

Install [PS2EXE](https://github.com/MScholtes/PS2EXE) and compile:

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-PS2EXE -InputFile wifi-monitor.ps1 -OutputFile ControlCenter.exe -NoConsole -Title 'Control Center'
```

Then double-click `ControlCenter.exe` to run.

### Speed Test Setup

Install via winget:

```powershell
winget install Ookla.Speedtest.CLI
```

The widget looks for speedtest.exe in the default winget install path. If installed elsewhere, update the `$speedtestExe` path at the top of the script.

## Trusted Devices

On first run, the widget creates `trusted-devices.json` in the same directory as the script/exe. Right-click any device in the Devices list to trust or untrust it. See `trusted-devices.example.json` for the format.

## Customization

| What | Where | How |
|------|-------|-----|
| Subnet | Line 102 | Change `192.168.0` to your subnet |
| Colors | Lines 138-148 | Modify the palette `$bg`, `$card`, `$txt`, etc. |
| Refresh interval | Timer section | Change `$tmr.Interval` (milliseconds) |
| Default opacity | Opacity slider | Change `$sOpa.Value` |
| Window size | Form section | Change `$W` (width) |
| Speedtest path | Line 8 | Update `$speedtestExe` |

## Architecture

Single-file PowerShell script with inline C# for:

- **DarkForm** - Borderless WinForms form with WndProc override for resize from all edges and corners
- **WinAPI** - P/Invoke for media key simulation and rounded window regions
- **AudioManager** - Windows Core Audio COM API for volume read/write/mute

No external dependencies beyond PowerShell 5.1 and .NET Framework 4.x (both pre-installed on Windows 10).

## License

MIT License. Use it, modify it, ship it.
