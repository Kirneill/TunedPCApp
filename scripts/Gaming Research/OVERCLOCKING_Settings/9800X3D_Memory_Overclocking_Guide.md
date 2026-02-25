# AMD Ryzen 9800X3D - DDR5 Memory Overclocking Guide for Maximum Gaming FPS
**Updated: February 2026 | Platform: AM5 (X670E/B650E/X870E/B850)**
**Focus: Call of Duty Black Ops 7 and competitive gaming**

---

## Executive Summary

The Ryzen 9800X3D with properly tuned DDR5 memory can deliver 5-15% higher average FPS and 10-25% higher 1% lows compared to running stock JEDEC or basic XMP/EXPO profiles. The sweet spot for this processor is **DDR5-6000 CL30 with tight secondary timings** running FCLK at 2000MHz in a 1:1 ratio. Going beyond 6000MT/s offers diminishing returns and risks FCLK desync penalties on most samples.

---

## 1. Optimal RAM Speed and Kits

### The Sweet Spot: DDR5-6000 (1:1 FCLK)

The AMD Ryzen 9800X3D (Zen 5 with 3D V-Cache) uses the same Infinity Fabric architecture as other Zen 5 AM5 processors. The critical factor is the **FCLK (Infinity Fabric Clock)** ratio:

| DDR5 Speed | FCLK | Ratio | Latency Impact | Recommendation |
|------------|------|-------|----------------|----------------|
| DDR5-4800 | 2400 | 1:1 | Baseline | Too slow |
| DDR5-5600 | 2800 | 1:1 | Good | Budget option |
| DDR5-6000 | 2000 | 1:1 | **Optimal** | **BEST for most users** |
| DDR5-6200 | 2067 | 1:1 | Slightly better if stable | Silicon lottery |
| DDR5-6400 | 2133 | 1:1 | Better IF stable | Requires good IMC |
| DDR5-6800+ | 2267+ | 1:1 or 1:2 | Diminishing/negative | Only if FCLK holds 1:1 |
| DDR5-7200+ | 2400+ | Likely 1:2 | Latency PENALTY | Avoid unless proven stable 1:1 |

**Key insight:** DDR5-6000 at CL30 with tight timings will outperform DDR5-7200 CL36 in gaming if the 7200 kit forces a 1:2 FCLK ratio. The 1:2 ratio adds significant latency that negates the bandwidth advantage.

**IMPORTANT NOTE on 9800X3D FCLK:** The 9800X3D, like other Zen 5 parts, generally has an FCLK wall around 2000-2133MHz for most samples. Some golden samples can do 2200MHz+, but this is not guaranteed. The safe and optimal target is **FCLK 2000MHz = DDR5-6000**.

### Best RAM Kits (Community-Verified, 2024-2025)

#### Tier 1: Best Overall (Samsung B-Die / Hynix A-Die Equivalent in DDR5)

| Kit | Speed/Timings | IC Type | Price Range | Notes |
|-----|--------------|---------|-------------|-------|
| **G.Skill Trident Z5 Neo** | 6000 CL30-36-36-96 | SK Hynix A-Die | $90-130 (2x16GB) | **Top recommendation.** Designed for AMD AM5. Most can tighten to CL28-30 |
| **G.Skill Trident Z5 Neo** | 6000 CL30-38-38-96 | SK Hynix A-Die | $80-110 (2x16GB) | Slightly looser stock, still excellent tuning |
| **G.Skill Trident Z5 RGB** | 6000 CL30-36-36-96 | SK Hynix A-Die | $100-140 (2x16GB) | RGB version, same excellent ICs |
| **Kingston Fury Beast** | 6000 CL30-36-36-96 | SK Hynix A-Die | $75-100 (2x16GB) | Excellent value, great overclocker |
| **Kingston Fury Renegade** | 6400 CL32-39-39-102 | SK Hynix A-Die | $110-150 (2x16GB) | For users with strong IMC |

#### Tier 2: Good Value

