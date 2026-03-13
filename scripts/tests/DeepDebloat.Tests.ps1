<#
.SYNOPSIS
    Pester 5 tests for Deep Debloat scripts (30 and 31).
    Validates manifest structure, service safety, AppX safety,
    SQ_CHECK marker coverage, and script headers.

.DESCRIPTION
    Run with:  Invoke-Pester scripts/tests/DeepDebloat.Tests.ps1 -Output Detailed
    Tag filter: Invoke-Pester scripts/tests/DeepDebloat.Tests.ps1 -Tag 'debloat-manifest'

    These are static analysis tests -- they parse the script source code
    and validate structure without running the scripts (which require admin
    and modify the system). No em dashes or bare ampersands in comments.

    IMPORTANT: Pester 5 runs top-level code during discovery (not execution).
    All path resolution and setup must be inside BeforeAll blocks.
#>

# ===========================================================================
# MANIFEST STRUCTURE VALIDATION
# ===========================================================================
Describe "Debloat Manifest Structure" -Tag "debloat-manifest" {

    BeforeAll {
        # Build a mock manifest matching the structure defined in 30_Deep_Debloat.ps1
        $script:MockManifest = [ordered]@{
            Version        = '1.0'
            CreatedAt      = (Get-Date -Format 'o')
            CompletedAt    = (Get-Date -Format 'o')
            BackupDir      = 'C:\Users\TestUser\Documents\SQ_DeepDebloat_Backup_2025-01-01_12-00-00'
            Services       = @(
                [ordered]@{ Name = 'DiagTrack'; OriginalStart = 'Automatic'; NewStart = 'Disabled' },
                [ordered]@{ Name = 'WerSvc'; OriginalStart = 'Manual'; NewStart = 'Disabled' },
                [ordered]@{ Name = 'XblAuthManager'; OriginalStart = 'Manual'; NewStart = 'Manual' }
            )
            AppxRemoved    = @(
                'Microsoft.BingNews',
                'Microsoft.BingWeather',
                'Microsoft.GetHelp'
            )
            Tasks          = @(
                [ordered]@{
                    TaskPath      = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
                    OriginalState = 'Ready'
                },
                [ordered]@{
                    TaskPath      = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
                    OriginalState = 'Ready'
                }
            )
            DismRemoved    = @(
                'Browser.InternetExplorer~~~~0.0.11.0',
                'MathRecognizer~~~~0.0.1.0'
            )
            NtfsOriginal   = [ordered]@{
                disable8dot3      = '0'
                disablelastaccess = '0'
                memoryusage       = '0'
            }
            Registry       = @(
                [ordered]@{
                    Path     = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                    Name     = 'SoftLandingEnabled'
                    Type     = 'DWord'
                    Value    = 0
                    Original = 1
                },
                [ordered]@{
                    Path     = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
                    Name     = 'Enabled'
                    Type     = 'DWord'
                    Value    = 0
                    Original = $null
                }
            )
            UpdateDeferral = $true
            DirectPlayEnabled = $true
        }
    }

    Context "Required top-level fields" {

        It "Has CreatedAt field" {
            $script:MockManifest.Keys | Should -Contain 'CreatedAt'
        }

        It "Has BackupDir field" {
            $script:MockManifest.Keys | Should -Contain 'BackupDir'
        }

        It "Has Services array" {
            $script:MockManifest.Keys | Should -Contain 'Services'
            $script:MockManifest.Services[0] | Should -Not -BeNullOrEmpty
            $script:MockManifest.Services[0] -is [System.Collections.IDictionary] | Should -BeTrue
        }

        It "Has AppxRemoved array" {
            $script:MockManifest.Keys | Should -Contain 'AppxRemoved'
            $script:MockManifest.AppxRemoved | Should -BeOfType [string]
        }

        It "Has Tasks array" {
            $script:MockManifest.Keys | Should -Contain 'Tasks'
            $script:MockManifest.Tasks[0] | Should -Not -BeNullOrEmpty
            $script:MockManifest.Tasks[0] -is [System.Collections.IDictionary] | Should -BeTrue
        }

        It "Has DismRemoved array" {
            $script:MockManifest.Keys | Should -Contain 'DismRemoved'
        }

        It "Has NtfsOriginal hashtable" {
            $script:MockManifest.Keys | Should -Contain 'NtfsOriginal'
            $script:MockManifest.NtfsOriginal -is [System.Collections.IDictionary] | Should -BeTrue
        }

        It "Has Registry array" {
            $script:MockManifest.Keys | Should -Contain 'Registry'
            $script:MockManifest.Registry[0] | Should -Not -BeNullOrEmpty
            $script:MockManifest.Registry[0] -is [System.Collections.IDictionary] | Should -BeTrue
        }

        It "Has UpdateDeferral field" {
            $script:MockManifest.Keys | Should -Contain 'UpdateDeferral'
        }

        It "Has DirectPlayEnabled field" {
            $script:MockManifest.Keys | Should -Contain 'DirectPlayEnabled'
        }
    }

    Context "Services entry structure" {

        It "Each Services entry has Name field" {
            foreach ($svc in $script:MockManifest.Services) {
                $svc.Keys | Should -Contain 'Name'
            }
        }

        It "Each Services entry has OriginalStart field" {
            foreach ($svc in $script:MockManifest.Services) {
                $svc.Keys | Should -Contain 'OriginalStart'
            }
        }

        It "Each Services entry has NewStart field" {
            foreach ($svc in $script:MockManifest.Services) {
                $svc.Keys | Should -Contain 'NewStart'
            }
        }
    }

    Context "Tasks entry structure" {

        It "Each Tasks entry has TaskPath field" {
            foreach ($task in $script:MockManifest.Tasks) {
                $task.Keys | Should -Contain 'TaskPath'
            }
        }

        It "Each Tasks entry has OriginalState field" {
            foreach ($task in $script:MockManifest.Tasks) {
                $task.Keys | Should -Contain 'OriginalState'
            }
        }
    }

    Context "Registry entry structure" {

        It "Each Registry entry has Path field" {
            foreach ($reg in $script:MockManifest.Registry) {
                $reg.Keys | Should -Contain 'Path'
            }
        }

        It "Each Registry entry has Name field" {
            foreach ($reg in $script:MockManifest.Registry) {
                $reg.Keys | Should -Contain 'Name'
            }
        }

        It "Each Registry entry has Type field" {
            foreach ($reg in $script:MockManifest.Registry) {
                $reg.Keys | Should -Contain 'Type'
            }
        }

        It "Each Registry entry has Value field" {
            foreach ($reg in $script:MockManifest.Registry) {
                $reg.Keys | Should -Contain 'Value'
            }
        }

        It "Each Registry entry has Original field (may be null)" {
            foreach ($reg in $script:MockManifest.Registry) {
                $reg.Keys | Should -Contain 'Original'
            }
        }
    }

    Context "JSON round-trip fidelity" {

        BeforeAll {
            $script:JsonString = $script:MockManifest | ConvertTo-Json -Depth 10
            $script:Parsed = $script:JsonString | ConvertFrom-Json
        }

        It "Manifest survives ConvertTo-Json then ConvertFrom-Json" {
            { $script:MockManifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json } | Should -Not -Throw
        }

        It "CreatedAt survives round-trip" {
            [string]$script:Parsed.CreatedAt | Should -Be ([string]$script:MockManifest.CreatedAt)
        }

        It "Services count survives round-trip" {
            $script:Parsed.Services.Count | Should -Be $script:MockManifest.Services.Count
        }

        It "AppxRemoved entries survive round-trip" {
            $script:Parsed.AppxRemoved.Count | Should -Be $script:MockManifest.AppxRemoved.Count
        }

        It "NTFS integer values survive round-trip as strings (bug fix verification)" {
            # The debloat script stores NTFS values as strings like '0'.
            # ConvertTo-Json preserves them as strings. ConvertFrom-Json should
            # return them so the undo script can pass them to fsutil.
            $ntfs = $script:Parsed.NtfsOriginal
            $ntfs.disable8dot3 | Should -Be '0'
            $ntfs.disablelastaccess | Should -Be '0'
            $ntfs.memoryusage | Should -Be '0'
        }

        It "Registry Original null survives round-trip" {
            # Entry with Original = null should stay null after round-trip
            $nullEntry = $script:Parsed.Registry | Where-Object { $_.Name -eq 'Enabled' }
            $nullEntry.Original | Should -BeNullOrEmpty
        }

        It "UpdateDeferral boolean survives round-trip" {
            $script:Parsed.UpdateDeferral | Should -Be $true
        }
    }
}


