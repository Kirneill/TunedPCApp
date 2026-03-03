#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Marvel Rivals - PC Optimization Script
    Version: 1.0 | March 2026
    Engine: Unreal Engine 5 (NetEase Games)

.DESCRIPTION
    Applies Windows EXE flags and Marvel Rivals config file optimizations.
    Marvel Rivals uses UE5 with internal project name "Marvel".
    Config path: %LOCALAPPDATA%\Marvel\Saved\Config\Windows\

    OPTIMIZATION PHILOSOPHY:
    Marvel Rivals is a hero shooter where visual clarity matters for tracking
    abilities and enemy movements. Settings balance max FPS with clean visuals:
    - All quality groups set to Low for maximum FPS
    - View Distance kept at Medium to avoid pop-in
    - Textures kept at Medium (VRAM-bound, minimal FPS cost)
    - All visual clutter disabled (motion blur, bloom, DoF, film grain)
    - NVIDIA Reflex On for lowest input latency (Boost must be set in-game)

.NOTES
    Key names verified against: UE5 standard ScalabilityGroups and
    community configs from Steam guide ID 3378914623.
    Steam App ID: 2767030
    Config folder: %LOCALAPPDATA%\Marvel\Saved\Config\Windows\
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# ------------------------------------------------------------------------------

