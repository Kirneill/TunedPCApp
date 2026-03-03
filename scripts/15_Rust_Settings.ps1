#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Rust - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Unity (HDRP)

.DESCRIPTION
    Writes an optimized client.cfg for competitive Rust performance.
    Applies EXE compatibility flags and sets client.cfg to read-only
    to prevent in-game overwriting.

    Rust uses EasyAntiCheat. Config file edits are safe.
    Target executable for GPU profiles: RustClient.exe (NOT Rust.exe).

.NOTES
    Rust does NOT support autoexec.cfg natively. All settings go into
    client.cfg which is read on startup. Setting read-only preserves
    manual edits but prevents in-game settings from saving.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Rust - Optimization Script' `
               -Subtitle 'March 2026 | Unity HDRP'

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE RUST AND SET EXE FLAGS
# -----------------------------------------------------------------------------


$RustRootFromHost = $null

# If provided by host process, trust this first.
if (-not [string]::IsNullOrWhiteSpace($env:RUST_PATH)) {
    if (Test-Path $env:RUST_PATH) {
        $RustRootFromHost = $env:RUST_PATH
        Write-Host "[INFO] Using host-detected Rust path: $RustRootFromHost" -ForegroundColor DarkCyan
    }
}

# Steam App ID: 252490
$SteamPaths = @(
    "${env:PROGRAMFILES(x86)}\Steam",
    "$env:PROGRAMFILES\Steam",
    "C:\Steam",
    "C:\SteamLibrary",
    "D:\Steam",
    "D:\SteamLibrary",
    "E:\Steam",
    "E:\SteamLibrary"
)

