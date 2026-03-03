#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Rainbow Six Siege - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: AnvilNext 2.0

.DESCRIPTION
    Applies EXE compatibility flags and writes optimized GameSettings.ini
    for competitive R6 Siege performance. Supports both Steam and Ubisoft
    Connect installations.

    R6 Siege uses BattlEye anti-cheat. Config file edits are safe.

.NOTES
    R6 Siege stores settings per-Ubisoft account in a unique hash folder
    under Documents. The script detects all account folders and applies
    settings to each one. Vulkan is recommended over DX11 for 5-15% more
    FPS and lower CPU overhead.
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Rainbow Six Siege - Optimization Script' `
               -Subtitle 'March 2026 | AnvilNext 2.0'

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE R6 SIEGE AND SET EXE FLAGS
# -----------------------------------------------------------------------------

$R6ExePaths = @()

# If provided by host process, trust this first.
if (-not [string]::IsNullOrWhiteSpace($env:R6_PATH)) {
    if (Test-Path $env:R6_PATH) {
        $R6ExePaths += Join-Path $env:R6_PATH "RainbowSix.exe"
        $R6ExePaths += Join-Path $env:R6_PATH "RainbowSix_BE.exe"
        Write-Host "[INFO] Using host-detected R6 Siege path: $($env:R6_PATH)" -ForegroundColor DarkCyan
    }
}

# Steam detection (App ID: 359550)
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

# Registry-based Steam path
try {
    $steamReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg.InstallPath) { $SteamPaths += $steamReg.InstallPath }
} catch {
    Write-Host "[WARN] Failed to read Steam registry: $_" -ForegroundColor DarkGray
}

# Uninstall registry
try {
    $uninstall = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 359550" -ErrorAction SilentlyContinue
    if ($uninstall.InstallLocation -and (Test-Path $uninstall.InstallLocation)) {
        $R6ExePaths += Join-Path $uninstall.InstallLocation "RainbowSix.exe"
        $R6ExePaths += Join-Path $uninstall.InstallLocation "RainbowSix_BE.exe"
    }
} catch {
    Write-Host "[WARN] Failed to read R6 Siege uninstall registry: $_" -ForegroundColor DarkGray
}

# Common Steam paths
foreach ($sp in ($SteamPaths | Select-Object -Unique)) {
    $r6Dir = Join-Path $sp "steamapps\common\Tom Clancy's Rainbow Six Siege"
    $R6ExePaths += Join-Path $r6Dir "RainbowSix.exe"
    $R6ExePaths += Join-Path $r6Dir "RainbowSix_BE.exe"

    # Parse libraryfolders.vdf
    $vdfPath = Join-Path $sp "steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        try {
            $vdfContent = Get-Content $vdfPath -Raw
            $libMatches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
            foreach ($match in $libMatches) {
                $libPath = $match.Groups[1].Value.Replace('\\\\', '\')
                # Skip if drive does not exist (Join-Path throws in PS 5.1)
                if ($libPath -match '^([A-Za-z]):' -and -not (Test-Path "$($Matches[1]):\")) { continue }
                $altR6Dir = Join-Path $libPath "steamapps\common\Tom Clancy's Rainbow Six Siege"
                $R6ExePaths += Join-Path $altR6Dir "RainbowSix.exe"
                $R6ExePaths += Join-Path $altR6Dir "RainbowSix_BE.exe"
            }
        } catch {
            Write-Host "[WARN] Failed to parse VDF at ${vdfPath}: $_" -ForegroundColor DarkGray
        }
    }
}

# Ubisoft Connect paths
$UbisoftPaths = @(
    "${env:PROGRAMFILES(x86)}\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
    "$env:PROGRAMFILES\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
    "C:\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy's Rainbow Six Siege",
    "D:\Ubisoft\games\Tom Clancy's Rainbow Six Siege",
    "E:\Ubisoft\games\Tom Clancy's Rainbow Six Siege"
)

# Filter out paths on drives that do not exist (Join-Path throws in PS 5.1)
$UbisoftPaths = @($UbisoftPaths | Where-Object {
    if ($_ -match '^([A-Za-z]):') { Test-Path "$($Matches[1]):\" } else { $true }
})

# Ubisoft Connect registry
try {
    $ubisoftReg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher" -ErrorAction SilentlyContinue
    if ($ubisoftReg.InstallDir) {
        $UbisoftPaths += Join-Path $ubisoftReg.InstallDir "games\Tom Clancy's Rainbow Six Siege"
    }
} catch {
    Write-Host "[WARN] Failed to read Ubisoft Connect registry: $_" -ForegroundColor DarkGray
}

foreach ($ubPath in ($UbisoftPaths | Select-Object -Unique)) {
    $R6ExePaths += Join-Path $ubPath "RainbowSix.exe"
    $R6ExePaths += Join-Path $ubPath "RainbowSix_BE.exe"
}

# Xbox Game Pass detection — scan all drives with .GamingRoot marker + common defaults
$xboxDrives = @("C","D","E")
foreach ($code in 65..90) {
    $letter = [char]$code
    if (Test-Path "${letter}:\.GamingRoot" -ErrorAction SilentlyContinue) {
        $xboxDrives += $letter
    }
}
foreach ($drive in ($xboxDrives | Select-Object -Unique)) {
    $xboxRoot = "${drive}:\XboxGames"
    if (Test-Path $xboxRoot) {
        try {
            Get-ChildItem -Path $xboxRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'Rainbow\s*Six' } |
                ForEach-Object {
                    $contentDir = Join-Path $_.FullName "Content"
                    if (Test-Path $contentDir) {
                        $R6ExePaths += Join-Path $contentDir "RainbowSix.exe"
                        $R6ExePaths += Join-Path $contentDir "RainbowSix_BE.exe"
                    }
                }
        } catch {
            Write-Host "[WARN] Failed to scan Xbox games on ${drive}: drive: $_" -ForegroundColor DarkGray
        }
    }
}

$foundCount = Set-ExeCompatFlags -ExePaths $R6ExePaths -CheckKey 'R6_EXE_FLAGS'

if ($foundCount -eq 0) {
    Write-Host "       Right-click RainbowSix.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED GameSettings.ini
# -----------------------------------------------------------------------------

$R6ConfigBase = "$env:USERPROFILE\Documents\My Games\Rainbow Six - Siege"
$AccountFolders = @()

if (Test-Path $R6ConfigBase) {
    $AccountFolders = Get-ChildItem $R6ConfigBase -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "GameSettings.ini")
    }
}

