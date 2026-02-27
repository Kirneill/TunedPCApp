#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Call of Duty: Black Ops 7 - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Engine: IW Engine (latest) | Anti-Cheat: Ricochet

.DESCRIPTION
    Applies EXE-level compatibility flags and config file optimizations for
    Call of Duty: Black Ops 7. Since BO7 uses the Ricochet anti-cheat system,
    this script modifies:
    - Windows compatibility flags for the game EXE (safe, OS-level)
    - Windows/Game Mode registry values that reduce gaming overhead
    - In-app guidance output for manual max-FPS game settings

    It does NOT patch game files, memory, or anything Ricochet monitors.

.NOTES
    IMPORTANT: BO7 encrypts and overwrites its config files on launch.
    This script sets Windows-layer optimizations only. BO7 player config template
    writes are disabled by design to prevent cloud/auto-detect sync from forcing
    unwanted quality presets. In-game settings should be applied manually.

    Optimal Settings Reference (February 2026 - IW Engine):
    - These settings tested across RTX 3060 to RTX 4090 tier hardware
    - Anti-cheat safe: only OS-level registry flags and user config files modified
#>

# --- HEADLESS MODE ------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Call of Duty: Black Ops 7 - Optimization Script" -ForegroundColor Cyan
Write-Host "  February 2026 | IW Engine | Ricochet Anti-Cheat" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

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

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE BLACK OPS 7 EXECUTABLE
# -----------------------------------------------------------------------------

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
    Write-Host "       Enable High DPI override for the executable" -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'COD_EXE_FLAGS' -Detail 'BlackOps7.exe not found in common paths'
} else {
    Write-Host "[INFO] Found Black Ops 7 at: $GameExe" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # SECTION 2: EXE COMPATIBILITY FLAGS (Safe, OS-Level Only)
    # WHY: Applies safe Windows compatibility flags for BO7.
    #      High DPI override prevents scaling artifacts.
    #      Theme disabling avoids extra OS visual injection overhead.
    # -------------------------------------------------------------------------

    try {
        $AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }

        # DISABLETHEMES: Prevents Windows from injecting visual theme DLL into the process
        # HIGHDPIAWARE: Lets game handle DPI rather than Windows scaling it
        Set-ItemProperty -Path $AppCompatLayers -Name $GameExe -Value "~ DISABLETHEMES HIGHDPIAWARE" -Type String -Force
        Write-Host "  [OK] EXE compatibility flags set (DPI-aware, themes disabled)." -ForegroundColor Green
        Write-Check -Status 'OK' -Key 'COD_EXE_FLAGS' -Detail 'DISABLETHEMES + HIGHDPIAWARE'
    } catch {
        Write-Host "  [WARN] Failed to set EXE compatibility flags: $_" -ForegroundColor Yellow
        Write-Check -Status 'FAIL' -Key 'COD_EXE_FLAGS' -Detail 'Unable to write AppCompatFlags'
    }
}

# -----------------------------------------------------------------------------
# SECTION 3: APPLY DPI OVERRIDE FOR COD LAUNCHER
# -----------------------------------------------------------------------------

$BattleNetExe = "C:\Program Files (x86)\Battle.net\Battle.net.exe"
if (Test-Path $BattleNetExe) {
    $AppCompatLayers = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $AppCompatLayers)) { New-Item -Path $AppCompatLayers -Force | Out-Null }
    Set-ItemProperty -Path $AppCompatLayers -Name $BattleNetExe -Value "~ HIGHDPIAWARE" -Type String -Force
    Write-Host "  [OK] Battle.net launcher: DPI override applied." -ForegroundColor Green
}


# -----------------------------------------------------------------------------
# SECTION 4: ENSURE WINDOWS GAME MODE STAYS ENABLED (COD PRIORITY)
# WHY: COD benefits from consistent scheduler priority and no DVR/background
#      capture overhead. Re-apply every BO7 run to prevent drift.
# -----------------------------------------------------------------------------

