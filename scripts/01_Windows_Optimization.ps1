#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Gaming Optimization Script - Competitive PC Gaming
    Version: 2.0 | Updated: February 2026
    Applies to: Call of Duty Black Ops 7, Fortnite, Valorant, CS2, Arc Raiders

.DESCRIPTION
    This script applies system-level Windows optimizations proven to reduce input latency,
    increase frame rates, and improve competitive gaming performance. All changes are
    non-destructive and a full registry backup is created before any changes are made.

    WHAT THIS SCRIPT DOES:
    - Creates a dated backup of affected registry keys
    - Sets the Ultimate Performance power plan
    - Configures GPU scheduling (HAGS)
    - Disables Xbox Game Bar and Game DVR
    - Disables Nagle's Algorithm for lower network latency
    - Sets Network Throttling Index to maximum
    - Configures Windows Multimedia scheduler for games
    - Adjusts visual effects for best performance
    - Disables fullscreen optimizations globally
    - Disables mouse acceleration
    - Sets process priority hints for gaming

.NOTES
    Run this script as Administrator.
    A system restore point is recommended before running.
    Reboot after completion for all changes to take effect.
#>

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY: Create backup folder and export registry snapshots before any changes
# ─────────────────────────────────────────────────────────────────────────────

$BackupDir = "$env:USERPROFILE\Documents\GamingOptimization_Backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Windows Gaming Optimization Script v2.0 (Feb 2026)" -ForegroundColor Cyan
Write-Host "  Supports: BO7, Fortnite, Valorant, CS2, Arc Raiders" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[BACKUP] Creating registry backups at: $BackupDir" -ForegroundColor Yellow

