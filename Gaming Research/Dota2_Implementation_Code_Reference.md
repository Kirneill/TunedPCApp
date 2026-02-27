# Dota 2 Path Detection & Config Implementation — Code Reference

This document provides ready-to-use code snippets for your optimizer.

---

## 1. DETECT STEAM PATH (PowerShell)

```powershell
function Get-SteamInstallPath {
    <#
    .SYNOPSIS
    Retrieves the Steam installation directory from Windows registry.

    .DESCRIPTION
    Attempts to read Steam path from HKEY_LOCAL_MACHINE (primary) and
    falls back to HKEY_CURRENT_USER if needed.

    .OUTPUTS
    [System.String] Path to Steam directory (e.g., C:\Program Files (x86)\Steam)

    .EXAMPLE
    $steamPath = Get-SteamInstallPath
    #>

    # Try HKEY_LOCAL_MACHINE (most reliable)
    $steamPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" `
                                   -Name "InstallPath" `
                                   -ErrorAction SilentlyContinue).InstallPath

    # Fallback to HKEY_CURRENT_USER
    if (-not $steamPath) {
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" `
                                       -Name "SteamPath" `
                                       -ErrorAction SilentlyContinue).SteamPath
    }

    # Validate path exists
    if ($steamPath -and (Test-Path $steamPath)) {
        return $steamPath
    } else {
        throw "Steam installation not found."
    }
}

# Usage:
$steamPath = Get-SteamInstallPath
Write-Host "Steam found at: $steamPath"
```

---

## 2. DETECT DOTA 2 INSTALLATION PATH (PowerShell)

```powershell
function Find-Dota2Installation {
    <#
    .SYNOPSIS
    Locates Dota 2 (app ID 570) across all Steam library folders.

    .DESCRIPTION
    Reads libraryfolders.vdf and checks each library for the game directory.
    Also validates via appmanifest_570.acf.

    .OUTPUTS
    [System.String] Path to Dota 2 install (e.g., C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta)

    .EXAMPLE
    $dotaPath = Find-Dota2Installation
    #>

    $steamPath = Get-SteamInstallPath

    # Check default location first (common case)
    $defaultPath = Join-Path $steamPath "steamapps\common\dota 2 beta"
    if (Test-Path $defaultPath) {
        return $defaultPath
    }

    # Parse libraryfolders.vdf to find other libraries
    $libraryVdfPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"

    if (-not (Test-Path $libraryVdfPath)) {
        throw "libraryfolders.vdf not found at $libraryVdfPath"
    }

    # Read VDF file (text-based KeyValues format)
    $vdfContent = Get-Content $libraryVdfPath -Raw

    # Parse library paths using regex (simple parser)
    # Looks for patterns like: "0"  "C:\Path\To\Steam"
    $pathPattern = '".*?"\s+"([^"]+)"'
    $matches = [regex]::Matches($vdfContent, $pathPattern)

    $libraryPaths = @($steamPath)  # Always include default
    foreach ($match in $matches) {
        $path = $match.Groups[1].Value
        if ($path -and (Test-Path $path)) {
            $libraryPaths += $path
        }
    }

    # Check each library for Dota 2
    foreach ($libPath in $libraryPaths) {
        $dotaCandidate = Join-Path $libPath "steamapps\common\dota 2 beta"
        if (Test-Path $dotaCandidate) {
            return $dotaCandidate
        }

        # Also check via manifest file
        $manifestPath = Join-Path $libPath "steamapps\appmanifest_570.acf"
        if (Test-Path $manifestPath) {
            return $dotaCandidate  # Path should exist if manifest does
        }
    }

    throw "Dota 2 (app 570) not found in any Steam library."
}

# Usage:
$dotaPath = Find-Dota2Installation
Write-Host "Dota 2 found at: $dotaPath"
```

---

## 3. READ VIDEO.TXT (PowerShell with KeyValues parsing)

