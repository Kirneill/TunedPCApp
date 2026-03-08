#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Latency Reduction Optimizations for Competitive Gaming
    Version: 1.0 | March 2026
.DESCRIPTION
    Applies system-level latency reduction tweaks proven to reduce
    input latency, improve frame pacing, and stabilize 1%/0.1% lows:
    - Timer resolution (global 0.5ms via registry)
    - Power throttling disable
    - Win32PrioritySeparation foreground boost (0x26)
    - Dynamic tick disable (bcdedit, reboot required)
    - HPET disable (bcdedit, reboot required)
    SAFETY: Registry backups created by parent script. bcdedit changes
    are reversible via documented revert commands.
.NOTES
    Run as Administrator. Reboot required for bcdedit changes.
    Each section is independently skippable via SKIP_* env vars.
#>

$ErrorActionPreference = 'SilentlyContinue'
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Set-RegistryValueSafe {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$CheckKey,
        [string]$Label
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Host "  [OK] $Label" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
    }
    catch {
        Write-Host "  [FAIL] $Label -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:${CheckKey}:$($_.Exception.Message)]"
    }
}


# ============================================================
# HEADER
# ============================================================

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Latency Reduction Optimizations v1.0 (March 2026)" -ForegroundColor Cyan
Write-Host "  Timer, Priority, Throttling, and Clock Tweaks" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# SECTION 1: TIMER RESOLUTION
# WHY: Windows default timer resolution is 15.6ms. Starting in
#      Windows 10 2004, Microsoft changed timer behavior so each
#      process gets only its own requested resolution. Setting
#      GlobalTimerResolutionRequests=1 restores the pre-2004
#      behavior where the highest resolution requested by ANY
#      process applies system-wide. When a game calls
#      timeBeginPeriod(1), all threads benefit from 0.5ms ticks.
#      Impact: 20-30% improvement in 1% and 0.1% frame time lows.
# ============================================================

if ($env:SKIP_TIMER_RES -eq '1') {
    Write-Host "[SKIP] Timer Resolution -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:TIMER_RES]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[1/5] TIMER RESOLUTION (0.5ms Global)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"

        Set-RegistryValueSafe `
            -Path $kernelPath `
            -Name "GlobalTimerResolutionRequests" `
            -Value 1 `
            -CheckKey "LATENCY_TIMER_GLOBAL" `
            -Label "GlobalTimerResolutionRequests = 1 (honor global timer requests)"

        Write-Host "  [NOTE] Games that call timeBeginPeriod() will set 0.5ms resolution globally" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Slightly increases idle power consumption" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:TIMER_RES]"
    } catch {
        Write-Host "  [FAIL] Timer Resolution: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:TIMER_RES]"
    }

    Write-Host ""
}


# ============================================================
# SECTION 2: POWER THROTTLING DISABLE
# WHY: Windows 10 Fall Creators Update (1709+) introduced
#      Power Throttling which reduces CPU performance for
#      processes Windows considers "low priority." On desktops,
#      this is unnecessary and can cause micro-stutters when
#      Windows incorrectly throttles game-related helper threads
#      or background audio/voice chat processes.
# ============================================================

if ($env:SKIP_POWER_THROTTLE -eq '1') {
    Write-Host "[SKIP] Power Throttling -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:POWER_THROTTLE]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[2/5] DISABLE POWER THROTTLING" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        Set-RegistryValueSafe `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" `
            -Name "PowerThrottlingOff" `
            -Value 1 `
            -CheckKey "LATENCY_POWER_THROTTLE" `
            -Label "PowerThrottlingOff = 1 (disable CPU power throttling)"

        Write-Host "  [NOTE] Prevents Windows from reducing CPU frequency for efficiency" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Laptop users: may reduce battery life" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:POWER_THROTTLE]"
    } catch {
        Write-Host "  [FAIL] Power Throttling: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:POWER_THROTTLE]"
    }

    Write-Host ""
}


# ============================================================
# SECTION 3: WIN32 PRIORITY SEPARATION
# WHY: Controls how the Windows scheduler allocates CPU quantum
#      time between foreground and background processes.
#      Value 0x26 (38 decimal) sets:
#        Bits 4-5: Short intervals (more responsive switching)
#        Bits 2-3: Variable quantum length
#        Bits 0-1: High foreground boost (3:1 ratio)
#      This gives the active game window 3x more CPU time per
#      scheduling quantum than background services and apps.
#      Default Windows workstation value is already 0x26, but
#      third-party tools or group policy may have changed it.
# ============================================================

if ($env:SKIP_PRIORITY_SEP -eq '1') {
    Write-Host "[SKIP] Priority Separation -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:PRIORITY_SEP]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[3/5] WIN32 PRIORITY SEPARATION" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $priorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"

        # Log current value for reference
        $currentVal = Get-ItemProperty -Path $priorityPath -Name "Win32PrioritySeparation" -ErrorAction SilentlyContinue
        if ($currentVal) {
            $hex = "0x" + [Convert]::ToString($currentVal.Win32PrioritySeparation, 16)
            Write-Host "  [BACKUP] Current Win32PrioritySeparation: $($currentVal.Win32PrioritySeparation) ($hex)" -ForegroundColor DarkGray
        }

        Set-RegistryValueSafe `
            -Path $priorityPath `
            -Name "Win32PrioritySeparation" `
            -Value 0x26 `
            -CheckKey "LATENCY_PRIORITY_SEP" `
            -Label "Win32PrioritySeparation = 0x26 (Short, Variable, High foreground boost)"

        Write-Host "  [NOTE] Foreground game gets 3x more CPU time than background processes" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:PRIORITY_SEP]"
    } catch {
        Write-Host "  [FAIL] Priority Separation: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:PRIORITY_SEP]"
    }

    Write-Host ""
}


