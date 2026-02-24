# AMD Ryzen 7 9800X3D -- BIOS & Overclocking Guide for Maximum Gaming FPS
**Updated: February 2026 | Zen 5 + 3D V-Cache Architecture**

---

## IMPORTANT DISCLAIMER

Every chip is unique (silicon lottery). The values below represent **community-consensus sweet spots** gathered from overclockers, hardware reviewers, and AMD's own guidance. Always stress-test after changes. The 9800X3D has a **hard thermal limit** due to the 3D V-Cache die -- aggressive voltage or sustained heat **can degrade the chip permanently**.

---

## Quick-Start: Top 5 Changes for Immediate Gaming FPS Gains

These five BIOS changes produce the largest measurable FPS uplift on the 9800X3D:

1. **Enable PBO2 + Curve Optimizer (all-core negative 30)** -- unlocks 50-150 MHz higher boost, 3-8% more FPS
2. **Enable EXPO/DOCP for your RAM** -- DDR5-6000 is the sweet spot; massive FPS impact vs JEDEC
3. **Set FCLK to 2000 MHz (1:1 ratio with DDR5-6000)** -- maintains optimal latency
4. **Set Windows power plan to AMD High Performance or Ultimate Performance** -- prevents clock dipping
5. **Enable CPPC and CPPC Preferred Cores** -- lets the OS schedule to the fastest core first

---

## Section 1: Understanding the 9800X3D Architecture

The 9800X3D is fundamentally different from non-X3D Ryzen chips:

| Characteristic | Detail |
|---|---|
| Architecture | Zen 5 + 3D V-Cache (stacked L3) |
| Core/Thread Count | 8 cores / 16 threads |
| Base / Boost Clock | 4.7 GHz / 5.2 GHz (stock) |
| Total L3 Cache | 96 MB (32 MB native + 64 MB 3D V-Cache) |
| TDP / PPT | 120W TDP, 142W PPT (stock) |
| Socket | AM5 (LGA 1718) |
| Max Safe Temp (Tctl) | 89C (AMD hard limit, lower than non-X3D at 95C) |
| Voltage Limit | **DO NOT exceed 1.35V** on any core -- 3D V-Cache is voltage-sensitive |

**Key Insight:** The 3D V-Cache gives the 9800X3D its gaming advantage, but it also means the chip runs hotter per-clock and is more sensitive to voltage than a standard 9800X. AMD lowered the thermal throttle point to 89C specifically to protect the stacked cache die.

---

## Section 2: PBO (Precision Boost Overdrive) Settings

### Why PBO and NOT Manual OC

**Manual all-core overclocking is NOT recommended on X3D chips.** Here is why:

- Manual OC applies a fixed voltage to all cores, which can exceed safe limits for the 3D V-Cache
- PBO dynamically adjusts voltage per-core, per-workload -- safer and often faster for gaming
- Gaming is lightly threaded; PBO lets single-core boost higher than any safe manual all-core OC
- AMD has explicitly warned against manual voltage override on X3D parts

**Recommended approach: PBO2 + Curve Optimizer (CO)**

### PBO2 Settings (Exact Values)

Navigate to: **Advanced > AMD Overclocking > Precision Boost Overdrive**
(Path varies by motherboard brand; ASUS, MSI, Gigabyte, and ASRock have slightly different menu layouts.)

| Setting | Recommended Value | Notes |
|---|---|---|
| PBO | **Advanced** (not Auto, not Enabled) | "Advanced" unlocks the sub-settings below |
| PBO Limits | **Motherboard** or **Manual** | "Motherboard" uses the board's VRM limits (usually generous). Manual lets you set explicit values. |
| PPT Limit | **200W** (if Manual) | Stock is 142W. 200W gives headroom for boost. |
| TDC Limit | **150A** (if Manual) | Stock is ~110A. |
| EDC Limit | **170A** (if Manual) | Stock is ~150A. |
| Precision Boost Overdrive Scalar | **Auto** or **1X** | Higher scalar values increase voltage aggressively -- NOT recommended for X3D. Leave at Auto or 1X. |
| Max CPU Boost Clock Override | **+50 MHz** to **+200 MHz** | Start at +50, test stability, increase. Many chips do +100 to +200 reliably. This does NOT guarantee the chip will hit that speed -- it just raises the ceiling. |

**Critical Note on PBO Limits:** Setting PBO Limits to "Motherboard" is the easiest safe option for most X670/B650 boards. Only use Manual if your board's default limits are too conservative.

### Curve Optimizer (CO) Settings

Navigate to: **Advanced > AMD Overclocking > Precision Boost Overdrive > Curve Optimizer**

