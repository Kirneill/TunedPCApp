#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SENSEQUALITY Undo Deep Debloat -- Reverses all changes made by 30_Deep_Debloat.ps1

.DESCRIPTION
    This script reads the debloat manifest JSON created by 30_Deep_Debloat.ps1
    and restores every change to its original state:
    - Re-enables disabled services to their original startup type
    - Attempts to reinstall removed AppX packages (best-effort)
    - Re-enables disabled scheduled tasks
    - Restores registry values to their original state
    - Restores DISM capabilities (requires internet)
    - Restores NTFS filesystem settings
    - Removes Windows Update feature deferral

    If no manifest is found, the script exits with an error.

.NOTES
    Run as Administrator. Reboot after completion for all changes to take effect.
#>

# -----------------------------------------------------------------------------
# HEADLESS MODE: When run from SENSEQUALITY app, skip interactive prompts
# -----------------------------------------------------------------------------
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

$ErrorActionPreference = 'Stop'
$script:totalFailures = 0

$ManifestDir  = Join-Path $env:APPDATA 'SENSEQUALITY'
$ManifestPath = Join-Path $ManifestDir 'debloat-manifest.json'

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  SENSEQUALITY Undo Deep Debloat" -ForegroundColor Cyan
Write-Host "  Restores Windows to pre-debloat state" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# LOAD MANIFEST
# =============================================================================
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[0/8] LOADING MANIFEST" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

if (-not (Test-Path $ManifestPath)) {
    Write-Host "  [FAIL] No debloat manifest found at: $ManifestPath" -ForegroundColor Red
    Write-Host "  [INFO] Run 30_Deep_Debloat.ps1 first, or the manifest may have been deleted." -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_FAIL:UNDO_MANIFEST:No debloat manifest found]"
    exit 1
}

try {
    $manifestContent = [System.IO.File]::ReadAllText($ManifestPath, [System.Text.UTF8Encoding]::new($false))
    $Manifest = $manifestContent | ConvertFrom-Json
    Write-Host "  [OK] Manifest loaded. Created: $($Manifest.CreatedAt)" -ForegroundColor Green
    Write-Host "  [INFO] Backup directory: $($Manifest.BackupDir)" -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_OK:UNDO_MANIFEST]"
} catch {
    Write-Host "  [FAIL] Could not parse manifest: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_MANIFEST:$_]"
    exit 1
}


# =============================================================================
# SECTION 1: RESTORE SERVICES
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[1/8] RESTORE SERVICES" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $restoredSvcCount = 0
    $failedSvcCount   = 0

    if ($Manifest.Services -and $Manifest.Services.Count -gt 0) {
        foreach ($svc in $Manifest.Services) {
            try {
                $svcName      = $svc.Name
                $originalType = $svc.OriginalStart

                # Validate the service exists
                $existing = Get-Service -Name $svcName -ErrorAction Stop

                Set-Service -Name $svcName -StartupType $originalType -ErrorAction Stop
                $restoredSvcCount++
                Write-Host "  [OK] $svcName -> $originalType (restored)" -ForegroundColor Green
            } catch {
                $failedSvcCount++
                Write-Host "  [WARN] Could not restore $($svc.Name): $_" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [INFO] No services to restore." -ForegroundColor DarkCyan
    }

    Write-Host ""
    Write-Host "  [INFO] Services restored: $restoredSvcCount, failed: $failedSvcCount" -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_OK:UNDO_SERVICES:$restoredSvcCount restored]"
} catch {
    Write-Host "  [FAIL] Service restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_SERVICES:$_]"
}


