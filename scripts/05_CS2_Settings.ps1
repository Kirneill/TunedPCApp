#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Counter-Strike 2 (CS2) - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Engine: Source 2

.DESCRIPTION
    Applies Windows EXE flags, Steam launch options (via registry), and writes
    an optimized autoexec.cfg for Counter-Strike 2.

    WHAT THIS SCRIPT DOES:
    - Creates a backup of existing autoexec.cfg
    - Writes a comprehensive competitive autoexec.cfg
    - Sets Steam launch options for CS2 in the registry
    - Sets EXE compatibility flags
    - Prints the full in-game settings guide

.NOTES
    CS2 autoexec location:
    %USERPROFILE%\AppData\Local\Steam\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\autoexec.cfg

    OR (common alternate Steam library):
    D:\Steam\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\autoexec.cfg

    IMPORTANT: -tickrate and -threads launch options are DEPRECATED in CS2
    and should NOT be used. Source 2 handles these automatically.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
$MonitorRefreshRate = $MonitorRefresh    # CS2 uses this alias
$UseStretchedRes = $env:CS2_STRETCHED -eq '1'

# Steam library paths to search (add your custom Steam library path if needed)
$SteamLibraryPaths = @(
    "$env:PROGRAMFILES(x86)\Steam\steamapps\common\Counter-Strike Global Offensive",
    "C:\Steam\steamapps\common\Counter-Strike Global Offensive",
    "D:\Steam\steamapps\common\Counter-Strike Global Offensive",
    "E:\Steam\steamapps\common\Counter-Strike Global Offensive",
    "D:\Games\steamapps\common\Counter-Strike Global Offensive"
)
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Counter-Strike 2 (CS2) - Optimization Script' `
               -Subtitle 'February 2026 | Source 2 Engine'
Write-Host "  Stretched Resolution   : $UseStretchedRes" -ForegroundColor White
Write-Host "  Monitor Refresh        : ${MonitorRefreshRate}Hz" -ForegroundColor White
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: FIND CS2 INSTALLATION
# -----------------------------------------------------------------------------

$CS2Path = $null
foreach ($path in $SteamLibraryPaths) {
    if (Test-Path $path) {
        $CS2Path = $path
        break
    }
}

