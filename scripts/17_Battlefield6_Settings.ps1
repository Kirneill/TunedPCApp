#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Battlefield 6 - PC Optimization Script
    Version: 1.0 | March 2026
    Engine: Frostbite (EA DICE)
    Anti-Cheat: EA Javelin (config edits are safe)

.DESCRIPTION
    Applies EXE compatibility flags and modifies the Battlefield 6 PROFSAVE_profile
    config file for maximum competitive performance. Uses read-merge-write to
    preserve user data (audio, input, keybindings, resolution) while overriding
    only performance-critical GstRender keys.

    WHAT THIS SCRIPT DOES:
    - Reads existing PROFSAVE_profile (preserves all non-performance settings)
    - Merges optimized competitive GstRender settings
    - Sets PROFSAVE_profile to read-only (prevents BF6 from overwriting on exit)
    - Sets Windows EXE flags for bf6.exe
    - Prints the full in-game settings guide

.NOTES
    Config file location:
    EA App:  %USERPROFILE%\Documents\Battlefield 6\settings\PROFSAVE_profile
    Steam:   %USERPROFILE%\Documents\Battlefield 6\settings\steam\PROFSAVE_profile

    KEY NAMES verified against real config dumps and community references.
    Do NOT rename without checking scripts/reference-configs/bf6-PROFSAVE_profile first.
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# --- USER CONFIGURATION -------------------------------------------------------
if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
    $NvidiaGPU      = $env:NVIDIA_GPU -eq '1'
} else {
    $MonitorWidth   = 1920
    $MonitorHeight  = 1080
    $MonitorRefresh = 240
    $NvidiaGPU      = $true
}
if ($MonitorRefresh -ge 144) {
    $FrameRateLimit = $MonitorRefresh - 3    # High-refresh: cap at refresh-3 for stable pacing
} else {
    $FrameRateLimit = 0                      # Sub-144Hz: uncapped
}
# ------------------------------------------------------------------------------

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FAIL', 'WARN')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Detail = ''
    )
    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { '' } else { ":$Detail" }
    Write-Host "[SQ_CHECK_${Status}:$Key$suffix]"
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Battlefield 6 - Optimization Script v1.0" -ForegroundColor Cyan
Write-Host "  March 2026 | Frostbite Engine" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
if ($FrameRateLimit -eq 0) {
    Write-Host "  FPS Cap           : Uncapped (monitor < 144Hz)" -ForegroundColor White
} else {
    Write-Host "  FPS Cap           : $FrameRateLimit (refresh-3 for stable pacing)" -ForegroundColor White
}
Write-Host "  GPU               : $(if ($NvidiaGPU) { 'NVIDIA' } else { 'AMD/Intel' })" -ForegroundColor White
Write-Host ""

# =============================================================================
# SECTION 1: LOCATE GAME AND SET EXE FLAGS
# =============================================================================

Write-Host "[SECTION 1] Locating Battlefield 6 and setting EXE flags..." -ForegroundColor Yellow
Write-Host ""

$GameExePath = $null

# Check env var from host app
if ($env:BF6_PATH) {
    $candidate = Join-Path $env:BF6_PATH "bf6.exe"
    if (Test-Path $candidate) { $GameExePath = $candidate }
}