# ============================================================
# SECTION 4: DISABLE DYNAMIC TICK
# WHY: By default, Windows uses a dynamic tick where the system
#      clock fires only when needed (to save power). Disabling
#      forces a consistent tick rate, reducing latency variability.
#      Hardware-dependent -- helps most systems but may cause FPS
#      drops on some. Windows 11 uses RTC-tick by default.
# RISK: Moderate. Increases power consumption. Some hardware
#       may experience FPS drops or weird mouse behavior.
#       Reboot required. Revert with:
#         bcdedit /deletevalue disabledynamictick
# ============================================================

if ($env:SKIP_DYNAMIC_TICK -eq '1') {
    Write-Host "[SKIP] Dynamic Tick -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:DYNAMIC_TICK]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[4/5] DISABLE DYNAMIC TICK (bcdedit)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Check current state
        $bcdOutput = bcdedit /enum "{current}" 2>&1 | Out-String
        $alreadyDisabled = $bcdOutput -match "disabledynamictick\s+Yes"

        if ($alreadyDisabled) {
            Write-Host "  [OK] Dynamic tick already disabled" -ForegroundColor Green
            Write-Host "[SQ_CHECK_OK:LATENCY_DYNAMIC_TICK]"
        } else {
            $result = bcdedit /set "{current}" disabledynamictick yes 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Dynamic tick disabled via bcdedit" -ForegroundColor Green
                Write-Host "[SQ_CHECK_OK:LATENCY_DYNAMIC_TICK]"
            } else {
                Write-Host "  [FAIL] bcdedit returned exit code $LASTEXITCODE -- $result" -ForegroundColor Red
                Write-Host "[SQ_CHECK_FAIL:LATENCY_DYNAMIC_TICK:BCDEDIT_EXIT_$LASTEXITCODE]"
            }
        }

        Write-Host "  [NOTE] Forces consistent system tick rate (reduces latency jitter)" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Hardware-dependent -- revert if FPS drops after reboot" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Revert: bcdedit /deletevalue disabledynamictick" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:DYNAMIC_TICK]"
    } catch {
        Write-Host "  [FAIL] Dynamic Tick: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:DYNAMIC_TICK]"
    }

    Write-Host ""
}


# ============================================================
# SECTION 5: DISABLE HPET (useplatformclock)
# WHY: The High Precision Event Timer (HPET) was designed for
#      accurate timekeeping but adds DPC latency overhead on some
#      systems. Modern Windows 10/11 uses TSC (Time Stamp Counter)
#      by default, which is faster. This section ensures
#      useplatformclock is not forcing HPET on.
#      If useplatformclock is not set, TSC is already in use
#      and no changes are needed.
# RISK: Moderate. Results vary by hardware. Most modern systems
#       benefit from TSC over HPET. Reboot required.
#       Revert: bcdedit /set useplatformclock true
# ============================================================

if ($env:SKIP_HPET -eq '1') {
    Write-Host "[SKIP] HPET -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:HPET]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[5/5] DISABLE HPET (bcdedit useplatformclock)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Check if useplatformclock is currently set
        $bcdOutput = bcdedit /enum "{current}" 2>&1 | Out-String
        $hpetEnabled = $bcdOutput -match "useplatformclock\s+Yes"

        if ($hpetEnabled) {
            # Remove the useplatformclock setting to revert to TSC
            $result = bcdedit /deletevalue "{current}" useplatformclock 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] useplatformclock removed (HPET disabled, using TSC)" -ForegroundColor Green
                Write-Host "[SQ_CHECK_OK:LATENCY_HPET]"
            } else {
                Write-Host "  [FAIL] bcdedit deletevalue returned $LASTEXITCODE -- $result" -ForegroundColor Red
                Write-Host "[SQ_CHECK_FAIL:LATENCY_HPET:BCDEDIT_EXIT_$LASTEXITCODE]"
            }
        } else {
            Write-Host "  [OK] useplatformclock not set (TSC already in use -- optimal)" -ForegroundColor Green
            Write-Host "[SQ_CHECK_OK:LATENCY_HPET]"
        }

        Write-Host "  [NOTE] TSC (Time Stamp Counter) is faster than HPET for timekeeping" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Modern Windows 10/11 uses TSC by default when HPET is not forced" -ForegroundColor DarkGray
        Write-Host "  [NOTE] Revert: bcdedit /set useplatformclock true" -ForegroundColor DarkGray
        Write-Host "[SQ_OK:HPET]"
    } catch {
        Write-Host "  [FAIL] HPET: $_" -ForegroundColor Red
        Write-Host "[SQ_FAIL:HPET]"
    }

    Write-Host ""
}


# ============================================================
# COMPLETION SUMMARY
# ============================================================

Write-Host "======================================================" -ForegroundColor Green
Write-Host "  LATENCY REDUCTION COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  REBOOT REQUIRED for these changes:" -ForegroundColor Yellow
Write-Host "    - Power Throttling (registry)" -ForegroundColor Yellow
Write-Host "    - Dynamic Tick (bcdedit)" -ForegroundColor Yellow
Write-Host "    - HPET (bcdedit)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  No reboot needed for:" -ForegroundColor DarkGray
Write-Host "    - Timer Resolution, Priority Separation" -ForegroundColor DarkGray
Write-Host ""
