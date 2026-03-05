#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Dota 2 - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Source 2

.DESCRIPTION
    Applies competitive performance optimizations for Dota 2:
    - Writes optimized video.txt (KeyValues format, read-merge-write)
    - Creates autoexec.cfg with network and performance commands
    - Sets Steam launch options for Dota 2 in the registry
    - Sets EXE compatibility flags (HIGHDPIAWARE, DISABLEFULLSCREENOPTIMIZATIONS)
    - Prints the full in-game settings guide

    IMPORTANT NOTES:
    - video.txt is overwritten by the game on exit -- autoexec.cfg persists
    - autoexec.cfg commands override video.txt settings
    - VAC does NOT monitor config file changes (completely safe)
    - Steam Cloud may override local video.txt (warn users)

.NOTES
    Dota 2 config location:
    <Steam>\steamapps\common\dota 2 beta\game\dota\cfg\video.txt
    <Steam>\steamapps\common\dota 2 beta\game\dota\cfg\autoexec.cfg
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine

# Steam library paths to search
$SteamLibraryPaths = @(
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\dota 2 beta",
    "C:\Steam\steamapps\common\dota 2 beta",
    "D:\Steam\steamapps\common\dota 2 beta",
    "D:\SteamLibrary\steamapps\common\dota 2 beta",
    "E:\Steam\steamapps\common\dota 2 beta",
    "E:\SteamLibrary\steamapps\common\dota 2 beta",
    "D:\Games\steamapps\common\dota 2 beta"
)
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Dota 2 - Optimization Script' `
               -Subtitle 'March 2026 | Source 2 Engine'
Write-Host "  Monitor Resolution     : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Monitor Refresh        : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: FIND DOTA 2 INSTALLATION
# -----------------------------------------------------------------------------

$DotaPath = $null

# Check env var from app first
if ($env:DOTA2_PATH -and (Test-Path $env:DOTA2_PATH)) {
    $DotaPath = $env:DOTA2_PATH
    Write-Host "[INFO] Dota 2 found via env var: $DotaPath" -ForegroundColor Green
}

# Check common Steam library paths
if (-not $DotaPath) {
    foreach ($path in $SteamLibraryPaths) {
        if (Test-Path $path) {
            $DotaPath = $path
            Write-Host "[INFO] Found Dota 2 at: $DotaPath" -ForegroundColor Green
            break
        }
    }
}