| Kit | Speed/Timings | IC Type | Price Range | Notes |
|-----|--------------|---------|-------------|-------|
| **Corsair Dominator Titanium** | 6000 CL30-36-36-96 | SK Hynix A-Die | $120-160 (2x16GB) | Premium build, iCUE RGB |
| **TeamGroup T-Force Delta** | 6000 CL30-38-38-96 | SK Hynix A-Die | $70-90 (2x16GB) | Budget king, often Hynix A-die |
| **Patriot Viper Venom** | 6000 CL30-36-36-76 | SK Hynix A-Die | $80-100 (2x16GB) | Good tuning headroom |

#### Tier 3: Acceptable but Not Ideal

| Kit | Speed/Timings | IC Type | Notes |
|-----|--------------|---------|-------|
| Any DDR5-5600 CL28 kit | SK Hynix M-Die | Works fine, less headroom |
| DDR5-6000+ Micron ICs | Various | Can be harder to tune subtimings |

### IC (Integrated Circuit) Hierarchy for DDR5 Overclocking

1. **SK Hynix A-Die** - Current king for DDR5 OC. Best voltage scaling, tightest timings
2. **SK Hynix M-Die** - Good, but less headroom than A-Die
3. **Samsung B-Die (DDR5)** - Rare, decent when found
4. **Micron A-Die** - Acceptable, struggles with some subtimings

**How to identify:** Use Thaiphoon Burner (free) to read the SPD and identify the IC manufacturer and revision.

---

## 2. Primary Timings

### Recommended Primary Timing Profiles

#### Profile 1: Safe Daily (Recommended Starting Point)
```
DDR5-6000 CL30-36-36-96 (1T/GDM On)
```
- This is what most good 6000MHz kits ship with via XMP/EXPO
- Stable on virtually all 9800X3D samples
- Already competitive for gaming

#### Profile 2: Tightened (Most Users Should Target This)
```
DDR5-6000 CL30-34-34-68 (1T/GDM On)
```
- Achievable on most SK Hynix A-Die kits with mild voltage increase
- Measurable FPS improvement over Profile 1
- **This is the best effort-to-reward ratio**

#### Profile 3: Aggressive (Good Silicon Required)
```
DDR5-6000 CL28-34-34-58 (1T/GDM On)
```
- Requires quality A-Die and decent IMC
- Noticeable latency improvement
- Test thoroughly with memory stress tests

#### Profile 4: Extreme (Top 10% Silicon)
```
DDR5-6000 CL26-33-33-56 (1T/GDM Off, 1T CR)
```
OR
```
DDR5-6400 CL30-36-36-72 (1T/GDM On)
```
- Silicon lottery territory
- Maximum gaming performance
- Requires extensive stability testing

### Primary Timing Explanations

| Timing | What It Does | Target Range (DDR5-6000) | Impact |
|--------|-------------|-------------------------|--------|
| **CL (CAS Latency)** | Delay from column address to data output | 26-30 | **HIGH** - Most impactful single timing |
| **tRCD (RAS to CAS Delay)** | Delay from row activation to column access | 33-38 | **HIGH** - Second most impactful |
| **tRP (Row Precharge)** | Time to close a row before opening another | 33-38 | **MEDIUM-HIGH** |
| **tRAS (Row Active Time)** | Minimum time a row must stay active | 56-96 | **MEDIUM** - Must be >= tRCD + tRTP (minimum). Lower is better but has diminishing returns |

### GDM (Gear Down Mode) Note
- **GDM On (recommended):** Rounds CL to nearest even number. Easier stability. CL30 effective.
- **GDM Off + 1T:** True 1T command rate. CL can be odd (CL29). Harder to stabilize but lower latency.
- For gaming, GDM On at CL28-30 is the pragmatic choice. GDM Off provides ~1-2ns latency improvement but risks instability.

---

## 3. Secondary and Tertiary Timings

These timings have a **significant cumulative effect** on real-world performance, sometimes more impactful than primary timings alone. Many users overlook these.

### Critical Secondary Timings

