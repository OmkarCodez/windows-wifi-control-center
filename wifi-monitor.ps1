Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $null
try { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction Stop } catch {}
if (-not $scriptDir) { $scriptDir = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$trustedFile = Join-Path $scriptDir 'trusted-devices.json'
$speedtestExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Ookla.Speedtest.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe\speedtest.exe'

$fa = [System.Windows.Forms.Form].Assembly.Location
$da = [System.Drawing.Color].Assembly.Location
Add-Type -ReferencedAssemblies $fa,$da -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("gdi32.dll")]  public static extern IntPtr CreateRoundRectRgn(int x1,int y1,int x2,int y2,int cx,int cy);
    [DllImport("user32.dll")] public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);
    public static void Key(byte vk){keybd_event(vk,0,0,UIntPtr.Zero);keybd_event(vk,0,2,UIntPtr.Zero);}
}

public class DarkForm : Form {
    protected override void WndProc(ref Message m) {
        if (m.Msg==0x84) {
            base.WndProc(ref m);
            Point c=PointToClient(Cursor.Position); int g=7;
            if (c.Y<g) {
                if (c.X<g) m.Result=(IntPtr)13;
                else if (c.X>=Width-g) m.Result=(IntPtr)14;
                else m.Result=(IntPtr)12;
            } else if (c.Y>=Height-g) {
                if (c.X<g) m.Result=(IntPtr)16;
                else if (c.X>=Width-g) m.Result=(IntPtr)17;
                else m.Result=(IntPtr)15;
            } else if (c.X<g) m.Result=(IntPtr)10;
            else if (c.X>=Width-g) m.Result=(IntPtr)11;
            return;
        }
        base.WndProc(ref m);
    }
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume {
    int f1(IntPtr a);int f2(IntPtr a);int f3(out uint a);int f4(float a,ref Guid b);
    int SetMasterVolumeLevelScalar(float fLevel,ref Guid ctx);
    int f6(out float a);
    int GetMasterVolumeLevelScalar(out float level);
    int f8(uint a,float b,ref Guid c);int f9(uint a,float b,ref Guid c);int f10(uint a,out float b);int f11(uint a,out float b);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool m,ref Guid ctx);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool m);
    int f14(out uint a,out uint b);int f15(ref Guid a);int f16(ref Guid a);int f17(out uint a);int f18(out float a,out float b,out float c);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
    int Activate(ref Guid iid,int ctx,IntPtr p,[MarshalAs(UnmanagedType.IUnknown)] out object o);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int flow,int state,[MarshalAs(UnmanagedType.IUnknown)] out object col);
    int GetDefaultAudioEndpoint(int flow,int role,out IMMDevice dev);
}

[ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
public class MMDeviceEnumerator {}

public static class AudioManager {
    private static IAudioEndpointVolume GetVol(){
        var e=(IMMDeviceEnumerator)(new MMDeviceEnumerator());
        IMMDevice d;e.GetDefaultAudioEndpoint(0,1,out d);
        Guid iid=typeof(IAudioEndpointVolume).GUID;object o;
        d.Activate(ref iid,1,IntPtr.Zero,out o);return(IAudioEndpointVolume)o;
    }
    public static int GetVolume(){try{float l;GetVol().GetMasterVolumeLevelScalar(out l);return(int)(l*100);}catch{return -1;}}
    public static void SetVolume(int pct){try{Guid g=Guid.Empty;GetVol().SetMasterVolumeLevelScalar(pct/100f,ref g);}catch{}}
    public static void ToggleMute(){try{var v=GetVol();bool m;v.GetMute(out m);Guid g=Guid.Empty;v.SetMute(!m,ref g);}catch{}}
}
"@

# --- Data helpers ---
function Get-WifiInfo {
    $info = @{}
    foreach ($line in (netsh wlan show interfaces)) {
        if ($line -match '^\s+(.+?)\s+:\s+(.+)$') { $info[$Matches[1].Trim()] = $Matches[2].Trim() }
    }
    return $info
}
function Get-ChannelMap {
    $chCount = @{}; 1..13 | ForEach-Object { $chCount[$_] = 0 }
    try { foreach ($line in (netsh wlan show networks mode=bssid 2>&1)) {
        if ($line -match '^\s+Channel\s+:\s+(\d+)') { $c=[int]$Matches[1]; if ($chCount.ContainsKey($c)) { $chCount[$c]++ } }
    } } catch {}
    return $chCount
}
function Get-NetworkDevices {
    $jobs = @()
    1..254 | ForEach-Object { $jobs += (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("192.168.0.$_", 80) }
    $dl = [DateTime]::Now.AddSeconds(5)
    while ([DateTime]::Now -lt $dl) {
        $done = $true; foreach ($j in $jobs) { if (-not $j.IsCompleted) { $done = $false; break } }
        if ($done) { break }
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50
    }
    $devs = New-Object System.Collections.ArrayList
    foreach ($line in (arp -a 2>&1)) {
        if ($line -match '^\s*(192\.168\.0\.\d+)\s+([\da-f-]{17})\s+dynamic' -and $Matches[2] -ne 'ff-ff-ff-ff-ff-ff') {
            [void]$devs.Add(@{ IP=$Matches[1]; MAC=$Matches[2] })
        }
    }
    return ,$devs
}
function Get-TrustedDevices { if (Test-Path $trustedFile) { try { return @((Get-Content $trustedFile -Raw | ConvertFrom-Json).trusted) } catch {} }; return @() }
function Save-TrustedDevices($l) { @{ trusted = @($l) } | ConvertTo-Json -Depth 3 | Set-Content $trustedFile -Encoding UTF8 }
function Add-TrustedDevice($mac,$name) {
    $l = @(Get-TrustedDevices)
    if (-not ($l | Where-Object { $_.mac -eq $mac })) {
        $l += [PSCustomObject]@{ mac=$mac; name=$name; added=(Get-Date -Format 'yyyy-MM-dd') }; Save-TrustedDevices $l
    }
}
function Remove-TrustedDevice($mac) { Save-TrustedDevices (@(Get-TrustedDevices) | Where-Object { $_.mac -ne $mac }) }
function Get-Brightness { try { return [int](Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness -EA Stop).CurrentBrightness } catch { return -1 } }
function Set-Brightness($v) { try { (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods -EA Stop).WmiSetBrightness(1,[Math]::Max(0,[Math]::Min(100,$v))) } catch {} }
function Test-DeviceInUse($cat) {
    foreach ($p in @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cat",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cat\NonPackaged")) {
        if (Test-Path $p) { foreach ($i in (Get-ChildItem $p -EA SilentlyContinue)) {
            try { $s = Get-ItemProperty $i.PSPath -EA SilentlyContinue
                if ($s.LastUsedTimeStart -gt 0 -and $s.LastUsedTimeStop -eq 0) { return $true }
            } catch {} } }
    }; return $false
}

# --- Palette ---
$bg    = [System.Drawing.Color]::FromArgb(30,30,32)
$card  = [System.Drawing.Color]::FromArgb(42,42,44)
$cardL = [System.Drawing.Color]::FromArgb(56,56,58)
$txt   = [System.Drawing.Color]::FromArgb(245,245,247)
$dim   = [System.Drawing.Color]::FromArgb(134,134,139)
$sep   = [System.Drawing.Color]::FromArgb(50,50,52)
$blue  = [System.Drawing.Color]::FromArgb(10,132,255)
$grn   = [System.Drawing.Color]::FromArgb(48,209,88)
$org   = [System.Drawing.Color]::FromArgb(255,159,10)
$red   = [System.Drawing.Color]::FromArgb(255,69,58)

$fH  = New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold)
$fS  = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
$fB  = New-Object System.Drawing.Font('Segoe UI',8.5)
$fC  = New-Object System.Drawing.Font('Segoe UI',7.5)
$fT  = New-Object System.Drawing.Font('Segoe UI',6.5)
$fTB = New-Object System.Drawing.Font('Segoe UI',6.5,[System.Drawing.FontStyle]::Bold)
$fIc = New-Object System.Drawing.Font('Segoe UI',9)
$fMd = New-Object System.Drawing.Font('Segoe UI Symbol',12)
$fDot= New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)

$RI = [string][char]0x21BB
$DOT = [string][char]0x25CF
$aTR   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$aLTR  = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$aLTRB = $aLTR -bor [System.Windows.Forms.AnchorStyles]::Bottom
$aLBR  = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$aLB   = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom

# ========== FORM ==========
$W = 340; $M = 10; $CW = $W - 2*$M; $G = 8

$form = New-Object DarkForm
$form.Text = 'Control Center'
$form.FormBorderStyle = 'None'
$form.BackColor = $bg
$form.ForeColor = $txt
$form.Font = $fB
$form.TopMost = $true
$form.Opacity = 0.95
$form.ShowInTaskbar = $true
$form.StartPosition = 'Manual'
$form.MinimumSize = New-Object System.Drawing.Size(300,520)
$form.Location = New-Object System.Drawing.Point(([System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width - $W - 12),12)

$script:drag = $false; $script:dPt = New-Object System.Drawing.Point(0,0)
$form.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dPt=$_.Location } })
$form.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Location.X+$_.X-$script:dPt.X),($form.Location.Y+$_.Y-$script:dPt.Y)) } })
$form.Add_MouseUp({ $script:drag=$false })
$form.Add_Resize({
    if ($form.IsHandleCreated -and $form.WindowState -ne 'Minimized') {
        [void][WinAPI]::SetWindowRgn($form.Handle,[WinAPI]::CreateRoundRectRgn(0,0,$form.Width,$form.Height,18,18),$true)
    }
})

