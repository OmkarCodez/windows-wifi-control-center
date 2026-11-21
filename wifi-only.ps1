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
            Point s=new Point(m.LParam.ToInt32()&0xFFFF,(m.LParam.ToInt32()>>16)&0xFFFF);
            Point c=PointToClient(s); int g=10;
            if (c.Y>=Height-g || c.Y<g || c.X<g || c.X>=Width-g) {
                if (c.Y<g) {
                    if (c.X<g) m.Result=(IntPtr)13;
                    else if (c.X>=Width-g) m.Result=(IntPtr)14;
                    else m.Result=(IntPtr)12;
                } else if (c.Y>=Height-g) {
                    if (c.X<g) m.Result=(IntPtr)16;
                    else if (c.X>=Width-g) m.Result=(IntPtr)17;
                    else m.Result=(IntPtr)15;
                } else if (c.X<g) m.Result=(IntPtr)10;
                else m.Result=(IntPtr)11;
                return;
            }
            base.WndProc(ref m);
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

public class SliderControl : Control {
    private int _min, _max, _val;
    private bool _dragging;
    private Color _trackColor, _fillColor, _thumbColor;
    public event EventHandler ValueChanged;
    public SliderControl(int min, int max, int val, Color track, Color fill, Color thumb) {
        _min=min; _max=max; _val=val; _trackColor=track; _fillColor=fill; _thumbColor=thumb;
        SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);
        Height=14; Cursor=Cursors.Hand;
    }
    public int Value { get{return _val;} set{if(value!=_val){_val=Math.Max(_min,Math.Min(_max,value));Invalidate();}} }
    public int Minimum { get{return _min;} set{_min=value;} }
    public int Maximum { get{return _max;} set{_max=value;} }
    public bool Dragging { get{return _dragging;} }
    public void SetValueFromSystem(int v){if(!_dragging){_val=Math.Max(_min,Math.Min(_max,v));Invalidate();}}
    protected override void OnPaint(PaintEventArgs e) {
        var g=e.Graphics; g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        float range=Math.Max(1,_max-_min);
        float pct=Math.Max(0f,Math.Min(1f,(_val-_min)/range));
        using(var bt=new SolidBrush(_trackColor)) g.FillRectangle(bt,0,5,Width,4);
        int fw=(int)(Width*pct);
        if(fw>0) using(var bf=new SolidBrush(_fillColor)) g.FillRectangle(bf,0,5,fw,4);
        int tx=Math.Max(0,Math.Min(Width-12,(int)(Width*pct)-6));
        using(var bth=new SolidBrush(_thumbColor)) g.FillEllipse(bth,tx,1,12,12);
    }
    private void UpdateFromMouse(int mx) {
        float pct=Math.Max(0f,Math.Min(1f,(float)mx/Width));
        int nv=(int)(_min+pct*(_max-_min));
        if(nv!=_val){_val=nv;Invalidate();if(ValueChanged!=null)ValueChanged(this,EventArgs.Empty);}
    }
    protected override void OnMouseDown(MouseEventArgs e){_dragging=true;Capture=true;UpdateFromMouse(e.X);base.OnMouseDown(e);}
    protected override void OnMouseMove(MouseEventArgs e){if(_dragging)UpdateFromMouse(e.X);base.OnMouseMove(e);}
    protected override void OnMouseUp(MouseEventArgs e){_dragging=false;Capture=false;base.OnMouseUp(e);}
}

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
function Get-TrustedDevices { if (Test-Path $trustedFile) { return (Get-Content $trustedFile -Raw | ConvertFrom-Json) } else { return @() } }
function Save-TrustedDevices($list) { $list | ConvertTo-Json -Depth 3 | Set-Content $trustedFile -Encoding UTF8 }
function Add-TrustedDevice($mac,$name) { $list = @(Get-TrustedDevices); $list += [PSCustomObject]@{mac=$mac;name=$name}; Save-TrustedDevices $list }
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
$bg    = [System.Drawing.Color]::FromArgb(28,28,30)
$card  = [System.Drawing.Color]::FromArgb(44,44,46)
$cardL = [System.Drawing.Color]::FromArgb(58,58,60)
$txt   = [System.Drawing.Color]::FromArgb(242,242,247)
$dim   = [System.Drawing.Color]::FromArgb(142,142,147)
$sep   = [System.Drawing.Color]::FromArgb(54,54,56)
$blue  = [System.Drawing.Color]::FromArgb(10,132,255)
$grn   = [System.Drawing.Color]::FromArgb(48,209,88)
$org   = [System.Drawing.Color]::FromArgb(255,159,10)
$red   = [System.Drawing.Color]::FromArgb(255,69,58)

