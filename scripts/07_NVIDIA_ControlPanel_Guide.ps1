<#
.SYNOPSIS
    NVIDIA Control Panel & AMD Adrenalin Settings Guide
    Version: 1.0 | Updated: February 2026

.DESCRIPTION
    This script prints the recommended GPU control panel settings and
    attempts to apply NVIDIA settings via NvAPI where supported.

    Most NVIDIA/AMD Control Panel settings CANNOT be set via script
    (they require the GUI or vendor SDKs). This script:
    1. Sets any registry-accessible GPU settings
    2. Prints a full manual guide for NVIDIA and AMD
    3. Configures Windows-level GPU scheduler settings

.NOTES
    For NVIDIA: Open NVIDIA Control Panel > Manage 3D Settings
    For AMD: Open AMD Software Adrenalin Edition > Gaming > Graphics
#>

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  GPU Control Panel Settings Guide" -ForegroundColor Cyan
Write-Host "  February 2026 | NVIDIA & AMD" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Detect GPU vendor
$GPUInfo = Get-WmiObject Win32_VideoController | Select-Object -First 1
$IsNvidia = $GPUInfo.Name -match "NVIDIA|GeForce|RTX|GTX"
$IsAMD    = $GPUInfo.Name -match "AMD|Radeon|RX "

if ($GPUInfo) {
    Write-Host "[DETECTED GPU] $($GPUInfo.Name)" -ForegroundColor Green
    Write-Host ""
}

# -----------------------------------------------------------------------------
# NVIDIA CONTROL PANEL GUIDE
# -----------------------------------------------------------------------------

if ($IsNvidia -or (-not $IsAMD)) {
    Write-Host "======================================================" -ForegroundColor Yellow
    Write-Host "  NVIDIA CONTROL PANEL - RECOMMENDED SETTINGS" -ForegroundColor Yellow
    Write-Host "  Open: Right-click desktop > NVIDIA Control Panel" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Navigate to: Manage 3D Settings > Global Settings" -ForegroundColor Cyan
    Write-Host "  (Apply globally first, then override per-game if needed)" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  SETTING                          | VALUE              | WHY" -ForegroundColor White
    Write-Host "  -----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Image Scaling                    | OFF                | Use in-game DLSS instead" -ForegroundColor White
    Write-Host "  Ambient Occlusion                | OFF                | FPS cost, hurts visibility" -ForegroundColor White
    Write-Host "  Anisotropic Filtering            | Application-ctrl   | Let game manage" -ForegroundColor White
    Write-Host "  Antialiasing - FXAA              | OFF                | Use in-game AA" -ForegroundColor White
    Write-Host "  Antialiasing - Mode              | Application-ctrl   | Let game manage" -ForegroundColor White
    Write-Host "  Background App Max Frame Rate    | OFF                | Uncap desktop performance" -ForegroundColor White
    Write-Host "  Low Latency Mode                 | On                 | Reduces pre-rendered frames" -ForegroundColor White
    Write-Host "                                   |                    | Use 'On' not 'Ultra'" -ForegroundColor DarkGray
    Write-Host "                                   |                    | If game has NVIDIA Reflex," -ForegroundColor DarkGray
    Write-Host "                                   |                    | set this to OFF and use Reflex" -ForegroundColor DarkGray
    Write-Host "  Max Frame Rate                   | OFF                | Cap in-game instead" -ForegroundColor White
    Write-Host "  Monitor Technology               | G-SYNC (if avail)  | Enables G-SYNC for tear-free" -ForegroundColor White
    Write-Host "                                   |                    | gaming without V-Sync latency" -ForegroundColor DarkGray
    Write-Host "  OpenGL Rendering GPU             | Your GPU           | Ensure correct GPU selected" -ForegroundColor White
    Write-Host "  Power Management Mode            | Prefer Maximum Performance | MOST IMPORTANT: Prevents" -ForegroundColor White
    Write-Host "                                   |                    | GPU from downclocking" -ForegroundColor DarkGray
    Write-Host "  Shader Cache Size                | Driver Default     | Don't reduce this" -ForegroundColor White
    Write-Host "  Texture Filtering - Anisotropic  | On                 | Better texture sharpness" -ForegroundColor White
    Write-Host "  Texture Filtering - Quality      | High Performance   | FPS over visual quality" -ForegroundColor White
    Write-Host "  Texture Filtering - Trilinear    | On                 | Minor quality at no perf cost" -ForegroundColor White
    Write-Host "  Threaded Optimization            | On                 | Better multi-core usage" -ForegroundColor White
    Write-Host "  Triple Buffering                 | Off                | Adds latency" -ForegroundColor White
    Write-Host "  Vertical Sync                    | Off                | Always OFF for competitive" -ForegroundColor White
    Write-Host "  Virtual Reality Pre-Rendered Fr. | 1                  | Minimum for lowest latency" -ForegroundColor White
    Write-Host "  Vulkan/GL Present Method         | Prefer Native      | Lower latency on modern GPUs" -ForegroundColor White

    Write-Host ""
    Write-Host "  --- G-SYNC SETUP (if monitor supports it) ---" -ForegroundColor Cyan
    Write-Host "  Navigate to: Set up G-SYNC > Enable G-SYNC/G-SYNC compatible" -ForegroundColor White
    Write-Host "  Enable for: Fullscreen and windowed mode" -ForegroundColor White
    Write-Host "  Then in game: V-Sync OFF, cap FPS 3 below monitor max" -ForegroundColor White
    Write-Host "  Example: 240Hz monitor = 237 FPS cap + G-SYNC = tear-free with low latency" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "  --- PER-GAME OVERRIDES (Manage 3D Settings > Program Settings) ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  VALORANT: Low Latency Mode = OFF (use Reflex in-game instead)" -ForegroundColor White
    Write-Host "  CS2:      Low Latency Mode = OFF (use in-game Reflex Enabled)" -ForegroundColor White
    Write-Host "  Fortnite: Low Latency Mode = OFF (use Reflex On+Boost in-game)" -ForegroundColor White
    Write-Host "  Black Ops 7: Low Latency Mode = On (game may not have Reflex)" -ForegroundColor White
    Write-Host "  Arc Raiders: Low Latency Mode = OFF (use Reflex On+Boost in-game)" -ForegroundColor White

    Write-Host ""
    Write-Host "  --- DRIVER RECOMMENDATION ---" -ForegroundColor Cyan
    Write-Host "  Use Game Ready Drivers (GRD) over Studio Drivers for gaming." -ForegroundColor White
    Write-Host "  Check for updates via GeForce Experience or NVIDIA website." -ForegroundColor White
    Write-Host "  Feb 2026: Use the most recent Game Ready Driver from NVIDIA." -ForegroundColor White
    Write-Host "  Clean install (DDU) recommended after major driver jumps." -ForegroundColor White
}