$Y = 4

# ---- HEADER: traffic-light buttons + expand/collapse, title ----
$btnClose = New-Object System.Windows.Forms.Label
$btnClose.Text = ''; $btnClose.Size = New-Object System.Drawing.Size(12,12)
$btnClose.BackColor = $red; $btnClose.Cursor = 'Hand'
$btnClose.Location = New-Object System.Drawing.Point(10,6)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$btnMin = New-Object System.Windows.Forms.Label
$btnMin.Text = ''; $btnMin.Size = New-Object System.Drawing.Size(12,12)
$btnMin.BackColor = $org; $btnMin.Cursor = 'Hand'
$btnMin.Location = New-Object System.Drawing.Point(28,6)
$btnMin.Add_Click({ $form.WindowState = 'Minimized' })
$form.Controls.Add($btnMin)

$script:expanded = $true; $script:fullH = 0
$btnExp = New-Object System.Windows.Forms.Label
$btnExp.Text = ''; $btnExp.Size = New-Object System.Drawing.Size(12,12)
$btnExp.BackColor = $grn; $btnExp.Cursor = 'Hand'
$btnExp.Location = New-Object System.Drawing.Point(46,6)
$btnExp.Add_Click({
    if ($script:expanded) {
        $script:fullH = $form.Height
        foreach ($c in @($pW,$pS,$pM,$pSp,$pD)) { $c.Visible = $false }
        $form.MinimumSize = New-Object System.Drawing.Size(200,24)
        $form.Height = 24
        $script:expanded = $false
    } else {
        $form.MinimumSize = New-Object System.Drawing.Size(300,520)
        foreach ($c in @($pW,$pS,$pM,$pSp,$pD)) { $c.Visible = $true }
        $form.Height = $script:fullH
        $script:expanded = $true
    }
})
$form.Controls.Add($btnExp)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'Control Center'; $lblTitle.Font = $fS; $lblTitle.ForeColor = $txt
$lblTitle.Location = New-Object System.Drawing.Point(64,$Y); $lblTitle.Size = New-Object System.Drawing.Size(200,16)
$lblTitle.Cursor = 'SizeAll'
$lblTitle.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dPt=$_.Location } })
$lblTitle.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Location.X+$_.X-$script:dPt.X),($form.Location.Y+$_.Y-$script:dPt.Y)) } })
$lblTitle.Add_MouseUp({ $script:drag=$false })
$form.Controls.Add($lblTitle)
$Y += 22

# ==== WI-FI CARD ====
$pW = New-Object System.Windows.Forms.Panel
$pW.Location = New-Object System.Drawing.Point($M,$Y); $pW.Size = New-Object System.Drawing.Size($CW,130); $pW.BackColor = $card
$pW.Anchor = $aLTR
$form.Controls.Add($pW)

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Wi-Fi'; $l.Font = $fS; $l.ForeColor = $grn
$l.Location = New-Object System.Drawing.Point(12,7); $l.Size = New-Object System.Drawing.Size(42,16)
$pW.Controls.Add($l)

$bWR = New-Object System.Windows.Forms.Label
$bWR.Text = $RI; $bWR.Font = $fIc; $bWR.ForeColor = $blue
$bWR.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bWR.BackColor = $cardL; $bWR.Cursor = 'Hand'
$bWR.Location = New-Object System.Drawing.Point(56,5); $bWR.Size = New-Object System.Drawing.Size(26,18)
$pW.Controls.Add($bWR)

$lblWTime = New-Object System.Windows.Forms.Label
$lblWTime.Text = ''; $lblWTime.Font = $fC; $lblWTime.ForeColor = $dim
$lblWTime.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lblWTime.Location = New-Object System.Drawing.Point(130,10); $lblWTime.Size = New-Object System.Drawing.Size(120,11)
$lblWTime.Anchor = $aTR
$pW.Controls.Add($lblWTime)

$wF = @('SSID','Channel','Signal','Speed','Band','Security')
$lblW = @{}; $ry = 26
foreach ($f in $wF) {
    $lk = New-Object System.Windows.Forms.Label
    $lk.Text = $f; $lk.Font = $fC; $lk.ForeColor = $dim
    $lk.Location = New-Object System.Drawing.Point(12,$ry); $lk.Size = New-Object System.Drawing.Size(52,12)
    $pW.Controls.Add($lk)
    $lv = New-Object System.Windows.Forms.Label
    $lv.Text = '--'; $lv.Font = $fB; $lv.ForeColor = $txt
    $lv.Location = New-Object System.Drawing.Point(68,$ry); $lv.Size = New-Object System.Drawing.Size(240,12)
    $lv.Anchor = $aLTR
    $pW.Controls.Add($lv)
    $lblW[$f] = $lv
    $ry += 13
}

