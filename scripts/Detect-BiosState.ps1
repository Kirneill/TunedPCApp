#Requires -RunAsAdministrator
# Detect-BiosState.ps1 -- Scans current system state for BIOS-related settings
# Returns JSON with detection results for the SENSEQUALITY BIOS Optimizer

$r = @{}

# --- CPU Info ---
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$r.cpuName = $cpu.Name
$r.cpuManufacturer = $cpu.Manufacturer

# --- Motherboard Info ---
$board = Get-CimInstance Win32_BaseBoard
$r.motherboardVendor = $board.Manufacturer
$r.motherboardModel = $board.Product

# --- BIOS Info ---
$bios = Get-CimInstance Win32_BIOS
$r.biosVendor = $bios.Manufacturer
$r.biosVersion = $bios.SMBIOSBIOSVersion
$r.isAmiBios = ($bios.Manufacturer -match 'American Megatrends|AMI')

# --- RAM / XMP Detection ---
$ram = Get-CimInstance Win32_PhysicalMemory
$firstStick = $ram | Select-Object -First 1
$r.ramCurrentSpeed = [int]$firstStick.ConfiguredClockSpeed
$r.ramRatedSpeed = [int]$firstStick.Speed
$r.ramSticks = $ram.Count
$r.ramTotalGB = [math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)

# XMP is likely enabled if current speed is close to or matches rated speed
if ($r.ramRatedSpeed -gt 0 -and $r.ramCurrentSpeed -gt 0) {
    $r.xmpLikelyEnabled = ($r.ramCurrentSpeed -ge ($r.ramRatedSpeed - 50))
} else {
    $r.xmpLikelyEnabled = $null
}

# --- VBS / Memory Integrity (HVCI) ---
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    if ($null -ne $dg) {
        $r.vbsRunning = ($dg.VirtualizationBasedSecurityStatus -eq 2)
        $r.memoryIntegrityEnabled = ($dg.SecurityServicesRunning -contains 2)
    } else {
        $r.vbsRunning = $false
        $r.memoryIntegrityEnabled = $false
    }
} catch {
    $r.vbsRunning = $null
    $r.memoryIntegrityEnabled = $null
}

# --- Memory Integrity via Registry (backup check) ---
try {
    $hvciReg = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -ErrorAction SilentlyContinue
    $r.memoryIntegrityRegistry = ($null -ne $hvciReg -and $hvciReg.Enabled -eq 1)
} catch {
    $r.memoryIntegrityRegistry = $null
}

# --- Hyper-V ---
try {
    $hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
    $r.hyperVInstalled = ($null -ne $hv -and $hv.State -eq 'Enabled')
} catch {
    $r.hyperVInstalled = $null
}

# --- Virtualization Enabled in Firmware ---
# Use WMI instead of systeminfo (systeminfo takes 15-30 seconds)
$r.virtualizationEnabled = [bool]$cpu.VirtualizationFirmwareEnabled

# --- Secure Boot ---
try {
    $r.secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
} catch {
    $r.secureBootEnabled = $null
}

# --- Resizable BAR (partial check via nvidia-smi) ---
# Parse BAR1 section specifically -- nvidia-smi has multiple "Total" lines
$r.rebarDetected = $null
try {
    $nvsmi = & 'nvidia-smi' -q 2>$null
    if ($nvsmi) {
        $lines = @($nvsmi)
        $bar1Idx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'BAR1 Memory Usage') {
                $bar1Idx = $i
                break
            }
        }
        if ($bar1Idx -ge 0) {
            $endIdx = [math]::Min($bar1Idx + 5, $lines.Count - 1)
            for ($j = $bar1Idx + 1; $j -le $endIdx; $j++) {
                if ($lines[$j] -match 'Total\s*:\s*(\d+)\s*MiB') {
                    $bar1Total = [int]$Matches[1]
                    $r.rebarDetected = ($bar1Total -gt 256)
                    $r.bar1TotalMB = $bar1Total
                    break
                }
            }
        }
    }
} catch {}

# Output as JSON
$r | ConvertTo-Json -Depth 2 -Compress
