#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EA Sports FC 26 - PC Optimization Script
    Version: 1.0 | March 2026
    Engine: Frostbite (EA Vancouver)
    Anti-Cheat: EA Javelin (config edits are safe)

.DESCRIPTION
    Applies EXE compatibility flags and modifies the fcsetup.ini config file
    for maximum competitive performance. Uses read-merge-write to preserve
    user data (resolution, display mode) while overriding only performance keys.

    WHAT THIS SCRIPT DOES:
    - Reads existing fcsetup.ini (preserves non-performance settings)
    - Merges optimized competitive settings
    - Sets fcsetup.ini to read-only (prevents FC26 from overwriting on exit)
    - Sets Windows EXE flags for FC26.exe
    - Prints the full in-game settings guide

.NOTES
    Config file location:
    %LOCALAPPDATA%\EA SPORTS FC 26\fcsetup.ini

    KEY NAMES verified against community sources and EA Pitch Notes.
    Do NOT rename without checking scripts/reference-configs/eafc26-fcsetup.ini first.

    KNOWN BUG: The in-game RenderingQuality preset can override custom per-setting
    values at halftime or on match load. Setting fcsetup.ini to read-only mitigates
    this but does not fully eliminate it. Users should also set Graphics Preset to
    "Custom" in-game.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# ------------------------------------------------------------------------------