$spCh = New-Object System.Windows.Forms.Panel
$spCh.Location = New-Object System.Drawing.Point(12,103); $spCh.Size = New-Object System.Drawing.Size(($CW-24),1); $spCh.BackColor = $sep
$spCh.Anchor = $aLTR
$pW.Controls.Add($spCh)

$script:lblCh = @{}; $chX = 14
for ($ch = 1; $ch -le 11; $ch++) {
    $cl = New-Object System.Windows.Forms.Label
    $cl.Text = [string]$ch; $cl.Font = $fT; $cl.ForeColor = $bg
    $cl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $cl.BackColor = $dim; $cl.Size = New-Object System.Drawing.Size(22,16)
    $cl.Location = New-Object System.Drawing.Point($chX,109)
    $pW.Controls.Add($cl)
    $script:lblCh[$ch] = $cl
    $chX += 25
}

function Update-Wifi {
    $bWR.ForeColor = $txt
    $w = Get-WifiInfo
    $lblW['SSID'].Text = if ($w['SSID']) { [string]$w['SSID'] } else { 'N/A' }
    $myCh = $w['Channel']
    $lblW['Channel'].Text = if ($myCh) { [string]$myCh } else { 'N/A' }
    if ($myCh -and ($myCh -in @('1','6','11'))) { $lblW['Channel'].ForeColor = $grn } else { $lblW['Channel'].ForeColor = $org }
    $lblW['Signal'].Text = if ($w['Signal']) { [string]$w['Signal'] } else { 'N/A' }
    $lblW['Speed'].Text = if ($w['Receive rate (Mbps)']) { "$($w['Receive rate (Mbps)']) Mbps" } else { 'N/A' }
    $lblW['Band'].Text = if ($w['Radio type']) { [string]$w['Radio type'] } else { 'N/A' }
    $lblW['Security'].Text = if ($w['Authentication']) { [string]$w['Authentication'] } else { 'N/A' }
    $chMap = Get-ChannelMap
    $myChNum = 0; if ($myCh) { try { $myChNum = [int]$myCh } catch {} }
    if ($myChNum -gt 0 -and $chMap.ContainsKey($myChNum)) { $chMap[$myChNum] = [Math]::Max(0,$chMap[$myChNum]-1) }
    for ($i = 1; $i -le 11; $i++) {
        $cnt = 0; if ($chMap.ContainsKey($i)) { $cnt = $chMap[$i] }
        if ($cnt -eq 0) { $script:lblCh[$i].BackColor = $grn }
        elseif ($cnt -le 2) { $script:lblCh[$i].BackColor = $org }
        else { $script:lblCh[$i].BackColor = $red }
        if ($i -eq $myChNum) { $script:lblCh[$i].Font = $fTB; $script:lblCh[$i].ForeColor = $txt }
        else { $script:lblCh[$i].Font = $fT; $script:lblCh[$i].ForeColor = $bg }
    }
    $lblWTime.Text = Get-Date -Format 'HH:mm:ss'
    $bWR.ForeColor = $blue
}
$bWR.Add_Click({ Update-Wifi })
$Y += (130 + $G)

# ==== CONTROLS CARD ====
$pS = New-Object System.Windows.Forms.Panel
$pS.Location = New-Object System.Drawing.Point($M,$Y); $pS.Size = New-Object System.Drawing.Size($CW,92); $pS.BackColor = $card
$pS.Anchor = $aLTR
$form.Controls.Add($pS)

# Volume (synced with system via Core Audio API)
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Vol'; $l.Font = $fC; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point(12,6); $l.Size = New-Object System.Drawing.Size(22,12)
$pS.Controls.Add($l)

$bMute = New-Object System.Windows.Forms.Button
$bMute.Text = 'M'; $bMute.Font = $fC; $bMute.FlatStyle = 'Flat'; $bMute.FlatAppearance.BorderSize = 0
$bMute.BackColor = $cardL; $bMute.ForeColor = $dim; $bMute.Cursor = 'Hand'
$bMute.Location = New-Object System.Drawing.Point(36,3); $bMute.Size = New-Object System.Drawing.Size(20,16)
$bMute.Add_Click({ [AudioManager]::ToggleMute() })
$pS.Controls.Add($bMute)

