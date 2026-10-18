# 开机自动打开微信并完成登录
# 原理：启动微信 -> 等登录窗口（UIA 类名 mmui::LoginWindow）出现
#       -> 找到"进入微信"按钮的屏幕坐标 -> 窗口置顶 -> 真实鼠标点击
# 不依赖键盘焦点，所以开机时被其他启动项抢占前台也能点中。
# 日志：%LOCALAPPDATA%\WeChatAutoLogin\log.txt

$ErrorActionPreference = 'SilentlyContinue'
$logDir = Join-Path $env:LOCALAPPDATA 'WeChatAutoLogin'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'log.txt'
try { if ((Get-Item $logFile).Length -gt 200000) { Remove-Item $logFile -Force } } catch { }

function Write-Log {
    param([string]$Message)
    try { Add-Content -Path $logFile -Value ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + $Message) -Encoding UTF8 } catch { }
}

Write-Log ("--- start (pid " + $PID + ") ---")

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

Add-Type @"
using System;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class WxClick {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public static long FindWeChatWindow(string pidCsv) {
        long found = 0;
        EnumWindows((h, l) => {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            if (!("," + pidCsv + ",").Contains("," + pid + ",")) return true;
            if (!IsWindowVisible(h)) return true;
            var t = new StringBuilder(256);
            GetWindowText(h, t, 256);
            if (t.ToString() == "微信") { found = h.ToInt64(); return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);   // left down
        Thread.Sleep(100);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);   // left up
    }

    public static void SetTopmost(long hWnd, bool topmost) {
        SetWindowPos(new IntPtr(hWnd), topmost ? new IntPtr(-1) : new IntPtr(-2), 0, 0, 0, 0, 0x0003);
    }
}
"@

$wechatExe = 'C:\Program Files\Tencent\Weixin\Weixin.exe'
$AE = [System.Windows.Automation.AutomationElement]

if (-not (Get-Process Weixin -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $wechatExe | Out-Null
    Write-Log 'wechat not running, started it'
}

$loginClass = 'mmui::LoginWindow'
$deadline = (Get-Date).AddSeconds(150)
$clicked = $false

while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $pids = @(Get-Process Weixin -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    if ($pids.Count -eq 0) { Write-Log 'wechat process gone'; break }

    $all = @()
    foreach ($p in $pids) {
        $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, [int]$p)
        $all += @($AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond))
    }
    if ($all.Count -eq 0) { continue }

    # 已登录：出现宽窗口且没有登录窗口
    $loginWin = $all | Where-Object { $_.Current.ClassName -eq $loginClass } | Select-Object -First 1
    $wide = $all | Where-Object { $_.Current.BoundingRectangle.Width -gt 800 } | Select-Object -First 1
    if (-not $loginWin -and $wide) { Write-Log 'already logged in, nothing to do'; return }

    if ($loginWin) {
        $btnCond = New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)),
            (New-Object System.Windows.Automation.PropertyCondition($AE::NameProperty, '进入微信')))
        $btn = $null
        # 登录框可能是"扫码"或"头像"两种状态，等按钮出现
        for ($t = 0; $t -lt 15 -and -not $btn; $t++) {
            $btn = $loginWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
            if (-not $btn) { Start-Sleep -Seconds 1 }
        }
        if (-not $btn) {
            Write-Log 'login window without enter-button (maybe QR state), give up'
            return
        }
        $r = $btn.Current.BoundingRectangle
        $x = [int]($r.X + $r.Width / 2)
        $y = [int]($r.Y + $r.Height / 2)
        $hwnd = [WxClick]::FindWeChatWindow(($pids -join ','))
        Write-Log ("clicking 进入微信 at " + $x + "," + $y + " hwnd=" + $hwnd)
        if ($hwnd -ne 0) {
            [WxClick]::SetTopmost($hwnd, $true)
            Start-Sleep -Milliseconds 800
        }
        [WxClick]::Click($x, $y)
        Start-Sleep -Seconds 2
        if ($hwnd -ne 0) { [WxClick]::SetTopmost($hwnd, $false) }
        $clicked = $true
        break
    }
}

if (-not $clicked) { Write-Log 'no login window detected within timeout'; return }

# 等主窗口出现
$ok = $false
$sub = (Get-Date).AddSeconds(25)
while ((Get-Date) -lt $sub) {
    Start-Sleep -Seconds 2
    $pids = @(Get-Process Weixin -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    if ($pids.Count -eq 0) { break }
    $all = @()
    foreach ($p in $pids) {
        $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, [int]$p)
        $all += @($AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond))
    }
    if (($all | Where-Object { $_.Current.ClassName -eq $loginClass }).Count -eq 0) { $ok = $true; break }
}
if ($ok) { Write-Log 'login completed' } else { Write-Log 'login did not complete (phone confirm or QR needed)' }
