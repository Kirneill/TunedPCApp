#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Apex Legends - PC Optimization Script
    Version: 1.0 | Updated: February 2026
    Engine: Source (r5apex) | Anti-Cheat: Easy Anti-Cheat

.DESCRIPTION
    Applies max-FPS Apex settings based on the project's research profile:
    - Writes competitive videoconfig.txt values
    - Sets videoconfig.txt to read-only (critical for persistence)
    - Creates/updates autoexec.cfg in the game install cfg folder
    - Applies Windows EXE compatibility flags for r5apex.exe

    The script only modifies user config files and Windows compatibility flags.
    It does not patch binaries or touch memory.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

function Find-ApexInstallPath {
    param([string]$HintPath)

    if (-not [string]::IsNullOrWhiteSpace($HintPath) -and (Test-Path $HintPath)) {
        if ($HintPath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
            return (Split-Path -Parent $HintPath)
        }
        return $HintPath
    }

    $registryCandidates = @(
        @{ Path = 'HKLM:\SOFTWARE\Respawn\Apex'; Name = 'Install Dir' },
        @{ Path = 'HKLM:\SOFTWARE\Respawn\Apex'; Name = 'InstallDir' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Respawn\Apex'; Name = 'Install Dir' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Respawn\Apex'; Name = 'InstallDir' }
    )

    foreach ($candidate in $registryCandidates) {
        try {
            $item = Get-ItemProperty -Path $candidate.Path -ErrorAction Stop
            $prop = $item.PSObject.Properties[$candidate.Name]
            if ($null -ne $prop) {
                $installDir = [string]$prop.Value
                if (-not [string]::IsNullOrWhiteSpace($installDir) -and (Test-Path $installDir)) {
                    return $installDir
                }
            }
        } catch {}
    }

    $steamRoot = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
    if (-not [string]::IsNullOrWhiteSpace($steamRoot)) {
        $defaultSteamPath = Join-Path $steamRoot 'steamapps\common\Apex Legends'
        if (Test-Path $defaultSteamPath) {
            return $defaultSteamPath
        }

        $libraryVdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path $libraryVdf) {
            try {
                $raw = Get-Content -Path $libraryVdf -Raw -ErrorAction Stop
                $matches = [regex]::Matches($raw, '"path"\s+"([^"]+)"')
                foreach ($match in $matches) {
                    $libraryPath = $match.Groups[1].Value -replace '\\\\', '\'
                    if ([string]::IsNullOrWhiteSpace($libraryPath)) { continue }
                    $steamApex = Join-Path $libraryPath 'steamapps\common\Apex Legends'
                    if (Test-Path $steamApex) {
                        return $steamApex
                    }
                }
            } catch {}
        }
    }

    $commonPaths = @(
        'C:\Program Files (x86)\Steam\steamapps\common\Apex Legends',
        'C:\Program Files\Steam\steamapps\common\Apex Legends',
        'D:\Steam\steamapps\common\Apex Legends',
        'D:\SteamLibrary\steamapps\common\Apex Legends',
        'E:\Steam\steamapps\common\Apex Legends',
        'E:\SteamLibrary\steamapps\common\Apex Legends',
        'C:\Program Files\EA Games\Apex Legends',
        'D:\EA Games\Apex Legends',
        'E:\EA Games\Apex Legends',
        'C:\Program Files (x86)\Origin Games\Apex',
        'D:\Origin Games\Apex',
        'E:\Origin Games\Apex'
    )

    foreach ($pathCandidate in $commonPaths) {
        if (Test-Path $pathCandidate) {
            return $pathCandidate
        }
    }

    return $null
}