| Timing | Stock/Auto Value | Optimized Value | Impact | Notes |
|--------|-----------------|----------------|--------|-------|
| **tRFC (Refresh Cycle Time)** | 560-630 | **280-380** | **VERY HIGH** | Single most impactful secondary. Lower = less time wasted refreshing. Target 290-340 for A-Die at 6000 |
| **tRFC2** | Auto (usually ~400+) | **200-260** | **HIGH** | Secondary refresh timing. Usually ~0.6-0.7x tRFC |
| **tRFCsb** | Auto | **160-200** | **MEDIUM** | Same-bank refresh. Usually ~0.5-0.6x tRFC |
| **tFAW (Four Activate Window)** | 32-48 | **16-24** | **MEDIUM** | Minimum time for 4 row activations. Lower = more parallelism |
| **tRRDS** | 8 | **4-5** | **MEDIUM** | Same bank group activate-to-activate |
| **tRRDL** | 8-12 | **6-8** | **MEDIUM** | Different bank group activate-to-activate |
| **tWR (Write Recovery)** | 48 | **30-40** | **MEDIUM** | Time after write before precharge. 30-36 usually works |
| **tRTP (Read to Precharge)** | 12-16 | **10-12** | **MEDIUM** | Minimum time from read to precharge |
| **tCWL (CAS Write Latency)** | 30-38 | **28-30** | **MEDIUM** | Write CAS latency. Usually CL-2 or equal to CL |
| **tWTRS** | 4 | **3-4** | **LOW-MEDIUM** | Write-to-read same bank group |
| **tWTRL** | 12-16 | **8-12** | **LOW-MEDIUM** | Write-to-read different bank group |
| **tCKE** | 8 | **1-2** | **LOW** | Clock enable minimum pulse width |

### Critical Tertiary Timings (SCL and Others)

| Timing | Stock/Auto Value | Optimized Value | Impact | Notes |
|--------|-----------------|----------------|--------|-------|
| **tRDRDSCL (Read-to-Read SCL)** | 4-6 | **2-4** | **HIGH** | Controls read-to-read scheduling. **2 is ideal** but 4 is safe. Huge impact on bandwidth |
| **tWRWRSCL (Write-to-Write SCL)** | 4-6 | **2-4** | **HIGH** | Controls write-to-write scheduling. Same as above. |
| **tRDRDSC** | 1 | **1** | LOW | Read-to-read same channel |
| **tRDRDSD** | 4-8 | **4-5** | LOW | Read-to-read same DIMM |
| **tRDRDDD** | 4-8 | **4-5** | LOW | Read-to-read different DIMM |
| **tWRWRSC** | 1 | **1** | LOW | Write-to-write same channel |
| **tWRWRSD** | 6-8 | **6-7** | LOW | Write-to-write same DIMM |
| **tWRWRDD** | 6-8 | **6-7** | LOW | Write-to-write different DIMM |
| **tRDWR** | 12-16 | **10-12** | MEDIUM | Read-to-write turnaround |
| **tWRRD** | 2-4 | **1-2** | MEDIUM | Write-to-read turnaround |

### tRFC Deep Dive (Most Impactful Secondary)

tRFC is the time the memory controller must wait during a refresh cycle. During this time, no read/write operations can occur. DDR5 refreshes very frequently, so reducing tRFC yields significant performance gains.

| IC Type | tRFC Range at 1.35V | tRFC Range at 1.40V | tRFC at 1.45V |
|---------|---------------------|---------------------|---------------|
| SK Hynix A-Die | 320-380 | 290-340 | 260-310 |
| SK Hynix M-Die | 400-500 | 360-440 | 340-400 |
| Micron A-Die | 380-480 | 340-420 | 320-380 |

**Target for A-Die at DDR5-6000:** tRFC 290-340 at 1.40V is the sweet spot.

---

## 4. Voltage Settings

### DDR5 Voltage Architecture

DDR5 has **on-DIMM voltage regulation** (PMIC), which is different from DDR4. The key voltages:

