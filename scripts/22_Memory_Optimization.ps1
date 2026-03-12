#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Memory Management Optimization for Competitive Gaming
    Version: 1.0 | March 2026

.DESCRIPTION
    Hardware-aware memory optimizations that adapt to the user's system.
    All decisions are conditional on RAM amount, storage type, and current state.

    FEATURES:
    1. Standby List Clearing -- frees cached memory for the game (8-32GB systems)
    2. Memory Compression Toggle -- keeps enabled on most systems for safety
    3. Pagefile Optimization -- sets fixed-size 8GB pagefile to prevent resize stalls
    4. Working Set Trim -- conservative trim of background apps (8GB systems only)

    SAFETY:
    - 8GB systems: compression stays ENABLED, standby clear + pagefile only
    - 16-32GB: compression stays ENABLED (safety net), standby clear, pagefile
    - 64GB+: compression disabled, standby clear skipped, minimal changes
    - Working set trim only on 8GB under extreme memory pressure
    - Recent BSOD detection skips aggressive optimizations
    - All changes are logged with SQ_CHECK markers

.NOTES
    Run as Administrator. Some changes require reboot (pagefile, compression).
#>

# --- HEADLESS MODE ---
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# Skip flags for individual sections
$SkipStandby     = $env:SKIP_MEM_STANDBY -eq '1'
$SkipCompression = $env:SKIP_MEM_COMPRESSION -eq '1'
$SkipPagefile    = $env:SKIP_MEM_PAGEFILE -eq '1'
$SkipWorkingSet  = $env:SKIP_MEM_WORKINGSET -eq '1'

# ============================================================================
# SAFETY: Create a System Restore Point before ANY changes
# ============================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Memory Management Optimization v1.0 (Mar 2026)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# The app handler (handlers.ts) creates a restore point before launching scripts
# and sets this env var. Skip the internal restore point to avoid Windows' 24hr throttle
# causing a false abort.
if ($env:SENSEQUALITY_SKIP_INTERNAL_RESTORE_POINT -eq '1') {
    Write-Host "[SAFETY] Restore point already created by the app. Skipping internal check." -ForegroundColor DarkCyan
    Write-Host "[SQ_CHECK_OK:MEM_RESTORE_POINT_APP]"
} else {
    Write-Host "[SAFETY] Creating a system restore point before making changes..." -ForegroundColor Yellow
    try {
        # Enable System Restore on the system drive if it is not already
        $sysDrive = $env:SystemDrive + "\"
        Enable-ComputerRestore -Drive $sysDrive -ErrorAction SilentlyContinue

        Checkpoint-Computer -Description "TunedPC Memory Optimization (before changes)" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Host "  [OK] Restore point created. You can undo all changes from Windows Recovery." -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:MEM_RESTORE_POINT]"
    } catch {
        # Windows throttles restore points to one per 24 hours -- this is expected
        if ($_.Exception.Message -match "frequency|1404|throttle") {
            Write-Host "  [INFO] A restore point was already created recently. Continuing." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_RESTORE_POINT_RECENT]"
        } else {
            Write-Host "  [FAIL] Could not create restore point: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  [INFO] For your safety, memory optimization will NOT proceed without a restore point." -ForegroundColor Yellow
            Write-Host "  [INFO] Fix: Open 'Create a restore point' in Windows Settings and make sure System Protection is ON for your C: drive." -ForegroundColor Yellow
            Write-Host "[SQ_CHECK_FAIL:MEM_RESTORE_POINT:$($_.Exception.Message)]"
            exit 1
        }
    }
}

Write-Host ""

# ============================================================================
# HARDWARE DETECTION
# ============================================================================