# Filter out paths on drives that do not exist (Join-Path throws in PS 5.1)
$SteamPaths = @($SteamPaths | Where-Object {
    if ($_ -match '^([A-Za-z]):') { Test-Path "$($Matches[1]):\" } else { $true }
})

# Also try registry
try {
    $steamReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg.InstallPath) { $SteamPaths += $steamReg.InstallPath }
} catch {
    Write-Host "[WARN] Failed to read Steam HKLM registry: $_" -ForegroundColor DarkGray
}
try {
    $steamRegUser = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamRegUser.SteamPath) { $SteamPaths += $steamRegUser.SteamPath.Replace('/', '\') }
} catch {
    Write-Host "[WARN] Failed to read Steam HKCU registry: $_" -ForegroundColor DarkGray
}

# Try uninstall registry
try {
    $uninstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 252490" -ErrorAction SilentlyContinue
    if ($uninstall.InstallLocation -and (Test-Path $uninstall.InstallLocation)) {
        $SteamPaths += (Split-Path (Split-Path (Split-Path $uninstall.InstallLocation)))
    }
} catch {
    Write-Host "[WARN] Failed to read Rust uninstall registry: $_" -ForegroundColor DarkGray
}

$RustExePaths = @()
$RustCfgPaths = @()

# Add host-detected path first (highest priority)
if ($RustRootFromHost) {
    $RustExePaths += Join-Path $RustRootFromHost "RustClient.exe"
    $hostCfgDir = Join-Path $RustRootFromHost "cfg"
    if (Test-Path $hostCfgDir) { $RustCfgPaths += $hostCfgDir }
}

foreach ($sp in ($SteamPaths | Select-Object -Unique)) {
    # Direct path
    $rustDir = Join-Path $sp "steamapps\common\Rust"
    if (Test-Path $rustDir) {
        $RustExePaths += Join-Path $rustDir "RustClient.exe"
        $cfgDir = Join-Path $rustDir "cfg"
        if (Test-Path $cfgDir) { $RustCfgPaths += $cfgDir }
    }

    # Parse libraryfolders.vdf for alternate libraries
    $vdfPath = Join-Path $sp "steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        try {
            $vdfContent = Get-Content $vdfPath -Raw
            $libMatches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
            foreach ($match in $libMatches) {
                $libPath = $match.Groups[1].Value.Replace('\\\\', '\')
                # Skip if drive does not exist (Join-Path throws in PS 5.1)
                if ($libPath -match '^([A-Za-z]):' -and -not (Test-Path "$($Matches[1]):\")) { continue }
                $altRustDir = Join-Path $libPath "steamapps\common\Rust"
                if (Test-Path $altRustDir) {
                    $RustExePaths += Join-Path $altRustDir "RustClient.exe"
                    $altCfgDir = Join-Path $altRustDir "cfg"
                    if (Test-Path $altCfgDir) { $RustCfgPaths += $altCfgDir }
                }
            }
        } catch {
            Write-Host "[WARN] Failed to parse VDF at ${vdfPath}: $_" -ForegroundColor DarkGray
        }
    }
}

$foundCount = Set-ExeCompatFlags -ExePaths $RustExePaths -CheckKey 'RUST_EXE_FLAGS'

if ($foundCount -eq 0) {
    Write-Host "       Right-click RustClient.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED client.cfg
# -----------------------------------------------------------------------------

# Rust client.cfg format: convar.name "value" — one per line
$RustConfig = @'
graphics.shadowdistance "50"
graphics.shadowcascades "1"
graphics.shadowlights "0"
graphics.drawdistance "1500"
graphics.fov "90"
graphics.shader "200"
graphics.meshquality "50"
graphics.texturequality "0"
graphics.af "1"
graphics.parallax "0"
graphics.terrain "1"
graphics.grass "0"
graphics.decor "0"
graphics.treequality "50"
graphics.maxtreemeshes "100"
graphics.water "0"
graphics.object "0"
graphics.particle "0"
graphics.aa "0"
graphics.bloom "0"
graphics.dof "0"
graphics.ao "0"
graphics.motionblur "0"
graphics.shafts "0"
graphics.contactshadows "0"
graphics.tssaa "0"
graphics.dlss "0"
graphics.fsr "0"
fps.limit "0"
gc.buffer "2048"
gc.incremental_enabled "true"
gc.incremental_milliseconds "2"
'@

$AnyConfigWritten = $false

if ($RustCfgPaths.Count -eq 0) {
    Write-Host "[WARN] Rust cfg directory not found. Game may not be installed." -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'RUST_CONFIG_WRITTEN' -Detail 'CFG_DIR_NOT_FOUND'
} else {
    foreach ($cfgDir in ($RustCfgPaths | Select-Object -Unique)) {
        $clientCfg = Join-Path $cfgDir "client.cfg"

        if (Test-Path $clientCfg) {
            Backup-ConfigFile -Path $clientCfg | Out-Null
        }

        try {
            # Read existing config and merge (preserve non-graphics settings)
            $configMap = [ordered]@{}
            if (Test-Path $clientCfg) {
                foreach ($line in (Get-Content $clientCfg)) {
                    if ($line -match '^(\S+)\s+"?([^"]*)"?$') {
                        $configMap[$Matches[1]] = $Matches[2]
                    }
                }
            }

            # Apply our competitive settings (overwrite matching keys)
            foreach ($line in ($RustConfig -split "`n")) {
                $line = $line.Trim()
                if ($line -match '^(\S+)\s+"([^"]*)"$') {
                    $configMap[$Matches[1]] = $Matches[2]
                }
            }

            # Write back
            $output = foreach ($key in $configMap.Keys) { '{0} "{1}"' -f $key, $configMap[$key] }
            $output | Set-Content $clientCfg -Encoding UTF8 -Force

            # Lock read-only to prevent in-game overwriting
            Lock-ConfigFile -Path $clientCfg

            Write-Host "  [OK] client.cfg written and locked (read-only): $clientCfg" -ForegroundColor Green
            $AnyConfigWritten = $true
        } catch {
            Write-Host "[FAIL] Failed to write client.cfg at $cfgDir : $_" -ForegroundColor Red
        }
    }
}

if ($AnyConfigWritten) {
    Write-Check -Status 'OK' -Key 'RUST_CONFIG_WRITTEN'
} else {
    if ($RustCfgPaths.Count -gt 0) {
        Write-Check -Status 'FAIL' -Key 'RUST_CONFIG_WRITTEN' -Detail 'WRITE_ERROR'
    }
}

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  RUST - COMPLETE SETTINGS GUIDE" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- LAUNCH OPTIONS (Steam) ---" -ForegroundColor Cyan
Write-Host "  Recommended: -window-mode exclusive -high -force-d3d11" -ForegroundColor White
Write-Host "  Optional   : -malloc=system -maxMem=16384 -cpuCount=8" -ForegroundColor White
Write-Host "  DO NOT USE : -force-vulkan (unstable in Rust)" -ForegroundColor Red

Write-Host ""
Write-Host "  --- CLIENT.CFG (Applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Shadow Distance        : 50 (competitive sweet spot)" -ForegroundColor White
Write-Host "  Shadow Cascades        : 1" -ForegroundColor White
Write-Host "  Shadow Lights          : 0 (no dynamic light shadows)" -ForegroundColor White
Write-Host "  Draw Distance          : 1500 (min for seeing players)" -ForegroundColor White
Write-Host "  FOV                    : 90 (max)" -ForegroundColor White
Write-Host "  Shader Level           : 200 (lowest usable)" -ForegroundColor White
Write-Host "  Grass                  : 0 (huge FPS gain)" -ForegroundColor White
Write-Host "  Tree Quality           : 50" -ForegroundColor White
Write-Host "  Water Quality          : 0 (simple)" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF" -ForegroundColor White
Write-Host "  Motion Blur            : OFF" -ForegroundColor White
Write-Host "  GC Buffer              : 2048 (reduces stutter)" -ForegroundColor White

Write-Host ""
Write-Host "  --- UPSCALING ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  DLSS                   : Balanced (if GPU-bound)" -ForegroundColor White
    Write-Host "  Note: If CPU-bound, DLSS will not help" -ForegroundColor DarkGray
} else {
    Write-Host "  FSR                    : Balanced (if GPU-bound)" -ForegroundColor White
    Write-Host "  Note: If CPU-bound, FSR will not help" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  --- NOTES ---" -ForegroundColor Cyan
Write-Host "  - client.cfg is locked read-only to preserve settings" -ForegroundColor DarkGray
Write-Host "  - To change settings later, remove read-only flag first" -ForegroundColor DarkGray
Write-Host "  - Some servers force grass rendering for fairness" -ForegroundColor DarkGray
Write-Host "  - Monthly wipe updates may change rendering behavior" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[DONE] Rust config written + EXE flags applied." -ForegroundColor Green
if (-not $script:ValidationFailed) {
    Write-Check -Status 'OK' -Key 'RUST_SETTINGS_APPLIED'
} else {
    Write-Check -Status 'WARN' -Key 'RUST_SETTINGS_APPLIED' -Detail 'PARTIAL'
}
Write-Host ""
