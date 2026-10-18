<#
.SYNOPSIS
    卸载微信开机自动登录。

.DESCRIPTION
    删除启动文件夹中的 微信.lnk，以及 %LOCALAPPDATA%\WeChatAutoLogin 目录。
    不需要管理员权限。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'

$lnkPath = Join-Path ([Environment]::GetFolderPath('Startup')) '微信.lnk'
if (Test-Path $lnkPath) {
    Remove-Item $lnkPath -Force
    Write-Host ("已删除启动项: " + $lnkPath) -ForegroundColor Green
} else {
    Write-Host '启动项不存在，跳过。'
}

$targetDir = Join-Path $env:LOCALAPPDATA 'WeChatAutoLogin'
if (Test-Path $targetDir) {
    Remove-Item $targetDir -Recurse -Force
    Write-Host ("已删除目录: " + $targetDir) -ForegroundColor Green
} else {
    Write-Host '目录不存在，跳过。'
}

Write-Host '卸载完成。'
