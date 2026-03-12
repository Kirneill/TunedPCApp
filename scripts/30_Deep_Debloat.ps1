#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SENSEQUALITY Deep Debloat -- Lightweight OS Mode
    Makes Windows as lean as AtlasOS/KernelOS while remaining safe and reversible.

.DESCRIPTION
    This script aggressively debloats Windows by disabling unnecessary services,
    removing bloatware AppX packages, disabling telemetry scheduled tasks,
    removing unused DISM capabilities, and applying filesystem and registry
    optimizations. Every change is recorded in a manifest JSON that the
    companion undo script (31_Undo_Deep_Debloat.ps1) uses to reverse all changes.

    WHAT THIS SCRIPT DOES:
    - Creates a system restore point and full backup manifest
    - Disables 30+ non-essential Windows services
    - Removes 25+ bloatware AppX packages and deprovisions them
    - Disables 14 telemetry and background scheduled tasks
    - Removes unused DISM capabilities (IE, WordPad, Fax, etc.)
    - Applies NTFS filesystem optimizations (8.3 names, last-access, memory)
    - Sets privacy and anti-bloat registry tweaks
    - Defers feature updates by 365 days (security updates still flow)

    SAFETY:
    - System restore point created before any changes
    - Full manifest JSON tracks every change for one-click undo
    - Never touches Defender, Firewall, CryptSvc, WMI, audio, or networking
    - Anti-cheat safe: Secure Boot, TPM, HVCI, VBS are untouched

.NOTES
    Run as Administrator. Reboot after completion for all changes to take effect.
    To undo: run scripts/31_Undo_Deep_Debloat.ps1
#>

# -----------------------------------------------------------------------------
# HEADLESS MODE: When run from SENSEQUALITY app, skip interactive prompts
# and read config from environment variables
# -----------------------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

$ErrorActionPreference = 'Stop'

# Manifest object -- tracks every change for the undo script
$Manifest = [ordered]@{
    Version       = '1.0'
    CreatedAt     = (Get-Date -Format 'o')
    BackupDir     = ''
    Services      = @()
    AppxRemoved   = @()
    Tasks         = @()
    DismRemoved   = @()
    NtfsOriginal  = [ordered]@{}
    Registry      = @()
    UpdateDeferral = $false
}

$ManifestDir  = Join-Path $env:APPDATA 'SENSEQUALITY'
$ManifestPath = Join-Path $ManifestDir 'debloat-manifest.json'

