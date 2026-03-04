<#
.SYNOPSIS
    SENSEQUALITY shared engine module for game optimization scripts.

.DESCRIPTION
    Provides common functions used by all game optimization scripts:
    Initialize-SQEngine, Write-Check, Write-SQHeader, Set-ExeCompatFlags,
    Backup-ConfigFile, Lock-ConfigFile, Unlock-ConfigFile, Get-FrameRateLimit.

    Usage -- dot-source from any game script:
        . "$PSScriptRoot\SQEngine.ps1"
        Initialize-SQEngine

    Dot-sourcing shares the caller's scope, so $script: variables set by
    Initialize-SQEngine are directly accessible in the game script.
#>

# =============================================================================
# Initialize-SQEngine
# =============================================================================
function Initialize-SQEngine {
    <#
    .SYNOPSIS
        Initializes headless mode variables from environment variables.
    .DESCRIPTION
        Sets $script:Headless, $script:MonitorWidth, $script:MonitorHeight,
        $script:MonitorRefresh, $script:NvidiaGPU, and $script:ValidationFailed
        in the calling script's scope (shared via dot-sourcing).
    #>
    $script:Headless = $env:SENSEQUALITY_HEADLESS -eq "1"
    $script:ValidationFailed = $false

    if ($script:Headless -and $env:MONITOR_WIDTH) {
        $script:MonitorWidth   = [int]$env:MONITOR_WIDTH
        $script:MonitorHeight  = [int]$env:MONITOR_HEIGHT
        $script:MonitorRefresh = [int]$env:MONITOR_REFRESH
        $script:NvidiaGPU      = $env:NVIDIA_GPU -eq '1'
    } else {
        $script:MonitorWidth   = 1920
        $script:MonitorHeight  = 1080
        $script:MonitorRefresh = 240
        $script:NvidiaGPU      = $true
    }
}

# =============================================================================
# Write-Check
# =============================================================================
function Write-Check {
    <#
    .SYNOPSIS
        Emits a structured [SQ_CHECK_OK/WARN/FAIL:KEY] marker.
    .DESCRIPTION
        These markers are parsed by handlers.ts for per-setting status reporting.
        Sets $script:ValidationFailed to $true when Status is FAIL.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('OK', 'FAIL', 'WARN')][string]$Status,
        [Parameter(Mandatory)][string]$Key,
        [string]$Detail = ''
    )

    # Collapse newlines in Detail to prevent multi-line markers
    if ($Detail) { $Detail = $Detail -replace '[\r\n]+', ' ' }

    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { '' } else { ":$Detail" }
    Write-Host "[SQ_CHECK_${Status}:$Key$suffix]"

    if ($Status -eq 'FAIL') {
        $script:ValidationFailed = $true
    }
}

# =============================================================================
# Write-SQHeader
# =============================================================================
function Write-SQHeader {
    <#
    .SYNOPSIS
        Prints the standard cyan optimization banner at script start.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Subtitle = ''
    )

    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    if ($Subtitle) { Write-Host "  $Subtitle" -ForegroundColor Cyan }
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""
}

# =============================================================================
# Set-ExeCompatFlags
# =============================================================================
function Set-ExeCompatFlags {
    <#
    .SYNOPSIS
        Sets Windows AppCompatFlags for game executables.
    .DESCRIPTION
        Loops through candidate EXE paths, sets the specified compatibility
        flags for each found executable, and emits a SQ_CHECK marker.
    .PARAMETER ExePaths
        Array of candidate EXE file paths to check.
    .PARAMETER CheckKey
        The SQ_CHECK key to emit (e.g., 'COD_EXE_FLAGS').
    .PARAMETER Flags
        Array of flag strings. Defaults to HIGHDPIAWARE + DISABLEFULLSCREENOPTIMIZATIONS.
    .OUTPUTS
        [int] Number of executables found and flagged.
    #>
    param(
        [Parameter(Mandatory)][string[]]$ExePaths,
        [Parameter(Mandatory)][string]$CheckKey,
        [string[]]$Flags = @('HIGHDPIAWARE', 'DISABLEFULLSCREENOPTIMIZATIONS')
    )

    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

    $flagValue = "~ $($Flags -join ' ')"
    $foundCount = 0

    try {
        foreach ($exePath in ($ExePaths | Select-Object -Unique)) {
            if (Test-Path $exePath) {
                Set-ItemProperty -Path $regPath -Name $exePath -Value $flagValue -Type String -Force
                Write-Host "  [OK] EXE flags set for: $exePath" -ForegroundColor Green
                $foundCount++
            }
        }

        if ($foundCount -gt 0) {
            Write-Check -Status 'OK' -Key $CheckKey -Detail ($Flags -join ' + ')
        } else {
            Write-Check -Status 'WARN' -Key $CheckKey -Detail 'EXE_NOT_FOUND'
        }
    } catch {
        Write-Check -Status 'FAIL' -Key $CheckKey -Detail $_.Exception.Message
    }

    return $foundCount
}

# =============================================================================
# Backup-ConfigFile
# =============================================================================
function Backup-ConfigFile {
    <#
    .SYNOPSIS
        Creates a timestamped backup of a config file.
    .DESCRIPTION
        Removes read-only flag if set, copies the file with a timestamp suffix.
        Returns the backup path on success, $null on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }

    try {
        Set-ItemProperty -Path $Path -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
        $backupPath = "$Path.bak_$timestamp"
        Copy-Item -Path $Path -Destination $backupPath -Force -ErrorAction Stop
        Write-Host "[BACKUP] Backed up to: $backupPath" -ForegroundColor Yellow
        return $backupPath
    } catch {
        Write-Host "[WARN] Could not back up ${Path}: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# =============================================================================
# Lock-ConfigFile / Unlock-ConfigFile
# =============================================================================
function Lock-ConfigFile {
    <#
    .SYNOPSIS
        Sets a config file to read-only to prevent the game from overwriting it.
    #>
    param([Parameter(Mandatory)][string]$Path)
    try {
        Set-ItemProperty -Path $Path -Name IsReadOnly -Value $true -ErrorAction Stop
    } catch {
        Write-Host "[WARN] Could not set read-only on ${Path}: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Unlock-ConfigFile {
    <#
    .SYNOPSIS
        Removes the read-only flag from a config file.
    #>
    param([Parameter(Mandatory)][string]$Path)
    Set-ItemProperty -Path $Path -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
}

# =============================================================================
# Get-FrameRateLimit
# =============================================================================
function Get-FrameRateLimit {
    <#
    .SYNOPSIS
        Returns the FPS limit for competitive play.
    .DESCRIPTION
        Always returns 0 (uncapped). Higher FPS = lower input latency
        even above monitor refresh rate. Players who want a cap should
        set it in-game or via NVIDIA Control Panel.
    #>
    param([int]$RefreshRate = $script:MonitorRefresh)

    return 0
}
