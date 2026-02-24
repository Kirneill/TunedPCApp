# Call of Duty: Black Ops 7 - Competitive Settings Research
**Updated: February 2026 | Engine: IW Engine (latest) | Anti-Cheat: Ricochet**

---

## Important Notes
- Ricochet anti-cheat means **all in-game settings must be applied manually** through the UI
- BO7 encrypts and overwrites its config files on launch
- The automation script only sets Windows-layer EXE compatibility flags (safe, OS-level)
- Settings tested across RTX 3060 to RTX 4090 tier hardware

---

## Display Settings

| Setting | Recommended Value | Reason |
|---------|------------------|--------|
| Display Mode | **Fullscreen Exclusive** | Lowest latency display path. NEVER use Borderless (adds 1-frame latency) |
| Resolution | Native monitor resolution | No reason to lower at 1080p |
| Refresh Rate | Maximum (match monitor Hz) | Use your monitor's full capability |
| Render Resolution | 100% | No DLSS/FSR unless GPU-limited |
| V-Sync | **OFF** | Eliminates 16-50ms input latency |
| FOV | **100-110** | Competitive sweet spot for awareness vs target size |
| ADS FOV | **Affected** | Maintains relative scale when aiming down sights |
| Weapon FOV | **Wide** | Better peripheral view of weapon model |
| World Motion Blur | **OFF** | Reduces visual clarity during movement |
| Weapon Motion Blur | **OFF** | Reduces visual clarity |
| Depth of Field | **OFF** | Blurs near/far objects, hurts focus on targets |
| Film Grain | **0.00** | Adds visual noise that obscures enemies |

---

## Graphics Quality by Hardware Tier

### Entry-Level (RTX 3060 / RX 6600)

| Setting | Value |
|---------|-------|
| Overall Quality Preset | Custom |
| Texture Resolution | Low |
| Texture Filter Quality | Normal (Anisotropic 4x) |
| Nearby Level of Detail | Low |
| Distant Level of Detail | Low |
| Clutter Draw Distance | Short |
| Particle Quality | Low |
| Bullet Impacts/Sprays | ON (shows hit confirmation) |
| Shader Quality | Low |
| Shadow Map Resolution | Low |
| Screen Space Shadows | OFF |
| Ambient Occlusion | OFF |
| Screen Space Reflections | OFF |
| Static Reflection Quality | Low |
| Weather Grid Volumes | OFF |
| Anti-Aliasing | SMAA T1X (best perf/clarity) |
| NVIDIA DLSS / AMD FSR | Quality or Balanced |
| Variable Rate Shading | ON (free performance) |
| On-Demand Texture Streaming | ON (reduces VRAM pressure) |

### Mid-Range (RTX 4070 / RX 7800 XT)

| Setting | Value |
|---------|-------|
| Texture Resolution | High |
| Texture Filter Quality | High (Anisotropic 8x) |
| Nearby Level of Detail | Medium |
| Distant Level of Detail | Low |
| Particle Quality | Low |
| Shader Quality | Medium |
| Shadow Map Resolution | Normal |
| Screen Space Shadows | OFF |
| Ambient Occlusion | OFF |
| Screen Space Reflections | OFF |
| Anti-Aliasing | SMAA T2X |
| Variable Rate Shading | ON |

### High-End (RTX 4090 / RX 7900 XTX)

| Setting | Value |
|---------|-------|
| Texture Resolution | High |
| Texture Filter Quality | High (Anisotropic 16x) |
| Nearby Level of Detail | High |
| Distant Level of Detail | Medium |
| Particle Quality | Low-Medium |
| Shader Quality | High |
| Shadow Map Resolution | High |
| Screen Space Shadows | OFF (minor visual, poor perf tradeoff) |
| Ambient Occlusion | OFF (hurts visibility in dark areas) |
| Screen Space Reflections | OFF |
| Anti-Aliasing | SMAA T2X |
| Variable Rate Shading | ON |

---

## Audio Settings (Competitive)

| Setting | Value | Reason |
|---------|-------|--------|
| Audio Mix | **Headphone or Headphone Bass Boost** | Boosts footstep frequency range |
| Master Volume | 85 | Clear without distortion |
| Music Volume | **0** | Eliminates audio masking of footsteps |
| Dialogue Volume | 20 | Minimal announcer |
| Effects Volume | 80 | Hear gunshots and explosions |
| Hit Marker Sound | **ON** | Audio + visual hit confirmation |
| Mono Audio | **OFF** | Keep stereo for directional cues |

---

## Sensitivity & Controls

| Setting | Value | Notes |
|---------|-------|-------|
| Mouse Sensitivity | 6.0-8.0 | Personal preference range |
| ADS Sensitivity Multiplier | 1.00 | Maintain consistency |
| Mouse Filtering | 0.00 | No smoothing |
| Mouse Acceleration | 0.00 | Disabled |
| Raw Input | **ON** | Bypasses Windows cursor pipeline |
| Mouse Polling Rate | 1000Hz minimum | 4000Hz if supported |

---

## Network Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Killcam | OFF | Reduces lag compensation artifacts |

---

## EXE Compatibility Flags (Script-Applied)

The script applies these Windows-layer flags to the BO7 executable:
- **HIGHDPIAWARE** - Lets game handle DPI rather than Windows scaling
- **DISABLETHEMES** - Prevents Windows from injecting visual theme DLL

These are standard OS features, not modifications to game files. Anti-cheat safe.

---

## Sources
- Dexerto - Best Black Ops 7 PC Settings (Feb 2026)
- ProSettings.net (Feb 2026)
- NVIDIA System Latency Optimization Guide
