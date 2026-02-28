# disable_auto_update_web.ps1
# Utility to control Windows Update for Web/App Servers
# Auto-download security patches but never auto-install or auto-reboot
# Maintainer: idc.net (http://idc.net)
# GitHub: https://github.com/idc-net/
# License: MIT

Write-Host "=== Windows Update Control Tool (Web Server) by idc.net ===`n" -ForegroundColor Cyan

# ── 1. 权限检查 ──────────────────────────────────────────────
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Elevated privileges required. Please relaunch as Administrator."
    Exit
}

# ── 2. 日志函数 ──────────────────────────────────────────────
$logFile = "$env:SystemRoot\Logs\windows_update_control.log"
if (-not (Test-Path (Split-Path $logFile))) {
    New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
}
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp][$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    switch ($Level) {
        "WARN"  { Write-Warning $Message }
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message }
    }
}

Write-Log "Script started by user: $env:USERNAME"

try {

    # ── 3. 组策略：自动下载补丁，通知安装，全时段禁止自动重启 ─
    Write-Host "`n[1/3] 配置更新策略：自动下载，通知安装，禁止自动重启..." -ForegroundColor Yellow
    $wuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $wuPolicyPath)) {
        New-Item -Path $wuPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoUpdate"                  -Value 0 -Type DWord  # 保持更新服务开启
    Set-ItemProperty -Path $wuPolicyPath -Name "AUOptions"                     -Value 3 -Type DWord  # 3 = 自动下载，通知安装
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord  # 全时段禁止自动重启
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequencyEnabled"     -Value 1 -Type DWord
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequency"            -Value 24 -Type DWord  # 每 24 小时检测一次（及时获取安全补丁）
    Write-Log "Group Policy: AUOptions=3 (Auto-download, notify install), NoAutoRebootWithLoggedOnUsers=1."
    Write-Host "   ✅ 完成（补丁自动下载，安装由你决定，全时段禁止自动重启）" -ForegroundColor Green

    # ── 4. 禁用交付优化（禁止从其他 PC 下载更新）────────────
    Write-Host "`n[2/3] 禁用交付优化..." -ForegroundColor Yellow
    $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (-not (Test-Path $doPath)) {
        New-Item -Path $doPath -Force | Out-Null
    }
    Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord  # 0 = 仅本机
    Write-Log "Delivery Optimization set to local PC only (DODownloadMode = 0)."
    Write-Host "   ✅ 完成" -ForegroundColor Green

    # ── 5. 确保 UsoSvc 正常运行（网站服务器需要保留调度服务）─
    Write-Host "`n[3/3] 确保更新调度服务 (UsoSvc) 正常运行..." -ForegroundColor Yellow
    Set-Service -Name "UsoSvc" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "UsoSvc" -ErrorAction SilentlyContinue
    Write-Log "UsoSvc (Update Orchestrator Service) set to Automatic."
    Write-Host "   ✅ 完成（保留调度服务以确保安全补丁正常推送）" -ForegroundColor Green

} catch {
    Write-Log "Unexpected error: $_" "ERROR"
    Write-Host "`n❌ 脚本执行过程中出现错误，请查看日志：$logFile" -ForegroundColor Red
    Exit 1
}

# ── 6. 操作摘要 ───────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Update Control Summary" -ForegroundColor Cyan
Write-Host "  Mode: Web / App Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [✅] 更新策略     : 自动下载，通知安装"
Write-Host "  [✅] 自动重启     : 全时段禁止"
Write-Host "  [✅] 检测频率     : 每 24 小时"
Write-Host "  [✅] 交付优化     : 仅本机模式"
Write-Host "  [✅] UsoSvc       : 保持运行（确保安全补丁推送）"
Write-Host "  [📋] 日志文件     : $logFile"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  提示：补丁下载完成后系统会弹窗通知，请选择低峰期手动安装。" -ForegroundColor DarkCyan
Write-Host "  建议每月至少安装一次安全更新，避免漏洞暴露风险。" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Visit us : http://idc.net" -ForegroundColor DarkCyan
Write-Host "  GitHub   : https://github.com/idc-net/" -ForegroundColor DarkCyan
Write-Host ""
Write-Log "Script completed successfully. | idc.net | https://github.com/idc-net/"
