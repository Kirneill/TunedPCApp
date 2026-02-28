#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fortnite - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Game Version: Chapter 6 (current season)
    Engine: Unreal Engine 5 (Performance Mode)

.DESCRIPTION
    Applies EXE compatibility flags and modifies the Fortnite GameUserSettings.ini
    config file for maximum competitive performance. Fortnite's config files are
    user-accessible and safe to modify.

    WHAT THIS SCRIPT DOES:
    - Backs up existing GameUserSettings.ini
    - Writes optimized competitive settings to GameUserSettings.ini
    - Sets Windows EXE flags for the Fortnite executable
    - Prints the full in-game settings guide

.NOTES
    Config file location:
    %LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini

    IMPORTANT: Set your desired Resolution and RefreshRate in the variables
    section below before running this script.
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# --- USER CONFIGURATION - EDIT THESE VALUES ----------------------------------
# When run from SENSEQUALITY app, these are overridden by environment variables.
# When run standalone, edit the values below.

if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
} else {
    $MonitorWidth     = 1920   # Your monitor width  (e.g., 1920, 2560, 1280)
    $MonitorHeight    = 1080   # Your monitor height (e.g., 1080, 1440, 720)
    $MonitorRefresh   = 240    # Your monitor refresh rate in Hz (e.g., 144, 165, 240, 360)
}
$FrameRateLimit   = $MonitorRefresh - 3    # Cap FPS at RefreshRate - 3 for frame stability
# -----------------------------------------------------------------------------

$script:ValidationFailed = $false

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FAIL', 'WARN')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Detail = ''
    )

    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { '' } else { ":$Detail" }
    Write-Host "[SQ_CHECK_${Status}:$Key$suffix]"
    if ($Status -eq 'FAIL') {
        $script:ValidationFailed = $true
    }
}

function Add-UniquePath {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not $List.Contains($Path)) { $List.Add($Path) }
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Fortnite Chapter 6 - Optimization Script" -ForegroundColor Cyan
Write-Host "  February 2026 | UE5 Performance Mode" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : $FrameRateLimit" -ForegroundColor White
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE TARGET CONFIG PATHS
# -----------------------------------------------------------------------------

# Fortnite may use WindowsClient or Windows depending on patch/install path.
# We write+lock both to prevent launch-time resets.
$ConfigRoot = Join-Path $env:LOCALAPPDATA "FortniteGame\Saved\Config"
$TargetConfigPaths = New-Object 'System.Collections.Generic.List[string]'

$PrimaryCandidates = @(
    (Join-Path $ConfigRoot "WindowsClient\GameUserSettings.ini"),
    (Join-Path $ConfigRoot "Windows\GameUserSettings.ini")
)

foreach ($candidate in $PrimaryCandidates) {
    Add-UniquePath -List $TargetConfigPaths -Path $candidate
}

