#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Marathon - PC Optimization Script
    Version: 1.0 | Updated: March 2026
    Engine: Tiger Engine (Bungie)

.DESCRIPTION
    Applies Windows EXE flags and writes optimized cvars.xml for
    competitive Marathon performance. Config is set to read-only after
    writing because Marathon OVERWRITES cvars.xml on exit.

    BattlEye is Marathon's anti-cheat. Config file edits are safe.

.NOTES
    cvars.xml is XML with namespaced cvar elements. The script uses a
    read-merge-write approach: only performance keys in the "graphics"
    namespace are overridden. All other namespaces (key bindings, audio,
    gameplay) are preserved exactly as-is. Resolution, window position,
    gamma, and version fields are also preserved.

    Config key names verified against a real cvars.xml from an actual
    Marathon installation (Steam App ID 3065800).
#>

# --- SHARED ENGINE + HEADLESS MODE --------------------------------------------
. "$PSScriptRoot\SQEngine.ps1"
Initialize-SQEngine
# -----------------------------------------------------------------------------

Write-SQHeader -Title 'Marathon - Optimization Script' `
               -Subtitle 'March 2026 | Tiger Engine'

# -----------------------------------------------------------------------------
# SECTION 1: LOCATE MARATHON AND SET EXE FLAGS
# -----------------------------------------------------------------------------

$MarathonExePaths = @()

# If provided by host process, trust this first.
if (-not [string]::IsNullOrWhiteSpace($env:MARATHON_PATH)) {
    $detectedPath = $env:MARATHON_PATH
    if (Test-Path $detectedPath) {
        $MarathonExePaths += Join-Path $detectedPath "Marathon.exe"
        Write-Host "[INFO] Using host-detected Marathon path: $detectedPath" -ForegroundColor DarkCyan
    }
}

# Steam App ID: 3065800
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

# Try Steam uninstall registry for Marathon specifically
try {
    $uninstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 3065800" -ErrorAction SilentlyContinue
    if ($uninstall.InstallLocation -and (Test-Path $uninstall.InstallLocation)) {
        $MarathonExePaths += Join-Path $uninstall.InstallLocation "Marathon.exe"
    }
} catch {
    Write-Host "[WARN] Failed to read Marathon uninstall registry: $_" -ForegroundColor DarkGray
}

foreach ($sp in ($SteamPaths | Select-Object -Unique)) {
    # Direct path
    $marathonDir = Join-Path $sp "steamapps\common\Marathon"
    if (Test-Path $marathonDir) {
        $MarathonExePaths += Join-Path $marathonDir "Marathon.exe"
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
                $altMarathonDir = Join-Path $libPath "steamapps\common\Marathon"
                if (Test-Path $altMarathonDir) {
                    $MarathonExePaths += Join-Path $altMarathonDir "Marathon.exe"
                }
            }
        } catch {
            Write-Host "[WARN] Failed to parse VDF at ${vdfPath}: $_" -ForegroundColor DarkGray
        }
    }
}

if ($MarathonExePaths.Count -eq 0) {
    $MarathonExePaths = @('__placeholder_nonexistent_path__')
}

$foundCount = Set-ExeCompatFlags -ExePaths $MarathonExePaths -CheckKey 'MARATHON_EXE_FLAGS'

if ($foundCount -eq 0) {
    Write-Host "       Right-click Marathon.exe > Properties >" -ForegroundColor Yellow
    Write-Host "       Compatibility > Check 'Disable fullscreen optimizations'" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# SECTION 2: WRITE OPTIMIZED CVARS.XML
# -----------------------------------------------------------------------------
# Marathon's cvars.xml is XML with <body> > <namespace name="X"> > <cvar name="" value="" />
# Marathon OVERWRITES cvars.xml on exit, so we set read-only after writing.
#
# Strategy: read-merge-write. Parse existing XML, only override performance
# keys in the "graphics" namespace. Preserve ALL other namespaces (key bindings,
# audio, gameplay) and non-performance graphics keys (resolution, window, gamma)
# exactly as-is.
# -----------------------------------------------------------------------------

$CvarsDir = "$env:APPDATA\Bungie\Marathon\prefs"
$CvarsFile = Join-Path $CvarsDir "cvars.xml"

# Competitive performance settings -- only keys that ACTUALLY exist in the real cvars.xml
# Keys NOT in this list are preserved from the existing config (resolution, window, gamma, version)
$CompetitiveSettings = [ordered]@{
    master                        = '0'    # Custom preset
    anti_aliasing_mode            = '2'    # SMAA (universal, no DLSS dependency)
    ssao_mode                     = '0'    # Off
    ssao_async_mode               = '0'    # Off
    shadow_quality                = '1'    # Low -- still renders player shadows
    environment_detail            = '1'    # Low
    character_detail              = '2'    # Medium -- enemies stay visible
    texture_quality               = '2'    # Medium -- VRAM dependent
    texture_anisotropy_level      = '4'    # 16x -- near-zero FPS cost
    foliage_detail                = '0'    # Lowest -- competitive advantage
    local_light_shadows           = '0'    # Off
    foliage_shadows_mode          = '0'    # Off
    hdr_output                    = '0'    # Off
    atmosphere_lighting_detail    = '0'    # Low
    framerate_cap_enabled         = '0'    # Uncapped
    framerate_cap                 = '0'    # Uncapped
    target_framerate              = '0'    # Disabled
    lighting_resolution           = '0'    # Lowest
    render_resolution_scaling_mode = '0'   # Native, no upscaling
    render_resolution_percentage  = '100'  # 100% native
}

# NVIDIA Reflex: On+Boost (2) for NVIDIA GPUs, Off (0) otherwise
if ($NvidiaGPU) {
    $CompetitiveSettings['low_latency_mode'] = '2'   # Reflex On+Boost
} else {
    $CompetitiveSettings['low_latency_mode'] = '0'   # Off (non-NVIDIA)
}

# Keys in the graphics namespace that must NEVER be overridden
$PreserveKeys = @(
    'force_auto_detect',
    'force_enable_multi_threaded_render_submit',
    'window_position_x',
    'window_position_y',
    'window_mode',
    'fullscreen_resolution_width',
    'fullscreen_resolution_height',
    'fullscreen_refresh_rate_numerator',
    'fullscreen_refresh_rate_denominator',
    'windowed_resolution_width',
    'windowed_resolution_height',
    'gamma_control',
    'version'
)

try {
    if (-not (Test-Path $CvarsDir)) {
        Write-Host "[WARN] Marathon prefs directory not found: $CvarsDir" -ForegroundColor Yellow
        Write-Host "       Marathon may not have been launched yet." -ForegroundColor Yellow
        Write-Check -Status 'WARN' -Key 'MARATHON_CONFIG_WRITTEN' -Detail 'PREFS_DIR_NOT_FOUND'
    } elseif (-not (Test-Path $CvarsFile)) {
        Write-Host "[WARN] cvars.xml not found: $CvarsFile" -ForegroundColor Yellow
        Write-Host "       Launch Marathon once to generate the config, then re-run." -ForegroundColor Yellow
        Write-Check -Status 'WARN' -Key 'MARATHON_CONFIG_WRITTEN' -Detail 'CVARS_NOT_FOUND'
    } else {
        # Backup existing config
        Backup-ConfigFile -Path $CvarsFile | Out-Null

        # Remove read-only if previously locked
        Unlock-ConfigFile -Path $CvarsFile

        # Parse existing XML
        $xmlRaw = [System.IO.File]::ReadAllText($CvarsFile, [System.Text.UTF8Encoding]::new($false))
        $xml = [xml]$xmlRaw

        # Find the graphics namespace
        $graphicsNs = $xml.body.namespace | Where-Object { $_.name -eq 'graphics' }

        if (-not $graphicsNs) {
            Write-Host "[WARN] No <namespace name='graphics'> found in cvars.xml -- cannot merge settings" -ForegroundColor Yellow
            Write-Check -Status 'FAIL' -Key 'MARATHON_CONFIG_WRITTEN' -Detail 'NO_GRAPHICS_NAMESPACE'
        } else {
            # Merge competitive settings into the graphics namespace
            foreach ($key in $CompetitiveSettings.Keys) {
                # Skip if this key is in the preserve list (safety check)
                if ($key -in $PreserveKeys) { continue }

                $existingCvar = $graphicsNs.cvar | Where-Object { $_.name -eq $key }
                if ($existingCvar) {
                    # Update existing cvar value
                    $existingCvar.value = $CompetitiveSettings[$key]
                } else {
                    # Add new cvar element (key exists in reference but not in user config)
                    $newElement = $xml.CreateElement('cvar')
                    $newElement.SetAttribute('name', $key)
                    $newElement.SetAttribute('value', $CompetitiveSettings[$key])
                    # Insert as self-closing with space before />
                    $graphicsNs.AppendChild($newElement) | Out-Null
                }
            }

            # Write XML with UTF-8 no BOM
            # Use XmlWriterSettings for clean output with tabs (matching original format)
            $writerSettings = [System.Xml.XmlWriterSettings]::new()
            $writerSettings.Indent = $true
            $writerSettings.IndentChars = "`t"
            $writerSettings.Encoding = [System.Text.UTF8Encoding]::new($false)
            $writerSettings.OmitXmlDeclaration = $false

            $stringWriter = [System.IO.StringWriter]::new()
            $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $writerSettings)
            $xml.Save($xmlWriter)
            $xmlWriter.Flush()
            $xmlWriter.Close()

            $xmlOutput = $stringWriter.ToString()
            [System.IO.File]::WriteAllText($CvarsFile, $xmlOutput, [System.Text.UTF8Encoding]::new($false))

            Write-Host "  [OK] cvars.xml written: $CvarsFile" -ForegroundColor Green

            # Lock read-only to prevent Marathon from overwriting on exit
            Lock-ConfigFile -Path $CvarsFile
            Write-Host "  [OK] cvars.xml locked read-only (Marathon overwrites on exit)" -ForegroundColor Green

            Write-Check -Status 'OK' -Key 'MARATHON_CONFIG_WRITTEN'
        }
    }
} catch {
    Write-Host "[FAIL] Failed to write cvars.xml: $_" -ForegroundColor Red
    Write-Check -Status 'FAIL' -Key 'MARATHON_CONFIG_WRITTEN' -Detail $_.Exception.Message
}

