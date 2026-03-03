#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Arc Raiders - PC Optimization Script
    Version: 2.0 | Updated: March 2026
    Engine: Unreal Engine 5 (Embark Studios custom fork)

.DESCRIPTION
    Applies Windows EXE flags and Arc Raiders config file optimizations.
    Arc Raiders uses UE5 with internal project name "PioneerGame".
    Config path: %LOCALAPPDATA%\PioneerGame\Saved\Config\WindowsClient\

    ARC RAIDERS OPTIMIZATION PHILOSOPHY:
    Unlike pure competitive shooters, Arc Raiders is a PvPvE extraction game
    where visual clarity matters for both PvP fights and environmental awareness.
    Settings balance maximum FPS with maintaining enemy visibility, especially:
    - Shadow settings (Medium minimum -- Low disables player shadows = big disadvantage)
    - Upscaling is recommended for performance gains
    - Night Mode audio is critical for hearing enemy footsteps

.NOTES
    Key names verified against: github.com/aj-geddes/arc-raiders-tuner
    Embark uses a custom UE5 fork that strips Nanite, Lumen, and Virtual Shadow Maps.
    Config sections: [/Script/EmbarkUserSettings.EmbarkGameUserSettings],
    [ScalabilityGroups], [SystemSettings], [/Script/Engine.InputSettings],
    [/Script/Engine.Engine], [/Script/Engine.GameUserSettings]
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Arc Raiders - Optimization Script' `
               -Subtitle 'March 2026 | Unreal Engine 5 | PioneerGame'

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS: Read-Merge-Write for UE5 INI files
# -----------------------------------------------------------------------------

function Read-IniFile {
    param([string]$Path)
    $sections = [ordered]@{}
    $currentSection = ""
    if (-not (Test-Path $Path)) { return $sections }
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

function Merge-IniSection {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Config,
        [string]$SectionName,
        [System.Collections.Specialized.OrderedDictionary]$Overrides
    )
    if (-not $Config.Contains($SectionName)) {
        $Config[$SectionName] = [ordered]@{}
    }
    foreach ($key in $Overrides.Keys) {
        $Config[$SectionName][$key] = $Overrides[$key]
    }
}

function Write-IniFile {
    param(
        [string]$Path,
        [System.Collections.Specialized.OrderedDictionary]$Config
    )
    $lines = @()
    $first = $true
    foreach ($section in $Config.Keys) {
        if (-not $first) { $lines += "" }
        $first = $false
        $lines += "[$section]"
        foreach ($key in $Config[$section].Keys) {
            $lines += "$key=$($Config[$section][$key])"
        }
    }
    $content = ($lines -join "`r`n") + "`r`n"
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

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
    "E:\SteamLibrary\steamapps\common\Arc Raiders"
)

foreach ($root in $CommonArcRoots) {
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "ArcRaiders.exe")
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "PioneerGame\Binaries\Win64\PioneerGame-Win64-Shipping.exe")
    Add-UniquePath -List $ArcRaidersPaths -Path (Join-Path $root "PioneerGame\Binaries\Win64\ArcRaiders-Win64-Shipping.exe")
}

$foundCount = Set-ExeCompatFlags -ExePaths $ArcRaidersPaths -CheckKey 'ARC_EXE_FLAGS'

