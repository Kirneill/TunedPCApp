@echo off
:: ============================================================
:: GAMING OPTIMIZER - Admin Launcher
:: Double-click this file to run the master optimization script
:: ============================================================

:: Check if running as admin already
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running as Administrator - OK
    goto :run
) else (
    echo Requesting Administrator privileges...
    goto :elevate
)

:elevate
:: Re-launch with admin rights using PowerShell elevation trick
powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
exit /b

:run
:: Set execution policy for this session to allow the PS1 to run
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp000_MASTER_RUN_ALL.ps1"

if %errorLevel% neq 0 (
    echo.
    echo An error occurred. Exit code: %errorLevel%
    echo See the PowerShell window output for details.
    pause
)