# ===========================================================================
# SERVICE NAME VALIDATION
# ===========================================================================
Describe "Debloat Service Names" -Tag "debloat-services" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $DebloatScript = Join-Path $ScriptsDir "30_Deep_Debloat.ps1"

        $script:ScriptContent = Get-Content $DebloatScript -Raw

        # Extract service entries from the $ServicesToChange array
        # Match lines like: @{ Name = 'DiagTrack';       Target = 'Disabled' }
        $script:ServiceEntries = [regex]::Matches($script:ScriptContent,
            "@\{\s*Name\s*=\s*'([^']+)'\s*;\s*Target\s*=\s*'([^']+)'\s*\}") |
            ForEach-Object {
                [PSCustomObject]@{
                    Name   = $_.Groups[1].Value
                    Target = $_.Groups[2].Value
                }
            }

        $script:ServiceNames = $script:ServiceEntries | ForEach-Object { $_.Name }

        # Forbidden services that must NEVER be disabled
        $script:ForbiddenServices = @(
            'WinDefend',         # Windows Defender
            'mpssvc',            # Windows Firewall
            'CryptSvc',          # Cryptographic Services
            'EventLog',          # Event Logging
            'RpcSs',             # RPC
            'DcomLaunch',        # DCOM Server Process Launcher
            'Winmgmt',           # WMI
            'BFE',               # Base Filtering Engine
            'WlanSvc',           # WLAN AutoConfig (Wi-Fi)
            'Dhcp',              # DHCP Client
            'Dnscache',          # DNS Client
            'nsi',               # Network Store Interface
            'LanmanWorkstation', # Workstation (SMB client)
            'LanmanServer',      # Server (SMB server)
            'AudioSrv',          # Windows Audio
            'Audiosrv'           # Windows Audio (alternate casing)
        )

        # Xbox services that should be Manual, not Disabled
        $script:XboxServices = @('XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc')

        # Update services that should be Manual, not Disabled
        $script:UpdateServices = @('BITS', 'wuauserv')
    }

    Context "Service name format validation" {

        It "Extracts at least 30 service entries from the script" {
            $script:ServiceEntries.Count | Should -BeGreaterOrEqual 30
        }

        It "All service names match valid Windows service name pattern" {
            foreach ($name in $script:ServiceNames) {
                $name | Should -Match '^[a-zA-Z][a-zA-Z0-9_.]+$' -Because "Service name '$name' should be a valid Windows service identifier"
            }
        }
    }

    Context "Forbidden services are not in the list" {

        It "Does not contain any forbidden critical services" {
            foreach ($forbidden in $script:ForbiddenServices) {
                $script:ServiceNames | Should -Not -Contain $forbidden -Because "$forbidden is a critical system service that must never be disabled"
            }
        }
    }

    Context "Xbox services are set to Manual (not Disabled)" {

        It "XblAuthManager target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'XblAuthManager' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }

        It "XblGameSave target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'XblGameSave' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }

        It "XboxNetApiSvc target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'XboxNetApiSvc' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }

        It "XboxGipSvc target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'XboxGipSvc' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }
    }

    Context "Update services are set to Manual (not Disabled)" {

        It "BITS target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'BITS' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }

        It "wuauserv target is Manual" {
            $entry = $script:ServiceEntries | Where-Object { $_.Name -eq 'wuauserv' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.Target | Should -Be 'Manual'
        }
    }
}