| Voltage | Safe Range | Recommended | Max Daily | Notes |
|---------|-----------|-------------|-----------|-------|
| **VDD (DRAM Core)** | 1.10-1.45V | **1.35-1.40V** | 1.45V | Primary DRAM voltage. DDR5 PMICs regulate this on-DIMM. Most kits default to 1.35V for XMP |
| **VDDQ (Data Bus)** | 1.10-1.45V | **1.35-1.40V** | 1.45V | Data signal voltage. Usually set equal to VDD or VDD-0.05V. Some boards label this as VDDQ |
| **VDD2 (PMIC Input)** | Auto | **Auto or 1.30-1.35V** | 1.40V | Input voltage to the on-DIMM PMIC. Usually left on auto |
| **VDDIO_MEM (CPU memory controller)** | Auto | **Auto or match VDDQ** | 1.45V | Memory controller I/O voltage. Some boards expose this |
| **SoC Voltage (VSOC)** | 1.00-1.30V | **1.10-1.20V** | 1.30V | Powers the Infinity Fabric and memory controller. Critical for FCLK stability |
| **VDDG CCD** | Auto | **Auto or 1.05-1.10V** | 1.15V | Infinity Fabric (CCD to IOD). Usually auto tracks SoC |
| **VDDG IOD** | Auto | **Auto or 1.05-1.15V** | 1.20V | Infinity Fabric (IOD). Slightly higher than CCD is fine |
| **MISC Voltage / CPU VDDIO** | Auto | **Auto** | -- | Board-specific, leave auto unless troubleshooting |

### Voltage Tuning Strategy

1. **Start at XMP/EXPO defaults** (usually VDD 1.35V, VDDQ 1.35V)
2. **For tighter primaries:** Bump VDD/VDDQ to 1.38-1.40V
3. **For aggressive tRFC:** May need 1.40-1.45V VDD
4. **For FCLK stability:** Increase SoC voltage in 0.01V steps (1.10 -> 1.15 -> 1.20V)
5. **VDDG IOD:** If FCLK is unstable, try VDDG IOD 1.10-1.15V

### Safety Notes
- DDR5 modules have thermal sensors. Monitor DIMM temps (target below 55C under load, below 50C ideal)
- VDD above 1.45V is not recommended for daily use and may degrade ICs over time
- SoC above 1.30V risks long-term degradation of the IMC
- **Always test stability** after voltage changes (see testing section)

---

## 5. FCLK (Infinity Fabric Clock)

### How FCLK Works on AM5

The AMD Infinity Fabric connects the CPU cores (CCD) to the I/O die (IOD) where the memory controller resides. The FCLK determines the speed of this interconnect.

```
Memory Controller Clock (MCLK) = DDR5 Speed / 2
UCLK = MCLK (in 1:1 mode)
FCLK = UCLK (in 1:1 mode)

Example: DDR5-6000 -> MCLK 3000MHz -> UCLK 3000MHz -> FCLK 2000MHz (wait, correction below)
```

**Correction for DDR5 on AM5:**
```
DDR5-6000 = 6000 MT/s
MCLK = 3000 MHz (half of transfer rate)
UCLK = 1500 MHz (MCLK / 2 for DDR5, since DDR5 has 2 channels per DIMM)

Actually, the correct mapping for AM5:
DDR5-6000 -> FCLK 2000 MHz in 1:1 mode
```

The exact internal clock ratios differ from DDR4, but the practical rule is:

| DDR5 Speed | FCLK 1:1 Target | FCLK 1:2 |
|------------|-----------------|----------|
| DDR5-5200 | 1733 MHz | 867 MHz |
| DDR5-5600 | 1867 MHz | 933 MHz |
| DDR5-6000 | **2000 MHz** | 1000 MHz |
| DDR5-6200 | 2067 MHz | 1033 MHz |
| DDR5-6400 | 2133 MHz | 1067 MHz |
| DDR5-6600 | 2200 MHz | 1100 MHz |
| DDR5-6800 | 2267 MHz | 1133 MHz |
| DDR5-7200 | 2400 MHz | 1200 MHz |

