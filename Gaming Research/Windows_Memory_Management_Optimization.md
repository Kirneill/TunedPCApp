# Windows Memory Management Optimization for Competitive Gaming

## Research Date: 2026-03-07
## Status: COMPLETE -- Ready for Implementation
## Risk Level: MIXED (Safe to Dangerous depending on hardware)

---

## EXECUTIVE SUMMARY

This document covers four Windows memory management optimizations for competitive gaming PCs. Each has different risk profiles depending on hardware configuration. The key finding is that **these optimizations are NOT one-size-fits-all** -- wrong settings on wrong hardware can cause BSODs, application crashes, and data loss.

**Critical Takeaway:** The script MUST detect hardware (RAM amount, storage type, CPU cores) and conditionally apply or skip each optimization. Never apply all four blindly.

| Feature | 8GB RAM | 16GB RAM | 32GB RAM | 64GB+ RAM |
|---------|---------|----------|----------|-----------|
| Standby List Clear | BENEFICIAL | BENEFICIAL | MARGINAL | SKIP |
| Memory Compression Off | DANGEROUS | SAFE | SAFE | SAFE |
| Pagefile Optimization | CRITICAL | RECOMMENDED | RECOMMENDED | OPTIONAL |
| Working Set Trim | RISKY | MARGINAL | MARGINAL | SKIP |

---

## 1. STANDBY LIST CLEARING

### What It Does

The Windows standby list is a cache of memory pages removed from process working sets but still in physical RAM. When a process needs a page that is on the standby list, Windows can return it instantly without disk I/O (a "soft page fault"). This is a performance feature.

However, a well-documented Windows 10/11 bug can cause the standby list to grow uncontrollably, consuming nearly all available RAM and preventing new allocations. This causes game stuttering because the game cannot get fresh memory pages even though most of the "used" RAM is just stale cache.

Clearing the standby list forces Windows to release these cached pages, making them immediately available as free memory.

