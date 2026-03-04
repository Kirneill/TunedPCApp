# Competitive Gaming Settings Reference
**Version: 2.0 | Updated: February 2026**
**Games: Call of Duty Black Ops 7 | Fortnite Ch.6 | Valorant | CS2 | Arc Raiders**

---

## Quick Start - Top 5 Changes for Immediate Impact

These five changes deliver the most noticeable improvement in any order:

1. **Power Plan: Ultimate Performance** - prevents CPU/GPU clock throttling mid-game
2. **NVIDIA: Power Management = Prefer Max Performance** - stops GPU from downclocking
3. **Disable V-Sync in every game** - removes 16-50ms of input latency
4. **Enable NVIDIA Reflex (or AMD Anti-Lag) in every supported game** - 15-30ms latency reduction
5. **Disable Mouse Acceleration in Windows** - critical for consistent aim muscle memory

---

## Call of Duty: Black Ops 7

**Engine:** IW Engine (latest) | **Anti-Cheat:** Ricochet | **Updated:** Feb 2026

### Display
| Setting | Value | Reason |
|---------|-------|--------|
| Display Mode | Fullscreen Exclusive | Lowest latency display path |
| Resolution | Native monitor res | No reason to lower at 1080p |
| V-Sync | OFF | Eliminates 16-50ms latency |
| FOV | 100-110 | Competitive sweet spot |
| ADS FOV | Affected | Maintains relative scale |
| World Motion Blur | OFF | Reduces visual clarity |
| Weapon Motion Blur | OFF | Reduces visual clarity |
| Depth of Field | OFF | Blurs scene, hurts focus |
| Film Grain | 0.00 | Adds visual noise |

### Graphics (Mid-Range: RTX 4070 / RX 7800 XT)
| Setting | Value |
|---------|-------|
| Texture Resolution | High |
| Shadow Map Resolution | Normal |
| Screen Space Shadows | OFF |
| Ambient Occlusion | OFF |
| Anti-Aliasing | SMAA T2X |
| Variable Rate Shading | ON |
| Screen Space Reflections | OFF |

### Audio
| Setting | Value |
|---------|-------|
| Audio Mix | Headphone or Headphone Bass Boost |
| Music Volume | 0 |
| Hit Marker Sound | ON |

---

## Fortnite (Chapter 6)

**Engine:** Unreal Engine 5 | **Rendering:** Performance Mode (DX11) | **Updated:** Feb 2026

### Critical: Use Performance Mode
`Settings > Video > Rendering Mode > Performance`
This increases FPS by 20-30% over DX12 mode.

### Video Settings
| Setting | Value | Reason |
|---------|-------|--------|
| Window Mode | Fullscreen | Lowest latency |
| Rendering Mode | Performance | +20-30% FPS vs DX12 |
| 3D Resolution | 100% | Lower hurts enemy clarity |
| V-Sync | OFF | Eliminates latency |
| Frame Rate Limit | Uncapped (0) | Higher FPS = lower input latency |
| Multithreaded Rendering | ON | Requires 6+ CPU cores |

### Graphics Quality
| Setting | Value |
|---------|-------|
| View Distance | Medium |
| Shadows | OFF |
| Anti-Aliasing | OFF |
| Textures | Low-Medium |
| Effects | Low |
| Post Processing | Low |
| Hardware Ray Tracing | OFF |
| NVIDIA Reflex | On + Boost |

### Audio
| Setting | Value |
|---------|-------|
| Sound Effects | 100 |
| Music | 0 |
| 3D Headphones (HRTF) | ON |
| Visualize Sound FX | ON |

---

## Valorant

**Engine:** Unreal Engine 4 | **Anti-Cheat:** Vanguard | **Updated:** Feb 2026

### Video Settings
| Setting | Value | Reason |
|---------|-------|--------|
| Display Mode | Fullscreen | Lowest latency |
| Resolution | 1920x1080 | Pro standard |
| V-Sync | OFF | Eliminates latency |
| Max Frame Rate | Uncapped (0) | Higher FPS = lower input latency |
| NVIDIA Reflex | Enabled + Boost | 15-30ms latency reduction |
| Multithreaded Rendering | ON | Required for modern CPUs |

### Graphics Quality
| Setting | Value |
|---------|-------|
| Material Quality | Low |
| Texture Quality | High (cheap, improves clarity) |
| Detail Quality | Low |
| UI Quality | Low |
| Vignette | OFF |
| Anti-Aliasing | None or MSAA 2x |
| Anisotropic Filtering | 4x |
| Improve Clarity | ON |
| Bloom | OFF |
| Distortion | OFF |
| Cast Shadows | OFF |

### Audio
| Setting | Value |
|---------|-------|
| Music Volume | 0 |
| Sound FX Volume | 100 |
| HRTF (Headphones) | ON |
| Agent Voice Lines | OFF |