```powershell
function Get-VideoConfig {
    <#
    .SYNOPSIS
    Reads Dota 2 video.txt and returns settings as a hashtable.

    .DESCRIPTION
    Parses KeyValues format file from Dota 2 config directory.

    .PARAMETER DotaPath
    Path to Dota 2 installation directory.

    .OUTPUTS
    [System.Collections.Hashtable] Settings like @{ "setting.fullscreen" = "1"; ... }

    .EXAMPLE
    $config = Get-VideoConfig -DotaPath "C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta"
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$DotaPath
    )

    $videoTxtPath = Join-Path $DotaPath "game\dota\cfg\video.txt"

    if (-not (Test-Path $videoTxtPath)) {
        Write-Warning "video.txt not found at $videoTxtPath"
        return @{}
    }

    $config = @{}
    $content = Get-Content $videoTxtPath -Raw

    # Simple KeyValues parser for video.txt
    # Format: "VideoConfig" { "setting.key" "value" ... }

    $pattern = '"([^"]+)"\s+"([^"]*)"'
    $matches = [regex]::Matches($content, $pattern)

    foreach ($match in $matches) {
        $key = $match.Groups[1].Value
        $value = $match.Groups[2].Value
        if ($key -and $key -ne "VideoConfig") {  # Skip section header
            $config[$key] = $value
        }
    }

    return $config
}

# Usage:
$dotaPath = Find-Dota2Installation
$videoConfig = Get-VideoConfig -DotaPath $dotaPath
$videoConfig  # Print all settings
Write-Host "Current fullscreen mode: $($videoConfig['setting.fullscreen'])"
```

---

## 4. WRITE VIDEO.TXT (PowerShell)

```powershell
function Set-VideoConfig {
    <#
    .SYNOPSIS
    Writes optimized settings to video.txt in KeyValues format.

    .DESCRIPTION
    Overwrites video.txt with provided settings dictionary while preserving
    the KeyValues structure that Dota 2 expects.

    .PARAMETER DotaPath
    Path to Dota 2 installation directory.

    .PARAMETER Settings
    Hashtable of settings like @{ "setting.fullscreen" = "1"; ... }

    .EXAMPLE
    $optimizedSettings = @{
        "setting.fullscreen" = "1"
        "setting.mat_vsync" = "0"
        "setting.gpu_mem_level" = "0"
    }
    Set-VideoConfig -DotaPath $dotaPath -Settings $optimizedSettings
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$DotaPath,

        [Parameter(Mandatory=$true)]
        [hashtable]$Settings
    )

    $videoTxtPath = Join-Path $DotaPath "game\dota\cfg\video.txt"

    # Build KeyValues format content
    $content = '"VideoConfig"' + "`r`n" + "{`r`n"

    foreach ($key in $Settings.Keys | Sort-Object) {
        $value = $Settings[$key]
        $content += "    `"$key`"`t`"$value`"`r`n"
    }

    $content += "}`r`n"

    # Write to file
    Set-Content -Path $videoTxtPath -Value $content -Encoding UTF8 -Force
    Write-Host "video.txt updated: $videoTxtPath"
}