### 1:1 vs 1:2 Ratio

| Aspect | 1:1 (Synchronous) | 1:2 (Asynchronous) |
|--------|-------------------|---------------------|
| Latency | **Lower (better)** | Higher (worse) |
| Bandwidth | Matched | Higher raw bandwidth possible |
| Gaming FPS | **Better in most games** | Worse in latency-sensitive games |
| Stability | Depends on FCLK ceiling | Easier (FCLK runs at half) |

**Rule of thumb:** Always prefer 1:1 unless you can run DDR5-7200+ AND your specific game benefits from pure bandwidth over latency.

**For Call of Duty / competitive shooters:** 1:1 ratio is ALWAYS preferred. These games are latency-sensitive.

### FCLK Stability on 9800X3D

- **Most samples:** Stable at FCLK 2000MHz (DDR5-6000)
- **Good samples:** Stable at FCLK 2100-2133MHz (DDR5-6200-6400)
- **Golden samples:** Stable at FCLK 2200MHz+ (DDR5-6600+)
- **FCLK instability symptoms:** WHEA errors (Event Viewer -> Windows Logs -> System, look for Event ID 19/20), random crashes, game crashes, subtle data corruption

### How to Test FCLK Stability
1. Run **OCCT** Memory test (Large data set, AVX2) for 1+ hours
2. Check Windows Event Viewer for WHEA errors (even if test passes)
3. Run **y-cruncher** for thermal and FCLK stress
4. Game for extended sessions and monitor for WHEA events

---

## 6. Impact on Call of Duty Black Ops 7

### How Memory Affects CoD Performance

Call of Duty (IW Engine) is **highly sensitive to memory latency and bandwidth**. The engine:
- Streams large amounts of texture and asset data from RAM
- Uses aggressive prefetching that benefits from lower latency
- Has many CPU-bound scenarios (large lobbies, smoke/particle effects, urban areas)
- Benefits significantly from faster memory when the GPU is not the bottleneck

### Expected FPS Gains from Memory Tuning (9800X3D)

These estimates are based on community benchmarks of similar IW Engine titles (MW3, Warzone) on the 9800X3D and other Zen 4/5 processors with various DDR5 configurations.

| Configuration | Avg FPS Gain vs JEDEC 4800 | 1% Low FPS Gain | Notes |
|--------------|---------------------------|-----------------|-------|
| DDR5-4800 CL40 (JEDEC baseline) | Baseline | Baseline | Stock, no XMP |
| DDR5-5600 CL36 (basic XMP) | +8-12% | +10-15% | Minimum you should run |
| DDR5-6000 CL36 (XMP) | +12-16% | +15-20% | Good starting point |
| **DDR5-6000 CL30 (XMP/tuned)** | **+15-20%** | **+18-25%** | **Recommended target** |
| DDR5-6000 CL28 + tight subs | +18-23% | +22-30% | Excellent, diminishing returns past here |
| DDR5-6400 CL30 + tight subs (1:1) | +20-25% | +25-32% | Only if FCLK stable at 2133 |

### CoD-Specific Memory Recommendations

1. **Minimum for competitive play:** DDR5-6000 CL30 with XMP/EXPO enabled
2. **Target for maximum FPS:** DDR5-6000 CL28-30 with tightened secondaries (especially tRFC)
3. **1% lows matter most in CoD:** The stuttery feel in CoD comes from poor 1% lows. Memory tuning improves 1% lows more than average FPS
4. **128-tick servers (ranked) are more CPU/memory sensitive** than public matches
5. **Warzone-style large maps** are more memory bandwidth sensitive than 6v6 multiplayer

### Specific BO7 Observations

- The IW Engine heavily utilizes the CPU cache (the 3D V-Cache on 9800X3D already helps enormously)
- Memory tuning on the 9800X3D provides smaller percentage gains than on non-X3D chips because the V-Cache masks some latency. However, the absolute FPS numbers are still higher
- **On-demand texture streaming** in CoD settings uses system RAM as a buffer; faster RAM helps this pipeline
- At 1080p with a high-end GPU (RTX 4080/4090), CoD becomes very CPU/memory bound, making tuning more impactful
- At 1440p/4K with mid-range GPU, you become GPU-bound and memory tuning matters less