### Sensitivity (Pro Meta)
- Target eDPI: 200-400
- Most pros: 400 DPI x 0.25-1.0 sens
- Example: TenZ = 800 DPI x 0.40 = 320 eDPI

---

## Counter-Strike 2

**Engine:** Source 2 | **Updated:** Feb 2026

### Launch Options
```
-novid -high -nojoy +exec autoexec.cfg
```
**DEPRECATED (do NOT use):** `-tickrate` `-threads` `-freq` (Source 1 options, broken in CS2)

### Video Settings
| Setting | Value | Reason |
|---------|-------|--------|
| Display Mode | Fullscreen | Lowest latency |
| Resolution | 1920x1080 OR 1280x960 stretch | Personal preference |
| Boost Player Contrast | ON | Critical - enemies stand out |
| V-Sync | OFF | Eliminates latency |
| NVIDIA Reflex | Enabled | 15-30ms reduction |
| Global Shadow Quality | Low | FPS, no competitive loss |
| Anti-Aliasing | 4x MSAA | Improves model clarity |
| Ambient Occlusion | OFF | FPS drain |

### Audio
| Setting | Value |
|---------|-------|
| Audio Output | Headphones |
| L/R Isolation | 100% |
| Perspective Correction | OFF |
| EQ Profile | Crisp |

### Sensitivity (Pro Meta - 863 players, Feb 2026)
- ~55% use 4:3 stretched, ~45% use 16:9
- Median eDPI: 830
- All pros: 400 or 800 DPI
- Notable: s1mple 400DPI 3.09, NiKo 400DPI 1.49, ZywOo 400DPI 2.0

---

## Arc Raiders

**Engine:** Unreal Engine 5 | **Type:** PvPvE Extraction | **Updated:** Feb 2026

### CRITICAL: Shadows Must Be Medium or Higher
Setting Shadows to Low **disables player shadows** - a significant competitive disadvantage.
Player shadows reveal enemy positions around corners.

### Display
| Setting | Value |
|---------|-------|
| Window Mode | Fullscreen |
| V-Sync | OFF |
| Frame Rate | Unlimited |
| FOV | 80-90 |

### Upscaling
| GPU | Setting | Quality |
|-----|---------|---------|
| NVIDIA | DLSS | Quality |
| AMD | FSR 3 | Quality |
| Either | Frame Generation | OFF (adds latency) |
| Either | NVIDIA Reflex / Anti-Lag | ON + Boost |

### Graphics
| Setting | Value | Note |
|---------|-------|------|
| Shadows | MEDIUM (minimum) | Low = no player shadows = disadvantage |
| Textures | High | Minimal FPS cost |
| Post Processing | Low | Removes bloom/lens effects |
| Effects | Low | Less combat clutter |
| Foliage | Low | Clearer sightlines |
| Global Illumination | Static GI | Dynamic GI = major FPS drain |
| Ambient Occlusion | OFF | |
| Motion Blur | OFF | |

### Audio
| Setting | Value | Reason |
|---------|-------|--------|
| Audio Preset | Night Mode | Compresses range, footsteps louder |
| Music Volume | 0 | Masks enemy sounds |
| Spatial Audio | ON | 3D positional audio |

---

## Windows System Settings

### Power Plan
```powershell
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
```

### Key Registry Tweaks Applied by Script
| Registry Path | Value | Effect |
|---------------|-------|--------|
| MMCSS\SystemProfile | SystemResponsiveness = 10 | 90% CPU to games |
| MMCSS\SystemProfile | NetworkThrottlingIndex = 0xFFFFFFFF | Remove network cap |
| MMCSS\Tasks\Games | Scheduling Category = High | Highest scheduler priority |
| Tcpip\Interfaces | TcpAckFrequency = 1 | Disable Nagle batching |
| Tcpip\Interfaces | TCPNoDelay = 1 | Send packets immediately |
| GraphicsDrivers | HwSchMode = 2 | Enable HAGS |
| GameConfigStore | GameDVR_Enabled = 0 | Disable background recording |

### NVIDIA Control Panel (Manual)
| Setting | Value |
|---------|-------|
| Power Management Mode | Prefer Maximum Performance |
| Low Latency Mode | On (Off if game has Reflex) |
| Vertical Sync | Off |
| Triple Buffering | Off |
| Texture Filtering Quality | High Performance |

---

## Hardware Upgrade Priority (if FPS-limited)

1. **Monitor** - 240Hz for competitive games; frames above monitor refresh are wasted
2. **GPU** - Primary bottleneck in most titles at 1080p/1440p
3. **CPU** - Secondary bottleneck; 6+ cores recommended, 8+ for streaming
4. **RAM** - 16GB DDR4 minimum; enable XMP/EXPO; dual-channel required
5. **Storage** - NVMe SSD for game install (reduces stutter from asset streaming)

---

*Sources: ProSettings.net (863 CS2 pros, 598 Valorant pros, 315 Fortnite pros, Feb 2026), Dexerto, PCGamesN, DotEsports, GameSpot, NVIDIA official guides*
