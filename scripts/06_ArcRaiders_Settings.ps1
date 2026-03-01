#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Arc Raiders - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Engine: Unreal Engine 5

.DESCRIPTION
    Applies Windows EXE flags for Arc Raiders competitive optimization.
    Arc Raiders uses Unreal Engine 5 and has most settings in-game.

    ARC RAIDERS OPTIMIZATION PHILOSOPHY:
    Unlike pure competitive shooters, Arc Raiders is a PvPvE extraction game
    where visual clarity matters for both PvP fights and environmental awareness.
    Settings balance maximum FPS with maintaining enemy visibility, especially:
    - Shadow settings (Medium minimum - Low disables player shadows = big disadvantage)
    - Upscaling is recommended for performance gains
    - Night Mode audio is critical for hearing enemy footsteps

.NOTES
    Arc Raiders is Unreal Engine 5, so DLSS/FSR performance can be excellent.
    As of early access 2026, the game occasionally stutters during shader
    compilation on first run - this improves after the first hour of gameplay.
    Patch 1.0.7 significantly improved shadow LOD transitions.
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# --- USER CONFIGURATION - EDIT THESE VALUES ----------------------------------
# When run from SENSEQUALITY app, these are overridden by environment variables.

if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
    $NvidiaGPU      = $env:NVIDIA_GPU -eq '1'
} else {
    $MonitorWidth   = 1920
    $MonitorHeight  = 1080
    $MonitorRefresh = 240
    $NvidiaGPU      = $true   # $true for NVIDIA DLSS, $false for AMD FSR
}
# -----------------------------------------------------------------------------

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Arc Raiders - Optimization Script" -ForegroundColor Cyan
Write-Host "  February 2026 | Unreal Engine 5" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE ARC RAIDERS AND SET EXE FLAGS
# -----------------------------------------------------------------------------

function Add-UniquePath {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not $List.Contains($Path)) { $List.Add($Path) }
}

$ArcRaidersPaths = New-Object 'System.Collections.Generic.List[string]'

# If provided by host process, trust this first.
$DetectedArcPath = $env:ARC_RAIDERS_PATH
if (-not [string]::IsNullOrWhiteSpace($DetectedArcPath)) {
    if ($DetectedArcPath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
        Add-UniquePath -List $ArcRaidersPaths -Path $DetectedArcPath
    } else {
        Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $DetectedArcPath "ArcRaiders.exe")
        Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $DetectedArcPath "Binaries\Win64\ArcRaiders-Win64-Shipping.exe")
        # UE5 internal project name "PioneerGame" — some installs use this subdirectory
        Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $DetectedArcPath "PioneerGame\Binaries\Win64\PioneerGame-Win64-Shipping.exe")
        Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $DetectedArcPath "PioneerGame\Binaries\Win64\ArcRaiders-Win64-Shipping.exe")
    }
}

$CommonArcRoots = @(
    "$env:PROGRAMFILES(x86)\Steam\steamapps\common\ArcRaiders",
    "$env:PROGRAMFILES(x86)\Steam\steamapps\common\Arc Raiders",
    "$env:PROGRAMFILES\Steam\steamapps\common\ArcRaiders",
    "$env:PROGRAMFILES\Steam\steamapps\common\Arc Raiders",
    "C:\Steam\steamapps\common\ArcRaiders",
    "C:\Steam\steamapps\common\Arc Raiders",
    "C:\SteamLibrary\steamapps\common\ArcRaiders",
    "C:\SteamLibrary\steamapps\common\Arc Raiders",
    "D:\Steam\steamapps\common\ArcRaiders",
    "D:\Steam\steamapps\common\Arc Raiders",
    "D:\SteamLibrary\steamapps\common\ArcRaiders",
    "D:\SteamLibrary\steamapps\common\Arc Raiders",
    "E:\Steam\steamapps\common\ArcRaiders",
    "E:\Steam\steamapps\common\Arc Raiders",
    "E:\SteamLibrary\steamapps\common\ArcRaiders",
    "E:\SteamLibrary\steamapps\common\Arc Raiders",
    "C:\Program Files\Epic Games\ArcRaiders",
    "D:\Epic Games\ArcRaiders",
    "E:\Epic Games\ArcRaiders"
)