Write-SQHeader -Title 'EA Sports FC 26 - Optimization Script v1.0' `
               -Subtitle 'March 2026 | Frostbite Engine'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : Uncapped (higher FPS = lower input lag)" -ForegroundColor White
Write-Host "  GPU               : $(if ($NvidiaGPU) { 'NVIDIA' } else { 'AMD/Intel' })" -ForegroundColor White
Write-Host ""

# =============================================================================
# SECTION 1: LOCATE GAME AND SET EXE FLAGS
# =============================================================================

Write-Host "[SECTION 1] Locating EA Sports FC 26 and setting EXE flags..." -ForegroundColor Yellow
Write-Host ""

$GameExePath = $null

# Check env var from host app
if ($env:EAFC26_PATH) {
    $candidate = Join-Path $env:EAFC26_PATH "FC26.exe"
    if (Test-Path $candidate) { $GameExePath = $candidate }
}

# Check EA App registry (uninstall key)
if (-not $GameExePath) {
    try {
        $eaPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{CC38BDAB-B776-4908-9A26-CC27C96404C2}" -ErrorAction SilentlyContinue).InstallLocation
        if ($eaPath) {
            $candidate = Join-Path $eaPath "FC26.exe"
            if (Test-Path $candidate) { $GameExePath = $candidate }
        }
    } catch {
        Write-Host "  [INFO] EA App registry check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Check Steam uninstall registry (App ID 3405690)
if (-not $GameExePath) {
    try {
        $steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 3405690" -ErrorAction SilentlyContinue).InstallLocation
        if ($steamPath) {
            $candidate = Join-Path $steamPath "FC26.exe"
            if (Test-Path $candidate) { $GameExePath = $candidate }
        }
    } catch {
        Write-Host "  [INFO] Steam registry check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Common install paths
if (-not $GameExePath) {
    $commonPaths = @(
        "C:\Program Files\EA Games\EA SPORTS FC 26\FC26.exe",
        "D:\EA Games\EA SPORTS FC 26\FC26.exe",
        "E:\EA Games\EA SPORTS FC 26\FC26.exe",
        "C:\Program Files (x86)\Steam\steamapps\common\FC 26\FC26.exe",
        "D:\Steam\steamapps\common\FC 26\FC26.exe",
        "D:\SteamLibrary\steamapps\common\FC 26\FC26.exe",
        "E:\Steam\steamapps\common\FC 26\FC26.exe",
        "E:\SteamLibrary\steamapps\common\FC 26\FC26.exe"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $GameExePath = $p
            break
        }
    }
}

if ($GameExePath) {
    Write-Host "  [FOUND] FC26.exe: $GameExePath" -ForegroundColor Green

    # Also flag FC26_Showcase.exe if it exists alongside the main exe
    $showcaseExe = Join-Path (Split-Path $GameExePath -Parent) "FC26_Showcase.exe"
    $exesToFlag = @($GameExePath)
    if (Test-Path $showcaseExe) { $exesToFlag += $showcaseExe }

    $null = Set-ExeCompatFlags -ExePaths $exesToFlag -CheckKey 'EAFC26_EXE_FLAGS'
} else {
    Write-Host "  [WARN] FC26.exe not found -- skipping EXE flags (config optimization will still apply)" -ForegroundColor Yellow
    Write-Check -Status WARN -Key EAFC26_EXE_FLAGS -Detail "EXE_NOT_FOUND"
}

# =============================================================================
# SECTION 2: WRITE OPTIMIZED fcsetup.ini (READ-MERGE-WRITE)
#
# Key names verified against: scripts/reference-configs/eafc26-fcsetup.ini
# Sources: EA Pitch Notes, Hone Blog, PCGamesN, AllThings.How, EA Forums
#
# WHY each setting:
# - RENDERING_QUALITY 1 (Medium): Largest FPS gain, visually identical in-match
# - DYNAMIC_AO_QUALITY 0 (Low): Up to 20% FPS gain vs High
# - STRAND_BASED_HAIR 0 (Off): 4%+ FPS gain, invisible during gameplay
# - CLOTH_QUALITY 0 (Low): Jersey physics -- indistinguishable at 60+ FPS
# - GRASS_QUALITY 1 (Medium): Low looks bad on pitch, Medium is optimal
# - CROWD_QUALITY 1 (Medium): Balances atmosphere and CPU load
# - MOTION_BLUR 0 (Off): Always off for competitive clarity
# - WAITFORVSYNC 0 (Off): Eliminates input lag from VSync
# - MAX_FRAME_RATE 0 (Uncapped): Higher FPS = lower input latency
# - DYNAMIC_RESOLUTION 0 (Off): Prevents resolution fluctuations mid-match
# - RENDERING_SCALE 1.0: Native resolution -- never reduce for competitive
# =============================================================================

Write-Host ""
Write-Host "[SECTION 2] Writing optimized EA Sports FC 26 config..." -ForegroundColor Yellow
Write-Host ""

# Build the competitive settings hashtable
$CompetitiveSettings = [ordered]@{
    'WAITFORVSYNC'                 = '0'
    'MAX_FRAME_RATE'               = '0'
    'REFRESH_RATE'                 = "$MonitorRefresh"
    'RENDERING_QUALITY'            = '1'
    'GRASS_QUALITY'                = '1'
    'CROWD_QUALITY'                = '1'
    'CLOTH_QUALITY'                = '0'
    'DYNAMIC_AO_QUALITY'           = '0'
    'MOTION_BLUR'                  = '0'
    'STRAND_BASED_HAIR'            = '0'
    'DYNAMIC_RESOLUTION'           = '0'
    'RENDERING_SCALE'              = '1.0'
    'FULLSCREEN'                   = '1'
    'WINDOWED_BORDERLESS'          = '0'
}

# Validate LOCALAPPDATA
$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) {
    Write-Host "  [FAIL] LOCALAPPDATA environment variable is not set" -ForegroundColor Red
    Write-Check -Status FAIL -Key EAFC26_CONFIG_WRITTEN -Detail "LOCALAPPDATA not set"
    return
}

# Locate fcsetup.ini
$ConfigDir = Join-Path $localAppData "EA SPORTS FC 26"
$ConfigPath = Join-Path $ConfigDir "fcsetup.ini"

if (-not (Test-Path $ConfigDir)) {
    try {
        New-Item -ItemType Directory -Path $ConfigDir -Force -ErrorAction Stop | Out-Null
        Write-Host "  [INFO] Created config directory: $ConfigDir" -ForegroundColor DarkCyan
    } catch {
        Write-Host "  [FAIL] Cannot create directory: $ConfigDir -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Check -Status FAIL -Key EAFC26_CONFIG_WRITTEN -Detail "Cannot create config directory"
        return
    }
}

try {
    # --- Read existing config into ordered dictionary ---
    $existingSettings = [ordered]@{}

    if (Test-Path $ConfigPath) {
        Backup-ConfigFile -Path $ConfigPath | Out-Null

        # Parse existing key-value pairs (format: KEY = VALUE)
        foreach ($line in (Get-Content $ConfigPath)) {
            if ($line -match '^\s*(\S+)\s*=\s*(.+?)\s*$') {
                $existingSettings[$Matches[1]] = $Matches[2]
            }
        }
        Write-Host "  [INFO] Read existing config with $($existingSettings.Count) settings" -ForegroundColor DarkCyan
    } else {
        Write-Host "  [INFO] No existing config found -- creating new: $ConfigPath" -ForegroundColor DarkCyan
    }

    # --- Merge competitive settings (override only performance keys) ---
    foreach ($key in $CompetitiveSettings.Keys) {
        $existingSettings[$key] = $CompetitiveSettings[$key]
    }

    # --- Write merged config ---
    $sb = [System.Text.StringBuilder]::new()
    foreach ($key in $existingSettings.Keys) {
        [void]$sb.AppendLine("$key = $($existingSettings[$key])")
    }

    # Write UTF-8 without BOM
    [System.IO.File]::WriteAllText($ConfigPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

    # Set read-only to prevent FC26 from overwriting on exit
    Lock-ConfigFile -Path $ConfigPath

    # Verify key content was written
    $verifyContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
    if (-not $verifyContent) {
        Write-Host "  [FAIL] Cannot read config back for verification: $ConfigPath" -ForegroundColor Red
        Write-Check -Status FAIL -Key EAFC26_CONFIG_WRITTEN -Detail "Verification read failed"
    } elseif ($verifyContent -match 'WAITFORVSYNC\s*=\s*0' -and $verifyContent -match 'RENDERING_QUALITY\s*=\s*1' -and $verifyContent -match 'MOTION_BLUR\s*=\s*0') {
        Write-Host "  [OK] Config written and locked: $ConfigPath" -ForegroundColor Green
        Write-Check -Status OK -Key EAFC26_CONFIG_WRITTEN
    } else {
        Write-Host "  [FAIL] Config verification failed: $ConfigPath" -ForegroundColor Red
        Write-Check -Status FAIL -Key EAFC26_CONFIG_WRITTEN -Detail "Key verification mismatch"
    }
} catch {
    Write-Host "  [FAIL] Error writing config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Check -Status FAIL -Key EAFC26_CONFIG_WRITTEN -Detail $_.Exception.Message
}

# =============================================================================
# SECTION 3: IN-GAME SETTINGS GUIDE
# =============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  EA Sports FC 26 -- In-Game Settings Guide" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  The following settings were applied via config file:" -ForegroundColor White
Write-Host ""
Write-Host "  DISPLAY:" -ForegroundColor Yellow
Write-Host "    VSync                    : Off" -ForegroundColor White
Write-Host "    Frame Rate Limit         : Uncapped" -ForegroundColor White
Write-Host "    Refresh Rate             : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "    Dynamic Resolution       : Off" -ForegroundColor White
Write-Host "    Render Scale             : 100%% (1.0)" -ForegroundColor White
Write-Host "    Display Mode             : Fullscreen Exclusive" -ForegroundColor White
Write-Host ""
Write-Host "  GRAPHICS:" -ForegroundColor Yellow
Write-Host "    Rendering Quality        : Medium" -ForegroundColor White
Write-Host "    Grass Quality            : Medium" -ForegroundColor White
Write-Host "    Crowd Quality            : Medium" -ForegroundColor White
Write-Host "    Cloth Quality            : Low" -ForegroundColor White
Write-Host "    Ambient Occlusion        : Low" -ForegroundColor White
Write-Host "    Strand-Based Hair        : Off" -ForegroundColor White
Write-Host "    Motion Blur              : Off" -ForegroundColor White
Write-Host ""
Write-Host "  SET MANUALLY IN-GAME:" -ForegroundColor Magenta
Write-Host "    Graphics Preset          : Custom (prevents preset override bug)" -ForegroundColor White
Write-Host "    Anti-Aliasing            : Set in-game (no config key)" -ForegroundColor White
Write-Host "    Cutscene Performance     : Full Frame Rate" -ForegroundColor White
Write-Host ""
Write-Host "  GPU DRIVER (set via NVIDIA Control Panel / AMD Software):" -ForegroundColor Magenta
if ($NvidiaGPU) {
    Write-Host "    Low Latency Mode         : Ultra (no Reflex in FC26)" -ForegroundColor White
    Write-Host "    Max Frame Rate           : $($MonitorRefresh - 3) (monitor Hz - 3)" -ForegroundColor White
    Write-Host "    Power Management         : Prefer Maximum Performance" -ForegroundColor White
} else {
    Write-Host "    Radeon Anti-Lag           : Enabled" -ForegroundColor White
    Write-Host "    FPS Cap (AMD Software)   : $($MonitorRefresh - 3)" -ForegroundColor White
}
Write-Host ""
Write-Host "  NOTE: Config is READ-ONLY. The game cannot overwrite it." -ForegroundColor DarkYellow
Write-Host "  To change settings, re-run this optimization after editing." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  KNOWN ISSUE: Graphics preset may override settings at halftime." -ForegroundColor DarkYellow
Write-Host "  Set Graphics Preset to 'Custom' in-game to minimize this." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  EA Sports FC 26 optimization complete!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
