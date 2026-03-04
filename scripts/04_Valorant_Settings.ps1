#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Valorant - PC Optimization Script
    Version: 2.0 | Updated: March 2026
    Engine: Unreal Engine 4 (custom fork)
    Anti-Cheat: Vanguard (kernel-level)

.DESCRIPTION
    Applies Windows EXE flags and Valorant config file optimizations.
    Valorant uses Riot Vanguard kernel-level anti-cheat. This script ONLY
    modifies user-accessible config files and OS-level compatibility flags.

    VALORANT OPTIMIZATION PHILOSOPHY:
    Valorant is a precision-based tactical shooter where frame rate consistency
    matters more than raw FPS numbers. The game runs well on low-end hardware
    and most competitive players prioritize 240+ FPS over visual quality.

    CONFIG FORMAT:
    Valorant uses a standard UE4 GameUserSettings.ini with 4 sections:
    - [/Script/ShooterGame.ShooterGameUserSettings] (display, resolution, hardware)
    - [/Script/Engine.GameUserSettings] (UE4 base - only bUseDesiredScreenHeight)
    - [ScalabilityGroups] (graphics quality scalability -- main performance keys)
    - [ShaderPipelineCache.CacheFile] (shader cache metadata -- do not modify)

    PATH STRUCTURE:
    %LOCALAPPDATA%\VALORANT\Saved\Config\<AccountID>\Windows\GameUserSettings.ini
    The <AccountID> folder varies per Riot account. We enumerate all subfolders.

    SOURCES:
    - github.com/JoShMiQueL/VALORANT-CONFIG
    - gist.github.com/geocine/db8d8ee9fdff240031f0762144abd827
    - github.com/SteffenCarlsen/ValorantForceLowSettings

.NOTES
    VANGUARD NOTE: Do not attempt to modify game files or memory.
    This script only touches user config and Windows compatibility flags.
    Editing GameUserSettings.ini while the game is closed is confirmed safe.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
