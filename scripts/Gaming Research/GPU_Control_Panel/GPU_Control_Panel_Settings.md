# GPU Control Panel Settings - NVIDIA & AMD Research
**Updated: February 2026 | Applies to all competitive titles**

---

## NVIDIA Control Panel Settings

**Open:** Right-click desktop > NVIDIA Control Panel > Manage 3D Settings > Global Settings

### Global Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Image Scaling | OFF | Use in-game DLSS instead |
| Ambient Occlusion | OFF | FPS cost, hurts visibility in dark areas |
| Anisotropic Filtering | Application-controlled | Let game manage |
| Antialiasing - FXAA | OFF | Use in-game AA |
| Antialiasing - Mode | Application-controlled | Let game manage |
| Background App Max Frame Rate | OFF | Uncap desktop performance |
| Low Latency Mode | **On** | Reduces pre-rendered frames (see per-game notes) |
| Max Frame Rate | OFF | Cap in-game instead |
| Monitor Technology | **G-SYNC** (if available) | Tear-free without V-Sync latency |
| OpenGL Rendering GPU | Your GPU | Ensure correct GPU selected |
| Power Management Mode | **Prefer Max Performance** | **MOST IMPORTANT** - Prevents GPU downclocking |
| Shader Cache Size | Driver Default | Don't reduce |
| Texture Filtering - Anisotropic | On | Better texture sharpness |
| Texture Filtering - Quality | **High Performance** | FPS over visual quality |
| Texture Filtering - Trilinear | On | Minor quality at no perf cost |
| Threaded Optimization | **On** | Better multi-core GPU usage |
| Triple Buffering | **Off** | Adds latency |
| Vertical Sync | **Off** | Always OFF for competitive |
| Virtual Reality Pre-Rendered Frames | 1 | Minimum for lowest latency |
| Vulkan/GL Present Method | **Prefer Native** | Lower latency on modern GPUs |

### Low Latency Mode Per-Game Overrides

**Important:** When a game has NVIDIA Reflex built-in, set Low Latency Mode to **OFF** and use the in-game Reflex instead. Reflex is more effective than the driver-level setting.

| Game | Low Latency Mode | Reason |
|------|-----------------|--------|
| Valorant | **OFF** | Use Reflex in-game |
| CS2 | **OFF** | Use Reflex in-game |
| Fortnite | **OFF** | Use Reflex On+Boost in-game |
| Black Ops 7 | **On** | Game may not have Reflex |
| Arc Raiders | **OFF** | Use Reflex On+Boost in-game |

### G-SYNC Setup

1. Navigate to: **Set up G-SYNC** > Enable G-SYNC/G-SYNC compatible
2. Enable for: **Fullscreen and windowed mode**
3. In-game: V-Sync OFF, cap FPS 3 below monitor max
4. Example: 240Hz monitor = 237 FPS cap + G-SYNC = tear-free with low latency

### Driver Recommendation

- Use **Game Ready Drivers (GRD)** over Studio Drivers for gaming
- Clean install (DDU) recommended after major driver version jumps
- Check for updates via GeForce Experience or nvidia.com

---

## AMD Software Adrenalin Settings

**Open:** AMD Software Adrenalin Edition (system tray or Start menu) > Gaming > Graphics

### Global Graphics Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Anti-Aliasing | **Use App Settings** | Game controls AA |
| Anti-Aliasing Method | **Multisampling** | Less blurry than temporal |
| Morphological AA (MLAA) | **Disabled** | Use in-game AA |
| Anisotropic Filtering | **Disabled** | Let game manage |
| Texture Filtering Quality | **Performance** | FPS over quality |
| Surface Format Optimizations | **Enabled** | FPS boost |
| Wait for Vertical Refresh | **Always Off** | V-Sync always OFF |
| OpenGL Triple Buffering | **Disabled** | Adds latency |
| Shader Cache | **AMD Optimized** | Keep enabled |
| Tessellation Mode | **Optimized** | Balanced perf/quality |
| Frame Rate Target Control | **Disabled** | Cap in-game instead |
| AMD Anti-Lag | **Enabled** | Reduces input lag (AMD's answer to NVIDIA Reflex) |
| AMD Anti-Lag+ | **Enabled** (if available) | Next-gen latency reduction |
| AMD Radeon Boost | **Enabled** | Dynamic res scaling during fast movement |
| AMD Fluid Motion Frames | **Disabled** | Adds latency (not for competitive) |
| FreeSync Premium | **Enabled** | If monitor supports it |
| RSR (Radeon Super Resolution) | **OFF** | Use in-game FSR instead |

### Performance Tuning
- **Power Tuning:** Default or +20% Power Limit
- **GPU Tuning:** Auto (for stability) or manual overclock if experienced

---

## Windows Display Settings (Manual Steps)

1. **Settings > System > Display > Advanced Display**
   - Set refresh rate to your monitor's MAXIMUM Hz

2. **Settings > System > Display > Graphics**
   - Hardware-Accelerated GPU Scheduling: **ON**
   - Variable Refresh Rate: **ON** (if monitor supports G-Sync/FreeSync)

3. **Settings > System > Display > Night light**
   - **OFF** during gaming sessions

4. **Desktop: Right-click > Display Settings > HDR**
   - HDR: **OFF** for competitive gaming
   - HDR washes out colors and adds display processing overhead
   - Exception: Only enable with 1000+ nit HDR monitors for single-player/visual quality

---

## Sources
- NVIDIA System Latency Optimization Guide
- NVIDIA Control Panel documentation
- AMD Adrenalin Software documentation
- PCGamesN, DotEsports optimization guides
