#Requires -RunAsAdministrator
<#
.SYNOPSIS
    RESTORE DEFAULTS - Undo all gaming optimizations
    Use this if you experience any issues after running the optimization scripts.

.DESCRIPTION
    This script:
    1. Lists all available backups in your Documents folder
    2. Lets you restore registry backups by double-clicking .reg files
    3. Provides instructions for restoring game config files
    4. Resets the power plan to Balanced (Windows default)
    5. Re-enables visual effects
    6. Re-enables fullscreen optimizations
#>

Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  RESTORE DEFAULTS - Gaming Optimization Reverter" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host ""

# Find all backup folders
$BackupFolders = Get-ChildItem -Path "$env:USERPROFILE\Documents" -Directory -Filter "GamingOptimization_Backup_*" | Sort-Object Name -Descending

if ($BackupFolders.Count -eq 0) {
    Write-Host "[INFO] No backup folders found. The optimizer may not have been run yet." -ForegroundColor DarkCyan
} else {
    Write-Host "[FOUND] $($BackupFolders.Count) backup(s) found:" -ForegroundColor Green
    foreach ($folder in $BackupFolders) {
        Write-Host "  $($folder.FullName)" -ForegroundColor White
        $regFiles = Get-ChildItem -Path $folder.FullName -Filter "*.reg"
        foreach ($reg in $regFiles) {
            Write-Host "    - $($reg.Name)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    Write-Host "  To restore Windows registry settings:" -ForegroundColor Yellow
    Write-Host "  Double-click any .reg file in the most recent backup folder" -ForegroundColor Yellow
    Write-Host "  and click Yes when prompted." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESTORING POWER PLAN TO BALANCED (Windows Default)" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Balanced plan GUID
$BalancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"
try {
    powercfg /setactive $BalancedGUID
    Write-Host "  [OK] Power plan set back to Balanced." -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not restore power plan. Set manually in Control Panel > Power Options." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESTORING WINDOWS VISUAL EFFECTS TO DEFAULT" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$VisualFXPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (Test-Path $VisualFXPath) {
    # VisualFXSetting 0 = Let Windows decide
    Set-ItemProperty -Path $VisualFXPath -Name "VisualFXSetting" -Value 0 -Type DWord -Force
    Write-Host "  [OK] Visual effects restored to 'Let Windows decide'." -ForegroundColor Green
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RE-ENABLING FULLSCREEN OPTIMIZATIONS" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$AppCompatPath = "HKCU:\System\GameConfigStore"
if (Test-Path $AppCompatPath) {
    # Restore fullscreen optimizations to Windows defaults
    Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_FSEBehaviorMode" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $AppCompatPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 0 -Type DWord -Force
    Write-Host "  [OK] Fullscreen optimizations re-enabled." -ForegroundColor Green
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESTORING MOUSE SETTINGS" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$MousePath = "HKCU:\Control Panel\Mouse"
if (Test-Path $MousePath) {
    # Windows default mouse settings (pointer precision enabled)
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed"      -Value "1" -Type String -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Value "6" -Type String -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Value "10" -Type String -Force
    Write-Host "  [OK] Mouse acceleration restored to Windows defaults." -ForegroundColor Green
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  GAME CONFIG FILE RESTORATION" -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To restore individual game configs, look for .bak files:" -ForegroundColor White
Write-Host ""
Write-Host "  Fortnite:" -ForegroundColor Cyan
$fnBak = Get-ChildItem "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\" -Filter "*.bak*" -ErrorAction SilentlyContinue
if ($fnBak) { foreach ($f in $fnBak) { Write-Host "    $($f.FullName)" -ForegroundColor White } }
else { Write-Host "    No Fortnite backup found." -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  Valorant:" -ForegroundColor Cyan
$valBak = Get-ChildItem "$env:LOCALAPPDATA\VALORANT\Saved\Config\Windows\" -Filter "*.bak*" -ErrorAction SilentlyContinue
if ($valBak) { foreach ($f in $valBak) { Write-Host "    $($f.FullName)" -ForegroundColor White } }
else { Write-Host "    No Valorant backup found." -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  To restore: Rename the .bak file to GameUserSettings.ini" -ForegroundColor DarkGray
Write-Host "  (Remove the .bak_YYYY-MM-DD_HH-mm extension)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "  *** REBOOT REQUIRED FOR ALL CHANGES TO TAKE EFFECT ***" -ForegroundColor Red
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host ""
