# RTX 5080 & RTX 5090 Overclocking & Optimization Guide
**Updated: February 2026 | Maximum FPS Gaming Configuration**

---

## Important Disclaimers

- Overclocking voids some warranties (check your AIB partner's policy; NVIDIA FE cards have no official OC warranty coverage)
- Silicon lottery means every GPU is different -- your mileage WILL vary
- Always stress-test stability with tools like 3DMark TimeSpy, Unigine Superposition, or FurMark (short bursts only for FurMark)
- Monitor temperatures at all times; thermal throttling negates any overclock gains

---

## Section 1: RTX 5080 Specifications Baseline

| Specification | RTX 5080 Founders Edition |
|---|---|
| GPU | GB203 (Blackwell architecture) |
| CUDA Cores | 10,752 |
| Base Clock | 2,370 MHz |
| Boost Clock | 2,617 MHz |
| Memory | 16 GB GDDR7 |
| Memory Bus | 256-bit |
| Memory Speed | 30 Gbps |
| Memory Bandwidth | 960 GB/s |
| TDP | 360W |
| PCIe | Gen 5 x16 |
| Power Connector | 1x 16-pin (12V-2x6) |

### RTX 5080 Overclocking Settings

#### Core Clock Offset

| Risk Level | Offset Range | Notes |
|---|---|---|
| Conservative | +50 to +100 MHz | Nearly all cards stable here |
| Moderate (Recommended) | +100 to +175 MHz | Sweet spot for most silicon |
| Aggressive | +175 to +250 MHz | Silicon lottery; may crash in heavy loads |
| Extreme (not recommended) | +250 to +300 MHz | Requires exceptional cooling and silicon |

**Typical Achieved Boost Clocks:**
- Stock: 2,617 MHz (boost), real-world ~2,700-2,800 MHz with GPU Boost 5.0
- Moderate OC: ~2,900-3,000 MHz sustained
- Aggressive OC: ~3,000-3,100 MHz (top-tier samples)

**Methodology:** Start at +50 MHz, run 3DMark TimeSpy, increase by +25 MHz increments until instability (artifacts, crashes, driver timeouts). Back off 25 MHz from the crash point for daily stability.

#### Memory Clock Offset (GDDR7)

| Risk Level | Offset Range | Notes |
|---|---|---|
| Conservative | +200 to +500 MHz | Safe for virtually all cards |
| Moderate (Recommended) | +500 to +1,000 MHz | Good gains, usually stable |
| Aggressive | +1,000 to +1,500 MHz | ECC on GDDR7 masks errors but perf may degrade |
| Extreme | +1,500 to +2,000 MHz | Only exceptional samples |

**Critical GDDR7 Note:** GDDR7 includes on-die ECC (Error Correction Code). This means unlike GDDR6/6X, memory overclocking on GDDR7 does NOT produce visual artifacts when pushed too far. Instead, you will see **performance degradation** as the ECC overhead increases to correct errors. Always benchmark after each memory OC step -- if FPS drops despite higher clocks, you have gone too far. This is the "ECC wall."

**Testing for GDDR7 Memory OC Stability:**
1. Run a benchmark (3DMark TimeSpy, Port Royal, or a repeatable in-game benchmark)
2. Record the score at each +100 MHz increment
3. When the score stops increasing or decreases, back off 100-200 MHz
4. That is your effective maximum

#### Power Limit

| Setting | Value | Notes |
|---|---|---|
| Recommended | 105-110% | Allows GPU Boost 5.0 to maintain higher clocks under sustained load |
| Maximum (FE) | 110% (~396W) | Founders Edition typical max slider |
| Maximum (AIB) | 110-133% (varies) | Some AIB cards like ASUS ROG STRIX allow higher power limits |

**Note:** Increasing power limit is the single most effective "overclock" on Blackwell cards. GPU Boost 5.0 is very aggressive and will automatically boost higher when more power headroom is available. Always max out power limit before touching core or memory clocks.

#### Voltage/Frequency Curve Tuning (Advanced)

MSI Afterburner's voltage/frequency curve editor (Ctrl+F) allows per-voltage-point frequency tuning:

1. Open MSI Afterburner > Ctrl+F to open the V/F curve
2. GPU Boost 5.0 on Blackwell is more granular than previous gens
3. **Strategy for max gaming FPS:**
   - Find the voltage point where your GPU typically operates at load (usually 0.950V - 1.050V for the 5080)
   - Raise the frequency at that voltage point by +50 to +150 MHz
   - Flatten the curve above that point (so the GPU does not try to boost to higher voltages that generate more heat)
   - This gives you a higher sustained clock at lower temperatures than a flat offset
4. **Alternative "Undervolting for Performance" approach:**
   - Set the frequency at 0.900V-0.950V to match or exceed your stock boost clock
   - This reduces heat, allowing GPU Boost to sustain higher clocks longer
   - Many users report EQUAL or HIGHER gaming FPS at lower voltages on Blackwell

#### Fan Curve

| Temp (C) | Fan Speed (%) | Rationale |
|---|---|---|
| < 40 | 0-30% | Silent idle/desktop |
| 40-55 | 30-45% | Light loads |
| 55-65 | 45-60% | Normal gaming |
| 65-75 | 60-80% | Heavy gaming / OC |
| 75-80 | 80-90% | Thermal management |
| > 80 | 100% | Thermal protection |

**Target:** Keep GPU temperature below 75C for sustained overclocks. Memory junction temp (visible in HWiNFO64) should stay below 95C for GDDR7 longevity.

#### Typical Performance Gains (RTX 5080 OC vs. Stock)

| Scenario | FPS Improvement |
|---|---|
| Power limit only (+10%) | 2-5% |
| Moderate core + memory OC | 5-10% |
| Aggressive OC (core + mem + power) | 8-13% |
| V/F curve optimized | 7-12% (with lower temps) |

**Source context:** These figures are based on aggregated review data from TechPowerUp, Tom's Hardware, GamersNexus, and Hardware Unboxed RTX 5080 reviews and OC testing from January-March 2025.

---

## Section 2: RTX 5090 Specifications Baseline

| Specification | RTX 5090 Founders Edition |
|---|---|
| GPU | GB202 (Blackwell architecture) |
| CUDA Cores | 21,760 |
| Base Clock | 2,017 MHz |
| Boost Clock | 2,407 MHz |
| Memory | 32 GB GDDR7 |
| Memory Bus | 512-bit |
| Memory Speed | 28 Gbps |
| Memory Bandwidth | 1,792 GB/s |
| TDP | 575W |
| PCIe | Gen 5 x16 |
| Power Connector | 1x 16-pin (12V-2x6) |

### RTX 5090 Overclocking Settings

#### Core Clock Offset

| Risk Level | Offset Range | Notes |
|---|---|---|
| Conservative | +50 to +100 MHz | Safe starting point |
| Moderate (Recommended) | +100 to +150 MHz | Sweet spot; 5090 has less OC headroom than 5080 due to higher TDP |
| Aggressive | +150 to +225 MHz | Requires excellent cooling; thermal throttling likely on air |
| Extreme | +225 to +300 MHz | Custom water cooling recommended |

**Typical Achieved Boost Clocks:**
- Stock: 2,407 MHz (boost), real-world ~2,600-2,750 MHz with GPU Boost 5.0
- Moderate OC: ~2,800-2,900 MHz sustained
- Aggressive OC: ~2,900-3,000 MHz (exceptional samples / water cooled)

**5090-Specific Considerations:**
- The RTX 5090 at 575W TDP is already pushing significant power. Overclocking headroom is more limited than the 5080 in percentage terms.
- Thermal management is the primary bottleneck. The GB202 die is large and generates substantial heat.
- Many reviewers found that the 5090 FE thermal solution runs at 80-85C under stock load, leaving minimal thermal headroom for OC on air cooling.
- **Water cooling unlocks significantly more potential** on the 5090 compared to the 5080, often gaining an additional 5-8% beyond what air cooling allows.

#### Memory Clock Offset (GDDR7)

| Risk Level | Offset Range | Notes |
|---|---|---|
| Conservative | +200 to +500 MHz | Safe baseline |
| Moderate (Recommended) | +500 to +1,000 MHz | Good for most cards |
| Aggressive | +1,000 to +1,500 MHz | Watch for ECC-induced performance regression |

**Same GDDR7 ECC considerations apply as the 5080.** The 5090's 512-bit bus means memory overclocking yields proportionally larger bandwidth gains. A +500 MHz effective memory OC on the 5090 adds more bandwidth in absolute terms than on the 5080.

**5090 Memory Bandwidth Impact:**
- Stock: 1,792 GB/s
- +500 MHz memory OC: ~1,850-1,900 GB/s estimated
- +1,000 MHz memory OC: ~1,950-2,000 GB/s estimated
- At 4K resolution, this additional bandwidth translates more directly to FPS than at 1080p

#### Power Limit

| Setting | Value | Notes |
|---|---|---|
| Recommended | 105-110% | Meaningful boost clock improvement |
| Maximum (FE) | 110% (~633W) | Requires robust PSU (850W+ recommended for system) |
| Maximum (AIB) | Up to 120-133% on premium AIBs | Cards like ASUS ROG STRIX, MSI SUPRIM may allow higher |

**PSU Requirement Warning:** An overclocked RTX 5090 at 110% power limit can draw 630W+ from the GPU alone. Combined with a high-end CPU, total system draw can exceed 900W. A high-quality 1000W+ PSU (80+ Gold or better, preferably ATX 3.0/3.1 with native 12V-2x6) is strongly recommended.

**Transient Power Spikes:** Blackwell GPUs (especially the 5090) can produce transient spikes up to 150-200% of rated TDP for microseconds. ATX 3.0/3.1 PSUs are designed to handle these. Older PSUs may trigger OCP (Over-Current Protection) shutdowns.

#### Voltage/Frequency Curve Tuning (RTX 5090)

Same methodology as the 5080, but with key differences:
- The 5090 typically operates at higher voltages under load (0.975V - 1.075V)
- V/F curve optimization is even more valuable on the 5090 because it helps manage the thermal envelope
- **Recommended approach:** Cap voltage at 1.000V-1.025V and maximize frequency at that point
- This often results in better sustained performance than a flat +150 MHz offset because the GPU spends less time thermal throttling

#### Fan Curve (RTX 5090)

| Temp (C) | Fan Speed (%) | Rationale |
|---|---|---|
| < 40 | 0-30% | Silent idle |
| 40-55 | 35-50% | Light loads |
| 55-65 | 50-70% | Normal gaming |
| 65-75 | 70-85% | Heavy gaming / OC |
| 75-83 | 85-95% | Thermal management |
| > 83 | 100% | Maximum cooling |

**The 5090 requires a more aggressive fan curve than the 5080.** Target below 80C for sustained overclocks. Memory junction temp target: below 100C (GDDR7 is rated higher than GDDR6X, but cooler is always better for longevity).

#### Typical Performance Gains (RTX 5090 OC vs. Stock)

| Scenario | FPS Improvement |
|---|---|
| Power limit only (+10%) | 2-4% |
| Moderate core + memory OC (air) | 4-8% |
| Aggressive OC (air) | 6-10% |
| Water-cooled aggressive OC | 10-15% |
| V/F curve optimized (air) | 5-9% (with better thermals) |

**Note:** Percentage gains are lower on the 5090 than the 5080 because the 5090 is already operating closer to the silicon's maximum capability out of the box. In absolute FPS terms, the gains may be similar or larger.

---

## Section 3: Best Overclocking Tools

### Primary Tools

| Tool | Pros | Cons | Recommendation |
|---|---|---|---|
| **MSI Afterburner** (v4.6.6+) | Industry standard, V/F curve editor, custom fan curves, OSD via RTSS, profiles | Requires Blackwell-compatible version (4.6.6+), UI can be confusing | **#1 Recommended** |
| **EVGA Precision X1** | Clean UI, good voltage control | EVGA exited GPU market; less maintained | Not recommended for 50-series |
| **ASUS GPU Tweak III** | Deep control for ASUS cards, 0dB fan mode toggle | ASUS cards only for full features | Use if you have an ASUS card |
| **MSI Center** | Integrated with MSI ecosystem | MSI cards only for full features | Use if you have an MSI card |
| **NVIDIA App** | Official, built-in performance tuning, auto OC | Limited manual control, no V/F curve | Good for beginners |

### Monitoring Tools (Use Alongside OC Tool)

| Tool | Purpose |
|---|---|
| **HWiNFO64** | Best-in-class hardware monitoring; shows GPU temp, hotspot temp, memory junction temp, power draw, clock speeds, voltage |
| **GPU-Z** | Quick GPU spec verification and basic sensor monitoring |
| **RTSS (RivaTuner Statistics Server)** | On-screen display for real-time monitoring during gaming; comes bundled with Afterburner |
| **CapFrameX** | Frame time analysis and benchmarking; better than average FPS for detecting stutters |

### Recommended MSI Afterburner Setup for RTX 5080/5090

1. Download MSI Afterburner 4.6.6 or newer (must support Blackwell)
2. Settings > General > Enable "Unlock voltage control" and "Unlock voltage monitoring"
3. Settings > Fan > Enable "Enable user defined software automatic fan control" and set custom curve
4. Settings > Monitoring > Configure OSD to show: GPU Temperature, GPU Clock, Memory Clock, GPU Usage, Framerate, Frame Time
5. Set power limit slider to maximum first
6. Apply core clock offset in +25 MHz increments
7. Test stability after each increment
8. Once core is stable, add memory offset in +100 MHz increments
9. Save to a profile (1-5)

---

## Section 4: NVIDIA Control Panel / Driver Settings for Maximum FPS

### Manage 3D Settings - Global Profile (Competitive Gaming)

| Setting | Recommended Value | Explanation |
|---|---|---|
| Image Scaling | **OFF** | Use DLSS in-game instead; driver-level scaling adds latency |
| Ambient Occlusion | **OFF** | Let game control; driver-level AO is imprecise |
| Anisotropic Filtering | **Application-controlled** | Minimal FPS cost in-game; driver override unnecessary |
| Antialiasing - FXAA | **OFF** | Blurs image; use in-game AA |
| Antialiasing - Mode | **Application-controlled** | |
| Background Application Max Frame Rate | **20 FPS** | Saves power when alt-tabbed |
| Low Latency Mode | **On** (or Ultra) | Set to OFF if game has NVIDIA Reflex built-in |
| Max Frame Rate | **OFF** | Cap in-game or via RTSS for lower latency than driver cap |
| Monitor Technology | **G-SYNC** or **G-SYNC Compatible** | If your monitor supports it |
| Power Management Mode | **Prefer Maximum Performance** | **CRITICAL** - Prevents downclocking during gameplay |
| Shader Cache Size | **Unlimited** | Reduces stutter from shader compilation |
| Texture Filtering - Quality | **High Performance** | FPS over visual fidelity |
| Threaded Optimization | **On** | Better multi-threaded driver performance |
| Triple Buffering | **OFF** | Adds latency; only useful with V-Sync ON |
| Vertical Sync | **OFF** | Always OFF for competitive gaming |

### NVIDIA Reflex Settings

**NVIDIA Reflex is the single most impactful latency-reduction technology for competitive gaming.**

| Scenario | Setting |
|---|---|
| Game supports Reflex | Enable Reflex **On + Boost** in-game; set NVCP Low Latency Mode to **OFF** |
| Game does NOT support Reflex | Set NVCP Low Latency Mode to **On** or **Ultra** |
| Reflex On vs On + Boost | "Boost" keeps GPU clocks high even during CPU-bound frames; use in competitive titles |

**Games with Reflex Support (as of early 2025):**
Valorant, CS2, Fortnite, Apex Legends, Overwatch 2, Call of Duty (MW3/Warzone), Rainbow Six Siege, PUBG, Escape from Tarkov, Marvel Rivals, and many more.

### Resizable BAR

| Setting | Value |
|---|---|
| NVIDIA Control Panel | Ensure "Resizable BAR" shows as enabled in System Information |
| Impact | 0-10% FPS gain depending on game; some games see no benefit or slight regression |
| Recommendation | **Leave ENABLED** globally; NVIDIA's driver profile automatically disables it per-game where it hurts performance |

### DLSS / Frame Generation for Competitive Games

| Technology | Competitive FPS Recommendation | Explanation |
|---|---|---|
| **DLSS Super Resolution** | **Performance or Balanced mode** | If you need more FPS at high resolution; at 1080p most competitive players run native |
| **DLSS Frame Generation (FG)** | **OFF for competitive** | FG interpolates frames, adding ~7-12ms of latency; displayed FPS is higher but input lag is worse |
| **DLSS Ray Reconstruction** | **OFF for competitive** | Minor visual improvement, slight FPS cost |
| **DLSS 4 Multi Frame Generation** | **OFF for competitive** | Generates up to 3 extra frames per rendered frame; great for visual smoothness but adds significant latency |

**Exception:** DLSS Frame Generation can be acceptable in casual/non-competitive gaming where visual smoothness matters more than input latency. DLSS 4 MFG on the RTX 5080/5090 is particularly impressive for single-player experiences.

**Key Point:** For competitive gaming, the goal is to maximize **rendered FPS** (not interpolated FPS) and minimize **system latency**. DLSS Super Resolution helps with the former; Frame Generation hurts the latter.

### Driver Version Recommendations

- Use **Game Ready Drivers (GRD)** over Studio Drivers
- Perform a **clean install with DDU** (Display Driver Uninstaller) when:
  - Upgrading from a different GPU generation
  - Experiencing crashes or instability
  - Major driver version jumps (e.g., 560.xx to 570.xx)
- Check NVIDIA's release notes for game-specific optimizations before updating
- The RTX 50-series launched with driver branch 571.xx; these were refined significantly in the weeks after launch

---

## Section 5: BIOS Settings for GPU Performance

### Critical BIOS Settings

| Setting | Location (varies by motherboard) | Recommended Value | Explanation |
|---|---|---|---|
| **Above 4G Decoding** | Advanced > PCI Subsystem / Boot | **Enabled** | **REQUIRED** for Resizable BAR to function |
| **Resizable BAR** | Advanced > PCI Subsystem | **Enabled** | Allows CPU to access full GPU VRAM; 0-10% FPS gain |
| **PCIe Generation** | Advanced > PCI Subsystem | **Auto** or **Gen 5** | RTX 5080/5090 support PCIe 5.0; set to Gen 5 if your CPU/motherboard supports it |
| **PCIe Link Speed** | Sometimes separate from Gen setting | **x16** | Ensure the GPU slot is running at full x16 width |
| **C-States (CPU)** | Advanced > CPU Configuration | **Enabled** (keep default) | Disabling can cause unnecessary power draw; modern CPUs handle this well |
| **PCI Express ASPM** | Advanced > PCI Subsystem | **Disabled** | Active State Power Management can add latency to PCIe transactions |
| **SR-IOV** | Advanced > PCI Subsystem | **Disabled** (unless using VMs) | Single Root I/O Virtualization; unnecessary overhead for gaming |

### PCIe Gen 5 Considerations

**RTX 5080/5090 and PCIe 5.0:**
- Both GPUs have PCIe 5.0 x16 interfaces
- PCIe 5.0 provides 64 GB/s bidirectional bandwidth (vs 32 GB/s for Gen 4)
- **Real-world gaming impact of Gen 5 vs Gen 4:** Minimal (0-3%) in most current games
- The bandwidth is more relevant for Resizable BAR transfers and future games with streaming assets
- **If your platform is Gen 4 only** (e.g., AMD AM4, older Intel): No action needed; the GPU will negotiate down to Gen 4 x16 with negligible gaming impact
- **If your platform supports Gen 5** (AMD AM5 with Zen 5, Intel Arrow Lake/Lunar Lake): Set to Auto or Gen 5

**Verifying PCIe Link Speed:**
- Use GPU-Z > Bus Interface field
- Should show "PCIe 5.0 x16 @ PCIe 5.0 x16" (or Gen 4 x16 if your platform is Gen 4)
- If it shows x8 or a lower generation, check physical installation, BIOS settings, and CPU PCIe lane allocation

### Resizable BAR Verification Checklist

1. BIOS: Above 4G Decoding = Enabled
2. BIOS: Resizable BAR = Enabled
3. NVIDIA Control Panel > System Information > Resizable BAR = "Yes"
4. GPU-Z > Bus Interface > Resizable BAR = "Enabled"
5. If any step shows disabled, work backwards through the chain

### Additional BIOS Settings

| Setting | Recommendation | Notes |
|---|---|---|
| **XMP / EXPO** (RAM) | **Enable Profile 1** | Faster RAM benefits CPU-bound scenarios, which indirectly helps GPU-limited games at lower resolutions |
| **Precision Boost Overdrive (AMD)** | **Enabled / Advanced** | More CPU performance helps in CPU-limited scenarios |
| **Intel Turbo Boost Max 3.0** | **Enabled** | Same reasoning |
| **ErP/EuP Ready** | **Disabled** | Can interfere with wake-on-USB and fast boot |
| **Fast Boot** | Personal preference | Faster POST but harder to enter BIOS; no gaming impact |
| **Secure Boot** | **Enabled** | Required by some anti-cheat (Vanguard, etc.); no performance impact |
| **TPM 2.0** | **Enabled** | Required by Windows 11; no performance impact |

---

## Section 6: Quick-Start Overclocking Profiles

### RTX 5080 "Daily Driver" Profile

```
Power Limit: 110% (max)
Core Clock: +125 MHz
Memory Clock: +750 MHz
Fan Curve: Custom (see Section 1)
Voltage: Default (do not lock)
```
Expected result: ~7-10% FPS improvement, temperatures under 75C with good airflow.

### RTX 5080 "Maximum Performance" Profile

```
Power Limit: 110% (max)
Core Clock: +200 MHz (test stability)
Memory Clock: +1,200 MHz (verify no ECC regression)
Fan Curve: Aggressive (70%+ during gaming)
Voltage: V/F curve optimized at 1.000V
```
Expected result: ~10-13% FPS improvement, temperatures 75-80C.

### RTX 5090 "Daily Driver" Profile (Air Cooled)

```
Power Limit: 110% (max)
Core Clock: +100 MHz
Memory Clock: +600 MHz
Fan Curve: Aggressive custom (see Section 2)
Voltage: Default
```
Expected result: ~5-8% FPS improvement, temperatures under 83C with good case airflow.

### RTX 5090 "Maximum Performance" Profile (Water Cooled)

```
Power Limit: 110-120% (AIB dependent)
Core Clock: +175 MHz
Memory Clock: +1,000 MHz
Fan/Pump: Maximum radiator fan speed during gaming
Voltage: V/F curve optimized at 1.025V
```
Expected result: ~10-15% FPS improvement, temperatures under 65C.

---

## Section 7: Troubleshooting Common Issues

| Symptom | Likely Cause | Fix |
|---|---|---|
| Driver crash / black screen during gaming | Core clock too high | Reduce core offset by 25-50 MHz |
| Performance DECREASE after memory OC | GDDR7 ECC error correction overhead | Reduce memory offset by 200-500 MHz |
| Thermal throttling (clock drops under load) | Insufficient cooling | Increase fan speed, improve case airflow, reduce OC |
| System shutdown under load | PSU OCP triggered (especially 5090) | Use higher-wattage PSU, reduce power limit |
| Artifacts / flickering | Core or memory instability | Reduce clocks; if persistent at stock, RMA the card |
| Coil whine increases with OC | Normal; higher power draw = more coil whine | Cosmetic issue; no fix beyond power limit reduction |

---

## Sources & References

- **Tom's Hardware** - RTX 5080 Review, RTX 5090 Review (January 2025)
- **TechPowerUp** - RTX 5080/5090 Reviews with overclocking sections (January-February 2025)
- **GamersNexus** - RTX 5090 Thermal and Power Analysis (January 2025)
- **Hardware Unboxed** - RTX 5080 & 5090 benchmark and OC testing (January 2025)
- **JayzTwoCents** - RTX 5090 water cooling and overclocking (February 2025)
- **der8auer** - Blackwell silicon analysis and extreme overclocking (February 2025)
- **NVIDIA** - Blackwell Architecture Whitepaper, GPU Boost 5.0 documentation
- **NVIDIA** - DLSS 4 Multi Frame Generation technical documentation (January 2025)
- **MSI Afterburner** - Official documentation and changelog for Blackwell support
- **HWiNFO64** - Sensor documentation for GDDR7 monitoring

---

## Confidence Ratings

| Section | Confidence | Justification |
|---|---|---|
| RTX 5080 core OC ranges | **Medium-High** | Based on multiple review outlets' OC testing; individual results vary by silicon |
| RTX 5090 core OC ranges | **Medium-High** | Same as above; thermal limitations are well-documented |
| GDDR7 memory OC ranges | **Medium** | GDDR7 overclocking behavior with ECC was a new discovery in early 2025; community understanding is still evolving |
| NVIDIA Control Panel settings | **High** | Well-established best practices, consistent across multiple expert sources |
| BIOS settings | **High** | Standard PCIe and Resizable BAR configuration is well-documented |
| Performance gain percentages | **Medium** | Aggregated from reviews but highly variable by game, resolution, and silicon quality |
| DLSS/FG latency impact | **High** | Well-measured by multiple outlets with NVIDIA LDAT and FrameView |

## Gaps / Limitations

1. **Web access was unavailable** during this research session. All data is from training knowledge through May 2025. Driver updates, BIOS revisions, or new overclocking tools released after that date are not covered.
2. **GDDR7 overclocking** is a relatively new area. The ECC behavior makes traditional artifact-based stability testing invalid; the community was still refining methodology in early 2025.
3. **AIB-specific power limits** vary significantly. The ranges given are general; consult your specific card model's reviews for exact power limit slider ranges.
4. **Specific game-by-game OC gains** are not included. Gains vary significantly by title, resolution, and whether the game is GPU-bound or CPU-bound.
5. **NVIDIA driver versions** evolve rapidly. The optimal driver version for RTX 50-series may have changed since the data used here. Always check community feedback on the latest driver before updating.
6. **Liquid nitrogen / extreme overclocking** is outside the scope of this guide. The settings here are for daily-driver stability.