$LegacyCandidate = Join-Path $ConfigRoot "WindowsNoEditor\GameUserSettings.ini"
if (Test-Path $LegacyCandidate) {
    Add-UniquePath -List $TargetConfigPaths -Path $LegacyCandidate
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED GameUserSettings.ini
# WHY FOR EACH SETTING:

# - bUseVSync=False: V-Sync adds 16-50ms input latency - always off competitive
# - bMotionBlur=False: Motion blur reduces clarity during movement and fights
# - sg.ShadowQuality=0: Shadows hurt FPS significantly with minimal visual need
# - sg.EffectsQuality=0: Storm/explosion effects reduced for cleaner sightlines
# - FrameRateLimit: Capping 3fps below max provides stable frame pacing
# - WindowMode=1: Fullscreen exclusive for lowest latency display path
# - ResolutionQuality=100: Full native render (no upscaling at 1080p target)
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Writing optimized Fortnite config..." -ForegroundColor DarkCyan

$FNConfig = @"
[/Script/FortniteGame.FortGameUserSettings]
bRunningOnHighEndMachine=True
LastConfirmedScalability=(ResolutionQuality=100,ViewDistanceQuality=1,AntiAliasingQuality=0,ShadowQuality=0,GlobalIlluminationQuality=0,ReflectionQuality=0,PostProcessQuality=0,TextureQuality=2,EffectsQuality=0,FoliageQuality=0,ShadingQuality=0)
bUseVSync=False
bMotionBlur=False
FrameRateLimit=$FrameRateLimit.000000
ResolutionSizeX=$MonitorWidth
ResolutionSizeY=$MonitorHeight
LastUserConfirmedResolutionSizeX=$MonitorWidth
LastUserConfirmedResolutionSizeY=$MonitorHeight
WindowPosX=-1
WindowPosY=-1
bFullscreenMode=1
LastConfirmedFullscreenMode=1
PreferredFullscreenMode=1
Version=5
AudioQualityLevel=2
LastConfirmedAudioQualityLevel=2
MusicVolume=0.000000
SoundFXVolume=0.850000
DialogueVolume=0.500000
VoiceChatVolume=0.700000
bCinematicMode=False
bEnableColorBlindMode=False
ColorBlindMode=0
ColorBlindModeStrength=10
bForceClientExclusive=True
bUseHighQualityConnectionForVoice=True
GameUserSettingsVersion=5

[ScalabilityGroups]
sg.ResolutionQuality=100
sg.ViewDistanceQuality=1
sg.AntiAliasingQuality=0
sg.ShadowQuality=0
sg.GlobalIlluminationQuality=0
sg.ReflectionQuality=0
sg.PostProcessQuality=0
sg.TextureQuality=2
sg.EffectsQuality=0
sg.FoliageQuality=0
sg.ShadingQuality=0

[/Script/Engine.GameUserSettings]
bUseVSync=False
ResolutionSizeX=$MonitorWidth
ResolutionSizeY=$MonitorHeight
LastUserConfirmedResolutionSizeX=$MonitorWidth
LastUserConfirmedResolutionSizeY=$MonitorHeight
WindowPosX=-1
WindowPosY=-1
bUseDesiredScreenHeight=False
FullscreenMode=1
LastConfirmedFullscreenMode=1
PreferredFullscreenMode=1
Version=5
AudioQualityLevel=2
FrameRateLimit=$FrameRateLimit.000000
DesiredScreenWidth=$MonitorWidth
DesiredScreenHeight=$MonitorHeight
LastUserConfirmedDesiredScreenWidth=$MonitorWidth
LastUserConfirmedDesiredScreenHeight=$MonitorHeight
"@

$TotalTargets = $TargetConfigPaths.Count
$WriteSuccessCount = 0
$ReadOnlySuccessCount = 0
$WriteFailures = @()
$ReadOnlyFailures = @()

foreach ($ConfigPath in $TargetConfigPaths) {
    $ConfigDir = Split-Path $ConfigPath -Parent

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    if (Test-Path $ConfigPath) {
        try {
            Set-ItemProperty -Path $ConfigPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
            $BackupPath = "$ConfigPath.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
            Copy-Item $ConfigPath $BackupPath -Force -ErrorAction Stop
            Write-Host "[BACKUP] Existing config backed up to: $BackupPath" -ForegroundColor Yellow
        } catch {
            Write-Host "[WARN] Backup failed for ${ConfigPath}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[INFO] Creating new config file: $ConfigPath" -ForegroundColor DarkCyan
    }

    try {
        Set-Content -Path $ConfigPath -Value $FNConfig -Encoding UTF8 -Force -ErrorAction Stop
        $raw = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($raw -match 'sg\.ShadowQuality=0' -and $raw -match 'FrameRateLimit=') {
            $WriteSuccessCount++
            Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green
        } else {
            $WriteFailures += "$ConfigPath (expected keys missing)"
            Write-Host "  [WARN] Config write verification failed: $ConfigPath" -ForegroundColor Yellow
        }
    } catch {
        $WriteFailures += "$ConfigPath ($($_.Exception.Message))"
        Write-Host "  [FAIL] Could not write config: $ConfigPath" -ForegroundColor Red
    }

    try {
        Set-ItemProperty -Path $ConfigPath -Name IsReadOnly -Value $true -ErrorAction Stop
        $isReadOnly = (Get-Item -Path $ConfigPath -ErrorAction Stop).IsReadOnly
        if ($isReadOnly) {
            $ReadOnlySuccessCount++
            Write-Host "  [OK] Read-only lock enabled: $ConfigPath" -ForegroundColor Green
        } else {
            $ReadOnlyFailures += "$ConfigPath (IsReadOnly false)"
            Write-Host "  [WARN] Read-only lock check failed: $ConfigPath" -ForegroundColor Yellow
        }
    } catch {
        $ReadOnlyFailures += "$ConfigPath ($($_.Exception.Message))"
        Write-Host "  [FAIL] Could not set read-only: $ConfigPath" -ForegroundColor Red
    }
}

if ($WriteSuccessCount -eq $TotalTargets) {
    Write-Check -Status 'OK' -Key 'FN_CONFIG_FILES_WRITTEN' -Detail "$WriteSuccessCount/$TotalTargets"
} else {
    Write-Check -Status 'FAIL' -Key 'FN_CONFIG_FILES_WRITTEN' -Detail (($WriteFailures -join '; '))
}

if ($ReadOnlySuccessCount -eq $TotalTargets) {
    Write-Check -Status 'OK' -Key 'FN_CONFIG_READONLY' -Detail "$ReadOnlySuccessCount/$TotalTargets"
} else {
    Write-Check -Status 'FAIL' -Key 'FN_CONFIG_READONLY' -Detail (($ReadOnlyFailures -join '; '))
}

# -----------------------------------------------------------------------------
# SECTION 3: PERSISTENCE NOTE
# -----------------------------------------------------------------------------

Write-Host "  [NOTE] Config was applied to WindowsClient + Windows paths and set read-only." -ForegroundColor DarkGray
Write-Host "  [NOTE] If Epic Cloud sync is enabled, cloud data may still override local files." -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# SECTION 4: EXE COMPATIBILITY FLAGS
# -----------------------------------------------------------------------------

$FNExePaths = @(
    "$env:LOCALAPPDATA\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe",
    "$env:ProgramFiles\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
)

$AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

foreach ($exePath in $FNExePaths) {
    if (Test-Path $exePath) {
        Set-ItemProperty -Path $AppCompatLayers -Name $exePath -Value "~ HIGHDPIAWARE" -Type String -Force
        Write-Host "  [OK] EXE flags set for: $exePath" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# SECTION 5: PRINT REMAINING IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  FORTNITE - REMAINING IN-GAME SETTINGS (Apply Manually)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- RENDERING MODE (MOST IMPORTANT SETTING) ---" -ForegroundColor Cyan
Write-Host "  Rendering Mode         : Performance (DX11)" -ForegroundColor White
Write-Host "                         Settings > Video > Rendering Mode" -ForegroundColor DarkGray
Write-Host "                         Increases FPS by 20-30% vs DX12" -ForegroundColor DarkGray
Write-Host "                         DX12 only for Ray Tracing (not competitive)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- VIDEO SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Window Mode            : Fullscreen" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Frame Rate Limit       : $FrameRateLimit (refresh-3 for stability)" -ForegroundColor White
Write-Host "  3D Resolution          : 100% (do not lower - hurts enemy clarity)" -ForegroundColor White
Write-Host "  Rendering Mode         : Performance" -ForegroundColor White
Write-Host "  Allow Multithreaded    : ON (requires 6+ CPU cores)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY ---" -ForegroundColor Cyan
Write-Host "  View Distance          : Medium (far enough for competitive awareness)" -ForegroundColor White
Write-Host "  Shadows                : OFF" -ForegroundColor White
Write-Host "  Global Illumination    : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : OFF (Performance Mode handles this)" -ForegroundColor White
Write-Host "  Textures               : Low-Medium (VRAM permitting)" -ForegroundColor White
Write-Host "  Effects                : Low" -ForegroundColor White
Write-Host "  Post Processing        : Low" -ForegroundColor White

Write-Host ""
Write-Host "  --- NVIDIA/AMD SPECIFIC ---" -ForegroundColor Cyan
Write-Host "  NVIDIA Reflex          : On + Boost (most impactful single setting)" -ForegroundColor White
Write-Host "  DLSS                   : Quality (if GPU-limited at 1080p)" -ForegroundColor White
Write-Host "  Hardware RT            : OFF (no competitive benefit)" -ForegroundColor White
Write-Host "  Nanite                 : OFF (no competitive benefit)" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO (COMPETITIVE) ---" -ForegroundColor Cyan
Write-Host "  Sound Effects          : 100" -ForegroundColor White
Write-Host "  Music                  : 0 (eliminates audio masking of footsteps)" -ForegroundColor White
Write-Host "  Voice Chat             : 70 (team comms)" -ForegroundColor White
Write-Host "  Subtitles              : OFF" -ForegroundColor White
Write-Host "  3D Headphones (HRTF)   : ON if using headphones (superior positional audio)" -ForegroundColor White
Write-Host "  Visualize Sound FX     : ON (visual indicator for nearby audio events)" -ForegroundColor White

Write-Host ""
Write-Host "  --- SENSITIVITY ---" -ForegroundColor Cyan
Write-Host "  X/Y Axis Sensitivity   : 7-10 (most pros use 7-12)" -ForegroundColor White
Write-Host "  ADS Sensitivity        : 65-75%" -ForegroundColor White
Write-Host "  Scope Sensitivity      : 65%" -ForegroundColor White
Write-Host "  Polling Rate           : 1000Hz+ recommended" -ForegroundColor White
Write-Host "  Disable mouse smoothing in Windows (done by Windows script)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- PRO PLAYER REFERENCE (Feb 2026) ---" -ForegroundColor Cyan
Write-Host "  All FNCS/competitive pros: Performance Mode, all settings Low/Off" -ForegroundColor White
Write-Host "  Bugha, Mero, Clix: 1920x1080, Performance Mode, 0% Music, Reflex On" -ForegroundColor White

Write-Host ""
if ($script:ValidationFailed) {
    Write-Host "[FAIL] Fortnite optimization completed with validation failures." -ForegroundColor Red
    exit 1
}

Write-Host "[DONE] Fortnite config written. Apply remaining settings in-game." -ForegroundColor Green
Write-Host ""