$initVol = [AudioManager]::GetVolume(); if ($initVol -lt 0) { $initVol = 50 }
$sVol = New-Object System.Windows.Forms.TrackBar
$sVol.Location = New-Object System.Drawing.Point(58,0); $sVol.Size = New-Object System.Drawing.Size(($CW-100),25)
$sVol.Minimum = 0; $sVol.Maximum = 100; $sVol.Value = $initVol; $sVol.TickStyle = 'None'; $sVol.BackColor = $card
$sVol.Anchor = $aLTR
$pS.Controls.Add($sVol)
$lVV = New-Object System.Windows.Forms.Label
$lVV.Text = [string]$initVol; $lVV.Font = $fC; $lVV.ForeColor = $dim; $lVV.BackColor = $card
$lVV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lVV.Location = New-Object System.Drawing.Point(($CW-42),6); $lVV.Size = New-Object System.Drawing.Size(34,12)
$lVV.Anchor = $aTR
$pS.Controls.Add($lVV)
$script:volSync = $false
$sVol.Add_Scroll({ [AudioManager]::SetVolume($sVol.Value); $lVV.Text = [string]$sVol.Value })
$sVol.Add_ValueChanged({ if (-not $script:volSync) { [AudioManager]::SetVolume($sVol.Value); $lVV.Text = [string]$sVol.Value } })

$sp1 = New-Object System.Windows.Forms.Panel
$sp1.Location = New-Object System.Drawing.Point(12,27); $sp1.Size = New-Object System.Drawing.Size(($CW-24),1); $sp1.BackColor = $sep
$sp1.Anchor = $aLTR
$pS.Controls.Add($sp1)

# Brightness
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Disp'; $l.Font = $fC; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point(12,34); $l.Size = New-Object System.Drawing.Size(26,12)
$pS.Controls.Add($l)
$cB = Get-Brightness; if ($cB -lt 0) { $cB = 50 }
$sBri = New-Object System.Windows.Forms.TrackBar
$sBri.Location = New-Object System.Drawing.Point(58,30); $sBri.Size = New-Object System.Drawing.Size(($CW-100),25)
$sBri.Minimum = 0; $sBri.Maximum = 100; $sBri.Value = $cB; $sBri.TickStyle = 'None'; $sBri.BackColor = $card
$sBri.Anchor = $aLTR
$pS.Controls.Add($sBri)
$lBV = New-Object System.Windows.Forms.Label
$lBV.Text = [string]$cB; $lBV.Font = $fC; $lBV.ForeColor = $dim; $lBV.BackColor = $card
$lBV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lBV.Location = New-Object System.Drawing.Point(($CW-42),34); $lBV.Size = New-Object System.Drawing.Size(34,12)
$lBV.Anchor = $aTR
$pS.Controls.Add($lBV)
$sBri.Add_Scroll({ Set-Brightness $sBri.Value; $lBV.Text = [string]$sBri.Value })

$sp2 = New-Object System.Windows.Forms.Panel
$sp2.Location = New-Object System.Drawing.Point(12,57); $sp2.Size = New-Object System.Drawing.Size(($CW-24),1); $sp2.BackColor = $sep
$sp2.Anchor = $aLTR
$pS.Controls.Add($sp2)

# Opacity
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Opacity'; $l.Font = $fC; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point(12,66); $l.Size = New-Object System.Drawing.Size(40,12)
$pS.Controls.Add($l)
$sOpa = New-Object System.Windows.Forms.TrackBar
$sOpa.Location = New-Object System.Drawing.Point(58,62); $sOpa.Size = New-Object System.Drawing.Size(($CW-100),25)
$sOpa.Minimum = 20; $sOpa.Maximum = 100; $sOpa.Value = 95; $sOpa.TickStyle = 'None'; $sOpa.BackColor = $card
$sOpa.Anchor = $aLTR
$pS.Controls.Add($sOpa)
$lOV = New-Object System.Windows.Forms.Label
$lOV.Text = '95%'; $lOV.Font = $fC; $lOV.ForeColor = $dim; $lOV.BackColor = $card
$lOV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lOV.Location = New-Object System.Drawing.Point(($CW-42),66); $lOV.Size = New-Object System.Drawing.Size(34,12)
$lOV.Anchor = $aTR
$pS.Controls.Add($lOV)
$sOpa.Add_Scroll({ $form.Opacity = $sOpa.Value / 100; $lOV.Text = "$($sOpa.Value)%" })
$Y += (92 + $G)

# ==== MEDIA + PRIVACY (green circle ON, red circle OFF) ====
$pM = New-Object System.Windows.Forms.Panel
$pM.Location = New-Object System.Drawing.Point($M,$Y); $pM.Size = New-Object System.Drawing.Size($CW,34); $pM.BackColor = $card
$pM.Anchor = $aLTR
$form.Controls.Add($pM)