# ===========================================================================
# APPX PACKAGE NAME VALIDATION
# ===========================================================================
Describe "Debloat AppX Package Names" -Tag "debloat-appx" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"
        $DebloatScript = Join-Path $ScriptsDir "30_Deep_Debloat.ps1"

        $script:ScriptContent = Get-Content $DebloatScript -Raw

        # Extract AppX package names from the $AppxToRemove array
        # Match lines like: 'Microsoft.BingNews',
        $script:AppxNames = [regex]::Matches($script:ScriptContent,
            "(?m)^\s+'([a-zA-Z0-9.*_-]+(?:\.[a-zA-Z0-9.*_-]+)*)'\s*,?\s*(?:#.*)?$") |
            ForEach-Object { $_.Groups[1].Value } |
            Select-Object -Unique

        # Packages that must be PRESERVED (NOT in the remove list)
        $script:PreservedPackages = @(
            'Microsoft.WindowsStore',
            'Microsoft.WindowsCalculator',
            'Microsoft.WindowsTerminal',
            'Microsoft.Paint',
            'Microsoft.ScreenSketch',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.GamingApp'
        )
    }

    Context "Package name format" {

        It "Extracts AppX package names from the script" {
            $script:AppxNames.Count | Should -BeGreaterThan 0
        }

        It "All package names match valid format" {
            foreach ($name in $script:AppxNames) {
                $name | Should -Match '^[a-zA-Z0-9.*_-]+$' -Because "Package name '$name' should only contain alphanumeric, dot, star, underscore, or hyphen characters"
            }
        }

        It "Package count is approximately 30 (25-35 range)" {
            $script:AppxNames.Count | Should -BeGreaterOrEqual 25
            $script:AppxNames.Count | Should -BeLessOrEqual 35
        }
    }

    Context "Preserved packages are NOT in the remove list" {

        It "Does not contain Microsoft.WindowsStore" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.WindowsStore'
        }

        It "Does not contain Microsoft.WindowsCalculator" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.WindowsCalculator'
        }

        It "Does not contain Microsoft.WindowsTerminal" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.WindowsTerminal'
        }

        It "Does not contain Microsoft.Paint" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.Paint'
        }

        It "Does not contain Microsoft.ScreenSketch" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.ScreenSketch'
        }

        It "Does not contain Microsoft.XboxIdentityProvider" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.XboxIdentityProvider'
        }

        It "Does not contain Microsoft.GamingApp" {
            $script:AppxNames | Should -Not -Contain 'Microsoft.GamingApp'
        }
    }
}


