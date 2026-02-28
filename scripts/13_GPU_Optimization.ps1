<#
.SYNOPSIS
    Applies GPU driver profile optimizations.

.DESCRIPTION
    NVIDIA: Uses nvidiaProfileInspector + sq_competitive.nip import.
             If the tool is missing, it is auto-downloaded.
    AMD: Placeholder path (not implemented yet in this script).
#>

$ErrorActionPreference = 'Stop'

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FAIL', 'WARN')] [string]$Status,
        [Parameter(Mandatory = $true)] [string]$Key,
        [string]$Detail = ''
    )

    $suffix = ''
    if ($Detail) {
        $safeDetail = $Detail -replace '[\r\n]+', ' ' -replace '\s+', ' '
        $suffix = ":$safeDetail"
    }

    Write-Host "[SQ_CHECK_${Status}:$Key$suffix]"
}

function Resolve-ToolsRoot {
    if ($env:GPU_TOOLS_PATH) {
        return $env:GPU_TOOLS_PATH
    }

    return (Join-Path $env:ProgramData 'SENSEQUALITY\tools')
}

function Resolve-BundledToolsRoot {
    if ($env:GPU_BUNDLED_TOOLS_PATH -and (Test-Path $env:GPU_BUNDLED_TOOLS_PATH)) {
        return $env:GPU_BUNDLED_TOOLS_PATH
    }

    $candidates = @(
        (Join-Path $PSScriptRoot '..\tools'),
        (Join-Path $PSScriptRoot '..\resources\tools')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)] [string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Ensure-ProfilePreset {
    param(
        [Parameter(Mandatory = $true)] [string]$ToolsRoot,
        [string]$BundledToolsRoot
    )

    $profileFile = Join-Path $ToolsRoot 'sq_competitive.nip'

    if ($BundledToolsRoot) {
        $bundledProfile = Join-Path $BundledToolsRoot 'sq_competitive.nip'
        if (Test-Path $bundledProfile) {
            Copy-Item -Path $bundledProfile -Destination $profileFile -Force
            Write-Host "[INFO] Synced GPU preset from bundled resources."
            Write-Check -Status 'OK' -Key 'GPU_PROFILE_PRESET_READY' -Detail $profileFile
            return $profileFile
        }
    }

    if (Test-Path $profileFile) {
        Write-Check -Status 'OK' -Key 'GPU_PROFILE_PRESET_READY' -Detail $profileFile
        return $profileFile
    }

    Write-Host "[SQ_FAIL:GPU_PROFILE]"
    Write-Check -Status 'FAIL' -Key 'GPU_PROFILE_PRESET_MISSING' -Detail "Missing sq_competitive.nip"
    throw "sq_competitive.nip not found in writable or bundled tools path."
}

function Ensure-NvidiaProfileInspector {
    param([Parameter(Mandatory = $true)] [string]$ToolsRoot)

    $inspectorExe = Join-Path $ToolsRoot 'nvidiaProfileInspector.exe'
    if (Test-Path $inspectorExe) {
        Write-Check -Status 'OK' -Key 'GPU_PROFILE_TOOL_READY' -Detail $inspectorExe
        return $inspectorExe
    }

    $downloadUrl = if ($env:GPU_NPI_DOWNLOAD_URL) {
        $env:GPU_NPI_DOWNLOAD_URL
    } else {
        'https://github.com/Orbmu2k/nvidiaProfileInspector/releases/latest/download/nvidiaProfileInspector.zip'
    }

    $downloadDir = Join-Path $env:TEMP 'SENSEQUALITY-GPU'
    $zipPath = Join-Path $downloadDir 'nvidiaProfileInspector.zip'
    $extractDir = Join-Path $downloadDir ("extract-{0}" -f [Guid]::NewGuid().ToString('N'))

    Ensure-Directory -Path $downloadDir
    Ensure-Directory -Path $extractDir

    try {
        Write-Host "[INFO] Downloading nvidiaProfileInspector (first-time setup)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $foundExe = Get-ChildItem -Path $extractDir -Filter 'nvidiaProfileInspector.exe' -Recurse -File | Select-Object -First 1

        if (-not $foundExe) {
            throw 'Downloaded archive did not contain nvidiaProfileInspector.exe.'
        }

        Copy-Item -Path $foundExe.FullName -Destination $inspectorExe -Force
        Write-Check -Status 'OK' -Key 'GPU_PROFILE_TOOL_DOWNLOADED' -Detail $inspectorExe
        Write-Check -Status 'OK' -Key 'GPU_PROFILE_TOOL_READY' -Detail $inspectorExe
        return $inspectorExe
    } catch {
        $msg = $_.Exception.Message
        Write-Host "[SQ_FAIL:GPU_PROFILE]"
        Write-Check -Status 'FAIL' -Key 'GPU_PROFILE_TOOL_DOWNLOAD_FAILED' -Detail $msg
        Write-Check -Status 'FAIL' -Key 'GPU_PROFILE_TOOL_MISSING' -Detail 'Unable to auto-download nvidiaProfileInspector.exe'
        throw "Failed to acquire nvidiaProfileInspector.exe. $msg"
    } finally {
        try { Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Invoke-ProcessOrThrow {
    param(
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string[]]$Arguments,
        [Parameter(Mandatory = $true)] [string]$StageName,
        [int]$TimeoutSeconds = 45
    )

    $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) {
        try { $proc.Kill() } catch {}
        throw "$StageName timed out after $TimeoutSeconds seconds."
    }

    if ($proc.ExitCode -ne 0) {
        throw "$StageName failed (exit code $($proc.ExitCode))."
    }
}

$IsNvidia = $env:NVIDIA_GPU -eq '1'

if (-not $IsNvidia) {
    Write-Host "[INFO] AMD/other GPU detected. Automated AMD profile path is not implemented yet."
    Write-Check -Status 'WARN' -Key 'GPU_PROFILE_AMD_NOT_IMPLEMENTED' -Detail 'No automated changes applied'
    Write-Host "[SQ_OK:GPU_PROFILE]"
    exit 0
}

$toolsRoot = Resolve-ToolsRoot
$bundledToolsRoot = Resolve-BundledToolsRoot
Ensure-Directory -Path $toolsRoot

Write-Host "[INFO] Writable GPU tools path: $toolsRoot"
if ($bundledToolsRoot) {
    Write-Host "[INFO] Bundled GPU tools path: $bundledToolsRoot"
}

$profileFile = Ensure-ProfilePreset -ToolsRoot $toolsRoot -BundledToolsRoot $bundledToolsRoot
$inspectorExe = Ensure-NvidiaProfileInspector -ToolsRoot $toolsRoot

$backupDir = Join-Path $env:ProgramData 'SENSEQUALITY\GPUProfileBackups'
$backupStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDir ("nvidia-drs-backup-{0}" -f $backupStamp)

try {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    $drsDir = Join-Path $env:ProgramData 'NVIDIA Corporation\Drs'
    $drsDb0 = Join-Path $drsDir 'nvdrsdb0.bin'
    $drsDb1 = Join-Path $drsDir 'nvdrsdb1.bin'

    if ((Test-Path $drsDb0) -and (Test-Path $drsDb1)) {
        Copy-Item -Path $drsDb0 -Destination (Join-Path $backupPath 'nvdrsdb0.bin') -Force
        Copy-Item -Path $drsDb1 -Destination (Join-Path $backupPath 'nvdrsdb1.bin') -Force
        Write-Host "[INFO] Backed up NVIDIA DRS database to $backupPath"
        Write-Check -Status 'OK' -Key 'GPU_PROFILE_BACKUP_CREATED' -Detail $backupPath
    } else {
        Write-Check -Status 'WARN' -Key 'GPU_PROFILE_BACKUP_SKIPPED' -Detail 'NVIDIA DRS database files not found'
    }
} catch {
    $msg = $_.Exception.Message
    Write-Check -Status 'WARN' -Key 'GPU_PROFILE_BACKUP_SKIPPED' -Detail $msg
}

Write-Host "[INFO] Applying NVIDIA competitive profile preset..."
Invoke-ProcessOrThrow -FilePath $inspectorExe -Arguments @($profileFile, '-silent') -StageName 'Profile import'

Write-Host "[SQ_OK:GPU_PROFILE]"
Write-Check -Status 'OK' -Key 'GPU_PROFILE_APPLIED'
Write-Check -Status 'OK' -Key 'GPU_PROFILE_POWER_MODE' -Detail 'Prefer Maximum Performance requested in profile preset'
Write-Check -Status 'OK' -Key 'GPU_PROFILE_TEXTURE_FILTER_QUALITY' -Detail 'High Performance requested in profile preset'
Write-Host "[INFO] Done. Restart running games so new driver settings are picked up."
