#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Escape from Tarkov - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Unity

.DESCRIPTION
    Applies Windows EXE flags and writes optimized Graphics.ini for
    competitive Tarkov performance. Config is set to read-only after
    writing to prevent Tarkov from overwriting on exit.

    BattlEye is Tarkov's anti-cheat. Config file edits are safe.

.NOTES
    Graphics.ini is JSON (despite .ini extension) with a required structural
    envelope (Version, Stored[], DisplaySettings{}). The script uses a
    read-merge-write approach to preserve the user's resolution settings
    while overriding only performance keys. Config key names verified against
    github.com/antheboets/tarkov-settings. PostFX must be set in-game.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Escape from Tarkov - Optimization Script' `
               -Subtitle 'March 2026 | Unity Engine'

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE TARKOV AND SET EXE FLAGS
# -----------------------------------------------------------------------------

$TarkovExePaths = @()

# If provided by host process, trust this first.
if (-not [string]::IsNullOrWhiteSpace($env:TARKOV_PATH)) {
    $detectedPath = $env:TARKOV_PATH
    if (Test-Path $detectedPath) {
        $TarkovExePaths += Join-Path $detectedPath "EscapeFromTarkov.exe"
        Write-Host "[INFO] Using host-detected Tarkov path: $detectedPath" -ForegroundColor DarkCyan
    }
}

# Registry detection -- BSG launcher / uninstall key
$regPaths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov",
    "HKCU:\Software\Battlestate Games\"
)
foreach ($rp in $regPaths) {
    try {
        $prop = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
        if ($prop.InstallLocation -and (Test-Path $prop.InstallLocation)) {
            $TarkovExePaths += Join-Path $prop.InstallLocation "EscapeFromTarkov.exe"
        }
    } catch {
        Write-Host "[WARN] Failed to read registry at ${rp}: $_" -ForegroundColor DarkGray
    }
}

# Common install paths
$CommonRoots = @(
    "C:\Battlestate Games\EFT",
    "D:\Battlestate Games\EFT",
    "E:\Battlestate Games\EFT",
    "C:\Games\Battlestate Games\EFT",
    "D:\Games\Battlestate Games\EFT"
)