# =============================================================================
# SECTION 2: RESTORE APPX PACKAGES (best-effort)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[2/8] RESTORE APPX PACKAGES (best-effort)" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    if ($Manifest.AppxRemoved -and $Manifest.AppxRemoved.Count -gt 0) {
        Write-Host "  [INFO] $($Manifest.AppxRemoved.Count) packages were removed during debloat." -ForegroundColor DarkCyan
        Write-Host "  [INFO] Attempting to re-register from system manifest..." -ForegroundColor DarkCyan

        $reregisteredCount = 0
        $failedAppxCount   = 0

        foreach ($appName in $Manifest.AppxRemoved) {
            try {
                # Try to find the package in the Windows store manifest cache
                $manifestPaths = Get-ChildItem -Path "C:\Program Files\WindowsApps\$appName*" -Filter 'AppxManifest.xml' -Recurse -ErrorAction SilentlyContinue
                if ($manifestPaths) {
                    $registered = $false
                    foreach ($mPath in $manifestPaths) {
                        try {
                            Add-AppxPackage -Register $mPath.FullName -DisableDevelopmentMode -ErrorAction Stop
                            $reregisteredCount++
                            $registered = $true
                            Write-Host "  [OK] Re-registered: $appName" -ForegroundColor Green
                            break
                        } catch {
                            # Try next manifest path
                        }
                    }
                    if (-not $registered) {
                        $failedAppxCount++
                        Write-Host "  [WARN] Could not re-register: $appName (may need manual reinstall)" -ForegroundColor Yellow
                    }
                } else {
                    $failedAppxCount++
                    Write-Host "  [SKIP] No local manifest for: $appName (reinstall from Microsoft Store)" -ForegroundColor DarkGray
                }
            } catch {
                $failedAppxCount++
                Write-Host "  [WARN] Could not restore $appName : $_" -ForegroundColor Yellow
            }
        }

        # Try resetting the Microsoft Store cache
        Write-Host "  [INFO] Resetting Microsoft Store cache..." -ForegroundColor DarkCyan
        try {
            Start-Process -FilePath 'wsreset.exe' -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
            Write-Host "  [OK] Store cache reset." -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not reset Store cache." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "  [INFO] Re-registered: $reregisteredCount, need manual reinstall: $failedAppxCount" -ForegroundColor DarkCyan
        Write-Host "[SQ_CHECK_WARN:UNDO_APPX:Some apps may need manual reinstall from Microsoft Store]"
    } else {
        Write-Host "  [INFO] No AppX packages to restore." -ForegroundColor DarkCyan
        Write-Host "[SQ_CHECK_OK:UNDO_APPX:No packages to restore]"
    }
} catch {
    Write-Host "  [FAIL] AppX restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_APPX:$_]"
}


# =============================================================================
# SECTION 3: RE-ENABLE SCHEDULED TASKS
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[3/8] RE-ENABLE SCHEDULED TASKS" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $restoredTaskCount = 0
    $failedTaskCount   = 0

    if ($Manifest.Tasks -and $Manifest.Tasks.Count -gt 0) {
        foreach ($task in $Manifest.Tasks) {
            try {
                $taskPath   = $task.TaskPath
                $taskFolder = Split-Path $taskPath -Parent
                $taskName   = Split-Path $taskPath -Leaf
                $origState  = $task.OriginalState

                # Only re-enable if it was not already disabled before debloat
                if ($origState -ne 'Disabled') {
                    Enable-ScheduledTask -TaskPath "$taskFolder\" -TaskName $taskName -ErrorAction Stop | Out-Null
                    $restoredTaskCount++
                    Write-Host "  [OK] Enabled: $taskName" -ForegroundColor Green
                } else {
                    Write-Host "  [SKIP] Was already disabled before debloat: $taskName" -ForegroundColor DarkGray
                }
            } catch {
                $failedTaskCount++
                Write-Host "  [WARN] Could not enable $(Split-Path $task.TaskPath -Leaf): $_" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [INFO] No tasks to restore." -ForegroundColor DarkCyan
    }

    Write-Host ""
    Write-Host "  [INFO] Tasks re-enabled: $restoredTaskCount, failed: $failedTaskCount" -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_OK:UNDO_TASKS:$restoredTaskCount re-enabled]"
} catch {
    Write-Host "  [FAIL] Task restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_TASKS:$_]"
}


