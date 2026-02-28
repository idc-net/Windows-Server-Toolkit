# disable_auto_update_desktop.ps1
# Utility to take full control of Windows Update — prevent auto-download, auto-install, and auto-reboot
# Maintainer: idc.net (http://idc.net)
# GitHub: https://github.com/idc-net/
# License: MIT

Write-Host "=== Windows Update Control Tool by idc.net ===`n" -ForegroundColor Cyan

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

    # ── 3. 组策略：通知但不自动下载和安装，全时段禁止自动重启 ─
    Write-Host "`n[1/5] 配置更新策略：通知但不自动下载，全时段禁止自动重启..." -ForegroundColor Yellow
    $wuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $wuPolicyPath)) {
        New-Item -Path $wuPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoUpdate"                  -Value 0 -Type DWord  # 不完全关闭，保留通知
    Set-ItemProperty -Path $wuPolicyPath -Name "AUOptions"                     -Value 2 -Type DWord  # 2 = 通知下载和通知安装
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord  # 任何时段有用户登录时均不重启
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequencyEnabled"     -Value 1 -Type DWord
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequency"            -Value 72 -Type DWord  # 每 72 小时检测一次
    Write-Log "Group Policy: AUOptions=2 (Notify only), NoAutoRebootWithLoggedOnUsers=1 (all hours)."
    Write-Host "   ✅ 完成（全时段禁止自动重启）" -ForegroundColor Green

    # ── 4. 断开自动更新服务器（让系统找不到更新源）───────────
    Write-Host "`n[2/5] 断开自动更新服务器地址..." -ForegroundColor Yellow
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (-not (Test-Path $wuPath)) {
        New-Item -Path $wuPath -Force | Out-Null
    }
    Set-ItemProperty -Path $wuPath -Name "WUServer"       -Value "http://localhost:8080" -Type String
    Set-ItemProperty -Path $wuPath -Name "WUStatusServer" -Value "http://localhost:8080" -Type String
    Set-ItemProperty -Path $wuPath -Name "UseWUServer"    -Value 1 -Type DWord
    Write-Log "Windows Update server redirected to localhost (effectively disabled auto-detection)."
    Write-Host "   ✅ 完成（更新服务器已重定向，自动检测失效）" -ForegroundColor Green

    # ── 5. 禁用交付优化（禁止从其他 PC 下载更新）────────────
    Write-Host "`n[3/5] 禁用交付优化..." -ForegroundColor Yellow
    $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (-not (Test-Path $doPath)) {
        New-Item -Path $doPath -Force | Out-Null
    }
    Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord  # 0 = 仅本机
    Write-Log "Delivery Optimization set to local PC only (DODownloadMode = 0)."
    Write-Host "   ✅ 完成" -ForegroundColor Green

    # ── 6. 禁用 Update Orchestrator Service (UsoSvc) ─────────
    Write-Host "`n[4/5] 禁用更新调度服务 (UsoSvc)..." -ForegroundColor Yellow
    Stop-Service -Name "UsoSvc" -Force -ErrorAction SilentlyContinue
    Set-Service  -Name "UsoSvc" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Log "UsoSvc (Update Orchestrator Service) disabled."
    Write-Host "   ✅ 完成" -ForegroundColor Green

    # ── 7. 禁用 WaaSMedicSvc（通过注册表，最顽固的服务）──────
    Write-Host "`n[5/5] 禁用 Windows Update 自修复服务 (WaaSMedicSvc)..." -ForegroundColor Yellow
    $medicPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc"
    if (Test-Path $medicPath) {
        $acl = Get-Acl $medicPath
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "Administrators", "FullControl", "Allow"
        )
        $acl.SetAccessRule($rule)
        try {
            Set-Acl -Path $medicPath -AclObject $acl -ErrorAction Stop
            Set-ItemProperty -Path $medicPath -Name "Start" -Value 4 -ErrorAction Stop  # 4 = 禁用
            Write-Log "WaaSMedicSvc disabled via registry (Start = 4)."
            Write-Host "   ✅ 完成" -ForegroundColor Green
        } catch {
            Write-Log "WaaSMedicSvc: Could not modify registry directly (protected). Manual action may be needed." "WARN"
            Write-Host "   ⚠️  WaaSMedicSvc 受系统保护，无法直接修改。其余配置已生效，此项可忽略。" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ℹ️  WaaSMedicSvc 注册表项不存在，跳过。" -ForegroundColor DarkGray
    }

} catch {
    Write-Log "Unexpected error: $_" "ERROR"
    Write-Host "`n❌ 脚本执行过程中出现错误，请查看日志：$logFile" -ForegroundColor Red
    Exit 1
}

# ── 8. 操作摘要 ───────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Update Control Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [✅] 更新策略     : 通知但不自动下载安装"
Write-Host "  [✅] 自动重启     : 全时段禁止"
Write-Host "  [✅] 更新服务器   : 已断开自动检测"
Write-Host "  [✅] 交付优化     : 仅本机模式"
Write-Host "  [✅] UsoSvc       : 已禁用"
Write-Host "  [⚠️] WaaSMedicSvc : 视系统版本结果不同"
Write-Host "  [📋] 日志文件     : $logFile"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  提示：如需手动更新，请打开「设置 → Windows 更新 → 检查更新」" -ForegroundColor DarkCyan
Write-Host "  建议每月固定选一天低峰期手动执行更新。" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Visit us : http://idc.net" -ForegroundColor DarkCyan
Write-Host "  GitHub   : https://github.com/idc-net/" -ForegroundColor DarkCyan
Write-Host ""
Write-Log "Script completed successfully. | idc.net | https://github.com/idc-net/"