foreach ($mInfo in @(
    @{ T=[string][char]0x23EE; X=12; BG=$cardL; VK=0xB1 },
    @{ T=[string][char]0x23EF; X=52; BG=$blue;  VK=0xB3 },
    @{ T=[string][char]0x23ED; X=92; BG=$cardL; VK=0xB0 }
)) {
    $mb = New-Object System.Windows.Forms.Button
    $mb.Text = $mInfo.T; $mb.Font = $fMd; $mb.FlatStyle = 'Flat'; $mb.FlatAppearance.BorderSize = 0
    $mb.BackColor = $mInfo.BG; $mb.ForeColor = $txt; $mb.Cursor = 'Hand'
    $mb.Location = New-Object System.Drawing.Point($mInfo.X,4); $mb.Size = New-Object System.Drawing.Size(36,25)
    $vk = $mInfo.VK
    $mb.Add_Click({ [WinAPI]::Key($vk) }.GetNewClosure())
    $pM.Controls.Add($mb)
}

$lMicDot = New-Object System.Windows.Forms.Label
$lMicDot.Text = $DOT; $lMicDot.Font = $fDot; $lMicDot.ForeColor = $red
$lMicDot.Location = New-Object System.Drawing.Point(144,5); $lMicDot.Size = New-Object System.Drawing.Size(16,20)
$pM.Controls.Add($lMicDot)
$lMic = New-Object System.Windows.Forms.Label
$lMic.Text = 'MIC'; $lMic.Font = $fC; $lMic.ForeColor = $dim
$lMic.Location = New-Object System.Drawing.Point(160,10); $lMic.Size = New-Object System.Drawing.Size(28,14)
$pM.Controls.Add($lMic)

$lCamDot = New-Object System.Windows.Forms.Label
$lCamDot.Text = $DOT; $lCamDot.Font = $fDot; $lCamDot.ForeColor = $red
$lCamDot.Location = New-Object System.Drawing.Point(204,5); $lCamDot.Size = New-Object System.Drawing.Size(16,20)
$pM.Controls.Add($lCamDot)
$lCam = New-Object System.Windows.Forms.Label
$lCam.Text = 'CAM'; $lCam.Font = $fC; $lCam.ForeColor = $dim
$lCam.Location = New-Object System.Drawing.Point(220,10); $lCam.Size = New-Object System.Drawing.Size(28,14)
$pM.Controls.Add($lCam)
$Y += (34 + $G)

# ==== SPEED TEST CARD (moved above Devices) ====
$pSp = New-Object System.Windows.Forms.Panel
$pSp.Location = New-Object System.Drawing.Point($M,$Y); $pSp.Size = New-Object System.Drawing.Size($CW,108); $pSp.BackColor = $card
$pSp.Anchor = $aLTR
$form.Controls.Add($pSp)

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Speed Test'; $l.Font = $fS; $l.ForeColor = $org
$l.Location = New-Object System.Drawing.Point(12,7); $l.Size = New-Object System.Drawing.Size(76,16)
$pSp.Controls.Add($l)

$bSpRun = New-Object System.Windows.Forms.Label
$bSpRun.Text = [string][char]0x25B6; $bSpRun.Font = $fIc; $bSpRun.ForeColor = $bg
$bSpRun.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bSpRun.BackColor = $org; $bSpRun.Cursor = 'Hand'
$bSpRun.Location = New-Object System.Drawing.Point(90,5); $bSpRun.Size = New-Object System.Drawing.Size(26,18)
$pSp.Controls.Add($bSpRun)

$spF = @('Download','Upload','Ping','Jitter','Server'); $lblSp = @{}; $sy = 26
foreach ($f in $spF) {
    $lk = New-Object System.Windows.Forms.Label
    $lk.Text = $f; $lk.Font = $fC; $lk.ForeColor = $dim
    $lk.Location = New-Object System.Drawing.Point(12,$sy); $lk.Size = New-Object System.Drawing.Size(52,12)
    $pSp.Controls.Add($lk)
    $lv = New-Object System.Windows.Forms.Label
    $lv.Text = '--'; $lv.Font = $fB; $lv.ForeColor = $txt
    $lv.Location = New-Object System.Drawing.Point(68,$sy); $lv.Size = New-Object System.Drawing.Size(240,12)
    $lv.Anchor = $aLTR
    $pSp.Controls.Add($lv)
    $lblSp[$f] = $lv
    $sy += 14
}
$lSpM = New-Object System.Windows.Forms.Label
$lSpM.Text = ''; $lSpM.Font = $fC; $lSpM.ForeColor = $dim
$lSpM.Location = New-Object System.Drawing.Point(12,$sy); $lSpM.Size = New-Object System.Drawing.Size(290,12)
$pSp.Controls.Add($lSpM)

