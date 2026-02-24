#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MASTER GAMING OPTIMIZATION SCRIPT
    Version: 2.0 | Updated: February 2026

    Runs ALL optimization scripts in the correct order for:
    - Call of Duty: Black Ops 7
    - Fortnite (Chapter 6)
    - Valorant
    - Counter-Strike 2
    - Arc Raiders

.DESCRIPTION
    This master script orchestrates the full optimization sequence:
    1. Windows system-level optimizations (power, network, registry)
    2. Black Ops 7 settings guide and EXE flags
    3. Fortnite config file + settings guide
    4. Valorant config file + settings guide
    5. CS2 autoexec.cfg + launch options + settings guide
    6. Arc Raiders Engine.ini + settings guide
    7. GPU Control Panel guide (NVIDIA/AMD)

    WHAT GETS CHANGED:
    - Windows registry (power plan, MMCSS, network, mouse)
    - Fortnite GameUserSettings.ini (graphics config)
    - Valorant GameUserSettings.ini (graphics config)
    - CS2 autoexec.cfg (network, graphics, crosshair commands)
    - CS2 Steam launch options (registry)
    - Arc Raiders Engine.ini (UE5 performance variables)
    - Windows EXE compatibility flags for all games

    WHAT DOES NOT GET CHANGED:
    - Game executable files (never modified)
    - Anti-cheat protected files (never touched)
    - Game assets or DLLs (never modified)

    SAFETY:
    - Full registry backup created before any changes
    - Config file backups created before each game's config is written
    - All changes are reversible via the backup files
    - A system restore point is recommended before running

.NOTES
    PREREQUISITES:
    - Run as Administrator (required)
    - Windows 10 v2004 or Windows 11 (for HAGS support)
    - Games installed (scripts will warn if not found, not fail)
    - Internet connection not required

    ESTIMATED TIME: 2-5 minutes
    REBOOT REQUIRED: Yes (after completion, reboot for all changes to apply)

    EDIT THE USER CONFIGURATION SECTION BELOW before running!
#>

# ═════════════════════════════════════════════════════════════════════════════
# USER CONFIGURATION - EDIT THESE BEFORE RUNNING
# ═════════════════════════════════════════════════════════════════════════════

# Your monitor specifications
$Global:MonitorWidth   = 1920    # Monitor width  in pixels (e.g., 1920, 2560)
$Global:MonitorHeight  = 1080    # Monitor height in pixels (e.g., 1080, 1440)
$Global:MonitorRefresh = 240     # Monitor refresh rate in Hz (e.g., 144, 165, 240, 360)

# GPU type (affects which upscaling tech is recommended)
$Global:NvidiaGPU = $true        # $true = NVIDIA, $false = AMD

# CS2 resolution preference
$Global:CS2Stretched = $false    # $true = 4:3 stretched (1280x960), $false = 16:9 native

# Which games to optimize (set $false to skip any game)
$OptimizeBO7       = $true
$OptimizeFortnite  = $true
$OptimizeValorant  = $true
$OptimizeCS2       = $true
$OptimizeArcRaiders = $true

# Script directory (auto-detected)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ═════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═════════════════════════════════════════════════════════════════════════════

Clear-Host
Write-Host ""
Write-Host "  ██████╗  █████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗" -ForegroundColor Cyan
Write-Host "  ██╔════╝ ██╔══██╗████╗ ████║██║████╗  ██║██╔════╝" -ForegroundColor Cyan
Write-Host "  ██║  ███╗███████║██╔████╔██║██║██╔██╗ ██║██║  ███╗" -ForegroundColor Cyan
Write-Host "  ██║   ██║██╔══██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║" -ForegroundColor Cyan
Write-Host "  ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝" -ForegroundColor Cyan
Write-Host "   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  COMPETITIVE PC GAMING OPTIMIZER - Master Script v2.0" -ForegroundColor White
Write-Host "  February 2026 | BO7 / Fortnite / Valorant / CS2 / Arc Raiders" -ForegroundColor White
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkGray

# Check admin rights
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "        Right-click the script > Run with PowerShell as Admin" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[WARN] PowerShell 5.0+ recommended. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
}

# Check Windows version
$WinVer = [System.Environment]::OSVersion.Version
Write-Host "[INFO] Windows Version: $($WinVer.Major).$($WinVer.Minor).$($WinVer.Build)" -ForegroundColor DarkCyan
Write-Host "[INFO] Monitor: ${Global:MonitorWidth}x${Global:MonitorHeight} @ ${Global:MonitorRefresh}Hz" -ForegroundColor DarkCyan
Write-Host "[INFO] GPU Type: $(if ($Global:NvidiaGPU) {'NVIDIA'} else {'AMD'})" -ForegroundColor DarkCyan
Write-Host "[INFO] CS2 Resolution: $(if ($Global:CS2Stretched) {'4:3 Stretched (1280x960)'} else {'16:9 Native'})" -ForegroundColor DarkCyan
Write-Host ""

# Confirm before proceeding
Write-Host "  This script will modify Windows registry settings and game config files." -ForegroundColor Yellow
Write-Host "  Backups will be created automatically before any changes." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "  Press ENTER to continue, or type 'CANCEL' to abort"
if ($confirm -eq "CANCEL") {
    Write-Host "Aborted by user." -ForegroundColor Red
    exit 0
}