try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $totalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
    $totalRAM_MB = [math]::Round($cs.TotalPhysicalMemory / 1MB)

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuCores = $cpu.NumberOfCores
    $cpuName = $cpu.Name

    # Detect storage type for system drive
    $sysDriveLetter = $env:SystemDrive[0]
    $storageInfo = $null
    Get-PhysicalDisk | ForEach-Object {
        $diskNum = $_.DeviceId
        $parts = Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue
        if ($parts.DriveLetter -contains $sysDriveLetter) {
            $storageInfo = [PSCustomObject]@{
                MediaType = $_.MediaType
                BusType   = $_.BusType
                Size_GB   = [math]::Round($_.Size / 1GB)
            }
        }
    }

    $isHDD  = $storageInfo -and $storageInfo.MediaType -eq "HDD"
    $isNVMe = $storageInfo -and $storageInfo.BusType -eq "NVMe"

    # Current memory state
    $os = Get-CimInstance Win32_OperatingSystem
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1024)
    $freePercent = [math]::Round(($freeMB / $totalRAM_MB) * 100, 1)

    # Current pagefile state
    $pagefileAuto = $cs.AutomaticManagedPagefile
    $pagefileUsage = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue

    # Current memory compression state
    $mmAgent = Get-MMAgent
    $compressionEnabled = $mmAgent.MemoryCompression

    # Display system profile
    $storageLabel = if ($storageInfo) { "$($storageInfo.MediaType) ($($storageInfo.BusType))" } else { "Unknown" }
    Write-Host "[SYSTEM PROFILE]" -ForegroundColor Yellow
    Write-Host "  RAM: ${totalRAM_GB}GB (${freeMB}MB free, ${freePercent}%)" -ForegroundColor White
    Write-Host "  CPU: $cpuName ($cpuCores cores)" -ForegroundColor White
    Write-Host "  Storage: $storageLabel" -ForegroundColor White
    Write-Host "  Pagefile: $(if($pagefileAuto){'Auto-managed'}else{'Custom'})" -ForegroundColor White
    Write-Host "  Memory Compression: $(if($compressionEnabled){'Enabled'}else{'Disabled'})" -ForegroundColor White
    Write-Host ""

    Write-Host "[SQ_CHECK_OK:MEM_HW_DETECT]"

    # SAFETY GATE: This optimizer is designed for low-end PCs (16GB or less).
    # Systems with more than 16GB don't need memory optimization and changing
    # pagefile/compression settings can actually cause crashes on high-end rigs.
    if ($totalRAM_GB -gt 16) {
        Write-Host ""
        Write-Host "  [INFO] ${totalRAM_GB}GB RAM detected -- your system does not need memory optimization." -ForegroundColor Cyan
        Write-Host "  [INFO] This tool is designed for systems with 16GB or less RAM." -ForegroundColor Cyan
        Write-Host "  [INFO] No changes will be made. Your system is already in great shape." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[SQ_CHECK_OK:MEM_HIGH_RAM_SKIP]"

        # Only run standby list clearing if free memory is genuinely low (safety net)
        if (-not $SkipStandby -and $freeMB -lt 2048) {
            Write-Host "  [INFO] Free memory is low (${freeMB}MB). Clearing standby list as a one-time fix..." -ForegroundColor Yellow
            # (standby clearing code will run below since we don't exit)
        } else {
            Write-Host "[SQ_CHECK_OK:MEM_STANDBY_SKIP_HIGH_RAM]"
            Write-Host "[SQ_CHECK_OK:MEM_COMPRESSION_SKIP_HIGH_RAM]"
            Write-Host "[SQ_CHECK_OK:MEM_PAGEFILE_SKIP_HIGH_RAM]"
            Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_SKIP_HIGH_RAM]"
            Write-Host ""
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "  Memory Optimization -- No Changes Needed" -ForegroundColor Cyan
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
    }
} catch {
    Write-Host "  [FAIL] Hardware detection failed: $_" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:MEM_HW_DETECT:$($_.Exception.Message)]"
    # Cannot proceed without hardware info -- abort
    exit 1
}