# Check EA App registry
if (-not $GameExePath) {
    try {
        $eaPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\EA Games\Battlefield 6" -ErrorAction SilentlyContinue)."Install Dir"
        if ($eaPath) {
            $candidate = Join-Path $eaPath "bf6.exe"
            if (Test-Path $candidate) { $GameExePath = $candidate }
        }
    } catch {
        Write-Host "  [INFO] EA App registry check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Check Steam uninstall registry
if (-not $GameExePath) {
    try {
        $steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2807960" -ErrorAction SilentlyContinue).InstallLocation
        if ($steamPath) {
            $candidate = Join-Path $steamPath "bf6.exe"
            if (Test-Path $candidate) { $GameExePath = $candidate }
        }
    } catch {
        Write-Host "  [INFO] Steam registry check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Common install paths
if (-not $GameExePath) {
    $commonPaths = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Battlefield 6\bf6.exe",
        "D:\Steam\steamapps\common\Battlefield 6\bf6.exe",
        "D:\SteamLibrary\steamapps\common\Battlefield 6\bf6.exe",
        "E:\Steam\steamapps\common\Battlefield 6\bf6.exe",
        "E:\SteamLibrary\steamapps\common\Battlefield 6\bf6.exe",
        "C:\Program Files\EA Games\Battlefield 6\bf6.exe",
        "D:\EA Games\Battlefield 6\bf6.exe",
        "E:\EA Games\Battlefield 6\bf6.exe"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $GameExePath = $p
            break
        }
    }
}

if ($GameExePath) {
    Write-Host "  [FOUND] bf6.exe: $GameExePath" -ForegroundColor Green

    # Set AppCompat flags
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        $flags = "~ HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name $GameExePath -Value $flags -Force
        Write-Host "  [OK] EXE flags set: HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS" -ForegroundColor Green
        Write-Check -Status OK -Key BF6_EXE_FLAGS
    } catch {
        Write-Host "  [WARN] Failed to set EXE flags: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Check -Status WARN -Key BF6_EXE_FLAGS -Detail $_.Exception.Message
    }
} else {
    Write-Host "  [WARN] bf6.exe not found -- skipping EXE flags (config optimization will still apply)" -ForegroundColor Yellow
    Write-Check -Status WARN -Key BF6_EXE_FLAGS -Detail "EXE_NOT_FOUND"
}

# =============================================================================
# SECTION 2: WRITE OPTIMIZED PROFSAVE_profile (READ-MERGE-WRITE)
#
# Key names verified against: scripts/reference-configs/bf6-PROFSAVE_profile
# Sources: Real installations, ProSettings.net, Dexerto, community configs
#
# WHY each setting:
# - TextureQuality 2 (High): Enemy readability without GPU overhead
# - LightingQuality 0: Major FPS gain, minimal visual loss competitive
# - EffectsQuality 0: Reduces explosion/smoke clutter
# - UndergrowthQuality 0: Critical for visibility
# - ShadowQuality 0: Major FPS gain
# - AmbientOcclusion 0: No competitive benefit
# - MotionBlurWorld/Weapon 0: Clarity during movement
# - NvidiaLowLatency 2 (On+Boost): Critical for latency
# - FutureFrameRendering 1: 30-50% FPS uplift
# - FrameGeneration 0: Adds latency
# - VSyncMode 0: Always off competitive
# =============================================================================

Write-Host ""
Write-Host "[SECTION 2] Writing optimized Battlefield 6 config..." -ForegroundColor Yellow
Write-Host ""

# Build the competitive settings hashtable
$CompetitiveSettings = [ordered]@{
    'GstRender.OverallGraphicsQuality'       = '5'
    'GstRender.TextureQuality'               = '2'
    'GstRender.TextureFiltering'             = '2'
    'GstRender.LightingQuality'              = '0'
    'GstRender.EffectsQuality'               = '0'
    'GstRender.PostProcessQuality'           = '0'
    'GstRender.MeshQuality'                  = '1'
    'GstRender.UndergrowthQuality'           = '0'
    'GstRender.TerrainQuality'               = '1'
    'GstRender.VolumetricQuality'            = '0'
    'GstRender.ShadowQuality'                = '0'
    'GstRender.SunShadowQuality'             = '0'
    'GstRender.LocalLightShadowQuality'      = '0'
    'GstRender.ShadowFiltering'              = '0'
    'GstRender.ReflectionQuality'            = '0'
    'GstRender.SignificanceQuality'           = '0'
    'GstRender.AmbientOcclusion'             = '0'
    'GstRender.NvidiaAntiAliasing'           = '1'
    'GstRender.NvidiaUpscalingTechnique'     = '0'
    'GstRender.NVIDIAFrameGenerationEnabled' = '0'
    'GstRender.NvidiaMultiFrameGeneration'   = '0'
    'GstRender.AMDFrameGenerationEnabled'    = '0'
    'GstRender.AMDIntelUpscalingTechnique'   = '0'
    'GstRender.IntelFrameGenerationEnabled'  = '0'
    'GstRender.FrameGeneration'              = '0'
    'GstRender.FutureFrameRendering'         = '1'
    'GstRender.NvidiaLowLatency'             = '2'
    'GstRender.DRSEnabled'                   = '0'
    'GstRender.VSyncMode'                    = '0'
    'GstRender.HighDynamicRangeMode'         = '0'
    'GstRender.Dx12Enabled'                  = '1'
    'GstRender.GpuMemRestriction'            = '0'
    'GstRender.MotionBlurWorld'              = '0.000000'
    'GstRender.MotionBlurWeapon'             = '0.000000'
    'GstRender.ChromaticAberration'          = '0'
    'GstRender.FilmGrain'                    = '0'
    'GstRender.Vignette'                     = '0'
    'GstRender.LensDistortion'              = '0'
    'GstRender.WeaponDOF'                    = '0'
    'GstRender.ScreenSpaceReflections'       = '0'
}

# Frame rate limit (dynamic based on monitor refresh)
if ($FrameRateLimit -gt 0) {
    $CompetitiveSettings['GstRender.FrameRateLimiterEnable'] = '1'
    $CompetitiveSettings['GstRender.FrameRateLimit'] = "$FrameRateLimit"
} else {
    $CompetitiveSettings['GstRender.FrameRateLimiterEnable'] = '0'
    $CompetitiveSettings['GstRender.FrameRateLimit'] = '0'
}

# Validate USERPROFILE
if (-not $env:USERPROFILE) {
    Write-Host "  [FAIL] USERPROFILE environment variable is not set" -ForegroundColor Red
    Write-Check -Status FAIL -Key BF6_CONFIG_WRITTEN -Detail "USERPROFILE not set"
    return
}

# Locate PROFSAVE_profile -- check both EA App and Steam paths
$DocsRoot = Join-Path $env:USERPROFILE "Documents\Battlefield 6\settings"
$TargetPaths = @()

$eaAppPath = Join-Path $DocsRoot "PROFSAVE_profile"
$steamSubPath = Join-Path $DocsRoot "steam\PROFSAVE_profile"

if (Test-Path $eaAppPath) { $TargetPaths += $eaAppPath }
if (Test-Path $steamSubPath) { $TargetPaths += $steamSubPath }

# If neither exists, default to EA App path (create directory)
if ($TargetPaths.Count -eq 0) {
    $TargetPaths += $eaAppPath
}

$WriteSuccessCount = 0
$WriteFailures = @()

foreach ($ConfigPath in $TargetPaths) {
    $ConfigDir = Split-Path $ConfigPath -Parent

    if (-not (Test-Path $ConfigDir)) {
        try {
            New-Item -ItemType Directory -Path $ConfigDir -Force -ErrorAction Stop | Out-Null
        } catch {
            $WriteFailures += $ConfigPath
            Write-Host "  [FAIL] Cannot create directory: $ConfigDir -- $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }

    try {
        # --- Read existing config into ordered dictionary ---
        $existingSettings = [ordered]@{}

        if (Test-Path $ConfigPath) {
            # Remove read-only before reading
            Set-ItemProperty -Path $ConfigPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

            # Backup existing config
            $BackupPath = "$ConfigPath.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
            Copy-Item $ConfigPath $BackupPath -Force -ErrorAction Stop
            Write-Host "  [BACKUP] Config backed up to: $BackupPath" -ForegroundColor Yellow

            # Parse existing key-value pairs
            foreach ($line in (Get-Content $ConfigPath)) {
                if ($line -match '^(\S+)\s+(.+)$') {
                    $existingSettings[$Matches[1]] = $Matches[2]
                }
            }
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
            [void]$sb.AppendLine("$key $($existingSettings[$key])")
        }

        # Write UTF-8 without BOM
        [System.IO.File]::WriteAllText($ConfigPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

        # Set read-only to prevent BF6 from overwriting
        try {
            Set-ItemProperty -Path $ConfigPath -Name IsReadOnly -Value $true -ErrorAction Stop
        } catch {
            Write-Host "  [WARN] Could not set read-only flag -- BF6 may overwrite on exit: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Verify key content was written
        $verifyContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if (-not $verifyContent) {
            $WriteFailures += $ConfigPath
            Write-Host "  [FAIL] Cannot read config back for verification: $ConfigPath" -ForegroundColor Red
        } elseif ($verifyContent -match 'GstRender\.ShadowQuality 0' -and $verifyContent -match 'GstRender\.VSyncMode 0' -and $verifyContent -match 'GstRender\.FutureFrameRendering 1') {
            $WriteSuccessCount++
            Write-Host "  [OK] Config written and locked: $ConfigPath" -ForegroundColor Green
        } else {
            $WriteFailures += $ConfigPath
            Write-Host "  [FAIL] Config verification failed: $ConfigPath" -ForegroundColor Red
        }
    } catch {
        $WriteFailures += $ConfigPath
        Write-Host "  [FAIL] Error writing config: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($WriteSuccessCount -gt 0 -and $WriteFailures.Count -eq 0) {
    Write-Check -Status OK -Key BF6_CONFIG_WRITTEN
} elseif ($WriteSuccessCount -gt 0) {
    Write-Check -Status WARN -Key BF6_CONFIG_WRITTEN -Detail "Partial: $WriteSuccessCount OK, $($WriteFailures.Count) failed"
} else {
    Write-Check -Status FAIL -Key BF6_CONFIG_WRITTEN -Detail "All config writes failed"
}

# =============================================================================
# SECTION 3: IN-GAME SETTINGS GUIDE
# =============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Battlefield 6 -- In-Game Settings Guide" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  The following settings were applied via config file:" -ForegroundColor White
Write-Host ""
Write-Host "  GRAPHICS:" -ForegroundColor Yellow
Write-Host "    Texture Quality          : High" -ForegroundColor White
Write-Host "    Texture Filtering        : High" -ForegroundColor White
Write-Host "    Lighting Quality         : Low" -ForegroundColor White
Write-Host "    Effects Quality          : Low" -ForegroundColor White
Write-Host "    Post-Process Quality     : Low" -ForegroundColor White
Write-Host "    Mesh Quality             : Medium" -ForegroundColor White
Write-Host "    Undergrowth Quality      : Low" -ForegroundColor White
Write-Host "    Terrain Quality          : Medium" -ForegroundColor White
Write-Host "    Volumetric Quality       : Low" -ForegroundColor White
Write-Host "    Shadow Quality           : Low" -ForegroundColor White
Write-Host "    Ambient Occlusion        : Off" -ForegroundColor White
Write-Host "    Reflection Quality       : Low" -ForegroundColor White
Write-Host ""
Write-Host "  DISPLAY:" -ForegroundColor Yellow
Write-Host "    VSync                    : Off" -ForegroundColor White
Write-Host "    HDR                      : Off" -ForegroundColor White
Write-Host "    DirectX 12               : On" -ForegroundColor White
if ($FrameRateLimit -gt 0) {
    Write-Host "    Frame Rate Limit         : $FrameRateLimit fps" -ForegroundColor White
} else {
    Write-Host "    Frame Rate Limit         : Uncapped" -ForegroundColor White
}
Write-Host ""
Write-Host "  RENDERING:" -ForegroundColor Yellow
Write-Host "    Future Frame Rendering   : On (30-50%% FPS boost)" -ForegroundColor White
Write-Host "    NVIDIA Reflex            : On + Boost" -ForegroundColor White
Write-Host "    Frame Generation         : Off (adds latency)" -ForegroundColor White
Write-Host "    Dynamic Resolution       : Off" -ForegroundColor White
Write-Host "    GPU Memory Restriction   : Off" -ForegroundColor White
Write-Host ""
Write-Host "  VISUAL EFFECTS:" -ForegroundColor Yellow
Write-Host "    Motion Blur (World)      : Off" -ForegroundColor White
Write-Host "    Motion Blur (Weapon)     : Off" -ForegroundColor White
Write-Host "    Chromatic Aberration     : Off" -ForegroundColor White
Write-Host "    Film Grain               : Off" -ForegroundColor White
Write-Host "    Vignette                 : Off" -ForegroundColor White
Write-Host "    Lens Distortion          : Off" -ForegroundColor White
Write-Host "    Weapon DOF               : Off" -ForegroundColor White
Write-Host ""
Write-Host "  SET MANUALLY IN-GAME:" -ForegroundColor Magenta
Write-Host "    FOV                      : 90-105 (personal preference)" -ForegroundColor White
Write-Host "    Sensitivity              : Match your other FPS games" -ForegroundColor White
Write-Host ""
Write-Host "  NOTE: Config is READ-ONLY. To change settings in-game," -ForegroundColor DarkYellow
Write-Host "  re-run this optimization after making changes." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Battlefield 6 optimization complete!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