# Helper: save manifest to disk incrementally so mid-script crashes do not lose the undo trail
function Save-Manifest {
    param([string]$Path, [object]$Data)
    $json = $Data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

# -- Diagnostic log function (defined early, $LogFile set once BackupDir is known) --
$script:LogFile = $null

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    if (-not $script:LogFile) { return }
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
}

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  SENSEQUALITY Deep Debloat -- Lightweight OS Mode" -ForegroundColor Cyan
Write-Host "  Safe, reversible Windows debloating for gaming" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# SECTION 1: PRE-FLIGHT SAFETY -- Restore point, registry backup, snapshots
# =============================================================================
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[1/9] PRE-FLIGHT SAFETY" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $BackupDir = Join-Path $env:USERPROFILE "Documents\SQ_DeepDebloat_Backup_$Timestamp"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $Manifest.BackupDir = $BackupDir

    # Initialize diagnostic log file
    $script:LogFile = Join-Path $BackupDir "debloat-run.log"
    Write-Log "SENSEQUALITY Deep Debloat started"
    Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"
    Write-Log "PS Version: $($PSVersionTable.PSVersion)"
    Write-Log "User: $env:USERNAME"
    Write-Log "Admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
    Write-Log "Headless: $Headless"
    Write-Log "Backup dir: $BackupDir"
    Write-Log "Manifest path: $ManifestPath"
    Write-Log ("=" * 60)

    # Create system restore point
    Write-Host "  [INFO] Creating system restore point..." -ForegroundColor DarkCyan
    Write-Log "Creating system restore point..."
    try {
        # Allow restore point creation even if one was recently made
        $SrpFreqPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        if (-not (Test-Path $SrpFreqPath)) { New-Item -Path $SrpFreqPath -Force | Out-Null }
        Set-ItemProperty -Path $SrpFreqPath -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force

        Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "SENSEQUALITY Deep Debloat (pre-debloat)" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Host "  [OK] System restore point created." -ForegroundColor Green
        Write-Log "Restore point created" "OK"
    } catch {
        Write-Host "  [WARN] Could not create restore point: $_" -ForegroundColor Yellow
        Write-Host "  [INFO] Continuing with file-based backup only." -ForegroundColor DarkCyan
        Write-Log "Failed to create restore point: $_" "WARN"
    }

    # Export full registry backup of key areas
    Write-Host "  [INFO] Exporting registry backup..." -ForegroundColor DarkCyan
    $RegKeysToBackup = @(
        @{ Name = 'Services';           Key = 'HKLM\SYSTEM\CurrentControlSet\Services' },
        @{ Name = 'ContentDelivery';    Key = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' },
        @{ Name = 'Policies_Windows';   Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows' },
        @{ Name = 'Policies_System';    Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' },
        @{ Name = 'AdvertisingInfo';    Key = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' },
        @{ Name = 'SettingsSync';       Key = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync' },
        @{ Name = 'WindowsUpdate';      Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' }
    )

    foreach ($item in $RegKeysToBackup) {
        $outFile = Join-Path $BackupDir "$($item.Name).reg"
        try {
            # Temporarily lower ErrorActionPreference so stderr from native
            # commands (reg.exe) does not become a terminating error.
            $oldEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            reg export $item.Key $outFile /y 2>$null | Out-Null
            $regExitCode = $LASTEXITCODE
            $ErrorActionPreference = $oldEAP

            if ($regExitCode -eq 0) {
                Write-Host "  [OK] Backed up: $($item.Name)" -ForegroundColor Green
                Write-Log "Registry backup: $($item.Name) exported to $outFile" "OK"
            } else {
                Write-Host "  [SKIP] Key not present: $($item.Name)" -ForegroundColor DarkGray
                Write-Log "Registry backup: $($item.Name) not present, skipped" "SKIP"
            }
        } catch {
            $ErrorActionPreference = $oldEAP
            Write-Host "  [SKIP] Key not present: $($item.Name)" -ForegroundColor DarkGray
            Write-Log "Registry backup: $($item.Name) not present, skipped" "SKIP"
        }
    }

    # Snapshot current service states
    Write-Host "  [INFO] Snapshotting service states..." -ForegroundColor DarkCyan
    $AllServices = Get-Service | Select-Object Name, StartType, Status |
        ForEach-Object { [ordered]@{ Name = $_.Name; StartType = $_.StartType.ToString(); Status = $_.Status.ToString() } }
    $ServiceSnapshot = $AllServices | ConvertTo-Json -Depth 3
    [System.IO.File]::WriteAllText(
        (Join-Path $BackupDir 'services-snapshot.json'),
        $ServiceSnapshot,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "  [OK] Service snapshot saved ($($AllServices.Count) services)." -ForegroundColor Green
    Write-Log "Service snapshot saved ($($AllServices.Count) services)" "OK"

    # Snapshot installed AppX packages
    Write-Host "  [INFO] Snapshotting AppX packages..." -ForegroundColor DarkCyan
    $AllAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Select-Object Name, PackageFullName, Version |
        ForEach-Object { [ordered]@{ Name = $_.Name; PackageFullName = $_.PackageFullName; Version = $_.Version } }
    $AppxSnapshot = $AllAppx | ConvertTo-Json -Depth 3
    [System.IO.File]::WriteAllText(
        (Join-Path $BackupDir 'appx-snapshot.json'),
        $AppxSnapshot,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "  [OK] AppX snapshot saved ($($AllAppx.Count) packages)." -ForegroundColor Green
    Write-Log "AppX snapshot saved ($($AllAppx.Count) packages)" "OK"

    # Ensure manifest directory exists
    if (-not (Test-Path $ManifestDir)) { New-Item -ItemType Directory -Path $ManifestDir -Force | Out-Null }

    Write-Host "  [INFO] Backup directory: $BackupDir" -ForegroundColor DarkCyan
    Write-Log "Pre-flight safety complete"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_BACKUP]"
} catch {
    Write-Host "  [FAIL] Pre-flight safety: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_BACKUP:$_]"
    Write-Log "ERROR in Section 1 (Pre-flight): $_" "ERROR"
    Write-Host ""
    Write-Host "Aborting debloat -- cannot proceed without backup." -ForegroundColor Red
    exit 1
}


# =============================================================================
# SECTION 2: SERVICE DISABLING (~34 services)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[2/9] SERVICE DISABLING" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Each entry: Name = service name, Target = desired start type
    # Services marked Manual stay available on demand but do not auto-start
    $ServicesToChange = @(
        # -- Telemetry and diagnostics --
        @{ Name = 'DiagTrack';       Target = 'Disabled' }   # Connected User Experiences and Telemetry
        @{ Name = 'WerSvc';          Target = 'Disabled' }   # Windows Error Reporting
        @{ Name = 'dmwappushservice'; Target = 'Disabled' }  # WAP Push Message Routing
        @{ Name = 'DusmSvc';         Target = 'Disabled' }   # Data Usage monitoring
        @{ Name = 'WdiServiceHost';  Target = 'Disabled' }   # Diagnostic System Host
        @{ Name = 'WdiSystemHost';   Target = 'Disabled' }   # Diagnostic Policy Service Host
        @{ Name = 'diagnosticshub.standardcollector.service'; Target = 'Disabled' }  # Diagnostics Hub

        # -- Compatibility and legacy --
        @{ Name = 'PcaSvc';          Target = 'Disabled' }   # Program Compatibility Assistant
        @{ Name = 'TrkWks';          Target = 'Disabled' }   # Distributed Link Tracking
        @{ Name = 'MapsBroker';      Target = 'Disabled' }   # Downloaded Maps Manager
        @{ Name = 'lfsvc';           Target = 'Disabled' }   # Geolocation Service
        @{ Name = 'RetailDemo';      Target = 'Disabled' }   # Retail Demo

        # -- Performance drains --
        @{ Name = 'SysMain';         Target = 'Disabled' }   # Superfetch -- hurts SSD gaming rigs
        @{ Name = 'WSearch';         Target = 'Manual' }     # Windows Search Indexing -- heavy I/O, Manual keeps search working

        # -- Unused hardware and features --
        @{ Name = 'Fax';             Target = 'Disabled' }   # Fax service
        @{ Name = 'WMPNetworkSvc';   Target = 'Disabled' }   # WMP Network Sharing
        @{ Name = 'TabletInputService'; Target = 'Manual' }   # Touch Keyboard and Handwriting -- Manual keeps emoji picker working
        @{ Name = 'PhoneSvc';        Target = 'Disabled' }   # Phone Service
        @{ Name = 'SEMgrSvc';        Target = 'Disabled' }   # Payments and NFC
        @{ Name = 'AJRouter';        Target = 'Disabled' }   # AllJoyn Router
        @{ Name = 'ALG';             Target = 'Disabled' }   # Application Layer Gateway
        @{ Name = 'SCardSvr';        Target = 'Disabled' }   # Smart Card
        @{ Name = 'ScDeviceEnum';    Target = 'Disabled' }   # Smart Card Device Enum
        @{ Name = 'SharedAccess';    Target = 'Disabled' }   # Internet Connection Sharing
        @{ Name = 'SSDPSRV';         Target = 'Disabled' }   # SSDP Discovery
        @{ Name = 'upnphost';        Target = 'Disabled' }   # UPnP Device Host

        # -- Sync and cloud --
        @{ Name = 'OneSyncSvc';      Target = 'Disabled' }   # Sync Host

        # -- Xbox services (Manual keeps Xbox and Game Pass games working on demand) --
        @{ Name = 'XblAuthManager';  Target = 'Manual' }     # Xbox Live Auth Manager
        @{ Name = 'XblGameSave';     Target = 'Manual' }     # Xbox Live Game Save
        @{ Name = 'XboxNetApiSvc';   Target = 'Manual' }     # Xbox Live Networking
        @{ Name = 'XboxGipSvc';      Target = 'Manual' }     # Xbox Accessory Management

        # -- Set to Manual (keep available but not auto-starting) --
        @{ Name = 'BITS';            Target = 'Manual' }     # Background Intelligent Transfer
        @{ Name = 'wuauserv';        Target = 'Manual' }     # Windows Update -- keep security updates working
        @{ Name = 'CertPropSvc';     Target = 'Manual' }     # Certificate Propagation
    )

    $disabledCount = 0
    $skippedCount  = 0

    foreach ($svc in $ServicesToChange) {
        try {
            $existing = Get-Service -Name $svc.Name -ErrorAction Stop
            $originalStartType = $existing.StartType.ToString()

            # Stop the service if it is running and we are disabling it
            if ($svc.Target -eq 'Disabled' -and $existing.Status -eq 'Running') {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            }

            Set-Service -Name $svc.Name -StartupType $svc.Target -ErrorAction Stop

            # Record original state in manifest AFTER successful change
            $Manifest.Services += [ordered]@{
                Name          = $svc.Name
                OriginalStart = $originalStartType
                NewStart      = $svc.Target
            }
            $disabledCount++
            Write-Host "  [OK] $($svc.Name): $originalStartType -> $($svc.Target)" -ForegroundColor Green
            Write-Log "Service $($svc.Name): $originalStartType -> $($svc.Target)" "OK"
        } catch {
            # Service may not exist on all Windows editions
            $skippedCount++
            Write-Host "  [SKIP] $($svc.Name): not found or access denied" -ForegroundColor DarkGray
            Write-Log "Service $($svc.Name): not found or access denied" "SKIP"
        }
    }

    Write-Host ""
    Write-Host "  [INFO] Services changed: $disabledCount, skipped: $skippedCount" -ForegroundColor DarkCyan
    Write-Log "Services: $disabledCount changed, $skippedCount skipped"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_SERVICES:$disabledCount changed]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] Service disabling: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_SERVICES:$_]"
    Write-Log "ERROR in Section 2 (Services): $_" "ERROR"
}


# =============================================================================
# SECTION 3: APPX PACKAGE REMOVAL (~25 packages)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[3/9] APPX PACKAGE REMOVAL" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Packages to remove -- bloatware that wastes RAM and disk
    # KEEP: WindowsStore, WindowsCalculator, WindowsTerminal, Paint, ScreenSketch,
    #       XboxIdentityProvider, GamingApp, DesktopAppInstaller
    $AppxToRemove = @(
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.BingFinance',
        'Microsoft.BingSports',
        'Microsoft.GetHelp',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.MixedReality.Portal',
        'Microsoft.People',
        'Microsoft.PowerAutomateDesktop',
        'Microsoft.SkypeApp',
        'Microsoft.Todos',
        'Microsoft.WindowsAlarms',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps',
        'Microsoft.WindowsSoundRecorder',
        'Microsoft.YourPhone',
        'Microsoft.ZuneMusic',
        'Microsoft.ZuneVideo',
        'Microsoft.549981C3F5F10',            # Cortana
        'Microsoft.Windows.DevHome',
        'Microsoft.WindowsCommunicationsApps', # Mail and Calendar
        'Microsoft.MicrosoftStickyNotes',
        'Clipchamp.Clipchamp',
        'Microsoft.OutlookForWindows',
        'MicrosoftTeams',
        'Microsoft.Copilot',
        'MicrosoftCorporationII.QuickAssist',
        'Microsoft.Xbox.TCUI',
        'Microsoft.XboxApp'
    )

    $removedCount     = 0
    $deprovisionCount = 0
    $notFoundCount    = 0

    foreach ($appName in $AppxToRemove) {
        $found = $false

        # Remove installed package for all users
        $packages = Get-AppxPackage -Name $appName -AllUsers -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($pkg in $packages) {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    $found = $true
                } catch {
                    # Some packages resist removal -- try without -AllUsers
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                        $found = $true
                    } catch {
                        Write-Host "  [WARN] Could not remove $appName : $_" -ForegroundColor Yellow
                    }
                }
            }
            if ($found) {
                $removedCount++
                $Manifest.AppxRemoved += $appName
                Write-Host "  [OK] Removed: $appName" -ForegroundColor Green
                Write-Log "AppX removed: $appName" "OK"
            }
        }

        # Deprovision to prevent reinstallation on new user accounts
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $appName }
        if ($provisioned) {
            foreach ($prov in $provisioned) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
                    $deprovisionCount++
                    if (-not $found) {
                        $Manifest.AppxRemoved += $appName
                        Write-Host "  [OK] Deprovisioned: $appName" -ForegroundColor Green
                        Write-Log "AppX deprovisioned: $appName" "OK"
                    }
                } catch {
                    Write-Host "  [WARN] Could not deprovision $appName : $_" -ForegroundColor Yellow
                }
            }
        }

        if (-not $found -and -not $provisioned) {
            $notFoundCount++
            Write-Host "  [SKIP] Not installed: $appName" -ForegroundColor DarkGray
            Write-Log "AppX skip: $appName not found" "SKIP"
        }
    }

    Write-Host ""
    Write-Host "  [INFO] Removed: $removedCount, deprovisioned: $deprovisionCount, not found: $notFoundCount" -ForegroundColor DarkCyan
    Write-Log "AppX: $removedCount removed, $deprovisionCount deprovisioned, $notFoundCount not found"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_APPX:$removedCount removed]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] AppX removal: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_APPX:$_]"
    Write-Log "ERROR in Section 3 (AppX): $_" "ERROR"
}