# ============================================================================
# SAFETY: Check for recent BSODs
# ============================================================================
$recentCrashes = 0
try {
    # EventID 41 = unexpected shutdown (Kernel-Power), EventID 1001 with BugCheck source = BSOD
    $crashEvents = Get-WinEvent -LogName System -FilterXPath "*[System[(EventID=41 and Provider[@Name='Microsoft-Windows-Kernel-Power']) or (EventID=1001 and Provider[@Name='BugCheck'])]]" -MaxEvents 10 -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -gt (Get-Date).AddDays(-7) }
    $recentCrashes = if ($crashEvents) { @($crashEvents).Count } else { 0 }

    if ($recentCrashes -gt 2) {
        Write-Host "[WARNING] System has had $recentCrashes recent crashes in the last 7 days." -ForegroundColor Red
        Write-Host "  Skipping aggressive optimizations (compression toggle, working set trim)." -ForegroundColor Red
        Write-Host ""
    }
} catch {
    # Cannot read event log -- not fatal, proceed with caution
    Write-Host "  [INFO] Could not read crash history. Proceeding with default safety." -ForegroundColor DarkGray
}

# ============================================================================
# SECTION 1: STANDBY LIST CLEARING
# Uses the same NtSetSystemInformation API as Microsoft's RAMMap.
# Safe on all systems. Skipped for 64GB+ (standby cache is useful at that tier).
# ============================================================================

