# Counter-Strike 2 (CS2) - Competitive Settings Research
**Updated: February 2026 | Engine: Source 2**

---

## Important: Deprecated Launch Options

The following Source 1 launch options are **DEPRECATED in CS2** and should NOT be used:
- `-tickrate` - Has no effect in Source 2
- `-threads` - Has no effect in Source 2
- `-freq` / `-rate` - Has no effect in Source 2
- `-processheap` - Source 1 only

**Valid Launch Options:**
```
-novid -high -nojoy +exec autoexec.cfg
```

| Option | Effect |
|--------|--------|
| `-novid` | Skips intro video (~5 seconds saved per launch) |
| `-high` | Sets CS2 process to High CPU priority |
| `-nojoy` | Disables joystick subsystem (frees minor CPU cycles) |
| `+exec autoexec.cfg` | Loads competitive autoexec on launch |

---

## Video Settings

| Setting | Recommended Value | Reason |
|---------|------------------|--------|
| Display Mode | **Fullscreen Exclusive** | Lowest latency |
| Resolution | **1920x1080** (16:9) or **1280x960** (4:3 stretched) | Personal preference - see pro stats below |
| Refresh Rate | Maximum monitor Hz | Full capability |
| Boost Player Contrast | **ON** | **Critical** - makes enemies visibly stand out from background |
| V-Sync | **Disabled** | Eliminates latency |
| NVIDIA Reflex | **Enabled** | 15-30ms latency reduction |

---

## Advanced Video Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Global Shadow Quality | **Low** | FPS gain, minimal competitive loss (some pros use Medium for read shadows) |
| Model/Texture Detail | **Low** | FPS gain |
| Texture Streaming | **Disabled** | Prevents pop-in |
| Effect Detail | **Low** | Less visual clutter |
| Shader Detail | **Low** | FPS gain |
| Boost Player Contrast | **Enabled** | Repeat for emphasis - most impactful visual setting |
| Multicore Rendering | **Enabled** | Required for modern CPUs |
| FidelityFX Super Res. | **Disabled** | Or Quality if GPU-limited |
| NVIDIA DLSS | **Disabled** | Or Quality if GPU-limited |
| Ambient Occlusion | **Disabled** | FPS drain |
| Anti-Aliasing | **4x MSAA** | Improves model edge clarity (CMAA2 if FPS-limited) |
| High Dynamic Range | **Performance** | Better performance mode |

---

## Audio Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Audio Output | **Headphones** | Critical for HRTF positioning |
| L/R Isolation | **100%** | Maximum directional separation |
| Perspective Correction | **Disabled** | Improves left-right distinction |
| EQ Profile | **Crisp** | Emphasizes footstep frequencies |
| Stream Music | **OFF** | No distractions |

---

## Autoexec.cfg Key Settings

The automation script writes a comprehensive `autoexec.cfg`:

### Network Settings (Critical for hit registration)
```
rate 786432              // Maximum packet rate (768KB/s)
cl_updaterate 128        // Max updates per second from server
cl_cmdrate 128           // Max commands per second to server
cl_interp 0              // Minimum interpolation
cl_interp_ratio 1        // Minimal interpolation delay
cl_lagcompensation 1     // Standard lag compensation
```

### Performance
```
fps_max [refresh+10]     // Cap with GPU headroom for stable pacing
fps_max_menu 60          // Save GPU in menus
r_dynamic 0              // Disable dynamic lighting
```

### Audio
```
snd_mixahead 0.05        // Lower audio buffer (less latency, safe for most systems)
snd_musicvolume 0.0      // No music
snd_tensecondwarning_volume 0.3  // Hear bomb timer
```

### Mouse
```
m_rawinput 1             // Direct mouse input, bypass Windows
sensitivity 2.0          // PLACEHOLDER - set your own
m_mouseaccel1 0          // No acceleration
m_mouseaccel2 0
zoom_sensitivity_ratio_mouse 1.0
```

### Radar (Competitive)
```
cl_radar_always_centered 0   // See more of the map
cl_radar_scale 0.4           // Zoomed out
cl_radar_rotate 1            // Perspective-relative
cl_hud_radar_scale 1.15      // Slightly larger HUD radar
```

### Viewmodel
```
viewmodel_fov 68             // Maximum allowed FOV
viewmodel_presetpos 3        // Desktop preset
```

---

## Sensitivity (Pro Meta - 863 Players Analyzed)

| Statistic | Value |
|-----------|-------|
| **~55% use 4:3 stretched** | 1280x960 |
| **~45% use 16:9 native** | 1920x1080 |
| **Median eDPI** | **830** |
| **100% use 400 or 800 DPI** | No exceptions |
| **100% MSAA enabled** | 4x most common |

### Notable Pro Settings
| Player | DPI | Sensitivity | eDPI |
|--------|-----|-------------|------|
| s1mple | 400 | 3.09 | 1236 |
| NiKo | 400 | 1.49 | 596 |
| ZywOo | 400 | 2.0 | 800 |

---

## 4:3 Stretched Resolution Setup

If using stretched (1280x960):
1. **NVIDIA Control Panel:** Manage 3D > Resolution: 1280x960 > Adjust desktop size: Full-screen
2. **In CS2:** Set resolution to 1280x960, Aspect Ratio: Normal
3. Game stretches to fill screen, making player models appear wider

**Pros:** Wider player models, potentially easier to track
**Cons:** Reduced peripheral vision, smaller FOV

---

## Config File Location

**Autoexec:** `[Steam]\steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg\autoexec.cfg`

The script also sets Steam launch options via registry at `HKCU\Software\Valve\Steam\Apps\730`.

---

## Sources
- ProSettings.net - 863 CS2 pros (Feb 2026)
- PCGamesN - Best CS2 Settings 2026
- Valve Developer Community - Source 2 documentation