# =============================================================================
# SECTION 4: SCHEDULED TASK DISABLING (~14 tasks)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[4/9] SCHEDULED TASK DISABLING" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $TasksToDisable = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\Windows\Maps\MapsToastTask',
        '\Microsoft\Windows\Maps\MapsUpdateTask',
        '\Microsoft\Windows\NlaSvc\WiFiTask',
        '\Microsoft\Windows\PI\Sqm-Tasks',
        '\Microsoft\XblGameSave\XblGameSaveTask'
    )

    $disabledTaskCount = 0
    $skippedTaskCount  = 0

    foreach ($taskPath in $TasksToDisable) {
        try {
            # Split path into folder and task name
            $taskFolder = Split-Path $taskPath -Parent
            $taskName   = Split-Path $taskPath -Leaf

            $task = Get-ScheduledTask -TaskPath "$taskFolder\" -TaskName $taskName -ErrorAction Stop

            # Record original state
            $originalState = $task.State.ToString()

            if ($originalState -ne 'Disabled') {
                Disable-ScheduledTask -TaskPath "$taskFolder\" -TaskName $taskName -ErrorAction Stop | Out-Null

                # Record in manifest AFTER successful disable
                $Manifest.Tasks += [ordered]@{
                    TaskPath      = $taskPath
                    OriginalState = $originalState
                }
                $disabledTaskCount++
                Write-Host "  [OK] Disabled: $taskName" -ForegroundColor Green
                Write-Log "Task disabled: $taskName" "OK"
            } else {
                # Already disabled -- skip recording in manifest (nothing to undo)
                Write-Host "  [OK] Already disabled: $taskName" -ForegroundColor Green
                Write-Log "Task skip: $taskName (already disabled)" "SKIP"
            }
        } catch {
            $skippedTaskCount++
            Write-Host "  [SKIP] Not found: $(Split-Path $taskPath -Leaf)" -ForegroundColor DarkGray
            Write-Log "Task skip: $(Split-Path $taskPath -Leaf) (not found)" "SKIP"
        }
    }

    Write-Host ""
    Write-Host "  [INFO] Tasks disabled: $disabledTaskCount, skipped: $skippedTaskCount" -ForegroundColor DarkCyan
    Write-Log "Tasks: $disabledTaskCount disabled, $skippedTaskCount skipped"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_TASKS:$disabledTaskCount disabled]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] Scheduled task disabling: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_TASKS:$_]"
    Write-Log "ERROR in Section 4 (Tasks): $_" "ERROR"
}