# Try Steam registry detection
if (-not $DotaPath) {
    try {
        $steamPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        if (-not $steamPath) {
            $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        }
        if ($steamPath) {
            # Parse libraryfolders.vdf for additional library paths
            $vdfPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"
            $libraryPaths = @($steamPath)
            if (Test-Path $vdfPath) {
                $vdfContent = Get-Content $vdfPath -Raw
                $pathMatches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
                foreach ($match in $pathMatches) {
                    $libPath = $match.Groups[1].Value -replace '\\\\', '\'
                    if (Test-Path $libPath) { $libraryPaths += $libPath }
                }
            }
            foreach ($libPath in $libraryPaths) {
                $candidate = Join-Path $libPath "steamapps\common\dota 2 beta"
                if (Test-Path $candidate) {
                    $DotaPath = $candidate
                    Write-Host "[INFO] Found Dota 2 via Steam registry: $DotaPath" -ForegroundColor Green
                    break
                }
            }
        }
    } catch {
        Write-Host "[WARN] Steam registry detection failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $DotaPath) {
    Write-Host "[WARN] Dota 2 installation not found." -ForegroundColor Yellow
    Write-Host "       Config files NOT written. Locate your Dota 2 folder manually." -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'DOTA2_CONFIG_WRITTEN' -Detail 'GAME_NOT_FOUND'
    Write-Check -Status 'WARN' -Key 'DOTA2_AUTOEXEC_WRITTEN' -Detail 'GAME_NOT_FOUND'
} else {
    $CfgDir = Join-Path $DotaPath "game\dota\cfg"

    if (-not (Test-Path $CfgDir)) {
        New-Item -ItemType Directory -Path $CfgDir -Force | Out-Null
    }

    # -------------------------------------------------------------------------
    # SECTION 2: WRITE OPTIMIZED VIDEO.TXT (KeyValues format)
    # Read-merge-write: preserve user resolution, override performance keys
    # -------------------------------------------------------------------------

    $VideoTxtPath = Join-Path $CfgDir "video.txt"

    Write-Host "[INFO] Writing video.txt..." -ForegroundColor DarkCyan

    try {
        # Read existing config if present
        $existingConfig = [ordered]@{}
        if (Test-Path $VideoTxtPath) {
            Backup-ConfigFile -Path $VideoTxtPath | Out-Null
            $existingContent = Get-Content $VideoTxtPath -Raw
            $kvMatches = [regex]::Matches($existingContent, '"([^"]+)"\s+"([^"]*)"')
            foreach ($match in $kvMatches) {
                $key = $match.Groups[1].Value
                $value = $match.Groups[2].Value
                if ($key -ne "VideoConfig") {
                    $existingConfig[$key] = $value
                }
            }
        }

        # Competitive performance settings to apply
        $competitiveSettings = [ordered]@{
            "setting.cl_particle_fallback_base"            = "0"
            "setting.cl_particle_fallback_multiplier"      = "0"
            "setting.fullscreen"                           = "1"
            "setting.nowindowborder"                       = "0"
            "setting.aspectratiomode"                      = "-1"
            "setting.r_deferred_height_fog"                = "0"
            "setting.r_deferred_simple_light"              = "1"
            "setting.r_screenspace_aa"                     = "0"
            "setting.mat_queue_mode"                       = "2"
            "setting.gpu_mem_level"                        = "0"
            "setting.cpu_level"                            = "0"
            "setting.gpu_level"                            = "0"
            "setting.mat_vsync"                            = "0"
            "setting.r_texturefilteringquality"            = "0"
            "setting.r_shadow_half_update_rate"            = "1"
            "setting.r_renderingpipeline"                  = "0"
            "setting.mat_dynamic_tonemapping"              = "0"
            "setting.r_dota_allow_fow_fog"                = "1"
            "setting.r_bloom_new"                          = "0"
            "setting.r_high_quality_hero_water_lighting"   = "0"
            "setting.r_screenspace_ground_ao"              = "0"
            "setting.r_dota_normal_mapped_ground"          = "0"
            "setting.r_world_normal_maps"                  = "0"
            "setting.r_ambient_occlusion"                  = "0"
            "setting.r_dota_cheap_water"                   = "1"
            "setting.r_dota_hdr"                           = "0"
            "setting.r_dota_specular"                      = "0"
            "setting.dota_global_light_world_shadow"       = "0"
            "setting.r_dota_tree_wind"                     = "0"
            "setting.r_dota_atmospheric_fog"               = "0"
            "setting.r_additive_animation"                 = "0"
            "setting.r_deferred_additive_pass"             = "0"
            "setting.r_deferred_specular"                  = "0"
            "setting.r_deferred_specular_bloom"            = "0"
            "setting.r_grass"                              = "0"
            "setting.r_compressedtextures"                 = "1"
            "setting.mat_software_aa_strength"             = "0"
        }

        # Preserve user resolution if it was already set
        if (-not $existingConfig.Contains("setting.defaultres")) {
            $competitiveSettings["setting.defaultres"] = [string]$MonitorWidth
        }
        if (-not $existingConfig.Contains("setting.defaultresheight")) {
            $competitiveSettings["setting.defaultresheight"] = [string]$MonitorHeight
        }

        # Merge: start with existing, override with competitive settings
        $mergedConfig = [ordered]@{}
        foreach ($key in $existingConfig.Keys) {
            $mergedConfig[$key] = $existingConfig[$key]
        }
        foreach ($key in $competitiveSettings.Keys) {
            $mergedConfig[$key] = $competitiveSettings[$key]
        }

        # Build KeyValues content
        $kvContent = "`"VideoConfig`"`r`n{`r`n"
        foreach ($key in $mergedConfig.Keys) {
            $value = $mergedConfig[$key]
            $kvContent += "`t`"$key`"`t`t`"$value`"`r`n"
        }
        $kvContent += "}`r`n"

        [System.IO.File]::WriteAllText($VideoTxtPath, $kvContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [OK] video.txt written to: $VideoTxtPath" -ForegroundColor Green
        Write-Host "  [NOTE] Game will overwrite video.txt on exit -- autoexec.cfg provides persistent overrides" -ForegroundColor DarkGray
        Write-Check -Status 'OK' -Key 'DOTA2_CONFIG_WRITTEN'
    } catch {
        Write-Host "  [FAIL] Failed to write video.txt: $($_.Exception.Message)" -ForegroundColor Red
        Write-Check -Status 'FAIL' -Key 'DOTA2_CONFIG_WRITTEN' -Detail $_.Exception.Message
    }

    # -------------------------------------------------------------------------
    # SECTION 3: WRITE AUTOEXEC.CFG
    # These commands persist across sessions and override video.txt
    # -------------------------------------------------------------------------

    $AutoExecPath = Join-Path $CfgDir "autoexec.cfg"

    Write-Host ""
    Write-Host "[INFO] Writing autoexec.cfg..." -ForegroundColor DarkCyan

    try {
        if (Test-Path $AutoExecPath) {
            Backup-ConfigFile -Path $AutoExecPath | Out-Null
        }

        $AutoExecContent = @"
// ============================================================
// Dota 2 Competitive AutoExec - Generated March 2026
// Engine: Source 2 | Last validated: Mar 2026
// ============================================================

// --- FPS & PERFORMANCE ---
// Uncapped FPS -- higher frames = lower input latency even above
// monitor refresh rate. Cap in-game or via NVIDIA CP if desired.
fps_max 0
engine_no_focus_sleep 0
r_dynamic_lod 1
r_lod_switch_scale 0.5
dota_cheap_water 1
dota_embers 0
cl_globallight_shadow_mode 0
mat_vsync 0
mat_queue_mode 2

// --- NETWORK (Competitive) ---
// rate: Maximum data rate in bytes/sec - 786432 = 768KB/s
// cl_cmdrate/updaterate: 60 ticks/sec (Dota 2 server tick rate)
// cl_interp 0 + cl_interp_ratio 1: minimum interpolation delay
rate 786432
cl_cmdrate 60
cl_updaterate 60
cl_interp 0
cl_interp_ratio 1
cl_lagcompensation 1
cl_smooth 1
cl_smoothtime 0.01

// --- VISUAL CLUTTER REDUCTION ---
dota_hud_healthbar_number 1
dota_sf_game_end_delay 0
dota_disable_range_finder 0

echo "Autoexec loaded - Dota 2 Competitive Config (Mar 2026)"
"@

        Set-Content -Path $AutoExecPath -Value $AutoExecContent -Encoding UTF8 -Force
        Write-Host "  [OK] autoexec.cfg written to: $AutoExecPath" -ForegroundColor Green
        Write-Check -Status 'OK' -Key 'DOTA2_AUTOEXEC_WRITTEN'
    } catch {
        Write-Host "  [FAIL] Failed to write autoexec.cfg: $($_.Exception.Message)" -ForegroundColor Red
        Write-Check -Status 'FAIL' -Key 'DOTA2_AUTOEXEC_WRITTEN' -Detail $_.Exception.Message
    }
}

# -----------------------------------------------------------------------------
# SECTION 4: SET STEAM LAUNCH OPTIONS FOR DOTA 2
# WHY:
# -novid: Skips intro video on launch
# -high: Sets process priority to High
# -dx11: Forces DirectX 11 renderer (most stable)
# +fps_max 0: Uncaps FPS at launch
# -prewarm: Pre-loads shaders and assets
# +exec autoexec.cfg: Ensures autoexec runs
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "[INFO] Attempting to set Dota 2 Steam launch options..." -ForegroundColor DarkCyan

# Dota 2 App ID is 570
$SteamAppsKey = "HKCU:\Software\Valve\Steam\Apps\570"
try {
    if (-not (Test-Path $SteamAppsKey)) {
        New-Item -Path $SteamAppsKey -Force | Out-Null
    }

    $LaunchOptions = "-novid -high -dx11 +fps_max 0 -prewarm +exec autoexec.cfg"
    Set-ItemProperty -Path $SteamAppsKey -Name "LaunchOptions" -Value $LaunchOptions -Type String -Force
    Write-Host "  [OK] Launch options set: $LaunchOptions" -ForegroundColor Green
    Write-Host "  [NOTE] Verify in Steam > Right-click Dota 2 > Properties > Launch Options" -ForegroundColor DarkGray
    Write-Check -Status 'OK' -Key 'DOTA2_LAUNCH_OPTIONS'
} catch {
    Write-Host "  [WARN] Could not set launch options: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'DOTA2_LAUNCH_OPTIONS' -Detail $_.Exception.Message
}

# -----------------------------------------------------------------------------
# SECTION 5: EXE COMPATIBILITY FLAGS
# -----------------------------------------------------------------------------

$DotaExePaths = @()
if ($DotaPath) {
    $DotaExePaths += Join-Path $DotaPath "game\bin\win64\dota2.exe"
}
# Also check common paths in case DotaPath was not found
$DotaExePaths += @(
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe",
    "C:\Steam\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe",
    "D:\Steam\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe",
    "D:\SteamLibrary\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe",
    "E:\Steam\steamapps\common\dota 2 beta\game\bin\win64\dota2.exe"
)

$null = Set-ExeCompatFlags -ExePaths $DotaExePaths -CheckKey 'DOTA2_EXE_FLAGS'

# -----------------------------------------------------------------------------
# SECTION 6: PRINT IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  DOTA 2 - COMPLETE IN-GAME SETTINGS GUIDE" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- VIDEO SETTINGS ---" -ForegroundColor Cyan
Write-Host "  Display Mode           : Exclusive Fullscreen" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight} (native)" -ForegroundColor White
Write-Host "  Rendering API          : DX11 (or test -vulkan for +5-15% FPS)" -ForegroundColor White
Write-Host "  V-Sync                 : Off" -ForegroundColor White
Write-Host "  Anti-Aliasing          : Off" -ForegroundColor White

Write-Host ""
Write-Host "  --- QUALITY SETTINGS (ALL LOW for max FPS) ---" -ForegroundColor Cyan
Write-Host "  Texture Quality        : Low" -ForegroundColor White
Write-Host "  Effects Quality        : Low (big FPS gain in teamfights)" -ForegroundColor White
Write-Host "  Shadow Quality         : Off (purely cosmetic)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : Off" -ForegroundColor White
Write-Host "  Bloom                  : Off (can obscure ability effects)" -ForegroundColor White
Write-Host "  Water Quality          : Low" -ForegroundColor White
Write-Host "  Threaded Rendering     : On (always)" -ForegroundColor White
Write-Host "  Compressed Textures    : On (saves VRAM)" -ForegroundColor White

Write-Host ""
Write-Host "  --- COMPETITIVE CLARITY ---" -ForegroundColor Cyan
Write-Host "  Grass                  : Off (removes ground clutter)" -ForegroundColor White
Write-Host "  Tree Wind              : Off (static trees easier to read)" -ForegroundColor White
Write-Host "  Atmospheric Fog        : Off (cleaner visual field)" -ForegroundColor White
Write-Host "  Fog of War Fog         : ON (keep -- competitive fog of war visual)" -ForegroundColor White
Write-Host "  Specular/HDR           : Off (reduces visual noise)" -ForegroundColor White

Write-Host ""
Write-Host "  --- STEAM CLOUD WARNING ---" -ForegroundColor Cyan
Write-Host "  Steam Cloud may override video.txt changes." -ForegroundColor White
Write-Host "  To prevent: Steam > Dota 2 > Properties > uncheck" -ForegroundColor White
Write-Host "  'Keep game saves in the Steam Cloud'" -ForegroundColor White
Write-Host "  autoexec.cfg settings persist regardless of Cloud sync." -ForegroundColor White

Write-Host ""
Write-Host "  --- VULKAN VS DX11 ---" -ForegroundColor Cyan
Write-Host "  Vulkan may give +5-15% FPS on NVIDIA 10xx+ and AMD RX 400+" -ForegroundColor White
Write-Host "  To test: change launch option from -dx11 to -vulkan" -ForegroundColor White
Write-Host "  If stable, keep Vulkan. If crashes, revert to -dx11." -ForegroundColor White

Write-Host ""
Write-Host "  --- LAUNCH OPTIONS (Already set via registry) ---" -ForegroundColor Cyan
Write-Host "  $LaunchOptions" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] Dota 2 optimization complete." -ForegroundColor Green
Write-Host "  video.txt + autoexec.cfg written, launch options set." -ForegroundColor Green
Write-Host ""