# Usage:
$optimizedSettings = @{
    "setting.fullscreen" = "1"
    "setting.mat_vsync" = "0"
    "setting.gpu_mem_level" = "0"
    "setting.cpu_level" = "0"
    "setting.gpu_level" = "0"
    "setting.r_screenspace_aa" = "0"
}
Set-VideoConfig -DotaPath $dotaPath -Settings $optimizedSettings
```

---

## 5. CREATE/UPDATE AUTOEXEC.CFG (PowerShell)

```powershell
function Set-AutoexecConfig {
    <#
    .SYNOPSIS
    Creates or updates autoexec.cfg with optimization commands.

    .DESCRIPTION
    Writes plaintext ConVar commands. These execute AFTER video.txt
    and override its settings. File persists across game sessions.

    .PARAMETER DotaPath
    Path to Dota 2 installation directory.

    .PARAMETER Commands
    Array of console commands (one per line).

    .PARAMETER Append
    If $true, append to existing autoexec.cfg; if $false, overwrite.

    .EXAMPLE
    $optimizationCommands = @(
        "fps_max 0"
        "engine_no_focus_sleep 0"
        "mat_vsync 0"
        "mat_queue_mode 2"
        "rate 786432"
        "cl_cmdrate 60"
        "cl_updaterate 60"
    )
    Set-AutoexecConfig -DotaPath $dotaPath -Commands $optimizationCommands -Append $false
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$DotaPath,

        [Parameter(Mandatory=$true)]
        [string[]]$Commands,

        [bool]$Append = $false
    )

    $autoexecPath = Join-Path $DotaPath "game\dota\cfg\autoexec.cfg"

    # Build content with header comment
    $content = "// === SENSEQUALITY OPTIMIZER - AUTO-GENERATED ===" + "`r`n"
    $content += "// Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
    $content += "// DO NOT EDIT - Changes will be overwritten`r`n"
    $content += "`r`n"

    foreach ($cmd in $Commands) {
        $content += "$cmd`r`n"
    }

    $content += "`r`n// === END SENSEQUALITY OPTIMIZATIONS ===" + "`r`n"

    # Write or append
    if ($Append -and (Test-Path $autoexecPath)) {
        Add-Content -Path $autoexecPath -Value ("`r`n" + $content)
        Write-Host "autoexec.cfg appended: $autoexecPath"
    } else {
        Set-Content -Path $autoexecPath -Value $content -Encoding UTF8 -Force
        Write-Host "autoexec.cfg created: $autoexecPath"
    }
}