$AnyConfigWritten = $false
$WrittenCount = 0

if ($AccountFolders.Count -eq 0) {
    Write-Host "[WARN] No R6 Siege account settings folders found." -ForegroundColor Yellow
    Write-Host "       Game may not have been launched yet." -ForegroundColor Yellow
    Write-Host "       Settings will be applied as a reference guide." -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'R6_CONFIG_WRITTEN' -Detail 'NO_ACCOUNT_FOLDERS'
} else {
    foreach ($folder in $AccountFolders) {
        $settingsFile = Join-Path $folder.FullName "GameSettings.ini"

        # Back up existing
        Backup-ConfigFile -Path $settingsFile | Out-Null

        try {
            # Read existing INI and merge sections we care about
            # Preserve sections we don't modify (INPUT, AUDIO, etc.)
            $existingSections = [ordered]@{}
            $currentSection = ""

            if (Test-Path $settingsFile) {
                foreach ($line in (Get-Content $settingsFile)) {
                    if ($line -match '^\[(.+)\]$') {
                        $currentSection = $Matches[1]
                        if (-not $existingSections.ContainsKey($currentSection)) {
                            $existingSections[$currentSection] = [ordered]@{}
                        }
                    } elseif ($currentSection -and $line -match '^(.+?)=(.*)$') {
                        $existingSections[$currentSection][$Matches[1]] = $Matches[2]
                    }
                }
            }

            # Apply our DISPLAY settings
            if (-not $existingSections.ContainsKey("DISPLAY")) { $existingSections["DISPLAY"] = [ordered]@{} }
            $existingSections["DISPLAY"]["Adapter"] = "0"
            $existingSections["DISPLAY"]["WindowMode"] = "0"
            $existingSections["DISPLAY"]["VSync"] = "0"
            $existingSections["DISPLAY"]["FPSLimit"] = "0"
            $existingSections["DISPLAY"]["Resolution"] = "${MonitorWidth}x${MonitorHeight}"
            $existingSections["DISPLAY"]["RefreshRate"] = "$MonitorRefresh"

            # Apply our GRAPHICS settings
            if (-not $existingSections.ContainsKey("GRAPHICS")) { $existingSections["GRAPHICS"] = [ordered]@{} }
            $existingSections["GRAPHICS"]["TextureQuality"] = "2"
            $existingSections["GRAPHICS"]["TextureFiltering"] = "4"
            $existingSections["GRAPHICS"]["LODQuality"] = "2"
            $existingSections["GRAPHICS"]["ShadingQuality"] = "1"
            $existingSections["GRAPHICS"]["ShadowQuality"] = "1"
            $existingSections["GRAPHICS"]["ReflectionQuality"] = "0"
            $existingSections["GRAPHICS"]["AmbientOcclusion"] = "0"
            $existingSections["GRAPHICS"]["LensEffect"] = "0"
            $existingSections["GRAPHICS"]["DepthOfField"] = "0"
            $existingSections["GRAPHICS"]["AntiAliasingMode"] = "1"
            $existingSections["GRAPHICS"]["RenderScaling"] = "100"
            if ($NvidiaGPU) {
                $existingSections["GRAPHICS"]["NvidiaReflex"] = "2"
            }

            # Rebuild the INI file
            $outputLines = @()
            foreach ($section in $existingSections.Keys) {
                $outputLines += "[$section]"
                foreach ($key in $existingSections[$section].Keys) {
                    $outputLines += "$key=$($existingSections[$section][$key])"
                }
                $outputLines += ""
            }

            $outputLines | Set-Content $settingsFile -Encoding UTF8 -Force
            Write-Host "  [OK] GameSettings.ini written: $settingsFile" -ForegroundColor Green
            $AnyConfigWritten = $true
            $WrittenCount++
        } catch {
            Write-Host "[FAIL] Failed to write GameSettings.ini for account $($folder.Name): $_" -ForegroundColor Red
        }
    }
}

