#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies Standard Windows tweaks profile.

.DESCRIPTION
    This script applies the standard baseline preset in SENSEQUALITY.
    It includes privacy, service, and maintenance adjustments.
#>

$ErrorActionPreference = 'SilentlyContinue'
$SectionFailures = 0

function Set-RegistryBatch {
    param([array]$Entries)

    foreach ($entry in $Entries) {
        try {
            if (-not (Test-Path $entry.Path)) {
                New-Item -Path $entry.Path -Force | Out-Null
            }

            if ($entry.Type -ieq 'String') {
                Set-ItemProperty -Path $entry.Path -Name $entry.Name -Type String -Value ([string]$entry.Value) -Force
            } else {
                $intValue = 0
                if ([int]::TryParse([string]$entry.Value, [ref]$intValue)) {
                    Set-ItemProperty -Path $entry.Path -Name $entry.Name -Type $entry.Type -Value $intValue -Force
                } else {
                    Set-ItemProperty -Path $entry.Path -Name $entry.Name -Type $entry.Type -Value $entry.Value -Force
                }
            }
        } catch {
            Write-Host "  [WARN] Registry set failed: $($entry.Path)\$($entry.Name)" -ForegroundColor Yellow
            $script:SectionFailures++
        }
    }
}

function Invoke-Section {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    Write-Host ""
    Write-Host "------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "$Name" -ForegroundColor White
    Write-Host "------------------------------------------------------" -ForegroundColor DarkGray

    try {
        & $Script
        Write-Host "  [OK] $Name" -ForegroundColor Green
    } catch {
        $script:SectionFailures++
        Write-Host "  [WARN] $Name failed: $_" -ForegroundColor Yellow
    }
}

function Set-ServiceStartupTypeSafe {
    param(
        [string]$Name,
        [string]$StartupType
    )

    switch ($StartupType) {
        'AutomaticDelayedStart' {
            Set-Service -Name $Name -StartupType Automatic -ErrorAction SilentlyContinue
            sc.exe config $Name start= delayed-auto | Out-Null
        }
        'Automatic' {
            Set-Service -Name $Name -StartupType Automatic -ErrorAction SilentlyContinue
        }
        'Manual' {
            Set-Service -Name $Name -StartupType Manual -ErrorAction SilentlyContinue
        }
        'Disabled' {
            Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
        default {
            Set-Service -Name $Name -StartupType Manual -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 300,
        [string]$Label = $FilePath
    )

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden -ErrorAction Stop
    } catch {
        Write-Host "  [WARN] Failed to start ${Label}: $_" -ForegroundColor Yellow
        $script:SectionFailures++
        return $false
    }

    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } catch {}
        Write-Host "  [WARN] $Label timed out after $TimeoutSeconds seconds and was skipped." -ForegroundColor Yellow
        $script:SectionFailures++
        return $false
    }

    if ($process.ExitCode -ne 0) {
        Write-Host "  [WARN] $Label exited with code $($process.ExitCode)." -ForegroundColor Yellow
        $script:SectionFailures++
        return $false
    }

    Write-Host "  [OK] $Label completed." -ForegroundColor Green
    return $true
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  WINUTIL STANDARD SETTINGS" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

Invoke-Section -Name "[1/11] Disable Activity History" -Script {
    $entries = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Type = 'DWord'; Value = '0' }
    )
    Set-RegistryBatch -Entries $entries
}

Invoke-Section -Name "[2/11] Disable Consumer Features" -Script {
    $entries = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = '1' }
    )
    Set-RegistryBatch -Entries $entries
}

Invoke-Section -Name "[3/11] Disable Explorer Auto Folder Discovery" -Script {
    $bags = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags"
    $bagMRU = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"

    Remove-Item -Path $bags -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $bagMRU -Recurse -Force -ErrorAction SilentlyContinue

    $allFolders = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
    if (-not (Test-Path $allFolders)) {
        New-Item -Path $allFolders -Force | Out-Null
    }

    New-ItemProperty -Path $allFolders -Name "FolderType" -Value "NotSpecified" -PropertyType String -Force | Out-Null
}

Invoke-Section -Name "[4/11] Disable WPBT" -Script {
    $entries = @(
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'DisableWpbtExecution'; Type = 'DWord'; Value = '1' }
    )
    Set-RegistryBatch -Entries $entries
}