if ($foundCount -eq 0) {
    Write-Host "       To set manually: Right-click ArcRaiders.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED CONFIG (Read-Merge-Write)
# Arc Raiders internal UE5 project name is "PioneerGame"
# Config: %LOCALAPPDATA%\PioneerGame\Saved\Config\WindowsClient\
# -----------------------------------------------------------------------------

$ConfigRoot = "$env:LOCALAPPDATA\PioneerGame\Saved\Config"
$PlatformDirs = @("WindowsClient", "WinGDKClient")
$TargetConfigDirs = New-Object 'System.Collections.Generic.List[string]'

if (Test-Path $ConfigRoot) {
    foreach ($platform in $PlatformDirs) {
        $dirPath = Join-Path $ConfigRoot $platform
        if (Test-Path $dirPath) {
            Add-UniquePath -List $TargetConfigDirs -Path $dirPath
        }
    }
}

if ($TargetConfigDirs.Count -eq 0) {
    $fallbackDir = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient"
    New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
    Add-UniquePath -List $TargetConfigDirs -Path $fallbackDir
    Write-Host "[INFO] No existing PioneerGame config found. Created fallback: $fallbackDir" -ForegroundColor DarkCyan
}

# --- Competitive overrides by section ---

# Embark custom settings section
$EmbarkOverrides = [ordered]@{
    'ResolutionScalingMethod' = 'None'
    'DLSSMode'                = if ($NvidiaGPU) { 'Quality' } else { 'Off' }
    'DLSSModel'               = 'Transformer'
    'XeSSMode'                = 'Off'
    'FSR3Mode'                = if ($NvidiaGPU) { 'Off' } else { 'Quality' }
    'DLSSFrameGenerationMode' = 'Off'
    'FSR3FrameGenerationMode' = 'Off'
    'NvReflexMode'            = if ($NvidiaGPU) { 'Enabled+Boost' } else { 'Off' }
    'ReflexLatewarpMode'      = 'Off'
    'bAntiLag2Enabled'        = if ($NvidiaGPU) { 'False' } else { 'True' }
    'RTXGIQuality'            = 'Static'
    'RTXGIResolutionQuality'  = '1'
    'FullscreenMode'          = '0'
    'bUseVSync'               = 'False'
    'FrameRateLimit'          = '0'
    'bUseHDRDisplayOutput'    = 'False'
    'MotionBlurEnabled'       = 'False'
    'LensDistortionEnabled'   = 'False'
    'AudioQualityLevel'       = '2'
    'bEnableAudioSpatialisation' = 'True'
}

# Scalability quality groups (0=Low, 1=Medium, 2=High, 3=Epic)
$ScalabilityOverrides = [ordered]@{
    'sg.ViewDistanceQuality'        = '2'
    'sg.ShadowQuality'             = '1'
    'sg.TextureQuality'            = '2'
    'sg.EffectsQuality'            = '0'
    'sg.FoliageQuality'            = '0'
    'sg.PostProcessQuality'        = '0'
    'sg.ReflectionQuality'         = '0'
    'sg.ShadingQuality'            = '1'
    'sg.GlobalIlluminationQuality' = '0'
    'sg.AntiAliasingQuality'       = '2'
    'sg.ResolutionQuality'         = '100.000000'
}

# System settings (r.* render commands)
$SystemSettingsOverrides = [ordered]@{
    'r.DepthOfFieldQuality'         = '0'
    'r.BloomQuality'                = '0'
    'r.LensFlareQuality'           = '0'
    'r.SceneColorFringe.Max'       = '0'
    'r.Tonemapper.Sharpen'         = '1'
    'r.Tonemapper.GrainQuantization' = '0'
    'r.Vignette.Quality'           = '0'
    'r.OneFrameThreadLag'          = '1'
    'r.CreateShadersOnLoad'        = '1'
    'r.Streaming.PoolSize'         = '4096'
    'r.MaxAnisotropy'              = '16'
    'r.TextureStreaming'           = '1'
}

# Input settings
$InputOverrides = [ordered]@{
    'bEnableMouseSmoothing'     = 'False'
    'bViewAccelerationEnabled'  = 'False'
}

# Engine settings
$EngineOverrides = [ordered]@{
    'bSmoothFrameRate' = 'False'
}

# GameUserSettings (UE5 base)
$GameUserOverrides = [ordered]@{
    'bEnableMouseSmoothing' = 'False'
}

# Engine.ini content (separate file, user-level engine overrides)
$EngineIniContent = @"
[SystemSettings]
r.ShaderPipelineCache.Mode=1
r.ShaderPipelineCache.BackgroundBatchSize=0
r.PSOPrecache.Validation=0
r.Streaming.MipBias=0
r.TemporalAASamples=8
r.AmbientOcclusionLevels=0
r.LensFlareQuality=0
r.BloomQuality=0
r.DepthOfFieldQuality=0
r.MotionBlurQuality=0
r.Tonemapper.GrainQuantization=0
r.DynamicGlobalIlluminationMethod=0

[ConsoleVariables]
r.Streaming.FullyLoadUsedTextures=1
"@

$AnyConfigWritten = $false
$WrittenCount = 0

foreach ($ConfigDir in $TargetConfigDirs) {
    $GameUserSettingsIni = Join-Path $ConfigDir "GameUserSettings.ini"
    $EngineIni = Join-Path $ConfigDir "Engine.ini"

    try {
        # --- Backup existing files ---
        Backup-ConfigFile -Path $GameUserSettingsIni | Out-Null
        Backup-ConfigFile -Path $EngineIni | Out-Null

        # --- Read-Merge-Write GameUserSettings.ini ---
        $config = Read-IniFile -Path $GameUserSettingsIni
        Merge-IniSection -Config $config -SectionName '/Script/EmbarkUserSettings.EmbarkGameUserSettings' -Overrides $EmbarkOverrides
        Merge-IniSection -Config $config -SectionName 'ScalabilityGroups' -Overrides $ScalabilityOverrides
        Merge-IniSection -Config $config -SectionName 'SystemSettings' -Overrides $SystemSettingsOverrides
        Merge-IniSection -Config $config -SectionName '/Script/Engine.InputSettings' -Overrides $InputOverrides
        Merge-IniSection -Config $config -SectionName '/Script/Engine.Engine' -Overrides $EngineOverrides
        Merge-IniSection -Config $config -SectionName '/Script/Engine.GameUserSettings' -Overrides $GameUserOverrides
        Write-IniFile -Path $GameUserSettingsIni -Config $config
        Lock-ConfigFile -Path $GameUserSettingsIni
        Write-Host "  [OK] GameUserSettings.ini written to: $GameUserSettingsIni" -ForegroundColor Green

        # --- Write Engine.ini (user-level engine override, safe to overwrite) ---
        [System.IO.File]::WriteAllText($EngineIni, $EngineIniContent, [System.Text.UTF8Encoding]::new($false))
        Lock-ConfigFile -Path $EngineIni
        Write-Host "  [OK] Engine.ini written to: $EngineIni" -ForegroundColor Green

        $AnyConfigWritten = $true
        $WrittenCount++
    }
    catch {
        Write-Host "[FAIL] Error writing config to ${ConfigDir}: $_" -ForegroundColor Red
        Write-Check -Status 'FAIL' -Key 'ARC_CONFIG_FILES_WRITTEN' -Detail 'WRITE_ERROR'
    }
}

if ($AnyConfigWritten) {
    Write-Check -Status 'OK' -Key 'ARC_CONFIG_FILES_WRITTEN' -Detail "$WrittenCount"
} else {
    Write-Check -Status 'FAIL' -Key 'ARC_CONFIG_FILES_WRITTEN' -Detail 'NO_WRITES'
    Write-Check -Status 'FAIL' -Key 'ARC_SETTINGS_APPLIED' -Detail 'NO_CONFIG_WRITES'
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
Write-Host "  Frame Rate Limit       : Unlimited (FrameRateLimit=0)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF" -ForegroundColor White

Write-Host ""
Write-Host "  --- UPSCALING ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  DLSS Mode              : Quality (best image with ~20% FPS gain)" -ForegroundColor White
    Write-Host "  DLSS Model             : Transformer" -ForegroundColor White
    Write-Host "  DLSS Frame Gen         : OFF (adds input latency)" -ForegroundColor White
    Write-Host "  NVIDIA Reflex          : Enabled + Boost" -ForegroundColor White
} else {
    Write-Host "  FSR 3 Mode             : Quality (best balance)" -ForegroundColor White
    Write-Host "  FSR Frame Gen          : OFF (adds input latency)" -ForegroundColor White
    Write-Host "  AMD Anti-Lag 2         : Enabled" -ForegroundColor White
}

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (COMPETITIVE) ---" -ForegroundColor Cyan
Write-Host "  Shadows                : MEDIUM (sg=1, minimum for competitive!)" -ForegroundColor Red
Write-Host "                         LOW disables player shadows - big disadvantage" -ForegroundColor Red
Write-Host "  Textures               : High (sg=2, minimal FPS cost)" -ForegroundColor White
Write-Host "  View Distance          : High (sg=2)" -ForegroundColor White
Write-Host "  Effects                : Low (sg=0)" -ForegroundColor White
Write-Host "  Foliage                : Low (sg=0, clearer sightlines)" -ForegroundColor White
Write-Host "  Post Processing        : Low (sg=0)" -ForegroundColor White
Write-Host "  Reflections            : Low (sg=0)" -ForegroundColor White
Write-Host "  Shading                : Medium (sg=1)" -ForegroundColor White
Write-Host "  Global Illumination    : Low/Static (sg=0)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : High (sg=2)" -ForegroundColor White
Write-Host "  Resolution Quality     : 100%%" -ForegroundColor White
Write-Host "  Motion Blur            : OFF" -ForegroundColor White
Write-Host "  Lens Distortion        : OFF" -ForegroundColor White
Write-Host "  Depth of Field         : OFF (r.DepthOfFieldQuality=0)" -ForegroundColor White
Write-Host "  Bloom                  : OFF (r.BloomQuality=0)" -ForegroundColor White
Write-Host "  Lens Flare             : OFF (r.LensFlareQuality=0)" -ForegroundColor White
Write-Host "  Film Grain             : OFF (r.Tonemapper.GrainQuantization=0)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF (Engine.ini r.AmbientOcclusionLevels=0)" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO (CRITICAL FOR ARC RAIDERS) ---" -ForegroundColor Cyan
Write-Host "  Audio Quality          : High (AudioQualityLevel=2)" -ForegroundColor White
Write-Host "  Spatial Audio          : ON (bEnableAudioSpatialisation=True)" -ForegroundColor White
Write-Host "  Master Volume          : 80" -ForegroundColor White
Write-Host "  Music Volume           : 0 (masks footsteps)" -ForegroundColor White
Write-Host "  SFX Volume             : 100" -ForegroundColor White

Write-Host ""
Write-Host "  --- INPUT ---" -ForegroundColor Cyan
Write-Host "  Mouse Smoothing        : OFF" -ForegroundColor White
Write-Host "  Mouse Acceleration     : OFF" -ForegroundColor White
Write-Host "  Smooth Frame Rate      : OFF" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] Arc Raiders config files written. Apply remaining settings in-game." -ForegroundColor Green
Write-Check -Status 'OK' -Key 'ARC_SETTINGS_APPLIED'
Write-Host ""