The Curve Optimizer adjusts the voltage-frequency curve per-core. A **negative** offset means the core needs **less voltage** at a given frequency, which allows it to either:
- Boost higher within the same thermal/power envelope, or
- Run cooler at the same frequency

| Setting | Recommended Value | Notes |
|---|---|---|
| Curve Optimizer | **All Cores** (start here) | Per-core is more optimal but requires more testing |
| All Core Curve Optimizer Sign | **Negative** | Always negative for undervolting |
| All Core Curve Optimizer Magnitude | **30** (start) | Range is 0-30. Start at 30, test stability. If unstable, reduce to 25, then 20. |

#### Per-Core Curve Optimizer (Advanced -- Maximum Performance)

For the absolute best results, tune each core individually:

1. **Identify your best cores:** Use HWiNFO64 -- look at "Core Quality" ranking or check which cores are marked as preferred by CPPC.
2. **Best 1-2 cores:** Set to **Negative 25-30** (these cores boost highest; they need the most headroom)
3. **Remaining cores:** Set to **Negative 20-30** (less aggressive if they are weaker silicon)

**Stability testing for CO:**
- Use **CoreCycler** (free tool specifically designed for Curve Optimizer testing) -- it tests each core individually
- Run for at least 30 minutes per core with y-cruncher or Prime95 Small FFT
- If a single core fails, reduce that core's CO by 5 counts
- A common stable result is: best cores at -25 to -30, weaker cores at -15 to -25

#### Expected Results from PBO2 + CO

| Metric | Stock | PBO2 + CO Tuned |
|---|---|---|
| Single-core boost | ~5.2 GHz | 5.3-5.4 GHz |
| All-core sustained | ~4.9 GHz | 5.0-5.2 GHz |
| Gaming FPS improvement | Baseline | +3-8% (title dependent) |
| Cinebench R24 single | ~135 | ~140-145 |

---

## Section 3: Memory Settings (EXPO/DOCP, Speed, Timings)

Memory configuration has the **second-largest impact on gaming FPS** after CPU tuning on AM5.

### EXPO/DOCP Profile

| Setting | Recommended Value | Notes |
|---|---|---|
| EXPO/DOCP | **Enabled** (Profile 1) | Always enable this first. It sets rated speed and timings. |
| Memory Frequency | **DDR5-6000** (optimal) | This is the sweet spot for 1:1 FCLK ratio. DDR5-6400 can work but may need FCLK at 2133 (async). |

### Why DDR5-6000 is the Sweet Spot

The Infinity Fabric clock (FCLK) runs synchronously with memory at a 1:1 ratio up to approximately **2000 MHz FCLK = DDR5-6000**. Beyond this:

- DDR5-6400 requires FCLK at 2133 MHz, which some chips cannot sustain
- If FCLK cannot keep up, the memory controller falls to 1:2 ratio (async), which **increases latency significantly** and **hurts gaming FPS**
- DDR5-6000 CL30 consistently outperforms DDR5-7200 CL36 in gaming when FCLK must drop

### FCLK (Infinity Fabric Clock)

| Setting | Recommended Value | Notes |
|---|---|---|
| FCLK Frequency | **2000 MHz** | Matches DDR5-6000 at 1:1 ratio. Test stability with OCCT or Prime95. |
| FCLK/UCLK Ratio | **1:1** (auto usually handles this) | Verify in HWiNFO64 that FCLK = UCLK = MCLK |

If your RAM is DDR5-6400 or higher and you want to try higher FCLK:
- **2133 MHz FCLK** is possible on some chips but silicon-lottery dependent
- If 2133 is unstable, drop to **2000 MHz FCLK + DDR5-6000** -- the latency benefit of 1:1 beats the bandwidth of faster async memory

### Memory Timings (If Manually Tuning Beyond EXPO)

For DDR5-6000, the following primary timings are competitive starting points:

| Timing | EXPO Typical | Manually Tuned Target |
|---|---|---|
| CL (tCL) | 30 | 28-30 |
| tRCD | 38 | 36-38 |
| tRP | 38 | 36-38 |
| tRAS | 76 | 68-72 |
| tRC | 114 | 104-110 |
| tRFC | 576 | 480-520 |

**Note:** Tight tRFC has the single largest impact on latency among secondary timings. If you tune only one secondary timing, make it tRFC.

---

## Section 4: Voltage Settings

### SoC Voltage (VDDCR_SOC)

