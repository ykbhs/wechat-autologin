<#
.SYNOPSIS
    安装微信开机自动登录。

.DESCRIPTION
    把 wechat-autologin.ps1 复制到 %LOCALAPPDATA%\WeChatAutoLogin，
    并在当前用户的启动文件夹创建快捷方式（以隐藏窗口方式调用脚本）。
    不需要管理员权限。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
#>

$ErrorActionPreference = 'Stop'

$srcScript = Join-Path $PSScriptRoot 'wechat-autologin.ps1'
if (-not (Test-Path $srcScript)) {
    throw "找不到 wechat-autologin.ps1，请确保它与 install.ps1 在同一目录。"
}

$targetDir = Join-Path $env:LOCALAPPDATA 'WeChatAutoLogin'
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
$targetScript = Join-Path $targetDir 'wechat-autologin.ps1'
Copy-Item $srcScript $targetScript -Force

$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$startupDir = [Environment]::GetFolderPath('Startup')
$lnkPath = Join-Path $startupDir '微信.lnk'

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath = $powershellExe
$lnk.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $targetScript + '"'
$lnk.WorkingDirectory = $targetDir
$lnk.IconLocation = 'C:\Program Files\Tencent\Weixin\Weixin.exe,0'
$lnk.Description = '开机自动打开微信并登录'
$lnk.WindowStyle = 7
$lnk.Save()

Write-Host '安装完成' -ForegroundColor Green
Write-Host ("  脚本   : " + $targetScript)
Write-Host ("  启动项 : " + $lnkPath)
Write-Host ''
Write-Host '下次登录 Windows 后自动生效。也可以现在运行一次验证：' -ForegroundColor Yellow
Write-Host ('  powershell -NoProfile -ExecutionPolicy Bypass -File "' + $targetScript + '"')
