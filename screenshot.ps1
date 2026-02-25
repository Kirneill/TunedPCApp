Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Minimize all VS Code windows
$vscodeProcs = Get-Process -Name "Code" -ErrorAction SilentlyContinue
foreach ($v in $vscodeProcs) {
    if ($v.MainWindowHandle -ne 0) {
        [Win32]::ShowWindow($v.MainWindowHandle, 6)  # SW_MINIMIZE
    }
}

Start-Sleep -Milliseconds 300

# Focus the Electron window
$procs = Get-Process -Name "electron" -ErrorAction SilentlyContinue
foreach ($p in $procs) {
    if ($p.MainWindowHandle -ne 0) {
        [Win32]::ShowWindow($p.MainWindowHandle, 9)  # SW_RESTORE
        [Win32]::SetForegroundWindow($p.MainWindowHandle)
        Write-Host "Focused: $($p.MainWindowTitle)"
        break
    }
}

Start-Sleep -Milliseconds 1000

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bitmap.Save('F:\CLAUDE\APPGaming\app-screenshot.png')
$graphics.Dispose()
$bitmap.Dispose()
Write-Host 'Screenshot saved'