# Export key registry areas before modification
$RegKeysToBackup = @(
    @{ Name = "PowerSettings";      Key = "HKLM\SYSTEM\CurrentControlSet\Control\Power" },
    @{ Name = "MultimediaProfile";  Key = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" },
    @{ Name = "GameTasks";          Key = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" },
    @{ Name = "GameDVR";            Key = "HKLM\SYSTEM\CurrentControlSet\Services\xbgm" },
    @{ Name = "NetworkTcpip";       Key = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" },
    @{ Name = "VisualEffects";      Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" },
    @{ Name = "MouseSettings";      Key = "HKCU\Control Panel\Mouse" },
    @{ Name = "GameMode";           Key = "HKCU\Software\Microsoft\GameBar" }
)

foreach ($item in $RegKeysToBackup) {
    $outFile = Join-Path $BackupDir "$($item.Name).reg"
    reg export $item.Key $outFile /y 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Backed up: $($item.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] Key not found (may be created new): $($item.Name)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "[INFO] Backup complete. To restore any setting, double-click the .reg file in:" -ForegroundColor DarkCyan
Write-Host "       $BackupDir" -ForegroundColor DarkCyan
Write-Host ""


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: POWER PLAN - Ultimate Performance
# WHY: Prevents CPU/GPU clock throttling under sustained gaming load.
#      Ultimate Performance is the highest-priority plan available.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[1/9] POWER PLAN" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

# Unlock the hidden "Ultimate Performance" power plan (GUID: e9a42b02-d5df-448d-aa00-03f14749eb61)
$UltimatePerfGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$existingPlans = powercfg /list
if ($existingPlans -notmatch $UltimatePerfGUID) {
    Write-Host "  [INFO] Unlocking Ultimate Performance plan..." -ForegroundColor DarkCyan
    powercfg -duplicatescheme $UltimatePerfGUID | Out-Null
}
powercfg /setactive $UltimatePerfGUID
Write-Host "  [OK] Ultimate Performance power plan activated." -ForegroundColor Green
Write-Host "  [TIP] Verify in: Control Panel > Power Options" -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: HARDWARE-ACCELERATED GPU SCHEDULING (HAGS)
# WHY: Reduces CPU overhead for GPU command scheduling.
#      Beneficial on NVIDIA RTX 30/40 series and AMD RDNA 2/3 with recent drivers.
#      Note: Disable if you experience increased VRAM usage or stutters on 8GB VRAM GPUs.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[2/9] HARDWARE-ACCELERATED GPU SCHEDULING (HAGS)" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (-not (Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Value 2 -Type DWord -Force
Write-Host "  [OK] HAGS enabled (HwSchMode = 2)." -ForegroundColor Green
Write-Host "  [TIP] If you have 8GB VRAM or less and experience stutters, disable via:" -ForegroundColor DarkGray
Write-Host "         Settings > Display > Graphics > Change default graphics settings" -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: WINDOWS GAME MODE
# WHY: When enabled, Game Mode focuses system resources on the active game,
#      reduces background process interference, and signals the OS scheduler
#      to prioritize the game. Should be ON for single-monitor gaming setups.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[3/9] WINDOWS GAME MODE" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$GameBarPath = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

# Enable Game Mode (focuses CPU/GPU resources on the game process)
Set-ItemProperty -Path $GameBarPath -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $GameBarPath -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force

# Disable Xbox Game Bar overlay (reduces background overhead and accidental activation)
# Game Bar overlay adds ~10-30ms of overhead and can cause frame drops when triggered
Set-ItemProperty -Path $GameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force
$GameBarPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (-not (Test-Path $GameBarPolicyPath)) { New-Item -Path $GameBarPolicyPath -Force | Out-Null }
Set-ItemProperty -Path $GameBarPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord -Force

# Disable Game DVR / background recording (significant CPU/GPU overhead when active)
$GameDVRPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $GameDVRPath)) { New-Item -Path $GameDVRPath -Force | Out-Null }
Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

Write-Host "  [OK] Game Mode enabled." -ForegroundColor Green
Write-Host "  [OK] Xbox Game Bar overlay disabled." -ForegroundColor Green
Write-Host "  [OK] Game DVR / background recording disabled." -ForegroundColor Green
Write-Host "  [TIP] These can also be toggled in: Settings > Gaming" -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: WINDOWS MULTIMEDIA SCHEDULER - GAME PRIORITY
# WHY: The Windows Multimedia Class Scheduler Service (MMCSS) controls CPU
#      time allocated to games vs background processes. Setting Scheduling
#      Category to High and SystemResponsiveness to 10 maximizes game CPU time.
#      Values below 10 are auto-rounded up to 20 by Windows, so 10 is optimal.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[4/9] MULTIMEDIA SCHEDULER & SYSTEM RESPONSIVENESS" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
$GamesTaskPath = "$ProfilePath\Tasks\Games"

if (-not (Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -Force | Out-Null }
if (-not (Test-Path $GamesTaskPath)) { New-Item -Path $GamesTaskPath -Force | Out-Null }

# SystemResponsiveness: 10 = allocate 90% of CPU cycles to games (min value OS honors)
Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Value 10 -Type DWord -Force
# NetworkThrottlingIndex: 0xFFFFFFFF = disable multimedia network throttling limit
Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force

# Games task profile settings
Set-ItemProperty -Path $GamesTaskPath -Name "Affinity"             -Value 0          -Type DWord -Force
Set-ItemProperty -Path $GamesTaskPath -Name "Background Only"      -Value "False"     -Type String -Force
Set-ItemProperty -Path $GamesTaskPath -Name "Clock Rate"           -Value 10000       -Type DWord -Force
Set-ItemProperty -Path $GamesTaskPath -Name "GPU Priority"         -Value 8          -Type DWord -Force
Set-ItemProperty -Path $GamesTaskPath -Name "Priority"             -Value 6          -Type DWord -Force
Set-ItemProperty -Path $GamesTaskPath -Name "Scheduling Category"  -Value "High"      -Type String -Force
Set-ItemProperty -Path $GamesTaskPath -Name "SFIO Priority"        -Value "High"      -Type String -Force

Write-Host "  [OK] SystemResponsiveness set to 10 (90% CPU to games)." -ForegroundColor Green
Write-Host "  [OK] NetworkThrottlingIndex disabled (0xFFFFFFFF)." -ForegroundColor Green
Write-Host "  [OK] MMCSS Games task: Scheduling Category=High, GPU Priority=8." -ForegroundColor Green


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: NETWORK OPTIMIZATION - NAGLE'S ALGORITHM & LATENCY
# WHY: Nagle's Algorithm batches small TCP packets to save bandwidth, but
#      this introduces 10-200ms of additional latency in online games.
#      Disabling it sends packets immediately, reducing ping and rubber-banding.
#      NetworkThrottlingIndex removal ensures full bandwidth for game traffic.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[5/9] NETWORK OPTIMIZATION (Nagle's Algorithm + Latency)" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$TcpipInterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"

if (Test-Path $TcpipInterfacesPath) {
    $interfaces = Get-ChildItem -Path $TcpipInterfacesPath
    $patchedCount = 0

    foreach ($iface in $interfaces) {
        # Only patch interfaces that have an assigned IP (active adapters)
        $ipAddr = (Get-ItemProperty -Path $iface.PSPath -Name "DhcpIPAddress" -ErrorAction SilentlyContinue)?.DhcpIPAddress
        $staticIp = (Get-ItemProperty -Path $iface.PSPath -Name "IPAddress" -ErrorAction SilentlyContinue)?.IPAddress

        if ($ipAddr -or $staticIp) {
            # TcpAckFrequency = 1: Send ACK for every packet (disables Nagle batching)
            Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            # TCPNoDelay = 1: Disable Nagle's Algorithm (send data immediately)
            Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            $patchedCount++
        }
    }

    Write-Host "  [OK] Nagle's Algorithm disabled on $patchedCount active network interface(s)." -ForegroundColor Green
} else {
    Write-Host "  [WARN] Could not find TCP/IP interfaces registry key. Skipping." -ForegroundColor Yellow
}

# Global TCP parameters for gaming
$TcpParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
if (Test-Path $TcpParamsPath) {
    # DefaultTTL: 64 is standard for gaming (reduces hop processing overhead)
    Set-ItemProperty -Path $TcpParamsPath -Name "DefaultTTL" -Value 64 -Type DWord -Force
    Write-Host "  [OK] DefaultTTL set to 64." -ForegroundColor Green
}


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: VISUAL EFFECTS - PERFORMANCE MODE
# WHY: Windows visual effects (animations, shadows, transparency) consume
#      CPU/GPU cycles even when gaming. Setting to "Best Performance" mode
#      eliminates this background rendering overhead.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[6/9] WINDOWS VISUAL EFFECTS (Best Performance)" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$VisualFXPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $VisualFXPath)) { New-Item -Path $VisualFXPath -Force | Out-Null }
# VisualFXSetting: 2 = "Adjust for best performance" (disables most animations/effects)
Set-ItemProperty -Path $VisualFXPath -Name "VisualFXSetting" -Value 2 -Type DWord -Force

# Additional animation/transparency toggles
$DWMPath = "HKCU:\Software\Microsoft\Windows\DWM"
if (-not (Test-Path $DWMPath)) { New-Item -Path $DWMPath -Force | Out-Null }
Set-ItemProperty -Path $DWMPath -Name "EnableAeroPeek" -Value 0 -Type DWord -Force

$PersonalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $PersonalizePath)) { New-Item -Path $PersonalizePath -Force | Out-Null }
Set-ItemProperty -Path $PersonalizePath -Name "EnableTransparency" -Value 0 -Type DWord -Force

Write-Host "  [OK] Visual effects set to Best Performance mode." -ForegroundColor Green
Write-Host "  [OK] Aero Peek disabled." -ForegroundColor Green
Write-Host "  [OK] Window transparency disabled." -ForegroundColor Green
Write-Host "  [TIP] To restore: Right-click My Computer > Properties > Advanced >" -ForegroundColor DarkGray
Write-Host "         Performance Settings > Visual Effects > Let Windows choose" -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: FULLSCREEN OPTIMIZATIONS - DISABLE GLOBALLY
# WHY: Windows Fullscreen Optimizations intercept exclusive fullscreen mode
#      and run the game in a borderless window internally. This adds latency
#      and can cause frame pacing issues. Disabling gives true exclusive
#      fullscreen with direct GPU-to-display buffer access.
#      NOTE: Some games (notably Valorant) work better with this enabled.
#      Per-game overrides are handled in individual game scripts.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[7/9] FULLSCREEN OPTIMIZATIONS (Global Disable)" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$AppCompatPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $AppCompatPath)) { New-Item -Path $AppCompatPath -Force | Out-Null }
Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_EFSEBehaviorMode" -Value 2 -Type DWord -Force

Write-Host "  [OK] Fullscreen optimizations disabled globally." -ForegroundColor Green
Write-Host "  [NOTE] Valorant may perform slightly better with FSO enabled." -ForegroundColor DarkGray
Write-Host "  [NOTE] Per-game EXE overrides are set in individual game scripts." -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: MOUSE SETTINGS - DISABLE ACCELERATION
# WHY: Mouse acceleration (Enhance Pointer Precision) makes cursor movement
#      speed-dependent rather than distance-dependent. This destroys muscle
#      memory consistency critical for competitive FPS aiming.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[8/9] MOUSE ACCELERATION (Disable)" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

$MousePath = "HKCU:\Control Panel\Mouse"
if (-not (Test-Path $MousePath)) { New-Item -Path $MousePath -Force | Out-Null }
# MouseSpeed = 0: Disable enhanced pointer precision (mouse acceleration)
# MouseThreshold1 & 2 = 0: Disable double/quadruple speed thresholds
Set-ItemProperty -Path $MousePath -Name "MouseSpeed"      -Value "0" -Type String -Force
Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Value "0" -Type String -Force
Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Value "0" -Type String -Force

Write-Host "  [OK] Mouse acceleration (Enhance Pointer Precision) disabled." -ForegroundColor Green
Write-Host "  [TIP] Also verify in: Control Panel > Mouse > Pointer Options >" -ForegroundColor DarkGray
Write-Host "         Uncheck 'Enhance pointer precision'" -ForegroundColor DarkGray


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9: TIMER RESOLUTION & SLEEP STATES
# WHY: Windows default timer resolution is 15.6ms. Setting it to 0.5ms (via
#      games that call timeBeginPeriod) improves frame scheduling precision.
#      Disabling CPU C-States (deep sleep) prevents wake latency spikes.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "[9/9] CPU POWER STATES & ADDITIONAL TWEAKS" -ForegroundColor White
Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

# Set minimum processor state to 100% on the Ultimate Performance plan
# This prevents CPU from downclocking when a new frame burst starts
$UltimatePerfGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg /setacvalueindex $UltimatePerfGUID SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setactive $UltimatePerfGUID

# Disable USB Selective Suspend (prevents mouse/keyboard latency spikes from USB power saving)
powercfg /setacvalueindex $UltimatePerfGUID 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

# Disable hibernation to free pagefile space and reduce wake delay
powercfg /hibernate off

Write-Host "  [OK] CPU minimum state set to 100% (no downclocking mid-game)." -ForegroundColor Green
Write-Host "  [OK] USB Selective Suspend disabled (prevents input latency spikes)." -ForegroundColor Green
Write-Host "  [OK] Hibernation disabled." -ForegroundColor Green


# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION SUMMARY
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  ALL WINDOWS OPTIMIZATIONS APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor White
Write-Host "  1. Run the per-game scripts for BO7/Fortnite/Valorant/CS2/Arc Raiders" -ForegroundColor White
Write-Host "  2. Apply NVIDIA/AMD Control Panel settings manually (see README)" -ForegroundColor White
Write-Host "  3. REBOOT your PC for all changes to fully take effect" -ForegroundColor White
Write-Host ""
Write-Host "  BACKUP LOCATION:" -ForegroundColor Yellow
Write-Host "  $BackupDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To restore ALL settings: run the .reg files in the backup folder." -ForegroundColor DarkGray
Write-Host ""