# -----------------------------------------------------------------------------
# SECTION 3: PRINT FULL IN-GAME SETTINGS GUIDE
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  MARATHON - COMPLETE SETTINGS GUIDE" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow

Write-Host ""
Write-Host "  --- DISPLAY SETTINGS (Preserved from your config) ---" -ForegroundColor Cyan
Write-Host "  Window Mode            : Keep your current setting" -ForegroundColor White
Write-Host "  Resolution             : Keep your current setting" -ForegroundColor White
Write-Host "  Render Resolution      : 100% Native (no upscaling)" -ForegroundColor White
Write-Host "  HDR                    : Off" -ForegroundColor White
Write-Host "  FPS Cap                : Uncapped (0)" -ForegroundColor White

Write-Host ""
Write-Host "  --- GRAPHICS (Applied via cvars.xml) ---" -ForegroundColor Cyan
Write-Host "  Master Preset          : Custom (0)" -ForegroundColor White
Write-Host "  Anti-Aliasing          : SMAA (2)" -ForegroundColor White
Write-Host "  SSAO                   : Off" -ForegroundColor White
Write-Host "  Shadow Quality         : Low (player shadows visible)" -ForegroundColor White
Write-Host "  Environment Detail     : Low" -ForegroundColor White
Write-Host "  Character Detail       : Medium (enemy visibility)" -ForegroundColor White
Write-Host "  Texture Quality        : Medium" -ForegroundColor White
Write-Host "  Texture Anisotropy     : 16x (near-zero FPS cost)" -ForegroundColor White
Write-Host "  Foliage Detail         : Lowest" -ForegroundColor White
Write-Host "  Foliage Shadows        : Off" -ForegroundColor White
Write-Host "  Local Light Shadows    : Off" -ForegroundColor White
Write-Host "  Atmosphere Lighting    : Low" -ForegroundColor White
Write-Host "  Lighting Resolution    : Lowest" -ForegroundColor White