$fTitle = New-Object System.Drawing.Font('Segoe UI',7.5,[System.Drawing.FontStyle]::Bold)
$fSect  = New-Object System.Drawing.Font('Segoe UI',8.5,[System.Drawing.FontStyle]::Bold)
$fLabel = New-Object System.Drawing.Font('Segoe UI',8)
$fValue = New-Object System.Drawing.Font('Segoe UI',8.5,[System.Drawing.FontStyle]::Bold)
$fSmall = New-Object System.Drawing.Font('Segoe UI',7)
$fCh    = New-Object System.Drawing.Font('Segoe UI',7,[System.Drawing.FontStyle]::Bold)
$fIcon  = New-Object System.Drawing.Font('Segoe UI',9)
$fMd    = New-Object System.Drawing.Font('Segoe UI Symbol',12)
$fDot   = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
$fLg    = New-Object System.Drawing.Font('Segoe UI',18,[System.Drawing.FontStyle]::Bold)
$fArr   = New-Object System.Drawing.Font('Segoe UI',14)

$RI  = [string][char]0x21BB
$DOT = [string][char]0x25CF
$aTR   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$aLTR  = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$aLTRB = $aLTR -bor [System.Windows.Forms.AnchorStyles]::Bottom
$aLB   = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom

# ========== FORM ==========
$W = 300; $pad = 14; $CW = $W - 2*$pad

$form = New-Object DarkForm
$form.Text = 'Control Center'
$form.FormBorderStyle = 'None'
$form.BackColor = $bg
$form.ForeColor = $txt
$form.Font = $fLabel
$form.TopMost = $true
$form.Opacity = 0.96
$form.ShowInTaskbar = $true
$form.StartPosition = 'Manual'
$form.MinimumSize = New-Object System.Drawing.Size(240,20)
$form.Location = New-Object System.Drawing.Point(([System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width - $W - 16),16)

$script:drag = $false; $script:dPt = New-Object System.Drawing.Point(0,0)
$form.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dPt=$_.Location } })
$form.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Location.X+$_.X-$script:dPt.X),($form.Location.Y+$_.Y-$script:dPt.Y)) } })
$form.Add_MouseUp({ $script:drag=$false })

$form.Add_Resize({
    if ($form.IsHandleCreated -and $form.WindowState -ne 'Minimized') {
        [void][WinAPI]::SetWindowRgn($form.Handle,[WinAPI]::CreateRoundRectRgn(0,0,($form.Width+1),($form.Height+1),14,14),$true)
    }
})

# ==============================
#  THIN TITLE BAR (centered)
# ==============================
$Y = 4
$grpW = 128
$gX = [int](($W - $grpW) / 2)

$btnClose = New-Object System.Windows.Forms.Label
$btnClose.Size = New-Object System.Drawing.Size(10,10)
$btnClose.BackColor = $red; $btnClose.Cursor = 'Hand'
$btnClose.Location = New-Object System.Drawing.Point($gX,($Y+1))
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$btnMin = New-Object System.Windows.Forms.Label
$btnMin.Size = New-Object System.Drawing.Size(10,10)
$btnMin.BackColor = $org; $btnMin.Cursor = 'Hand'
$btnMin.Location = New-Object System.Drawing.Point(($gX+15),($Y+1))
$btnMin.Add_Click({ $form.WindowState = 'Minimized' })
$form.Controls.Add($btnMin)

$btnExp = New-Object System.Windows.Forms.Label
$btnExp.Size = New-Object System.Drawing.Size(10,10)
$btnExp.BackColor = $grn; $btnExp.Cursor = 'Hand'
$btnExp.Location = New-Object System.Drawing.Point(($gX+30),($Y+1))
$script:expanded = $true; $script:fullH = 0
$btnExp.Add_Click({
    if ($script:expanded) {
        $script:fullH = $form.Height
        $form.Height = 20
        $script:expanded = $false
    } else {
        $form.Height = $script:fullH
        $script:expanded = $true
    }
})
$form.Controls.Add($btnExp)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'Control Center'; $lblTitle.Font = $fTitle; $lblTitle.ForeColor = $dim
$lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblTitle.Location = New-Object System.Drawing.Point(($gX+46),$Y); $lblTitle.Size = New-Object System.Drawing.Size(82,12)
$lblTitle.Cursor = 'SizeAll'
$lblTitle.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:drag=$true; $script:dPt=$_.Location } })
$lblTitle.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Location.X+$_.X-$script:dPt.X),($form.Location.Y+$_.Y-$script:dPt.Y)) } })
$lblTitle.Add_MouseUp({ $script:drag=$false })
$form.Controls.Add($lblTitle)
$Y += 18

# ==============================
#  CONTROLS — custom drawn sliders (no TrackBar)
# ==============================
$sepCtrl = New-Object System.Windows.Forms.Panel
$sepCtrl.Location = New-Object System.Drawing.Point($pad,$Y); $sepCtrl.Size = New-Object System.Drawing.Size($CW,1); $sepCtrl.BackColor = $sep; $sepCtrl.Anchor = $aLTR
$form.Controls.Add($sepCtrl)
$Y += 5

function New-Slider($parent,$x,$y,$w,$min,$max,$val,$onChange) {
    $sl = New-Object SliderControl($min,$max,$val,$cardL,$blue,$txt)
    $sl.Location = New-Object System.Drawing.Point($x,$y)
    $sl.Width = $w
    $sl.BackColor = $bg
    $parent.Controls.Add($sl)
    if ($onChange) { $sl.Add_ValueChanged($onChange) }
    return $sl
}

# Volume
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Vol'; $l.Font = $fSmall; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point($pad,($Y+2)); $l.Size = New-Object System.Drawing.Size(22,12)
$form.Controls.Add($l)

