#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Valorant - PC Optimization Script
    Version: 1.0 | Updated: February 2026
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

.NOTES
    Config file location:
    %LOCALAPPDATA%\VALORANT\Saved\Config\Windows\GameUserSettings.ini

    VANGUARD NOTE: Do not attempt to modify game files or memory.
    This script only touches user config and Windows compatibility flags.
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# --- USER CONFIGURATION - EDIT THESE VALUES ----------------------------------
# When run from SENSEQUALITY app, these are overridden by environment variables.

if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
} else {
    $MonitorWidth   = 1920
    $MonitorHeight  = 1080
    $MonitorRefresh = 240
}
$FrameRateLimit = $MonitorRefresh - 3    # Refresh rate minus 3 for frame stability
# -----------------------------------------------------------------------------

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  VALORANT - Optimization Script" -ForegroundColor Cyan
Write-Host "  February 2026 | UE4 Engine | Vanguard Anti-Cheat" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: BACKUP AND WRITE VALORANT CONFIG
# -----------------------------------------------------------------------------

$ConfigPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config\Windows\GameUserSettings.ini"
$BackupPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config\Windows\GameUserSettings.ini.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath $BackupPath -Force
    Write-Host "[BACKUP] Config backed up to: $BackupPath" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] No existing Valorant config found. Creating fresh config." -ForegroundColor DarkCyan
    $ConfigDir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
}

Write-Host "[INFO] Writing optimized Valorant config..." -ForegroundColor DarkCyan

# WHY THESE SETTINGS:
# - FullscreenMode=1: Exclusive fullscreen for lowest latency GPU-to-display path
# - bUseVSync=False: V-Sync adds 16-50ms input latency - catastrophic in Valorant
# - FrameRateLimit: Capped at refresh-3 prevents frame-pacing irregularity
# - sg.ShadowQuality=0: Shadows eat FPS, no competitive benefit
# - sg.TextureQuality=3: Textures are cheap, help with agent/wall clarity
# - NVIDIA Reflex (set via in-game, not config) reduces system latency 15-30ms

$ValorantConfig = @"
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
AudioQualityLevel=0
FrameRateLimit=$FrameRateLimit.000000
DesiredScreenWidth=$MonitorWidth
DesiredScreenHeight=$MonitorHeight
LastUserConfirmedDesiredScreenWidth=$MonitorWidth
LastUserConfirmedDesiredScreenHeight=$MonitorHeight
FullscreenMode=1

[ScalabilityGroups]
sg.ResolutionQuality=100
sg.ViewDistanceQuality=0
sg.AntiAliasingQuality=0
sg.ShadowQuality=0
sg.GlobalIlluminationQuality=0
sg.ReflectionQuality=0
sg.PostProcessQuality=0
sg.TextureQuality=3
sg.EffectsQuality=0
sg.FoliageQuality=0
sg.ShadingQuality=0

[/Script/ShooterGame.ShooterGameUserSettings]
bColorVisionDeficiency=False
ColorVisionDeficiencyType=Deuteranopia
bColorVisionDeficiencyStrength=True
ColorVisionDeficiencyStrength=0
bColorVisionDeficiencyRemovingCorrection=False
bColorVisionDeficiencyFilterStrength=0
ControllerVibration=True
bGamepadEnabled=False
bSaveTeammatesPositions=True
"@

Set-Content -Path $ConfigPath -Value $ValorantConfig -Encoding UTF8 -Force
Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green

# -----------------------------------------------------------------------------
# SECTION 2: EXE COMPATIBILITY FLAGS FOR VALORANT
# NOTE: Valorant has Vanguard anti-cheat. We ONLY set Windows-layer flags
#       that Windows itself applies before the process starts.
#       These are standard OS features, not modifications to game files.
# -----------------------------------------------------------------------------

$ValorantExePaths = @(
    "C:\Riot Games\VALORANT\live\VALORANT.exe",
    "C:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe",
    "D:\Riot Games\VALORANT\live\VALORANT.exe"
)

$AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

foreach ($exePath in $ValorantExePaths) {
    if (Test-Path $exePath) {
        # HIGHDPIAWARE: Ensures Valorant controls its own DPI scaling
        # Note: Valorant works well with fullscreen optimizations ON (unlike most games)
        # So we do NOT add DISABLEFULLSCREENOPTIMIZATIONS here
        Set-ItemProperty -Path $AppCompatLayers -Name $exePath -Value "~ HIGHDPIAWARE" -Type String -Force
        Write-Host "  [OK] EXE flags set for: $exePath" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  VALORANT - COMPLETE SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Display Mode           : Fullscreen" -ForegroundColor White
Write-Host "                         (Valorant's fullscreen is already optimized)" -ForegroundColor DarkGray
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Max Frame Rate         : $FrameRateLimit" -ForegroundColor White
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
Write-Host "  --- PRO PLAYER REFERENCE (Feb 2026, ProSettings.net) ---" -ForegroundColor Cyan
Write-Host "  598 pro players analyzed - universal consensus:" -ForegroundColor White
Write-Host "  - 100% use 1920x1080 or lower (no pro uses 1440p/4K in ranked)" -ForegroundColor White
Write-Host "  - 100% use Fullscreen (not borderless)" -ForegroundColor White
Write-Host "  - 100% V-Sync OFF" -ForegroundColor White
Write-Host "  - 0% shadows enabled" -ForegroundColor White
Write-Host "  - 95%+ NVIDIA Reflex Enabled + Boost" -ForegroundColor White
Write-Host "  - Median eDPI: 280" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] Valorant config written. Apply remaining settings in-game." -ForegroundColor Green
Write-Host ""
