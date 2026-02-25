#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables Windows Copilot via policy and removes the Copilot appx package.

.DESCRIPTION
    Applies 8 registry entries to disable Copilot at the policy level,
    then removes the Microsoft.Copilot appx package for the current user.

    WARNING: This may affect apps that rely on the Copilot integration
    (e.g. Edge sidebar, Windows Search AI features, Bing Chat).
#>

$ErrorActionPreference = 'SilentlyContinue'
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  DISABLE WINDOWS COPILOT" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/2] Applying Copilot policy registry entries..." -ForegroundColor White

try {
    # Disable Copilot via Windows policy
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1

    # Disable Copilot in current user scope
    New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1

    # Disable Copilot button on taskbar
    $AdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $AdvancedPath -Name "ShowCopilotButton" -Value 0 -Type DWord -Force

    # Disable Bing Search in Start Menu
    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord -Force

    # Disable Bing in Settings
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Type DWord -Value 1

    # Disable Edge Copilot sidebar (if Edge policy path exists)
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "CopilotCDPPageContext" -Type DWord -Value 0

    Write-Host "  [OK] Copilot policy entries applied." -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Some registry entries may not have applied: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/2] Removing Copilot appx package..." -ForegroundColor White

try {
    $copilotPkg = Get-AppxPackage -Name "Microsoft.Copilot" -ErrorAction SilentlyContinue
    if ($copilotPkg) {
        $copilotPkg | Remove-AppxPackage -ErrorAction Stop
        Write-Host "  [OK] Microsoft.Copilot package removed." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Microsoft.Copilot package not found (already removed or not installed)." -ForegroundColor DarkCyan
    }

    # Also try the Windows.Copilot provisioned package
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($provisioned) {
        $provisioned | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Copilot provisioned package(s) removed." -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Copilot package removal had issues: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  WINDOWS COPILOT DISABLED" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[NOTE] Some apps that use Copilot/Bing AI features may be affected." -ForegroundColor Yellow
Write-Host "[NOTE] Reboot recommended for all changes to apply." -ForegroundColor Yellow