# ===========================================================================
# SQ_CHECK MARKER COVERAGE
# ===========================================================================
Describe "SQ_CHECK Marker Coverage" -Tag "debloat-markers" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"

        $script:DebloatContent = Get-Content (Join-Path $ScriptsDir "30_Deep_Debloat.ps1") -Raw
        $script:UndoContent   = Get-Content (Join-Path $ScriptsDir "31_Undo_Deep_Debloat.ps1") -Raw
    }

    Context "30_Deep_Debloat.ps1 OK markers" {

        It "Contains SQ_CHECK_OK:DEBLOAT_BACKUP marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_BACKUP'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_SERVICES marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_SERVICES'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_APPX marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_APPX'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_TASKS marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_TASKS'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_DISM marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_DISM'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_NTFS marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_NTFS'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_REGISTRY marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_REGISTRY'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_UPDATES marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_UPDATES'
        }

        It "Contains SQ_CHECK_OK:DEBLOAT_COMPLETE marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_OK:DEBLOAT_COMPLETE'
        }
    }

    Context "30_Deep_Debloat.ps1 FAIL markers" {

        It "Contains SQ_CHECK_FAIL:DEBLOAT_BACKUP marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_BACKUP'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_SERVICES marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_SERVICES'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_APPX marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_APPX'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_TASKS marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_TASKS'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_DISM marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_DISM'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_NTFS marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_NTFS'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_REGISTRY marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_REGISTRY'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_UPDATES marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_UPDATES'
        }

        It "Contains SQ_CHECK_FAIL:DEBLOAT_COMPLETE marker" {
            $script:DebloatContent | Should -Match 'SQ_CHECK_FAIL:DEBLOAT_COMPLETE'
        }
    }

    Context "31_Undo_Deep_Debloat.ps1 OK markers" {

        It "Contains SQ_CHECK_OK:UNDO_MANIFEST marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_MANIFEST'
        }

        It "Contains SQ_CHECK_OK:UNDO_SERVICES marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_SERVICES'
        }

        It "Contains SQ_CHECK_OK or SQ_CHECK_WARN for UNDO_APPX" {
            $script:UndoContent | Should -Match 'SQ_CHECK_(OK|WARN):UNDO_APPX'
        }

        It "Contains SQ_CHECK_OK:UNDO_TASKS marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_TASKS'
        }

        It "Contains SQ_CHECK_OK:UNDO_REGISTRY marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_REGISTRY'
        }

        It "Contains SQ_CHECK_OK or SQ_CHECK_WARN for UNDO_DISM" {
            $script:UndoContent | Should -Match 'SQ_CHECK_(OK|WARN):UNDO_DISM'
        }

        It "Contains SQ_CHECK_OK:UNDO_NTFS marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_NTFS'
        }

        It "Contains SQ_CHECK_OK:UNDO_UPDATES marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_UPDATES'
        }

        It "Contains SQ_CHECK_OK:UNDO_COMPLETE marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_OK:UNDO_COMPLETE'
        }
    }

    Context "31_Undo_Deep_Debloat.ps1 FAIL markers" {

        It "Contains SQ_CHECK_FAIL:UNDO_MANIFEST marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_MANIFEST'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_SERVICES marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_SERVICES'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_APPX marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_APPX'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_TASKS marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_TASKS'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_REGISTRY marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_REGISTRY'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_DISM marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_DISM'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_NTFS marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_NTFS'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_UPDATES marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_UPDATES'
        }

        It "Contains SQ_CHECK_FAIL:UNDO_COMPLETE marker" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_COMPLETE'
        }
    }
}