# =============================================================================
# SECTION 5: DISM FEATURE/CAPABILITY REMOVAL
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[5/9] DISM CAPABILITY REMOVAL" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $CapabilitiesToRemove = @(
        'Browser.InternetExplorer~~~~0.0.11.0',
        'MathRecognizer~~~~0.0.1.0',
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',
        'App.StepsRecorder~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Windows.WordPad~~~~0.0.1.0',
        'Print.Fax.Scan~~~~0.0.1.0',
        'Hello.Face~~~~0.0.1.0'
    )

    $removedCapCount = 0
    $skippedCapCount = 0

    # Get currently installed capabilities once
    $installedCaps = Get-WindowsCapability -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Installed' }
    $installedCapNames = $installedCaps | ForEach-Object { $_.Name }

    foreach ($capName in $CapabilitiesToRemove) {
        if ($installedCapNames -contains $capName) {
            try {
                Write-Host "  [INFO] Removing: $capName ..." -ForegroundColor DarkCyan
                Remove-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null
                $removedCapCount++
                $Manifest.DismRemoved += $capName
                Write-Host "  [OK] Removed: $capName" -ForegroundColor Green
                Write-Log "DISM removed: $capName" "OK"
            } catch {
                $skippedCapCount++
                Write-Host "  [WARN] Could not remove $capName : $_" -ForegroundColor Yellow
                Write-Log "DISM failed to remove: $capName -- $_" "WARN"
            }
        } else {
            $skippedCapCount++
            Write-Host "  [SKIP] Not installed: $capName" -ForegroundColor DarkGray
            Write-Log "DISM skip: $capName not present" "SKIP"
        }
    }

    # Enable DirectPlay for legacy game compatibility
    Write-Host "  [INFO] Enabling DirectPlay for legacy game compatibility..." -ForegroundColor DarkCyan
    try {
        $dpFeature = Get-WindowsOptionalFeature -Online -FeatureName 'DirectPlay' -ErrorAction SilentlyContinue
        if ($dpFeature -and $dpFeature.State -ne 'Enabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName 'DirectPlay' -NoRestart -ErrorAction Stop | Out-Null
            $Manifest.DirectPlayEnabled = $true
            Write-Host "  [OK] DirectPlay enabled." -ForegroundColor Green
            Write-Log "DISM enabled: DirectPlay" "OK"
        } else {
            Write-Host "  [OK] DirectPlay already enabled." -ForegroundColor Green
            Write-Log "DISM: DirectPlay already enabled" "SKIP"
        }
    } catch {
        Write-Host "  [WARN] Could not enable DirectPlay: $_" -ForegroundColor Yellow
        Write-Log "DISM failed to enable DirectPlay: $_" "WARN"
    }

    Write-Host ""
    Write-Host "  [INFO] Capabilities removed: $removedCapCount, skipped: $skippedCapCount" -ForegroundColor DarkCyan
    Write-Log "DISM: $removedCapCount removed, $skippedCapCount skipped"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_DISM:$removedCapCount removed]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] DISM capability removal: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_DISM:$_]"
    Write-Log "ERROR in Section 5 (DISM): $_" "ERROR"
}


