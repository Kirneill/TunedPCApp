#Requires -RunAsAdministrator
<#
.SYNOPSIS
    League of Legends - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Riot proprietary engine
    Anti-Cheat: Vanguard (kernel-level)

.DESCRIPTION
    Applies Windows EXE flags and League of Legends game.cfg optimizations.
    League uses Riot Vanguard kernel-level anti-cheat. This script ONLY
    modifies user-accessible config files (game.cfg) and OS-level
    compatibility flags.

    LEAGUE OPTIMIZATION PHILOSOPHY:
    League is a MOBA where visual clarity and frame rate consistency matter
    more than raw graphical fidelity. 100% of pro players disable shadows
    and use low quality settings. Higher FPS reduces input latency for
    ability combos and last-hitting.

    CONFIG FORMAT:
    League uses standard Windows INI format (game.cfg) with sections:
    - [General] -- display mode, resolution, visual toggles, mouse settings
    - [Performance] -- graphics quality, shadows, FPS cap, AA, particle budgets
    - [HUD] -- interface scaling, minimap, health bars (mostly preserved)
    - Other sections: [Sound], [Volume], [Voice], [Chat], [FloatingText],
      [LossOfControl], [Accessibility], [ColorPalette], [Highlights],
      [MapSkinOptions], [Replay], [ItemShop], [TFTHUD], [TFTChat],
      [TFT], [Mobile], [Ftux], [RecommendPage]

    IMPORTANT: game.cfg is rewritten on every game exit. We set it
    to read-only after writing to preserve optimized settings.

    PATH STRUCTURE:
    <LOL_INSTALL>\Game\Config\game.cfg

    SOURCES:
    - github.com/kevin7600/LOL-configs
    - github.com/fluzz142857/lol-config
    - gist.github.com/matootie/dcfef766dec2a4b74df9457d6933e599
    - github.com/WelFedTed/LoL-Config (FrameCapType mapping)