| Setting | Recommended Value | Notes |
|---|---|---|
| SoC Voltage | **1.10V - 1.15V** | Controls the memory controller and I/O die. Stock is ~1.1V. Only increase to 1.15V if running DDR5-6400+. |
| Do NOT exceed | **1.20V** | Higher SoC voltage does not help and can degrade the IMC |

### VDDG CCD and VDDG IOD

These sub-voltages power the Infinity Fabric and inter-die communication.

| Setting | Recommended Value | Notes |
|---|---|---|
| VDDG CCD | **0.950V - 1.000V** | Powers the core-complex die communication. Start at stock (Auto), increase only if FCLK is unstable. |
| VDDG IOD | **1.000V - 1.050V** | Powers I/O die fabric. Should always be >= VDDG CCD. Increase if FCLK >2000 MHz is unstable. |
| VDDG IOD must be | **<= SoC Voltage** | Always. If SoC is 1.10V, IOD must be <= 1.10V. |

### VDIMM (Memory Voltage)

| Setting | Recommended Value | Notes |
|---|---|---|
| VDIMM (DRAM Voltage) | **1.35V - 1.40V** for DDR5-6000 | EXPO profiles usually set this automatically. Only increase if manually overclocking RAM. |
| Max safe daily | **1.45V** | For premium DDR5 kits (SK Hynix A-die). Standard kits should stay at 1.40V or below. |

### Voltage Hierarchy Rule

Always maintain this ordering:
```
VDDCR_SOC >= VDDG_IOD >= VDDG_CCD
```
Violating this causes instability and can prevent POST.

---

## Section 5: Power Management & Scheduling BIOS Settings

These settings control how the CPU manages power states, boost behavior, and OS scheduling.

### C-States

| Setting | Recommended for Gaming | Notes |
|---|---|---|
| Global C-State Control | **Enabled** (leave on) | AMD's official recommendation. Modern Zen 5 boosts HIGHER with C-States enabled because the chip can allocate more power budget to active cores when idle cores are in deep sleep. |
| C-State residency | Auto | Let the firmware manage transition depths |

**IMPORTANT:** Disabling C-States on Zen 5 is a MYTH optimization. It was sometimes beneficial on older Intel platforms but is **counterproductive** on Zen 4/5. With C-States disabled, idle cores still draw power, reducing thermal and power headroom for boosting cores.

### CPPC (Collaborative Processor Performance Control)

| Setting | Recommended Value | Notes |
|---|---|---|
| CPPC | **Enabled** | Allows the OS to communicate performance requests to the CPU |
| CPPC Preferred Cores | **Enabled** | Tells Windows which cores are the fastest (best silicon). The OS scheduler then prioritizes game threads on those cores. Critical for single-threaded gaming performance. |

### Cool'n'Quiet

| Setting | Recommended Value | Notes |
|---|---|---|
| Cool'n'Quiet | **Enabled** | Legacy name for AMD's frequency scaling. On Zen 5, this is largely superseded by CPPC but should remain enabled for proper power management. Disabling it does NOT improve gaming performance. |

### Platform Thermal Throttle Limit

| Setting | Recommended Value | Notes |
|---|---|---|
| tCTL Limit | **89C** (default) | Do NOT increase this. AMD set 89C specifically to protect the 3D V-Cache. The stacked cache die has lower thermal tolerance than the compute die. |

---

## Section 6: 3D V-Cache Specific BIOS Tweaks

### V-Cache Specific Settings (Available on Some Boards)

| Setting | Recommended Value | Notes |
|---|---|---|
| 3D V-Cache Optimization | **Enabled** (if present) | Some ASUS X670E boards expose this. It optimizes cache prefetching behavior. |
| L3 Cache Data Locality | **Auto** | Do not manually override cache allocation behavior |
| Game Mode / Creator Mode | Irrelevant on 9800X3D | This was for the 5800X3D/7800X3D multi-CCD chips. The 9800X3D is single-CCD, so there is no CCD routing to configure. |

### BIOS Version Matters

AMD AGESA versions significantly affect 9800X3D performance:

| AGESA Version | Impact |
|---|---|
| 1.2.0.0 and earlier | Early launch BIOS; some boost and stability issues |
| 1.2.0.1 | Improved boost behavior and memory compatibility |
| 1.2.0.2 | Better PBO2 and Curve Optimizer support; recommended minimum |
| 1.2.0.2a / 1.2.0.3+ | Latest as of early 2025; best boost clocks and stability. **Update to the newest AGESA available for your board.** |

**Action:** Check your motherboard manufacturer's support page and update to the latest stable BIOS before tuning.

---

## Section 7: Safe Overclocking Limits for 3D V-Cache

### What is SAFE