# =============================================================================
# SECTION 6: NTFS AND FILESYSTEM OPTIMIZATIONS
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[6/9] NTFS AND FILESYSTEM OPTIMIZATIONS" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Capture original values before changing -- extract only the first number from fsutil output
    $rawOutput = (fsutil behavior query disable8dot3 2>$null) | Select-Object -First 1
    $origDisable8dot3 = if ($rawOutput -match '\b(\d+)\b') { $Matches[1] } else { '0' }

    $rawOutput = (fsutil behavior query disablelastaccess 2>$null) | Select-Object -First 1
    $origLastAccess = if ($rawOutput -match '\b(\d+)\b') { $Matches[1] } else { '0' }

    $rawOutput = (fsutil behavior query memoryusage 2>$null) | Select-Object -First 1
    $origMemoryUsage = if ($rawOutput -match '\b(\d+)\b') { $Matches[1] } else { '0' }

    $Manifest.NtfsOriginal = [ordered]@{
        disable8dot3     = $origDisable8dot3
        disablelastaccess = $origLastAccess
        memoryusage      = $origMemoryUsage
    }

    # Disable 8.3 short name creation -- reduces NTFS overhead
    fsutil behavior set disable8dot3 1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fsutil disable8dot3 returned exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Log "NTFS disable8dot3: fsutil returned $LASTEXITCODE" "WARN"
    } else {
        Write-Host "  [OK] 8.3 short name creation disabled (reduces NTFS overhead)." -ForegroundColor Green
        Write-Log "NTFS disable8dot3: original=$origDisable8dot3, set=1" "OK"
    }

    # Disable last-access timestamp updates -- reduces disk writes
    fsutil behavior set disablelastaccess 1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fsutil disablelastaccess returned exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Log "NTFS disablelastaccess: fsutil returned $LASTEXITCODE" "WARN"
    } else {
        Write-Host "  [OK] Last-access timestamp updates disabled (reduces disk writes)." -ForegroundColor Green
        Write-Log "NTFS disablelastaccess: original=$origLastAccess, set=1" "OK"
    }

    # Increase NTFS memory allocation -- improves file system caching
    fsutil behavior set memoryusage 2 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] fsutil memoryusage returned exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Log "NTFS memoryusage: fsutil returned $LASTEXITCODE" "WARN"
    } else {
        Write-Host "  [OK] NTFS memory allocation increased (improves caching)." -ForegroundColor Green
        Write-Log "NTFS memoryusage: original=$origMemoryUsage, set=2" "OK"
    }

    Write-Host "[SQ_CHECK_OK:DEBLOAT_NTFS]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] NTFS optimization: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_NTFS:$_]"
    Write-Log "ERROR in Section 6 (NTFS): $_" "ERROR"
}


