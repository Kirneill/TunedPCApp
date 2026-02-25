# Valorant - Competitive Settings Research
**Updated: February 2026 | Engine: Unreal Engine 4 (Custom Fork) | Anti-Cheat: Vanguard (Kernel-Level)**

---

## Optimization Philosophy

Valorant is a precision-based tactical shooter where **frame rate consistency matters more than raw FPS numbers**. The game runs well on low-end hardware, and most competitive players prioritize 240+ FPS over visual quality.

**Vanguard Note:** Do not modify game files or memory. Only user config files and Windows compatibility flags are safe to modify.

---

## Video Settings

| Setting | Recommended Value | Reason |
|---------|------------------|--------|
| Display Mode | **Fullscreen** | Valorant's fullscreen is already well-optimized |
| Resolution | **1920x1080** | Pro standard - no pro uses 1440p/4K in ranked |
| V-Sync | **OFF** | Eliminates 16-50ms latency - catastrophic in a tactical shooter |
| Max Frame Rate | **Refresh Rate - 3** (e.g., 237 for 240Hz) | Stable frame pacing |
| NVIDIA Reflex | **Enabled + Boost** | Most important setting - 15-30ms latency reduction |
| Multithreaded Rendering | **ON** | Required for modern 6+ core CPUs |

---

## Graphics Quality

| Setting | Value | Reason |
|---------|-------|--------|
| Material Quality | **Low** | FPS boost, minimal visual impact |
| Texture Quality | **High** | Cheap on VRAM, improves wall/agent clarity |
| Detail Quality | **Low** | FPS boost |
| UI Quality | **Low** | Less UI overhead |
| Vignette | **OFF** | Darkens screen edges, reduces visibility |
| Anti-Aliasing | **None** (or MSAA 2x) | None = highest FPS; MSAA 2x = cleaner model edges |
| Anisotropic Filtering | **4x** | Sharpens textures at angles |
| Improve Clarity | **ON** | Sharpens distant textures significantly |
| Bloom | **OFF** | Visual noise |
| Distortion | **OFF** | Visual noise |
| Cast Shadows | **OFF** | No competitive benefit in Valorant |
| Shadows | **OFF** | FPS drain |
| Ambient Occlusion | **OFF** | FPS drain |

---

## Audio Settings (Competitive)

| Setting | Value | Reason |
|---------|-------|--------|
| Master Volume | 80 | Clear without distortion |
| Music Volume | **0** | Silences lobby/death screen music |
| Sound FX Volume | **100** | Maximum footstep/ability awareness |
| Voice Chat Volume | 70 | Team comms |
| Agent Voice Lines | **OFF** | Eliminates distraction during fights |
| HRTF (Headphones) | **ON** | Dramatically improves vertical audio - critical for hearing agents above/below |
| Windows Sonic/Dolby | **OFF** | Conflicts with HRTF if both enabled |

---

## Sensitivity (Pro Meta - 598 Players Analyzed)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Target eDPI | **200-400** | (sensitivity x DPI) |
| In-Game Sensitivity | 0.3-0.5 | Most pros in this range |
| Scoped Sens Multiplier | 1.0 | Consistent muscle memory |
| Mouse Filtering | 0.00 | No smoothing |
| Raw Input Buffer | **OFF** | Can cause micro-stutters in Valorant |
| Polling Rate | 1000Hz standard | 4000Hz if supported and stable |

### Notable Pro Settings
| Player | DPI | Sensitivity | eDPI |
|--------|-----|-------------|------|
| TenZ | 800 | 0.40 | 320 |
| Aspas | 800 | 0.33 | 264 |
| ScreaM | 800 | 0.22 | 176 |
| **Median** | - | - | **280** |

---

## Crosshair (Competitive Meta)

| Setting | Value | Reason |
|---------|-------|--------|
| Outlines | OFF | Reduces visual clutter |
| Inner Line Length | 4 | Standard competitive |
| Inner Line Width | 2 | Standard competitive |
| Center Dot | OFF | Dot obscures target center at range |
| Color | Cyan or Green | Highest visibility vs most backgrounds |
| Movement Error | OFF | Crosshair stays static for consistency |
| Firing Error | ON | Shows spray pattern feedback |

---

## Minimap

| Setting | Value |
|---------|-------|
| Rotate | Rotate (perspective-relative) |
| Keep Player Centered | OFF |
| Minimap Size | 1.1 |
| Minimap Zoom | 0.9 |

---

## Config File Details

**Location:** `%LOCALAPPDATA%\VALORANT\Saved\Config\Windows\GameUserSettings.ini`

The automation script:
1. Backs up existing config
2. Writes optimized settings with all scalability groups
3. Sets EXE compatibility flags (HIGHDPIAWARE only - Valorant works well with FSO enabled)

**Note:** Valorant is one of the few games that performs well with Fullscreen Optimizations ON, so the script does NOT add DISABLEFULLSCREENOPTIMIZATIONS.

---

## Pro Player Statistics (598 Pros, Feb 2026 - ProSettings.net)

- **100%** use 1920x1080 or lower
- **100%** use Fullscreen (not borderless)
- **100%** V-Sync OFF
- **0%** have shadows enabled
- **95%+** use NVIDIA Reflex Enabled + Boost
- Median eDPI: **280**

---

## Sources
- ProSettings.net - 598 Valorant pros (Feb 2026)
- Riot Games official optimization guide
- NVIDIA System Latency Optimization Guide
