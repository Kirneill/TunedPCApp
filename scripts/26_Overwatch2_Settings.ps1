#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Overwatch 2 - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Blizzard Proprietary (successor to original Overwatch engine)
    Anti-Cheat: Defense Matrix (Blizzard proprietary)

.DESCRIPTION
    Applies Overwatch 2 config file optimizations and Windows EXE flags.
    Defense Matrix does NOT monitor config file edits -- Settings_v0.ini is
    a standard user preferences file meant to be editable.

    OVERWATCH 2 OPTIMIZATION PHILOSOPHY:
    Overwatch 2 is a fast-paced hero shooter where low input latency and
    high FPS are critical. The game supports up to 600 FPS cap (game max).
    Most competitive players use all-low settings with max FOV.

    CONFIG FORMAT:
    Custom INI with quoted string values. Section headers have version
    numbers (e.g., [Render.13], [Sound.3]). All values are double-quoted
    strings, even numbers: Key = "value"

    PATH:
    %USERPROFILE%\Documents\Overwatch\Settings\Settings_v0.ini
    Shared between Battle.net and Steam installations.

    IMPORTANT:
    - The game overwrites Settings_v0.ini on exit. We set read-only
      after writing to preserve competitive settings.
    - NVIDIA Reflex must be set in-game (not in config file).
    - CpuForceSyncEnabled (Reduce Buffering) conflicts with Reflex --
      disable it on NVIDIA GPUs, enable on AMD.

    SOURCES:
    - github.com/Marqasa/overwatch-settings (typed Zod schema)
    - Multiple verified community configs (see research file)
    - Blizzard Forums CpuForceSyncEnabled discussion