Write-Host ""

# ═════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTION: Run a sub-script with error handling
# ═════════════════════════════════════════════════════════════════════════════

function Invoke-OptimizationScript {
    param(
        [string]$ScriptPath,
        [string]$GameName,
        [hashtable]$Parameters = @{}
    )

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  RUNNING: $GameName" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path $ScriptPath)) {
        Write-Host "[ERROR] Script not found: $ScriptPath" -ForegroundColor Red
        return $false
    }

    try {
        # Pass global config variables to the sub-script via environment
        $env:MONITOR_WIDTH   = $Global:MonitorWidth
        $env:MONITOR_HEIGHT  = $Global:MonitorHeight
        $env:MONITOR_REFRESH = $Global:MonitorRefresh
        $env:NVIDIA_GPU      = $Global:NvidiaGPU

        & $ScriptPath
        Write-Host ""
        Write-Host "  [COMPLETED] $GameName optimization done." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[ERROR] $GameName script failed: $_" -ForegroundColor Red
        return $false
    }
}

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1: WINDOWS SYSTEM OPTIMIZATION (always runs)
# ═════════════════════════════════════════════════════════════════════════════

$results = @{}
$results["Windows"] = Invoke-OptimizationScript `
    -ScriptPath (Join-Path $ScriptDir "01_Windows_Optimization.ps1") `
    -GameName "Windows System Optimization"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2-6: PER-GAME SCRIPTS
# ═════════════════════════════════════════════════════════════════════════════

if ($OptimizeBO7) {
    $results["BlackOps7"] = Invoke-OptimizationScript `
        -ScriptPath (Join-Path $ScriptDir "02_BlackOps7_Settings.ps1") `
        -GameName "Call of Duty: Black Ops 7"
}

if ($OptimizeFortnite) {
    $results["Fortnite"] = Invoke-OptimizationScript `
        -ScriptPath (Join-Path $ScriptDir "03_Fortnite_Settings.ps1") `
        -GameName "Fortnite (Chapter 6)"
}

if ($OptimizeValorant) {
    $results["Valorant"] = Invoke-OptimizationScript `
        -ScriptPath (Join-Path $ScriptDir "04_Valorant_Settings.ps1") `
        -GameName "Valorant"
}

if ($OptimizeCS2) {
    $results["CS2"] = Invoke-OptimizationScript `
        -ScriptPath (Join-Path $ScriptDir "05_CS2_Settings.ps1") `
        -GameName "Counter-Strike 2"
}

if ($OptimizeArcRaiders) {
    $results["ArcRaiders"] = Invoke-OptimizationScript `
        -ScriptPath (Join-Path $ScriptDir "06_ArcRaiders_Settings.ps1") `
        -GameName "Arc Raiders"
}

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7: GPU CONTROL PANEL GUIDE
# ═════════════════════════════════════════════════════════════════════════════

$results["GPU"] = Invoke-OptimizationScript `
    -ScriptPath (Join-Path $ScriptDir "07_NVIDIA_ControlPanel_Guide.ps1") `
    -GameName "GPU Control Panel Settings Guide"

# ═════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  OPTIMIZATION COMPLETE - SUMMARY" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

foreach ($key in $results.Keys) {
    $status = if ($results[$key]) { "[OK]    " } else { "[FAILED]" }
    $color  = if ($results[$key]) { "Green" } else { "Red" }
    Write-Host "  $status $key" -ForegroundColor $color
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  MANUAL STEPS STILL REQUIRED:" -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. NVIDIA/AMD Control Panel: Apply GPU settings (see guide printed above)" -ForegroundColor White
Write-Host "     Most important: Power Management = Prefer Max Performance" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. BLACK OPS 7: Apply all settings manually in-game" -ForegroundColor White
Write-Host "     (BO7 Ricochet anti-cheat protects config files)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. ALL GAMES: Verify NVIDIA Reflex / AMD Anti-Lag is ON in each game" -ForegroundColor White
Write-Host "     This is the single most impactful per-game setting" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. MONITOR: Set refresh rate to maximum in Windows Display Settings" -ForegroundColor White
Write-Host "     Settings > Display > Advanced Display > Choose refresh rate" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  5. RAM XMP/EXPO: Enable in BIOS if not already active" -ForegroundColor White
Write-Host "     Restart > Enter BIOS (Del/F2) > Enable XMP/EXPO profile" -ForegroundColor DarkGray
Write-Host "     This alone can improve frame times by 10-20% on some systems" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  6. SSD: Ensure games are installed on an SSD, not HDD" -ForegroundColor White
Write-Host "     NVMe SSD is best; SATA SSD is acceptable; HDD causes stutter" -ForegroundColor DarkGray
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "  *** REBOOT REQUIRED FOR ALL CHANGES TO TAKE EFFECT ***" -ForegroundColor Red
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host ""

$reboot = Read-Host "  Reboot now? (Y/N)"
if ($reboot -match "^[Yy]") {
    Write-Host "  Rebooting in 10 seconds... Press Ctrl+C to cancel." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "  Remember to reboot before gaming for all settings to apply!" -ForegroundColor Yellow
    Write-Host ""
}
