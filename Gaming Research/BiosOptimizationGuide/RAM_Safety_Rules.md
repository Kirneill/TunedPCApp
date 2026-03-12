# RAM Safety Rules — BIOS Auto-Optimizer

**CRITICAL: These rules prevent systems from crashing. Do NOT weaken without real hardware testing.**

Implementation: `src/data/ram-safety.ts` (shared between UI and main process)

---

## Rule 1: AMD Ryzen 7000/9000 + RAM > 6000 MHz → Block Auto-XMP

**Why:** The Zen 4/5 memory controller (IMC) tops out at ~6000 MHz for stable daily use. DDR5 kits rated at 7200, 8000, or higher will crash if XMP enables the full rated speed. The sweet spot is DDR5-6000 with FCLK 2000 MHz (1:1 ratio).

**What we do:**
- Skip the "RAM Speed Profile" setting (don't auto-enable XMP)
- Show a DANGER warning explaining why
- Tell user to manually enable XMP in BIOS, then set memory frequency to 6000 MHz

**Affected CPUs:** All Ryzen 7000 (7600X, 7700X, 7800X3D, 7900X, 7950X) and Ryzen 9000 (9600X, 9700X, 9800X3D, 9900X, 9950X)

**Source:** AMD official spec, Level1Techs DDR5 AM5 testing, community consensus 2024-2026

---

## Rule 2: Intel + RAM > 6800 MHz → Warning (Don't Block)

**Why:** Intel's memory controller handles higher speeds better than AMD, but above 6800 MHz stability becomes questionable on many boards. We warn but don't block because some Intel platforms (especially Z790/Z890 with high-end boards) CAN run 7200+ stable.

**What we do:**
- Show a WARNING (not blocking)
- Suggest trying a lower XMP profile if crashes occur
- Recommend 6400-6800 MHz as fallback

**Affected CPUs:** All Intel processors

---

## Rule 3: >2 RAM Sticks on Ryzen 7000/9000 or Intel 13th/14th Gen → Block CPU Overclock

**Why:** Running 4 DIMMs puts significantly more electrical stress on the memory controller. The signal integrity degrades (daisy-chain topology on 4-DIMM boards), which makes both memory AND CPU overclocking unreliable. 4 sticks + PBO/Curve Optimizer = random crashes, WHEA errors, and data corruption.

**What we do:**
- Block all CPU overclock settings:
  - CPU Auto-Boost (PBO)
  - CPU Speed Boost
  - CPU Efficiency Tuning (Curve Optimizer)
  - CPU Undervolt Direction/Amount
  - Max Frequency Enhancer
  - CPU Voltage Offset/Safety Cap
  - Voltage Control Mode / Stability (LLC)
- Keep safe settings: XMP, ReBAR, C-States, Virtualization, CSM, etc.
- Show a DANGER warning explaining that 2 sticks > 4 sticks for performance
- Recommend switching to 2 higher-capacity sticks to unlock overclocking

**Affected CPUs:**
- AMD Ryzen 7000 series (7600X, 7700X, 7800X3D, 7900X, 7950X)
- AMD Ryzen 9000 series (9600X, 9700X, 9800X3D, 9900X, 9950X)
- Intel 13th Gen (13400-13900KS)
- Intel 14th Gen (14400-14900KS)

**Source:** Level1Techs 4-DIMM testing, XDA Developers "regretting 4 sticks", overclocker consensus, AMD/Intel memory topology documentation

---

## Implementation Notes

- Safety checks run in TWO places (defense in depth):
  1. **UI side** (`BiosAutomateTab.tsx`): Shows warnings, hides skipped settings from preview
  2. **Server side** (`bios-handlers.ts`): Filters profile settings before NVRAM matching/patching
- The `lastDetection` variable in bios-handlers caches the most recent scan result
- Detection data comes from `Detect-BiosState.ps1` which reads `Win32_PhysicalMemory` WMI:
  - `ramSticks` = count of physical DIMMs
  - `ramRatedSpeed` = highest rated speed of any DIMM (the XMP/EXPO target)
  - `ramCurrentSpeed` = actual running speed
- CPU name matching uses regex against the `cpuName` field from WMI `Win32_Processor`

---

## Future Considerations

- Intel Arrow Lake / Core Ultra 200S may have different RAM limits — revisit when data is available
- AMD Zen 6 may improve IMC — don't assume 6000 MHz cap carries forward
- Some high-end Z790/Z890 boards can do 7200+ stable — could add board-specific overrides later
- 2-DIMM boards (B650M, B850) have cleaner signal paths and can often overclock higher than 4-DIMM boards at the same settings