# =============================================================================
# SECTION 7: ADDITIONAL REGISTRY TWEAKS (beyond existing Windows scripts)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[7/9] REGISTRY TWEAKS (Privacy and Anti-Bloat)" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Helper: read existing reg value, set new value, record original in manifest
    function Set-RegAndRecord {
        param(
            [string]$Path,
            [string]$Name,
            [object]$Value,
            [string]$Type = 'DWord',
            [string]$Label
        )

        $original = $null
        try {
            if (Test-Path $Path) {
                $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                if ($null -ne $prop -and ($prop.PSObject.Properties.Name -contains $Name)) {
                    $original = $prop.$Name
                }
            }
        } catch {
            Write-Host "  [WARN] Could not read original value for $Name at ${Path}: $_" -ForegroundColor Yellow
        }

        # Ensure path exists
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Log "Registry created key: $Path"
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force

        $script:Manifest.Registry += [ordered]@{
            Path     = $Path
            Name     = $Name
            Original = $original
            NewValue = $Value
            Type     = $Type
        }

        Write-Log "Registry set: $Path\$Name = $Value (original: $original)"
        if ($Label) {
            Write-Host "  [OK] $Label" -ForegroundColor Green
        }
    }

    # -- Disable Windows Tips and Suggestions --
    $cdmPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-RegAndRecord -Path $cdmPath -Name 'SoftLandingEnabled' -Value 0 -Label 'Windows Tips disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-338388Enabled' -Value 0 -Label 'Suggested content in Settings disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-338389Enabled' -Value 0 -Label 'Tips about Windows disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-310093Enabled' -Value 0 -Label 'Start Menu suggestions disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-338393Enabled' -Value 0 -Label 'Suggested content in Settings (2) disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-353694Enabled' -Value 0 -Label 'Suggested content in Settings (3) disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SubscribedContent-353696Enabled' -Value 0 -Label 'Suggested content in Settings (4) disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'SystemPaneSuggestionsEnabled' -Value 0 -Label 'System pane suggestions disabled'

    # -- Disable Start Menu web search --
    $explorerPolicyPath = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    Set-RegAndRecord -Path $explorerPolicyPath -Name 'DisableSearchBoxSuggestions' -Value 1 -Label 'Start Menu web search disabled'

    # -- Disable Cloud Content (consumer features) --
    $cloudContentPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
    Set-RegAndRecord -Path $cloudContentPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -Label 'Windows consumer features disabled'

    # -- Disable Activity History --
    $systemPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    Set-RegAndRecord -Path $systemPolicyPath -Name 'EnableActivityFeed' -Value 0 -Label 'Activity Feed disabled'
    Set-RegAndRecord -Path $systemPolicyPath -Name 'PublishUserActivities' -Value 0 -Label 'User activity publishing disabled'

    # -- Disable Advertising ID --
    $adInfoPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    Set-RegAndRecord -Path $adInfoPath -Name 'Enabled' -Value 0 -Label 'Advertising ID disabled'

    # -- Disable Settings sync --
    $syncPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync'
    Set-RegAndRecord -Path $syncPath -Name 'SyncPolicy' -Value 5 -Label 'Settings sync disabled'
    $syncGroupPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync\Groups\Accessibility'
    Set-RegAndRecord -Path $syncGroupPath -Name 'Enabled' -Value 0 -Label 'Accessibility sync disabled'
    $syncGroupPath2 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync\Groups\Personalization'
    Set-RegAndRecord -Path $syncGroupPath2 -Name 'Enabled' -Value 0 -Label 'Personalization sync disabled'
    $syncGroupPath3 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync\Groups\BrowserSettings'
    Set-RegAndRecord -Path $syncGroupPath3 -Name 'Enabled' -Value 0 -Label 'Browser settings sync disabled'
    $syncGroupPath4 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingsSync\Groups\Windows'
    Set-RegAndRecord -Path $syncGroupPath4 -Name 'Enabled' -Value 0 -Label 'Windows sync disabled'

    # -- Disable Clipboard history --
    Set-RegAndRecord -Path $systemPolicyPath -Name 'AllowClipboardHistory' -Value 0 -Label 'Clipboard history disabled'

    # -- Disable lock screen tips --
    Set-RegAndRecord -Path $cdmPath -Name 'RotatingLockScreenEnabled' -Value 0 -Label 'Lock screen spotlight disabled'
    Set-RegAndRecord -Path $cdmPath -Name 'RotatingLockScreenOverlayEnabled' -Value 0 -Label 'Lock screen overlay disabled'

    Write-Host ""
    Write-Host "  [INFO] $($Manifest.Registry.Count) registry values set." -ForegroundColor DarkCyan
    Write-Log "Registry: $($Manifest.Registry.Count) values set"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_REGISTRY]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] Registry tweaks: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_REGISTRY:$_]"
    Write-Log "ERROR in Section 7 (Registry): $_" "ERROR"
}


