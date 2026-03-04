#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fortnite - PC Optimization Script
    Version: 2.0 | Updated: March 2026
    Game Version: Chapter 6 (current season)
    Engine: Unreal Engine 5 (Performance Mode / DX11)

.DESCRIPTION
    Applies EXE compatibility flags and modifies the Fortnite GameUserSettings.ini
    config file for maximum competitive performance. Uses read-merge-write to
    preserve user data (EULA, playlists, shop state, social settings) while
    overriding only performance-critical keys.

    Reference config verified against real installations:
    - Jan 2025 (FortniteReleaseVersion=9, Chapter 6)
    - Feb 2024 (wispurn/Fortnite-Optimized-Settings)
    - N0madical/FortniteSettingsManager key list

    WHAT THIS SCRIPT DOES:
    - Reads existing GameUserSettings.ini (preserves all user data)
    - Merges optimized competitive settings into the config
    - Writes [D3DRHIPreference] for Performance Mode (DX11)
    - Writes [PerformanceMode] with MeshQuality=0
    - Disables ray tracing via [RayTracing] section
    - Sets Windows EXE flags for the Fortnite executable
    - Ensures config files remain writable so in-game settings can save
    - Prints the full in-game settings guide

.NOTES
    Config file location:
    %LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini

    KEY NAMES verified against real config dumps -- do NOT rename without
    checking scripts/reference-configs/fortnite-GameUserSettings.ini first.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
$FrameRateLimit = Get-FrameRateLimit
# ------------------------------------------------------------------------------

function Add-UniquePath {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not $List.Contains($Path)) { $List.Add($Path) }
}

# --- Simple INI parser and writer ---------------------------------------------
# Fortnite uses UE4 INI format with [Section] headers and Key=Value pairs.
# We parse into an ordered dictionary of sections, each containing an ordered
# list of key=value lines. This preserves order, comments, and duplicate keys.

function Read-FortniteIni {
    param([string]$Path)
    $sections = [ordered]@{}
    $currentSection = ''
    $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()

    foreach ($line in (Get-Content $Path)) {
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()
            }
        } else {
            $sections[$currentSection].Add($line)
        }
    }
    return $sections
}

function Set-IniValue {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Sections,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )
    if (-not $Sections.Contains($Section)) {
        $Sections[$Section] = [System.Collections.Generic.List[string]]::new()
    }
    $lines = $Sections[$Section]
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($Key))=") {
            $lines[$i] = "$Key=$Value"
            $found = $true
            break
        }
    }
    if (-not $found) {
        $lines.Add("$Key=$Value")
    }
}

function Write-FortniteIni {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Sections,
        [string]$Path
    )
    $sb = [System.Text.StringBuilder]::new()
    $first = $true
    foreach ($sectionName in $Sections.Keys) {
        if ($sectionName -ne '') {
            if (-not $first) { [void]$sb.AppendLine() }
            [void]$sb.AppendLine("[$sectionName]")
        }
        foreach ($line in $Sections[$sectionName]) {
            [void]$sb.AppendLine($line)
        }
        $first = $false
    }
    # Write UTF-8 without BOM (safe for UE4 INI parser)
    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
}