$bMute = New-Object System.Windows.Forms.Button
$bMute.Text = 'M'; $bMute.Font = $fSmall; $bMute.FlatStyle = 'Flat'; $bMute.FlatAppearance.BorderSize = 0
$bMute.BackColor = $cardL; $bMute.ForeColor = $dim; $bMute.Cursor = 'Hand'
$bMute.Location = New-Object System.Drawing.Point(($pad+24),($Y+1)); $bMute.Size = New-Object System.Drawing.Size(18,14)
$bMute.Add_Click({ [AudioManager]::ToggleMute() })
$form.Controls.Add($bMute)

$lVV = New-Object System.Windows.Forms.Label
$initVol = [AudioManager]::GetVolume(); if ($initVol -lt 0) { $initVol = 50 }
$lVV.Text = [string]$initVol; $lVV.Font = $fSmall; $lVV.ForeColor = $dim
$lVV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lVV.Location = New-Object System.Drawing.Point(($W-$pad-24),($Y+2)); $lVV.Size = New-Object System.Drawing.Size(24,12)
$lVV.Anchor = $aTR
$form.Controls.Add($lVV)

$slVol = New-Slider $form ($pad+46) $Y ($CW-70-24) 0 100 $initVol {
    $v = $this.Value; [AudioManager]::SetVolume($v); $lVV.Text = [string]$v
}
$Y += 18

# Brightness
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Bri'; $l.Font = $fSmall; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point($pad,($Y+2)); $l.Size = New-Object System.Drawing.Size(22,12)
$form.Controls.Add($l)

$lBV = New-Object System.Windows.Forms.Label
$cB = Get-Brightness; if ($cB -lt 0) { $cB = 50 }
$lBV.Text = [string]$cB; $lBV.Font = $fSmall; $lBV.ForeColor = $dim
$lBV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lBV.Location = New-Object System.Drawing.Point(($W-$pad-24),($Y+2)); $lBV.Size = New-Object System.Drawing.Size(24,12)
$lBV.Anchor = $aTR
$form.Controls.Add($lBV)

$slBri = New-Slider $form ($pad+46) $Y ($CW-70) 0 100 $cB {
    $v = $this.Value; Set-Brightness $v; $lBV.Text = [string]$v
}
$Y += 18

# Opacity
$l = New-Object System.Windows.Forms.Label
$l.Text = 'Opa'; $l.Font = $fSmall; $l.ForeColor = $dim
$l.Location = New-Object System.Drawing.Point($pad,($Y+2)); $l.Size = New-Object System.Drawing.Size(24,12)
$form.Controls.Add($l)

$lOV = New-Object System.Windows.Forms.Label
$lOV.Text = '96%'; $lOV.Font = $fSmall; $lOV.ForeColor = $dim
$lOV.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lOV.Location = New-Object System.Drawing.Point(($W-$pad-28),($Y+2)); $lOV.Size = New-Object System.Drawing.Size(28,12)
$lOV.Anchor = $aTR
$form.Controls.Add($lOV)

$slOpa = New-Slider $form ($pad+46) $Y ($CW-74) 20 100 96 {
    $v = $this.Value; $form.Opacity = $v / 100; $lOV.Text = "$v%"
}
$Y += 18

# ==============================
#  WI-FI SECTION
# ==============================
$sepW = New-Object System.Windows.Forms.Panel
$sepW.Location = New-Object System.Drawing.Point($pad,$Y); $sepW.Size = New-Object System.Drawing.Size($CW,1); $sepW.BackColor = $sep; $sepW.Anchor = $aLTR
$form.Controls.Add($sepW)
$Y += 5

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Wi-Fi'; $l.Font = $fSect; $l.ForeColor = $grn
$l.Location = New-Object System.Drawing.Point($pad,$Y); $l.Size = New-Object System.Drawing.Size(40,14)
$form.Controls.Add($l)

$lblWStat = New-Object System.Windows.Forms.Label
$lblWStat.Font = $fSmall; $lblWStat.ForeColor = $grn
$lblWStat.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblWStat.Location = New-Object System.Drawing.Point(($pad+44),($Y+1)); $lblWStat.Size = New-Object System.Drawing.Size(55,12)
$form.Controls.Add($lblWStat)

$bWR = New-Object System.Windows.Forms.Label
$bWR.Text = $RI; $bWR.Font = $fIcon; $bWR.ForeColor = $blue
$bWR.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bWR.BackColor = $cardL; $bWR.Cursor = 'Hand'
$bWR.Location = New-Object System.Drawing.Point(($W - $pad - 54),$Y); $bWR.Size = New-Object System.Drawing.Size(24,16)
$bWR.Anchor = $aTR
$form.Controls.Add($bWR)

$lblWTime = New-Object System.Windows.Forms.Label
$lblWTime.Font = $fSmall; $lblWTime.ForeColor = $dim
$lblWTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblWTime.Location = New-Object System.Drawing.Point(($W - $pad - 26),($Y+1)); $lblWTime.Size = New-Object System.Drawing.Size(26,12)
$lblWTime.Anchor = $aTR
$form.Controls.Add($lblWTime)
$Y += 20