# =============================================================================
# SECTION 4: RESTORE REGISTRY VALUES
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[4/8] RESTORE REGISTRY VALUES" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $restoredRegCount = 0
    $removedRegCount  = 0
    $failedRegCount   = 0

    if ($Manifest.Registry -and $Manifest.Registry.Count -gt 0) {
        foreach ($reg in $Manifest.Registry) {
            try {
                $regPath = $reg.Path
                $regName = $reg.Name
                $regOrig = $reg.Original
                $regType = $reg.Type

                if ($null -eq $regOrig) {
                    # Value did not exist before -- remove it
                    if (Test-Path $regPath) {
                        Remove-ItemProperty -Path $regPath -Name $regName -Force -ErrorAction SilentlyContinue
                        $removedRegCount++
                        Write-Host "  [OK] Removed (was new): $regName" -ForegroundColor Green
                    }
                } else {
                    # Restore original value
                    if (-not (Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    Set-ItemProperty -Path $regPath -Name $regName -Value $regOrig -Type $regType -Force
                    $restoredRegCount++
                    Write-Host "  [OK] Restored: $regName -> $regOrig" -ForegroundColor Green
                }
            } catch {
                $failedRegCount++
                Write-Host "  [WARN] Could not restore $($reg.Name): $_" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [INFO] No registry values to restore." -ForegroundColor DarkCyan
    }

    Write-Host ""
    Write-Host "  [INFO] Registry restored: $restoredRegCount, removed: $removedRegCount, failed: $failedRegCount" -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_OK:UNDO_REGISTRY:$restoredRegCount restored]"
} catch {
    Write-Host "  [FAIL] Registry restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_REGISTRY:$_]"
}


# =============================================================================
# SECTION 5: RESTORE DISM CAPABILITIES (requires internet)
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[5/8] RESTORE DISM CAPABILITIES" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $restoredCapCount = 0
    $failedCapCount   = 0

    if ($Manifest.DismRemoved -and $Manifest.DismRemoved.Count -gt 0) {
        Write-Host "  [INFO] Restoring $($Manifest.DismRemoved.Count) DISM capabilities (requires internet)..." -ForegroundColor DarkCyan

        foreach ($capName in $Manifest.DismRemoved) {
            try {
                Write-Host "  [INFO] Adding: $capName ..." -ForegroundColor DarkCyan
                Add-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null
                $restoredCapCount++
                Write-Host "  [OK] Restored: $capName" -ForegroundColor Green
            } catch {
                $failedCapCount++
                Write-Host "  [WARN] Could not restore $capName : $_" -ForegroundColor Yellow
                Write-Host "         Try manually: DISM /Online /Add-Capability /CapabilityName:$capName" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "  [INFO] DISM restored: $restoredCapCount, failed: $failedCapCount" -ForegroundColor DarkCyan

        if ($failedCapCount -gt 0) {
            Write-Host "[SQ_CHECK_WARN:UNDO_DISM:$failedCapCount capabilities could not be restored]"
        } else {
            Write-Host "[SQ_CHECK_OK:UNDO_DISM:$restoredCapCount restored]"
        }
    } else {
        Write-Host "  [INFO] No DISM capabilities to restore." -ForegroundColor DarkCyan
        Write-Host "[SQ_CHECK_OK:UNDO_DISM:No capabilities to restore]"
    }
} catch {
    Write-Host "  [FAIL] DISM restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_DISM:$_]"
}


# =============================================================================
# SECTION 6: RESTORE NTFS SETTINGS
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[6/8] RESTORE NTFS SETTINGS" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    if ($Manifest.NtfsOriginal) {
        $ntfs = $Manifest.NtfsOriginal

        if ($null -ne $ntfs.disable8dot3) {
            fsutil behavior set disable8dot3 $ntfs.disable8dot3 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] fsutil disable8dot3 restore returned exit code $LASTEXITCODE" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] 8.3 short names restored to: $($ntfs.disable8dot3)" -ForegroundColor Green
            }
        }

        if ($null -ne $ntfs.disablelastaccess) {
            fsutil behavior set disablelastaccess $ntfs.disablelastaccess | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] fsutil disablelastaccess restore returned exit code $LASTEXITCODE" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] Last-access timestamps restored to: $($ntfs.disablelastaccess)" -ForegroundColor Green
            }
        }

        if ($null -ne $ntfs.memoryusage) {
            fsutil behavior set memoryusage $ntfs.memoryusage | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] fsutil memoryusage restore returned exit code $LASTEXITCODE" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] NTFS memory usage restored to: $($ntfs.memoryusage)" -ForegroundColor Green
            }
        }

        Write-Host "[SQ_CHECK_OK:UNDO_NTFS]"
    } else {
        Write-Host "  [INFO] No NTFS settings to restore." -ForegroundColor DarkCyan
        Write-Host "[SQ_CHECK_OK:UNDO_NTFS:No NTFS settings to restore]"
    }
} catch {
    Write-Host "  [FAIL] NTFS restoration: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_NTFS:$_]"
}