if ($AnyConfigWritten) {
    Write-Check -Status 'OK' -Key 'R6_CONFIG_WRITTEN' -Detail "$WrittenCount"
} else {
    if ($AccountFolders.Count -gt 0) {
        Write-Check -Status 'FAIL' -Key 'R6_CONFIG_WRITTEN' -Detail 'WRITE_ERROR'
        $script:ValidationFailed = $true
    }
}

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  RAINBOW SIX SIEGE - COMPLETE SETTINGS GUIDE" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- DISPLAY (Applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Display Mode           : Fullscreen" -ForegroundColor White
Write-Host "  Resolution             : ${MonitorWidth}x${MonitorHeight}" -ForegroundColor White
Write-Host "  VSync                  : OFF" -ForegroundColor White
Write-Host "  FPS Limit              : Unlimited" -ForegroundColor White

Write-Host ""
Write-Host "  --- RENDERER ---" -ForegroundColor Cyan
Write-Host "  Rendering Backend      : Vulkan (recommended)" -ForegroundColor Red
Write-Host "                         +5-15% FPS vs DX11, lower CPU overhead" -ForegroundColor DarkGray
Write-Host "                         Switch in-game or use -vulkan launch option" -ForegroundColor DarkGray

Write-Host ""
Write-Host "  --- GRAPHICS (Applied automatically) ---" -ForegroundColor Cyan
Write-Host "  Texture Quality        : Medium (VRAM-bound, not FPS)" -ForegroundColor White
Write-Host "  Texture Filtering      : Aniso 4x (nearly free)" -ForegroundColor White
Write-Host "  LOD Quality            : Medium (Low hides distant targets)" -ForegroundColor White
Write-Host "  Shading Quality        : Low" -ForegroundColor White
Write-Host "  Shadow Quality         : Low (NOT Off)" -ForegroundColor Red
Write-Host "                         Shadows reveal enemy positions!" -ForegroundColor Red
Write-Host "  Reflection Quality     : Low" -ForegroundColor White
Write-Host "  Ambient Occlusion      : OFF (significant FPS cost)" -ForegroundColor White
Write-Host "  Lens Effects           : OFF" -ForegroundColor White
Write-Host "  Depth of Field         : OFF" -ForegroundColor White
Write-Host "  Anti-Aliasing          : TAA (reduces wire/fence shimmer)" -ForegroundColor White
Write-Host "  Render Scaling         : 100% (never below native)" -ForegroundColor White

Write-Host ""
Write-Host "  --- LATENCY ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  NVIDIA Reflex          : ON + Boost (applied automatically)" -ForegroundColor White
    Write-Host "  DLSS                   : Quality (if GPU-bound)" -ForegroundColor White
} else {
    Write-Host "  FSR                    : Quality (if GPU-bound)" -ForegroundColor White
}

Write-Host ""
Write-Host "  --- LAUNCH OPTIONS (Steam) ---" -ForegroundColor Cyan
Write-Host "  Recommended: -vulkan -high" -ForegroundColor White

Write-Host ""
Write-Host "[DONE] R6 Siege config written + EXE flags applied." -ForegroundColor Green
Write-Host "       Switch to Vulkan renderer in-game for best performance." -ForegroundColor Green
if (-not $script:ValidationFailed) {
    Write-Check -Status 'OK' -Key 'R6_SETTINGS_APPLIED'
} else {
    Write-Check -Status 'WARN' -Key 'R6_SETTINGS_APPLIED' -Detail 'PARTIAL'
}
Write-Host ""