---

## 7. Complete Recommended Profile

### Profile: "Gaming Optimized" (DDR5-6000 on SK Hynix A-Die)

This is the **recommended daily-driver profile** that balances performance and stability.

#### BIOS Settings

```
=== Memory Frequency ===
DDR5 Speed:           6000 MT/s
FCLK:                 2000 MHz (1:1 ratio, set manually)
UCLK:                 Auto (will follow FCLK in 1:1)

=== Primary Timings ===
CAS Latency (CL):     30
tRCD:                  36 (try 34 if stable)
tRP:                   36 (try 34 if stable)
tRAS:                  68 (try 58-62 if stable)
Command Rate:          1T
GDM:                   Enabled

=== Secondary Timings ===
tRFC:                  320 (try 290-300 if stable at 1.40V)
tRFC2:                 220 (try 200 if stable)
tRFCsb:                180 (try 160 if stable)
tFAW:                  24 (try 16 if stable)
tRRDS:                 4
tRRDL:                 8 (try 6 if stable)
tWR:                   36 (try 30 if stable)
tRTP:                  12 (try 10 if stable)
tCWL:                  28-30
tWTRS:                 4
tWTRL:                 10 (try 8 if stable)
tCKE:                  1

=== Tertiary Timings ===
tRDRDSCL:              4 (try 2 if stable - BIG impact)
tWRWRSCL:              4 (try 2 if stable - BIG impact)
tRDRDSC:               1
tRDRDSD:               5
tRDRDDD:               5
tWRWRSC:               1
tWRWRSD:               7
tWRWRDD:               7
tRDWR:                 12 (try 10 if stable)
tWRRD:                 2 (try 1 if stable)

=== Voltages ===
VDD (DRAM):            1.38V (increase to 1.40-1.42V if needed)
VDDQ:                  1.38V (match VDD or VDD-0.02V)
VDD2:                  Auto
SoC Voltage:           1.15V (increase to 1.20V if FCLK unstable)
VDDG CCD:             Auto (or 1.05V)
VDDG IOD:             Auto (or 1.10V)
CPU VDDIO/MISC:       Auto

=== Other Settings ===
Power Down Mode:       Disabled
Gear Down Mode:        Enabled (safer) or Disabled (faster, harder)
Bank Group Swap:       Enabled
Interleaving:          Auto
```

### Profile: "Aggressive" (For Experienced Overclockers)

```
=== Memory Frequency ===
DDR5 Speed:           6000 MT/s (or 6400 if FCLK holds 2133)
FCLK:                 2000 MHz (or 2133 if stable)

=== Primary Timings ===
CL:                    28
tRCD:                  34
tRP:                   34
tRAS:                  58

=== Key Secondaries ===
tRFC:                  290
tRFC2:                 200
tRFCsb:                160
tFAW:                  16
tRRDS:                 4
tRRDL:                 6
tWR:                   30
tRTP:                  10
tCWL:                  28

=== Key Tertiaries ===
tRDRDSCL:              2
tWRWRSCL:              2
tRDWR:                 10
tWRRD:                 1

=== Voltages ===
VDD:                   1.42V
VDDQ:                  1.40V
SoC:                   1.20V
VDDG IOD:             1.12V
```

---

## 8. Stability Testing Protocol

**DO NOT game on untested memory settings.** Unstable RAM causes subtle data corruption, save file corruption, and random crashes.

### Testing Procedure (In Order)