$wF = @('SSID','Channel','Signal','Speed','Band','Security')
$lblW = @{}
foreach ($f in $wF) {
    $lk = New-Object System.Windows.Forms.Label
    $lk.Text = $f; $lk.Font = $fLabel; $lk.ForeColor = $dim
    $lk.Location = New-Object System.Drawing.Point($pad,$Y); $lk.Size = New-Object System.Drawing.Size(55,14)
    $form.Controls.Add($lk)
    $lv = New-Object System.Windows.Forms.Label
    $lv.Text = '--'; $lv.Font = $fValue; $lv.ForeColor = $txt
    $lv.Location = New-Object System.Drawing.Point(($pad+58),$Y); $lv.Size = New-Object System.Drawing.Size(($CW - 58),14)
    $lv.Anchor = $aLTR
    $form.Controls.Add($lv)
    $lblW[$f] = $lv
    $Y += 16
}
$Y += 2

$chW = 22; $chGap = 2
$totalChW = 11 * $chW + 10 * $chGap
$chStart = [int](($W - $totalChW) / 2)
$script:lblCh = @{}; $chX = $chStart
for ($ch = 1; $ch -le 11; $ch++) {
    $cl = New-Object System.Windows.Forms.Label
    $cl.Text = [string]$ch; $cl.Font = $fCh; $cl.ForeColor = $bg
    $cl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $cl.BackColor = $dim; $cl.Size = New-Object System.Drawing.Size($chW,18)
    $cl.Location = New-Object System.Drawing.Point($chX,$Y)
    $form.Controls.Add($cl)
    $script:lblCh[$ch] = $cl
    $chX += ($chW + $chGap)
}
$Y += 24

# ==============================
#  MEDIA + PRIVACY
# ==============================
$sepM = New-Object System.Windows.Forms.Panel
$sepM.Location = New-Object System.Drawing.Point($pad,$Y); $sepM.Size = New-Object System.Drawing.Size($CW,1); $sepM.BackColor = $sep; $sepM.Anchor = $aLTR
$form.Controls.Add($sepM)
$Y += 5

$script:mediaBtns = New-Object System.Collections.ArrayList
$mbX = $pad
foreach ($mInfo in @(
    @{ T=[string][char]0x23EE; BG=$cardL; VK=0xB1 },
    @{ T=[string][char]0x23EF; BG=$blue;  VK=0xB3 },
    @{ T=[string][char]0x23ED; BG=$cardL; VK=0xB0 }
)) {
    $mb = New-Object System.Windows.Forms.Button
    $mb.Text = $mInfo.T; $mb.Font = $fMd; $mb.FlatStyle = 'Flat'; $mb.FlatAppearance.BorderSize = 0
    $mb.BackColor = $mInfo.BG; $mb.ForeColor = $txt; $mb.Cursor = 'Hand'
    $mb.Location = New-Object System.Drawing.Point($mbX,$Y); $mb.Size = New-Object System.Drawing.Size(36,25)
    $vk = $mInfo.VK
    $mb.Add_Click({ [WinAPI]::Key($vk) }.GetNewClosure())
    $form.Controls.Add($mb)
    [void]$script:mediaBtns.Add($mb)
    $mbX += 40
}

$lMicDot = New-Object System.Windows.Forms.Label
$lMicDot.Text = $DOT; $lMicDot.Font = $fDot; $lMicDot.ForeColor = $red
$lMicDot.Location = New-Object System.Drawing.Point(($pad+128),($Y+4)); $lMicDot.Size = New-Object System.Drawing.Size(14,16)
$form.Controls.Add($lMicDot)
$lMic = New-Object System.Windows.Forms.Label
$lMic.Text = 'MIC'; $lMic.Font = $fSmall; $lMic.ForeColor = $dim
$lMic.Location = New-Object System.Drawing.Point(($pad+142),($Y+7)); $lMic.Size = New-Object System.Drawing.Size(26,12)
$form.Controls.Add($lMic)

$lCamDot = New-Object System.Windows.Forms.Label
$lCamDot.Text = $DOT; $lCamDot.Font = $fDot; $lCamDot.ForeColor = $red
$lCamDot.Location = New-Object System.Drawing.Point(($pad+174),($Y+4)); $lCamDot.Size = New-Object System.Drawing.Size(14,16)
$form.Controls.Add($lCamDot)
$lCam = New-Object System.Windows.Forms.Label
$lCam.Text = 'CAM'; $lCam.Font = $fSmall; $lCam.ForeColor = $dim
$lCam.Location = New-Object System.Drawing.Point(($pad+188),($Y+7)); $lCam.Size = New-Object System.Drawing.Size(26,12)
$form.Controls.Add($lCam)
$Y += 32

# ==============================
#  SPEED TEST (non-blocking)
# ==============================
$sepS = New-Object System.Windows.Forms.Panel
$sepS.Location = New-Object System.Drawing.Point($pad,$Y); $sepS.Size = New-Object System.Drawing.Size($CW,1); $sepS.BackColor = $sep; $sepS.Anchor = $aLTR
$form.Controls.Add($sepS)
$Y += 5

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Speed Test'; $l.Font = $fSect; $l.ForeColor = $org
$l.Location = New-Object System.Drawing.Point($pad,$Y); $l.Size = New-Object System.Drawing.Size(76,14)
$form.Controls.Add($l)