foreach ($root in $CommonArcRoots) {
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "ArcRaiders.exe")
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "Binaries\Win64\ArcRaiders-Win64-Shipping.exe")
    # UE5 internal project name "PioneerGame" — some installs use this subdirectory
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "PioneerGame\Binaries\Win64\PioneerGame-Win64-Shipping.exe")
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "PioneerGame\Binaries\Win64\ArcRaiders-Win64-Shipping.exe")
}

$AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

$foundExe = $false
foreach ($exePath in $ArcRaidersPaths) {
    if (Test-Path $exePath) {
        Set-ItemProperty -Path $AppCompatLayers -Name $exePath -Value "~ HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS" -Type String -Force
        Write-Host "  [OK] EXE flags set for: $exePath" -ForegroundColor Green
        $foundExe = $true
    }
}

if (-not $foundExe) {
    Write-Host "[WARN] Arc Raiders executable not found in common Steam paths." -ForegroundColor Yellow
    Write-Host "       To set manually: Right-click ArcRaiders.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
    Write-Host "[SQ_CHECK_WARN:ARC_EXE_FLAGS:EXE_NOT_FOUND]"
} else {
    Write-Host "[SQ_CHECK_OK:ARC_EXE_FLAGS]"
}

# -----------------------------------------------------------------------------
# SECTION 2: UE5 ENGINE CONFIG OVERRIDE
# Unreal Engine 5 games support an Engine.ini override in the user folder
# -----------------------------------------------------------------------------

$ConfigRootCandidates = @(
    "$env:LOCALAPPDATA\ArcRaiders\Saved\Config",
    "$env:LOCALAPPDATA\Arc Raiders\Saved\Config",
    "$env:LOCALAPPDATA\ARCRaiders\Saved\Config",
    "$env:LOCALAPPDATA\ArcRaidersGame\Saved\Config"
)

$PlatformDirs = @("Windows", "WindowsClient", "WindowsNoEditor", "WinGDK")
$TargetConfigDirs = New-Object 'System.Collections.Generic.List[string]'

foreach ($root in $ConfigRootCandidates) {
    if (-not (Test-Path $root)) { continue }
    foreach ($platform in $PlatformDirs) {
        $dirPath = Join-Path $root $platform
        if (Test-Path $dirPath) {
            Add-UniquePath -List $TargetConfigDirs -Path $dirPath
        }
    }
}

if ($TargetConfigDirs.Count -eq 0) {
    $fallbackDir = "$env:LOCALAPPDATA\ArcRaiders\Saved\Config\WindowsClient"
    New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
    Add-UniquePath -List $TargetConfigDirs -Path $fallbackDir
    Write-Host "[INFO] No existing Arc config folders found. Created fallback: $fallbackDir" -ForegroundColor DarkCyan
}

$AnyConfigWritten = $false
$WrittenCount = 0

# UE5 Engine.ini performance tweaks
# These are user-side engine config overrides (safe, no anti-cheat conflict)
$EngineIniContent = @"
[SystemSettings]
; Reduces shader compilation stutter on new areas
r.ShaderPipelineCache.Mode=1
r.ShaderPipelineCache.BackgroundBatchSize=0
; Reduces PSO compilation hitches at runtime
r.PSOPrecache.Validation=0
; Smoother streaming of world geometry
r.Streaming.MipBias=0
; Disable temporal dithering (cleaner image)
r.TemporalAASamples=8
; Reduce GPU memory fragmentation
r.streaming.limitpoolsizetodownloadedmips=1
; Ambient Occlusion OFF for competitive clarity
r.AmbientOcclusionLevels=0
; Screen Space Ambient Occlusion OFF
r.SSAO.Enabled=0
; Lens flare OFF (visual distraction)
r.LensFlareQuality=0
; Bloom OFF (reduces visual noise)
r.BloomQuality=0
; Depth of Field OFF (clarity at all ranges)
r.DepthOfFieldQuality=0
; Motion Blur OFF
r.MotionBlurQuality=0
; Film grain OFF
r.Tonemapper.GrainQuantization=0
; Reduce draw call overhead
r.DynamicGlobalIlluminationMethod=0

[ConsoleVariables]
; Ensures engine tweaks load immediately
r.Streaming.FullyLoadUsedTextures=1
"@

$GameUserSettingsContent = @"
[/Script/Engine.GameUserSettings]
bUseVSync=False
FrameRateLimit=$MonitorRefresh.000000
ResolutionSizeX=$MonitorWidth
ResolutionSizeY=$MonitorHeight
LastUserConfirmedResolutionSizeX=$MonitorWidth
LastUserConfirmedResolutionSizeY=$MonitorHeight
FullscreenMode=1
LastConfirmedFullscreenMode=1
PreferredFullscreenMode=1
Version=5
"@