| Step | Tool | Duration | What It Tests |
|------|------|----------|--------------|
| 1 | **OCCT Memory Test** (Large, AVX2) | 30 min | Basic memory stability |
| 2 | **TestMem5 with anta777 Extreme preset** | 3-6 cycles | Deep pattern testing |
| 3 | **y-cruncher** (all tests) | 30 min | FCLK stability + thermal |
| 4 | **Karhu RAM Test** ($10, optional) | 6400%+ coverage | Gold standard for daily stability |
| 5 | **Check Event Viewer for WHEA errors** | After each test | Catches silent FCLK errors |
| 6 | **Game for 2+ hours** | Extended | Real-world validation |

### If Instability Is Found

1. First loosen tRFC by 20-40 ticks
2. Then try increasing VDD/VDDQ by 0.02V
3. If FCLK errors: increase SoC voltage by 0.025V, then VDDG IOD
4. If still unstable: drop to DDR5-5800 or DDR5-5600 with same tight timings (still very fast)

---

## 9. AIDA64 Latency Targets

Use AIDA64 Cache & Memory Benchmark to verify your tuning results.

| Configuration | Read (MB/s) | Write (MB/s) | Copy (MB/s) | Latency (ns) |
|--------------|-------------|-------------|-------------|---------------|
| DDR5-4800 CL40 (stock) | ~55,000 | ~38,000 | ~52,000 | ~85-90 |
| DDR5-6000 CL36 (XMP) | ~72,000 | ~48,000 | ~66,000 | ~62-68 |
| **DDR5-6000 CL30 (tuned)** | **~78,000** | **~52,000** | **~72,000** | **~55-60** |
| DDR5-6000 CL28 (aggressive) | ~82,000 | ~55,000 | ~76,000 | ~50-55 |
| DDR5-6400 CL30 (tuned, 1:1) | ~86,000 | ~58,000 | ~80,000 | ~50-54 |

**Target for gaming:** Below 58ns AIDA64 latency is excellent. Below 52ns is exceptional.

---

## 10. Motherboard Recommendations for Memory OC

The motherboard significantly affects memory overclocking potential. Boards with 2 DIMM slots (no daisy-chain topology) are optimal.

| Tier | Boards | DIMM Slots | Notes |
|------|--------|------------|-------|
| **S-Tier** | ASUS ROG Crosshair X870E Hero, MSI MEG X870E Ace | 2 or 4 | Best signal integrity, best BIOS for RAM OC |
| **A-Tier** | ASUS ROG Strix X870E-E, MSI MAG X870E Tomahawk, Gigabyte X870E Aorus Master | 2 or 4 | Excellent for 6000-6400 |
| **B-Tier** | ASUS TUF Gaming B850-Plus, MSI MAG B850 Tomahawk | 2 | Good value, 2-DIMM is actually better for OC |
| **Budget** | Any decent B650/B850 | 2 preferred | Will usually hit 6000 CL30 fine |

**Key insight:** A $180 B850 board with 2 DIMM slots can often overclock RAM just as well as a $400 X870E board for DDR5-6000. The 2-DIMM topology has cleaner signal paths.

---

## Sources and Confidence Ratings

### Sources (from training data through May 2025)

| Source | Type | Content |
|--------|------|---------|
| Buildzoid (Actually Hardcore Overclocking) | YouTube / Technical Analysis | DDR5 subtiming tuning guides for AM5, Zen 5 memory architecture deep dives |
| TechPowerUp | Hardware Review | 9800X3D DDR5 scaling benchmarks across multiple speeds |
| Tom's Hardware | Hardware Review | Best RAM for 9800X3D roundup, benchmarks |
| Hardware Unboxed | YouTube / Benchmarks | DDR5 speed scaling on AM5, gaming benchmarks |
| Gamersnexus | YouTube / Technical | 9800X3D review with memory performance analysis |
| r/overclocking (Reddit) | Community | Extensive 9800X3D memory OC results threads, voltage findings, stability reports |
| r/AMD (Reddit) | Community | FCLK stability reports, WHEA discussions, XMP compatibility |
| Overclock.net forums | Community | Deep subtiming tuning threads for DDR5 on AM5 |
| SkatterBencher | YouTube / OC Guide | AM5 DDR5 overclocking guides with specific BIOS walkthroughs |
| AMD official | Documentation | AM5 memory support, EXPO profiles, recommended configurations |
| JEDEC DDR5 Specification | Standard | DDR5 timing definitions, voltage specifications |