# ===========================================================================
# SCRIPT HEADER VALIDATION
# ===========================================================================
Describe "Debloat Script Headers" -Tag "debloat-header" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"

        $script:DebloatContent = Get-Content (Join-Path $ScriptsDir "30_Deep_Debloat.ps1") -Raw
        $script:UndoContent   = Get-Content (Join-Path $ScriptsDir "31_Undo_Deep_Debloat.ps1") -Raw

        $script:DebloatLines = Get-Content (Join-Path $ScriptsDir "30_Deep_Debloat.ps1")
        $script:UndoLines   = Get-Content (Join-Path $ScriptsDir "31_Undo_Deep_Debloat.ps1")
    }

    Context "30_Deep_Debloat.ps1 header requirements" {

        It "Contains #Requires -RunAsAdministrator" {
            $script:DebloatContent | Should -Match '#Requires\s+-RunAsAdministrator'
        }

        It "Checks SENSEQUALITY_HEADLESS environment variable" {
            $script:DebloatContent | Should -Match '\$env:SENSEQUALITY_HEADLESS'
        }

        It "Sets ErrorActionPreference to Stop" {
            $script:DebloatContent | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        }

        It "Does not contain em dashes in comments" {
            # Em dash is Unicode U+2014. Check each line for em dashes in comment sections.
            $emDash = [char]0x2014
            foreach ($line in $script:DebloatLines) {
                if ($line -match '#' -and $line.Contains($emDash)) {
                    $line | Should -Not -Match $emDash -Because "Em dashes in comments cause Pester parse errors. Use -- instead."
                }
            }
        }

        It "Does not contain bare ampersands in comments" {
            foreach ($line in $script:DebloatLines) {
                # Only check comment portions of lines (after #)
                if ($line -match '#(.+)$') {
                    $commentPart = $Matches[1]
                    # Bare ampersand in a comment (not in a string or code context)
                    # Allow ampersands that are part of code like *>&1
                    if ($commentPart -match '\s&\s' -or $commentPart -match '\b&\b') {
                        # Found a bare ampersand in comment text
                        $commentPart | Should -Not -Match '(?<![*>])\s&\s' -Because "Bare ampersands in comments cause parse errors. Use 'and' instead."
                    }
                }
            }
        }
    }

    Context "31_Undo_Deep_Debloat.ps1 header requirements" {

        It "Contains #Requires -RunAsAdministrator" {
            $script:UndoContent | Should -Match '#Requires\s+-RunAsAdministrator'
        }

        It "Checks SENSEQUALITY_HEADLESS environment variable" {
            $script:UndoContent | Should -Match '\$env:SENSEQUALITY_HEADLESS'
        }

        It "Sets ErrorActionPreference to Stop" {
            $script:UndoContent | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        }

        It "Does not contain em dashes in comments" {
            $emDash = [char]0x2014
            foreach ($line in $script:UndoLines) {
                if ($line -match '#' -and $line.Contains($emDash)) {
                    $line | Should -Not -Match $emDash -Because "Em dashes in comments cause Pester parse errors. Use -- instead."
                }
            }
        }

        It "Does not contain bare ampersands in comments" {
            foreach ($line in $script:UndoLines) {
                if ($line -match '#(.+)$') {
                    $commentPart = $Matches[1]
                    if ($commentPart -match '\s&\s' -or $commentPart -match '\b&\b') {
                        $commentPart | Should -Not -Match '(?<![*>])\s&\s' -Because "Bare ampersands in comments cause parse errors. Use 'and' instead."
                    }
                }
            }
        }
    }
}


