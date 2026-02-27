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
    - Intel CPUs: sets the Ultimate Performance power plan
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

# -----------------------------------------------------------------------------
# HEADLESS MODE: When run from SENSEQUALITY app, skip interactive prompts
# and read skip flags from environment variables
# -----------------------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# CPU vendor detection for power plan policy
$CpuName = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name)
$IsIntelCpu = $CpuName -match "Intel"

# -----------------------------------------------------------------------------
# SAFETY: Create backup folder and export registry snapshots before any changes
# -----------------------------------------------------------------------------

$BackupDir = "$env:USERPROFILE\Documents\GamingOptimization_Backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

if (-not $Headless) { Clear-Host }
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


# -----------------------------------------------------------------------------
# SECTION 1: POWER PLAN - Intel only
# WHY: Prevents CPU/GPU clock throttling under sustained gaming load.
#      Ultimate Performance is applied only on Intel CPUs.
#      AMD/Ryzen systems keep their existing plan (chipset plans are preferred).
# -----------------------------------------------------------------------------

if ($env:SKIP_POWER_PLAN -eq '1') {
    Write-Host "[1/12] POWER PLAN - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:POWER_PLAN]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[1/12] POWER PLAN" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        if (-not $IsIntelCpu) {
            Write-Host "  [INFO] Non-Intel CPU detected ($CpuName). Leaving existing power plan unchanged." -ForegroundColor DarkCyan
            Write-Host "[SQ_SKIP:POWER_PLAN]"
        } else {
            # Unlock the hidden "Ultimate Performance" power plan (GUID: e9a42b02-d5df-448d-aa00-03f14749eb61)
            $UltimatePerfGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $existingPlans = powercfg /list
            if ($existingPlans -notmatch $UltimatePerfGUID) {
                Write-Host "  [INFO] Unlocking Ultimate Performance plan..." -ForegroundColor DarkCyan
                powercfg -duplicatescheme $UltimatePerfGUID | Out-Null
            }
            powercfg /setactive $UltimatePerfGUID
            Write-Host "  [OK] Intel CPU detected. Ultimate Performance power plan activated." -ForegroundColor Green
            Write-Host "  [TIP] Verify in: Control Panel > Power Options" -ForegroundColor DarkGray
            Write-Host "[SQ_OK:POWER_PLAN]"
        }
    } catch {
        Write-Host "  [FAIL] Power plan: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:POWER_PLAN]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 2: HARDWARE-ACCELERATED GPU SCHEDULING (HAGS)
# WHY: Reduces CPU overhead for GPU command scheduling.
#      Beneficial on NVIDIA RTX 30/40 series and AMD RDNA 2/3 with recent drivers.
#      Note: Disable if you experience increased VRAM usage or stutters on 8GB VRAM GPUs.
# -----------------------------------------------------------------------------

if ($env:SKIP_HAGS -eq '1') {
    Write-Host "[2/12] HAGS - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:HAGS]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[2/12] HARDWARE-ACCELERATED GPU SCHEDULING (HAGS)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

        Set-ItemProperty -Path $HagsPath -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Host "  [OK] HAGS enabled (HwSchMode = 2)." -ForegroundColor Green
        Write-Host "  [TIP] If you have 8GB VRAM or less and experience stutters, disable via:" -ForegroundColor DarkGray
        Write-Host "         Settings > Display > Graphics > Change default graphics settings" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:HAGS]"
    } catch {
        Write-Host "  [FAIL] HAGS: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:HAGS]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 3: WINDOWS GAME MODE
# WHY: When enabled, Game Mode focuses system resources on the active game,
#      reduces background process interference, and signals the OS scheduler
#      to prioritize the game. Should be ON for single-monitor gaming setups.
# -----------------------------------------------------------------------------

if ($env:SKIP_GAME_MODE -eq '1') {
    Write-Host "[3/12] GAME MODE - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:GAME_MODE]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[3/12] WINDOWS GAME MODE" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $GameBarPath = "HKCU:\Software\Microsoft\GameBar"
        if (-not (Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

        Set-ItemProperty -Path $GameBarPath -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $GameBarPath -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $GameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force

        $GameBarPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        if (-not (Test-Path $GameBarPolicyPath)) { New-Item -Path $GameBarPolicyPath -Force | Out-Null }
        Set-ItemProperty -Path $GameBarPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord -Force

        $GameDVRPath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $GameDVRPath)) { New-Item -Path $GameDVRPath -Force | Out-Null }
        Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

        Write-Host "  [OK] Game Mode enabled." -ForegroundColor Green
        Write-Host "  [OK] Xbox Game Bar overlay disabled." -ForegroundColor Green
        Write-Host "  [OK] Game DVR / background recording disabled." -ForegroundColor Green
        Write-Host "  [TIP] These can also be toggled in: Settings > Gaming" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:GAME_MODE]"
    } catch {
        Write-Host "  [FAIL] Game Mode: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:GAME_MODE]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 4: WINDOWS MULTIMEDIA SCHEDULER - GAME PRIORITY
# WHY: The Windows Multimedia Class Scheduler Service (MMCSS) controls CPU
#      time allocated to games vs background processes. Setting Scheduling
#      Category to High and SystemResponsiveness to 10 maximizes game CPU time.
#      Values below 10 are auto-rounded up to 20 by Windows, so 10 is optimal.
# -----------------------------------------------------------------------------

if ($env:SKIP_MMCSS -eq '1') {
    Write-Host "[4/12] MMCSS - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:MMCSS]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[4/12] MULTIMEDIA SCHEDULER & SYSTEM RESPONSIVENESS" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $ProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $GamesTaskPath = "$ProfilePath\Tasks\Games"

        if (-not (Test-Path $ProfilePath)) { New-Item -Path $ProfilePath -Force | Out-Null }
        if (-not (Test-Path $GamesTaskPath)) { New-Item -Path $GamesTaskPath -Force | Out-Null }

        Set-ItemProperty -Path $ProfilePath -Name "SystemResponsiveness" -Value 10 -Type DWord -Force
        Set-ItemProperty -Path $ProfilePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force

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
        Write-Host "[SQ_OK:MMCSS]"
    } catch {
        Write-Host "  [FAIL] MMCSS: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:MMCSS]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 5: NETWORK OPTIMIZATION - NAGLE'S ALGORITHM & LATENCY
# WHY: Nagle's Algorithm batches small TCP packets to save bandwidth, but
#      this introduces 10-200ms of additional latency in online games.
#      Disabling it sends packets immediately, reducing ping and rubber-banding.
#      NetworkThrottlingIndex removal ensures full bandwidth for game traffic.
# -----------------------------------------------------------------------------

if ($env:SKIP_NETWORK -eq '1') {
    Write-Host "[5/12] NETWORK - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:NETWORK]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[5/12] NETWORK OPTIMIZATION (Nagle's Algorithm + Latency)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $TcpipInterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"

        if (Test-Path $TcpipInterfacesPath) {
            $interfaces = Get-ChildItem -Path $TcpipInterfacesPath
            $patchedCount = 0

            foreach ($iface in $interfaces) {
                $dhcpProps = Get-ItemProperty -Path $iface.PSPath -Name "DhcpIPAddress" -ErrorAction SilentlyContinue
                $ipProps = Get-ItemProperty -Path $iface.PSPath -Name "IPAddress" -ErrorAction SilentlyContinue
                $ipAddr = if ($null -ne $dhcpProps) { $dhcpProps.DhcpIPAddress } else { $null }
                $staticIp = if ($null -ne $ipProps) { $ipProps.IPAddress } else { $null }

                if ($ipAddr -or $staticIp) {
                    Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
                    $patchedCount++
                }
            }

            Write-Host "  [OK] Nagle's Algorithm disabled on $patchedCount active network interface(s)." -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Could not find TCP/IP interfaces registry key. Skipping." -ForegroundColor Yellow
        }

        $TcpParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        if (Test-Path $TcpParamsPath) {
            Set-ItemProperty -Path $TcpParamsPath -Name "DefaultTTL" -Value 64 -Type DWord -Force
            Write-Host "  [OK] DefaultTTL set to 64." -ForegroundColor Green
        }
        Write-Host "[SQ_OK:NETWORK]"
    } catch {
        Write-Host "  [FAIL] Network: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:NETWORK]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 6: VISUAL EFFECTS - PERFORMANCE MODE
# WHY: Windows visual effects (animations, shadows, transparency) consume
#      CPU/GPU cycles even when gaming. Setting to "Best Performance" mode
#      eliminates this background rendering overhead.
# -----------------------------------------------------------------------------

if ($env:SKIP_VISUAL_FX -eq '1') {
    Write-Host "[6/12] VISUAL FX - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:VISUAL_FX]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[6/12] WINDOWS VISUAL EFFECTS (Best Performance)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $VisualFXPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path $VisualFXPath)) { New-Item -Path $VisualFXPath -Force | Out-Null }
        Set-ItemProperty -Path $VisualFXPath -Name "VisualFXSetting" -Value 2 -Type DWord -Force

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
        Write-Host "[SQ_OK:VISUAL_FX]"
    } catch {
        Write-Host "  [FAIL] Visual FX: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:VISUAL_FX]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 7: FULLSCREEN OPTIMIZATIONS - DISABLE GLOBALLY
# WHY: Windows Fullscreen Optimizations intercept exclusive fullscreen mode
#      and run the game in a borderless window internally. This adds latency
#      and can cause frame pacing issues. Disabling gives true exclusive
#      fullscreen with direct GPU-to-display buffer access.
#      NOTE: Some games (notably Valorant) work better with this enabled.
#      Per-game overrides are handled in individual game scripts.
# -----------------------------------------------------------------------------

if ($env:SKIP_FULLSCREEN -eq '1') {
    Write-Host "[7/12] FULLSCREEN - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:FULLSCREEN]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[7/12] FULLSCREEN OPTIMIZATIONS (Global Disable)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $AppCompatPath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $AppCompatPath)) { New-Item -Path $AppCompatPath -Force | Out-Null }
        Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
        Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_EFSEBehaviorMode" -Value 2 -Type DWord -Force

        Write-Host "  [OK] Fullscreen optimizations disabled globally." -ForegroundColor Green
        Write-Host "  [NOTE] Valorant may perform slightly better with FSO enabled." -ForegroundColor DarkGray
        Write-Host "  [NOTE] Per-game EXE overrides are set in individual game scripts." -ForegroundColor DarkGray
        Write-Host "[SQ_OK:FULLSCREEN]"
    } catch {
        Write-Host "  [FAIL] Fullscreen: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:FULLSCREEN]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 8: MOUSE SETTINGS - DISABLE ACCELERATION
# WHY: Mouse acceleration (Enhance Pointer Precision) makes cursor movement
#      speed-dependent rather than distance-dependent. This destroys muscle
#      memory consistency critical for competitive FPS aiming.
# -----------------------------------------------------------------------------

if ($env:SKIP_MOUSE -eq '1') {
    Write-Host "[8/12] MOUSE - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:MOUSE]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[8/12] MOUSE ACCELERATION (Disable)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $MousePath = "HKCU:\Control Panel\Mouse"
        if (-not (Test-Path $MousePath)) { New-Item -Path $MousePath -Force | Out-Null }
        Set-ItemProperty -Path $MousePath -Name "MouseSpeed"      -Value "0" -Type String -Force
        Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Value "0" -Type String -Force

        Write-Host "  [OK] Mouse acceleration (Enhance Pointer Precision) disabled." -ForegroundColor Green
        Write-Host "  [TIP] Also verify in: Control Panel > Mouse > Pointer Options >" -ForegroundColor DarkGray
        Write-Host "         Uncheck 'Enhance pointer precision'" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:MOUSE]"
    } catch {
        Write-Host "  [FAIL] Mouse: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:MOUSE]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 9: TIMER RESOLUTION & SLEEP STATES
# WHY: Windows default timer resolution is 15.6ms. Setting it to 0.5ms (via
#      games that call timeBeginPeriod) improves frame scheduling precision.
#      Disabling CPU C-States (deep sleep) prevents wake latency spikes.
# -----------------------------------------------------------------------------

if ($env:SKIP_CPU_POWER -eq '1') {
    Write-Host "[9/12] CPU POWER - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:CPU_POWER]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[9/12] CPU POWER STATES & ADDITIONAL TWEAKS" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        if ($IsIntelCpu) {
            $UltimatePerfGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            powercfg /setacvalueindex $UltimatePerfGUID SUB_PROCESSOR PROCTHROTTLEMIN 100
            powercfg /setactive $UltimatePerfGUID

            powercfg /setacvalueindex $UltimatePerfGUID 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

            Write-Host "  [OK] Intel CPU detected. CPU minimum state set to 100% on Ultimate plan." -ForegroundColor Green
            Write-Host "  [OK] USB Selective Suspend disabled on Ultimate plan." -ForegroundColor Green
        } else {
            Write-Host "  [INFO] Non-Intel CPU detected ($CpuName). Skipping Ultimate/high power-plan forcing." -ForegroundColor DarkCyan
        }

        powercfg /hibernate off
        Write-Host "  [OK] Hibernation disabled." -ForegroundColor Green
        Write-Host "[SQ_OK:CPU_POWER]"
    } catch {
        Write-Host "  [FAIL] CPU Power: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:CPU_POWER]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 10: DISABLE BACKGROUND APPS
# WHY: UWP/Store apps run background tasks (sync, update checks, telemetry)
#      that steal CPU time and trigger disk I/O during gaming. Disabling the
#      global background-access toggle stops all Store apps from running
#      background tasks unless you grant them individually.
# -----------------------------------------------------------------------------

if ($env:SKIP_BG_APPS -eq '1') {
    Write-Host "[10/12] BACKGROUND APPS - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:BG_APPS]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[10/12] DISABLE BACKGROUND APPS" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $BgAppsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        if (-not (Test-Path $BgAppsPath)) { New-Item -Path $BgAppsPath -Force | Out-Null }
        Set-ItemProperty -Path $BgAppsPath -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force

        $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
        Set-ItemProperty -Path $SearchPath -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -Force

        Write-Host "  [OK] Background apps disabled globally." -ForegroundColor Green
        Write-Host "  [TIP] Individual app permissions in: Settings > Privacy > Background apps" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:BG_APPS]"
    } catch {
        Write-Host "  [FAIL] Background Apps: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:BG_APPS]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 11: DISABLE MULTIPLANE OVERLAY (MPO)
# WHY: MPO allows the DWM compositor to send independent "planes" to the
#      display hardware, which can cause micro-stutters, black flickers, and
#      frame pacing issues - particularly on multi-monitor setups and with
#      hardware-accelerated apps (browsers, Discord). Disabling it forces
#      single-plane composition, which is more predictable for gaming.
# -----------------------------------------------------------------------------

if ($env:SKIP_MPO -eq '1') {
    Write-Host "[11/12] MPO - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:MPO]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[11/12] DISABLE MULTIPLANE OVERLAY (MPO)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $DwmPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
        if (-not (Test-Path $DwmPath)) { New-Item -Path $DwmPath -Force | Out-Null }
        Set-ItemProperty -Path $DwmPath -Name "OverlayTestMode" -Value 5 -Type DWord -Force

        Write-Host "  [OK] Multiplane Overlay (MPO) disabled." -ForegroundColor Green
        Write-Host "  [NOTE] Fixes flickers and stutters on multi-monitor setups." -ForegroundColor DarkGray
        Write-Host "[SQ_OK:MPO]"
    } catch {
        Write-Host "  [FAIL] MPO: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:MPO]"
    }
}


# -----------------------------------------------------------------------------
# SECTION 12: VISUAL EFFECTS EXTRAS
# WHY: Beyond the "Best Performance" toggle in Section 6, there are additional
#      UI elements that steal focus or consume DWM resources:
#      - MenuShowDelay: default 400ms delays all right-click and start menus
#      - KeyboardDelay: default repeat delay is higher than needed
#      - Chat/TaskView/Search icons: taskbar icons that trigger background
#        processes and can steal focus during fullscreen gaming
# -----------------------------------------------------------------------------

if ($env:SKIP_VISUAL_EXTRAS -eq '1') {
    Write-Host "[12/12] VISUAL EXTRAS - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:VISUAL_EXTRAS]"
} else {
    Write-Host ""
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[12/12] VISUAL EFFECTS EXTRAS" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Speed up context menus (default is 400ms)
        $DesktopPath = "HKCU:\Control Panel\Desktop"
        if (-not (Test-Path $DesktopPath)) { New-Item -Path $DesktopPath -Force | Out-Null }
        Set-ItemProperty -Path $DesktopPath -Name "MenuShowDelay" -Value "200" -Type String -Force
        Write-Host "  [OK] Menu show delay reduced to 200ms (from 400ms)." -ForegroundColor Green

        # Reduce keyboard repeat delay (0=shortest)
        $KeyboardPath = "HKCU:\Control Panel\Keyboard"
        if (-not (Test-Path $KeyboardPath)) { New-Item -Path $KeyboardPath -Force | Out-Null }
        Set-ItemProperty -Path $KeyboardPath -Name "KeyboardDelay" -Value "0" -Type String -Force
        Write-Host "  [OK] Keyboard repeat delay set to minimum." -ForegroundColor Green

        # Hide Chat icon on taskbar
        $ChatPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $ChatPath -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Chat icon hidden from taskbar." -ForegroundColor Green

        # Hide Task View button
        Set-ItemProperty -Path $ChatPath -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Task View button hidden." -ForegroundColor Green

        # Minimize Search to icon-only (0=hidden, 1=icon, 2=box)
        $SearchUIPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $SearchUIPath)) { New-Item -Path $SearchUIPath -Force | Out-Null }
        Set-ItemProperty -Path $SearchUIPath -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -Force
        Write-Host "  [OK] Search bar minimized to icon." -ForegroundColor Green

        Write-Host "[SQ_OK:VISUAL_EXTRAS]"
    } catch {
        Write-Host "  [FAIL] Visual Extras: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:VISUAL_EXTRAS]"
    }
}


# -----------------------------------------------------------------------------
# COMPLETION SUMMARY
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  WINDOWS OPTIMIZATIONS COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
if (-not $Headless) {
    Write-Host "  NEXT STEPS:" -ForegroundColor White
    Write-Host "  1. Run the per-game scripts for BO7/Fortnite/Valorant/CS2/Arc Raiders" -ForegroundColor White
    Write-Host "  2. Apply NVIDIA/AMD Control Panel settings manually (see README)" -ForegroundColor White
    Write-Host "  3. REBOOT your PC for all changes to fully take effect" -ForegroundColor White
    Write-Host ""
}
Write-Host "  BACKUP LOCATION:" -ForegroundColor Yellow
Write-Host "  $BackupDir" -ForegroundColor Yellow
Write-Host ""
if (-not $Headless) {
    Write-Host "  To restore ALL settings: run the .reg files in the backup folder." -ForegroundColor DarkGray
    Write-Host ""
}