Write-SQHeader -Title 'Apex Legends - Optimization Script' `
               -Subtitle 'February 2026 | Max FPS + Competitive Visibility'
Write-Host "  Target Resolution : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  Refresh Rate      : ${MonitorRefresh}Hz" -ForegroundColor White
Write-Host ""

# -----------------------------------------------------------------------------
# SECTION 1: WRITE VIDEOCONFIG.TXT (CRITICAL) AND LOCK READ-ONLY
# -----------------------------------------------------------------------------

$ApexLocalDir = Join-Path $env:USERPROFILE 'Saved Games\Respawn\Apex\local'
$VideoConfigPath = Join-Path $ApexLocalDir 'videoconfig.txt'

if (-not (Test-Path $ApexLocalDir)) {
    New-Item -ItemType Directory -Path $ApexLocalDir -Force | Out-Null
}

if (Test-Path $VideoConfigPath) {
    Backup-ConfigFile -Path $VideoConfigPath | Out-Null
}

$VideoConfigContent = @"
"VideoConfig"
{
    "setting.cl_gib_allow"                    "0"
    "setting.cl_particle_fallback_base"       "0"
    "setting.cl_particle_fallback_multiplier" "0"
    "setting.cl_ragdoll_maxcount"             "0"
    "setting.cl_ragdoll_self_collision"       "0"
    "setting.csm_coverage"                    "1"
    "setting.csm_cascade_res"                 "512"
    "setting.fadeDistScale"                   "1.0"
    "setting.gpu_mem_level"                   "0"
    "setting.mat_depthfeather_enable"         "0"
    "setting.mat_forceaniso"                  "2"
    "setting.mat_letterbox_aspect_goal"       "0"
    "setting.mat_letterbox_aspect_threshold"  "0"
    "setting.mat_mip_linear"                  "0"
    "setting.mat_monitorgamma"                "1.6"
    "setting.mat_monitorgamma_tv_enabled"     "0"
    "setting.mat_queue_mode"                  "2"
    "setting.mat_texture_list_txinfo"         "0"
    "setting.mat_vsync"                       "0"
    "setting.mat_vsync_mode"                  "0"
    "setting.model_lod_meshes_enable"         "0"
    "setting.modeldecals_forceAllowed"        "0"
    "setting.r_createmodeldecals"             "0"
    "setting.r_decals"                        "0"
    "setting.r_drawscreenspaceparticles"      "0"
    "setting.r_dynamic"                       "1"
    "setting.r_jiggle_bones"                  "0"
    "setting.r_lod_switch_scale"              "0.6"
    "setting.shadow_enable"                   "0"
    "setting.shadow_depth_dimen_min"          "0"
    "setting.shadow_depth_upres_factor_max"   "0"
    "setting.shadow_maxdynamic"               "0"
    "setting.ssao_enabled"                    "0"
    "setting.ssao_downsample"                 "3"
    "setting.stream_memory"                   "300000"
    "setting.defaultres"                      "$MonitorWidth"
    "setting.defaultresheight"                "$MonitorHeight"
    "setting.fullscreen"                      "1"
    "setting.nowindowborder"                  "1"
    "setting.volumetric_lighting"             "0"
    "setting.mat_dynamic_tonemapping"         "0"
    "setting.r_particle_low_res_enable"       "0"
    "setting.cl_spot_shadow_detail"           "0"
    "setting.dvs_enable"                      "0"
    "setting.dvs_gpuframetime_min"            "14000"
    "setting.dvs_gpuframetime_max"            "16500"
    "setting.fps_max"                         "0"
}
"@

try {
    Set-Content -Path $VideoConfigPath -Value $VideoConfigContent -Encoding ASCII -Force -ErrorAction Stop
    Lock-ConfigFile -Path $VideoConfigPath
    Write-Host "[OK] Wrote videoconfig.txt and set read-only lock." -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Could not write videoconfig.txt: $($_.Exception.Message)" -ForegroundColor Red
}

$videoConfigValid = $false
if (Test-Path $VideoConfigPath) {
    $rawVideo = Get-Content -Path $VideoConfigPath -Raw -ErrorAction SilentlyContinue
    $videoConfigValid = ($rawVideo -match '"setting.shadow_enable"\s+"0"') -and ($rawVideo -match '"setting.fps_max"\s+"0"')
}

if ($videoConfigValid) {
    Write-Check -Status 'OK' -Key 'APEX_VIDEOCONFIG_WRITTEN' -Detail "$MonitorWidth x $MonitorHeight"
} else {
    Write-Check -Status 'FAIL' -Key 'APEX_VIDEOCONFIG_WRITTEN' -Detail 'Expected FPS keys missing'
}

try {
    $isReadOnly = (Get-Item -Path $VideoConfigPath -ErrorAction Stop).IsReadOnly
    if ($isReadOnly) {
        Write-Check -Status 'OK' -Key 'APEX_VIDEOCONFIG_READONLY'
    } else {
        Write-Check -Status 'FAIL' -Key 'APEX_VIDEOCONFIG_READONLY' -Detail 'Read-only flag is false'
    }
} catch {
    Write-Check -Status 'FAIL' -Key 'APEX_VIDEOCONFIG_READONLY' -Detail 'Unable to validate read-only state'
}

# -----------------------------------------------------------------------------
# SECTION 2: AUTOEXEC.CFG + EXE FLAGS
# -----------------------------------------------------------------------------

$ApexInstallPath = Find-ApexInstallPath -HintPath $env:APEX_PATH

if ([string]::IsNullOrWhiteSpace($ApexInstallPath)) {
    Write-Host "[WARN] Apex install path not found. Skipping autoexec + EXE flag steps." -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'APEX_AUTOEXEC_WRITTEN' -Detail 'Install path not found'
    Write-Check -Status 'WARN' -Key 'APEX_EXE_FLAGS' -Detail 'Install path not found'
} else {
    Write-Host "[INFO] Apex install path: $ApexInstallPath" -ForegroundColor Green

    $CfgDir = Join-Path $ApexInstallPath 'cfg'
    $AutoExecPath = Join-Path $CfgDir 'autoexec.cfg'
    if (-not (Test-Path $CfgDir)) {
        New-Item -ItemType Directory -Path $CfgDir -Force | Out-Null
    }

    if (Test-Path $AutoExecPath) {
        Backup-ConfigFile -Path $AutoExecPath | Out-Null
    }

    $AutoExecContent = @"
fps_max 0
cl_forcepreload 1
cl_interp_ratio 1
cl_interp 0.0
mat_screen_blur_enabled 0
mat_bloomscale 0
mat_bloom_scalefactor_scalar 0
mat_queue_mode 2
miles_occlusion 0
"@

    try {
        Set-Content -Path $AutoExecPath -Value $AutoExecContent -Encoding ASCII -Force -ErrorAction Stop
        Write-Host "[OK] autoexec.cfg written: $AutoExecPath" -ForegroundColor Green
        Write-Check -Status 'OK' -Key 'APEX_AUTOEXEC_WRITTEN'
    } catch {
        Write-Host "[WARN] Could not write autoexec.cfg: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Check -Status 'FAIL' -Key 'APEX_AUTOEXEC_WRITTEN' -Detail 'Write failed'
    }

    $ApexExe = Join-Path $ApexInstallPath 'r5apex.exe'
    $null = Set-ExeCompatFlags -ExePaths @($ApexExe) -CheckKey 'APEX_EXE_FLAGS' -Flags @('HIGHDPIAWARE', 'DISABLEDXMAXIMIZEDWINDOWEDMODE')
}

# -----------------------------------------------------------------------------
# SECTION 3: MANUAL SETTINGS REMINDER
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  APEX - MANUAL IN-GAME SETTINGS (IMPORTANT)" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  NVIDIA Reflex         : Enabled + Boost" -ForegroundColor White
Write-Host "  TSAA                  : ON (best target visibility for small FPS cost)" -ForegroundColor White
Write-Host "  Launch Options        : +fps_max 0 -novid -preload -high" -ForegroundColor White
Write-Host "  V-Sync                : OFF" -ForegroundColor White
Write-Host "  Adaptive Resolution   : OFF" -ForegroundColor White
Write-Host ""

if ($script:ValidationFailed) {
    Write-Host "[FAIL] Apex optimization completed with validation failures." -ForegroundColor Red
    exit 1
}

Write-Host "[DONE] Apex optimization completed successfully." -ForegroundColor Green
exit 0