Invoke-Section -Name "[5/11] Disable Location Tracking" -Script {
    $entries = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; Type = 'String'; Value = 'Deny' }
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}'; Name = 'SensorPermissionState'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration'; Name = 'Status'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SYSTEM\Maps'; Name = 'AutoUpdateEnabled'; Type = 'DWord'; Value = '0' }
    )
    Set-RegistryBatch -Entries $entries
}

Invoke-Section -Name "[6/11] Set Services to Standard Profile" -Script {
    $serviceSettings = @(
    @{ Name = 'ALG'; StartupType = 'Manual' }
    @{ Name = 'AppMgmt'; StartupType = 'Manual' }
    @{ Name = 'AppReadiness'; StartupType = 'Manual' }
    @{ Name = 'AppVClient'; StartupType = 'Disabled' }
    @{ Name = 'Appinfo'; StartupType = 'Manual' }
    @{ Name = 'AssignedAccessManagerSvc'; StartupType = 'Disabled' }
    @{ Name = 'AudioEndpointBuilder'; StartupType = 'Automatic' }
    @{ Name = 'AudioSrv'; StartupType = 'Automatic' }
    @{ Name = 'Audiosrv'; StartupType = 'Automatic' }
    @{ Name = 'AxInstSV'; StartupType = 'Manual' }
    @{ Name = 'BDESVC'; StartupType = 'Manual' }
    @{ Name = 'BITS'; StartupType = 'AutomaticDelayedStart' }
    @{ Name = 'BTAGService'; StartupType = 'Manual' }
    @{ Name = 'BthAvctpSvc'; StartupType = 'Automatic' }
    @{ Name = 'CDPSvc'; StartupType = 'Manual' }
    @{ Name = 'COMSysApp'; StartupType = 'Manual' }
    @{ Name = 'CertPropSvc'; StartupType = 'Manual' }
    @{ Name = 'CryptSvc'; StartupType = 'Automatic' }
    @{ Name = 'CscService'; StartupType = 'Manual' }
    @{ Name = 'DPS'; StartupType = 'Automatic' }
    @{ Name = 'DevQueryBroker'; StartupType = 'Manual' }
    @{ Name = 'DeviceAssociationService'; StartupType = 'Manual' }
    @{ Name = 'DeviceInstall'; StartupType = 'Manual' }
    @{ Name = 'Dhcp'; StartupType = 'Automatic' }
    @{ Name = 'DiagTrack'; StartupType = 'Disabled' }
    @{ Name = 'DialogBlockingService'; StartupType = 'Disabled' }
    @{ Name = 'DispBrokerDesktopSvc'; StartupType = 'Automatic' }
    @{ Name = 'DisplayEnhancementService'; StartupType = 'Manual' }
    @{ Name = 'EFS'; StartupType = 'Manual' }
    @{ Name = 'EapHost'; StartupType = 'Manual' }
    @{ Name = 'EventLog'; StartupType = 'Automatic' }
    @{ Name = 'EventSystem'; StartupType = 'Automatic' }
    @{ Name = 'FDResPub'; StartupType = 'Manual' }
    @{ Name = 'FontCache'; StartupType = 'Automatic' }
    @{ Name = 'FrameServer'; StartupType = 'Manual' }
    @{ Name = 'FrameServerMonitor'; StartupType = 'Manual' }
    @{ Name = 'GraphicsPerfSvc'; StartupType = 'Manual' }
    @{ Name = 'HvHost'; StartupType = 'Manual' }
    @{ Name = 'IKEEXT'; StartupType = 'Manual' }
    @{ Name = 'InstallService'; StartupType = 'Manual' }
    @{ Name = 'InventorySvc'; StartupType = 'Manual' }
    @{ Name = 'IpxlatCfgSvc'; StartupType = 'Manual' }
    @{ Name = 'KeyIso'; StartupType = 'Automatic' }
    @{ Name = 'KtmRm'; StartupType = 'Manual' }
    @{ Name = 'LanmanServer'; StartupType = 'Automatic' }
    @{ Name = 'LanmanWorkstation'; StartupType = 'Automatic' }
    @{ Name = 'LicenseManager'; StartupType = 'Manual' }
    @{ Name = 'LxpSvc'; StartupType = 'Manual' }
    @{ Name = 'MSDTC'; StartupType = 'Manual' }
    @{ Name = 'MSiSCSI'; StartupType = 'Manual' }
    @{ Name = 'MapsBroker'; StartupType = 'AutomaticDelayedStart' }
    @{ Name = 'McpManagementService'; StartupType = 'Manual' }
    @{ Name = 'MicrosoftEdgeElevationService'; StartupType = 'Manual' }
    @{ Name = 'NaturalAuthentication'; StartupType = 'Manual' }
    @{ Name = 'NcaSvc'; StartupType = 'Manual' }
    @{ Name = 'NcbService'; StartupType = 'Manual' }
    @{ Name = 'NcdAutoSetup'; StartupType = 'Manual' }
    @{ Name = 'NetSetupSvc'; StartupType = 'Manual' }
    @{ Name = 'NetTcpPortSharing'; StartupType = 'Disabled' }
    @{ Name = 'Netman'; StartupType = 'Manual' }
    @{ Name = 'NlaSvc'; StartupType = 'Manual' }
    @{ Name = 'PcaSvc'; StartupType = 'Manual' }
    @{ Name = 'PeerDistSvc'; StartupType = 'Manual' }
    @{ Name = 'PerfHost'; StartupType = 'Manual' }
    @{ Name = 'PhoneSvc'; StartupType = 'Manual' }
    @{ Name = 'PlugPlay'; StartupType = 'Manual' }
    @{ Name = 'PolicyAgent'; StartupType = 'Manual' }
    @{ Name = 'Power'; StartupType = 'Automatic' }
    @{ Name = 'PrintNotify'; StartupType = 'Manual' }
    @{ Name = 'ProfSvc'; StartupType = 'Automatic' }
    @{ Name = 'PushToInstall'; StartupType = 'Manual' }
    @{ Name = 'QWAVE'; StartupType = 'Manual' }
    @{ Name = 'RasAuto'; StartupType = 'Manual' }
    @{ Name = 'RasMan'; StartupType = 'Manual' }
    @{ Name = 'RemoteAccess'; StartupType = 'Disabled' }
    @{ Name = 'RemoteRegistry'; StartupType = 'Disabled' }
    @{ Name = 'RetailDemo'; StartupType = 'Manual' }
    @{ Name = 'RmSvc'; StartupType = 'Manual' }
    @{ Name = 'RpcLocator'; StartupType = 'Manual' }
    @{ Name = 'SCPolicySvc'; StartupType = 'Manual' }
    @{ Name = 'SCardSvr'; StartupType = 'Manual' }
    @{ Name = 'SDRSVC'; StartupType = 'Manual' }
    @{ Name = 'SEMgrSvc'; StartupType = 'Manual' }
    @{ Name = 'SENS'; StartupType = 'Automatic' }
    @{ Name = 'SNMPTRAP'; StartupType = 'Manual' }
    @{ Name = 'SNMPTrap'; StartupType = 'Manual' }
    @{ Name = 'SSDPSRV'; StartupType = 'Manual' }
    @{ Name = 'SamSs'; StartupType = 'Automatic' }
    @{ Name = 'ScDeviceEnum'; StartupType = 'Manual' }
    @{ Name = 'SensorDataService'; StartupType = 'Manual' }
    @{ Name = 'SensorService'; StartupType = 'Manual' }
    @{ Name = 'SensrSvc'; StartupType = 'Manual' }
    @{ Name = 'SessionEnv'; StartupType = 'Manual' }
    @{ Name = 'SharedAccess'; StartupType = 'Manual' }
    @{ Name = 'ShellHWDetection'; StartupType = 'Automatic' }
    @{ Name = 'SmsRouter'; StartupType = 'Manual' }
    @{ Name = 'Spooler'; StartupType = 'Automatic' }
    @{ Name = 'SstpSvc'; StartupType = 'Manual' }
    @{ Name = 'StiSvc'; StartupType = 'Manual' }
    @{ Name = 'StorSvc'; StartupType = 'Manual' }
    @{ Name = 'SysMain'; StartupType = 'Automatic' }
    @{ Name = 'TapiSrv'; StartupType = 'Manual' }
    @{ Name = 'TermService'; StartupType = 'Manual' }
    @{ Name = 'Themes'; StartupType = 'Automatic' }
    @{ Name = 'TieringEngineService'; StartupType = 'Manual' }
    @{ Name = 'TokenBroker'; StartupType = 'Manual' }
    @{ Name = 'TrkWks'; StartupType = 'Automatic' }
    @{ Name = 'TroubleshootingSvc'; StartupType = 'Manual' }
    @{ Name = 'TrustedInstaller'; StartupType = 'Manual' }
    @{ Name = 'UevAgentService'; StartupType = 'Disabled' }
    @{ Name = 'UmRdpService'; StartupType = 'Manual' }
    @{ Name = 'UserManager'; StartupType = 'Automatic' }
    @{ Name = 'UsoSvc'; StartupType = 'Manual' }
    @{ Name = 'VSS'; StartupType = 'Manual' }
    @{ Name = 'VaultSvc'; StartupType = 'Manual' }
    @{ Name = 'W32Time'; StartupType = 'Manual' }
    @{ Name = 'WEPHOSTSVC'; StartupType = 'Manual' }
    @{ Name = 'WFDSConMgrSvc'; StartupType = 'Manual' }
    @{ Name = 'WMPNetworkSvc'; StartupType = 'Manual' }
    @{ Name = 'WManSvc'; StartupType = 'Manual' }
    @{ Name = 'WPDBusEnum'; StartupType = 'Manual' }
    @{ Name = 'WSAIFabricSvc'; StartupType = 'Manual' }
    @{ Name = 'WSearch'; StartupType = 'AutomaticDelayedStart' }
    @{ Name = 'WalletService'; StartupType = 'Manual' }
    @{ Name = 'WarpJITSvc'; StartupType = 'Manual' }
    @{ Name = 'WbioSrvc'; StartupType = 'Manual' }
    @{ Name = 'Wcmsvc'; StartupType = 'Automatic' }
    @{ Name = 'WdiServiceHost'; StartupType = 'Manual' }
    @{ Name = 'WdiSystemHost'; StartupType = 'Manual' }
    @{ Name = 'WebClient'; StartupType = 'Manual' }
    @{ Name = 'Wecsvc'; StartupType = 'Manual' }
    @{ Name = 'WerSvc'; StartupType = 'Manual' }
    @{ Name = 'WiaRpc'; StartupType = 'Manual' }
    @{ Name = 'WinRM'; StartupType = 'Manual' }
    @{ Name = 'Winmgmt'; StartupType = 'Automatic' }
    @{ Name = 'WpcMonSvc'; StartupType = 'Manual' }
    @{ Name = 'WpnService'; StartupType = 'Manual' }
    @{ Name = 'XblAuthManager'; StartupType = 'Manual' }
    @{ Name = 'XblGameSave'; StartupType = 'Manual' }
    @{ Name = 'XboxGipSvc'; StartupType = 'Manual' }
    @{ Name = 'XboxNetApiSvc'; StartupType = 'Manual' }
    @{ Name = 'autotimesvc'; StartupType = 'Manual' }
    @{ Name = 'bthserv'; StartupType = 'Manual' }
    @{ Name = 'camsvc'; StartupType = 'Manual' }
    @{ Name = 'cloudidsvc'; StartupType = 'Manual' }
    @{ Name = 'dcsvc'; StartupType = 'Manual' }
    @{ Name = 'defragsvc'; StartupType = 'Manual' }
    @{ Name = 'diagsvc'; StartupType = 'Manual' }
    @{ Name = 'dmwappushservice'; StartupType = 'Manual' }
    @{ Name = 'dot3svc'; StartupType = 'Manual' }
    @{ Name = 'edgeupdate'; StartupType = 'Manual' }
    @{ Name = 'edgeupdatem'; StartupType = 'Manual' }
    @{ Name = 'fdPHost'; StartupType = 'Manual' }
    @{ Name = 'fhsvc'; StartupType = 'Manual' }
    @{ Name = 'hidserv'; StartupType = 'Manual' }
    @{ Name = 'icssvc'; StartupType = 'Manual' }
    @{ Name = 'iphlpsvc'; StartupType = 'Automatic' }
    @{ Name = 'lfsvc'; StartupType = 'Manual' }
    @{ Name = 'lltdsvc'; StartupType = 'Manual' }
    @{ Name = 'lmhosts'; StartupType = 'Manual' }
    @{ Name = 'netprofm'; StartupType = 'Manual' }
    @{ Name = 'nsi'; StartupType = 'Automatic' }
    @{ Name = 'perceptionsimulation'; StartupType = 'Manual' }
    @{ Name = 'pla'; StartupType = 'Manual' }
    @{ Name = 'seclogon'; StartupType = 'Manual' }
    @{ Name = 'shpamsvc'; StartupType = 'Disabled' }
    @{ Name = 'smphost'; StartupType = 'Manual' }
    @{ Name = 'ssh-agent'; StartupType = 'Disabled' }
    @{ Name = 'svsvc'; StartupType = 'Manual' }
    @{ Name = 'swprv'; StartupType = 'Manual' }
    @{ Name = 'tzautoupdate'; StartupType = 'Disabled' }
    @{ Name = 'upnphost'; StartupType = 'Manual' }
    @{ Name = 'vds'; StartupType = 'Manual' }
    @{ Name = 'vmicguestinterface'; StartupType = 'Manual' }
    @{ Name = 'vmicheartbeat'; StartupType = 'Manual' }
    @{ Name = 'vmickvpexchange'; StartupType = 'Manual' }
    @{ Name = 'vmicrdv'; StartupType = 'Manual' }
    @{ Name = 'vmicshutdown'; StartupType = 'Manual' }
    @{ Name = 'vmictimesync'; StartupType = 'Manual' }
    @{ Name = 'vmicvmsession'; StartupType = 'Manual' }
    @{ Name = 'vmicvss'; StartupType = 'Manual' }
    @{ Name = 'wbengine'; StartupType = 'Manual' }
    @{ Name = 'wcncsvc'; StartupType = 'Manual' }
    @{ Name = 'webthreatdefsvc'; StartupType = 'Manual' }
    @{ Name = 'wercplsupport'; StartupType = 'Manual' }
    @{ Name = 'wisvc'; StartupType = 'Manual' }
    @{ Name = 'wlidsvc'; StartupType = 'Manual' }
    @{ Name = 'wlpasvc'; StartupType = 'Manual' }
    @{ Name = 'wmiApSrv'; StartupType = 'Manual' }
    @{ Name = 'workfolderssvc'; StartupType = 'Manual' }
    @{ Name = 'wuauserv'; StartupType = 'Manual' }
    )

    $applied = 0
    $missing = 0

    foreach ($svc in $serviceSettings) {
        try {
            $existing = Get-Service -Name $svc.Name -ErrorAction Stop
            if ($existing) {
                Set-ServiceStartupTypeSafe -Name $svc.Name -StartupType $svc.StartupType
                $applied++
            }
        } catch {
            $missing++
        }
    }

    Write-Host "  [INFO] Service startup profile applied: $applied updated, $missing missing." -ForegroundColor DarkCyan
}