### Confidence Ratings

| Claim | Confidence | Justification |
|-------|-----------|---------------|
| DDR5-6000 1:1 FCLK is the sweet spot | **HIGH** | Unanimously confirmed across all major reviewers and community testing. AMD themselves recommend this. |
| SK Hynix A-Die is the best DDR5 IC | **HIGH** | Consistent community and reviewer consensus from late 2024 through 2025. |
| Primary timing targets (CL28-30 at 6000) | **HIGH** | Widely reproduced across many kits and boards. Well within A-Die specifications. |
| Secondary timing targets (tRFC 290-340) | **HIGH** | Extensively tested by overclockers. tRFC values are well-characterized for A-Die. |
| Tertiary timing targets (SCL 2-4) | **MEDIUM-HIGH** | SCL timings are well-understood but board/BIOS-version dependent. |
| Voltage safe limits (1.45V VDD max) | **MEDIUM-HIGH** | Generally accepted but long-term degradation data for DDR5 at high voltage is still being gathered as of 2025. |
| CoD FPS improvement percentages | **MEDIUM** | Based on IW Engine benchmarks (MW3/Warzone/BO6) which use similar engine versions. BO7-specific comprehensive benchmarks may differ by a few percentage points. |
| FCLK ceiling of 2000-2133 for most samples | **HIGH** | Consistently reported across thousands of user reports. |
| Specific motherboard tier rankings | **MEDIUM** | Board revisions and BIOS updates can change OC capability. Rankings valid as of early 2025. |

### Gaps / Limitations

1. **Call of Duty Black Ops 7 was not yet released during my training data cutoff.** CoD-specific claims are extrapolated from MW3/Warzone/BO6 which use the same IW Engine family. The engine architecture is similar enough that memory scaling behavior should be comparable, but BO7-specific numbers could vary.
2. **BIOS maturity:** AM5 BIOS updates in late 2025/early 2026 may have improved FCLK stability or changed voltage requirements. Check for the latest BIOS for your board.
3. **Specific kit recommendations:** DDR5 kit availability and pricing change rapidly. The kits listed were commonly available in early-mid 2025. Newer revisions may use different ICs.
4. **Long-term voltage degradation:** DDR5 is relatively new, and community data on long-term effects of running 1.40V+ daily is still being accumulated.
5. **Individual silicon variance:** All overclocking is subject to the silicon lottery. Your specific CPU's IMC and RAM kit's ICs may perform better or worse than these guidelines.
6. **32GB vs 64GB:** This guide assumes 2x16GB (single rank). 2x32GB (dual rank) kits can provide slightly more bandwidth but are harder to overclock to the same timings due to increased load on the memory controller.

---

## Quick Reference Card

```
+------------------------------------------+
|  9800X3D MEMORY QUICK REFERENCE          |
+------------------------------------------+
|  Speed:    DDR5-6000 MT/s                |
|  FCLK:     2000 MHz (1:1 ratio)          |
|  CL:       30 (try 28)                   |
|  tRCD:     36 (try 34)                   |
|  tRP:      36 (try 34)                   |
|  tRAS:     68 (try 58)                   |
|  tRFC:     320 (try 290)                 |
|  tRDRDSCL: 4 (try 2)                     |
|  tWRWRSCL: 4 (try 2)                     |
|  VDD:      1.38-1.40V                    |
|  VDDQ:     1.38-1.40V                    |
|  SoC:      1.15V (1.20V if needed)       |
|  GDM:      On                            |
|  Kit:      G.Skill Trident Z5 Neo        |
|            6000 CL30 (Hynix A-Die)       |
|  Target:   <58ns AIDA64 latency          |
+------------------------------------------+
```

---

*This guide was compiled from extensive community benchmarking data, hardware review publications, and overclocker reports from October 2024 through May 2025. Always verify with current sources for the latest BIOS-specific findings.*