**Source:** [Wagnardsoft ISLC](https://www.wagnardsoft.com/content/Download-Intelligent-standby-list-cleaner-ISLC-1037), [Microsoft Q&A on standby memory](https://learn.microsoft.com/en-us/answers/questions/3922350/would-it-be-possible-to-completely-remove-standby), [Overclock.net standby memory thread](https://www.overclock.net/threads/windows-memory-issue-standby-using-too-much-windows-auto-closing-games-and-apps-to-keep-standby-full.1805539/)

### How It Works Technically

The operation uses the undocumented `NtSetSystemInformation` API with `SystemMemoryListInformation` (information class 80) and a `SYSTEM_MEMORY_LIST_COMMAND` enum value:

```
Enum SYSTEM_MEMORY_LIST_COMMAND:
  0 = MemoryCaptureAccessedBits
  1 = MemoryCaptureAndResetAccessedBits
  2 = MemoryEmptyWorkingSets
  3 = MemoryFlushModifiedList
  4 = MemoryPurgeStandbyList        <-- This is what we want
  5 = MemoryPurgeLowPriorityStandbyList
```

**Required privilege:** `SeProfileSingleProcessPrivilege` (acquired via `AdjustTokenPrivileges`)
**Required elevation:** Administrator

This is the same API that Microsoft's own RAMMap tool (Sysinternals) uses under "Empty > Empty Standby List."

**Source:** [GitHub MemListMgr](https://github.com/fafalone/MemListMgr), [GitHub gist by bitshifter](https://gist.github.com/bitshifter/c87aa396446bbebeab29), [NtSetSystemInformation on NtDoc](https://ntdoc.m417z.com/ntsetsysteminformation)

### Hardware-Dependent Recommendations

| RAM | Recommendation | Rationale |
|-----|---------------|-----------|
| 8GB | BENEFICIAL -- clear when free < 1GB | Standby list bug hits hardest on low-RAM systems. Clearing prevents game stuttering from memory pressure. |
| 16GB | BENEFICIAL -- clear when free < 2GB | Still benefits from clearing, especially during heavy gaming sessions with browser/Discord open. |
| 32GB | MARGINAL -- clear when free < 2GB | Less likely to hit the bug. Clearing can still help during long sessions but the standby cache is actually useful at this tier. |
| 64GB+ | SKIP or very conservative | You almost never hit memory pressure. The standby list IS the cache. Clearing it removes useful cached data and forces re-reads from disk. |

**CPU:** Not a factor. The clear operation itself is instant.
**Storage:** SSD mitigates the impact of both the bug (faster page-in) and the clearing (faster re-caching). On HDD, the standby cache is MORE valuable because re-reading from disk is slow.

### Risk Analysis

| Risk | Severity | Details |
|------|----------|---------|
| BSOD | NONE | Clearing the standby list cannot cause a BSOD. It uses documented memory management operations. |
| Data loss | NONE | Standby pages are clean copies -- dirty pages are on the modified list, not the standby list. |
| Performance degradation | LOW-MEDIUM | On high-RAM systems, clearing removes useful cache. Programs may take slightly longer to re-access recently used files. |
| System instability | NONE | RAMMap (Microsoft's own tool) provides this exact functionality. |

**Reversibility:** Fully automatic. Windows immediately begins re-populating the standby list after clearing. No reboot needed. No persistent state change.

**Source:** [Microsoft Q&A on RAMMap safety](https://learn.microsoft.com/en-us/answers/questions/3804559/is-it-safe-to-use-rammap-application-to-truncate-e), [ElevenForum discussion](https://www.elevenforum.com/t/is-it-worth-it-clearing-standby-list.38462/)

### One-Time vs Periodic

For a gaming optimization app that runs once before a gaming session: **one-time clearing is the correct approach.**

ISLC (the popular tool) runs periodically (every 1-10 seconds) which is more aggressive. For our use case, a single clear before gaming is sufficient and safer. The gamer will build up a fresh game-relevant cache during play.

If implementing periodic clearing (not recommended for our use case):
- Interval: 120-300 seconds minimum
- Only trigger when free memory drops below threshold
- ISLC defaults: clear when free < 1024MB, standby limit at 50% of RAM

**Source:** [Joltfly ISLC Guide](https://joltfly.com/intelligent-standby-list-cleaner-settings-guide-max-fps/), [Wagnardsoft ISLC](https://www.wagnardsoft.com/intelligent-standby-list-cleaner)

### Implementation (PowerShell)

```powershell
# Standby list clearing via P/Invoke
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MemoryManagement {
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
        out long lpLuid
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

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public int PrivilegeCount;
        public long Luid;
        public int Attributes;
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

        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Attributes = SE_PRIVILEGE_ENABLED;

        long luid;
        if (!LookupPrivilegeValue(null, privilege, out luid))
            return false;
        tp.Luid = luid;

        return AdjustTokenPrivileges(tokenHandle, false, ref tp, 0,
            IntPtr.Zero, IntPtr.Zero);
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

# Check if clearing is warranted
$os = Get-CimInstance Win32_OperatingSystem
$freeMemMB = [math]::Round($os.FreePhysicalMemory / 1024)
$totalMemMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freePercent = [math]::Round(($freeMemMB / $totalMemMB) * 100, 1)

# Only clear if free memory is below threshold
$thresholdMB = if ($totalMemMB -le 8192) { 1024 }
               elseif ($totalMemMB -le 16384) { 2048 }
               elseif ($totalMemMB -le 32768) { 2048 }
               else { 0 }  # Skip for 64GB+

if ($thresholdMB -gt 0 -and $freeMemMB -lt $thresholdMB) {
    $result = [MemoryManagement]::PurgeStandbyList()
    if ($result -eq 0) {
        Write-Host "Standby list cleared successfully"
    } else {
        Write-Host "Failed to clear standby list (NTSTATUS: $result)"
    }
} else {
    Write-Host "Standby list clearing skipped (free: ${freeMemMB}MB, threshold: ${thresholdMB}MB)"
}
```

### Detection of Current State

```powershell
# Check current memory state
$os = Get-CimInstance Win32_OperatingSystem
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeMB = [math]::Round($os.FreePhysicalMemory / 1024)
$usedMB = $totalMB - $freeMB

# For standby-specific info, use performance counters
$standbyBytes = (Get-Counter '\Memory\Standby Cache Normal Priority Bytes').CounterSamples[0].CookedValue
$standbyMB = [math]::Round($standbyBytes / 1MB)

Write-Host "Total RAM: ${totalMB}MB"
Write-Host "Free RAM: ${freeMB}MB"
Write-Host "Standby Cache: ${standbyMB}MB"
```

### Rollback

No rollback needed. The standby list repopulates automatically and immediately after clearing. The operation is entirely transient.

---

## 2. MEMORY COMPRESSION TOGGLE

### What It Does

Windows 10/11 includes a memory compression feature (introduced in Windows 10 Threshold 2) that compresses infrequently accessed memory pages in RAM using the XPRESS4K algorithm (a variant of LZ77 optimized for speed). Instead of writing pages to the pagefile on disk, Windows compresses them to ~40-60% of original size and keeps them in a "compression store" in physical RAM.

**The tradeoff:** Uses CPU cycles for compression/decompression instead of disk I/O for paging. On low-RAM systems, this is a huge win (CPU is faster than disk). On high-RAM systems with fast SSDs, the CPU overhead is wasted because you rarely need to page anyway.

**Source:** [Windows OS Hub](https://woshub.com/memory-compression-process-high-usage-windows-10/), [Windows 10 Memory Compression Insider Hub](https://riverar.github.io/insiderhubcontent/memory_compression.html), [guru3D detailed info](https://forums.guru3d.com/threads/a-bit-detailed-info-about-memory-compression-in-win10.419260/)

### Compression Internals

- **Algorithm:** XPRESS4K (LZ77 variant), designed for speed over maximum compression ratio
- **Compression ratio:** Pages compress to ~30-50% of original size (315% ratio observed in testing)
- **Managed by:** SysMain service (formerly SuperFetch)
- **Location:** Compressed pages live in the System process working set, within an in-memory "compression store"
- **Trigger:** Memory Manager moves infrequently accessed pages from the modified list to the compression store instead of writing to pagefile
- **Requirement:** Pagefile must be enabled (minimum 16 MB) and SysMain service must be running
- **Default state:** Enabled on Windows 10/11 desktop; DISABLED on Windows Server (all versions)

**Source:** [Windows OS Hub](https://woshub.com/memory-compression-process-high-usage-windows-10/), [Microsoft Learn Xpress Compression](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-xca/a8b7cb0a-92a6-4187-a23b-5e14273b96f8)

### Hardware-Dependent Recommendations

| RAM | Recommendation | Rationale |
|-----|---------------|-----------|
| 8GB | KEEP ENABLED | Memory compression is critical on low-RAM systems. Without it, you will hit the pagefile constantly, which is far worse than CPU overhead. Disabling on 8GB can cause severe stuttering and out-of-memory crashes. |
| 16GB | SAFE TO DISABLE | The CPU overhead of compression/decompression can cause micro-stutters in games. With 16GB, you rarely need memory compression. Disabling reduces latency. |
| 32GB | DISABLE | Compression provides virtually no benefit. The CPU overhead is pure waste. Microsoft's own WinDev issue tracker has a 5+ year open bug about compression hurting 32GB+ systems. |
| 64GB+ | DISABLE | Same as 32GB but even more emphatic. You will never need compressed memory with this much RAM. |

**CPU considerations:**
- Under 8 cores: Compression overhead is more noticeable. Users with less than an 8-core CPU on low-RAM systems face a harder tradeoff.
- High core count (8+): Compression overhead is spread across cores, less impactful on single-threaded game performance.

**Storage considerations:**
- HDD: KEEP COMPRESSION ENABLED even on 16GB. The alternative (paging to HDD) is catastrophically slow. Compression CPU overhead is vastly preferable to HDD random I/O.
- SATA SSD: Standard recommendation applies.
- NVMe SSD: Disabling is even more beneficial because NVMe paging latency (~10-20 microseconds) is low enough that the rare page-in from disk is acceptable.

**Source:** [Microsoft WinDev Issue #35](https://github.com/microsoft/WinDev/issues/35), [GO-EUC Citrix benchmarks](https://www.go-euc.com/performance-value-of-memory-compression/), [XDA Developers](https://www.xda-developers.com/little-known-windows-feature-hurting-your-pcs-performance-heres-how-can-disable-it/)

### Measured Performance Impact

**GO-EUC Citrix CVAD benchmark (controlled lab test):**
- CPU overhead: No measurable difference in aggregate CPU utilization, but "more fluctuation" with compression enabled
- Memory savings: Only 0.64% difference in free memory (negligible)
- Pagefile usage: 3.48% with compression disabled vs 0.001% with compression enabled (dramatic)
- Conclusion: "In properly-sized environments, memory compression does not show any performance benefit"

**Microsoft WinDev Issue #35 (real-world reports):**
- VsChromium on 32GB system: 92% of CPU time spent in KiPageFault during decompression
- Search operations: 10x slower (0.5s normal vs 5.5s with compression)
- Blender rendering: 7.3% performance penalty with 24.5GB compressed
- Issue open since August 2020, unresolved as of late 2025

**Source:** [GO-EUC](https://www.go-euc.com/performance-value-of-memory-compression/), [Microsoft WinDev Issue #35](https://github.com/microsoft/WinDev/issues/35)

### Risk Analysis

| Risk | Severity | Details |
|------|----------|---------|
| BSOD | NONE | Disabling memory compression does not cause BSODs. |
| Out-of-memory crashes | HIGH (8GB) / NONE (16GB+) | On 8GB systems with heavy multitasking, disabling compression means more pagefile usage. If pagefile is also undersized, applications will crash. |
| Increased pagefile usage | MEDIUM (8GB) / LOW (16GB+) | Without compression, Windows falls back to paging to disk. On SSD this is acceptable; on HDD this causes severe stuttering. |
| System instability | NONE | Memory compression is disabled by default on all Windows Server versions. It is a well-tested configuration. |

**Reversibility:** Fully reversible. Run `Enable-MMAgent -MemoryCompression` and reboot. No data loss, no persistent side effects.

### Implementation (PowerShell)

```powershell
# Check current state
$mmAgent = Get-MMAgent
$compressionEnabled = $mmAgent.MemoryCompression

# Detect hardware
$totalRAM_GB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$cpuCores = (Get-CimInstance Win32_Processor).NumberOfCores

# Detect storage type for pagefile drive
$pagefileDrive = ($env:SystemDrive).TrimEnd(':')
$disk = Get-PhysicalDisk | Where-Object {
    $partitions = Get-Partition -DiskNumber $_.DeviceId -ErrorAction SilentlyContinue
    $partitions.DriveLetter -contains $pagefileDrive
}
$storageType = if ($disk) { $disk.MediaType } else { "Unknown" }
$busType = if ($disk) { $disk.BusType } else { "Unknown" }
$isHDD = $storageType -eq "HDD"

# Decision logic
$shouldDisable = $false
if ($totalRAM_GB -ge 32) {
    $shouldDisable = $true  # Always disable for 32GB+
} elseif ($totalRAM_GB -ge 16 -and -not $isHDD) {
    $shouldDisable = $true  # Disable for 16GB+ unless pagefile is on HDD
} elseif ($totalRAM_GB -lt 16) {
    $shouldDisable = $false  # NEVER disable for under 16GB
}

if ($shouldDisable -and $compressionEnabled) {
    Disable-MMAgent -MemoryCompression
    Write-Host "Memory compression disabled. Reboot required to take effect."
    # NOTE: Does NOT take effect until reboot
} elseif (-not $shouldDisable -and -not $compressionEnabled) {
    Enable-MMAgent -MemoryCompression
    Write-Host "Memory compression re-enabled (was incorrectly disabled). Reboot required."
}
```

### Detection of Current State

```powershell
# Check if memory compression is enabled
(Get-MMAgent).MemoryCompression  # Returns True or False

# Check current compression stats (requires admin)
$proc = Get-Process -Id 4  # System process
Write-Host "System process working set: $([math]::Round($proc.WorkingSet64 / 1MB)) MB"
# A large System working set often indicates active compression
```

### Rollback

```powershell
Enable-MMAgent -MemoryCompression
Restart-Computer  # Required for change to take effect
```

**IMPORTANT:** Changes require a reboot to take effect. The script should note this to the user and NOT attempt to reboot automatically.

---

## 3. PAGEFILE OPTIMIZATION

### What It Does

The pagefile (pagefile.sys) is virtual memory on disk that extends physical RAM. When RAM is full, Windows pages infrequently used memory to the pagefile. The pagefile also serves as backing for crash dumps.

By default, Windows manages the pagefile size automatically ("System managed"). This works but can result in:
1. Dynamic resizing during gameplay (causes stuttering from I/O)
2. Fragmented pagefile (on HDDs, causes slow random access)
3. Suboptimal size (too small causes OOM, too large wastes SSD space)

Setting a fixed pagefile size (initial = maximum) prevents resizing during gameplay and keeps the file contiguous.

**Source:** [Microsoft Learn pagefile sizing](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows), [Tom's Hardware pagefile guide](https://www.tomshardware.com/news/how-to-manage-virtual-memory-pagefile-windows-10,36929.html)

### Microsoft's Official Guidance

From the Microsoft Learn article (updated 2026-02-12):

**System-managed defaults:**
- Minimum: Varies based on usage history, RAM / 8 (max 32 GB), and crash dump settings
- Maximum: 3x RAM or 4 GB, whichever is larger (limited to volume size / 8)

**Crash dump requirements:**

| Dump Type | Minimum Pagefile Size |
|-----------|----------------------|
| Small memory dump (256 KB) | 1 MB |
| Kernel memory dump | Depends on kernel virtual memory |
| Complete memory dump | 1x RAM + 257 MB |
| Automatic memory dump (default) | Depends on kernel virtual memory |

**The system commit limit** = physical RAM + all pagefiles combined. If no pagefile exists, the commit limit is slightly less than physical RAM, which means Windows cannot over-commit memory AT ALL.

**Source:** [Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows)

### Hardware-Dependent Recommendations

**NEVER disable the pagefile entirely.** Even on 64GB+ systems:
- Some applications allocate virtual address space they never use (games are notorious for this)
- Without a pagefile, Windows cannot write crash dumps on BSOD
- Some applications explicitly check for pagefile and refuse to run
- Memory leaks in background apps will crash the system faster without pagefile overflow space

**Source:** [Puget Systems pagefile guide](https://www.pugetsystems.com/support/guides/what-is-pagefile-and-how-to-adjust-it-2243/), [Linus Tech Tips forum](https://linustechtips.com/topic/1373108-should-i-disable-page-file-on-windows-if-i-have-plenty-of-ram/), [Tom's Hardware forum](https://forums.tomshardware.com/threads/can-i-disable-virtual-memory.3878495/)

| RAM | Fixed Pagefile Size | Rationale |
|-----|-------------------|-----------|
| 8GB | 8192 MB (8 GB) | Equal to RAM. Critical for stability. Games like Tarkov require 8GB minimum and will pagefile heavily. |
| 16GB | 8192 MB (8 GB) | Half of RAM. Enough for crash dumps and occasional page-outs. Most games won't exceed 16GB total. |
| 32GB | 4096 MB (4 GB) | Minimal but present. Needed for crash dumps (kernel dump) and edge-case applications. |
| 64GB+ | 4096 MB (4 GB) | Minimal. Crash dump support only. Almost no gaming workload will touch it. |

**Why fixed size (initial = maximum):**
- Prevents runtime resizing (which causes I/O stalls)
- Prevents fragmentation on HDDs
- On SSDs, fragmentation doesn't matter but resizing still causes brief stalls
- Fixed size = predictable behavior

### Storage Considerations

| Storage Type | Latency | Random 4K IOPS | Pagefile Impact |
|-------------|---------|----------------|-----------------|
| HDD (7200 RPM) | ~14 ms | ~190 IOPS | TERRIBLE. Any pagefile hit = massive stutter. Prioritize large pagefile + keep memory compression ON. |
| SATA SSD | ~100 us | ~70,000 IOPS | Good. Pagefile hits are barely noticeable. |
| NVMe SSD | ~10-20 us | ~500,000+ IOPS | Excellent. Pagefile is nearly transparent. |

**Recommendation:** Always place pagefile on fastest available drive. If system drive is HDD, consider placing pagefile on a secondary SSD if available.

**Source:** [Tom's Hardware pagefile SSD config](https://forums.tomshardware.com/threads/pagefile-with-pcie-nvme-and-sata-ssd-config.3576869/), [Enterprise Storage Forum NVMe speeds](https://www.enterprisestorageforum.com/hardware/how-fast-are-nvme-speeds/)

### Risk Analysis

| Risk | Severity | Details |
|------|----------|---------|
| BSOD from too-small pagefile | LOW | Windows will warn before crashing. Kernel dump may not be captured. |
| Application crashes | MEDIUM | If pagefile is disabled and RAM is exhausted, applications crash with no warning. Games are particularly susceptible. |
| Data loss | LOW | Only if pagefile is disabled AND RAM exhausts AND application has unsaved data. The pagefile PREVENTS data loss by providing overflow space. |
| Disk wear (SSD) | NEGLIGIBLE | Modern SSDs have TBW ratings far exceeding pagefile write patterns. A 512GB NVMe will outlast its usefulness long before pagefile writes matter. |

**Source:** [XDA Developers SSD endurance](https://www.xda-developers.com/i-doubled-my-ssd-endurance-by-changing-these-windows-settings/)

**Reversibility:** Fully reversible. Set back to "System managed" via PowerShell or System Properties. Reboot required.

### Implementation (PowerShell)

```powershell
# ---- DETECT CURRENT STATE ----
$cs = Get-CimInstance Win32_ComputerSystem
$isAutoManaged = $cs.AutomaticManagedPagefile

# Current pagefile usage
$pfu = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
if ($pfu) {
    Write-Host "Current pagefile: $($pfu.Name)"
    Write-Host "Allocated: $($pfu.AllocatedBaseSize) MB"
    Write-Host "Current usage: $($pfu.CurrentUsage) MB"
    Write-Host "Peak usage: $($pfu.PeakUsage) MB"
}
Write-Host "Auto-managed: $isAutoManaged"

# ---- CALCULATE OPTIMAL SIZE ----
$totalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
$targetSizeMB = switch ($true) {
    ($totalRAM_GB -le 8)  { 8192 }    # 8 GB
    ($totalRAM_GB -le 16) { 8192 }    # 8 GB
    ($totalRAM_GB -le 32) { 4096 }    # 4 GB
    default               { 4096 }    # 4 GB
}

# ---- APPLY ----
# Step 1: Disable automatic management
$cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }

# Step 2: Remove existing custom settings (if any)
$existingPF = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
if ($existingPF) {
    $existingPF | Remove-CimInstance
}

# Step 3: Create fixed-size pagefile on system drive
$systemDrive = $env:SystemDrive
New-CimInstance -ClassName Win32_PageFileSetting -Property @{
    Name = "$systemDrive\pagefile.sys"
    InitialSize = $targetSizeMB
    MaximumSize = $targetSizeMB
}

Write-Host "Pagefile set to fixed ${targetSizeMB}MB on $systemDrive"
Write-Host "Reboot required for changes to take effect."
```

### Detection of Current State

```powershell
# Is pagefile auto-managed?
(Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile

# What is current pagefile configuration?
Get-CimInstance Win32_PageFileSetting | Select-Object Name, InitialSize, MaximumSize

# What is current pagefile usage?
Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

# What storage type hosts the pagefile?
$sysDriveLetter = $env:SystemDrive[0]
Get-PhysicalDisk | ForEach-Object {
    $diskNum = $_.DeviceId
    $parts = Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue
    if ($parts.DriveLetter -contains $sysDriveLetter) {
        [PSCustomObject]@{
            DiskNumber = $diskNum
            MediaType  = $_.MediaType
            BusType    = $_.BusType
            Size_GB    = [math]::Round($_.Size / 1GB)
        }
    }
}
```

### Rollback

```powershell
# Restore to system-managed
$cs = Get-CimInstance Win32_ComputerSystem
$cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $true }

# Remove custom settings
Get-CimInstance Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue

Write-Host "Pagefile restored to system-managed. Reboot required."
```

---

## 4. PROCESS WORKING SET TRIM

### What It Does

Every running process has a "working set" -- the set of memory pages currently resident in physical RAM. Trimming a process's working set (via `SetProcessWorkingSetSizeEx` with both parameters set to -1) forces Windows to remove as many pages as possible from that process's physical memory. The pages are moved to the modified list (eventually written to pagefile) or standby list (if clean).

The theory: trim background processes to free RAM for the foreground game.

The reality: **this is the most controversial and potentially harmful of the four optimizations.** Multiple authoritative sources (Microsoft, Bitsum/Process Lasso creator, Windows Internals experts) warn against aggressive working set trimming.

**Source:** [Microsoft Learn SetProcessWorkingSetSizeEx](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-setprocessworkingsetsizeex), [Guy Leech's Blog](https://guyrleech.wordpress.com/tag/memory-trimming/), [Bitsum virtual memory facts](https://bitsum.com/virtual_memory_facts_and_memory_optimizer_scams.php)

### How It Works Technically

```
SetProcessWorkingSetSizeEx(hProcess, (SIZE_T)-1, (SIZE_T)-1, 0)
```

When both min and max are set to -1: "the function removes as many pages as possible from the working set of the specified process."

**Required access rights:** `PROCESS_SET_QUOTA` on the target process handle.
**Required privilege:** Runs as admin to open other processes.

This is the exact mechanism used by "RAM cleaners" and "memory optimizers" -- tools that are widely considered [snake oil by security researchers and Microsoft](https://www.malwarebytes.com/blog/news/2015/06/digital-snake-oil).

**Source:** [Microsoft Learn SetProcessWorkingSetSizeEx](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-setprocessworkingsetsizeex)

### The Problem: Hard Page Faults

When you trim a process's working set, those pages are removed from RAM. When the process needs them again (which it will, often within seconds), it triggers a **hard page fault** -- the page must be read back from the pagefile on disk. This is:

- **100-1000x slower than a soft page fault** (which just reclaims from standby list)
- **Cascading**: if you trim 20 processes, all 20 will fight to page back in simultaneously
- **Counterproductive**: you freed memory momentarily, but the re-paging storm uses MORE total I/O than if you had left the processes alone

Guy Leech (author of the most widely-used memory trimming PowerShell script) describes this as "akin to scalping the victim" and warns: "the scalped processes quickly require some of this memory which has potentially been paged out which can lead to excessive hard page faults."

**Source:** [Guy Leech's blog](https://guyrleech.wordpress.com/tag/memory-trimming/), [Guy Leech memory control script](https://guyrleech.wordpress.com/2018/03/15/memory-control-script-reclaiming-unused-memory/)

Bitsum (Process Lasso) adds: "Paging out one or more processes in its entirety has downsides. First, it causes some percent of the pages to be immediately recovered when referenced again, incurring a re-load penalty." And: "RAM fragmentation claims are mythical because RAM is random-access storage with no seek time."

**Source:** [Bitsum virtual memory facts](https://bitsum.com/virtual_memory_facts_and_memory_optimizer_scams.php)

### Hardware-Dependent Recommendations

| RAM | Recommendation | Rationale |
|-----|---------------|-----------|
| 8GB | RISKY -- only if memory pressure is extreme | On 8GB, you genuinely might need the memory. But the page fault storm from trimming can make things worse, not better. Only trim if specific known-bloated processes are identified. |
| 16GB | MARGINAL -- skip in most cases | With 16GB, memory pressure from background processes is uncommon. Trimming provides negligible benefit and risks page fault storms. |
| 32GB | SKIP | You have plenty of RAM. Trimming background processes is pointless -- Windows already manages this efficiently. |
| 64GB+ | SKIP | Absolutely no benefit. Working set trimming on 64GB is pure snake oil. |

**CPU:** More cores = less impact from page fault handling overhead. But the I/O wait from hard page faults is not mitigated by CPU speed.
**Storage:** On NVMe, hard page faults from trimming resolve faster (~20us). On HDD, each hard page fault costs ~14ms -- trimming 100 processes could create thousands of page faults, each taking 14ms. This is catastrophic.

### Processes NEVER Safe to Trim

The following processes should NEVER have their working set trimmed:

| Process | Reason |
|---------|--------|
| The game itself | Obviously. Trimming the foreground game would cause massive stuttering. |
| csrss.exe | Client/Server Runtime Subsystem. Critical system process. Handles console windows, thread creation. Trimming can cause UI freezes. |
| lsass.exe | Local Security Authority. Handles authentication. Trimming can cause login failures and security issues. |
| smss.exe | Session Manager. Parent of all sessions. Trimming can cause session instability. |
| wininit.exe | Windows initialization. Critical boot process. |
| dwm.exe | Desktop Window Manager. Handles all window compositing. Trimming causes visual glitches and stuttering. |
| audiodg.exe | Windows Audio Device Graph. Trimming causes audio crackling and dropout. |
| svchost.exe | Service Host. Trimming the wrong svchost instance can affect networking, Windows Update, COM+, and dozens of other services. |
| Any anticheat (EasyAntiCheat, BattlEye, vgc.exe, FACEIT) | Anticheat processes monitor memory integrity. Trimming their working set may trigger false positive detections or kicks. |
| System (PID 4) | Kernel process. Cannot meaningfully be trimmed from userspace. |
| Registry (if present) | Windows Registry process in newer builds. |

**Source:** [Microsoft Learn Working Set](https://learn.microsoft.com/en-us/windows/win32/memory/working-set), [Microsoft TechCommunity Working Set Trimming](https://techcommunity.microsoft.com/t5/ask-the-performance-team/prf-memory-management-working-set-trimming/ba-p/373758), [Bitsum SmartTrim](https://bitsum.com/smarttrim/)

### Processes POTENTIALLY Safe to Trim (with caveats)

Only if memory pressure is genuinely high and only background non-interactive processes:

- Browser processes (chrome.exe, msedge.exe) -- but only background tab processes
- Discord (but may cause voice call issues)
- Spotify
- Steam client (but NOT steam game processes)
- Non-essential Windows Store apps
- OBS Studio (only if not recording)

Even these should only be trimmed conservatively (not to -1 but to a reasonable floor like 50MB).

### Risk Analysis

| Risk | Severity | Details |
|------|----------|---------|
| Game stuttering | HIGH | If game process or dwm.exe is trimmed, immediate stuttering. If many background processes are trimmed simultaneously, the page-in storm competes with the game for I/O. |
| Application crashes | MEDIUM | Aggressive trimming of services can cause them to fail when they cannot re-acquire memory fast enough. |
| Audio issues | HIGH | Trimming audiodg.exe causes crackling, pops, or complete audio dropout. |
| Anticheat bans/kicks | HIGH | Memory manipulation of anticheat processes may trigger detection. This is a BAN RISK. |
| System instability | MEDIUM | Trimming critical system processes (csrss, lsass, smss) can cause hangs, login failures, or session crashes. |
| BSOD | LOW | Unlikely from userspace trimming, but trimming critical kernel-supporting processes under extreme memory pressure has been reported to cause instability leading to bugchecks. |

**Reversibility:** Automatic. Trimmed processes immediately begin rebuilding their working sets as they access memory. No persistent state change. No reboot needed.

### Implementation Recommendation: DO NOT IMPLEMENT (or implement conservatively)

Given the risk profile, I recommend one of two approaches:

**Option A: Skip entirely.** The standby list clearing (Feature 1) achieves most of the same benefit (freeing RAM for the game) without the page fault storm. Standby list clearing removes CACHE, not ACTIVE PROCESS MEMORY, which is fundamentally safer.

**Option B: Conservative implementation with strict exclusion list.** Only trim processes that are:
1. Not the foreground window
2. Not on the exclusion list
3. Using more than 200MB of working set
4. Not a system process (session 0)

```powershell
# CONSERVATIVE working set trim -- USE WITH EXTREME CAUTION
# Only trim specific known-safe background processes

$neverTrimProcesses = @(
    'csrss', 'lsass', 'smss', 'wininit', 'winlogon', 'services',
    'dwm', 'audiodg', 'svchost', 'System', 'Registry',
    'fontdrvhost', 'conhost', 'sihost', 'taskhostw',
    'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost',
    'RuntimeBroker', 'dllhost', 'WmiPrvSE',
    # Anticheat - NEVER TRIM
    'EasyAntiCheat', 'BEService', 'BEDaisy', 'vgc', 'vgtray',
    'FACEITService', 'faceit', 'RiotClientServices',
    # Game processes - detected dynamically
    'explorer'  # Windows shell
)

# Only proceed if RAM is below 16GB AND free memory is critically low
$totalRAM_GB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$os = Get-CimInstance Win32_OperatingSystem
$freeMB = [math]::Round($os.FreePhysicalMemory / 1024)

if ($totalRAM_GB -ge 16 -or $freeMB -gt 1024) {
    Write-Host "Working set trim skipped -- sufficient RAM available."
    return
}

# Get foreground window process to exclude
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class ForegroundWindow {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    }
"@

$fgHwnd = [ForegroundWindow]::GetForegroundWindow()
$fgPid = 0
[ForegroundWindow]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid) | Out-Null

$trimCount = 0
$trimmedMB = 0

Get-Process | Where-Object {
    $_.Id -ne $fgPid -and
    $_.Id -ne $PID -and
    $_.ProcessName -notin $neverTrimProcesses -and
    $_.WorkingSet64 -gt 200MB -and
    $_.SessionId -ne 0  # Don't trim session 0 (system services)
} | ForEach-Object {
    $beforeMB = [math]::Round($_.WorkingSet64 / 1MB)
    try {
        # Trim to minimum, not to -1 (less aggressive)
        $_.MinWorkingSet = 204800  # 200KB (20 pages)
        $trimCount++
        $afterMB = [math]::Round($_.WorkingSet64 / 1MB)
        $savedMB = $beforeMB - $afterMB
        if ($savedMB -gt 0) { $trimmedMB += $savedMB }
        Write-Host "  Trimmed $($_.ProcessName) (PID $($_.Id)): ${beforeMB}MB -> ${afterMB}MB"
    } catch {
        # Access denied or protected process -- skip silently
    }
}

Write-Host "Trimmed $trimCount processes, freed ~${trimmedMB}MB"
```

### Detection of Current State

```powershell
# Show top memory consumers (potential trim targets)
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 |
    Format-Table ProcessName, Id, @{N='WorkingSet_MB';E={[math]::Round($_.WorkingSet64/1MB)}},
    @{N='Private_MB';E={[math]::Round($_.PrivateMemorySize64/1MB)}}
```

### Rollback

No rollback needed. Working sets rebuild automatically as processes access memory. The trimming effect is entirely transient.

---

## COMBINED IMPLEMENTATION STRATEGY

### Execution Order

The four optimizations should be applied in this specific order:

1. **Detect hardware** (RAM, storage type, CPU cores) -- FIRST
2. **Pagefile optimization** (if conditions met) -- requires reboot, so flag it
3. **Memory compression toggle** (if conditions met) -- requires reboot, so flag it
4. **Standby list clearing** (if conditions met) -- immediate effect
5. **Working set trim** (if conditions met) -- immediate effect, do LAST

### Hardware Detection Script

```powershell
# ---- COMPREHENSIVE HARDWARE DETECTION ----

# RAM
$cs = Get-CimInstance Win32_ComputerSystem
$totalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
$totalRAM_MB = [math]::Round($cs.TotalPhysicalMemory / 1MB)

# CPU
$cpu = Get-CimInstance Win32_Processor
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors
$cpuName = $cpu.Name

# Storage type for system drive
$sysDriveLetter = $env:SystemDrive[0]
$storageInfo = Get-PhysicalDisk | ForEach-Object {
    $diskNum = $_.DeviceId
    $parts = Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue
    if ($parts.DriveLetter -contains $sysDriveLetter) {
        [PSCustomObject]@{
            MediaType = $_.MediaType    # SSD, HDD, Unspecified
            BusType   = $_.BusType      # NVMe, SATA, SAS, USB
            Size_GB   = [math]::Round($_.Size / 1GB)
        }
    }
}
$isHDD = $storageInfo.MediaType -eq "HDD"
$isNVMe = $storageInfo.BusType -eq "NVMe"
$isSSD = $storageInfo.MediaType -eq "SSD" -or $storageInfo.MediaType -eq "Unspecified" -and -not $isHDD

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

Write-Host "=== SYSTEM PROFILE ==="
Write-Host "RAM: ${totalRAM_GB}GB (${freeMB}MB free, ${freePercent}%)"
Write-Host "CPU: $cpuName ($cpuCores cores, $cpuThreads threads)"
Write-Host "Storage: $($storageInfo.MediaType) ($($storageInfo.BusType))"
Write-Host "Pagefile: $(if($pagefileAuto){'Auto-managed'}else{'Custom'})"
Write-Host "Memory Compression: $compressionEnabled"
```

### Decision Matrix

```powershell
# ---- DECISION MATRIX ----

$actions = @{
    ClearStandbyList = $false
    DisableCompression = $false
    SetFixedPagefile = $false
    TrimWorkingSets = $false
    RequiresReboot = $false
}

# 1. Standby list: clear if free memory is low (skip for 64GB+)
if ($totalRAM_GB -lt 64) {
    $threshold = if ($totalRAM_GB -le 8) { 1024 } else { 2048 }
    $actions.ClearStandbyList = ($freeMB -lt $threshold)
}

# 2. Memory compression: disable for 16GB+ (unless HDD)
if ($totalRAM_GB -ge 32) {
    $actions.DisableCompression = $compressionEnabled
} elseif ($totalRAM_GB -ge 16 -and -not $isHDD) {
    $actions.DisableCompression = $compressionEnabled
}
if ($actions.DisableCompression) { $actions.RequiresReboot = $true }

# 3. Pagefile: set fixed size if auto-managed
if ($pagefileAuto) {
    $actions.SetFixedPagefile = $true
    if ($actions.SetFixedPagefile) { $actions.RequiresReboot = $true }
}

# 4. Working set trim: ONLY for 8GB systems under extreme pressure
if ($totalRAM_GB -le 8 -and $freeMB -lt 512) {
    $actions.TrimWorkingSets = $true
}
```

### Safety Checks Before Any Action

```powershell
# Verify we are running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Memory optimization requires administrator privileges."
    return
}

# Verify system stability (no recent BSODs)
$recentCrashes = Get-WinEvent -LogName System -FilterXPath "*[System[EventID=1001]]" -MaxEvents 5 -ErrorAction SilentlyContinue |
    Where-Object { $_.TimeCreated -gt (Get-Date).AddDays(-7) }
if ($recentCrashes.Count -gt 2) {
    Write-Warning "System has had $($recentCrashes.Count) recent crashes. Skipping aggressive optimizations."
    $actions.TrimWorkingSets = $false
    $actions.DisableCompression = $false
}
```

---

## CONFIDENCE ASSESSMENT

| Feature | Confidence | Justification |
|---------|------------|---------------|
| Standby List Clearing | HIGH | Well-documented API used by Microsoft's own RAMMap. ISLC is widely used in competitive gaming. No risk of data loss or BSOD. |
| Memory Compression Toggle | HIGH | Official Microsoft PowerShell cmdlet. Disabled by default on all Windows Server editions. Well-understood tradeoffs. Multiple benchmarks available. |
| Pagefile Optimization | HIGH | Microsoft provides detailed official guidance. Fixed-size pagefile is standard enterprise practice. Well-understood risks. |
| Working Set Trim | LOW-MEDIUM | Widely considered snake oil by experts. Real risk of making performance WORSE. The only scenario where it helps (8GB under extreme pressure) is narrow. Multiple authoritative sources advise against it. |

### Gaps and Limitations

1. **No controlled gaming-specific benchmarks found** for standby list clearing impact on frame times. All evidence is anecdotal (ISLC user reports).
2. **Memory compression CPU overhead** has not been precisely measured in gaming workloads. The GO-EUC benchmark was Citrix, not gaming. The WinDev issue #35 reports are real but from developer workloads, not games.
3. **Working set trim** research is largely from VDI/Citrix environments, not gaming PCs. The gaming-specific risks (anticheat interaction) are based on inference, not documented incidents.
4. **Pagefile sizing recommendations** vary widely between sources. Microsoft's official guidance is vague ("depends on the system"). The sizes in this document are consensus recommendations from multiple forums and tech sites, not Microsoft-specified.
5. **NtSetSystemInformation** is an undocumented API. While RAMMap uses it, Microsoft could change it in future Windows versions. The PowerShell P/Invoke implementation should handle failures gracefully.
6. **Testing across Windows versions** is needed. Windows 10 and 11 have different memory management behaviors. The standby list bug is more pronounced in certain Windows 10 builds (1703-1809).

---

## SOURCES

### Primary Sources (Microsoft Official)
- [Microsoft Learn: How to determine appropriate page file size](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows)
- [Microsoft Learn: SetProcessWorkingSetSizeEx API](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-setprocessworkingsetsizeex)
- [Microsoft Learn: Working Set](https://learn.microsoft.com/en-us/windows/win32/memory/working-set)
- [Microsoft Learn: Disable-MMAgent](https://learn.microsoft.com/en-us/powershell/module/mmagent/disable-mmagent?view=windowsserver2025-ps)
- [Microsoft TechCommunity: Memory Management Working Set Trimming](https://techcommunity.microsoft.com/t5/ask-the-performance-team/prf-memory-management-working-set-trimming/ba-p/373758)
- [Microsoft WinDev Issue #35: Memory Compression on Large Systems](https://github.com/microsoft/WinDev/issues/35)
- [Microsoft Learn: NtSetSystemInformation](https://learn.microsoft.com/en-us/windows/win32/sysinfo/ntsetsysteminformation)
- [Microsoft Sysinternals: RAMMap](https://learn.microsoft.com/en-us/sysinternals/downloads/rammap)

### Technical References
- [GitHub MemListMgr: SYSTEM_MEMORY_LIST_COMMAND implementation](https://github.com/fafalone/MemListMgr)
- [GitHub gist: PurgeStandbyList.cpp source](https://gist.github.com/bitshifter/c87aa396446bbebeab29)
- [NtDoc: NtSetSystemInformation documentation](https://ntdoc.m417z.com/ntsetsysteminformation)
- [Windows OS Hub: Memory Compression Process](https://woshub.com/memory-compression-process-high-usage-windows-10/)
- [Windows 10 Memory Compression Insider Hub](https://riverar.github.io/insiderhubcontent/memory_compression.html)

### Performance Benchmarks
- [GO-EUC: Performance Value of Memory Compression for Citrix](https://www.go-euc.com/performance-value-of-memory-compression/)
- [guru3D: Memory Compression Details](https://forums.guru3d.com/threads/a-bit-detailed-info-about-memory-compression-in-win10.419260/)

### Expert Analysis
- [Guy Leech: Memory Trimming (SetProcessWorkingSetSizeEx expert)](https://guyrleech.wordpress.com/tag/memory-trimming/)
- [Guy Leech: Memory Control Script](https://guyrleech.wordpress.com/2018/03/15/memory-control-script-reclaiming-unused-memory/)
- [Bitsum: Virtual Memory Facts and Memory Optimizer Scams](https://bitsum.com/virtual_memory_facts_and_memory_optimizer_scams.php)
- [Bitsum: SmartTrim Documentation](https://bitsum.com/smarttrim/)
- [Puget Systems: What is Pagefile](https://www.pugetsystems.com/support/guides/what-is-pagefile-and-how-to-adjust-it-2243/)

### Community / Gaming-Specific
- [Wagnardsoft: ISLC (Intelligent Standby List Cleaner)](https://www.wagnardsoft.com/intelligent-standby-list-cleaner)
- [Joltfly: ISLC Settings Guide](https://joltfly.com/intelligent-standby-list-cleaner-settings-guide-max-fps/)
- [ElevenForum: Memory Compression Toggle](https://www.elevenforum.com/t/enable-or-disable-memory-compression-in-windows-10-and-windows-11.3555/)
- [Steam Community: Windows Optimization Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1108775770)
- [Tom's Hardware: Pagefile Management](https://www.tomshardware.com/news/how-to-manage-virtual-memory-pagefile-windows-10,36929.html)