Write-SQHeader -Title 'Fortnite Chapter 6 - Optimization Script v2.0' `
               -Subtitle 'March 2026 | UE5 Performance Mode (DX11)'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : Uncapped (higher FPS = lower input lag)" -ForegroundColor White
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE TARGET CONFIG PATHS
# -----------------------------------------------------------------------------

# Fortnite may use WindowsClient or Windows depending on patch/install path.
# We write both active targets and ensure they are NOT read-only.
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
# SECTION 2: WRITE OPTIMIZED GameUserSettings.ini (READ-MERGE-WRITE)
#
# Key names verified against: scripts/reference-configs/fortnite-GameUserSettings.ini
# Sources: Real installations (Jan 2025, Feb 2024), N0madical/FortniteSettingsManager
#
# WHY each setting:
# - bUseVSync=False: V-Sync adds 16-50ms input latency -- always off competitive
# - bMotionBlur=False: Motion blur reduces clarity during movement and fights
# - sg.ShadowQuality=0: Shadows hurt FPS significantly with minimal visual need
# - sg.EffectsQuality=0: Storm/explosion effects reduced for cleaner sightlines
# - FrameRateLimit=0: Uncapped -- higher FPS = lower input latency
# - PreferredFullscreenMode=0: Fullscreen exclusive for lowest latency display path
# - PreferredRHI=dx11: Performance Mode (DX11) gives 20-30% more FPS than DX12
# - bShowGrass=True: Keep grass visible for casual users (pros toggle off in-game)
# - bRayTracing=False: Ray tracing has zero competitive benefit
# - bUseNanite=False: Nanite has zero competitive benefit
# - FortAntiAliasingMethod=Disabled: Performance Mode handles AA internally
# - LowInputLatencyModeIsEnabled=True: Reduces input delay
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Writing optimized Fortnite config (read-merge-write)..." -ForegroundColor DarkCyan

$TotalTargets = $TargetConfigPaths.Count
$WriteSuccessCount = 0
$WritableSuccessCount = 0
$WriteFailures = @()
$WritableFailures = @()

foreach ($ConfigPath in $TargetConfigPaths) {
    $ConfigDir = Split-Path $ConfigPath -Parent

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    # --- Read existing or create fresh config ---
    $ini = $null
    if (Test-Path $ConfigPath) {
        try {
            Backup-ConfigFile -Path $ConfigPath | Out-Null
            $ini = Read-FortniteIni -Path $ConfigPath
        } catch {
            Write-Host "[WARN] Backup/read failed for ${ConfigPath}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # If no existing config or read failed, create empty structure
    if ($null -eq $ini) {
        Write-Host "[INFO] Creating new config file: $ConfigPath" -ForegroundColor DarkCyan
        $ini = [ordered]@{
            '' = [System.Collections.Generic.List[string]]::new()
        }
    }

    try {
        # --- [/Script/FortniteGame.FortGameUserSettings] ---
        # These are the REAL key names from verified config dumps
        $fortSection = '/Script/FortniteGame.FortGameUserSettings'

        # Display and resolution
        Set-IniValue $ini $fortSection 'bUseVSync' 'False'
        Set-IniValue $ini $fortSection 'bUseDynamicResolution' 'False'
        Set-IniValue $ini $fortSection 'ResolutionSizeX' "$MonitorWidth"
        Set-IniValue $ini $fortSection 'ResolutionSizeY' "$MonitorHeight"
        Set-IniValue $ini $fortSection 'LastUserConfirmedResolutionSizeX' "$MonitorWidth"
        Set-IniValue $ini $fortSection 'LastUserConfirmedResolutionSizeY' "$MonitorHeight"
        Set-IniValue $ini $fortSection 'LastConfirmedFullscreenMode' '0'
        Set-IniValue $ini $fortSection 'PreferredFullscreenMode' '0'
        Set-IniValue $ini $fortSection 'FrameRateLimit' "${FrameRateLimit}.000000"
        Set-IniValue $ini $fortSection 'DesiredScreenWidth' "$MonitorWidth"
        Set-IniValue $ini $fortSection 'DesiredScreenHeight' "$MonitorHeight"
        Set-IniValue $ini $fortSection 'LastUserConfirmedDesiredScreenWidth' "$MonitorWidth"
        Set-IniValue $ini $fortSection 'LastUserConfirmedDesiredScreenHeight' "$MonitorHeight"
        Set-IniValue $ini $fortSection 'WindowPosX' '-1'
        Set-IniValue $ini $fortSection 'WindowPosY' '-1'
        Set-IniValue $ini $fortSection 'bUseHDRDisplayOutput' 'False'

        # Visual quality
        Set-IniValue $ini $fortSection 'bMotionBlur' 'False'
        Set-IniValue $ini $fortSection 'bShowGrass' 'True'
        Set-IniValue $ini $fortSection 'FortAntiAliasingMethod' 'Disabled'
        Set-IniValue $ini $fortSection 'TemporalSuperResolutionQuality' 'Custom'
        Set-IniValue $ini $fortSection 'DLSSQuality' '0'
        Set-IniValue $ini $fortSection 'DesiredGlobalIlluminationQuality' '0'
        Set-IniValue $ini $fortSection 'DesiredReflectionQuality' '0'
        Set-IniValue $ini $fortSection 'PreNaniteGlobalIlluminationQuality' '0'
        Set-IniValue $ini $fortSection 'PreNaniteReflectionQuality' '0'
        Set-IniValue $ini $fortSection 'bRayTracing' 'False'
        Set-IniValue $ini $fortSection 'bUseNanite' 'False'
        Set-IniValue $ini $fortSection 'bEnableDLSSFrameGeneration' 'False'

        # Performance and input
        Set-IniValue $ini $fortSection 'LowInputLatencyModeIsEnabled' 'True'
        Set-IniValue $ini $fortSection 'bAllowMultithreadedRendering' 'True'
        Set-IniValue $ini $fortSection 'bDisableMouseAcceleration' 'True'
        Set-IniValue $ini $fortSection 'bIsEnergySavingEnabledIdle' 'False'
        Set-IniValue $ini $fortSection 'bIsEnergySavingEnabledFocusLoss' 'False'
        Set-IniValue $ini $fortSection 'b120FpsMode' 'False'
        Set-IniValue $ini $fortSection 'bShowFPS' 'True'

        # Audio
        Set-IniValue $ini $fortSection 'AudioQualityLevel' '2'
        Set-IniValue $ini $fortSection 'LastConfirmedAudioQualityLevel' '2'

        # --- [ScalabilityGroups] ---
        # Values: 0=Off/Low, 1=Medium, 2=High, 3=Epic
        Set-IniValue $ini 'ScalabilityGroups' 'sg.ResolutionQuality' '100'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.ViewDistanceQuality' '1'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.AntiAliasingQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.ShadowQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.GlobalIlluminationQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.ReflectionQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.PostProcessQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.TextureQuality' '2'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.EffectsQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.FoliageQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.ShadingQuality' '0'
        Set-IniValue $ini 'ScalabilityGroups' 'sg.LandscapeQuality' '2'

        # --- [D3DRHIPreference] --- Forces Performance Mode (DX11)
        Set-IniValue $ini 'D3DRHIPreference' 'PreferredRHI' 'dx11'
        Set-IniValue $ini 'D3DRHIPreference' 'PreferredFeatureLevel' 'es31'

        # --- [PerformanceMode] --- Mesh quality for perf mode
        Set-IniValue $ini 'PerformanceMode' 'MeshQuality' '0'

        # --- [RayTracing] --- Disable ray tracing
        Set-IniValue $ini 'RayTracing' 'r.RayTracing.EnableInGame' 'False'

        # --- Write output ---
        Write-FortniteIni -Sections $ini -Path $ConfigPath

        # Verify key content was written
        $raw = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($raw -match 'sg\.ShadowQuality=0' -and $raw -match 'FrameRateLimit=' -and $raw -match 'PreferredRHI=dx11') {
            $WriteSuccessCount++
            Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green
        } else {
            $WriteFailures += "$ConfigPath (expected keys missing after write)"
            Write-Host "  [WARN] Config write verification failed: $ConfigPath" -ForegroundColor Yellow
        }
    } catch {
        $WriteFailures += "$ConfigPath ($($_.Exception.Message))"
        Write-Host "  [FAIL] Could not write config: $ConfigPath" -ForegroundColor Red
    }

    # Ensure writable so Fortnite can save in-game changes
    try {
        Set-ItemProperty -Path $ConfigPath -Name IsReadOnly -Value $false -ErrorAction Stop
        $isReadOnly = (Get-Item -Path $ConfigPath -ErrorAction Stop).IsReadOnly
        if (-not $isReadOnly) {
            $WritableSuccessCount++
            Write-Host "  [OK] Config writable (read-only cleared): $ConfigPath" -ForegroundColor Green
        } else {
            $WritableFailures += "$ConfigPath (IsReadOnly true)"
            Write-Host "  [WARN] Writable check failed (still read-only): $ConfigPath" -ForegroundColor Yellow
        }
    } catch {
        $WritableFailures += "$ConfigPath ($($_.Exception.Message))"
        Write-Host "  [FAIL] Could not clear read-only: $ConfigPath" -ForegroundColor Red
    }
}

if ($TotalTargets -eq 0) {
    Write-Check -Status 'WARN' -Key 'FN_CONFIG_FILES_WRITTEN' -Detail 'no config paths found'
    Write-Check -Status 'WARN' -Key 'FN_CONFIG_WRITABLE' -Detail 'no config paths found'
} else {
    if ($WriteSuccessCount -eq $TotalTargets) {
        Write-Check -Status 'OK' -Key 'FN_CONFIG_FILES_WRITTEN' -Detail "$WriteSuccessCount/$TotalTargets"
    } else {
        Write-Check -Status 'FAIL' -Key 'FN_CONFIG_FILES_WRITTEN' -Detail (($WriteFailures -join '; '))
    }

    if ($WritableSuccessCount -eq $TotalTargets) {
        Write-Check -Status 'OK' -Key 'FN_CONFIG_WRITABLE' -Detail "$WritableSuccessCount/$TotalTargets"
    } else {
        Write-Check -Status 'FAIL' -Key 'FN_CONFIG_WRITABLE' -Detail (($WritableFailures -join '; '))
    }
}

# -----------------------------------------------------------------------------
# SECTION 3: PERSISTENCE NOTE
# -----------------------------------------------------------------------------

Write-Host "  [NOTE] Config was applied and read-only was cleared so Fortnite can save in-game changes." -ForegroundColor DarkGray
Write-Host "  [NOTE] If Epic Cloud sync is enabled, cloud data may still override local files." -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# SECTION 4: EXE COMPATIBILITY FLAGS
# -----------------------------------------------------------------------------

$FNExePaths = @(
    "$env:LOCALAPPDATA\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe",
    "$env:ProgramFiles\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
)

$null = Set-ExeCompatFlags -ExePaths $FNExePaths -CheckKey 'FN_EXE_FLAGS' -Flags @('HIGHDPIAWARE')

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
Write-Host "                           Config: PreferredRHI=dx11, MeshQuality=0" -ForegroundColor DarkGray
Write-Host "                           Increases FPS by 20-30% vs DX12" -ForegroundColor DarkGray
Write-Host "                           Set in-game: Settings > Video > Rendering Mode" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- VIDEO SETTINGS (written to config) ---" -ForegroundColor Cyan
Write-Host "  Window Mode            : Fullscreen Exclusive (PreferredFullscreenMode=0)" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Frame Rate Limit       : Uncapped (FrameRateLimit=0)" -ForegroundColor White
Write-Host "  3D Resolution          : 100% (sg.ResolutionQuality=100)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF (bUseVSync=False)" -ForegroundColor White
Write-Host "  Multithreaded Rendering: ON (bAllowMultithreadedRendering=True)" -ForegroundColor White
Write-Host "  Low Input Latency      : ON (LowInputLatencyModeIsEnabled=True)" -ForegroundColor White
Write-Host "  Show Grass             : ON (bShowGrass=True)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (written to config) ---" -ForegroundColor Cyan
Write-Host "  View Distance          : Medium (sg.ViewDistanceQuality=1)" -ForegroundColor White
Write-Host "  Shadows                : OFF (sg.ShadowQuality=0)" -ForegroundColor White
Write-Host "  Global Illumination    : OFF (sg.GlobalIlluminationQuality=0)" -ForegroundColor White
Write-Host "  Reflections            : OFF (sg.ReflectionQuality=0)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : OFF (sg.AntiAliasingQuality=0)" -ForegroundColor White
Write-Host "  Textures               : High (sg.TextureQuality=2 -- no FPS cost on 6GB+)" -ForegroundColor White
Write-Host "  Effects                : OFF (sg.EffectsQuality=0)" -ForegroundColor White
Write-Host "  Post Processing        : OFF (sg.PostProcessQuality=0)" -ForegroundColor White
Write-Host "  Foliage                : OFF (sg.FoliageQuality=0)" -ForegroundColor White
Write-Host "  Shading                : OFF (sg.ShadingQuality=0)" -ForegroundColor White
Write-Host "  Landscape              : High (sg.LandscapeQuality=2)" -ForegroundColor White

Write-Host ""
Write-Host "  --- NVIDIA/AMD SPECIFIC (written to config) ---" -ForegroundColor Cyan
Write-Host "  NVIDIA Reflex          : Set in-game to On + Boost (most impactful)" -ForegroundColor White
Write-Host "  Anti-Aliasing Method   : Disabled (FortAntiAliasingMethod=Disabled)" -ForegroundColor White
Write-Host "  DLSS                   : OFF (DLSSQuality=0)" -ForegroundColor White
Write-Host "  DLSS Frame Generation  : OFF (bEnableDLSSFrameGeneration=False)" -ForegroundColor White
Write-Host "  Hardware RT            : OFF (bRayTracing=False)" -ForegroundColor White
Write-Host "  Nanite                 : OFF (bUseNanite=False)" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO (set in-game) ---" -ForegroundColor Cyan
Write-Host "  Audio Quality          : High (AudioQualityLevel=2 in config)" -ForegroundColor White
Write-Host "  Sound Effects          : 100" -ForegroundColor White
Write-Host "  Music                  : 0 (eliminates audio masking of footsteps)" -ForegroundColor White
Write-Host "  Voice Chat             : 70 (team comms)" -ForegroundColor White
Write-Host "  Subtitles              : OFF" -ForegroundColor White
Write-Host "  3D Headphones (HRTF)   : ON if using headphones (superior positional audio)" -ForegroundColor White
Write-Host "  Visualize Sound FX     : ON (visual indicator for nearby audio events)" -ForegroundColor White
Write-Host "  Mouse Acceleration     : OFF (bDisableMouseAcceleration=True in config)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- SENSITIVITY (set in-game) ---" -ForegroundColor Cyan
Write-Host "  X/Y Axis Sensitivity   : 7-10 (most pros use 7-12)" -ForegroundColor White
Write-Host "  ADS Sensitivity        : 65-75%" -ForegroundColor White
Write-Host "  Scope Sensitivity      : 65%" -ForegroundColor White
Write-Host "  Polling Rate           : 1000Hz+ recommended" -ForegroundColor White

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