$bSpRun = New-Object System.Windows.Forms.Label
$bSpRun.Text = [string][char]0x25B6; $bSpRun.Font = $fIcon; $bSpRun.ForeColor = $bg
$bSpRun.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bSpRun.BackColor = $org; $bSpRun.Cursor = 'Hand'
$bSpRun.Location = New-Object System.Drawing.Point(($pad+80),$Y); $bSpRun.Size = New-Object System.Drawing.Size(24,16)
$form.Controls.Add($bSpRun)
$Y += 20

$half = [int]($W / 2)

$lDlArr = New-Object System.Windows.Forms.Label
$lDlArr.Text = [string][char]0x2193; $lDlArr.Font = $fArr; $lDlArr.ForeColor = $grn
$lDlArr.Location = New-Object System.Drawing.Point($pad,$Y); $lDlArr.Size = New-Object System.Drawing.Size(20,22)
$form.Controls.Add($lDlArr)
$lblSpDl = New-Object System.Windows.Forms.Label
$lblSpDl.Text = '--'; $lblSpDl.Font = $fLg; $lblSpDl.ForeColor = $txt
$lblSpDl.Location = New-Object System.Drawing.Point(($pad+22),($Y-4)); $lblSpDl.Size = New-Object System.Drawing.Size(100,26)
$form.Controls.Add($lblSpDl)
$lDlU = New-Object System.Windows.Forms.Label
$lDlU.Text = 'Mbps'; $lDlU.Font = $fSmall; $lDlU.ForeColor = $dim
$lDlU.Location = New-Object System.Drawing.Point(($pad+22),($Y+20)); $lDlU.Size = New-Object System.Drawing.Size(40,12)
$form.Controls.Add($lDlU)

$lUlArr = New-Object System.Windows.Forms.Label
$lUlArr.Text = [string][char]0x2191; $lUlArr.Font = $fArr; $lUlArr.ForeColor = $blue
$lUlArr.Location = New-Object System.Drawing.Point($half,$Y); $lUlArr.Size = New-Object System.Drawing.Size(20,22)
$form.Controls.Add($lUlArr)
$lblSpUl = New-Object System.Windows.Forms.Label
$lblSpUl.Text = '--'; $lblSpUl.Font = $fLg; $lblSpUl.ForeColor = $txt
$lblSpUl.Location = New-Object System.Drawing.Point(($half+22),($Y-4)); $lblSpUl.Size = New-Object System.Drawing.Size(100,26)
$form.Controls.Add($lblSpUl)
$lUlU = New-Object System.Windows.Forms.Label
$lUlU.Text = 'Mbps'; $lUlU.Font = $fSmall; $lUlU.ForeColor = $dim
$lUlU.Location = New-Object System.Drawing.Point(($half+22),($Y+20)); $lUlU.Size = New-Object System.Drawing.Size(40,12)
$form.Controls.Add($lUlU)
$Y += 36

$lPnL = New-Object System.Windows.Forms.Label
$lPnL.Text = 'Ping'; $lPnL.Font = $fSmall; $lPnL.ForeColor = $dim
$lPnL.Location = New-Object System.Drawing.Point($pad,$Y); $lPnL.Size = New-Object System.Drawing.Size(28,12)
$form.Controls.Add($lPnL)
$lblSpPn = New-Object System.Windows.Forms.Label
$lblSpPn.Text = '--'; $lblSpPn.Font = $fSect; $lblSpPn.ForeColor = $txt
$lblSpPn.Location = New-Object System.Drawing.Point(($pad+30),$Y); $lblSpPn.Size = New-Object System.Drawing.Size(80,14)
$form.Controls.Add($lblSpPn)

$lJtL = New-Object System.Windows.Forms.Label
$lJtL.Text = 'Jitter'; $lJtL.Font = $fSmall; $lJtL.ForeColor = $dim
$lJtL.Location = New-Object System.Drawing.Point($half,$Y); $lJtL.Size = New-Object System.Drawing.Size(30,12)
$form.Controls.Add($lJtL)
$lblSpJt = New-Object System.Windows.Forms.Label
$lblSpJt.Text = '--'; $lblSpJt.Font = $fSect; $lblSpJt.ForeColor = $txt
$lblSpJt.Location = New-Object System.Drawing.Point(($half+32),$Y); $lblSpJt.Size = New-Object System.Drawing.Size(80,14)
$form.Controls.Add($lblSpJt)
$Y += 18

$lblSpSrv = New-Object System.Windows.Forms.Label
$lblSpSrv.Text = '--'; $lblSpSrv.Font = $fSmall; $lblSpSrv.ForeColor = $dim
$lblSpSrv.Location = New-Object System.Drawing.Point($pad,$Y); $lblSpSrv.Size = New-Object System.Drawing.Size($CW,12)
$lblSpSrv.Anchor = $aLTR
$form.Controls.Add($lblSpSrv)
$Y += 14

