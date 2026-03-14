# Build the TUNEDPC Lightweight OS playbook (.apbx)
#
# An .apbx file is a 7z archive encrypted with password "malte" containing:
#   - playbook.conf (XML metadata)
#   - playbook.png (background image shown in AME Wizard)
#   - Configuration/ (YAML task files)
#   - Executables/ (README and any bundled scripts)
#
# The encryption prevents Windows Defender from scanning archive contents
# and flagging the playbook as malicious. This is the standard AME Wizard
# packaging format used by AtlasOS, ReviOS, and all other playbooks.
#
# Requires: 7-Zip (https://7-zip.org)
# Usage: .\build.ps1
# Output: TUNEDPC.apbx in the same directory

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputName = 'TUNEDPC.apbx'
$outputPath = Join-Path $scriptDir $outputName

Write-Host '============================================'
Write-Host '  TUNEDPC Playbook Builder'
Write-Host '============================================'
Write-Host ''

# Find 7-Zip (required for encrypted .apbx)
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

if (-not $sevenZip) {
    Write-Host '[ERROR] 7-Zip is required but not found.' -ForegroundColor Red
    Write-Host '        Download from https://7-zip.org and install, then re-run.' -ForegroundColor Red
    exit 1
}

Write-Host "[OK] 7-Zip found at $sevenZip"

# Remove old build artifacts
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
    Write-Host "[OK] Removed old $outputName"
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

# Build encrypted 7z archive with password "malte" and header encryption
Write-Host '[INFO] Creating encrypted .apbx archive...'

Push-Location $scriptDir
$archiveItems = @('playbook.conf', 'Configuration', 'Executables')
$playbookPng = Join-Path $scriptDir 'playbook.png'
if (Test-Path $playbookPng) {
    $archiveItems += 'playbook.png'
    Write-Host '[OK] playbook.png found -- will be included as background image.'
}
& $sevenZip a -t7z -pmalte -mhe=on $outputPath @archiveItems | Out-Null
$exitCode = $LASTEXITCODE
Pop-Location

if ($exitCode -ne 0 -or -not (Test-Path $outputPath)) {
    Write-Host '[ERROR] 7-Zip failed to create the archive.' -ForegroundColor Red
    exit 1
}

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
