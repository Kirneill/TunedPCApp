# Arc Raiders - Competitive Settings Research
**Updated: February 2026 | Engine: Unreal Engine 5 | Type: PvPvE Extraction Shooter**

---

## Optimization Philosophy

Unlike pure competitive shooters, Arc Raiders is a **PvPvE extraction game** where visual clarity matters for both PvP fights and environmental awareness. Settings balance maximum FPS with maintaining enemy visibility.

**Key Differences from Pure FPS Games:**
- Shadows must be Medium minimum (Low disables player shadows = massive disadvantage)
- DLSS/FSR upscaling is strongly recommended for UE5 performance
- Night Mode audio is critical for hearing enemy footsteps in PvPvE
- Larger play spaces mean slightly lower sensitivity than Valorant/CS2

---

## CRITICAL WARNING: Shadow Settings

**NEVER set Shadows to Low in Arc Raiders.**

Setting Shadows to Low **disables player shadows entirely**. Player shadows reveal enemy positions around corners and behind cover. This is a **massive competitive disadvantage**.

**Minimum: MEDIUM shadows.**

---

## Display Settings

| Setting | Recommended Value | Reason |
|---------|------------------|--------|
| Window Mode | **Fullscreen Exclusive** | Lowest latency |
| Resolution | Native monitor (e.g., 1920x1080) | Match display |
| Frame Rate Limit | **Unlimited** (or monitor refresh) | Maximum responsiveness |
| V-Sync | **OFF** | Eliminates input latency |
| Brightness | 50 (default) | Adjust for your monitor |

---

## Upscaling (Critical for UE5 Performance)

### NVIDIA GPU
| Setting | Value | Reason |
|---------|-------|--------|
| Upscaling Mode | **DLSS** | Strongly recommended - ~20% FPS gain |
| DLSS Quality | **Quality** | Best image with significant FPS gain |
| DLSS Frame Generation | **OFF** | Adds input latency - not competitive |
| NVIDIA Reflex | **On + Boost** | 15-30ms latency reduction |

### AMD GPU
| Setting | Value | Reason |
|---------|-------|--------|
| Upscaling Mode | **FSR 3** or **TSR** | Best available for AMD |
| FSR Quality | **Quality** | Best balance |
| FSR Frame Generation | **OFF** | Adds input latency - not competitive |
| AMD Anti-Lag | **Enabled** | Latency reduction |

### General
| Setting | Value |
|---------|-------|
| Anti-Aliasing | TAA or DLSS (not TAAU - too blurry) |
| Frame Generation | **Always OFF** for competitive play |

---

## Graphics Quality (Competitive)

| Setting | Value | Reason |
|---------|-------|--------|
| Shadows | **MEDIUM (minimum!)** | Low = no player shadows = massive disadvantage |
| Shadow Distance | Medium | See shadows at useful ranges |
| Texture Quality | **High** | Minimal FPS cost, much better visibility |
| Post Processing | **Low** | Disables bloom, lens effects |
| Effects Quality | **Low** | Less visual clutter in combat |
| Foliage Quality | **Low** | Clearer sightlines through vegetation |
| Terrain Quality | Low-Medium | FPS gain |
| Object Detail | Medium | See objects clearly |
| Global Illumination | **Static GI** | Dynamic GI = major FPS drain |
| Ambient Occlusion | **OFF** | FPS drain |
| Motion Blur | **OFF** | Visual clarity |
| Depth of Field | **OFF** | Clarity at all ranges |
| Lens Flare | **OFF** | Visual distraction |
| Bloom | **OFF** | Visual noise |

---

## Hardware Tier Recommendations

### Entry-Level (RTX 3060 / RX 6600)
| Setting | Value |
|---------|-------|
| Quality Preset | Low (then raise shadows to Medium) |
| DLSS/FSR | Performance mode |
| Target FPS | 100-144 |

### Mid-Range (RTX 4070 / RX 7800 XT)
| Setting | Value |
|---------|-------|
| Quality Preset | Medium (then lower effects/foliage to Low) |
| DLSS/FSR | Quality mode |
| Target FPS | 144-240 |

### High-End (RTX 4090 / RX 7900 XTX)
| Setting | Value |
|---------|-------|
| Quality Preset | High (keep shadows High, effects Medium) |
| DLSS/FSR | Quality or off |
| Target FPS | 240+ |

---

## Audio Settings (Critical for Arc Raiders)

| Setting | Value | Reason |
|---------|-------|--------|
| Audio Preset | **Night Mode** | Compresses dynamic range - quiet sounds become louder |
| Master Volume | 80 | Clear audio |
| Music Volume | **0** | Extraction tension music masks enemy footsteps |
| SFX Volume | **100** | Maximum environmental awareness |
| UI Volume | 50 | Moderate |
| Voice Chat Volume | 70 | Team comms |
| Spatial Audio | **ON** | 3D positional audio for enemy detection |

**Night Mode** is especially important in Arc Raiders because the PvPvE environment has louder ambient sounds (AI enemies, environmental effects) that can mask player footsteps.

---

## Sensitivity

| Setting | Value | Notes |
|---------|-------|-------|
| Mouse Sensitivity | 0.15-0.25 | Slower than pure FPS games |
| ADS Sensitivity | 0.85 | Consistent with hipfire muscle memory |
| Scope Sensitivity | 0.85 | Consistent |
| FOV | **80-90** | 80 is competitive standard; higher hurts precision at distance |
| Polling Rate | 1000Hz | Recommended |

**Note:** Arc Raiders has larger play spaces than Valorant/CS2, so slightly lower sensitivity helps with precision at longer engagement distances.

---

## UE5 Engine.ini Overrides

The automation script writes an `Engine.ini` override to the user config folder:

**Location:** `%LOCALAPPDATA%\ArcRaiders\Saved\Config\Windows\Engine.ini`

### Key Engine Overrides
```ini
[SystemSettings]
r.ShaderPipelineCache.Mode=1          ; Reduces shader compilation stutter
r.AmbientOcclusionLevels=0            ; AO OFF
r.SSAO.Enabled=0                      ; SSAO OFF
r.LensFlareQuality=0                  ; Lens flare OFF
r.BloomQuality=0                      ; Bloom OFF
r.DepthOfFieldQuality=0               ; DOF OFF
r.MotionBlurQuality=0                 ; Motion blur OFF
r.Tonemapper.GrainQuantization=0      ; Film grain OFF
r.DynamicGlobalIlluminationMethod=0   ; Static GI only
r.Streaming.FullyLoadUsedTextures=1   ; Preload textures
```

---

## Known UE5 Issues

- **First launch:** Expect shader compilation stutter for approximately the first hour of gameplay
- **Patch 1.0.7:** Shadow LOD transitions were significantly improved
- **Frame Generation (DLSS/FSR):** Always OFF for competitive play - adds input latency
- The game is well-optimized for UE5 - mid-range hardware can hit 144fps at 1080p

---

## Sources
- GameSpot - Best Arc Raiders Graphics Settings
- ProSettings.net (Feb 2026)
- Unreal Engine 5 optimization documentation