.NOTES
    VANGUARD NOTE: Do not modify game data files in Game\DATA\.
    This script only touches game.cfg (user settings INI) and Windows
    compatibility flags. Editing game.cfg is confirmed safe -- it contains
    the same settings available through the in-game options menu.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'LEAGUE OF LEGENDS - Optimization Script' `
               -Subtitle 'March 2026 | Riot Engine | Vanguard Anti-Cheat'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host "  FPS Cap           : Uncapped (FrameCapType=10)" -ForegroundColor White
Write-Host ""

# =============================================================================
# INI PARSER: Read-Merge-Write for standard INI files
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
    # Write UTF-8 without BOM
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
# SECTION 1: LOCATE LEAGUE OF LEGENDS INSTALLATION
# =============================================================================

$LolPath = $null

# Check env var from host app
if ($env:LOL_PATH -and (Test-Path $env:LOL_PATH)) {
    $LolPath = $env:LOL_PATH
}

if (-not $LolPath) {
    # Method 1: RiotClientInstalls.json (most reliable)
    $riotJsonPath = "C:\ProgramData\Riot Games\RiotClientInstalls.json"
    if (Test-Path $riotJsonPath) {
        try {
            $riotJson = Get-Content $riotJsonPath -Raw | ConvertFrom-Json
            if ($riotJson.associated_client) {
                foreach ($prop in $riotJson.associated_client.PSObject.Properties) {
                    if ($prop.Name -match 'league_of_legends' -or $prop.Name -match 'League of Legends') {
                        $candidate = $prop.Name -replace '/[^/]*$', ''
                        $candidate = $candidate -replace '/', '\'
                        if (Test-Path $candidate) {
                            $LolPath = $candidate
                            break
                        }
                    }
                }
            }
        } catch {
            Write-Host "[WARN] Could not parse RiotClientInstalls.json: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

if (-not $LolPath) {
    # Method 2: Registry (LoL direct)
    try {
        $regPath = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Riot Games\League of Legends' -ErrorAction SilentlyContinue
        if ($regPath -and $regPath.InstallPath -and (Test-Path $regPath.InstallPath)) {
            $LolPath = $regPath.InstallPath
        }
    } catch { }
}

if (-not $LolPath) {
    # Method 3: Uninstall registry
    try {
        $uninstReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\League of Legends' -ErrorAction SilentlyContinue
        if ($uninstReg -and $uninstReg.InstallLocation -and (Test-Path $uninstReg.InstallLocation)) {
            $LolPath = $uninstReg.InstallLocation
        }
    } catch { }
}

if (-not $LolPath) {
    # Method 4: Common install paths
    $commonPaths = @(
        "C:\Riot Games\League of Legends",
        "D:\Riot Games\League of Legends",
        "C:\Program Files\Riot Games\League of Legends",
        "C:\Program Files (x86)\Riot Games\League of Legends",
        "E:\Riot Games\League of Legends"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $LolPath = $p
            break
        }
    }
}

# =============================================================================
# SECTION 2: EXE COMPATIBILITY FLAGS
# =============================================================================

$LolExePaths = @()

if ($LolPath) {
    # Main game executable is at <Install>\Game\League of Legends.exe
    $gameExe = Join-Path $LolPath "Game\League of Legends.exe"
    if (Test-Path $gameExe) {
        $LolExePaths += $gameExe
    }
}

# Add common fallback paths
$LolExePaths += @(
    "C:\Riot Games\League of Legends\Game\League of Legends.exe",
    "D:\Riot Games\League of Legends\Game\League of Legends.exe"
)

$null = Set-ExeCompatFlags -ExePaths $LolExePaths -CheckKey 'LOL_EXE_FLAGS' -Flags @('HIGHDPIAWARE', 'DISABLEFULLSCREENOPTIMIZATIONS')

# =============================================================================
# SECTION 3: WRITE OPTIMIZED game.cfg
# =============================================================================

$ConfigPath = $null

if ($LolPath) {
    $ConfigPath = Join-Path $LolPath "Game\Config\game.cfg"
}

# Fallback: try common paths directly
if (-not $ConfigPath -or -not (Test-Path (Split-Path $ConfigPath -Parent))) {
    $configCandidates = @(
        "C:\Riot Games\League of Legends\Game\Config\game.cfg",
        "D:\Riot Games\League of Legends\Game\Config\game.cfg"
    )
    foreach ($c in $configCandidates) {
        $dir = Split-Path $c -Parent
        if (Test-Path $dir) {
            $ConfigPath = $c
            break
        }
    }
}

if (-not $ConfigPath -or -not (Test-Path (Split-Path $ConfigPath -Parent))) {
    Write-Host "[INFO] No League of Legends config folder found. LoL may not be installed." -ForegroundColor DarkCyan
    Write-Check -Status 'WARN' -Key 'LOL_CONFIG_WRITTEN' -Detail 'NO_CONFIG_FOLDER'
} else {
    try {
        # READ existing config if present
        if (Test-Path $ConfigPath) {
            # Remove read-only if set from a previous run
            Unlock-ConfigFile -Path $ConfigPath
            Backup-ConfigFile -Path $ConfigPath | Out-Null

            $iniData = Read-IniFile -Path $ConfigPath
        } else {
            Write-Host "[INFO] No existing game.cfg -- creating fresh" -ForegroundColor DarkCyan
            $iniData = [ordered]@{}
        }

        # --- Competitive settings to merge ---

        # [General] section -- performance-related keys only
        # We preserve: Width, Height, Colors, CfgVersion, UserSetResolution,
        # GameMouseSpeed, SystemMouseSpeed, CursorScale, CursorOverride,
        # EnableAudio, AutoAcquireTarget, gameplay preferences, etc.
        $GeneralOverrides = @{
            'WindowMode'                 = '0'
            'WaitForVerticalSync'        = '0'
            'EnableScreenShake'          = '0'
            'HideEyeCandy'              = '1'
            'ShowGodray'                 = '0'
            'EnableLightFx'              = '0'
            'EnableSoftParticleSupport'  = '0'
            'Antialiasing'               = '0'
            'PreferDX9LegacyMode'        = '0'
            'PreferOpenGLLegacyMode'     = '0'
        }

        # [Performance] section -- core graphics quality
        # GraphicsSlider=-1 (Custom) prevents the preset from overriding
        # individual settings. FrameCapType=10 = Uncapped.
        $PerformanceOverrides = @{
            'GraphicsSlider'               = '-1'
            'ShadowsEnabled'               = '0'
            'ShadowQuality'                = '0'
            'CharacterQuality'             = '1'
            'EnvironmentQuality'           = '1'
            'EffectsQuality'               = '1'
            'CharacterInking'              = '0'
            'EnableGrassSwaying'           = '0'
            'EnableFXAA'                   = '0'
            'EnableHUDAnimations'          = '0'
            'EnableParticleOptimizations'  = '1'
            'AutoPerformanceSettings'      = '0'
            'GammaEnabled'                 = '0'
            'FrameCapType'                 = '10'
            'BudgetOverdrawAverage'        = '10'
            'BudgetSkinnedVertexCount'     = '40000'
            'BudgetSkinnedDrawCallCount'   = '50'
            'BudgetTextureUsage'           = '20000'
            'BudgetVertexCount'            = '100000'
            'BudgetTriangleCount'          = '100000'
            'BudgetDrawCallCount'          = '500'
        }

        # [HUD] section -- only performance-related keys
        $HudOverrides = @{
            'FlashScreenWhenDamaged'  = '0'
            'ShowHealthBarShake'      = '0'
        }

        # MERGE competitive settings (preserves all other keys/sections)
        Merge-IniSection -Existing $iniData -SectionName 'General' -Overrides $GeneralOverrides
        Merge-IniSection -Existing $iniData -SectionName 'Performance' -Overrides $PerformanceOverrides
        Merge-IniSection -Existing $iniData -SectionName 'HUD' -Overrides $HudOverrides

        # WRITE with UTF-8 no BOM
        Write-IniFile -Path $ConfigPath -Sections $iniData

        # LOCK read-only to prevent LoL from overwriting on exit
        Lock-ConfigFile -Path $ConfigPath

        # Verify the write
        $verifyContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($verifyContent -match 'ShadowsEnabled=0' -and $verifyContent -match 'FrameCapType=10') {
            Write-Host "  [OK] Config written to: $ConfigPath" -ForegroundColor Green
            Write-Check -Status 'OK' -Key 'LOL_CONFIG_WRITTEN'
        } else {
            Write-Host "  [WARN] Config write verification failed: $ConfigPath" -ForegroundColor Yellow
            Write-Check -Status 'FAIL' -Key 'LOL_CONFIG_WRITTEN' -Detail 'VERIFICATION_FAILED'
        }
    } catch {
        Write-Host "  [FAIL] Could not write config: $($_.Exception.Message)" -ForegroundColor Red
        Write-Check -Status 'FAIL' -Key 'LOL_CONFIG_WRITTEN' -Detail $_.Exception.Message
    }
}

# =============================================================================
# SECTION 4: PRINT FULL IN-GAME SETTINGS GUIDE
# =============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  LEAGUE OF LEGENDS - SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS (Applied via game.cfg) ---" -ForegroundColor Cyan
Write-Host "  Window Mode            : Fullscreen (exclusive GPU access)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF" -ForegroundColor White
Write-Host "  Frame Rate Cap         : Uncapped (higher FPS = lower input lag)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : OFF" -ForegroundColor White
Write-Host "  Hide Eye Candy         : ON (removes ambient critter effects)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (Applied via game.cfg) ---" -ForegroundColor Cyan
Write-Host "  Character Quality      : Low" -ForegroundColor White
Write-Host "  Environment Quality    : Low" -ForegroundColor White
Write-Host "  Effects Quality        : Low" -ForegroundColor White
Write-Host "  Shadows                : OFF (biggest FPS gain -- 100% of pros disable)" -ForegroundColor White
Write-Host "  Character Inking       : OFF" -ForegroundColor White
Write-Host "  Grass Swaying          : OFF" -ForegroundColor White
Write-Host "  FXAA                   : OFF" -ForegroundColor White
Write-Host "  HUD Animations         : OFF" -ForegroundColor White

Write-Host ""
Write-Host "  --- SETTINGS TO SET IN-GAME ---" -ForegroundColor Cyan
Write-Host "  Colorblind Mode        : Consider enabling (better ability visibility)" -ForegroundColor White
Write-Host "  Show FPS and Latency   : ON (monitor performance)" -ForegroundColor White
Write-Host "  Camera Move Speed      : Personal preference (default 32-50)" -ForegroundColor White
Write-Host "  Quick Cast             : Enable per-ability via keybindings" -ForegroundColor White
Write-Host "  Attack Move Click      : Recommended for kiting" -ForegroundColor White

Write-Host ""
Write-Host "  --- CLIENT SETTINGS (Riot Client) ---" -ForegroundColor Cyan
Write-Host "  Low Spec Mode          : Enable in Riot Client settings (reduces lobby UI)" -ForegroundColor White
Write-Host "  Close Client During Game: Enable (frees RAM)" -ForegroundColor White

Write-Host ""
Write-Host "  --- PRO PLAYER REFERENCE ---" -ForegroundColor Cyan
Write-Host "  Based on Faker, Showmaker, Chovy, Zeus, Oner, Rekkles:" -ForegroundColor White
Write-Host "  - 100% disable shadows" -ForegroundColor White
Write-Host "  - 100% V-Sync OFF" -ForegroundColor White
Write-Host "  - 100% Anti-Aliasing OFF" -ForegroundColor White
Write-Host "  - ~80% use Low quality for character/environment/effects" -ForegroundColor White
Write-Host "  - ~60% use Fullscreen (not Borderless)" -ForegroundColor White
Write-Host "  - Most use 1920x1080 even with higher-res monitors" -ForegroundColor White

Write-Host ""
Write-Host "  --- READ-ONLY PROTECTION ---" -ForegroundColor Cyan
Write-Host "  game.cfg is now READ-ONLY to prevent LoL from overwriting." -ForegroundColor White
Write-Host "  To change settings in-game, right-click game.cfg and" -ForegroundColor White
Write-Host "  uncheck 'Read-only', or run this optimizer again." -ForegroundColor White

Write-Host ""
if ($script:ValidationFailed) {
    Write-Host "[FAIL] League of Legends optimization completed with validation failures." -ForegroundColor Red
    exit 1
}

Write-Host "[DONE] League of Legends config written. Apply remaining settings in-game." -ForegroundColor Green
Write-Host ""
