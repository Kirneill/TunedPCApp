# Windows 11 Gaming Optimization Research
**Updated: February 2026 | Applies to all competitive titles**

---

## Top 5 Changes for Immediate Impact

These five changes deliver the most noticeable improvement in any game:

1. **Power Plan: Ultimate Performance** - prevents CPU/GPU clock throttling mid-game
2. **NVIDIA: Power Management = Prefer Max Performance** - stops GPU from downclocking
3. **Disable V-Sync in every game** - removes 16-50ms of input latency
4. **Enable NVIDIA Reflex (or AMD Anti-Lag) in every supported game** - 15-30ms latency reduction
5. **Disable Mouse Acceleration in Windows** - critical for consistent aim muscle memory

---

## Section 1: Power Plan - Ultimate Performance

**WHY:** Prevents CPU/GPU clock throttling under sustained gaming load. Ultimate Performance is the highest-priority plan available in Windows 11.

**How to enable:**
```powershell
# Unlock the hidden Ultimate Performance plan
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
```

**Verify:** Control Panel > Power Options - should show "Ultimate Performance" as active.

---

## Section 2: Hardware-Accelerated GPU Scheduling (HAGS)

**WHY:** Reduces CPU overhead for GPU command scheduling. Beneficial on NVIDIA RTX 30/40 series and AMD RDNA 2/3 with recent drivers.

**Registry:**
| Path | Value | Data |
|------|-------|------|
| `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` | HwSchMode | 2 (DWORD) |

**Note:** Disable if you experience increased VRAM usage or stutters on 8GB VRAM GPUs.

---

## Section 3: Windows Game Mode

**WHY:** When enabled, Game Mode focuses system resources on the active game, reduces background process interference, and signals the OS scheduler to prioritize the game.

| Setting | Registry Path | Value | Effect |
|---------|--------------|-------|--------|
| Game Mode ON | `HKCU\Software\Microsoft\GameBar` | AllowAutoGameMode = 1 | Focus CPU/GPU on game |
| Game Mode ON | `HKCU\Software\Microsoft\GameBar` | AutoGameModeEnabled = 1 | Focus CPU/GPU on game |
| Game Bar OFF | `HKCU\Software\Microsoft\GameBar` | UseNexusForGameBarEnabled = 0 | Remove overlay overhead |
| Game DVR OFF | `HKCU\System\GameConfigStore` | GameDVR_Enabled = 0 | Disable background recording |
| Game DVR Policy | `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR` | AllowGameDVR = 0 | Enforce DVR disabled |

**Game Bar overlay adds ~10-30ms overhead** and can cause frame drops when triggered accidentally.

---

## Section 4: MMCSS (Multimedia Class Scheduler Service)

**WHY:** Controls CPU time allocated to games vs background processes. Setting Scheduling Category to High and SystemResponsiveness to 10 maximizes game CPU time.

| Registry Path | Value | Data | Effect |
|--------------|-------|------|--------|
| `HKLM\...\Multimedia\SystemProfile` | SystemResponsiveness | 10 (DWORD) | 90% CPU to games |
| `HKLM\...\Multimedia\SystemProfile` | NetworkThrottlingIndex | 0xFFFFFFFF (DWORD) | Remove network cap |
| `HKLM\...\SystemProfile\Tasks\Games` | Scheduling Category | "High" (String) | Highest scheduler priority |
| `HKLM\...\SystemProfile\Tasks\Games` | GPU Priority | 8 (DWORD) | High GPU priority |
| `HKLM\...\SystemProfile\Tasks\Games` | Priority | 6 (DWORD) | High CPU priority |
| `HKLM\...\SystemProfile\Tasks\Games` | SFIO Priority | "High" (String) | High I/O priority |
| `HKLM\...\SystemProfile\Tasks\Games` | Clock Rate | 10000 (DWORD) | 10ms timer resolution |

**Note:** Values below 10 for SystemResponsiveness are auto-rounded up to 20 by Windows, so 10 is the optimal minimum.

---

## Section 5: Network Optimization (Nagle's Algorithm)