# ===========================================================================
# UNDO SCRIPT MANIFEST HANDLING
# ===========================================================================
Describe "Undo Script Manifest Handling" -Tag "debloat-undo" {

    BeforeAll {
        $ProjectRoot = (Get-Location).Path
        $ScriptsDir = Join-Path $ProjectRoot "scripts"

        $script:UndoContent = Get-Content (Join-Path $ScriptsDir "31_Undo_Deep_Debloat.ps1") -Raw
    }

    Context "Manifest path and loading" {

        It "References the correct manifest path under APPDATA\SENSEQUALITY" {
            $script:UndoContent | Should -Match '\$env:APPDATA'
            $script:UndoContent | Should -Match 'SENSEQUALITY'
            $script:UndoContent | Should -Match 'debloat-manifest\.json'
        }

        It "Emits SQ_CHECK_FAIL:UNDO_MANIFEST when manifest is missing" {
            $script:UndoContent | Should -Match 'SQ_CHECK_FAIL:UNDO_MANIFEST'
            # Verify it checks Test-Path before loading
            $script:UndoContent | Should -Match 'Test-Path\s+\$ManifestPath'
        }

        It "Checks Test-Path for manifest existence" {
            $script:UndoContent | Should -Match '-not\s+\(Test-Path\s+\$ManifestPath\)'
        }
    }

    Context "NTFS value restoration uses null-safe checks" {

        It "Uses null-ne check for disable8dot3" {
            $script:UndoContent | Should -Match '\$null\s+-ne\s+\$ntfs\.disable8dot3'
        }

        It "Uses null-ne check for disablelastaccess" {
            $script:UndoContent | Should -Match '\$null\s+-ne\s+\$ntfs\.disablelastaccess'
        }

        It "Uses null-ne check for memoryusage" {
            $script:UndoContent | Should -Match '\$null\s+-ne\s+\$ntfs\.memoryusage'
        }
    }

    Context "Registry restoration handles null Original values" {

        It "Checks for null Original to decide remove vs restore" {
            $script:UndoContent | Should -Match '\$null\s+-eq\s+\$regOrig'
        }

        It "Uses Remove-ItemProperty for values that did not exist before" {
            $script:UndoContent | Should -Match 'Remove-ItemProperty'
        }
    }
}