$script:spRunning = $false
$bSpRun.Add_Click({
    if ($script:spRunning) { return }
    if (-not (Test-Path $speedtestExe)) { $lSpM.Text = 'CLI not found'; $lSpM.ForeColor = $red; return }
    $script:spRunning = $true; $bSpRun.Text = '...'
    $lSpM.Text = 'Running (~20s)...'; $lSpM.ForeColor = $org; $form.Refresh()
    try {
        $tmpF = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath $speedtestExe -ArgumentList '--accept-license','--accept-gdpr','--format=json' -RedirectStandardOutput $tmpF -WindowStyle Hidden -PassThru
        while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
        $json = Get-Content $tmpF -Raw
        Remove-Item $tmpF -Force -ErrorAction SilentlyContinue
        $r = $json | ConvertFrom-Json
        $dl = [math]::Round($r.download.bandwidth * 8 / 1000000,1)
        $ul = [math]::Round($r.upload.bandwidth * 8 / 1000000,1)
        $pi = [math]::Round($r.ping.latency,1)
        $ji = [math]::Round($r.ping.jitter,2)
        $lblSp['Download'].Text = "$dl Mbps"; $lblSp['Upload'].Text = "$ul Mbps"
        $lblSp['Ping'].Text = "$pi ms"; $lblSp['Jitter'].Text = "$ji ms"
        $lblSp['Server'].Text = "$($r.server.name), $($r.server.location)"; $lblSp['Server'].Font = $fC
        if ($dl -ge 45) { $lblSp['Download'].ForeColor = $grn } elseif ($dl -ge 25) { $lblSp['Download'].ForeColor = $org } else { $lblSp['Download'].ForeColor = $red }
        if ($pi -le 10) { $lblSp['Ping'].ForeColor = $grn } elseif ($pi -le 30) { $lblSp['Ping'].ForeColor = $org } else { $lblSp['Ping'].ForeColor = $red }
        $lSpM.Text = "Done $(Get-Date -Format 'HH:mm:ss')"; $lSpM.ForeColor = $grn
    } catch { $lSpM.Text = 'Error'; $lSpM.ForeColor = $red }
    $script:spRunning = $false; $bSpRun.Text = [string][char]0x25B6
})
$Y += (108 + $G)

# ==== DEVICES CARD (moved to bottom, stretches on resize) ====
$pD = New-Object System.Windows.Forms.Panel
$pD.Location = New-Object System.Drawing.Point($M,$Y); $pD.Size = New-Object System.Drawing.Size($CW,130); $pD.BackColor = $card
$pD.Anchor = $aLTRB
$form.Controls.Add($pD)

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Devices'; $l.Font = $fS; $l.ForeColor = $blue
$l.Location = New-Object System.Drawing.Point(12,7); $l.Size = New-Object System.Drawing.Size(56,16)
$pD.Controls.Add($l)

$lDC = New-Object System.Windows.Forms.Label
$lDC.Text = "Tap $RI to scan"; $lDC.Font = $fC; $lDC.ForeColor = $dim
$lDC.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lDC.Location = New-Object System.Drawing.Point(120,8); $lDC.Size = New-Object System.Drawing.Size(140,12)
$lDC.Anchor = $aTR
$pD.Controls.Add($lDC)

$bDR = New-Object System.Windows.Forms.Label
$bDR.Text = $RI; $bDR.Font = $fIc; $bDR.ForeColor = $blue
$bDR.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bDR.BackColor = $cardL; $bDR.Cursor = 'Hand'
$bDR.Location = New-Object System.Drawing.Point(70,5); $bDR.Size = New-Object System.Drawing.Size(26,18)
$pD.Controls.Add($bDR)

$lsD = New-Object System.Windows.Forms.ListView
$lsD.Location = New-Object System.Drawing.Point(12,26); $lsD.Size = New-Object System.Drawing.Size(($CW-24),78)
$lsD.View = 'Details'; $lsD.FullRowSelect = $true; $lsD.BackColor = $card; $lsD.ForeColor = $txt; $lsD.Font = $fC
$lsD.GridLines = $false; $lsD.BorderStyle = 'None'; $lsD.HeaderStyle = 'Nonclickable'
$lsD.Anchor = $aLTRB
[void]$lsD.Columns.Add('',22); [void]$lsD.Columns.Add('IP',78); [void]$lsD.Columns.Add('MAC',108); [void]$lsD.Columns.Add('Name',100)
$pD.Controls.Add($lsD)

$lAlert = New-Object System.Windows.Forms.Label
$lAlert.Text = ''; $lAlert.Font = $fC; $lAlert.ForeColor = $dim
$lAlert.Location = New-Object System.Drawing.Point(12,110); $lAlert.Size = New-Object System.Drawing.Size(290,12)
$lAlert.Anchor = $aLB
$pD.Controls.Add($lAlert)