Write-SQHeader -Title 'Marvel Rivals - Optimization Script v1.0' `
               -Subtitle 'March 2026 | Unreal Engine 5 | Steam App 2767030'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  GPU               : $(if ($NvidiaGPU) { 'NVIDIA (DLSS)' } else { 'AMD/Intel (FSR)' })" -ForegroundColor White
Write-Host ""

# =============================================================================
# HELPER FUNCTIONS: Read-Merge-Write for UE5 INI files
# =============================================================================

function Read-IniFile {
    param([string]$Path)
    $sections = [ordered]@{}
    $currentSection = ""
    if (-not (Test-Path $Path)) { return $sections }
    foreach ($line in (Get-Content $Path)) {
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }
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

# =============================================================================
# SECTION 1: LOCATE MARVEL RIVALS AND SET EXE FLAGS
# =============================================================================

Write-Host "[SECTION 1] Locating Marvel Rivals and setting EXE flags..." -ForegroundColor Yellow
Write-Host ""

try {
    $ExePaths = New-Object 'System.Collections.Generic.List[string]'

    # Helper to add unique non-empty paths
    function Add-UniquePath {
        param(
            [System.Collections.Generic.List[string]]$List,
            [string]$Path
        )
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if (-not $List.Contains($Path)) { $List.Add($Path) }
    }

    # If provided by host process, trust this first
    $DetectedPath = $env:MARVEL_RIVALS_PATH
    if (-not [string]::IsNullOrWhiteSpace($DetectedPath)) {
        if ($DetectedPath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-UniquePath -List $ExePaths -Path $DetectedPath
        } else {
            Add-UniquePath -List $ExePaths -Path (Join-Path $DetectedPath "MarvelRivals_Launcher.exe")
            Add-UniquePath -List $ExePaths -Path (Join-Path $DetectedPath "MarvelRivals.exe")
            Add-UniquePath -List $ExePaths -Path (Join-Path $DetectedPath "Marvel\Binaries\Win64\Marvel-Win64-Shipping.exe")
        }
    }

    # Steam uninstall registry (App ID 2767030)
    try {
        $regPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2767030" -ErrorAction SilentlyContinue).InstallLocation
        if ($regPath -and (Test-Path $regPath)) {
            Add-UniquePath -List $ExePaths -Path (Join-Path $regPath "MarvelRivals_Launcher.exe")
            Add-UniquePath -List $ExePaths -Path (Join-Path $regPath "MarvelRivals.exe")
            Add-UniquePath -List $ExePaths -Path (Join-Path $regPath "Marvel\Binaries\Win64\Marvel-Win64-Shipping.exe")
        }
    } catch {
        Write-Host "  [WARN] Registry detection failed: $_" -ForegroundColor Yellow
    }

    # Common Steam paths
    $CommonRoots = @(
        "$env:PROGRAMFILES(x86)\Steam\steamapps\common\MarvelRivals",
        "$env:PROGRAMFILES\Steam\steamapps\common\MarvelRivals",
        "C:\Steam\steamapps\common\MarvelRivals",
        "C:\SteamLibrary\steamapps\common\MarvelRivals",
        "D:\Steam\steamapps\common\MarvelRivals",
        "D:\SteamLibrary\steamapps\common\MarvelRivals",
        "E:\Steam\steamapps\common\MarvelRivals",
        "E:\SteamLibrary\steamapps\common\MarvelRivals"
    )
    foreach ($root in $CommonRoots) {
        Add-UniquePath -List $ExePaths -Path (Join-Path $root "MarvelRivals_Launcher.exe")
        Add-UniquePath -List $ExePaths -Path (Join-Path $root "MarvelRivals.exe")
        Add-UniquePath -List $ExePaths -Path (Join-Path $root "Marvel\Binaries\Win64\Marvel-Win64-Shipping.exe")
    }

    $null = Set-ExeCompatFlags -ExePaths $ExePaths.ToArray() -CheckKey 'MR_EXE_FLAGS'
} catch {
    Write-Host "  [FAIL] EXE flags section crashed: $_" -ForegroundColor Red
    Write-Check -Status FAIL -Key MR_EXE_FLAGS -Detail "SECTION_CRASH: $_"
}

# =============================================================================
# SECTION 2: WRITE OPTIMIZED CONFIG
# Read-Merge-Write for GameUserSettings.ini; full overwrite for Engine.ini
# (Engine.ini contains only CVar overrides with no user-specific data)
# =============================================================================

Write-Host ""
Write-Host "[SECTION 2] Writing optimized Marvel Rivals config..." -ForegroundColor Yellow
Write-Host ""

try {
    # Detect config directory -- folder name may vary
    $ConfigDir = $null
    $PossibleNames = @("Marvel", "MarvelRivals", "Marvel Rivals")
    foreach ($name in $PossibleNames) {
        $testPath = "$env:LOCALAPPDATA\$name\Saved\Config\Windows"
        if (Test-Path $testPath) {
            $ConfigDir = $testPath
            break
        }
    }

    # Fallback: scan %LOCALAPPDATA% for Marvel* directories with Saved\Config
    if (-not $ConfigDir) {
        $localAppData = $env:LOCALAPPDATA
        if ($localAppData -and (Test-Path $localAppData)) {
            $marvelDirs = Get-ChildItem -Path $localAppData -Directory -Filter "Marvel*" -ErrorAction SilentlyContinue
            foreach ($dir in $marvelDirs) {
                $candidate = Join-Path $dir.FullName "Saved\Config\Windows"
                if (Test-Path $candidate) {
                    $ConfigDir = $candidate
                    break
                }
            }
        }
    }

    # Last resort: create the default path
    if (-not $ConfigDir) {
        $ConfigDir = "$env:LOCALAPPDATA\Marvel\Saved\Config\Windows"
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        Write-Host "  [INFO] No existing Marvel Rivals config found. Created: $ConfigDir" -ForegroundColor DarkCyan
    }

    Write-Host "  [INFO] Config directory: $ConfigDir" -ForegroundColor DarkCyan

    # --- Competitive overrides by section ---

    # Scalability quality groups (0=Low, 1=Medium, 2=High, 3=Epic, 4=Cinematic)
    $ScalabilityOverrides = [ordered]@{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '1'
        'sg.AntiAliasingQuality'       = '0'
        'sg.PostProcessQuality'        = '0'
        'sg.ShadowQuality'            = '0'
        'sg.GlobalIlluminationQuality' = '0'
        'sg.ReflectionQuality'        = '0'
        'sg.EffectsQuality'           = '0'
        'sg.FoliageQuality'           = '0'
        'sg.TextureQuality'           = '1'
        'sg.ShadingQuality'           = '0'
    }

    # Marvel-specific GameUserSettings section (takes precedence over UE5 base)
    # AntiAliasingSuperSamplingMode: 0=Off, 1=TAAU, 2=DLSS, 3=FSR, 4=TSR, 5=XeSS
    #   (mapping inferred from community configs; verify in-game if behavior changes)
    # SuperSamplingQuality: 0=UltraPerf, 1=Perf, 2=Balanced, 3=Quality, 4=UltraQuality
    $MarvelOverrides = [ordered]@{
        'bUseVSync'                         = 'False'
        'bUseDynamicResolution'             = 'False'
        'FullscreenMode'                    = '0'
        'LastConfirmedFullscreenMode'       = '0'
        'PreferredFullscreenMode'           = '0'
        'FrameRateLimit'                    = '0.000000'
        'ResolutionSizeX'                   = "$MonitorWidth"
        'ResolutionSizeY'                   = "$MonitorHeight"
        'LastUserConfirmedResolutionSizeX'  = "$MonitorWidth"
        'LastUserConfirmedResolutionSizeY'  = "$MonitorHeight"
        'DesiredScreenWidth'                = "$MonitorWidth"
        'DesiredScreenHeight'               = "$MonitorHeight"
        'AntiAliasingSuperSamplingMode'     = if ($NvidiaGPU) { '2' } else { '3' }
        'SuperSamplingQuality'              = '3'
        'CASSharpness'                      = '1.000000'
        'bNvidiaReflex'                     = if ($NvidiaGPU) { 'True' } else { 'False' }
        'bXeLowLatency'                     = 'False'
        'bDlssFrameGeneration'              = 'False'
        'bFSRFrameGeneration'               = 'False'
        'bXeFrameGeneration'                = 'False'
        'bUseHDRDisplayOutput'              = 'False'
    }

    # UE5 base GameUserSettings
    $EngineGameUserOverrides = [ordered]@{
        'bUseDesiredScreenHeight'           = 'False'
    }

    # Engine.ini content (separate file -- advanced render command overrides)
    # Full overwrite is intentional: Engine.ini contains only CVar overrides
    # with no user-specific data (resolution, account, keybinds live elsewhere)
    $EngineIniContent = @"
[SystemSettings]
r.Shadow.MaxResolution=512
r.Shadow.MaxCSMResolution=512
r.Shadow.CSM.MaxCascades=1
r.ContactShadows=0
r.VolumetricFog=0
r.VolumetricCloud=0
r.LightShaftBloom=0
r.EyeAdaptationQuality=0
r.SSR.Quality=0
r.AmbientOcclusionLevels=0

[/Script/Engine.RendererSettings]
r.MotionBlurQuality=0
r.DepthOfFieldQuality=0
r.BloomQuality=0
r.LensFlareQuality=0
r.FilmGrain=0
r.Tonemapper.Sharpen=0
r.SceneColorFringeQuality=0

[/Script/Engine.InputSettings]
bEnableMouseSmoothing=False
bViewAccelerationEnabled=False
"@

    $GameUserSettingsIni = Join-Path $ConfigDir "GameUserSettings.ini"
    $EngineIni = Join-Path $ConfigDir "Engine.ini"

    # --- Backup existing files ---
    if (Test-Path $GameUserSettingsIni) {
        Backup-ConfigFile -Path $GameUserSettingsIni | Out-Null
    }
    if (Test-Path $EngineIni) {
        Backup-ConfigFile -Path $EngineIni | Out-Null
    }

    # --- Read-Merge-Write GameUserSettings.ini ---
    $config = Read-IniFile -Path $GameUserSettingsIni
    Merge-IniSection -Config $config -SectionName 'ScalabilityGroups' -Overrides $ScalabilityOverrides
    Merge-IniSection -Config $config -SectionName '/Script/Marvel.MarvelGameUserSettings' -Overrides $MarvelOverrides
    Merge-IniSection -Config $config -SectionName '/Script/Engine.GameUserSettings' -Overrides $EngineGameUserOverrides
    Write-IniFile -Path $GameUserSettingsIni -Config $config
    Lock-ConfigFile -Path $GameUserSettingsIni
    Write-Host "  [OK] GameUserSettings.ini written to: $GameUserSettingsIni" -ForegroundColor Green

    # --- Write Engine.ini (CVar overrides only, no user data to preserve) ---
    [System.IO.File]::WriteAllText($EngineIni, $EngineIniContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  [OK] Engine.ini written to: $EngineIni" -ForegroundColor Green

    Write-Check -Status OK -Key MR_CONFIG_WRITTEN
}
catch {
    Write-Host "[FAIL] Error writing config: $_" -ForegroundColor Red
    Write-Check -Status FAIL -Key MR_CONFIG_WRITTEN -Detail "WRITE_ERROR: $_"
    Write-Check -Status FAIL -Key MR_SETTINGS_APPLIED -Detail "CONFIG_WRITE_FAILED"
    exit 1
}

# =============================================================================
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# =============================================================================

try {
    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Yellow
    Write-Host "  MARVEL RIVALS - COMPLETE SETTINGS GUIDE" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "  --- DISPLAY SETTINGS ---" -ForegroundColor Cyan
    Write-Host "  Window Mode            : Fullscreen Exclusive (FullscreenMode=0)" -ForegroundColor White
    Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
    Write-Host "  Frame Rate Limit       : Unlimited (FrameRateLimit=0)" -ForegroundColor White
    Write-Host "  V-Sync                 : OFF" -ForegroundColor White

    Write-Host ""
    Write-Host "  --- UPSCALING (Applied via Config) ---" -ForegroundColor Cyan
    if ($NvidiaGPU) {
        Write-Host "  DLSS                   : Quality (SuperSamplingQuality=3)" -ForegroundColor White
        Write-Host "  DLSS Frame Generation  : OFF (adds input latency)" -ForegroundColor White
        Write-Host "  NVIDIA Reflex          : ON (set Boost in-game for best latency)" -ForegroundColor White
        Write-Host "  Dynamic Resolution     : OFF" -ForegroundColor White
    } else {
        Write-Host "  FSR                    : Quality (SuperSamplingQuality=3)" -ForegroundColor White
        Write-Host "  FSR Frame Generation   : OFF (adds input latency)" -ForegroundColor White
        Write-Host "  Dynamic Resolution     : OFF" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  --- GRAPHICS QUALITY (Applied via Config) ---" -ForegroundColor Cyan
    Write-Host "  Shadows                : Low (sg=0, biggest FPS gain)" -ForegroundColor White
    Write-Host "  Global Illumination    : Low (sg=0, Lumen GI very expensive)" -ForegroundColor White
    Write-Host "  Reflections            : Low (sg=0)" -ForegroundColor White
    Write-Host "  Effects                : Low (sg=0, reduces ability particles)" -ForegroundColor White
    Write-Host "  Post Processing        : Low (sg=0)" -ForegroundColor White
    Write-Host "  Shading                : Low (sg=0)" -ForegroundColor White
    Write-Host "  Anti-Aliasing          : Low (sg=0)" -ForegroundColor White
    Write-Host "  Foliage                : Low (sg=0)" -ForegroundColor White
    Write-Host "  View Distance          : Medium (sg=1, avoids pop-in)" -ForegroundColor White
    Write-Host "  Textures               : Medium (sg=1, minimal FPS cost)" -ForegroundColor White
    Write-Host "  Resolution Quality     : 100%% (native)" -ForegroundColor White

    Write-Host ""
    Write-Host "  --- VISUAL CLUTTER (Disabled via Engine.ini) ---" -ForegroundColor Cyan
    Write-Host "  Motion Blur            : OFF" -ForegroundColor White
    Write-Host "  Depth of Field         : OFF" -ForegroundColor White
    Write-Host "  Bloom                  : OFF" -ForegroundColor White
    Write-Host "  Lens Flare             : OFF" -ForegroundColor White
    Write-Host "  Film Grain             : OFF" -ForegroundColor White
    Write-Host "  Chromatic Aberration   : OFF (r.SceneColorFringeQuality=0)" -ForegroundColor White
    Write-Host "  Volumetric Fog         : OFF" -ForegroundColor White
    Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White
    Write-Host "  Screen Space Reflections: OFF" -ForegroundColor White

    Write-Host ""
    Write-Host "  --- INPUT ---" -ForegroundColor Cyan
    Write-Host "  Mouse Smoothing        : OFF" -ForegroundColor White
    Write-Host "  Mouse Acceleration     : OFF" -ForegroundColor White

    Write-Host ""
    Write-Host "  CAS Sharpness          : 1.0 (restores upscaling clarity)" -ForegroundColor White

    Write-Host ""
    Write-Host "[DONE] Marvel Rivals optimization complete." -ForegroundColor Green
    Write-Check -Status OK -Key MR_SETTINGS_APPLIED
    Write-Host ""
} catch {
    Write-Check -Status FAIL -Key MR_SETTINGS_APPLIED -Detail "GUIDE_OUTPUT_ERROR: $_"
}