.NOTES
    DEFENSE MATRIX NOTE: This script only touches user config and Windows
    compatibility flags. Defense Matrix focuses on runtime cheat detection,
    not config file monitoring. Editing Settings_v0.ini is explicitly safe.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# Overwatch 2 max FPS cap is 600 (no true uncapped). Not using Get-FrameRateLimit.
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'OVERWATCH 2 - Optimization Script' `
               -Subtitle 'March 2026 | Blizzard Engine | Defense Matrix Anti-Cheat'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : 600 (game maximum -- no true uncapped)" -ForegroundColor White
Write-Host "  GPU Vendor        : $(if ($NvidiaGPU) { 'NVIDIA (Reflex in-game)' } else { 'AMD (Reduce Buffering on)' })" -ForegroundColor White
Write-Host ""

# =============================================================================
# INI PARSER: Overwatch 2 Custom INI Format
# =============================================================================
# Overwatch uses a custom INI where ALL values are double-quoted strings:
#   Key = "value"
# Section headers include version numbers: [Render.13], [Sound.3]
# This is NOT standard INI and NOT UE4 INI -- requires a custom parser.

function Read-OW2IniFile {
    param([string]$Path)
    $sections = [ordered]@{}
    $currentSection = ""
    $skippedCount = 0
    foreach ($line in (Get-Content $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [ordered]@{}
            }
        } elseif ($currentSection -and $trimmed -match '^(\S+)\s*=\s*"(.*)"$') {
            $sections[$currentSection][$Matches[1]] = $Matches[2]
        } elseif ($currentSection) {
            $skippedCount++
        }
    }
    if ($skippedCount -gt 0) {
        Write-Host "[WARN] Skipped $skippedCount unparseable lines in Settings_v0.ini" -ForegroundColor Yellow
    }
    return $sections
}

function Write-OW2IniFile {
    param([string]$Path, [System.Collections.Specialized.OrderedDictionary]$Sections)
    $lines = New-Object System.Collections.Generic.List[string]
    $first = $true
    foreach ($sectionName in $Sections.Keys) {
        if (-not $first) { $lines.Add("") }
        $first = $false
        $lines.Add("[$sectionName]")
        foreach ($key in $Sections[$sectionName].Keys) {
            $val = $Sections[$sectionName][$key]
            $lines.Add("$key = `"$val`"")
        }
    }
    # Write UTF-8 without BOM (safest for cross-engine compatibility)
    $content = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Merge-OW2IniSection {
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
# SECTION 1: LOCATE AND WRITE OVERWATCH 2 CONFIG
# =============================================================================
# Config path: %USERPROFILE%\Documents\Overwatch\Settings\Settings_v0.ini
# Shared between Battle.net and Steam installations.

$ConfigDir = Join-Path $env:USERPROFILE "Documents\Overwatch\Settings"
$ConfigPath = Join-Path $ConfigDir "Settings_v0.ini"

try {
    if (-not (Test-Path $ConfigDir)) {
        Write-Host "[INFO] Overwatch config folder not found. Creating: $ConfigDir" -ForegroundColor DarkCyan
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    # READ existing config if present
    if (Test-Path $ConfigPath) {
        Backup-ConfigFile -Path $ConfigPath | Out-Null
        try {
            $iniData = Read-OW2IniFile -Path $ConfigPath
        } catch {
            Write-Host "[WARN] Settings_v0.ini could not be parsed: $_" -ForegroundColor Yellow
            Write-Host "       Delete the file and launch Overwatch 2 once to regenerate defaults." -ForegroundColor Yellow
            $iniData = [ordered]@{}
        }
    } else {
        Write-Host "[INFO] No existing config at $ConfigPath -- creating fresh" -ForegroundColor DarkCyan
        $iniData = [ordered]@{}
    }

    # --- Competitive performance settings for [Render.13] ---
    # We ONLY override performance keys. Display/resolution/brightness keys
    # are PRESERVED from the existing config.
    $RenderOverrides = [ordered]@{
        'GFXPresetLevel'            = '1'
        'AADetail'                  = '0'
        'DirectionalShadowDetail'   = '1'
        'SimpleDirectionalShadows'  = '1'
        'EffectsQuality'            = '1'
        'LightQuality'              = '0'
        'LocalFogDetail'            = '1'
        'LocalReflections'          = '0'
        'MaxAnisotropy'             = '1'
        'MaxEffectsAnisotropy'      = '1'
        'MaxExtraQualityAnisotropy' = '1'
        'ModelQuality'              = '1'
        'PhysicsQuality'            = '1'
        'RefractionDetail'          = '0'
        'ShaderQuality'             = '1'
        'SSAODetail'                = '0'
        'SSLRDetailLevel'           = '0'
        'SSQuality'                 = '0'
        'TextureDetail'             = '1'
        'TranslucentShadowDetail'   = '0'
        'HighQualityUpsample'       = '0'
        'ImageSharpening'           = '0.000000'
        'WaterCombineCascades'      = '0'
        'SoundQuality'              = '0'
        'FrameRateCap'              = '600'
        'UseCustomFrameRates'       = '1'
        'LimitTo30'                 = '0'
        'LimitToRefresh'            = '0'
        'VerticalSyncEnabled'       = '0'
        'TripleBufferingEnabled'    = '0'
        'DynamicRenderScale'        = '0'
        'UseCustomWorldScale'       = '1'
        'MaxWorldScale'             = '100'
        'MinWorldScale'             = '100'
        'WindowMode'                = '0'
        'FullscreenWindow'          = '0'
        'FullscreenWindowEnabled'   = '0'
        'WindowedFullscreen'        = '0'
        'HorizontalFOV'             = '103.000000'
        'ShowFPSCounter'            = '1'
        'RenderScale'               = '0'
        'UseGPUScale'               = '0'
        'AnisotropicFiltering'      = '1'
    }

    # GPU-specific: CpuForceSyncEnabled (Reduce Buffering)
    # NVIDIA: OFF (use Reflex in-game instead -- overlap causes stuttering)
    # AMD: ON (no Reflex available, Reduce Buffering lowers input lag)
    if ($NvidiaGPU) {
        $RenderOverrides['CpuForceSyncEnabled'] = '0'
        Write-Host "[INFO] NVIDIA GPU detected -- CpuForceSyncEnabled OFF (use Reflex in-game)" -ForegroundColor DarkCyan
    } else {
        $RenderOverrides['CpuForceSyncEnabled'] = '1'
        Write-Host "[INFO] AMD GPU detected -- CpuForceSyncEnabled ON (Reduce Buffering)" -ForegroundColor DarkCyan
    }

    # MERGE performance settings into [Render.13]
    Merge-OW2IniSection -Existing $iniData -SectionName 'Render.13' -Overrides $RenderOverrides

    # --- Cinematics settings ---
    $CinematicsOverrides = [ordered]@{
        'ShowIntro' = '0'
    }
    Merge-OW2IniSection -Existing $iniData -SectionName 'Cinematics.1' -Overrides $CinematicsOverrides

    # --- Sound settings ---
    $SoundOverrides = [ordered]@{
        'AudioMix'    = '0'
        'MusicVolume' = '0.000000'
        'SFXVolume'   = '100.000000'
        'VoiceVolume' = '100.000000'
    }
    Merge-OW2IniSection -Existing $iniData -SectionName 'Sound.3' -Overrides $SoundOverrides

    # --- Input settings ---
    $InputOverrides = [ordered]@{
        'HighTickInput' = '1'
    }
    Merge-OW2IniSection -Existing $iniData -SectionName 'Input.1' -Overrides $InputOverrides

    # UNLOCK before write (no-op if already writable, required on re-runs after read-only lock)
    Unlock-ConfigFile -Path $ConfigPath

    # WRITE with UTF-8 no BOM
    Write-OW2IniFile -Path $ConfigPath -Sections $iniData

    # LOCK read-only to prevent Overwatch from overwriting on exit
    Lock-ConfigFile -Path $ConfigPath

    # Verify the write
    $verifyContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
    if ($verifyContent -match 'FrameRateCap\s*=\s*"600"' -and $verifyContent -match 'AADetail\s*=\s*"0"') {
        Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green
        Write-Check -Status 'OK' -Key 'OW2_CONFIG_WRITTEN'
    } else {
        Write-Host "  [WARN] Config write verification failed: $ConfigPath" -ForegroundColor Yellow
        Write-Check -Status 'WARN' -Key 'OW2_CONFIG_WRITTEN' -Detail 'VERIFICATION_FAILED'
    }
} catch {
    Write-Host "  [FAIL] Could not write config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Check -Status 'FAIL' -Key 'OW2_CONFIG_WRITTEN' -Detail $_.Exception.Message
}

# =============================================================================
# SECTION 2: EXE COMPATIBILITY FLAGS FOR OVERWATCH 2
# =============================================================================
# Defense Matrix does NOT monitor AppCompat flags. These are standard
# Windows-layer flags applied by the OS before the process starts.

$OW2ExePaths = @()

# Check env var from host app first
if ($env:OVERWATCH2_PATH -and (Test-Path $env:OVERWATCH2_PATH)) {
    # env var may point to game root or directly to exe
    if ($env:OVERWATCH2_PATH -match '\.exe$') {
        $OW2ExePaths += $env:OVERWATCH2_PATH
    } else {
        # Battle.net layout: root\_retail_\Overwatch.exe
        $OW2ExePaths += Join-Path $env:OVERWATCH2_PATH "_retail_\Overwatch.exe"
        # Steam layout: root\Overwatch.exe
        $OW2ExePaths += Join-Path $env:OVERWATCH2_PATH "Overwatch.exe"
    }
}

# Battle.net common paths
$OW2ExePaths += @(
    "C:\Program Files (x86)\Overwatch\_retail_\Overwatch.exe",
    "D:\Program Files (x86)\Overwatch\_retail_\Overwatch.exe",
    "D:\Overwatch\_retail_\Overwatch.exe",
    "E:\Overwatch\_retail_\Overwatch.exe",
    "C:\Games\Overwatch\_retail_\Overwatch.exe"
)

# Steam common paths
$OW2ExePaths += @(
    "C:\Program Files (x86)\Steam\steamapps\common\Overwatch\Overwatch.exe",
    "D:\Steam\steamapps\common\Overwatch\Overwatch.exe",
    "D:\SteamLibrary\steamapps\common\Overwatch\Overwatch.exe",
    "E:\Steam\steamapps\common\Overwatch\Overwatch.exe",
    "E:\SteamLibrary\steamapps\common\Overwatch\Overwatch.exe"
)

$null = Set-ExeCompatFlags -ExePaths $OW2ExePaths -CheckKey 'OW2_EXE_FLAGS'

# =============================================================================
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# =============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  OVERWATCH 2 - COMPLETE SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS (set via config file) ---" -ForegroundColor Cyan
Write-Host "  Display Mode           : Fullscreen" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  FPS Cap                : 600 (game maximum)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Triple Buffering       : OFF" -ForegroundColor White
Write-Host "  Dynamic Render Scale   : OFF" -ForegroundColor White
Write-Host "  Render Scale           : 100%% (native)" -ForegroundColor White
Write-Host "  Field of View          : 103 (maximum)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (set via config file) ---" -ForegroundColor Cyan
Write-Host "  Graphics Quality       : Low" -ForegroundColor White
Write-Host "  Texture Quality        : Low" -ForegroundColor White
Write-Host "  Texture Filtering      : Low (1x)" -ForegroundColor White
Write-Host "  Shadow Detail          : Low" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White
Write-Host "  Local Reflections      : OFF" -ForegroundColor White
Write-Host "  Effects Detail         : Low" -ForegroundColor White
Write-Host "  Lighting Detail        : Low" -ForegroundColor White
Write-Host "  Model Quality          : Low" -ForegroundColor White
Write-Host "  Fog Detail             : Low" -ForegroundColor White
Write-Host "  Refraction Quality     : Low" -ForegroundColor White
Write-Host "  FSR / Upsampling       : OFF (native rendering)" -ForegroundColor White
Write-Host "  Image Sharpening       : 0%% (only active with FSR)" -ForegroundColor White

Write-Host ""
Write-Host "  --- MUST SET IN-GAME (not in config file) ---" -ForegroundColor Cyan
Write-Host "  NVIDIA Reflex          : On + Boost (most important setting)" -ForegroundColor White
Write-Host "                         Reduces system latency by up to 50%%" -ForegroundColor DarkGray
if ($NvidiaGPU) {
    Write-Host "                         Reduce Buffering set to OFF (conflicts with Reflex)" -ForegroundColor DarkGray
} else {
    Write-Host "                         Not available on AMD -- Reduce Buffering set to ON" -ForegroundColor DarkGray
}
Write-Host "  High Precision Mouse   : ON (Gameplay > Miscellaneous)" -ForegroundColor White
Write-Host "                         Makes aim significantly more responsive" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- REDUCE BUFFERING vs REFLEX NOTE ---" -ForegroundColor Cyan
Write-Host "  Do NOT enable both Reduce Buffering and NVIDIA Reflex." -ForegroundColor White
Write-Host "  They overlap and can cause stuttering." -ForegroundColor White
if ($NvidiaGPU) {
    Write-Host "  NVIDIA: Reflex On + Boost in-game, Reduce Buffering OFF (set in config)" -ForegroundColor White
} else {
    Write-Host "  AMD: Reduce Buffering ON (set in config), Reflex not available" -ForegroundColor White
}

Write-Host ""
Write-Host "  --- AUDIO SETTINGS (competitive) ---" -ForegroundColor Cyan
Write-Host "  Audio Mix              : Studio Reference (clearest directional audio)" -ForegroundColor White
Write-Host "                         Default 'Headphones' is muddy -- Studio Reference" -ForegroundColor DarkGray
Write-Host "                         provides best footstep and ability clarity" -ForegroundColor DarkGray
Write-Host "  Music Volume           : 0%% (disabled for competitive focus)" -ForegroundColor White
Write-Host "  Sound Effects          : 100%%" -ForegroundColor White
Write-Host "  Voice Volume           : 100%%" -ForegroundColor White

Write-Host ""
Write-Host "  --- OTHER SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Skip Intro             : Yes (set in config)" -ForegroundColor White
Write-Host "  FPS Counter            : On (set in config)" -ForegroundColor White
Write-Host "  High Tick Input        : On (set in config)" -ForegroundColor White
Write-Host "  Config Lock            : Read-only (prevents game from overwriting)" -ForegroundColor White

Write-Host ""
if ($script:ValidationFailed) {
    Write-Host "[FAIL] Overwatch 2 optimization completed with validation failures." -ForegroundColor Red
    Write-Check -Status 'WARN' -Key 'OW2_SETTINGS_APPLIED' -Detail 'PARTIAL'
    exit 1
}

Write-Host "[DONE] Overwatch 2 config written. Set NVIDIA Reflex and High Precision Mouse in-game." -ForegroundColor Green
Write-Check -Status 'OK' -Key 'OW2_SETTINGS_APPLIED'
Write-Host ""