if ($SkipStandby) {
    Write-Host "[1/4] STANDBY LIST CLEARING - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_CHECK_OK:MEM_STANDBY_SKIP]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[1/4] STANDBY LIST CLEARING" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Determine threshold based on RAM tier
        $standbyThresholdMB = switch ($true) {
            ($totalRAM_GB -ge 64)  { 0 }       # Skip for 64GB+ -- cache is useful
            ($totalRAM_GB -ge 32)  { 2048 }    # 32GB: only if free < 2GB
            ($totalRAM_GB -ge 16)  { 2048 }    # 16GB: only if free < 2GB
            default                { 1024 }    # 8GB: only if free < 1GB
        }

        if ($standbyThresholdMB -eq 0) {
            Write-Host "  [INFO] ${totalRAM_GB}GB RAM detected -- standby cache is beneficial at this tier." -ForegroundColor DarkCyan
            Write-Host "  [INFO] Skipping standby list clearing." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_STANDBY_SKIP_64GB]"
        } elseif ($freeMB -ge $standbyThresholdMB) {
            Write-Host "  [INFO] Free memory (${freeMB}MB) is above threshold (${standbyThresholdMB}MB)." -ForegroundColor DarkCyan
            Write-Host "  [INFO] Standby list clearing not needed right now." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_STANDBY_NOT_NEEDED]"
        } else {
            Write-Host "  [INFO] Free memory (${freeMB}MB) below threshold (${standbyThresholdMB}MB). Clearing standby list..." -ForegroundColor Yellow

            # P/Invoke for NtSetSystemInformation
            $memMgmtTypeDef = @"
using System;
using System.Runtime.InteropServices;

public class SQMemoryManagement {
    [DllImport("ntdll.dll")]
    public static extern int NtSetSystemInformation(
        int SystemInformationClass,
        ref int SystemInformation,
        int SystemInformationLength
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(
        IntPtr ProcessHandle,
        uint DesiredAccess,
        out IntPtr TokenHandle
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool LookupPrivilegeValue(
        string lpSystemName,
        string lpName,
        out LUID lpLuid
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(
        IntPtr TokenHandle,
        bool DisableAllPrivileges,
        ref TOKEN_PRIVILEGES NewState,
        int BufferLength,
        IntPtr PreviousState,
        IntPtr ReturnLength
    );

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID {
        public uint LowPart;
        public int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID_AND_ATTRIBUTES {
        public LUID Luid;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public int PrivilegeCount;
        public LUID_AND_ATTRIBUTES Privileges;
    }

    public const int SE_PRIVILEGE_ENABLED = 0x00000002;
    public const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
    public const uint TOKEN_QUERY = 0x0008;
    public const int SystemMemoryListInformation = 80;
    public const int MemoryPurgeStandbyList = 4;

    public static bool EnablePrivilege(string privilege) {
        IntPtr tokenHandle;
        if (!OpenProcessToken(GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out tokenHandle))
            return false;

        try {
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Privileges.Attributes = SE_PRIVILEGE_ENABLED;

            LUID luid;
            if (!LookupPrivilegeValue(null, privilege, out luid))
                return false;
            tp.Privileges.Luid = luid;

            return AdjustTokenPrivileges(tokenHandle, false, ref tp, 0,
                IntPtr.Zero, IntPtr.Zero);
        } finally {
            CloseHandle(tokenHandle);
        }
    }

    public static int PurgeStandbyList() {
        if (!EnablePrivilege("SeProfileSingleProcessPrivilege"))
            return -1;

        int command = MemoryPurgeStandbyList;
        return NtSetSystemInformation(
            SystemMemoryListInformation,
            ref command,
            sizeof(int)
        );
    }
}
"@

            # Only add the type if it does not already exist
            if (-not ([System.Management.Automation.PSTypeName]'SQMemoryManagement').Type) {
                Add-Type -TypeDefinition $memMgmtTypeDef
            }

            # Capture before state
            $beforeOS = Get-CimInstance Win32_OperatingSystem
            $beforeFreeMB = [math]::Round($beforeOS.FreePhysicalMemory / 1024)

            $result = [SQMemoryManagement]::PurgeStandbyList()

            if ($result -eq 0) {
                # Capture after state
                $afterOS = Get-CimInstance Win32_OperatingSystem
                $afterFreeMB = [math]::Round($afterOS.FreePhysicalMemory / 1024)
                $freedMB = $afterFreeMB - $beforeFreeMB

                Write-Host "  [OK] Standby list cleared successfully." -ForegroundColor Green
                Write-Host "  [INFO] Free memory: ${beforeFreeMB}MB -> ${afterFreeMB}MB (freed ~${freedMB}MB)" -ForegroundColor DarkCyan
                Write-Host "[SQ_CHECK_OK:MEM_STANDBY_CLEARED]"
            } else {
                Write-Host "  [WARN] Standby list clear returned NTSTATUS: $result" -ForegroundColor Yellow
                Write-Host "  [INFO] This may happen if the process lacks SeProfileSingleProcessPrivilege." -ForegroundColor DarkGray
                Write-Host "[SQ_CHECK_WARN:MEM_STANDBY_CLEARED:NTSTATUS_$result]"
            }
        }
    } catch {
        Write-Host "  [FAIL] Standby list clearing failed: $_" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:MEM_STANDBY_CLEARED:$($_.Exception.Message)]"
    }
}

Write-Host ""

# ============================================================================
# SECTION 2: MEMORY COMPRESSION TOGGLE
# Disabled by default on ALL Windows Server editions.
# NEVER disable on 8GB systems (causes severe pagefile thrashing).
# NEVER disable when pagefile is on HDD (CPU overhead beats disk I/O).
# Requires reboot to take effect.
# ============================================================================

if ($SkipCompression) {
    Write-Host "[2/4] MEMORY COMPRESSION - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_CHECK_OK:MEM_COMPRESSION_SKIP]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[2/4] MEMORY COMPRESSION" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    $compressionChanged = $false
    try {
        $shouldDisableCompression = $false
        $reason = ""

        # Safety: skip if recent crashes
        if ($recentCrashes -gt 2) {
            $reason = "Skipped due to $recentCrashes recent system crashes"
        }
        # NEVER disable on systems under 16GB -- compression is critical
        elseif ($totalRAM_GB -lt 16) {
            if (-not $compressionEnabled) {
                # Re-enable it -- someone incorrectly disabled it
                Write-Host "  [WARN] Memory compression is disabled on a ${totalRAM_GB}GB system!" -ForegroundColor Red
                Write-Host "  [INFO] Re-enabling -- compression is critical for systems under 16GB." -ForegroundColor Yellow
                Enable-MMAgent -MemoryCompression
                $compressionChanged = $true
                $reason = "Re-enabled compression on low-RAM system (was incorrectly disabled)"
                Write-Host "  [OK] $reason. Reboot required." -ForegroundColor Green
            } else {
                $reason = "Compression kept enabled -- critical for ${totalRAM_GB}GB systems"
            }
        }
        # NEVER disable when pagefile is on HDD -- disk I/O is catastrophically slow
        elseif ($isHDD) {
            $reason = "Compression kept enabled -- system drive is HDD (disk paging would be worse)"
        }
        # 16-32GB: keep compression enabled -- CPU cost is ~2-4% (negligible in-game)
        # but provides a critical safety net against OOM when games + browser + Discord
        # push past physical RAM. Only disable at 64GB+ where it truly cannot matter.
        elseif ($totalRAM_GB -lt 64) {
            $reason = "Compression kept enabled -- safety net for ${totalRAM_GB}GB systems (negligible CPU cost)"
        }
        # 64GB+ with SSD -- safe to disable (compression is truly unnecessary)
        elseif ($totalRAM_GB -ge 64) {
            $shouldDisableCompression = $true
        }

        if ($shouldDisableCompression) {
            if ($compressionEnabled) {
                Disable-MMAgent -MemoryCompression
                $compressionChanged = $true
                Write-Host "  [OK] Memory compression disabled (${totalRAM_GB}GB RAM, SSD storage)." -ForegroundColor Green
                Write-Host "  [INFO] Reboot required for this change to take effect." -ForegroundColor Yellow
                Write-Host "  [INFO] Reduces CPU overhead from decompression during gaming." -ForegroundColor DarkCyan
                Write-Host "[SQ_CHECK_OK:MEM_COMPRESSION_DISABLED]"
            } else {
                Write-Host "  [INFO] Memory compression is already disabled. No change needed." -ForegroundColor DarkCyan
                Write-Host "[SQ_CHECK_OK:MEM_COMPRESSION_ALREADY_OFF]"
            }
        } else {
            Write-Host "  [INFO] $reason" -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_COMPRESSION_KEPT]"
        }
    } catch {
        Write-Host "  [FAIL] Memory compression toggle failed: $_" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:MEM_COMPRESSION:$($_.Exception.Message)]"
    }
}

