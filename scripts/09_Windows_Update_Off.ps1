#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables Windows Update services, tasks, and automatic update policy.

.DESCRIPTION
    This is an aggressive mode intended for advanced users who patch manually.
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  WINDOWS UPDATE MODE: OFF" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "[1/3] Applying Windows Update policy settings..." -ForegroundColor White
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 1

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 0
Write-Host "  [OK] Automatic update policy disabled." -ForegroundColor Green

Write-Host ""
Write-Host "[2/3] Disabling update services..." -ForegroundColor White
Set-Service -Name BITS -StartupType Disabled
Set-Service -Name wuauserv -StartupType Disabled
Set-Service -Name UsoSvc -StartupType Disabled
Set-Service -Name WaaSMedicSvc -StartupType Disabled
Write-Host "  [OK] Update services set to Disabled." -ForegroundColor Green

if (Test-Path "C:\Windows\SoftwareDistribution") {
    Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Cleared SoftwareDistribution cache." -ForegroundColor Green
}

Write-Host ""
Write-Host "[3/3] Disabling update scheduled tasks..." -ForegroundColor White
$Tasks =
    '\Microsoft\Windows\InstallService\*',
    '\Microsoft\Windows\UpdateOrchestrator\*',
    '\Microsoft\Windows\UpdateAssistant\*',
    '\Microsoft\Windows\WaaSMedic\*',
    '\Microsoft\Windows\WindowsUpdate\*',
    '\Microsoft\WindowsUpdate\*'

foreach ($Task in $Tasks) {
    Get-ScheduledTask -TaskPath $Task | Disable-ScheduledTask -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Update tasks disabled." -ForegroundColor Green

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  WINDOWS UPDATE IS NOW OFF" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[NOTE] Reboot recommended for all changes to apply." -ForegroundColor Yellow