$lSpM = New-Object System.Windows.Forms.Label
$lSpM.Text = ''; $lSpM.Font = $fSmall; $lSpM.ForeColor = $dim
$lSpM.Location = New-Object System.Drawing.Point($pad,$Y); $lSpM.Size = New-Object System.Drawing.Size($CW,12)
$form.Controls.Add($lSpM)
$Y += 16

$script:spRunning = $false
$script:spProc = $null
$script:spTmpFile = $null
$script:spTimer = New-Object System.Windows.Forms.Timer
$script:spTimer.Interval = 300

$script:spTimer.Add_Tick({
    if ($script:spProc -ne $null -and $script:spProc.HasExited) {
        $script:spTimer.Stop()
        try {
            $json = Get-Content $script:spTmpFile -Raw
            Remove-Item $script:spTmpFile -Force -ErrorAction SilentlyContinue
            $r = $json | ConvertFrom-Json
            $dl = [math]::Round($r.download.bandwidth * 8 / 1000000,1)
            $ul = [math]::Round($r.upload.bandwidth * 8 / 1000000,1)
            $pi = [math]::Round($r.ping.latency,1)
            $ji = [math]::Round($r.ping.jitter,2)
            $lblSpDl.Text = [string]$dl; $lblSpUl.Text = [string]$ul
            $lblSpPn.Text = "$pi ms"; $lblSpJt.Text = "$ji ms"
            $lblSpSrv.Text = "$($r.server.name), $($r.server.location)"
            if ($dl -ge 45) { $lblSpDl.ForeColor = $grn } elseif ($dl -ge 25) { $lblSpDl.ForeColor = $org } else { $lblSpDl.ForeColor = $red }
            if ($pi -le 10) { $lblSpPn.ForeColor = $grn } elseif ($pi -le 30) { $lblSpPn.ForeColor = $org } else { $lblSpPn.ForeColor = $red }
            $lSpM.Text = "Done $(Get-Date -Format 'HH:mm:ss')"; $lSpM.ForeColor = $grn
        } catch {
            $lSpM.Text = 'Parse error'; $lSpM.ForeColor = $red
        }
        $script:spRunning = $false; $bSpRun.Text = [string][char]0x25B6; $script:spProc = $null
    }
})

$bSpRun.Add_Click({
    if ($script:spRunning) { return }
    if (-not (Test-Path $speedtestExe)) { $lSpM.Text = 'CLI not found'; $lSpM.ForeColor = $red; return }
    $script:spRunning = $true; $bSpRun.Text = '...'
    $lSpM.Text = 'Running...'; $lSpM.ForeColor = $org
    $script:spTmpFile = [System.IO.Path]::GetTempFileName()
    try {
        $script:spProc = Start-Process -FilePath $speedtestExe -ArgumentList '--accept-license','--accept-gdpr','--format=json' -RedirectStandardOutput $script:spTmpFile -NoNewWindow -PassThru
        $script:spTimer.Start()
    } catch {
        $lSpM.Text = 'Start error'; $lSpM.ForeColor = $red
        $script:spRunning = $false; $bSpRun.Text = [string][char]0x25B6
    }
})

# ==============================
#  DEVICES (non-blocking scan)
# ==============================
$sepD = New-Object System.Windows.Forms.Panel
$sepD.Location = New-Object System.Drawing.Point($pad,$Y); $sepD.Size = New-Object System.Drawing.Size($CW,1); $sepD.BackColor = $sep; $sepD.Anchor = $aLTR
$form.Controls.Add($sepD)
$Y += 5

$l = New-Object System.Windows.Forms.Label
$l.Text = 'Devices'; $l.Font = $fSect; $l.ForeColor = $blue
$l.Location = New-Object System.Drawing.Point($pad,$Y); $l.Size = New-Object System.Drawing.Size(56,14)
$form.Controls.Add($l)

$bDR = New-Object System.Windows.Forms.Label
$bDR.Text = "$RI Scan"; $bDR.Font = $fSmall; $bDR.ForeColor = $blue
$bDR.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$bDR.BackColor = $cardL; $bDR.Cursor = 'Hand'
$bDR.Location = New-Object System.Drawing.Point(($pad+60),$Y); $bDR.Size = New-Object System.Drawing.Size(46,16)
$form.Controls.Add($bDR)

$lDC = New-Object System.Windows.Forms.Label
$lDC.Text = "Tap $RI to scan"; $lDC.Font = $fSmall; $lDC.ForeColor = $dim
$lDC.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$lDC.Location = New-Object System.Drawing.Point(($W-$pad-120),($Y+1)); $lDC.Size = New-Object System.Drawing.Size(120,12)
$lDC.Anchor = $aTR
$form.Controls.Add($lDC)
$Y += 20

$lsD = New-Object System.Windows.Forms.ListView
$lsD.Location = New-Object System.Drawing.Point($pad,$Y); $lsD.Size = New-Object System.Drawing.Size($CW,78)
$lsD.View = 'Details'; $lsD.FullRowSelect = $true; $lsD.BackColor = $bg; $lsD.ForeColor = $txt; $lsD.Font = $fSmall
$lsD.GridLines = $false; $lsD.BorderStyle = 'None'; $lsD.HeaderStyle = 'Nonclickable'; $lsD.Scrollable = $false
$lsD.Anchor = $aLTRB
[void]$lsD.Columns.Add('',20); [void]$lsD.Columns.Add('IP',70); [void]$lsD.Columns.Add('MAC',96); [void]$lsD.Columns.Add('Name',80)
$form.Controls.Add($lsD)
$Y += 82