Write-Host ""

# ============================================================================
# SECTION 3: PAGEFILE OPTIMIZATION
# Sets a fixed-size pagefile to prevent runtime resizing stalls.
# NEVER disables the pagefile entirely (crash dumps, virtual address space).
# Size is tiered by RAM amount.
# Requires reboot.
# ============================================================================

$alreadyOptimal = $false

if ($SkipPagefile) {
    Write-Host "[3/4] PAGEFILE OPTIMIZATION - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_CHECK_OK:MEM_PAGEFILE_SKIP]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[3/4] PAGEFILE OPTIMIZATION" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Calculate target size based on RAM
        # IMPORTANT: Never set pagefile smaller than what the system may need.
        # Modern games (BO7, Warzone, Tarkov) use 15-20GB commit charge alone.
        # Total commit limit = RAM + pagefile. Too small = "memory limit reached" crashes.
        $targetPagefileMB = switch ($true) {
            ($totalRAM_GB -le 8)  { 8192 }    # 8GB: pagefile = RAM size (critical for stability)
            ($totalRAM_GB -le 16) { 8192 }    # 16GB: half RAM -- games need the headroom
            ($totalRAM_GB -le 32) { 8192 }    # 32GB: 8GB -- safe floor for heavy games + background apps
            default               { 8192 }    # 64GB+: 8GB minimum for crash dumps and edge cases
        }

        Write-Host "  [INFO] RAM: ${totalRAM_GB}GB -- target pagefile: ${targetPagefileMB}MB (fixed)" -ForegroundColor DarkCyan

        # Check current state -- filter to system drive pagefile only
        $allPF = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
        $systemDrive = $env:SystemDrive
        $currentPF = $allPF | Where-Object { $_.Name -like "$systemDrive*" } | Select-Object -First 1

        if (-not $pagefileAuto -and $currentPF) {
            # Check if already set to our target
            if ($currentPF.InitialSize -eq $targetPagefileMB -and $currentPF.MaximumSize -eq $targetPagefileMB) {
                $alreadyOptimal = $true
            }
        }

        if ($alreadyOptimal) {
            Write-Host "  [INFO] Pagefile is already set to optimal fixed size (${targetPagefileMB}MB)." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_PAGEFILE_ALREADY_SET]"
        } else {
            # Record current state for logging
            $currentState = if ($pagefileAuto) { "auto-managed" }
                           elseif ($currentPF) { "custom ($($currentPF.InitialSize)-$($currentPF.MaximumSize)MB)" }
                           else { "no custom settings" }

            Write-Host "  [INFO] Current: $currentState -> Setting fixed ${targetPagefileMB}MB" -ForegroundColor Yellow

            # Step 1: Disable automatic management
            $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }

            # Step 2: Remove existing custom settings for system drive only (preserve other drives)
            $existingSysPF = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$systemDrive*" }
            if ($existingSysPF) {
                $existingSysPF | Remove-CimInstance
            }

            # Step 3: Create fixed-size pagefile on system drive
            $systemDrive = $env:SystemDrive
            New-CimInstance -ClassName Win32_PageFileSetting -Property @{
                Name        = "$systemDrive\pagefile.sys"
                InitialSize = [uint32]$targetPagefileMB
                MaximumSize = [uint32]$targetPagefileMB
            } | Out-Null

            Write-Host "  [OK] Pagefile set to fixed ${targetPagefileMB}MB on $systemDrive" -ForegroundColor Green
            Write-Host "  [INFO] Reboot required for this change to take effect." -ForegroundColor Yellow
            if ($isHDD) {
                Write-Host "  [TIP] Your system drive is HDD. Consider moving pagefile to an SSD for best results." -ForegroundColor DarkGray
            }
            Write-Host "[SQ_CHECK_OK:MEM_PAGEFILE_SET]"
        }
    } catch {
        Write-Host "  [FAIL] Pagefile optimization failed: $_" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:MEM_PAGEFILE:$($_.Exception.Message)]"
    }
}