# Filter out paths on drives that do not exist (Join-Path throws in PS 5.1)
$CommonRoots = @($CommonRoots | Where-Object {
    if ($_ -match '^([A-Za-z]):') { Test-Path "$($Matches[1]):\" } else { $true }
})

foreach ($root in $CommonRoots) {
    $TarkovExePaths += Join-Path $root "EscapeFromTarkov.exe"
}

$foundCount = Set-ExeCompatFlags -ExePaths $TarkovExePaths -CheckKey 'TARKOV_EXE_FLAGS'

if ($foundCount -eq 0) {
    Write-Host "       Right-click EscapeFromTarkov.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED GRAPHICS CONFIG
# -----------------------------------------------------------------------------
# Tarkov's Graphics.ini is JSON (despite the .ini extension) parsed by Unity.
# It REQUIRES a structural envelope: Version, Stored[], DisplaySettings{}.
# Without these, the rendering pipeline cannot initialize → infinite loading.
#
# Strategy: read-merge-write. If an existing config exists we parse it and only
# override the performance keys, preserving the user's resolution and display
# settings. If no config exists we build a fresh envelope from monitor info.
# -----------------------------------------------------------------------------

$SettingsDir = "$env:APPDATA\Battlestate Games\Escape from Tarkov\Settings"

if (-not (Test-Path $SettingsDir)) {
    New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
    Write-Host "[INFO] Created Tarkov settings directory: $SettingsDir" -ForegroundColor DarkCyan
}

$GraphicsIni = Join-Path $SettingsDir "Graphics.ini"
$config = $null

# --- Read existing config to preserve resolution / display settings ----------
if (Test-Path $GraphicsIni) {
    Backup-ConfigFile -Path $GraphicsIni | Out-Null

    try {
        $raw = [System.IO.File]::ReadAllText($GraphicsIni, [System.Text.UTF8Encoding]::new($false))
        $config = $raw | ConvertFrom-Json -ErrorAction Stop

        # Validate the structural envelope Tarkov requires to initialize rendering
        $hasEnvelope = $config.PSObject.Properties['Version'] -and
                       $config.PSObject.Properties['Stored'] -and
                       $config.PSObject.Properties['DisplaySettings']
        if (-not $hasEnvelope) {
            Write-Host "[WARN] Graphics.ini missing required fields (Version/Stored/DisplaySettings) -- rebuilding" -ForegroundColor Yellow
            $config = $null
            $script:ValidationFailed = $true
        } else {
            Write-Host "[INFO] Parsed existing Graphics.ini -- preserving resolution settings" -ForegroundColor DarkCyan
        }
    } catch {
        Write-Host "[WARN] Existing Graphics.ini could not be parsed -- writing fresh config" -ForegroundColor Yellow
        $config = $null
        $script:ValidationFailed = $true
    }
}

# --- Helper: compute aspect ratio from resolution ---------------------------
function Get-AspectRatio([int]$w, [int]$h) {
    if ($w -le 0 -or $h -le 0) { return @{ X = 16; Y = 9 } }
    $a = $w; $b = $h
    while ($b -ne 0) { $t = $b; $b = $a % $b; $a = $t }
    return @{ X = [int]($w / $a); Y = [int]($h / $a) }
}

# --- Build structural envelope when no valid config exists -------------------
if (-not $config) {
    $aspect = Get-AspectRatio $MonitorWidth $MonitorHeight
    $config = [PSCustomObject]@{
        Version          = 5
        Stored           = @(
            [PSCustomObject]@{
                Index                 = 0
                FullScreenResolution  = [PSCustomObject]@{ Width = $MonitorWidth; Height = $MonitorHeight }
                FullScreenAspectRatio = [PSCustomObject]@{ X = $aspect.X; Y = $aspect.Y }
                WindowResolution      = [PSCustomObject]@{ Width = $MonitorWidth; Height = $MonitorHeight }
                WindowAspectRatio     = [PSCustomObject]@{ X = $aspect.X; Y = $aspect.Y }
            }
        )
        DisplaySettings  = [PSCustomObject]@{
            Display        = 0
            FullScreenMode = 0
            Resolution     = [PSCustomObject]@{ Width = $MonitorWidth; Height = $MonitorHeight }
            AspectRatio    = [PSCustomObject]@{ X = $aspect.X; Y = $aspect.Y }
        }
        GraphicsQuality  = $null
    }
    Write-Host "[INFO] Built fresh config for ${MonitorWidth}x${MonitorHeight}" -ForegroundColor DarkCyan
}

# PowerShell 5.1 may collapse single-element JSON arrays on parse
if ($config.Stored -and $config.Stored -isnot [array]) {
    $config.Stored = @($config.Stored)
}

# --- Competitive settings -- exact Tarkov key names and value types -----------
# Reference: github.com/antheboets/tarkov-settings, github.com/td4b/TarkovOptimization
$competitiveSettings = [ordered]@{
    ShadowsQuality       = [int]0           # Low
    TextureQuality       = [int]1           # Medium
    CloudsQuality        = "Low"
    VSync                = $false
    LobbyFramerate       = [int]60
    GameFramerate        = [int]0           # Unlimited
    SuperSampling        = "Off"
    AnisotropicFiltering = "Enable"
    OverallVisibility    = [double]400.0
    LodBias              = [double]2.0
    Ssao                 = "Off"
    Sharpen              = [double]0.7
    SSR                  = "Off"
    AntiAliasing         = "TAA_Low"
    GrassShadow          = $false
    ChromaticAberrations = $false
    Noise                = $false
    ZBlur                = $false
    HighQualityColor     = $true
    MipStreaming         = $true
    ShadowDistance       = [double]40.0
    SuperSamplingFactor  = [double]1.0
    DLSSMode             = "Off"
    FSR2Mode             = "Off"
    FSR3Mode             = "Off"
    DLSSEnabled          = $false
    FSR2Enabled          = $false
    FSR3Enabled          = $false
}

if ($NvidiaGPU) {
    $competitiveSettings["NVidiaReflex"] = "OnAndBoost"
}

# Merge into config -- preserves Version, Stored, DisplaySettings untouched
foreach ($key in $competitiveSettings.Keys) {
    if ($config.PSObject.Properties[$key]) {
        $config.$key = $competitiveSettings[$key]
    } else {
        $config | Add-Member -NotePropertyName $key -NotePropertyValue $competitiveSettings[$key] -Force
    }
}

# --- Write JSON without UTF-8 BOM -------------------------------------------
# PS 5.1's Set-Content -Encoding UTF8 prepends a BOM (EF BB BF) which breaks
# Unity JSON parsers. Use .NET WriteAllText with BOM-less encoding.
$json = $config | ConvertTo-Json -Depth 10

try {
    [System.IO.File]::WriteAllText($GraphicsIni, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  [OK] Graphics.ini written: $GraphicsIni" -ForegroundColor Green
    Write-Check -Status 'OK' -Key 'TARKOV_CONFIG_WRITTEN'
} catch {
    Write-Host "[FAIL] Failed to write Graphics.ini: $_" -ForegroundColor Red
    Write-Check -Status 'FAIL' -Key 'TARKOV_CONFIG_WRITTEN' -Detail 'WRITE_ERROR'
}

# Read-only lock (separate -- a failure here should not mask a successful write)
Lock-ConfigFile -Path $GraphicsIni

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  TARKOV - COMPLETE SETTINGS GUIDE (Apply In-Game)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- DISPLAY SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Screen Mode            : Fullscreen" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight} (native)" -ForegroundColor White
Write-Host "  Game FPS Limit         : 0 (Unlimited)" -ForegroundColor White
Write-Host "  Lobby FPS Limit        : 60 (saves GPU thermals)" -ForegroundColor White

Write-Host ""
Write-Host "  --- UPSCALING (set in-game if desired) ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  DLSS                   : OFF (set to Quality in-game for sharpness)" -ForegroundColor White
    Write-Host "  DLSS Frame Gen         : OFF (adds latency)" -ForegroundColor White
    Write-Host "  Reflex Low Latency     : ON + Boost" -ForegroundColor White
} else {
    Write-Host "  FSR                    : OFF (set to Quality in-game for sharpness)" -ForegroundColor White
    Write-Host "  Frame Gen              : OFF (adds latency)" -ForegroundColor White
}

Write-Host ""
Write-Host "  --- GRAPHICS (Config applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Texture Quality        : Medium (Low looks awful, High = minimal diff)" -ForegroundColor White
Write-Host "  Shadow Quality         : Low (big FPS impact)" -ForegroundColor White
Write-Host "  Shadow Visibility      : 40 (competitive sweet spot)" -ForegroundColor White
Write-Host "  Object LOD Quality     : 2 (player detail at distance)" -ForegroundColor White
Write-Host "  Overall Visibility     : 400 (min for gameplay; 1000 for sniping)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : TAA Low" -ForegroundColor White
Write-Host "  SSAO                   : OFF (significant FPS cost)" -ForegroundColor White
Write-Host "  SSR                    : OFF (major FPS hit, cosmetic only)" -ForegroundColor White
Write-Host "  Sharpness              : 0.7" -ForegroundColor White

Write-Host ""
Write-Host "  --- TOGGLES (Applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Z-Blur (Motion Blur)   : OFF" -ForegroundColor White
Write-Host "  Chromatic Aberration   : OFF" -ForegroundColor White
Write-Host "  Noise                  : OFF" -ForegroundColor White
Write-Host "  Grass Shadows          : OFF" -ForegroundColor White
Write-Host "  MIP Streaming          : ON (reduces VRAM stutter)" -ForegroundColor White

Write-Host ""
Write-Host "  --- STUTTER FIXES ---" -ForegroundColor Cyan
Write-Host "  RAM Cleaner            : OFF if 32GB+ RAM, ON if 16GB" -ForegroundColor White
Write-Host "  Only Use Physical Cores: OFF for modern CPUs (12th gen+/Ryzen 5000+)" -ForegroundColor White

Write-Host ""
Write-Host "  --- POSTFX (Must set in-game) ---" -ForegroundColor Cyan
Write-Host "  Clarity                : 50-80 (best single visibility boost)" -ForegroundColor Red
Write-Host "  Brightness             : 0 to +50 (map-dependent)" -ForegroundColor White
Write-Host "  Saturation             : 0 to +30" -ForegroundColor White
Write-Host "  Colorfulness           : 30-50" -ForegroundColor White
Write-Host "  Luma Sharpen           : 30-50" -ForegroundColor White
Write-Host "  Color Grading          : Cognac or Koda" -ForegroundColor White
Write-Host "  Intensity              : 30-50" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] Tarkov config written + EXE flags applied." -ForegroundColor Green
Write-Host "       Apply PostFX and remaining settings in-game." -ForegroundColor Green
if (-not $script:ValidationFailed) {
    Write-Check -Status 'OK' -Key 'TARKOV_SETTINGS_APPLIED'
} else {
    Write-Check -Status 'WARN' -Key 'TARKOV_SETTINGS_APPLIED' -Detail 'PARTIAL'
}
Write-Host ""