$lAlert = New-Object System.Windows.Forms.Label
$lAlert.Text = ''; $lAlert.Font = $fSmall; $lAlert.ForeColor = $dim
$lAlert.Location = New-Object System.Drawing.Point($pad,$Y); $lAlert.Size = New-Object System.Drawing.Size($CW,12)
$lAlert.Anchor = $aLB
$form.Controls.Add($lAlert)
$Y += 16

$ctx = New-Object System.Windows.Forms.ContextMenuStrip
$mT = New-Object System.Windows.Forms.ToolStripMenuItem('Trust')
$mT.Add_Click({
    if ($lsD.SelectedItems.Count -gt 0) {
        $sel = $lsD.SelectedItems[0]
        $sMac = [string]$sel.SubItems[2].Text; $sIp = [string]$sel.SubItems[1].Text
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = 'Name'; $dlg.Size = New-Object System.Drawing.Size(260,100)
        $dlg.StartPosition = 'CenterParent'; $dlg.BackColor = $bg; $dlg.ForeColor = $txt; $dlg.TopMost = $true
        $tbox = New-Object System.Windows.Forms.TextBox
        $tbox.Location = New-Object System.Drawing.Point(8,10); $tbox.Size = New-Object System.Drawing.Size(230,22); $tbox.Text = "Device $sIp"
        $dlg.Controls.Add($tbox)
        $okBtn = New-Object System.Windows.Forms.Button
        $okBtn.Text = 'OK'; $okBtn.Font = $fLabel; $okBtn.FlatStyle = 'Flat'; $okBtn.FlatAppearance.BorderSize = 0
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

$script:scanRunning = $false
$script:scanRS = $null
$script:scanPS = $null
$script:scanHandle = $null
$script:scanTimer = New-Object System.Windows.Forms.Timer
$script:scanTimer.Interval = 500

$script:scanTimer.Add_Tick({
    if ($script:scanHandle -ne $null -and $script:scanHandle.IsCompleted) {
        $script:scanTimer.Stop()
        try {
            $devs = @($script:scanPS.EndInvoke($script:scanHandle))
            $tr = @(Get-TrustedDevices); $tMacs = @($tr | ForEach-Object { [string]$_.mac })
            $lsD.Items.Clear(); $unk = 0
            foreach ($dev in $devs) {
                $dIp = [string]$dev.IP; $dMac = [string]$dev.MAC
                $ok = $dMac -in $tMacs
                $info = $tr | Where-Object { $_.mac -eq $dMac }
                $nm = if ($info) { [string]$info.name } else { '?' }
                if (-not $ok) { $unk++ }
                $item = New-Object System.Windows.Forms.ListViewItem
                if ($ok) { $item.Text = $DOT; $item.ForeColor = $grn }
                else { $item.Text = $DOT; $item.ForeColor = $red }
                $item.BackColor = $bg
                [void]$item.SubItems.Add($dIp); [void]$item.SubItems.Add($dMac); [void]$item.SubItems.Add($nm)
                [void]$lsD.Items.Add($item)
            }
            $lDC.Text = "$($devs.Count) total, $unk unknown"
            if ($unk -gt 0) { $lAlert.Text = "$unk unknown device(s)"; $lAlert.ForeColor = $red }
            else { $lAlert.Text = 'All trusted'; $lAlert.ForeColor = $grn }
        } catch {
            $lDC.Text = 'Scan error'; $lAlert.Text = ''
        }
        try { $script:scanPS.Dispose() } catch {}
        try { $script:scanRS.Close(); $script:scanRS.Dispose() } catch {}
        $script:scanRunning = $false; $bDR.ForeColor = $blue
    }
})

$bDR.Add_Click({
    if ($script:scanRunning) { return }
    $script:scanRunning = $true
    $bDR.ForeColor = $txt; $lDC.Text = 'Scanning...'
    $script:scanRS = [runspacefactory]::CreateRunspace()
    $script:scanRS.Open()
    $script:scanPS = [powershell]::Create()
    $script:scanPS.Runspace = $script:scanRS
    [void]$script:scanPS.AddScript({
        $subnet = '192.168.0'
        $jobs = 1..254 | ForEach-Object { (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("$subnet.$_",120) }
        try { [System.Threading.Tasks.Task]::WaitAll($jobs) } catch {}
        $arp = arp -a | Where-Object { $_ -match '^\s+(\d+\.\d+\.\d+\.\d+)\s+([\w-]+)' }
        $devs = @()
        foreach ($line in $arp) {
            if ($line -match '^\s+(\d+\.\d+\.\d+\.\d+)\s+([\w-]+)') {
                $ip = $Matches[1]; $mac = $Matches[2]
                if ($mac -ne 'ff-ff-ff-ff-ff-ff' -and $ip.StartsWith($subnet)) {
                    $devs += [PSCustomObject]@{IP=$ip;MAC=$mac;Name='?'}
                }
            }
        }
        return $devs
    })
    $script:scanHandle = $script:scanPS.BeginInvoke()
    $script:scanTimer.Start()
})

# ==============================
#  UPDATE WI-FI
# ==============================
function Update-Wifi {
    $bWR.ForeColor = $txt
    $w = Get-WifiInfo
    $lblW['SSID'].Text = if ($w['SSID']) { [string]$w['SSID'] } else { 'N/A' }
    $myCh = $w['Channel']
    $lblW['Channel'].Text = if ($myCh) { [string]$myCh } else { '--' }
    $sig = $w['Signal']
    $lblW['Signal'].Text = if ($sig) { [string]$sig } else { '--' }
    $lblW['Speed'].Text  = if ($w['Receive rate (Mbps)']) { "$($w['Receive rate (Mbps)']) Mbps" } else { '--' }
    $lblW['Band'].Text   = if ($w['Radio type']) { [string]$w['Radio type'] } else { '--' }
    $lblW['Security'].Text = if ($w['Authentication']) { [string]$w['Authentication'] } else { '--' }
    if ($w['State'] -eq 'connected') { $lblWStat.Text='Connected'; $lblWStat.ForeColor=$grn } else { $lblWStat.Text='No Wi-Fi'; $lblWStat.ForeColor=$red }
    $lblWTime.Text = (Get-Date).ToString('HH:mm')
    $cm = Get-ChannelMap
    $myChInt = 0; try { $myChInt = [int]$myCh } catch {}
    foreach ($c in 1..11) {
        $n = $cm[$c]; $lbl = $script:lblCh[$c]
        if ($c -eq $myChInt -and $n -gt 0) { $n-- }
        if ($n -eq 0) { $lbl.BackColor = $grn; $lbl.ForeColor = $bg }
        elseif ($n -le 2) { $lbl.BackColor = $org; $lbl.ForeColor = $bg }
        else { $lbl.BackColor = $red; $lbl.ForeColor = $txt }
        if ($c -eq $myChInt) { $lbl.ForeColor = $txt; $lbl.Font = New-Object System.Drawing.Font('Segoe UI',7,[System.Drawing.FontStyle]::Bold) }
        else { $lbl.Font = $fCh }
    }
    $bWR.ForeColor = $blue
}
$bWR.Add_Click({ Update-Wifi })

# ==============================
#  FINAL SIZE + CORNERS + TIMER
# ==============================
$form.Size = New-Object System.Drawing.Size($W,$Y)
$form.Add_Shown({
    [void][WinAPI]::SetWindowRgn($form.Handle,[WinAPI]::CreateRoundRectRgn(0,0,($form.Width+1),($form.Height+1),14,14),$true)
    [void][WinAPI]::SetWindowRgn($btnClose.Handle,[WinAPI]::CreateRoundRectRgn(0,0,11,11,10,10),$true)
    [void][WinAPI]::SetWindowRgn($btnMin.Handle,[WinAPI]::CreateRoundRectRgn(0,0,11,11,10,10),$true)
    [void][WinAPI]::SetWindowRgn($btnExp.Handle,[WinAPI]::CreateRoundRectRgn(0,0,11,11,10,10),$true)
    [void][WinAPI]::SetWindowRgn($bWR.Handle,[WinAPI]::CreateRoundRectRgn(0,0,25,17,6,6),$true)
    [void][WinAPI]::SetWindowRgn($bSpRun.Handle,[WinAPI]::CreateRoundRectRgn(0,0,25,17,6,6),$true)
    [void][WinAPI]::SetWindowRgn($bDR.Handle,[WinAPI]::CreateRoundRectRgn(0,0,47,17,6,6),$true)
    foreach ($mb in $script:mediaBtns) {
        [void][WinAPI]::SetWindowRgn($mb.Handle,[WinAPI]::CreateRoundRectRgn(0,0,37,26,20,20),$true)
    }
    foreach ($cl in $script:lblCh.Values) {
        [void][WinAPI]::SetWindowRgn($cl.Handle,[WinAPI]::CreateRoundRectRgn(0,0,($cl.Width+1),($cl.Height+1),4,4),$true)
    }
})

$tmr = New-Object System.Windows.Forms.Timer
$tmr.Interval = 5000
$tmr.Add_Tick({
    if (Test-DeviceInUse 'microphone') { $lMicDot.ForeColor = $grn } else { $lMicDot.ForeColor = $red }
    if (Test-DeviceInUse 'webcam') { $lCamDot.ForeColor = $grn } else { $lCamDot.ForeColor = $red }
    if (-not $slVol.Dragging) {
        $v = [AudioManager]::GetVolume()
        if ($v -ge 0) {
            $lVV.Text = [string]$v
            $slVol.SetValueFromSystem($v)
        }
    }
    if (-not $slBri.Dragging) {
        $b = Get-Brightness
        if ($b -ge 0) {
            $lBV.Text = [string]$b
            $slBri.SetValueFromSystem($b)
        }
    }
})
$tmr.Start()

Update-Wifi

[System.Windows.Forms.Application]::Run($form)