foreach ($ConfigDir in $TargetConfigDirs) {
    $UE5EngineIni = Join-Path $ConfigDir "Engine.ini"
    $GameUserSettingsIni = Join-Path $ConfigDir "GameUserSettings.ini"

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $engineBackupPath = "$UE5EngineIni.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
    if (Test-Path $UE5EngineIni) {
        Copy-Item $UE5EngineIni $engineBackupPath -Force
        Write-Host "[BACKUP] Engine.ini backed up to: $engineBackupPath" -ForegroundColor Yellow
    }

    $gusBackupPath = "$GameUserSettingsIni.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
    if (Test-Path $GameUserSettingsIni) {
        Copy-Item $GameUserSettingsIni $gusBackupPath -Force
        Write-Host "[BACKUP] GameUserSettings.ini backed up to: $gusBackupPath" -ForegroundColor Yellow
    }

    Set-Content -Path $UE5EngineIni -Value $EngineIniContent -Encoding UTF8 -Force
    Set-Content -Path $GameUserSettingsIni -Value $GameUserSettingsContent -Encoding UTF8 -Force
    Write-Host "  [OK] Engine.ini written to: $UE5EngineIni" -ForegroundColor Green
    Write-Host "  [OK] GameUserSettings.ini written to: $GameUserSettingsIni" -ForegroundColor Green
    $AnyConfigWritten = $true
    $WrittenCount++
}

if ($AnyConfigWritten) {
    Write-Host "[SQ_CHECK_OK:ARC_CONFIG_FILES_WRITTEN:$WrittenCount]"
} else {
    Write-Host "[SQ_CHECK_FAIL:ARC_CONFIG_FILES_WRITTEN:NO_WRITES]"
    Write-Host "[SQ_CHECK_FAIL:ARC_SETTINGS_APPLIED:NO_CONFIG_WRITES]"
    Write-Host "[FAIL] Arc Raiders config files could not be written." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  ARC RAIDERS - COMPLETE SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- DISPLAY SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Window Mode            : Fullscreen Exclusive" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Frame Rate Limit       : Unlimited (or monitor refresh rate)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Brightness             : 50 (default, adjust for your monitor)" -ForegroundColor White

Write-Host ""
Write-Host "  --- UPSCALING (Critical for UE5 performance) ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  Upscaling Mode         : DLSS (strongly recommended for NVIDIA)" -ForegroundColor White
    Write-Host "  DLSS Quality           : Quality (best image with ~20% FPS gain)" -ForegroundColor White
    Write-Host "                         Balanced if still FPS-limited" -ForegroundColor DarkGray
    Write-Host "  DLSS Frame Gen         : OFF (adds input latency - not competitive)" -ForegroundColor White
    Write-Host "  NVIDIA Reflex          : On + Boost" -ForegroundColor White
} else {
    Write-Host "  Upscaling Mode         : FSR 3 or TSR" -ForegroundColor White
    Write-Host "  FSR Quality            : Quality (best balance)" -ForegroundColor White
    Write-Host "  FSR Frame Gen          : OFF (adds input latency - not competitive)" -ForegroundColor White
    Write-Host "  AMD Anti-Lag            : Enabled" -ForegroundColor White
}
Write-Host "  Anti-Aliasing          : TAA or DLSS (not TAAU - too blurry)" -ForegroundColor White
Write-Host "                         TSR is good alternative if not using DLSS/FSR" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (COMPETITIVE COMPETITIVE) ---" -ForegroundColor Cyan
Write-Host "  Shadows                : MEDIUM (minimum for competitive!)" -ForegroundColor Red
Write-Host "                         LOW disables player shadows - massive disadvantage" -ForegroundColor Red
Write-Host "                         Player shadows reveal enemy positions behind cover" -ForegroundColor DarkGray
Write-Host "  Shadow Distance        : Medium" -ForegroundColor White
Write-Host "  Texture Quality        : High (minimal FPS cost, much better visibility)" -ForegroundColor White
Write-Host "  Post Processing        : Low (disables bloom, lens effects)" -ForegroundColor White
Write-Host "  Effects Quality        : Low (less visual clutter in combat)" -ForegroundColor White
Write-Host "  Foliage Quality        : Low (clearer sightlines through vegetation)" -ForegroundColor White
Write-Host "  Terrain Quality        : Low-Medium" -ForegroundColor White
Write-Host "  Object Detail          : Medium" -ForegroundColor White
Write-Host "  Global Illumination    : Static GI (not Dynamic - major FPS drain)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF (Engine.ini also enforces this)" -ForegroundColor White
Write-Host "  Motion Blur            : OFF" -ForegroundColor White
Write-Host "  Depth of Field         : OFF" -ForegroundColor White
Write-Host "  Lens Flare             : OFF" -ForegroundColor White
Write-Host "  Bloom                  : OFF" -ForegroundColor White