$ctx = New-Object System.Windows.Forms.ContextMenuStrip
$mT = New-Object System.Windows.Forms.ToolStripMenuItem('Trust')
$mT.Add_Click({
    if ($lsD.SelectedItems.Count -gt 0) {
        $sel = $lsD.SelectedItems[0]
        $sMac = [string]$sel.SubItems[2].Text; $sIp = [string]$sel.SubItems[1].Text
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = 'Name'; $dlg.Size = New-Object System.Drawing.Size(260,100)
        $dlg.StartPosition = 'CenterParent'; $dlg.BackColor = $card; $dlg.ForeColor = $txt; $dlg.TopMost = $true
        $tbox = New-Object System.Windows.Forms.TextBox
        $tbox.Location = New-Object System.Drawing.Point(8,10); $tbox.Size = New-Object System.Drawing.Size(230,22); $tbox.Text = "Device $sIp"
        $dlg.Controls.Add($tbox)
        $okBtn = New-Object System.Windows.Forms.Button
        $okBtn.Text = 'OK'; $okBtn.Font = $fB; $okBtn.FlatStyle = 'Flat'; $okBtn.FlatAppearance.BorderSize = 0
        $okBtn.BackColor = $grn; $okBtn.ForeColor = $bg; $okBtn.Cursor = 'Hand'
        $okBtn.Location = New-Object System.Drawing.Point(80,40); $okBtn.Size = New-Object System.Drawing.Size(80,24)
        $okBtn.Add_Click({ Add-TrustedDevice $sMac $tbox.Text; $dlg.Close() })
        $dlg.Controls.Add($okBtn)
        [void]$dlg.ShowDialog()
    }
})
[void]$ctx.Items.Add($mT)
$mU = New-Object System.Windows.Forms.ToolStripMenuItem('Untrust')
$mU.Add_Click({ if ($lsD.SelectedItems.Count -gt 0) { Remove-TrustedDevice ([string]$lsD.SelectedItems[0].SubItems[2].Text) } })
[void]$ctx.Items.Add($mU)
$lsD.ContextMenuStrip = $ctx

$bDR.Add_Click({
    $bDR.ForeColor = $txt; $lDC.Text = 'Scanning...'; $form.Refresh()
    $devs = Get-NetworkDevices
    $tr = @(Get-TrustedDevices); $tMacs = @($tr | ForEach-Object { [string]$_.mac })
    $lsD.Items.Clear(); $unk = 0
    foreach ($dev in $devs) {
        $dIp = [string]$dev.IP; $dMac = [string]$dev.MAC
        $ok = $dMac -in $tMacs
        $info = $tr | Where-Object { $_.mac -eq $dMac }
        $nm = if ($info) { [string]$info.name } else { '?' }
        if (-not $ok) { $unk++ }
        $item = New-Object System.Windows.Forms.ListViewItem
        if ($ok) { $item.Text = [string][char]0x2713; $item.ForeColor = $grn }
        else { $item.Text = '!'; $item.ForeColor = $red }
        $item.BackColor = $card
        [void]$item.SubItems.Add($dIp); [void]$item.SubItems.Add($dMac); [void]$item.SubItems.Add($nm)
        [void]$lsD.Items.Add($item)
    }
    $lDC.Text = "$($devs.Count) total, $unk unknown"
    if ($unk -gt 0) { $lAlert.Text = "$unk unknown device(s)"; $lAlert.ForeColor = $red }
    else { $lAlert.Text = 'All trusted'; $lAlert.ForeColor = $grn }
    $bDR.ForeColor = $blue
})
$Y += (130 + 12)

# ==== FINAL SIZE + CORNERS ====
$form.Size = New-Object System.Drawing.Size($W,$Y)
$form.Add_Shown({
    [void][WinAPI]::SetWindowRgn($form.Handle,[WinAPI]::CreateRoundRectRgn(0,0,$form.Width,$form.Height,18,18),$true)
    [void][WinAPI]::SetWindowRgn($btnClose.Handle,[WinAPI]::CreateRoundRectRgn(0,0,13,13,12,12),$true)
    [void][WinAPI]::SetWindowRgn($btnMin.Handle,[WinAPI]::CreateRoundRectRgn(0,0,13,13,12,12),$true)
    [void][WinAPI]::SetWindowRgn($btnExp.Handle,[WinAPI]::CreateRoundRectRgn(0,0,13,13,12,12),$true)
})

# ==== TIMER (mic/cam, volume sync, brightness sync, 5s) ====
$tmr = New-Object System.Windows.Forms.Timer
$tmr.Interval = 5000
$tmr.Add_Tick({
    if (Test-DeviceInUse 'microphone') { $lMicDot.ForeColor = $grn } else { $lMicDot.ForeColor = $red }
    if (Test-DeviceInUse 'webcam') { $lCamDot.ForeColor = $grn } else { $lCamDot.ForeColor = $red }
    $v = [AudioManager]::GetVolume(); if ($v -ge 0) { $script:volSync = $true; $sVol.Value = $v; $lVV.Text = [string]$v; $script:volSync = $false }
    $b = Get-Brightness; if ($b -ge 0) { $sBri.Value = $b; $lBV.Text = [string]$b }
})
$tmr.Start()

Update-Wifi

[System.Windows.Forms.Application]::Run($form)
