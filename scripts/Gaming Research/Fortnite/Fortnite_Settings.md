# Fortnite Chapter 6 - Competitive Settings Research
**Updated: February 2026 | Engine: Unreal Engine 5 | Rendering: Performance Mode (DX11)**

---

## Critical Setting: Use Performance Mode

**Settings > Video > Rendering Mode > Performance**

This is the single most impactful setting in Fortnite. Performance Mode (DX11) increases FPS by **20-30%** over DX12 mode. Every competitive/FNCS pro uses Performance Mode.

DX12 is only for Ray Tracing, which has zero competitive benefit.

---

## Video Settings

| Setting | Recommended Value | Reason |
|---------|------------------|--------|
| Window Mode | **Fullscreen** | Lowest latency display path |
| Rendering Mode | **Performance** | +20-30% FPS vs DX12 |
| Resolution | Native monitor (e.g., 1920x1080) | Match your display |
| 3D Resolution | **100%** | Lowering hurts enemy clarity significantly |
| V-Sync | **OFF** | Eliminates 16-50ms input latency |
| Frame Rate Limit | **Refresh Rate - 3** (e.g., 237 for 240Hz) | Stable frame pacing |
| Allow Multithreaded Rendering | **ON** | Requires 6+ CPU cores |

---

## Graphics Quality

| Setting | Value | Reason |
|---------|-------|--------|
| View Distance | **Medium** | Far enough for competitive awareness |
| Shadows | **OFF** | Major FPS drain, minimal competitive benefit |
| Global Illumination | **OFF** | FPS drain |
| Anti-Aliasing | **OFF** | Performance Mode handles this internally |
| Textures | **Low-Medium** | VRAM permitting, minimal visual need |
| Effects | **Low** | Reduced storm/explosion clutter |
| Post Processing | **Low** | Cleaner image |

---

## NVIDIA/AMD Specific Settings

| Setting | Value | Reason |
|---------|-------|--------|
| NVIDIA Reflex | **On + Boost** | Most impactful single latency setting (15-30ms) |
| DLSS | Quality (if GPU-limited) | Only if needed at 1080p |
| Hardware Ray Tracing | **OFF** | No competitive benefit |
| Nanite | **OFF** | No competitive benefit |

---

## Audio Settings (Competitive)

| Setting | Value | Reason |
|---------|-------|--------|
| Sound Effects | **100** | Maximum awareness |
| Music | **0** | Eliminates audio masking of footsteps |
| Voice Chat | 70 | Team comms |
| Subtitles | OFF | Visual clutter |
| 3D Headphones (HRTF) | **ON** | Superior positional audio with headphones |
| Visualize Sound FX | **ON** | Visual indicator for nearby audio events (footsteps, chests, etc.) |

---

## Sensitivity

| Setting | Value | Notes |
|---------|-------|-------|
| X/Y Axis Sensitivity | 7-10 | Most pros use 7-12 |
| ADS Sensitivity | 65-75% | Standard competitive range |
| Scope Sensitivity | 65% | Consistent with ADS |
| Polling Rate | 1000Hz+ | Recommended minimum |

---

## Config File Details

**Location:** `%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini`

The automation script:
1. Backs up existing config
2. Writes optimized `GameUserSettings.ini` with all scalability groups set to competitive values
3. Sets config as **read-only** to prevent Fortnite from overwriting on launch
4. Sets EXE compatibility flags (HIGHDPIAWARE)

**Key config values written:**
```ini
[ScalabilityGroups]
sg.ResolutionQuality=100
sg.ViewDistanceQuality=1
sg.AntiAliasingQuality=0
sg.ShadowQuality=0
sg.GlobalIlluminationQuality=0
sg.ReflectionQuality=0
sg.PostProcessQuality=0
sg.TextureQuality=2
sg.EffectsQuality=0
sg.FoliageQuality=0
sg.ShadingQuality=0
```

**Note:** If Fortnite resets settings after a game update, re-run the script.

---

## Pro Player Reference (February 2026)

- **315 Fortnite pros analyzed** (ProSettings.net)
- All FNCS/competitive pros use: Performance Mode, all settings Low/Off
- Notable pros: Bugha, Mero, Clix - 1920x1080, Performance Mode, 0% Music, Reflex On
- 100% use Fullscreen (not borderless)
- 100% V-Sync OFF

---

## Sources
- ProSettings.net - 315 Fortnite pros (Feb 2026)
- Dexerto, PCGamesN, DotEsports
- NVIDIA System Latency Optimization Guide