# =============================================================================
# SECTION 7: REMOVE UPDATE DEFERRAL
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[7/8] REMOVE UPDATE DEFERRAL" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    if ($Manifest.UpdateDeferral -eq $true) {
        $wuPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

        if (Test-Path $wuPolicyPath) {
            # Remove the deferral value rather than the whole key (other policies may exist)
            Remove-ItemProperty -Path $wuPolicyPath -Name 'DeferFeatureUpdatesPeriodInDays' -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Feature update deferral removed." -ForegroundColor Green
        } else {
            Write-Host "  [INFO] WindowsUpdate policy key does not exist -- nothing to remove." -ForegroundColor DarkCyan
        }

        Write-Host "[SQ_CHECK_OK:UNDO_UPDATES]"
    } else {
        Write-Host "  [INFO] No update deferral was set." -ForegroundColor DarkCyan
        Write-Host "[SQ_CHECK_OK:UNDO_UPDATES:No deferral to remove]"
    }
} catch {
    Write-Host "  [FAIL] Update deferral removal: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_UPDATES:$_]"
}


# =============================================================================
# SECTION 8: CLEANUP AND SUMMARY
# =============================================================================
Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[8/8] CLEANUP AND SUMMARY" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    # Delete the manifest file after successful undo
    try {
        Remove-Item -Path $ManifestPath -Force -ErrorAction Stop
        Write-Host "  [OK] Manifest file deleted: $ManifestPath" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Could not delete manifest: $_" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "  UNDO DEEP DEBLOAT COMPLETE" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Restored items:" -ForegroundColor White
    Write-Host "    Services:           $($Manifest.Services.Count) entries processed" -ForegroundColor White
    Write-Host "    AppX packages:      $($Manifest.AppxRemoved.Count) attempted (some may need Store reinstall)" -ForegroundColor White
    Write-Host "    Scheduled tasks:    $($Manifest.Tasks.Count) entries processed" -ForegroundColor White
    Write-Host "    DISM capabilities:  $($Manifest.DismRemoved.Count) entries processed" -ForegroundColor White
    Write-Host "    Registry values:    $($Manifest.Registry.Count) entries processed" -ForegroundColor White
    Write-Host "    NTFS settings:      restored" -ForegroundColor White
    Write-Host "    Update deferral:    removed" -ForegroundColor White
    Write-Host ""

    if ($Manifest.BackupDir -and (Test-Path $Manifest.BackupDir)) {
        Write-Host "  Original backup still available at:" -ForegroundColor Yellow
        Write-Host "    $($Manifest.BackupDir)" -ForegroundColor Yellow
        Write-Host "  You can safely delete it after verifying everything works." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  REBOOT REQUIRED for all changes to take full effect." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[SQ_CHECK_OK:UNDO_COMPLETE]"
} catch {
    Write-Host "  [FAIL] Cleanup: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:UNDO_COMPLETE:$_]"
}