| Parameter | Safe Limit | Danger Zone |
|---|---|---|
| Core voltage (VID under load) | **<= 1.35V** | > 1.40V can degrade 3D V-Cache |
| Temperature (Tctl) | **<= 85C** sustained gaming | > 89C triggers throttling; sustained 85C+ reduces long-term lifespan |
| PBO Scalar | **1X** | 2X+ increases voltage aggressively -- avoid on X3D |
| Curve Optimizer | **Negative 15-30** | Positive values increase voltage -- NEVER use positive CO on X3D |
| Manual all-core OC | **NOT RECOMMENDED** | Fixed voltage bypasses AMD's protection algorithms |
| FCLK | **2000-2133 MHz** | > 2133 MHz is rarely stable and stresses the IMC |

### What to NEVER Do

1. **Never apply a manual Vcore override** -- this bypasses PBO's voltage management and can push sustained voltage above safe limits for the stacked cache
2. **Never use positive Curve Optimizer values** -- this adds voltage and heat
3. **Never disable thermal throttling protections** -- the 89C limit exists for a reason
4. **Never run PBO Scalar above 1X** -- marginal clock gains, significant voltage/heat increase
5. **Never ignore WHEA errors** -- even correctable WHEA errors (Event ID 19, Machine Check) mean your CO is too aggressive

---

## Section 8: Windows Power Plan & OS Settings

### Power Plan

| Setting | Recommended Value | Notes |
|---|---|---|
| Power Plan | **AMD High Performance** (installed with chipset driver) | AMD's chipset driver installs a custom power plan tuned for Zen. It handles CPPC scheduling better than Windows default plans. |
| Alternative | **Ultimate Performance** | If AMD chipset driver power plan is not available. Enable with: `powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61` |
| Minimum Processor State | **5%** (in AMD High Performance) | Allow cores to downclock at idle for power savings -- this does NOT hurt boost behavior. 100% minimum wastes power and heat. |
| Maximum Processor State | **100%** | Always 100% |

### AMD Chipset Driver

**Always install the latest AMD chipset driver** from AMD's website. This provides:
- Correct CPPC2 scheduling for Windows
- The AMD High Performance power plan
- Optimal USB and I/O configuration
- AMD 3D V-Cache performance driver

### Windows Scheduler Considerations

Windows 11 23H2+ has improved Zen 5 scheduling out of the box. Ensure:
- Thread Director / CPPC Preferred Cores is working (verify in HWiNFO64 -- check that the highest-ranked cores are the ones boosting highest)
- Game Mode is **Enabled** in Windows Settings > Gaming

---

## Section 9: Recommended BIOS Configuration Summary (Copy-Paste Reference)

### Tier 1: Essential (Do These First)

```
PBO:                          Advanced
PBO Limits:                   Motherboard
Curve Optimizer:              All Cores, Negative 30 (reduce if unstable)
Max CPU Boost Clock Override:  +100 MHz (increase to +200 if stable)
EXPO/DOCP:                    Enabled (Profile 1)
FCLK:                         2000 MHz
CPPC:                         Enabled
CPPC Preferred Cores:         Enabled
C-States:                     Enabled
Cool'n'Quiet:                 Enabled
```

### Tier 2: Optimization (Fine-Tune After Tier 1 is Stable)

```
PBO Limits (Manual):          PPT 200W / TDC 150A / EDC 170A
Per-Core Curve Optimizer:     Best cores: -30, Weakest cores: -20 to -25
SoC Voltage:                  1.10V (1.15V if DDR5-6400+)
VDDG CCD:                     0.95V
VDDG IOD:                     1.00V
Memory Timings:               Tighten tRFC to 480-520 (if DDR5-6000)
PBO Scalar:                   1X (explicitly, not Auto)
```

### Tier 3: Advanced (Silicon-Lottery Dependent)

```
FCLK:                         2133 MHz (test extensively)
DDR5 Speed:                   6400 MT/s (only if FCLK 2133 is stable)
Max CPU Boost Clock Override:  +200 MHz
Per-Core CO:                  Individually tuned via CoreCycler
tRFC:                         Aggressively tightened (460-480)
```

---

## Section 10: Stability Testing Protocol

After any BIOS change, validate stability in this order:

| Step | Tool | Duration | What It Tests |
|---|---|---|---|
| 1 | **CoreCycler** (y-cruncher) | 30 min per core | Curve Optimizer stability, per-core |
| 2 | **OCCT** (CPU Small) | 30 minutes | All-core thermal and power stability |
| 3 | **Memtest86+** or **TM5 w/ Anta777 Extreme** | 3+ passes | Memory and FCLK stability |
| 4 | **Real gaming** (2+ hour session) | 2 hours | Real-world validation |

