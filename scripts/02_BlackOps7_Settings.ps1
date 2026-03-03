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
    This script sets Windows-layer optimizations and performs byte-for-byte
    BO7 template file replacement from BO7BACKUP into the active players folder.
    It intentionally avoids in-place text rewrites to preserve exact template bytes.

    Optimal Settings Reference (February 2026 - IW Engine):
    - These settings tested across RTX 3060 to RTX 4090 tier hardware
    - Anti-cheat safe: only OS-level registry flags and user config files modified
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine

if (-not $Headless) { Clear-Host }
Write-SQHeader -Title 'Call of Duty: Black Ops 7 - Optimization Script' `
               -Subtitle 'February 2026 | IW Engine | Ricochet Anti-Cheat'

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE BLACK OPS 7 EXECUTABLE
# -----------------------------------------------------------------------------

$PossiblePaths = @(
    # Legacy executable naming
    "C:\Program Files (x86)\Call of Duty\BlackOps7.exe",
    "C:\Program Files\Call of Duty\BlackOps7.exe",
    "D:\Call of Duty\BlackOps7.exe",
    "E:\Call of Duty\BlackOps7.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty HQ\BlackOps7.exe",
    # COD HQ / Battle.net executable naming
    "C:\Program Files (x86)\Call of Duty\_retail_\cod.exe",
    "C:\Program Files (x86)\Call of Duty\_retail_\cod24\cod24-cod.exe",
    "C:\Program Files (x86)\Call of Duty\_retail_\cod25\cod25-cod.exe",
    "C:\Program Files\Call of Duty\_retail_\cod.exe",
    "C:\Program Files\Call of Duty\_retail_\cod24\cod24-cod.exe",
    "C:\Program Files\Call of Duty\_retail_\cod25\cod25-cod.exe",
    "D:\Call of Duty\_retail_\cod.exe",
    "D:\Call of Duty\_retail_\cod24\cod24-cod.exe",
    "D:\Call of Duty\_retail_\cod25\cod25-cod.exe",
    "E:\Call of Duty\_retail_\cod.exe",
    "E:\Call of Duty\_retail_\cod24\cod24-cod.exe",
    "E:\Call of Duty\_retail_\cod25\cod25-cod.exe",
    # Steam COD HQ executable naming
    "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty HQ\cod.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty HQ\cod24\cod24-cod.exe",
    "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty HQ\cod25\cod25-cod.exe",
    "D:\Steam\steamapps\common\Call of Duty HQ\cod.exe",
    "D:\Steam\steamapps\common\Call of Duty HQ\cod24\cod24-cod.exe",
    "D:\Steam\steamapps\common\Call of Duty HQ\cod25\cod25-cod.exe",
    "D:\SteamLibrary\steamapps\common\Call of Duty HQ\cod.exe",
    "D:\SteamLibrary\steamapps\common\Call of Duty HQ\cod24\cod24-cod.exe",
    "D:\SteamLibrary\steamapps\common\Call of Duty HQ\cod25\cod25-cod.exe",
    "E:\Steam\steamapps\common\Call of Duty HQ\cod.exe",
    "E:\Steam\steamapps\common\Call of Duty HQ\cod24\cod24-cod.exe",
    "E:\Steam\steamapps\common\Call of Duty HQ\cod25\cod25-cod.exe",
    "E:\SteamLibrary\steamapps\common\Call of Duty HQ\cod.exe",
    "E:\SteamLibrary\steamapps\common\Call of Duty HQ\cod24\cod24-cod.exe",
    "E:\SteamLibrary\steamapps\common\Call of Duty HQ\cod25\cod25-cod.exe",
    # Xbox Game Pass executable naming
    "C:\XboxGames\Call of Duty\Content\cod.exe",
    "C:\XboxGames\Call of Duty\Content\cod24\cod24-cod.exe",
    "C:\XboxGames\Call of Duty\Content\cod25\cod25-cod.exe",
    "C:\XboxGames\Call of Duty_1\Content\cod.exe",
    "C:\XboxGames\Call of Duty_1\Content\cod24\cod24-cod.exe",
    "C:\XboxGames\Call of Duty_1\Content\cod25\cod25-cod.exe",
    "D:\XboxGames\Call of Duty\Content\cod.exe",
    "D:\XboxGames\Call of Duty\Content\cod24\cod24-cod.exe",
    "D:\XboxGames\Call of Duty\Content\cod25\cod25-cod.exe",
    "D:\XboxGames\Call of Duty_1\Content\cod.exe",
    "D:\XboxGames\Call of Duty_1\Content\cod24\cod24-cod.exe",
    "D:\XboxGames\Call of Duty_1\Content\cod25\cod25-cod.exe",
    "E:\XboxGames\Call of Duty\Content\cod.exe",
    "E:\XboxGames\Call of Duty\Content\cod24\cod24-cod.exe",
    "E:\XboxGames\Call of Duty\Content\cod25\cod25-cod.exe",
    "E:\XboxGames\Call of Duty_1\Content\cod.exe",
    "E:\XboxGames\Call of Duty_1\Content\cod24\cod24-cod.exe",
    "E:\XboxGames\Call of Duty_1\Content\cod25\cod25-cod.exe"
)

$GameExe = $null
foreach ($path in $PossiblePaths) {
    if (Test-Path $path) {
        $GameExe = $path
        break
    }
}

if (-not $GameExe) {
    $XboxRoots = @("C:\XboxGames", "D:\XboxGames", "E:\XboxGames")
    foreach ($XboxRoot in $XboxRoots) {
        if (-not (Test-Path $XboxRoot)) { continue }

        $InstallDirs = Get-ChildItem -Path $XboxRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Call of Duty*' }
        foreach ($InstallDir in $InstallDirs) {
            $DynamicCandidates = @(
                (Join-Path $InstallDir.FullName "Content\cod.exe"),
                (Join-Path $InstallDir.FullName "Content\cod24\cod24-cod.exe"),
                (Join-Path $InstallDir.FullName "Content\cod25\cod25-cod.exe"),
                (Join-Path $InstallDir.FullName "Content\_retail_\cod.exe"),
                (Join-Path $InstallDir.FullName "Content\_retail_\cod24\cod24-cod.exe"),
                (Join-Path $InstallDir.FullName "Content\_retail_\cod25\cod25-cod.exe")
            )

            foreach ($DynamicPath in $DynamicCandidates) {
                if (Test-Path $DynamicPath) {
                    $GameExe = $DynamicPath
                    break
                }
            }

            if ($GameExe) { break }
        }

        if ($GameExe) { break }
    }
}

if (-not $GameExe) {
    Write-Host "[WARN] BO7/COD executable not found in common locations." -ForegroundColor Yellow
    Write-Host "       Skipping EXE compatibility flags." -ForegroundColor Yellow
    Write-Host "       If installed in a custom location, set EXE flags manually:" -ForegroundColor Yellow
    Write-Host "       Right-click cod.exe (or codXX-cod.exe) > Properties > Compatibility >" -ForegroundColor Yellow
    Write-Host "       Enable High DPI override for the executable" -ForegroundColor Yellow
    Write-Check -Status 'WARN' -Key 'COD_EXE_FLAGS' -Detail 'No BO7/COD executable found in known paths'
} else {
    Write-Host "[INFO] Found Black Ops 7 at: $GameExe" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # SECTION 2: EXE COMPATIBILITY FLAGS (Safe, OS-Level Only)
    # WHY: Applies safe Windows compatibility flags for BO7.
    #      High DPI override prevents scaling artifacts.
    #      Theme disabling avoids extra OS visual injection overhead.
    # -------------------------------------------------------------------------

    # DISABLETHEMES: Prevents Windows from injecting visual theme DLL into the process
    # HIGHDPIAWARE: Lets game handle DPI rather than Windows scaling it
    $null = Set-ExeCompatFlags -ExePaths @($GameExe) -CheckKey 'COD_EXE_FLAGS' -Flags @('DISABLETHEMES', 'HIGHDPIAWARE')
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
# SECTION 5: RESTORE BO7 PLAYER FILES FROM BACKUP TEMPLATES
# WHY: Match manual file-copy behavior exactly.
#      Replace files byte-for-byte and avoid Set-Content rewrites.
# -----------------------------------------------------------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $ScriptRoot "BO7BACKUP"
$PlayersDirs = @()
$PlayersDirs += (Join-Path $env:LOCALAPPDATA "Activision\Call of Duty\players")

# Also target Xbox install-local players folders (Game Pass installs).
$XboxRoots = @("C:\XboxGames", "D:\XboxGames", "E:\XboxGames")
foreach ($XboxRoot in $XboxRoots) {
    if (-not (Test-Path $XboxRoot)) { continue }

    $InstallDirs = Get-ChildItem -Path $XboxRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Call of Duty*' }

    foreach ($InstallDir in $InstallDirs) {
        $XboxPlayersCandidate = Join-Path $InstallDir.FullName "Content\Call of Duty\players"
        $XboxPlayersParent = Split-Path -Parent $XboxPlayersCandidate

        if (Test-Path $XboxPlayersParent) {
            $PlayersDirs += $XboxPlayersCandidate
        }
    }
}

$PlayersDirs = $PlayersDirs | Select-Object -Unique
$RequiredCodFiles = @(
    's.1.0.cod25.txt0',
    's.1.0.cod25.txt1',
    's.1.0.cod25.m'
)
$RequiredCodCopyFailures = @()

if (-not (Test-Path $BackupDir)) {
    Write-Host "[WARN] BO7 backup folder not found: $BackupDir" -ForegroundColor Yellow
    Write-Host "       Skipping player config replacement." -ForegroundColor Yellow
    Write-Check -Status 'FAIL' -Key 'COD_CONFIG_FILES_COPIED' -Detail 'BO7BACKUP folder missing'
    Write-Check -Status 'WARN' -Key 'COD_RENDERER_WORKER_COUNT' -Detail 'Skipped to preserve template bytes'
} else {
    Write-Host "[INFO] BO7 players targets:" -ForegroundColor Cyan
    foreach ($PlayersDir in $PlayersDirs) {
        Write-Host "  - $PlayersDir" -ForegroundColor Cyan
    }
    Write-Host "[INFO] Restoring BO7 template files (.txt0, .txt1, .m) byte-for-byte..." -ForegroundColor Cyan

    foreach ($PlayersDir in $PlayersDirs) {
        if (-not (Test-Path $PlayersDir)) {
            New-Item -ItemType Directory -Path $PlayersDir -Force | Out-Null
        }

        foreach ($RequiredFile in $RequiredCodFiles) {
            $SourcePath = Join-Path $BackupDir $RequiredFile
            $DestinationPath = Join-Path $PlayersDir $RequiredFile

            if (-not (Test-Path $SourcePath)) {
                $RequiredCodCopyFailures += "$PlayersDir -> $RequiredFile -> Required template missing in BO7BACKUP"
                Write-Host "  [WARN] Missing backup template: $RequiredFile" -ForegroundColor Yellow
                continue
            }

            try {
                if (Test-Path $DestinationPath) {
                    Set-ItemProperty -Path $DestinationPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                    Remove-Item -Path $DestinationPath -Force -ErrorAction Stop
                }

                Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop

                $SourceHash = (Get-FileHash -Path $SourcePath -Algorithm SHA256 -ErrorAction Stop).Hash
                $DestinationHash = (Get-FileHash -Path $DestinationPath -Algorithm SHA256 -ErrorAction Stop).Hash

                if ($SourceHash -eq $DestinationHash) {
                    Write-Host "  [OK] Replaced $RequiredFile in $PlayersDir and verified destination hash." -ForegroundColor Green
                } else {
                    $RequiredCodCopyFailures += "$PlayersDir -> $RequiredFile -> Hash mismatch after copy"
                    Write-Host "  [WARN] $RequiredFile copied to $PlayersDir but hash mismatch detected." -ForegroundColor Yellow
                }
            } catch {
                $RequiredCodCopyFailures += "$PlayersDir -> $RequiredFile -> Copy failed: $($_.Exception.Message)"
                Write-Host "  [WARN] Failed to replace $RequiredFile in ${PlayersDir}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    if ($RequiredCodCopyFailures.Count -eq 0) {
        Write-Check -Status 'OK' -Key 'COD_CONFIG_FILES_COPIED' -Detail ".txt0/.txt1/.m replaced byte-for-byte in $($PlayersDirs.Count) players folder(s)"
    } else {
        Write-Check -Status 'FAIL' -Key 'COD_CONFIG_FILES_COPIED' -Detail ($RequiredCodCopyFailures -join '; ')
    }

    Write-Check -Status 'WARN' -Key 'COD_RENDERER_WORKER_COUNT' -Detail 'Skipped to preserve template bytes'
}

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
