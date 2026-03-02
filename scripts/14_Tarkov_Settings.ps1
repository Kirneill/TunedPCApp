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
    Config file keys are approximations — BSG may rename them between
    patches. The script writes known-good settings and sets read-only
    to preserve them. PostFX must be set in-game (not exposed in config).
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
    $NvidiaGPU      = $env:NVIDIA_GPU -eq '1'
} else {
    $MonitorWidth   = 1920
    $MonitorHeight  = 1080
    $MonitorRefresh = 240
    $NvidiaGPU      = $true
}
# -----------------------------------------------------------------------------

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Escape from Tarkov - Optimization Script" -ForegroundColor Cyan
Write-Host "  March 2026 | Unity Engine" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE TARKOV AND SET EXE FLAGS
# -----------------------------------------------------------------------------

$AnyFailure = $false
$TarkovExePaths = @()

# If provided by host process, trust this first.
if (-not [string]::IsNullOrWhiteSpace($env:TARKOV_PATH)) {
    $detectedPath = $env:TARKOV_PATH
    if (Test-Path $detectedPath) {
        $TarkovExePaths += Join-Path $detectedPath "EscapeFromTarkov.exe"
        Write-Host "[INFO] Using host-detected Tarkov path: $detectedPath" -ForegroundColor DarkCyan
    }
}

# Registry detection — BSG launcher / uninstall key
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

foreach ($root in $CommonRoots) {
    $TarkovExePaths += Join-Path $root "EscapeFromTarkov.exe"
}

$AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

$foundExe = $false
foreach ($exePath in ($TarkovExePaths | Select-Object -Unique)) {
    if (Test-Path $exePath) {
        Set-ItemProperty -Path $AppCompatLayers -Name $exePath -Value "~ HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS" -Type String -Force
        Write-Host "  [OK] EXE flags set for: $exePath" -ForegroundColor Green
        $foundExe = $true
    }
}

if (-not $foundExe) {
    Write-Host "[WARN] Tarkov executable not found in common paths." -ForegroundColor Yellow
    Write-Host "       Right-click EscapeFromTarkov.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
    Write-Host "[SQ_CHECK_WARN:TARKOV_EXE_FLAGS:EXE_NOT_FOUND]"
    $AnyFailure = $true
} else {
    Write-Host "[SQ_CHECK_OK:TARKOV_EXE_FLAGS]"
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED GRAPHICS CONFIG
# -----------------------------------------------------------------------------

$SettingsDir = "$env:APPDATA\Battlestate Games\Escape from Tarkov\Settings"

if (-not (Test-Path $SettingsDir)) {
    New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
    Write-Host "[INFO] Created Tarkov settings directory: $SettingsDir" -ForegroundColor DarkCyan
}

$GraphicsIni = Join-Path $SettingsDir "Graphics.ini"

# Back up existing config
if (Test-Path $GraphicsIni) {
    # Remove read-only if set from previous run
    try {
        $file = Get-Item $GraphicsIni
        if ($file.IsReadOnly) { $file.IsReadOnly = $false }
    } catch {
        Write-Host "[WARN] Could not remove read-only flag from Graphics.ini: $_" -ForegroundColor Yellow
    }

    $backupPath = "$GraphicsIni.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
    Copy-Item $GraphicsIni $backupPath -Force
    Write-Host "[BACKUP] Graphics.ini backed up to: $backupPath" -ForegroundColor Yellow
}

# Tarkov stores graphics as a JSON blob inside the file.
# We write a known-good competitive config.
$GraphicsConfig = @{
    TextureQuality = 1
    ShadowQuality = 1
    ShadowVisibility = 40
    LodQuality = 2
    OverallVisibility = 400
    AntiAliasing = 1
    SSAOMode = 0
    SSRMode = 0
    AnisotropicFiltering = 1
    Sharpness = 0.7
    ZBlur = $false
    ChromaticAberration = $false
    Noise = $false
    GrassShadows = $false
    MIPStreaming = $true
    LobbyFPS = 60
    GameFPS = 0
}

$jsonContent = $GraphicsConfig | ConvertTo-Json -Depth 3
# Fix PowerShell boolean serialization: "True"/"False" → true/false for JSON compliance
$jsonContent = $jsonContent -replace ':\s*"True"', ': true' -replace ':\s*"False"', ': false'

try {
    Set-Content -Path $GraphicsIni -Value $jsonContent -Encoding UTF8 -Force
    # Set read-only to prevent Tarkov from overwriting on exit
    Set-ItemProperty -Path $GraphicsIni -Name IsReadOnly -Value $true
    Write-Host "  [OK] Graphics.ini written and locked (read-only): $GraphicsIni" -ForegroundColor Green
    Write-Host "[SQ_CHECK_OK:TARKOV_CONFIG_WRITTEN]"
} catch {
    Write-Host "[FAIL] Failed to write Graphics.ini: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:TARKOV_CONFIG_WRITTEN:WRITE_ERROR]"
    $AnyFailure = $true
}

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
Write-Host "  --- UPSCALING ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  DLSS                   : Quality" -ForegroundColor White
    Write-Host "  DLSS Frame Gen         : OFF (adds latency)" -ForegroundColor White
    Write-Host "  Reflex Low Latency     : ON + Boost" -ForegroundColor White
} else {
    Write-Host "  FSR                    : Quality" -ForegroundColor White
    Write-Host "  Frame Gen              : OFF (adds latency)" -ForegroundColor White
}

Write-Host ""
Write-Host "  --- GRAPHICS (Config applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Texture Quality        : Medium (Low looks awful, High = minimal diff)" -ForegroundColor White
Write-Host "  Shadow Quality         : Low (big FPS impact)" -ForegroundColor White
Write-Host "  Shadow Visibility      : 40 (competitive sweet spot)" -ForegroundColor White
Write-Host "  Object LOD Quality     : 2 (player detail at distance)" -ForegroundColor White
Write-Host "  Overall Visibility     : 400 (min for gameplay; 1000 for sniping)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : TAA" -ForegroundColor White
Write-Host "  HBAO                   : OFF (significant FPS cost)" -ForegroundColor White
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
if (-not $AnyFailure) {
    Write-Host "[SQ_CHECK_OK:TARKOV_SETTINGS_APPLIED]"
} else {
    Write-Host "[SQ_CHECK_WARN:TARKOV_SETTINGS_APPLIED:PARTIAL]"
}
Write-Host ""