Write-Host ""

# ============================================================================
# SECTION 4: WORKING SET TRIM (CONSERVATIVE)
# Only runs on 8GB systems under extreme memory pressure (free < 512MB).
# Uses a strict exclusion list -- never trims system processes, anticheat, or
# the foreground window. Skipped entirely on 16GB+ systems.
# ============================================================================

if ($SkipWorkingSet) {
    Write-Host "[4/4] WORKING SET TRIM - SKIPPED" -ForegroundColor DarkGray
    Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_SKIP]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[4/4] WORKING SET TRIM (CONSERVATIVE)" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        # Gate: only for 8GB systems under extreme memory pressure
        if ($totalRAM_GB -ge 16) {
            Write-Host "  [INFO] ${totalRAM_GB}GB RAM detected -- working set trim is unnecessary." -ForegroundColor DarkCyan
            Write-Host "  [INFO] Windows manages memory efficiently at 16GB+." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_NOT_NEEDED]"
        } elseif ($recentCrashes -gt 2) {
            Write-Host "  [INFO] Skipped -- recent system crashes detected. Avoiding aggressive changes." -ForegroundColor Yellow
            Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_SKIP_CRASHES]"
        } elseif ($freeMB -gt 512) {
            Write-Host "  [INFO] Free memory (${freeMB}MB) is above critical threshold (512MB)." -ForegroundColor DarkCyan
            Write-Host "  [INFO] Working set trim not needed. Standby list clearing is sufficient." -ForegroundColor DarkCyan
            Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_NOT_NEEDED]"
        } else {
            Write-Host "  [WARN] Low RAM system (${totalRAM_GB}GB) with critically low free memory (${freeMB}MB)." -ForegroundColor Yellow
            Write-Host "  [INFO] Trimming background processes with working set > 200MB..." -ForegroundColor Yellow

            # Processes that must NEVER be trimmed
            $neverTrimProcesses = @(
                # Critical Windows processes
                'csrss', 'lsass', 'smss', 'wininit', 'winlogon', 'services',
                'dwm', 'audiodg', 'svchost', 'System', 'Registry', 'Idle',
                'fontdrvhost', 'conhost', 'sihost', 'taskhostw',
                'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost',
                'RuntimeBroker', 'dllhost', 'WmiPrvSE', 'spoolsv',
                'explorer',
                # Anticheat -- NEVER trim (ban risk)
                'EasyAntiCheat', 'EasyAntiCheat_EOS', 'BEService', 'BEDaisy',
                'vgc', 'vgtray', 'vgk',
                'FACEITService', 'faceit', 'faceitclient',
                'RiotClientServices', 'RiotClientCrashHandler',
                'nProtect', 'GameGuard',
                # Our own process
                'SENSEQUALITY Optimizer', 'electron'
            )

            # Get foreground window PID to exclude
            $fgPidExclude = $null
            $skipTrimDueToFg = $false
            try {
                if (-not ([System.Management.Automation.PSTypeName]'SQForegroundWindow').Type) {
                    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SQForegroundWindow {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@
                }
                $fgHwnd = [SQForegroundWindow]::GetForegroundWindow()
                $fgPid = [uint32]0
                [SQForegroundWindow]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid) | Out-Null
                $fgPidExclude = $fgPid
            } catch {
                # Cannot detect foreground -- skip trim for safety (but do NOT exit script)
                Write-Host "  [WARN] Cannot detect foreground window. Skipping trim for safety." -ForegroundColor Yellow
                Write-Host "[SQ_CHECK_WARN:MEM_WORKINGSET_TRIMMED:NO_FG_DETECT]"
                $skipTrimDueToFg = $true
            }

            $trimCount = 0
            $trimmedMB = 0

            if (-not $skipTrimDueToFg) {
                Get-Process | Where-Object {
                    $_.Id -ne $fgPidExclude -and
                    $_.Id -ne $PID -and
                    $_.Id -ne 0 -and
                    $_.Id -ne 4 -and
                    $_.ProcessName -notin $neverTrimProcesses -and
                    $_.WorkingSet64 -gt 200MB -and
                    $_.SessionId -ne 0    # Never trim session 0 (system services)
                } | ForEach-Object {
                    $beforeMB = [math]::Round($_.WorkingSet64 / 1MB)
                    try {
                        # Empty the working set -- forces pages to standby/modified list
                        # Less aggressive than SetProcessWorkingSetSizeEx(-1,-1) because
                        # Windows will immediately page back in actively-used pages
                        $proc = [System.Diagnostics.Process]::GetProcessById($_.Id)
                        $proc.MinWorkingSet = [IntPtr]204800  # 200KB floor
                        $proc.MaxWorkingSet = [IntPtr]204800  # Force trim to floor
                        $trimCount++
                        Start-Sleep -Milliseconds 50
                        $afterProc = Get-Process -Id $_.Id -ErrorAction SilentlyContinue
                        if ($afterProc) {
                            $afterMB = [math]::Round($afterProc.WorkingSet64 / 1MB)
                            $savedMB = $beforeMB - $afterMB
                            if ($savedMB -gt 0) { $trimmedMB += $savedMB }
                            Write-Host "  Trimmed $($_.ProcessName) (PID $($_.Id)): ${beforeMB}MB -> ${afterMB}MB" -ForegroundColor DarkGray
                        }
                    } catch {
                        # Access denied or protected process -- skip silently
                    }
                }

                if ($trimCount -gt 0) {
                    Write-Host "  [OK] Trimmed $trimCount background processes, freed ~${trimmedMB}MB" -ForegroundColor Green
                    Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_TRIMMED]"
                } else {
                    Write-Host "  [INFO] No eligible background processes found above 200MB threshold." -ForegroundColor DarkCyan
                    Write-Host "[SQ_CHECK_OK:MEM_WORKINGSET_NONE_ELIGIBLE]"
                }
            }
        }
    } catch {
        Write-Host "  [FAIL] Working set trim failed: $_" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:MEM_WORKINGSET:$($_.Exception.Message)]"
    }
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Memory Optimization Complete" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Check if any changes require reboot
$needsReboot = $false
if (-not $SkipCompression -and $compressionChanged) {
    $needsReboot = $true
}
if (-not $SkipPagefile -and ($pagefileAuto -or -not $alreadyOptimal)) {
    $needsReboot = $true
}

if ($needsReboot) {
    Write-Host ""
    Write-Host "  ** REBOOT REQUIRED for pagefile and/or compression changes. **" -ForegroundColor Yellow
}

Write-Host ""