Write-Host ""
Write-Host "  --- HARDWARE TIER RECOMMENDATIONS ---" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [ENTRY-LEVEL: RTX 3060 / RX 6600]" -ForegroundColor Yellow
Write-Host "  Quality Preset         : Low (then adjust shadows to Medium)" -ForegroundColor White
Write-Host "  DLSS/FSR               : Performance mode" -ForegroundColor White
Write-Host "  Target FPS             : 100-144" -ForegroundColor White
Write-Host ""
Write-Host "  [MID-RANGE: RTX 4070 / RX 7800 XT]" -ForegroundColor Yellow
Write-Host "  Quality Preset         : Medium (then lower effects/foliage to Low)" -ForegroundColor White
Write-Host "  DLSS/FSR               : Quality mode" -ForegroundColor White
Write-Host "  Target FPS             : 144-240" -ForegroundColor White
Write-Host ""
Write-Host "  [HIGH-END: RTX 4090 / RX 7900 XTX]" -ForegroundColor Yellow
Write-Host "  Quality Preset         : High (keep shadows High, effects Medium)" -ForegroundColor White
Write-Host "  DLSS/FSR               : Quality or off (if native 1440p perf allows)" -ForegroundColor White
Write-Host "  Target FPS             : 240+" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO (CRITICAL FOR ARC RAIDERS) ---" -ForegroundColor Cyan
Write-Host "  Audio Preset           : Night Mode" -ForegroundColor White
Write-Host "                         Compresses dynamic range - quiet sounds louder" -ForegroundColor DarkGray
Write-Host "                         Makes footsteps, enemy movements much clearer" -ForegroundColor DarkGray
Write-Host "  Master Volume          : 80" -ForegroundColor White
Write-Host "  Music Volume           : 0 (extraction tension music masks footsteps)" -ForegroundColor White
Write-Host "  SFX Volume             : 100" -ForegroundColor White
Write-Host "  UI Volume              : 50" -ForegroundColor White
Write-Host "  Voice Chat Volume      : 70" -ForegroundColor White
Write-Host "  Spatial Audio          : ON (3D positional audio for enemy detection)" -ForegroundColor White

Write-Host ""
Write-Host "  --- SENSITIVITY ---" -ForegroundColor Cyan
Write-Host "  Mouse Sensitivity      : 0.15-0.25 (slower than pure FPS games)" -ForegroundColor White
Write-Host "                         Arc Raiders has larger play spaces than Valorant" -ForegroundColor DarkGray
Write-Host "  ADS Sensitivity        : 0.85 (consistent with hipfire muscle memory)" -ForegroundColor White
Write-Host "  Scope Sensitivity      : 0.85" -ForegroundColor White
Write-Host "  FOV                    : 80-90 (80 is competitive standard)" -ForegroundColor White
Write-Host "                         Higher FOV hurts precision aiming at distance" -ForegroundColor DarkGray
Write-Host "  Polling Rate           : 1000Hz recommended" -ForegroundColor White

Write-Host ""
Write-Host "  --- NOTES ON ARC RAIDERS UE5 SPECIFICS ---" -ForegroundColor Cyan
Write-Host "  - First launch: Expect shader compilation stutter (first ~1 hour)" -ForegroundColor DarkGray
Write-Host "  - Patch 1.0.7: Shadow LOD transitions significantly improved" -ForegroundColor DarkGray
Write-Host "  - Frame Generation (DLSS/FSR): Always OFF for competitive - adds latency" -ForegroundColor DarkGray
Write-Host "  - The game is well-optimized for UE5 - mid-range can hit 144fps at 1080p" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[DONE] Arc Raiders config files written. Apply remaining settings in-game." -ForegroundColor Green
Write-Host "[SQ_CHECK_OK:ARC_SETTINGS_APPLIED]"
Write-Host ""