$FrameRateLimit = Get-FrameRateLimit
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'VALORANT - Optimization Script' `
               -Subtitle 'March 2026 | UE4 Engine | Vanguard Anti-Cheat'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : Uncapped (higher FPS = lower input lag)" -ForegroundColor White
Write-Host ""

# =============================================================================
# INI PARSER: Read-Merge-Write for UE4 INI files
# =============================================================================

function Read-IniFile {
    param([string]$Path)
    $sections = [ordered]@{}
    $currentSection = ""
    foreach ($line in (Get-Content $Path)) {
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [ordered]@{}
            }
        } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
            $sections[$currentSection][$Matches[1]] = $Matches[2]
        }
    }
    return $sections
}

function Write-IniFile {
    param([string]$Path, [System.Collections.Specialized.OrderedDictionary]$Sections)
    $lines = New-Object System.Collections.Generic.List[string]
    $first = $true
    foreach ($sectionName in $Sections.Keys) {
        if (-not $first) { $lines.Add("") }
        $first = $false
        $lines.Add("[$sectionName]")
        foreach ($key in $Sections[$sectionName].Keys) {
            $lines.Add("$key=$($Sections[$sectionName][$key])")
        }
    }
    # Write UTF-8 without BOM -- Valorant is UE4 INI, not JSON,
    # but using no-BOM is still safest for cross-engine compatibility
    $content = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Merge-IniSection {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Existing,
        [string]$SectionName,
        [hashtable]$Overrides
    )
    if (-not $Existing.Contains($SectionName)) {
        $Existing[$SectionName] = [ordered]@{}
    }
    foreach ($key in $Overrides.Keys) {
        $Existing[$SectionName][$key] = $Overrides[$key]
    }
}

# =============================================================================
# SECTION 1: LOCATE AND WRITE VALORANT CONFIG
# =============================================================================
# Valorant stores configs under:
#   %LOCALAPPDATA%\VALORANT\Saved\Config\<AccountID>\Windows\GameUserSettings.ini
# Multiple AccountID folders may exist. We update ALL of them.

$ConfigRoot = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
$TargetConfigPaths = @()

try {
    if (Test-Path $ConfigRoot) {
        # Enumerate all account subfolders
        $accountDirs = Get-ChildItem -Path $ConfigRoot -Directory -ErrorAction SilentlyContinue
        foreach ($accountDir in $accountDirs) {
            $windowsDir = Join-Path $accountDir.FullName "Windows"
            $iniPath = Join-Path $windowsDir "GameUserSettings.ini"
            # Include folders that already have the config, or that have a Windows subfolder
            if ((Test-Path $iniPath) -or (Test-Path $windowsDir)) {
                $TargetConfigPaths += $iniPath
            }
        }
    }
} catch {
    Write-Host "[WARN] Error scanning config folders: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Fallback: if no account folders found, create under a default path
if ($TargetConfigPaths.Count -eq 0) {
    # Check if the VALORANT folder exists at all
    $valorantRoot = Join-Path $env:LOCALAPPDATA "VALORANT\Saved\Config"
    if (Test-Path $valorantRoot) {
        # Enumerate again -- maybe there are folders without a Windows subfolder
        $accountDirs = Get-ChildItem -Path $valorantRoot -Directory -ErrorAction SilentlyContinue
        foreach ($accountDir in $accountDirs) {
            $windowsDir = Join-Path $accountDir.FullName "Windows"
            if (-not (Test-Path $windowsDir)) {
                New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null
            }
            $TargetConfigPaths += (Join-Path $windowsDir "GameUserSettings.ini")
        }
    }

    if ($TargetConfigPaths.Count -eq 0) {
        Write-Host "[INFO] No Valorant config folders found. Valorant may not be installed." -ForegroundColor DarkCyan
        Write-Check -Status 'WARN' -Key 'VALORANT_CONFIG_WRITTEN' -Detail 'NO_CONFIG_FOLDER'
    }
}

Write-Host "[INFO] Found $($TargetConfigPaths.Count) Valorant config target(s)" -ForegroundColor DarkCyan

# --- Competitive settings to merge ---

# Performance keys for [/Script/ShooterGame.ShooterGameUserSettings]
# We ONLY override performance-related keys. Keys like DefaultMonitorDeviceID,
# WindowPosX/Y, benchmark results, and HDR settings are PRESERVED.
$ShooterGameOverrides = @{
    'bUseVSync'                  = 'False'
    'bUseDynamicResolution'      = 'False'
    'LastConfirmedFullscreenMode'= '0'
    'PreferredFullscreenMode'    = '1'
    'FrameRateLimit'             = "$FrameRateLimit.000000"
    'AudioQualityLevel'          = '0'
    'LastConfirmedAudioQualityLevel' = '0'
}

# [/Script/Engine.GameUserSettings] -- only one key lives here
$EngineOverrides = @{
    'bUseDesiredScreenHeight' = 'False'
}

# [ScalabilityGroups] -- these are the main graphics quality knobs
# WHY THESE VALUES:
# - sg.ResolutionQuality=100: Full native render, no upscaling
# - sg.ViewDistanceQuality=0: Reduces draw distance -- minimal competitive impact in Valorant
# - sg.AntiAliasingQuality=0: No AA for maximum clarity and FPS
# - sg.ShadowQuality=0: Shadows consume significant FPS with no competitive benefit
# - sg.PostProcessQuality=0: Removes post-process effects for cleaner visuals
# - sg.TextureQuality=3: Textures are cheap on VRAM, help with agent/wall clarity
# - sg.EffectsQuality=0: Reduces particle/explosion effects
# - sg.FoliageQuality=0: Reduces foliage rendering (minimal in Valorant maps)
# - sg.ShadingQuality=0: Reduces shading complexity for FPS
$ScalabilityOverrides = @{
    'sg.ResolutionQuality'    = '100.000000'
    'sg.ViewDistanceQuality'  = '0'
    'sg.AntiAliasingQuality'  = '0'
    'sg.ShadowQuality'        = '0'
    'sg.PostProcessQuality'   = '0'
    'sg.TextureQuality'       = '3'
    'sg.EffectsQuality'       = '0'
    'sg.FoliageQuality'       = '0'
    'sg.ShadingQuality'       = '0'
}

# [ShaderPipelineCache.CacheFile] -- preserve as-is, only ensure it exists
$ShaderCacheDefaults = @{
    'LastOpened' = 'ShooterGame'
}

$WriteSuccessCount = 0
$WriteFailures = @()

foreach ($ConfigPath in $TargetConfigPaths) {
    $ConfigDir = Split-Path $ConfigPath -Parent

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    try {
        # READ existing config if present
        if (Test-Path $ConfigPath) {
            Backup-ConfigFile -Path $ConfigPath | Out-Null

            # Parse existing INI
            $iniData = Read-IniFile -Path $ConfigPath
        } else {
            Write-Host "[INFO] No existing config at $ConfigPath -- creating fresh" -ForegroundColor DarkCyan
            $iniData = [ordered]@{}
        }

        # MERGE competitive settings into existing data (preserves all other keys)
        Merge-IniSection -Existing $iniData -SectionName '/Script/ShooterGame.ShooterGameUserSettings' -Overrides $ShooterGameOverrides
        Merge-IniSection -Existing $iniData -SectionName '/Script/Engine.GameUserSettings' -Overrides $EngineOverrides
        Merge-IniSection -Existing $iniData -SectionName 'ScalabilityGroups' -Overrides $ScalabilityOverrides
        Merge-IniSection -Existing $iniData -SectionName 'ShaderPipelineCache.CacheFile' -Overrides $ShaderCacheDefaults

        # WRITE with UTF-8 no BOM
        Write-IniFile -Path $ConfigPath -Sections $iniData

        # LOCK read-only to prevent Valorant from overwriting on exit
        Lock-ConfigFile -Path $ConfigPath

        # Verify the write
        $verifyContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($verifyContent -match 'sg\.ShadowQuality=0' -and $verifyContent -match 'FrameRateLimit=') {
            $WriteSuccessCount++
            Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green
        } else {
            $WriteFailures += "$ConfigPath (verification failed)"
            Write-Host "  [WARN] Config write verification failed: $ConfigPath" -ForegroundColor Yellow
        }
    } catch {
        $WriteFailures += "$ConfigPath ($($_.Exception.Message))"
        Write-Host "  [FAIL] Could not write config: $ConfigPath" -ForegroundColor Red
    }
}

$TotalTargets = $TargetConfigPaths.Count
if ($TotalTargets -eq 0) {
    # Already emitted WARN above
} elseif ($WriteSuccessCount -eq $TotalTargets) {
    Write-Check -Status 'OK' -Key 'VALORANT_CONFIG_WRITTEN' -Detail "$WriteSuccessCount/$TotalTargets"
} elseif ($WriteSuccessCount -gt 0) {
    Write-Check -Status 'WARN' -Key 'VALORANT_CONFIG_WRITTEN' -Detail "$WriteSuccessCount/$TotalTargets succeeded"
} else {
    Write-Check -Status 'FAIL' -Key 'VALORANT_CONFIG_WRITTEN' -Detail ($WriteFailures -join '; ')
}

# =============================================================================
# SECTION 2: EXE COMPATIBILITY FLAGS FOR VALORANT
# NOTE: Valorant has Vanguard anti-cheat. We ONLY set Windows-layer flags
#       that Windows itself applies before the process starts.
#       These are standard OS features, not modifications to game files.
# =============================================================================

$ValorantExePaths = @(
    "C:\Riot Games\VALORANT\live\VALORANT.exe",
    "C:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe",
    "D:\Riot Games\VALORANT\live\VALORANT.exe",
    "D:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe"
)

# Check env var from host app
if ($env:VALORANT_PATH -and (Test-Path $env:VALORANT_PATH)) {
    $ValorantExePaths = @($env:VALORANT_PATH) + $ValorantExePaths
}

# HIGHDPIAWARE only: Valorant works well with fullscreen optimizations ON (unlike most games)
$null = Set-ExeCompatFlags -ExePaths $ValorantExePaths -CheckKey 'VALORANT_EXE_FLAGS' -Flags @('HIGHDPIAWARE')

# =============================================================================
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# =============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  VALORANT - COMPLETE SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Display Mode           : Fullscreen" -ForegroundColor White
Write-Host "                         (Exclusive fullscreen = lowest input latency)" -ForegroundColor DarkGray
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Max Frame Rate         : Uncapped" -ForegroundColor White
Write-Host "  NVIDIA Reflex          : Enabled + Boost (most important setting)" -ForegroundColor White
Write-Host "                         Reduces system latency by 15-30ms" -ForegroundColor DarkGray
Write-Host "  Multithreaded Rendering: ON (required for 6+ core CPUs)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY ---" -ForegroundColor Cyan
Write-Host "  Material Quality       : Low" -ForegroundColor White
Write-Host "  Texture Quality        : High (cheap, improves wall/agent clarity)" -ForegroundColor White
Write-Host "  Detail Quality         : Low" -ForegroundColor White
Write-Host "  UI Quality             : Low" -ForegroundColor White
Write-Host "  Vignette               : OFF" -ForegroundColor White
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : None (or MSAA 2x for cleaner edges)" -ForegroundColor White
Write-Host "                         None = highest FPS, MSAA 2x = cleaner models" -ForegroundColor DarkGray
Write-Host "  Anisotropic Filtering  : 4x" -ForegroundColor White
Write-Host "  Improve Clarity        : ON (sharpens distant textures)" -ForegroundColor White
Write-Host "  Bloom                  : OFF" -ForegroundColor White
Write-Host "  Distortion             : OFF" -ForegroundColor White
Write-Host "  Cast Shadows           : OFF" -ForegroundColor White
Write-Host "  Shadows                : OFF" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO SETTINGS (COMPETITIVE) ---" -ForegroundColor Cyan
Write-Host "  Master Volume          : 80" -ForegroundColor White
Write-Host "  Music Volume           : 0 (silences lobby/death screen music)" -ForegroundColor White
Write-Host "  Sound FX Volume        : 100" -ForegroundColor White
Write-Host "  Voice Chat Volume      : 70" -ForegroundColor White
Write-Host "  Agent Voice Lines      : OFF (eliminates distraction during fights)" -ForegroundColor White
Write-Host "  HRTF (Headphones)      : ON (dramatically improves vertical audio)" -ForegroundColor White
Write-Host "                         Critical for hearing agents above/below you" -ForegroundColor DarkGray
Write-Host "  Windows Sonic/Dolby    : OFF if using HRTF (they conflict)" -ForegroundColor White

Write-Host ""
Write-Host "  --- SENSITIVITY ---" -ForegroundColor Cyan
Write-Host "  Sensitivity            : 0.3-0.5 (most pros in this range)" -ForegroundColor White
Write-Host "  Scoped Sens Multiplier : 1.0 (consistent muscle memory)" -ForegroundColor White
Write-Host "  Target eDPI            : 200-400 (sens x DPI)" -ForegroundColor White
Write-Host "  Example Pro Settings   :" -ForegroundColor DarkGray
Write-Host "    TenZ: 800 DPI x 0.40 = 320 eDPI" -ForegroundColor DarkGray
Write-Host "    Aspas: 800 DPI x 0.33 = 264 eDPI" -ForegroundColor DarkGray
Write-Host "    ScreaM: 800 DPI x 0.22 = 176 eDPI (low, but consistent)" -ForegroundColor DarkGray
Write-Host "  Mouse Filtering        : 0.00" -ForegroundColor White
Write-Host "  Raw Input Buffer       : OFF (can cause micro-stutters in Valorant)" -ForegroundColor White
Write-Host "  Polling Rate           : 1000Hz standard, 4000Hz if supported" -ForegroundColor White

Write-Host ""
Write-Host "  --- CROSSHAIR (COMPETITIVE META) ---" -ForegroundColor Cyan
Write-Host "  Outlines               : OFF (reduces visual clutter)" -ForegroundColor White
Write-Host "  Inner Line Length      : 4" -ForegroundColor White
Write-Host "  Inner Line Width       : 2" -ForegroundColor White
Write-Host "  Center Dot             : OFF (dot obscures target center)" -ForegroundColor White
Write-Host "  Color                  : Cyan or Green (highest visibility vs backgrounds)" -ForegroundColor White
Write-Host "  Movement Error         : OFF (crosshair stays static for consistency)" -ForegroundColor White
Write-Host "  Firing Error           : ON (shows spray pattern feedback)" -ForegroundColor White

Write-Host ""
Write-Host "  --- MINIMAP ---" -ForegroundColor Cyan
Write-Host "  Rotate                 : Rotate (keeps your perspective-relative)" -ForegroundColor White
Write-Host "  Keep Player Centered   : OFF" -ForegroundColor White
Write-Host "  Minimap Size           : 1.1" -ForegroundColor White
Write-Host "  Minimap Zoom           : 0.9" -ForegroundColor White

Write-Host ""
Write-Host "  --- PRO PLAYER REFERENCE (ProSettings.net) ---" -ForegroundColor Cyan
Write-Host "  598 pro players analyzed - universal consensus:" -ForegroundColor White
Write-Host "  - 100% use 1920x1080 or lower (no pro uses 1440p/4K in ranked)" -ForegroundColor White
Write-Host "  - 100% use Fullscreen (not borderless)" -ForegroundColor White
Write-Host "  - 100% V-Sync OFF" -ForegroundColor White
Write-Host "  - 0% shadows enabled" -ForegroundColor White
Write-Host "  - 95%+ NVIDIA Reflex Enabled + Boost" -ForegroundColor White
Write-Host "  - Median eDPI: 280" -ForegroundColor White

Write-Host ""
if ($script:ValidationFailed) {
    Write-Host "[FAIL] Valorant optimization completed with validation failures." -ForegroundColor Red
    exit 1
}

Write-Host "[DONE] Valorant config written. Apply remaining settings in-game." -ForegroundColor Green
Write-Host ""