Invoke-Section -Name "[7/11] Disable Telemetry" -Script {
    $entries = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Name = 'HasAccepted'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Type = 'DWord'; Value = '1' }
    @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Type = 'DWord'; Value = '1' }
    @{ Path = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Type = 'DWord'; Value = '0' }
    @{ Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Type = 'DWord'; Value = '0' }
    )
    Set-RegistryBatch -Entries $entries

    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
    Set-Service -Name diagtrack -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name wermgr -StartupType Disabled -ErrorAction SilentlyContinue

    $memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $memory -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -ErrorAction SilentlyContinue
}

Invoke-Section -Name "[8/11] Cleanup (Disk + Temp)" -Script {
    Write-Host "  [INFO] Running cleanup with timeout safeguards..." -ForegroundColor DarkCyan
    Invoke-ProcessWithTimeout -FilePath "cleanmgr.exe" -ArgumentList @("/d", "C:", "/VERYLOWDISK") -TimeoutSeconds 180 -Label "Disk Cleanup (cleanmgr)"
    Invoke-ProcessWithTimeout -FilePath "Dism.exe" -ArgumentList @("/online", "/Cleanup-Image", "/StartComponentCleanup") -TimeoutSeconds 900 -Label "Component Cleanup (DISM)"
    Remove-Item -Path "$Env:Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$Env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Temporary files cleaned." -ForegroundColor Green
}

Invoke-Section -Name "[9/11] Enable End Task on Taskbar Right-Click" -Script {
    $entries = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name = 'TaskbarEndTask'; Type = 'DWord'; Value = '1' }
    )
    Set-RegistryBatch -Entries $entries
}

Invoke-Section -Name "[10/11] Create Restore Point" -Script {
    $entries = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'; Name = 'SystemRestorePointCreationFrequency'; Type = 'DWord'; Value = '0' }
    )
    Set-RegistryBatch -Entries $entries

    if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
        Enable-ComputerRestore -Drive $Env:SystemDrive -ErrorAction SilentlyContinue
    }

    Checkpoint-Computer -Description "System Restore Point created by SENSEQUALITY (Standard Baseline)" -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue
}

Invoke-Section -Name "[11/11] Disable PowerShell 7 Telemetry" -Script {
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
}

Write-Host ""
if ($SectionFailures -gt 0) {
    Write-Host "[WARN] Standard Windows settings finished with $SectionFailures warning(s)." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Standard Windows settings applied successfully." -ForegroundColor Green
}
Write-Host ""
Write-Host "[NOTE] Reboot recommended for all changes to fully apply." -ForegroundColor Yellow