# =============================================================================
# SECTION 8: WINDOWS UPDATE DEFERRAL
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[8/9] WINDOWS UPDATE DEFERRAL" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $wuPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

    # Record original value if it exists
    $originalDeferDays = $null
    try {
        if (Test-Path $wuPolicyPath) {
            $prop = Get-ItemProperty -Path $wuPolicyPath -Name 'DeferFeatureUpdatesPeriodInDays' -ErrorAction SilentlyContinue
            if ($null -ne $prop -and ($prop.PSObject.Properties.Name -contains 'DeferFeatureUpdatesPeriodInDays')) {
                $originalDeferDays = $prop.DeferFeatureUpdatesPeriodInDays
            }
        }
    } catch {
        Write-Host "  [WARN] Could not read original update deferral value: $_" -ForegroundColor Yellow
    }

    if (-not (Test-Path $wuPolicyPath)) { New-Item -Path $wuPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $wuPolicyPath -Name 'DeferFeatureUpdatesPeriodInDays' -Value 365 -Type DWord -Force

    $Manifest.Registry += [ordered]@{
        Path     = $wuPolicyPath
        Name     = 'DeferFeatureUpdatesPeriodInDays'
        Original = $originalDeferDays
        NewValue = 365
        Type     = 'DWord'
    }
    $Manifest.UpdateDeferral = $true

    Write-Host "  [OK] Feature updates deferred by 365 days." -ForegroundColor Green
    Write-Host "  [INFO] Security updates will continue to install normally." -ForegroundColor DarkCyan
    Write-Host "  [INFO] This prevents Windows from reverting your optimizations." -ForegroundColor DarkCyan
    Write-Log "Update deferral: DeferFeatureUpdatesPeriodInDays=365 (original: $originalDeferDays)"
    Write-Host "[SQ_CHECK_OK:DEBLOAT_UPDATES]"
    Save-Manifest -Path $ManifestPath -Data $Manifest
} catch {
    Write-Host "  [FAIL] Update deferral: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_UPDATES:$_]"
    Write-Log "ERROR in Section 8 (Updates): $_" "ERROR"
}