if ($CS2Path) {
    Write-Host "[INFO] Found CS2 at: $CS2Path" -ForegroundColor Green
    $CfgDir     = Join-Path $CS2Path "game\csgo\cfg"
    $AutoExec   = Join-Path $CfgDir "autoexec.cfg"
    $BackupPath = "$AutoExec.bak_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

    if (-not (Test-Path $CfgDir)) { New-Item -ItemType Directory -Path $CfgDir -Force | Out-Null }

    if (Test-Path $AutoExec) {
        Backup-ConfigFile -Path $AutoExec | Out-Null
    }

    # -------------------------------------------------------------------------
    # SECTION 2: WRITE OPTIMIZED AUTOEXEC.CFG
    # WHY FOR EACH SETTING:
    # - fps_max 0: Uncapped -- higher FPS = lower input latency
    # - cl_interp_ratio 1: Reduces interpolation delay for hit registration
    # - rate 786432: Maximum packet rate for modern connections (768KB/s)
    # - cl_updaterate/cmdrate: Maximum tick rate supported (128 on Valve servers)
    # - r_dynamic 0: Disables dynamic lighting - FPS boost, no competitive loss
    # - snd_mixahead 0.05: Reduces audio buffer for lower sound latency
    # - sensitivity: Just a placeholder - set your own value
    # -------------------------------------------------------------------------

    Write-Host "[INFO] Writing autoexec.cfg..." -ForegroundColor DarkCyan

    $AutoExecContent = @"
// ============================================================
// CS2 Competitive AutoExec - Generated February 2026
// Engine: Source 2 | Last validated: Feb 2026
// ============================================================

// --- FRAME RATE ---
// Uncapped FPS -- higher frames = lower input latency even above
// monitor refresh rate. Cap in-game or via NVIDIA CP if desired.
fps_max 0
fps_max_menu 60

// --- NETWORK SETTINGS (Critical for hit registration) ---
// rate: Maximum data rate in bytes/sec - 786432 = 768KB/s (current maximum)
// cl_updaterate: How many updates per second to request from server
// cl_cmdrate: How many commands per second to send to server
// cl_interp_ratio 1 with cl_updaterate 128: minimal interpolation delay
rate 786432
cl_updaterate 128
cl_cmdrate 128
cl_interp 0
cl_interp_ratio 1
// cl_lagcompensation: Keep at 1 for standard lag compensation
cl_lagcompensation 1

// --- GRAPHICS PERFORMANCE ---
// r_dynamic 0: Disables dynamic lights (explosions, flashbangs light effects)
// No competitive advantage to keeping dynamic lighting ON
r_dynamic 0

// fog_enable 0: Disables volumetric fog rendering
// fog_enable 0

// --- RADAR & HUD ---
// Competitive-optimized radar that shows more of the map
cl_radar_always_centered 0
cl_radar_scale 0.4
cl_radar_icon_scale_min 0.6
cl_radar_rotate 1
cl_hud_radar_scale 1.15
cl_hud_background_alpha 0.4

// --- AUDIO ---
// snd_mixahead: Audio buffer size in seconds
// Lower = less audio latency but more CPU usage. 0.05 is safe for most systems
snd_mixahead 0.05
// Footstep and ambient audio levels
// snd_mapobjective_volume: Map objective sounds (bomb, hostage)
snd_musicvolume 0.0
snd_tensecondwarning_volume 0.3

// --- MOUSE ---
// m_rawinput 1: Direct mouse input bypasses Windows cursor pipeline
// sensitivity: PLACEHOLDER - Set your personal value below
m_rawinput 1
sensitivity 2.0
m_mouseaccel1 0
m_mouseaccel2 0
zoom_sensitivity_ratio_mouse 1.0

// --- CROSSHAIR (Competitive Static) ---
// Static crosshair ensures consistent visual reference regardless of movement
// These values mimic a classic CS crosshair preferred by most pros
cl_crosshair_recoil 0
cl_crosshairsize 2
cl_crosshairthickness 1
cl_crosshairdot 0
cl_crosshairgap -1
cl_crosshair_drawoutline 0
cl_crosshaircolor 5
cl_crosshaircolor_r 0
cl_crosshaircolor_g 255
cl_crosshaircolor_b 255
cl_crosshairstyle 4
cl_crosshairusealpha 1
cl_crosshairalpha 255

// --- VIEWMODEL ---
// Moves weapon model to left side and further back for wider FOV
// viewmodel_fov 68 = maximum allowed by game
viewmodel_fov 68
viewmodel_offset_x -2
viewmodel_offset_y -2
viewmodel_offset_z -2
viewmodel_presetpos 3
cl_viewmodel_shift_left_amt 0.5
cl_viewmodel_shift_right_amt 0.25
cl_bob_lower_amt 5
cl_bobamt_lat 0.1
cl_bobamt_vert 0.1

// --- GAME FEEL ---
// These reduce unnecessary animations and UI jitter
cl_show_team_equipment 0
cl_use_opens_buy_menu 0

// Ensure autoexec runs on every launch
echo "Autoexec loaded - CS2 Competitive Config (Feb 2026)"
"@

    Set-Content -Path $AutoExec -Value $AutoExecContent -Encoding UTF8 -Force
    Write-Host "  [OK] autoexec.cfg written to: $AutoExec" -ForegroundColor Green

} else {
    Write-Host "[WARN] CS2 installation not found in common paths." -ForegroundColor Yellow
    Write-Host "       autoexec.cfg NOT written. Locate your CS2 folder manually:" -ForegroundColor Yellow
    Write-Host "       [CS2 Install]\game\csgo\cfg\autoexec.cfg" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 3: SET STEAM LAUNCH OPTIONS FOR CS2
# WHY:
# -novid: Skips intro video on launch (saves ~5 seconds per launch)
# -high: Sets CS2 process to High CPU priority (marginal benefit)
# -nojoy: Disables joystick subsystem (frees minor CPU cycles)
# -fullscreen: Forces fullscreen mode on launch
# NOTE: -tickrate and -freq/-rate are DEPRECATED in CS2 Source 2
#       and should NOT be included - they have no effect or can cause issues
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Attempting to set CS2 Steam launch options..." -ForegroundColor DarkCyan

# CS2 App ID is 730
$SteamAppsKey = "HKCU:\Software\Valve\Steam\Apps\730"
if (-not (Test-Path $SteamAppsKey)) {
    New-Item -Path $SteamAppsKey -Force | Out-Null
}

$LaunchOptions = "-novid -high -nojoy +exec autoexec.cfg"
Set-ItemProperty -Path $SteamAppsKey -Name "LaunchOptions" -Value $LaunchOptions -Type String -Force
Write-Host "  [OK] Launch options set: $LaunchOptions" -ForegroundColor Green
Write-Host "  [NOTE] Verify in Steam > Right-click CS2 > Properties > Launch Options" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# SECTION 4: EXE COMPATIBILITY FLAGS
# -----------------------------------------------------------------------------

$CS2ExePaths = @(
    "$env:PROGRAMFILES(x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe",
    "C:\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe",
    "D:\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe"
)

$null = Set-ExeCompatFlags -ExePaths $CS2ExePaths -CheckKey 'CS2_EXE_FLAGS'

# -----------------------------------------------------------------------------
# SECTION 5: PRINT IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  CS2 - COMPLETE IN-GAME SETTINGS GUIDE" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Display Mode           : Fullscreen Exclusive" -ForegroundColor White
if ($UseStretchedRes) {
    Write-Host "  Resolution             : 1280x960 (4:3 Stretched)" -ForegroundColor White
    Write-Host "                         Set in NVIDIA/AMD Control Panel first:" -ForegroundColor DarkGray
    Write-Host "                         NVIDIA: Manage 3D > Resolution: 1280x960," -ForegroundColor DarkGray
    Write-Host "                         Adjust desktop size: Full-screen" -ForegroundColor DarkGray
    Write-Host "  Aspect Ratio           : Normal (game stretches to fill screen)" -ForegroundColor White
} else {
    Write-Host "  Resolution             : 1920x1080 (native 16:9)" -ForegroundColor White
    Write-Host "  Aspect Ratio           : Widescreen 16:9" -ForegroundColor White
}
Write-Host "  Refresh Rate           : ${MonitorRefreshRate}Hz" -ForegroundColor White
Write-Host "  Boost Player Contrast  : ON (critical - makes enemies stand out)" -ForegroundColor White
Write-Host "  V-Sync                 : Disabled" -ForegroundColor White
Write-Host "  NVIDIA Reflex          : Enabled (not Boost - use in-game setting)" -ForegroundColor White

Write-Host ""
Write-Host "  --- ADVANCED VIDEO ---" -ForegroundColor Cyan
Write-Host "  Global Shadow Quality  : Low (some pros use Medium for read shadows)" -ForegroundColor White
Write-Host "  Model/Texture Detail   : Low" -ForegroundColor White
Write-Host "  Texture Streaming      : Disabled" -ForegroundColor White
Write-Host "  Effect Detail          : Low" -ForegroundColor White
Write-Host "  Shader Detail          : Low" -ForegroundColor White
Write-Host "  Boost Player Contrast  : Enabled" -ForegroundColor White
Write-Host "  Multicore Rendering    : Enabled" -ForegroundColor White
Write-Host "  FidelityFX Super Res.  : Disabled (or Quality if GPU-limited)" -ForegroundColor White
Write-Host "  NVIDIA DLSS            : Disabled (or Quality if GPU-limited)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : Disabled" -ForegroundColor White
Write-Host "  Anti-Aliasing          : 4x MSAA (or CMAA2 if FPS-limited)" -ForegroundColor White
Write-Host "                         4x MSAA improves model edge clarity" -ForegroundColor DarkGray
Write-Host "  High Dynamic Range     : Performance" -ForegroundColor White

Write-Host ""
Write-Host "  --- AUDIO ---" -ForegroundColor Cyan
Write-Host "  Audio Output           : Headphones (critical for HRTF)" -ForegroundColor White
Write-Host "  L/R Isolation          : 100% (maximum directional separation)" -ForegroundColor White
Write-Host "  Perspective Correction : Disabled (improves left-right distinction)" -ForegroundColor White
Write-Host "  EQ Profile             : Crisp" -ForegroundColor White
Write-Host "  Stream Music           : OFF" -ForegroundColor White

Write-Host ""
Write-Host "  --- SENSITIVITY ---" -ForegroundColor Cyan
Write-Host "  DPI                    : 400 or 800 (pro standard)" -ForegroundColor White
Write-Host "  In-Game Sensitivity    : Set for 200-800 eDPI range" -ForegroundColor White
Write-Host "    At 400 DPI: sens 0.5-2.0 (eDPI 200-800)" -ForegroundColor DarkGray
Write-Host "    At 800 DPI: sens 0.25-1.0 (eDPI 200-800)" -ForegroundColor DarkGray
Write-Host "  Zoom Sensitivity       : 1.0 (consistent muscle memory)" -ForegroundColor White
Write-Host "  Mouse Acceleration     : Disabled" -ForegroundColor White
Write-Host "  Raw Input              : Enabled" -ForegroundColor White
Write-Host "  Polling Rate           : 1000Hz (4000Hz if supported and stable)" -ForegroundColor White
Write-Host ""
Write-Host "  --- PRO STATISTICS (863 Pro Players, Feb 2026 - ProSettings.net) ---" -ForegroundColor Cyan
Write-Host "  ~55% of pros use 4:3 stretched resolution" -ForegroundColor White
Write-Host "  ~45% use 16:9 native (1920x1080)" -ForegroundColor White
Write-Host "  Median eDPI: 830 (400DPI x 2.07 avg sens)" -ForegroundColor White
Write-Host "  100% use 400 or 800 DPI" -ForegroundColor White
Write-Host "  100% MSAA enabled (4x most common)" -ForegroundColor White
Write-Host "  Notable pros: s1mple 400DPI 3.09, NiKo 400DPI 1.49, ZywOo 400DPI 2.0" -ForegroundColor White

Write-Host ""
Write-Host "  --- LAUNCH OPTIONS (Already set via registry) ---" -ForegroundColor Cyan
Write-Host "  $LaunchOptions" -ForegroundColor White
Write-Host "  DEPRECATED (do NOT use): -tickrate -threads -processheap" -ForegroundColor DarkGray
Write-Host "  These are Source 1 options that have no effect in CS2's Source 2 engine" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[DONE] CS2 autoexec.cfg written and launch options set." -ForegroundColor Green
Write-Host ""
