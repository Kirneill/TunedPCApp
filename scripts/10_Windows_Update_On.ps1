#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables Windows Update and applies a security-focused update policy profile.

.DESCRIPTION
    Re-enables update services/tasks and then applies the security profile:
    - Exclude driver updates from Windows Update
    - Defer feature updates 365 days
    - Defer quality updates 4 days
    - Prevent automatic restart while users are logged on
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  WINDOWS UPDATE MODE: ON (SECURITY PROFILE)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Resetting Windows Update policy paths..." -ForegroundColor White
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Policy paths reset." -ForegroundColor Green

Write-Host ""
Write-Host "[2/4] Re-enabling update services and tasks..." -ForegroundColor White
Set-Service -Name BITS -StartupType Manual
Set-Service -Name wuauserv -StartupType Manual
Set-Service -Name UsoSvc -StartupType Automatic
Set-Service -Name WaaSMedicSvc -StartupType Manual

$Tasks =
    '\Microsoft\Windows\InstallService\*',
    '\Microsoft\Windows\UpdateOrchestrator\*',
    '\Microsoft\Windows\UpdateAssistant\*',
    '\Microsoft\Windows\WaaSMedic\*',
    '\Microsoft\Windows\WindowsUpdate\*',
    '\Microsoft\WindowsUpdate\*'

foreach ($Task in $Tasks) {
    Get-ScheduledTask -TaskPath $Task | Enable-ScheduledTask -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Update services/tasks re-enabled." -ForegroundColor Green

Write-Host ""
Write-Host "[3/4] Applying security-focused update policy..." -ForegroundColor White

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Type DWord -Value 1

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -Type DWord -Value 0

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Type DWord -Value 1

New-Item -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -Type DWord -Value 20
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -Type DWord -Value 365
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays" -Type DWord -Value 4

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -Type DWord -Value 0
Write-Host "  [OK] Security profile policy applied." -ForegroundColor Green

Write-Host ""
Write-Host "[4/4] Resetting local security policy baseline..." -ForegroundColor White
secedit /configure /cfg "$Env:SystemRoot\inf\defltbase.inf" /db defltbase.sdb | Out-Null
Write-Host "  [OK] Local security policy baseline refreshed." -ForegroundColor Green

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  WINDOWS UPDATE IS ON (SECURITY PROFILE ACTIVE)" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[NOTE] Reboot recommended for all changes to apply." -ForegroundColor Yellow