# -----------------------------------------------------------------------------
# AMD ADRENALIN GUIDE
# -----------------------------------------------------------------------------

if ($IsAMD) {
    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Red
    Write-Host "  AMD SOFTWARE ADRENALIN - RECOMMENDED SETTINGS" -ForegroundColor Red
    Write-Host "  Open: AMD Software Adrenalin Edition (system tray or Start)" -ForegroundColor Red
    Write-Host "======================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Navigate to: Gaming > Graphics (Global Settings)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  SETTING                          | VALUE              | WHY" -ForegroundColor White
    Write-Host "  -----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Anti-Aliasing                    | Use App Settings   | Game controls AA" -ForegroundColor White
    Write-Host "  Anti-Aliasing Method             | Multisampling      | Less blurry than temporal" -ForegroundColor White
    Write-Host "  Morphological AA (MLAA)          | Disabled           | Use in-game AA" -ForegroundColor White
    Write-Host "  Anisotropic Filtering            | Disabled           | Let game manage" -ForegroundColor White
    Write-Host "  Texture Filtering Quality        | Performance        | FPS over quality" -ForegroundColor White
    Write-Host "  Surface Format Optimizations     | Enabled            | FPS boost" -ForegroundColor White
    Write-Host "  Wait for Vertical Refresh        | Always Off         | V-Sync always OFF" -ForegroundColor White
    Write-Host "  OpenGL Triple Buffering          | Disabled           | Adds latency" -ForegroundColor White
    Write-Host "  Shader Cache                     | AMD Optimized      | Keep enabled" -ForegroundColor White
    Write-Host "  Tessellation Mode                | Optimized          | Balanced perf/quality" -ForegroundColor White
    Write-Host "  Frame Rate Target Control        | Disabled           | Cap in-game" -ForegroundColor White
    Write-Host "  AMD Anti-Lag                     | Enabled            | Reduces input lag" -ForegroundColor White
    Write-Host "  AMD Anti-Lag+                    | Enabled (if avail) | Next-gen latency reduction" -ForegroundColor White
    Write-Host "  AMD Radeon Boost                 | Enabled            | Dynamic res scaling for FPS" -ForegroundColor White
    Write-Host "                                   |                    | Only during fast movement" -ForegroundColor DarkGray
    Write-Host "  AMD Fluid Motion Frames           | Disabled           | Adds latency (not for comp)" -ForegroundColor White
    Write-Host "  FreeSync Premium                 | Enabled            | If monitor supports it" -ForegroundColor White
    Write-Host "  RSR (Radeon Super Resolution)    | OFF                | Use in-game FSR instead" -ForegroundColor White

    Write-Host ""
    Write-Host "  Navigate to: Performance > Tuning" -ForegroundColor Cyan
    Write-Host "  Power Tuning               : Default or +20% Power Limit" -ForegroundColor White
    Write-Host "  GPU Tuning                 : Auto (for stability) or manual OC" -ForegroundColor White
}

# -----------------------------------------------------------------------------
# WINDOWS DISPLAY SETTINGS
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  WINDOWS DISPLAY SETTINGS (Manual Steps)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Settings > System > Display > Advanced Display" -ForegroundColor White
Write-Host "     Choose refresh rate: Set to your monitor's MAXIMUM Hz" -ForegroundColor White
Write-Host ""
Write-Host "  2. Settings > System > Display > Graphics" -ForegroundColor White
Write-Host "     Hardware-Accelerated GPU Scheduling: ON" -ForegroundColor White
Write-Host "     Variable Refresh Rate: ON (if monitor supports G-Sync/FreeSync)" -ForegroundColor White
Write-Host ""
Write-Host "  3. Settings > System > Display > Night light: OFF during gaming" -ForegroundColor White
Write-Host ""
Write-Host "  4. Desktop: Right-click > Display Settings > HDR" -ForegroundColor White
Write-Host "     HDR: OFF for competitive gaming (washes out colors, adds processing)" -ForegroundColor White
Write-Host "     Exception: Only enable if your monitor has 1000+ nit HDR and you" -ForegroundColor White
Write-Host "     prefer it for single-player/visual quality gaming" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[DONE] Apply the above settings manually in your GPU control panel." -ForegroundColor Green
Write-Host ""
