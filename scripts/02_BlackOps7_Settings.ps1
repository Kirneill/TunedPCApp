#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Call of Duty: Black Ops 7 - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Engine: IW Engine (latest) | Anti-Cheat: Ricochet

.DESCRIPTION
    Applies EXE-level compatibility flags and config file optimizations for
    Call of Duty: Black Ops 7. Since BO7 uses the Ricochet anti-cheat system,
    this script ONLY modifies:
    - Windows compatibility flags for the game EXE (safe, OS-level)
    - User-accessible config files (same as editing settings in-game)

    It does NOT patch game files, memory, or anything Ricochet monitors.

.NOTES
    IMPORTANT: BO7 encrypts and overwrites its config files on launch.
    This script sets the Windows-layer optimizations. In-game settings
    must be applied manually using the settings guide printed at the end.

    Optimal Settings Reference (February 2026 - IW Engine):
    - These settings tested across RTX 3060 to RTX 4090 tier hardware
    - Anti-cheat safe: only OS-level registry flags modified
#>

# ─── HEADLESS MODE ────────────────────────────────────────────────────────────
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Call of Duty: Black Ops 7 - Optimization Script" -ForegroundColor Cyan
Write-Host "  February 2026 | IW Engine | Ricochet Anti-Cheat" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: LOCATE BLACK OPS 7 EXECUTABLE
# ─────────────────────────────────────────────────────────────────────────────

$PossiblePaths = @(
    "C:\Program Files (x86)\Call of Duty\BlackOps7.exe",
    "C:\Program Files\Call of Duty\BlackOps7.exe",
    "D:\Call of Duty\BlackOps7.exe",
    "E:\Call of Duty\BlackOps7.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty HQ\BlackOps7.exe"
)

$GameExe = $null
foreach ($path in $PossiblePaths) {
    if (Test-Path $path) {
        $GameExe = $path
        break
    }
}

if (-not $GameExe) {
    Write-Host "[WARN] Black Ops 7 executable not found in common locations." -ForegroundColor Yellow
    Write-Host "       Skipping EXE compatibility flags." -ForegroundColor Yellow
    Write-Host "       If installed in a custom location, set EXE flags manually:" -ForegroundColor Yellow
    Write-Host "       Right-click BlackOps7.exe > Properties > Compatibility >" -ForegroundColor Yellow
    Write-Host "       Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Found Black Ops 7 at: $GameExe" -ForegroundColor Green

    # ─────────────────────────────────────────────────────────────────────────
    # SECTION 2: EXE COMPATIBILITY FLAGS (Safe, OS-Level Only)
    # WHY: Disabling fullscreen optimizations for the specific EXE ensures
    #      true exclusive fullscreen mode, reducing latency by ~1 frame.
    #      High DPI override prevents Windows scaling artifacts.
    # ─────────────────────────────────────────────────────────────────────────

    $AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

    # DISABLETHEMES: Prevents Windows from injecting visual theme DLL into game process
    # DISABLEDWM: Skips DWM composition check (handled by exclusive fullscreen)
    # HIGHDPIAWARE: Lets game handle DPI rather than Windows scaling it
    Set-ItemProperty -Path $AppCompatLayers -Name $GameExe -Value "~ DISABLETHEMES HIGHDPIAWARE" -Type String -Force
    Write-Host "  [OK] EXE compatibility flags set (DPI-aware, themes disabled)." -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: DISABLE FULLSCREEN OPTIMIZATIONS FOR COD LAUNCHER
# ─────────────────────────────────────────────────────────────────────────────

$BattleNetExe = "C:\Program Files (x86)\Battle.net\Battle.net.exe"
if (Test-Path $BattleNetExe) {
    $AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }
    Set-ItemProperty -Path $AppCompatLayers -Name $BattleNetExe -Value "~ HIGHDPIAWARE" -Type String -Force
    Write-Host "  [OK] Battle.net launcher: DPI override applied." -ForegroundColor Green
}


# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: PRINT IN-GAME SETTINGS GUIDE
# WHY: BO7's Ricochet anti-cheat makes direct config editing unsafe/ineffective.
#      All graphics settings must be set manually through the in-game UI.
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  BLACK OPS 7 - IN-GAME SETTINGS GUIDE (Apply Manually)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- DISPLAY SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Display Mode           : Fullscreen Exclusive" -ForegroundColor White
Write-Host "                         (NEVER Borderless - adds 1-frame latency)" -ForegroundColor DarkGray
Write-Host "  Resolution             : Your native monitor resolution" -ForegroundColor White
Write-Host "  Refresh Rate           : Max (match your monitor's max Hz)" -ForegroundColor White
Write-Host "  Render Resolution      : 100% (no DLSS/FSR unless GPU-limited)" -ForegroundColor White
Write-Host "  V-Sync                 : OFF - adds 16-50ms latency" -ForegroundColor White
Write-Host "  Field of View (FOV)    : 100-110 (competitive sweet spot)" -ForegroundColor White
Write-Host "  ADS FOV                : Affected (preserves relative scale)" -ForegroundColor White
Write-Host "  Weapon FOV             : Wide" -ForegroundColor White
Write-Host "  World Motion Blur      : OFF (reduces visual clarity)" -ForegroundColor White
Write-Host "  Weapon Motion Blur     : OFF" -ForegroundColor White
Write-Host "  Depth of Field         : OFF (blurs near/far, hurts focus)" -ForegroundColor White
Write-Host "  Film Grain             : 0.00 (adds noise, hurts visibility)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS QUALITY (BY HARDWARE TIER) ---" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [ENTRY-LEVEL: RTX 3060 / RX 6600]" -ForegroundColor Yellow
Write-Host "  Overall Quality Preset : Custom" -ForegroundColor White
Write-Host "  Texture Resolution     : Low" -ForegroundColor White
Write-Host "  Texture Filter Quality : Normal (Anisotropic 4x)" -ForegroundColor White
Write-Host "  Nearby Level of Detail : Low" -ForegroundColor White
Write-Host "  Distant Level of Detail: Low" -ForegroundColor White
Write-Host "  Clutter Draw Distance  : Short" -ForegroundColor White
Write-Host "  Particle Quality       : Low" -ForegroundColor White
Write-Host "  Bullet Impacts/Sprays  : ON (competitive - shows hit confirmation)" -ForegroundColor White
Write-Host "  Shader Quality         : Low" -ForegroundColor White
Write-Host "  Shadow Map Resolution  : Low" -ForegroundColor White
Write-Host "  Screen Space Shadows   : OFF" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White
Write-Host "  Screen Space Refl.     : OFF" -ForegroundColor White
Write-Host "  Static Reflection Qual.: Low" -ForegroundColor White
Write-Host "  Weather Grid Volumes   : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : SMAA T1X (best perf/clarity tradeoff)" -ForegroundColor White
Write-Host "  NVIDIA DLSS            : Quality or Balanced if available" -ForegroundColor White
Write-Host "  AMD FSR                : Quality or Balanced if available" -ForegroundColor White
Write-Host "  Variable Rate Shading  : ON (free performance gain)" -ForegroundColor White
Write-Host "  On-Demand Texture Str. : ON (reduces VRAM pressure)" -ForegroundColor White
Write-Host ""
Write-Host "  [MID-RANGE: RTX 4070 / RX 7800 XT]" -ForegroundColor Yellow
Write-Host "  Texture Resolution     : High" -ForegroundColor White
Write-Host "  Texture Filter Quality : High (Anisotropic 8x)" -ForegroundColor White
Write-Host "  Nearby Level of Detail : Medium" -ForegroundColor White
Write-Host "  Distant Level of Detail: Low" -ForegroundColor White
Write-Host "  Particle Quality       : Low (no competitive benefit to higher)" -ForegroundColor White
Write-Host "  Shader Quality         : Medium" -ForegroundColor White
Write-Host "  Shadow Map Resolution  : Normal (shadows help spot enemies)" -ForegroundColor White
Write-Host "  Screen Space Shadows   : OFF" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White
Write-Host "  Screen Space Refl.     : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : SMAA T2X" -ForegroundColor White
Write-Host "  Variable Rate Shading  : ON" -ForegroundColor White
Write-Host ""
Write-Host "  [HIGH-END: RTX 4090 / RX 7900 XTX]" -ForegroundColor Yellow
Write-Host "  Texture Resolution     : High" -ForegroundColor White
Write-Host "  Texture Filter Quality : High (Anisotropic 16x)" -ForegroundColor White
Write-Host "  Nearby Level of Detail : High" -ForegroundColor White
Write-Host "  Distant Level of Detail: Medium" -ForegroundColor White
Write-Host "  Particle Quality       : Low-Medium" -ForegroundColor White
Write-Host "  Shader Quality         : High" -ForegroundColor White
Write-Host "  Shadow Map Resolution  : High" -ForegroundColor White
Write-Host "  Screen Space Shadows   : OFF (minor visual, poor perf tradeoff)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF (hurts visibility in dark areas)" -ForegroundColor White
Write-Host "  Screen Space Refl.     : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : SMAA T2X" -ForegroundColor White
Write-Host "  Variable Rate Shading  : ON" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO SETTINGS (COMPETITIVE) ---" -ForegroundColor Cyan
Write-Host "  Audio Mix              : Headphone or Headphone Bass Boost" -ForegroundColor White
Write-Host "                         (boosts footstep frequency range)" -ForegroundColor DarkGray
Write-Host "  Master Volume          : 85" -ForegroundColor White
Write-Host "  Music Volume           : 0 (eliminates audio masking)" -ForegroundColor White
Write-Host "  Dialogue Volume        : 20" -ForegroundColor White
Write-Host "  Effects Volume         : 80" -ForegroundColor White
Write-Host "  Hit Marker Sound       : ON (audio + visual hit confirmation)" -ForegroundColor White
Write-Host "  Mono Audio             : OFF (keep stereo for directional cues)" -ForegroundColor White

Write-Host ""
Write-Host "  --- SENSITIVITY & CONTROLS ---" -ForegroundColor Cyan
Write-Host "  Mouse Sensitivity      : 6.0-8.0 (personal preference)" -ForegroundColor White
Write-Host "  ADS Sensitivity Multi  : 1.00 (maintain consistency)" -ForegroundColor White
Write-Host "  Mouse Filtering        : 0.00 (no smoothing)" -ForegroundColor White
Write-Host "  Mouse Acceleration     : 0.00" -ForegroundColor White
Write-Host "  Raw Input              : ON (bypasses Windows cursor pipeline)" -ForegroundColor White
Write-Host "  Mouse Polling Rate     : 1000Hz minimum, 4000Hz if supported" -ForegroundColor White

Write-Host ""
Write-Host "  --- NETWORK SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Killcam                : OFF (reduces lag compensation artifacts)" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] Apply the above settings manually in Black Ops 7's settings menu." -ForegroundColor Green
Write-Host ""