Write-Host ""
Write-Host "  --- LATENCY ---" -ForegroundColor Cyan
if ($NvidiaGPU) {
    Write-Host "  NVIDIA Reflex          : On+Boost (2)" -ForegroundColor White
} else {
    Write-Host "  Low Latency Mode       : Off (non-NVIDIA GPU)" -ForegroundColor White
}
Write-Host "  Render Resolution Mode : Native (no upscaling)" -ForegroundColor White

Write-Host ""
Write-Host "  --- NOTES ---" -ForegroundColor Cyan
Write-Host "  - cvars.xml is locked read-only to preserve settings" -ForegroundColor DarkGray
Write-Host "  - Marathon overwrites cvars.xml on exit without this lock" -ForegroundColor DarkGray
Write-Host "  - To change settings later, remove read-only flag first:" -ForegroundColor DarkGray
Write-Host "    attrib -R `"$CvarsFile`"" -ForegroundColor DarkGray
Write-Host "  - Key bindings, audio, and gameplay settings are preserved" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[DONE] Marathon cvars.xml written + EXE flags applied." -ForegroundColor Green
if (-not $script:ValidationFailed) {
    Write-Check -Status 'OK' -Key 'MARATHON_SETTINGS_APPLIED'
} else {
    Write-Check -Status 'WARN' -Key 'MARATHON_SETTINGS_APPLIED' -Detail 'PARTIAL'
}
Write-Host ""