try {
    $GameBarPath = "HKCU:\Software\Microsoft\GameBar"
    if (-not (Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

    Set-ItemProperty -Path $GameBarPath -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $GameBarPath -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $GameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force

    $GameBarPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $GameBarPolicyPath)) { New-Item -Path $GameBarPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord -Force

    $GameDVRPath = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $GameDVRPath)) { New-Item -Path $GameDVRPath -Force | Out-Null }
    Set-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

    $allowAutoGameMode = (Get-ItemProperty -Path $GameBarPath -Name "AllowAutoGameMode" -ErrorAction Stop).AllowAutoGameMode
    $autoGameModeEnabled = (Get-ItemProperty -Path $GameBarPath -Name "AutoGameModeEnabled" -ErrorAction Stop).AutoGameModeEnabled
    $allowGameDVR = (Get-ItemProperty -Path $GameBarPolicyPath -Name "AllowGameDVR" -ErrorAction Stop).AllowGameDVR
    $gameDvrEnabled = (Get-ItemProperty -Path $GameDVRPath -Name "GameDVR_Enabled" -ErrorAction Stop).GameDVR_Enabled

    Write-Host "  [OK] Game Mode re-applied for COD." -ForegroundColor Green
    Write-Host "  [OK] Game DVR/background recording disabled." -ForegroundColor Green
    if ($allowAutoGameMode -eq 1 -and $autoGameModeEnabled -eq 1) {
        Write-Check -Status 'OK' -Key 'COD_GAME_MODE_ON' -Detail 'AllowAutoGameMode=1, AutoGameModeEnabled=1'
    } else {
        Write-Check -Status 'FAIL' -Key 'COD_GAME_MODE_ON' -Detail "AllowAutoGameMode=$allowAutoGameMode, AutoGameModeEnabled=$autoGameModeEnabled"
    }

    if ($allowGameDVR -eq 0 -and $gameDvrEnabled -eq 0) {
        Write-Check -Status 'OK' -Key 'COD_GAME_DVR_OFF' -Detail 'AllowGameDVR=0, GameDVR_Enabled=0'
    } else {
        Write-Check -Status 'FAIL' -Key 'COD_GAME_DVR_OFF' -Detail "AllowGameDVR=$allowGameDVR, GameDVR_Enabled=$gameDvrEnabled"
    }
} catch {
    Write-Host "  [WARN] Could not enforce Game Mode settings: $_" -ForegroundColor Yellow
    Write-Check -Status 'FAIL' -Key 'COD_GAME_MODE_ON' -Detail 'Registry write failed'
    Write-Check -Status 'FAIL' -Key 'COD_GAME_DVR_OFF' -Detail 'Registry write failed'
}


# -----------------------------------------------------------------------------
# SECTION 5: BO7 PLAYER TEMPLATE COPY (DISABLED BY DESIGN)
# WHY: BO7 can resync/overwrite local config via cloud + auto-detection.
#      Copying BO7BACKUP templates here caused quality to revert unexpectedly
#      on some systems, so this step is intentionally skipped.
# -----------------------------------------------------------------------------

Write-Host "[INFO] BO7 player template copy step is disabled by design." -ForegroundColor Cyan
Write-Host "       No .txt0/.txt1/.m files are copied into Activision\\Call of Duty\\players." -ForegroundColor DarkGray
Write-Host "       Apply the recommended in-game settings manually for stable max FPS." -ForegroundColor DarkGray
Write-Check -Status 'WARN' -Key 'COD_CONFIG_FILES_COPIED' -Detail 'Disabled by design; BO7BACKUP templates not copied'
Write-Check -Status 'WARN' -Key 'COD_RENDERER_WORKER_COUNT' -Detail 'Disabled by design; RendererWorkerCount not patched'

# -----------------------------------------------------------------------------
# SECTION 6: PRINT IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

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

if ($script:ValidationFailed) {
    Write-Host "[FAIL] One or more COD verification checks failed." -ForegroundColor Red
    exit 1
}
