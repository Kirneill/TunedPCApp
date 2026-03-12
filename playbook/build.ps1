# Build the TUNEDPC Lightweight OS playbook (.apbx)
#
# An .apbx file is a ZIP archive (or 7z archive) containing:
#   - playbook.conf (XML metadata)
#   - Configuration/ (YAML task files)
#   - Executables/ (README and any bundled scripts)
#
# AME Wizard convention uses password "malte" for .apbx archives,
# but a plain ZIP also works. This script creates a plain ZIP
# for simplicity -- no 7-Zip dependency required.
#
# Usage: .\build.ps1
# Output: TUNEDPC-Lightweight-OS.apbx in the same directory

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputName = 'TUNEDPC-Lightweight-OS.apbx'
$outputPath = Join-Path $scriptDir $outputName
$tempZip = Join-Path $scriptDir 'temp-playbook.zip'

Write-Host '============================================'
Write-Host '  TUNEDPC Playbook Builder'
Write-Host '============================================'
Write-Host ''

# Remove old build artifacts
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
    Write-Host "[OK] Removed old $outputName"
}
if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force
}

# Verify required files exist
$requiredFiles = @(
    'playbook.conf',
    'Configuration\custom.yml',
    'Configuration\tunedpc\start.yml',
    'Configuration\tunedpc\services.yml',
    'Configuration\tunedpc\appx.yml',
    'Configuration\tunedpc\tasks.yml',
    'Configuration\tunedpc\registry.yml',
    'Configuration\tunedpc\privacy.yml',
    'Configuration\tunedpc\performance.yml',
    'Configuration\tunedpc\components.yml',
    'Configuration\tunedpc\cleanup.yml',
    'Executables\README.txt'
)

$missing = @()
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $scriptDir $file
    if (-not (Test-Path $fullPath)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Host '[ERROR] Missing required files:' -ForegroundColor Red
    foreach ($m in $missing) {
        Write-Host "  - $m" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[OK] All $($requiredFiles.Count) required files found."

# Create the ZIP archive from playbook contents
$items = @(
    (Join-Path $scriptDir 'playbook.conf'),
    (Join-Path $scriptDir 'Configuration'),
    (Join-Path $scriptDir 'Executables')
)

Write-Host '[INFO] Creating archive...'
Compress-Archive -Path $items -DestinationPath $tempZip -Force

# Rename .zip to .apbx
Rename-Item $tempZip $outputName

$fileSize = [math]::Round((Get-Item $outputPath).Length / 1KB, 1)

Write-Host ''
Write-Host '============================================'
Write-Host '  Build Complete!' -ForegroundColor Green
Write-Host '============================================'
Write-Host ''
Write-Host "  Output: $outputPath"
Write-Host "  Size:   ${fileSize} KB"
Write-Host ''
Write-Host '  To use:'
Write-Host '  1. Download AME Wizard from https://ameliorated.io'
Write-Host '  2. Open AME Wizard'
Write-Host "  3. Drag and drop $outputName into the window"
Write-Host '  4. Follow the on-screen prompts'
Write-Host ''

# Optional: Create a 7z version with password if 7-Zip is installed
$sevenZipPaths = @(
    'C:\Program Files\7-Zip\7z.exe',
    'C:\Program Files (x86)\7-Zip\7z.exe'
)

$sevenZip = $null
foreach ($path in $sevenZipPaths) {
    if (Test-Path $path) {
        $sevenZip = $path
        break
    }
}

if ($sevenZip) {
    $outputName7z = 'TUNEDPC-Lightweight-OS-encrypted.apbx'
    $outputPath7z = Join-Path $scriptDir $outputName7z

    if (Test-Path $outputPath7z) { Remove-Item $outputPath7z -Force }

    Write-Host '[INFO] 7-Zip found -- also building encrypted .apbx (password: malte)...'

    # 7z needs to be run from the playbook directory to get relative paths
    Push-Location $scriptDir
    & $sevenZip a -t7z -pmalte -mhe=on $outputPath7z playbook.conf Configuration Executables | Out-Null
    Pop-Location

    if (Test-Path $outputPath7z) {
        $fileSize7z = [math]::Round((Get-Item $outputPath7z).Length / 1KB, 1)
        Write-Host "[OK] Encrypted build: $outputPath7z (${fileSize7z} KB)" -ForegroundColor Green
    }
} else {
    Write-Host '[INFO] 7-Zip not found -- skipping encrypted build.'
    Write-Host '       Install 7-Zip to create password-protected .apbx files.'
}