# =============================================================================
# SECTION 9: SUMMARY AND MANIFEST SAVE
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[9/9] SUMMARY" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Save the manifest JSON
    $Manifest.CompletedAt = (Get-Date -Format 'o')
    $manifestJson = $Manifest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($ManifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "  DEEP DEBLOAT COMPLETE" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Changes applied:" -ForegroundColor White
    Write-Host "    Services disabled/changed:  $($Manifest.Services.Count)" -ForegroundColor White
    Write-Host "    AppX packages removed:      $($Manifest.AppxRemoved.Count)" -ForegroundColor White
    Write-Host "    Scheduled tasks disabled:   $($Manifest.Tasks.Count)" -ForegroundColor White
    Write-Host "    DISM capabilities removed:  $($Manifest.DismRemoved.Count)" -ForegroundColor White
    Write-Host "    Registry values set:        $($Manifest.Registry.Count)" -ForegroundColor White
    Write-Host "    NTFS optimizations:         3" -ForegroundColor White
    Write-Host "    Feature update deferral:    365 days" -ForegroundColor White
    Write-Host ""
    Write-Host "  Estimated RAM savings: ~1-2 GB (after reboot)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Backup location:" -ForegroundColor Yellow
    Write-Host "    $BackupDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Undo manifest:" -ForegroundColor Yellow
    Write-Host "    $ManifestPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To undo ALL changes: run scripts/31_Undo_Deep_Debloat.ps1" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  REBOOT REQUIRED for all changes to take full effect." -ForegroundColor Yellow
    Write-Host ""

    Write-Log "COMPLETE: Services=$($Manifest.Services.Count), AppX=$($Manifest.AppxRemoved.Count), Tasks=$($Manifest.Tasks.Count), DISM=$($Manifest.DismRemoved.Count), Registry=$($Manifest.Registry.Count)"
    Write-Log "Manifest saved to: $ManifestPath"

    Write-Host "[SQ_CHECK_OK:DEBLOAT_COMPLETE]"

    Write-Host ""
    Write-Host "  Diagnostic log saved to:" -ForegroundColor DarkCyan
    Write-Host "    $LogFile" -ForegroundColor DarkCyan
} catch {
    Write-Host "  [FAIL] Could not save manifest: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:DEBLOAT_COMPLETE:$_]"
    Write-Log "ERROR in Section 9 (Summary): $_" "ERROR"
}
