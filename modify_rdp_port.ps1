# modify_rdp_port.ps1
# Utility to update the RDP listening port with safety checks and rollback support
# Maintainer: idc.net (http://idc.net)
# GitHub: https://github.com/idc-net/
# License: MIT

Write-Host "=== RDP Port Configuration Tool by idc.net ===`n"

# ── 1. 权限检查 ──────────────────────────────────────────────
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Elevated privileges required. Please relaunch as Administrator."
    Exit
}

# ── 2. 日志函数 ──────────────────────────────────────────────
$logFile = "$env:SystemRoot\Logs\rdp_port_change.log"
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

# ── 3. 读取当前端口（用于回滚）───────────────────────────────
$rdpRegPath    = "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
$rdpEnablePath = "HKLM:\System\CurrentControlSet\Control\Terminal Server"

$oldPort = (Get-ItemProperty -Path $rdpRegPath -Name "PortNumber").PortNumber
Write-Log "Current RDP port: $oldPort"

# ── 4. 输入新端口 ─────────────────────────────────────────────
do {
    $portInput = Read-Host "Specify the new RDP port number (valid range: 1025 - 65535, current: $oldPort)"
} while (-not ($portInput -match '^\d+$' -and [int]$portInput -ge 1025 -and [int]$portInput -le 65535))

$newPort = [int]$portInput

if ($newPort -eq $oldPort) {
    Write-Log "New port is the same as current port ($oldPort). No changes made." "WARN"
    Exit
}

# ── 5. 检测端口占用 ───────────────────────────────────────────
$portInUse = Get-NetTCPConnection -LocalPort $newPort -ErrorAction SilentlyContinue
if ($portInUse) {
    $occupyingProcess = (Get-Process -Id $portInUse.OwningProcess -ErrorAction SilentlyContinue).Name
    Write-Log "Port $newPort is already in use by process: $occupyingProcess (PID: $($portInUse.OwningProcess))" "ERROR"
    Exit
}

# ── 6. 核心操作（带回滚）─────────────────────────────────────
try {
    # 6-1. 修改注册表端口
    Set-ItemProperty -Path $rdpRegPath -Name "PortNumber" -Value $newPort -ErrorAction Stop
    Write-Log "Registry updated: RDP port set to $newPort"

    # 6-2. 启用 RDP（如果被禁用）
    $rdpStatus = (Get-ItemProperty -Path $rdpEnablePath -Name "fDenyTSConnections").fDenyTSConnections
    if ($rdpStatus -ne 0) {
        Set-ItemProperty -Path $rdpEnablePath -Name "fDenyTSConnections" -Value 0 -ErrorAction Stop
        Write-Log "Remote Desktop has been activated."
    }

    # 6-3. 启用 NLA（网络级别身份验证）
    Set-ItemProperty -Path $rdpRegPath -Name "UserAuthentication" -Value 1 -ErrorAction Stop
    Write-Log "NLA (Network Level Authentication) enforced."

    # 6-4. 移除旧端口防火墙规则（仅移除本脚本创建的规则）
    $oldRules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "RDP Access - Port *" }
    if ($oldRules) {
        $oldRules | Remove-NetFirewallRule
        Write-Log "Old RDP firewall rule(s) removed."
    }

    # 6-5. 添加新防火墙规则
    New-NetFirewallRule `
        -DisplayName "RDP Access - Port $newPort" `
        -Direction Inbound `
        -LocalPort $newPort `
        -Protocol TCP `
        -Action Allow `
        -Profile Any `
        -ErrorAction Stop | Out-Null
    Write-Log "Inbound firewall rule created for port $newPort."

    # 6-6. 重启 RDP 服务
    Restart-Service -Name TermService -Force -ErrorAction Stop
    Write-Log "Remote Desktop Services restarted successfully."

} catch {
    # ── 回滚 ──
    Write-Log "ERROR encountered: $_" "ERROR"
    Write-Log "Rolling back to previous port: $oldPort" "WARN"

    Set-ItemProperty -Path $rdpRegPath -Name "PortNumber" -Value $oldPort
    Restart-Service -Name TermService -Force -ErrorAction SilentlyContinue

    Write-Log "Rollback completed. RDP port restored to $oldPort." "WARN"
    Exit 1
}

# ── 7. 操作摘要 ───────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RDP Configuration Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Previous Port : $oldPort"
Write-Host "  New Port      : $newPort"
Write-Host "  NLA Enforced  : Yes"
Write-Host "  Log File      : $logFile"
Write-Host "  More Tools    : https://github.com/idc-net/"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Log "Script completed successfully. | idc.net | https://github.com/idc-net/"

# ── 8. 安全提示 ───────────────────────────────────────────────
Write-Host "Reminder: Keep an alternative access method available" -ForegroundColor Yellow
Write-Host "          (e.g., console, VNC, or IPMI) in case of connectivity issues." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Visit us : http://idc.net" -ForegroundColor DarkCyan
Write-Host "  GitHub   : https://github.com/idc-net/" -ForegroundColor DarkCyan