# Usage:
$optimizationCommands = @(
    "fps_max 0",
    "engine_no_focus_sleep 0",
    "r_dynamic_lod 1",
    "mat_vsync 0",
    "mat_queue_mode 2",
    "rate 786432",
    "cl_cmdrate 60",
    "cl_updaterate 60",
    "cl_interp 0",
    "cl_interp_ratio 1"
)
Set-AutoexecConfig -DotaPath $dotaPath -Commands $optimizationCommands -Append $false
```

---

## 6. SET STEAM LAUNCH OPTIONS (PowerShell with binary VDF)

```powershell
function Set-SteamLaunchOptions {
    <#
    .SYNOPSIS
    Updates Steam launch options for Dota 2 (app 570).

    .DESCRIPTION
    Modifies the binary localconfig.vdf file. Requires vdf library or
    manual binary parsing. This is complex; consider using existing tools.

    .PARAMETER SteamPath
    Path to Steam installation directory.

    .PARAMETER LaunchOptions
    Launch options string (e.g., "-novid -high -dx11 +fps_max 0").

    .NOTES
    WARNING: Binary VDF parsing is error-prone. Backup localconfig.vdf first.
    Consider using: https://github.com/DoctorMcKay/node-vdf (Node.js)
    or Python's vdf library. Recommend users set options manually in Steam UI.

    .EXAMPLE
    Set-SteamLaunchOptions -SteamPath "C:\Program Files (x86)\Steam" `
        -LaunchOptions "-novid -high -dx11 +fps_max 0 -prewarm"
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]$SteamPath,

        [Parameter(Mandatory=$true)]
        [string]$LaunchOptions
    )

    $localconfigPath = Join-Path $SteamPath "config\localconfig.vdf"

    if (-not (Test-Path $localconfigPath)) {
        Write-Error "localconfig.vdf not found at $localconfigPath"
        return
    }

    # BACKUP FIRST (critical!)
    $backupPath = $localconfigPath + ".backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $localconfigPath -Destination $backupPath
    Write-Host "Backup created: $backupPath"

    # Read binary file
    [byte[]]$fileBytes = [System.IO.File]::ReadAllBytes($localconfigPath)

    # This is where manual VDF parsing gets very complicated
    # For production use, recommend:
    # 1. Call external Python script with vdf library
    # 2. Use Node.js vdf library
    # 3. Document: "Edit in Steam UI" as fallback

    Write-Warning "Binary VDF modification is complex. Recommend:"
    Write-Warning "  1. Use Python: pip install vdf; python -c 'import vdf; ...'"
    Write-Warning "  2. Use Node.js: npm install vdf"
    Write-Warning "  3. Or tell users to right-click Dota 2 > Properties > Launch Options"
}

# SIMPLER ALTERNATIVE: PowerShell helper to show instructions
function Get-SteamLaunchOptionsInstructions {
    @"
=== SET DOTA 2 LAUNCH OPTIONS MANUALLY ===

Binary VDF files cannot be safely edited with PowerShell. Follow these steps:

1. Open Steam Client
2. Right-click "Dota 2" in your library
3. Select "Properties"
4. In "General" tab, find "Launch Options"
5. Paste this string:
   -novid -high -dx11 +fps_max 0 -prewarm

6. Click "Close"
7. Launch Dota 2 (new options take effect)

These options will persist across game updates.
"@
}

# Usage:
Write-Host (Get-SteamLaunchOptionsInstructions)
```

---

## 7. DETECT DOTA 2 EXECUTABLE (PowerShell)

```powershell
function Get-Dota2ExecutablePath {
    <#
    .SYNOPSIS
    Returns the full path to dota2.exe.

    .OUTPUTS
    [System.String] Full path to dota2.exe

    .EXAMPLE
    $exePath = Get-Dota2ExecutablePath
    #>

    $dotaPath = Find-Dota2Installation
    $exePath = Join-Path $dotaPath "game\bin\win64\dota2.exe"

    if (Test-Path $exePath) {
        return $exePath
    } else {
        throw "dota2.exe not found at expected location: $exePath"
    }
}

# Usage:
$dota2Exe = Get-Dota2ExecutablePath
Write-Host "Dota 2 executable: $dota2Exe"
Write-Host "Process name for GPU profiles: dota2.exe"
```

---

## 8. COMPLETE OPTIMIZATION WORKFLOW (PowerShell)

```powershell
function Optimize-Dota2 {
    <#
    .SYNOPSIS
    Complete workflow: detect paths, apply video.txt, create autoexec.cfg.

    .DESCRIPTION
    End-to-end optimization for Dota 2. Handles errors gracefully.

    .PARAMETER Backup
    If $true, backup config files before modifying.

    .EXAMPLE
    Optimize-Dota2 -Backup $true
    #>

    param(
        [bool]$Backup = $true
    )

    try {
        # Step 1: Locate Dota 2
        Write-Host "Step 1: Locating Dota 2..."
        $dotaPath = Find-Dota2Installation
        Write-Host "  ✓ Found at: $dotaPath"

        # Step 2: Backup existing configs
        if ($Backup) {
            Write-Host "Step 2: Creating backups..."
            $backupDir = Join-Path $env:APPDATA "SENSEQUALITY\dota2_backups\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

            Copy-Item -Path (Join-Path $dotaPath "game\dota\cfg\video.txt") -Destination $backupDir -ErrorAction SilentlyContinue
            Copy-Item -Path (Join-Path $dotaPath "game\dota\cfg\autoexec.cfg") -Destination $backupDir -ErrorAction SilentlyContinue

            Write-Host "  ✓ Backups saved to: $backupDir"
        }

        # Step 3: Apply video.txt optimizations
        Write-Host "Step 3: Applying video.txt optimizations..."
        $videoSettings = @{
            "setting.fullscreen" = "1"
            "setting.mat_vsync" = "0"
            "setting.gpu_mem_level" = "0"
            "setting.cpu_level" = "0"
            "setting.gpu_level" = "0"
            "setting.r_screenspace_aa" = "0"
            "setting.r_renderingpipeline" = "0"
            "setting.r_ambient_occlusion" = "0"
            "setting.r_bloom_new" = "0"
            "setting.r_grass" = "0"
            "setting.mat_queue_mode" = "2"
        }
        Set-VideoConfig -DotaPath $dotaPath -Settings $videoSettings
        Write-Host "  ✓ video.txt updated"

        # Step 4: Create autoexec.cfg
        Write-Host "Step 4: Creating autoexec.cfg..."
        $autoexecCommands = @(
            "fps_max 0",
            "engine_no_focus_sleep 0",
            "mat_vsync 0",
            "mat_queue_mode 2",
            "rate 786432",
            "cl_cmdrate 60",
            "cl_updaterate 60",
            "cl_interp 0",
            "cl_interp_ratio 1"
        )
        Set-AutoexecConfig -DotaPath $dotaPath -Commands $autoexecCommands -Append $false
        Write-Host "  ✓ autoexec.cfg created"

        # Step 5: Get executable info
        Write-Host "Step 5: GPU profile setup..."
        $exePath = Get-Dota2ExecutablePath
        Write-Host "  ✓ Executable: dota2.exe (add this to NVIDIA/AMD drivers)"

        Write-Host ""
        Write-Host "=== OPTIMIZATION COMPLETE ===" -ForegroundColor Green
        Write-Host "Recommendations:"
        Write-Host "  1. Add dota2.exe to NVIDIA GeForce Experience or AMD Radeon driver profiles"
        Write-Host "  2. Set Power Management = Maximum Performance"
        Write-Host "  3. Disable Steam Cloud for Dota 2 (if you prefer local config control)"
        Write-Host "  4. Launch Dota 2 to verify settings take effect"

    } catch {
        Write-Error "Optimization failed: $_"
        return $false
    }

    return $true
}

# Usage:
Optimize-Dota2 -Backup $true
```

---

## 9. NODEJS VDF PARSING (Alternative to PowerShell)

If you prefer Node.js for VDF parsing (more reliable for binary files):

```javascript
const fs = require('fs');
const vdf = require('vdf');

// Read binary localconfig.vdf
const localconfigPath = 'C:\\Program Files (x86)\\Steam\\config\\localconfig.vdf';
const fileContent = fs.readFileSync(localconfigPath, 'utf-8');

// Parse VDF
const parsed = vdf.parse(fileContent);

// Access launch options
const launchOptions = parsed.UserLocalConfigStore
                            .Software
                            .Valve
                            .Steam
                            .Apps['570']
                            .LaunchOptions;

console.log('Current launch options:', launchOptions);

// Modify
parsed.UserLocalConfigStore.Software.Valve.Steam.Apps['570'].LaunchOptions =
    '-novid -high -dx11 +fps_max 0 -prewarm';

// Write back
const updated = vdf.stringify(parsed);
fs.writeFileSync(localconfigPath, updated, 'utf-8');

console.log('Launch options updated!');
```

Install with: `npm install vdf`

---

## 10. PYTHON VDF PARSING (Alternative)

```python
import vdf
import os

steam_path = "C:\\Program Files (x86)\\Steam"
localconfig_path = os.path.join(steam_path, "config", "localconfig.vdf")

# Read binary VDF
with open(localconfig_path, 'rb') as f:
    config = vdf.load(f, merge_duplicate_keys=False)

# Access launch options for app 570
launch_options = config['UserLocalConfigStore']['Software']['Valve']['Steam']['Apps']['570']['LaunchOptions']
print(f"Current: {launch_options}")

# Modify
config['UserLocalConfigStore']['Software']['Valve']['Steam']['Apps']['570']['LaunchOptions'] = \
    '-novid -high -dx11 +fps_max 0 -prewarm'

# Write back
with open(localconfig_path, 'wb') as f:
    vdf.dump(config, f, pretty=False)

print("Launch options updated!")
```

Install with: `pip install vdf`

---

## SUMMARY

| Task | Best Approach |
|---|---|
| Detect Steam path | PowerShell registry query (HKLM/HKCU) |
| Find Dota 2 | Parse libraryfolders.vdf + check directories |
| Modify video.txt | PowerShell text manipulation (KeyValues format) |
| Modify autoexec.cfg | PowerShell plaintext file write |
| Modify launch options | Node.js or Python with vdf library (binary VDF) |
| Get executable name | Return hardcoded "dota2.exe" for GPU profiles |
| Backup configs | PowerShell copy-item before modifications |

---

## CRITICAL REMINDERS

1. **Always backup** `video.txt` and `autoexec.cfg` before modifications
2. **Do NOT set video.txt read-only** (game needs to write to it)
3. **autoexec.cfg is safe** to keep and won't be overwritten by the game
4. **Steam Cloud** can override local configs—warn users
5. **Binary VDF files** (localconfig.vdf) require proper parsers; text editing will corrupt them
6. **Test on a clean install** before deploying to users

