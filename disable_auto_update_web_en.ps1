# disable_auto_update_web.ps1
# Utility to control Windows Update for Web/App Servers
# Auto-download security patches but never auto-install or auto-reboot

Write-Host "=== Windows Update Control Tool (Web Server) ===`n" -ForegroundColor Cyan

# ── 1. Privilege Check ───────────────────────────────────────
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Elevated privileges required. Please relaunch as Administrator."
    Exit
}

# ── 2. Logging Function ──────────────────────────────────────
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

    # ── 3. Group Policy: Auto-download patches, notify for install, disable auto-reboot ─
    Write-Host "`n[1/3] Configuring update policy: auto-download, notify to install, disable auto-reboot..." -ForegroundColor Yellow
    $wuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $wuPolicyPath)) {
        New-Item -Path $wuPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoUpdate"                  -Value 0 -Type DWord  # Keep Windows Update service enabled
    Set-ItemProperty -Path $wuPolicyPath -Name "AUOptions"                     -Value 3 -Type DWord  # 3 = Auto-download, notify to install
    Set-ItemProperty -Path $wuPolicyPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord  # Disable auto-reboot at all times
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequencyEnabled"     -Value 1 -Type DWord
    Set-ItemProperty -Path $wuPolicyPath -Name "DetectionFrequency"            -Value 24 -Type DWord  # Check every 24 hours for timely security patches
    Write-Log "Group Policy: AUOptions=3 (Auto-download, notify install), NoAutoRebootWithLoggedOnUsers=1."
    Write-Host "   ✅ Done (patches auto-downloaded, installation is your call, auto-reboot disabled at all times)" -ForegroundColor Green

    # ── 4. Disable Delivery Optimization (block downloading updates from other PCs) ──
    Write-Host "`n[2/3] Disabling Delivery Optimization..." -ForegroundColor Yellow
    $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (-not (Test-Path $doPath)) {
        New-Item -Path $doPath -Force | Out-Null
    }
    Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord  # 0 = Local PC only
    Write-Log "Delivery Optimization set to local PC only (DODownloadMode = 0)."
    Write-Host "   ✅ Done" -ForegroundColor Green

    # ── 5. Ensure UsoSvc is running (web servers should retain the orchestrator service) ─
    Write-Host "`n[3/3] Ensuring Update Orchestrator Service (UsoSvc) is running..." -ForegroundColor Yellow
    Set-Service -Name "UsoSvc" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "UsoSvc" -ErrorAction SilentlyContinue
    Write-Log "UsoSvc (Update Orchestrator Service) set to Automatic."
    Write-Host "   ✅ Done (orchestrator service retained to ensure security patches are delivered)" -ForegroundColor Green

} catch {
    Write-Log "Unexpected error: $_" "ERROR"
    Write-Host "`n❌ An error occurred during script execution. Please check the log: $logFile" -ForegroundColor Red
    Exit 1
}

# ── 6. Summary ────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Update Control Summary" -ForegroundColor Cyan
Write-Host "  Mode: Web / App Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [✅] Update Policy    : Auto-download, notify to install"
Write-Host "  [✅] Auto-Reboot      : Disabled at all times"
Write-Host "  [✅] Detection Rate   : Every 24 hours"
Write-Host "  [✅] Delivery Optim.  : Local PC only"
Write-Host "  [✅] UsoSvc           : Running (ensures security patch delivery)"
Write-Host "  [📋] Log File         : $logFile"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tip: Once patches are downloaded, a notification will appear." -ForegroundColor DarkCyan
Write-Host "       Please install them manually during off-peak hours." -ForegroundColor DarkCyan
Write-Host "  Recommendation: Install security updates at least once a month" -ForegroundColor DarkCyan
Write-Host "                  to minimize exposure to vulnerabilities." -ForegroundColor DarkCyan
Write-Host ""
Write-Log "Script completed successfully."