**WHY:** Nagle's Algorithm batches small TCP packets to save bandwidth, introducing 10-200ms additional latency in online games. Disabling sends packets immediately.

| Registry Path | Value | Data | Effect |
|--------------|-------|------|--------|
| `HKLM\...\Tcpip\Parameters\Interfaces\{GUID}` | TcpAckFrequency | 1 (DWORD) | ACK every packet |
| `HKLM\...\Tcpip\Parameters\Interfaces\{GUID}` | TCPNoDelay | 1 (DWORD) | Disable Nagle batching |
| `HKLM\...\Tcpip\Parameters` | DefaultTTL | 64 (DWORD) | Standard gaming TTL |

**Apply to all active network interfaces** (interfaces with assigned IP addresses).

---

## Section 6: Visual Effects - Performance Mode

**WHY:** Windows visual effects (animations, shadows, transparency) consume CPU/GPU cycles even when gaming.

| Registry Path | Value | Data | Effect |
|--------------|-------|------|--------|
| `HKCU\...\Explorer\VisualEffects` | VisualFXSetting | 2 (DWORD) | Best Performance mode |
| `HKCU\Software\Microsoft\Windows\DWM` | EnableAeroPeek | 0 (DWORD) | Disable Aero Peek |
| `HKCU\...\Themes\Personalize` | EnableTransparency | 0 (DWORD) | Disable transparency |

---

## Section 7: Fullscreen Optimizations - Disable Globally

**WHY:** Windows Fullscreen Optimizations intercept exclusive fullscreen mode and run the game in a borderless window internally. This adds latency and can cause frame pacing issues.

| Registry Path | Value | Data |
|--------------|-------|------|
| `HKCU\System\GameConfigStore` | GameDVR_FSEBehaviorMode | 2 |
| `HKCU\System\GameConfigStore` | GameDVR_HonorUserFSEBehaviorMode | 1 |
| `HKCU\System\GameConfigStore` | GameDVR_DXGIHonorFSEWindowsCompatible | 1 |
| `HKCU\System\GameConfigStore` | GameDVR_EFSEBehaviorMode | 2 |

**Note:** Valorant may perform slightly better with FSO enabled. Per-game overrides handled in game scripts.

---

## Section 8: Mouse Acceleration - Disable

**WHY:** Mouse acceleration (Enhance Pointer Precision) makes cursor movement speed-dependent rather than distance-dependent. Destroys muscle memory consistency critical for FPS aiming.

| Registry Path | Value | Data |
|--------------|-------|------|
| `HKCU\Control Panel\Mouse` | MouseSpeed | "0" |
| `HKCU\Control Panel\Mouse` | MouseThreshold1 | "0" |
| `HKCU\Control Panel\Mouse` | MouseThreshold2 | "0" |

**Also verify:** Control Panel > Mouse > Pointer Options > Uncheck "Enhance pointer precision"

---

## Section 9: CPU Power States & Additional Tweaks

| Optimization | Command/Setting | Effect |
|-------------|----------------|--------|
| CPU Min State 100% | `powercfg /setacvalueindex ... PROCTHROTTLEMIN 100` | No downclocking mid-game |
| USB Selective Suspend OFF | `powercfg /setacvalueindex ...` | No mouse/keyboard latency spikes |
| Hibernation OFF | `powercfg /hibernate off` | Frees pagefile space |

---

## Hardware Upgrade Priority (if FPS-limited)

1. **Monitor** - 240Hz for competitive games; frames above monitor refresh are wasted visually
2. **GPU** - Primary bottleneck in most titles at 1080p/1440p
3. **CPU** - Secondary bottleneck; 6+ cores recommended, 8+ for streaming
4. **RAM** - 16GB DDR4 minimum; enable XMP/EXPO in BIOS; dual-channel required
5. **Storage** - NVMe SSD for game install (reduces stutter from asset streaming)

---

## Sources
- Windows Forum - Gaming Tuning Guide 2026
- NVIDIA - System Latency Optimization Guide
- ProSettings.net (Feb 2026)
- PCGamesN, Dexerto, DotEsports
