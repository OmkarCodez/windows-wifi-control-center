# Widget Anatomy

Architectural breakdown of the Control Center widget (`wifi-only.ps1`).

## Layer Stack

```
┌──────────────────────────────────────┐
│  C# Add-Type (compiled at runtime)   │
│  ├─ WinAPI        P/Invoke calls     │
│  ├─ DarkForm      Borderless resize  │
│  ├─ SliderControl Custom slider      │
│  ├─ AudioManager  Core Audio COM     │
│  └─ IAudioEndpointVolume COM ifaces  │
├──────────────────────────────────────┤
│  PowerShell WinForms GUI             │
│  ├─ Title bar (drag, close/min/exp)  │
│  ├─ Controls section (sliders)       │
│  ├─ Wi-Fi section (netsh parsing)    │
│  ├─ Media + Privacy indicators       │
│  ├─ Speed Test (Ookla CLI, async)    │
│  └─ Devices (ARP + Runspace, async)  │
├──────────────────────────────────────┤
│  .NET Framework 4.x + WinForms       │
│  PowerShell 5.1 runtime              │
│  Windows 10/11                        │
└──────────────────────────────────────┘
```

## C# Types (Add-Type)

### WinAPI
- `keybd_event` — media key simulation (play/pause, prev, next)
- `CreateRoundRectRgn` — rounded window corners
- `SetWindowRgn` — applies region to form and buttons

### DarkForm : Form
Borderless form with `WndProc` override for `WM_NCHITTEST` (0x84). Returns hit-test codes for all 8 resize directions (10-17) with a 10px grab zone. Edge detection runs before `base.WndProc` to bypass rounded region clipping at bottom corners.

### SliderControl : Control
Custom owner-drawn slider replacing WinForms TrackBar. Avoids PowerShell 5.1 `.GetNewClosure()` scope isolation bug by handling all logic in C#.

- **OnPaint** — draws grey track (4px), blue fill, white thumb circle (12px)
- **OnMouseDown/Move/Up** — drag with `Capture = true`, percentage-to-value math
- **SetValueFromSystem(int)** — external sync that skips update when user is dragging
- **ValueChanged event** — fires on user interaction only

### AudioManager
Windows Core Audio COM API. Enumerates default audio endpoint, gets/sets master volume scalar (0-100), toggles mute. Uses correct vtable ordering for `IAudioEndpointVolume`.

## Sections

### Title Bar (Y: 0-18)
- 10px traffic-light dots (close=red, minimize=orange, expand/collapse=green)
- Centered "Control Center" label
- Drag-to-move on dots and label
- Collapse toggles between full height and 20px slim bar

### Controls — Sliders (Y: 18-72)
| Slider | Range | Backend |
|--------|-------|---------|
| Volume | 0-100 | `AudioManager.SetVolume()` via Core Audio COM |
| Brightness | 0-100 | WMI `WmiMonitorBrightnessMethods.WmiSetBrightness` |
| Opacity | 20-100 | `$form.Opacity` (WinForms property) |

Timer syncs volume/brightness every 5s via `SetValueFromSystem()`, skipped during drag.

### Wi-Fi (Y: ~77-200)
- Parses `netsh wlan show interfaces` for SSID, channel, signal, speed, band, security
- Channel congestion: `netsh wlan show networks mode=bssid`, counts networks per channel
- Color coding: green (0 others), orange (1-2 others), red (3+ others)
- User's own channel count is subtracted before coloring
- Auto-refresh via timer, manual refresh button

### Media + Privacy (Y: ~205-230)
- Play/pause, prev, next via `keybd_event` (VK_MEDIA_*)
- Mic/camera status via registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\{microphone,webcam}`
- Green dot = in use, red dot = off. Polled every 5s.

### Speed Test (Y: ~235-390)
- Launches Ookla `speedtest.exe --format=json` as background process
- Non-blocking: Timer polls `$proc.HasExited` every 500ms
- Displays download, upload (Mbps), ping, jitter (ms)
- Two-column layout with colored arrows

### Devices (Y: ~395-end)
- Reads ARP table: `arp -a` parsed for IP + MAC
- Runs in background `Runspace` to avoid UI freeze
- Timer polls runspace completion every 500ms
- Cross-references `trusted-devices.json` for known device names
- Right-click context menu: trust/untrust devices
- Green dot = trusted, grey dot = unknown

## Non-Blocking I/O Pattern

```
1. Start work (Process or Runspace)
2. Create polling Timer (500ms interval)
3. Timer checks completion flag
4. On complete: stop timer, parse results, update UI
```

Both speed test and device scanning use this pattern, keeping the UI responsive during long operations.

## File Structure

```
WiFi-Monitor/
├── wifi-only.ps1              Main script (all-in-one Control Center)
├── wifi-monitor.ps1           Legacy full Control Center (ControlCenter29)
├── trusted-devices.json       User's trusted device list (gitignored)
├── trusted-devices.example.json  Template for trusted devices
├── control-center.ico         App icon
├── .gitignore
├── README.md
├── WIDGET-ANATOMY.md          This file
└── control-center-wireframe/  Design reference files
    ├── 01-control-center-wireframe.svg
    ├── build_wireframe.py
    ├── component-spec.json
    ├── claude-build-prompt.md
    └── index.html
```