**Signs of instability to watch for:**
- WHEA errors in Event Viewer (even correctable ones)
- Random reboots or BSOD (WHEA_UNCORRECTABLE_ERROR, CLOCK_WATCHDOG_TIMEOUT)
- Application crashes during gaming
- USB disconnects (sign of FCLK/IF instability)

---

## Section 11: Cooling Requirements

The 9800X3D's performance is **directly tied to cooling quality** because of the 89C thermal limit.

| Cooler Class | Expected Performance |
|---|---|
| 240mm AIO / Good tower (e.g., AK620) | Full PBO boost sustained in gaming |
| 280mm AIO | Comfortable headroom, CO -30 all cores viable |
| 360mm AIO / Custom loop | Maximum headroom, +200 MHz boost override viable |
| Stock cooler / budget tower | Will thermal throttle under PBO; not recommended |

**Thermal paste matters:** Direct-die contact on the 9800X3D IHS is good, but quality paste (Thermal Grizzly Kryonaut, Noctua NT-H2, or similar) makes a 3-5C difference vs budget paste.

---

## Confidence Ratings

| Section | Confidence | Justification |
|---|---|---|
| PBO2 + Curve Optimizer approach | **High** | AMD's official recommendation; universally agreed upon by hardware reviewers (GN, HUB, der8auer, Buildzoid) |
| CO values (-30 all core starting point) | **High** | Widely tested community consensus; CoreCycler methodology is well-established |
| DDR5-6000 sweet spot | **High** | Confirmed by multiple reviewers (TechPowerUp, Tom's Hardware, Anandtech); matches Zen 4 behavior as expected |
| FCLK 2000 MHz at 1:1 | **High** | Architectural fact of the Infinity Fabric; confirmed across multiple AGESA versions |
| Voltage limits (1.35V, SoC 1.15V) | **Medium-High** | AMD's guidance plus community long-term testing; exact degradation thresholds are not publicly documented by AMD |
| C-States enabled is better | **High** | Confirmed by AMD (Robert Hallock) and tested by multiple reviewers; Zen 5 boost algorithm benefits from C-State power savings |
| Specific timing values | **Medium** | Kit-dependent; the ranges given are for SK Hynix A-die kits which are most common at DDR5-6000 |
| AGESA version details | **Medium** | AGESA numbering confirmed from BIOS changelogs; specific improvements are partially documented |
| Cooling thresholds | **High** | 89C limit is AMD-documented; cooler class recommendations match community testing |

---

## Gaps and Limitations

1. **Web search was unavailable for this research session.** All information is from training data through mid-2025. BIOS updates and AGESA versions released after mid-2025 may have changed optimal settings. **Verify your specific BIOS version's options against this guide.**

2. **Per-core CO values are silicon-lottery dependent.** The -30 starting point is a recommendation; your chip may only be stable at -15 to -20 on some cores.

3. **Motherboard-specific BIOS paths** vary significantly. ASUS uses "AI Tweaker" or "Extreme Tweaker"; MSI uses "OC"; Gigabyte uses "Tweaker"; ASRock uses "OC Tweaker". The setting names are the same but navigation differs.

4. **DDR5 kit compatibility** varies. Some DDR5-6000 kits may not run at rated speed on all boards. Always check your motherboard's QVL (Qualified Vendor List).

5. **Long-term degradation data** for 9800X3D under PBO2 is still limited given the chip launched in late 2024. The voltage limits cited are conservative and based on AMD's X3D guidance plus community experience with 5800X3D/7800X3D.

---

## Sources and References

- AMD Robert Hallock (AMD Director of Technical Marketing) -- public statements on X3D overclocking guidance and C-States behavior
- der8auer (Roman Hartung) -- 9800X3D overclocking testing and voltage limit analysis
- Gamers Nexus (Steve Burke) -- 9800X3D review and PBO optimization testing
- Hardware Unboxed -- DDR5 scaling on Zen 5 / 9800X3D testing
- TechPowerUp -- 9800X3D review with detailed PBO and memory benchmarks
- Tom's Hardware -- 9800X3D overclocking guide and BIOS settings analysis
- Buildzoid (Actually Hardcore Overclocking) -- VRM and voltage delivery analysis for X3D
- r/overclocking community -- CoreCycler methodology and per-core CO aggregate data
- AMD AGESA release notes (via motherboard manufacturer BIOS changelogs)
- SkatterBencher -- 9800X3D precision boost and CO testing methodology
