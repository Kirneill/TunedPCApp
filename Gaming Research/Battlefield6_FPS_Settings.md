# Battlefield 6 -- Competitive FPS Optimization Settings

**Status**: Released October 10, 2025 by EA/DICE. Frostbite engine. Steam App ID: 2807960.
**Anti-Cheat**: EA Javelin Anticheat (requires Secure Boot + TPM 2.0). Config file edits are safe.

---

## 1. Config File Locations

**Confidence: High**

| File | Path | Purpose |
|------|------|---------|
| PROFSAVE_profile | `%USERPROFILE%\Documents\Battlefield 6\settings\PROFSAVE_profile` | All graphics, audio, input settings (EA App) |
| PROFSAVE_profile (Steam) | `%USERPROFILE%\Documents\Battlefield 6\settings\steam\PROFSAVE_profile` | Steam variant |
| user.cfg | `<GAME_INSTALL_DIR>\user.cfg` | Console command overrides (does not exist by default) |
| Shader cache | `%LOCALAPPDATA%\Battlefield 6\cache` | Shader cache (safe to delete) |

The `PROFSAVE_profile` is a plaintext key-value file. Settings use the pattern `GstRender.SettingName Value`.
Config files are in `Documents\`, NOT in the game install directory.

---

## 2. Config File Format

**Frostbite key-value format** (same as BF2042):
- One setting per line: `GstRender.KeyName Value`
- Plain text, no sections, no JSON
- Spaces separate key from value
- Includes GstRender.*, GstAudio.*, GstInput.*, GstKeyBinding.* namespaces
- BF6 rewrites PROFSAVE_profile on exit -- set read-only after editing

---

## 3. In-Game Graphics Settings -- Competitive Values

### Quality Settings (0=Low, 1=Medium, 2=High, 3=Ultra)

| Setting (In-Game) | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **Texture Quality** | `GstRender.TextureQuality` | `2` (High) | Enemy readability -- most pros use High |
| **Texture Filtering** | `GstRender.TextureFiltering` | `2` (High) | Near-zero FPS cost |
| **Lighting Quality** | `GstRender.LightingQuality` | `0` (Low) | Major FPS gain |
| **Effects Quality** | `GstRender.EffectsQuality` | `0` (Low) | Reduces explosion/smoke clutter |
| **Post-Process Quality** | `GstRender.PostProcessQuality` | `0` (Low) | Removes blur, bloom, lens effects |
| **Mesh Quality** | `GstRender.MeshQuality` | `1` (Medium) | Low causes pop-in |
| **Undergrowth Quality** | `GstRender.UndergrowthQuality` | `0` (Low) | Critical for visibility |
| **Terrain Quality** | `GstRender.TerrainQuality` | `1` (Medium) | Low causes terrain pop-in |
| **Volumetric Quality** | `GstRender.VolumetricQuality` | `0` (Low) | Reduces fog/smoke density |
| **Shadow Quality** | `GstRender.ShadowQuality` | `0` (Low) | Major FPS gain |
| **Sun Shadow Quality** | `GstRender.SunShadowQuality` | `0` (Low) | Major FPS gain |
| **Local Light Shadow Quality** | `GstRender.LocalLightShadowQuality` | `0` (Low) | Minor FPS gain |
| **Shadow Filtering** | `GstRender.ShadowFiltering` | `0` (Low) | Reduces shadow softness |
| **Reflection Quality** | `GstRender.ReflectionQuality` | `0` (Low) | No competitive benefit |
| **Significance Quality** | `GstRender.SignificanceQuality` | `0` (Low) | Reduces detail at distance |
| **Anti-Aliasing** | `GstRender.NvidiaAntiAliasing` | `1` (TAA Low) | TAA is mandatory in Frostbite |
| **Ambient Occlusion** | `GstRender.AmbientOcclusion` | `0` (Off) | No competitive benefit |

### Rendering / Upscaling

| Setting | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **NVIDIA Upscaling** | `GstRender.NvidiaUpscalingTechnique` | `2` (DLSS Quality) | NVIDIA GPUs only |
| **NVIDIA Frame Gen** | `GstRender.NVIDIAFrameGenerationEnabled` | `0` (Off) | Adds latency |
| **Multi Frame Gen** | `GstRender.NvidiaMultiFrameGeneration` | `0` (Off) | Adds latency |
| **AMD Frame Gen** | `GstRender.AMDFrameGenerationEnabled` | `0` (Off) | Adds latency |
| **AMD/Intel Upscaling** | `GstRender.AMDIntelUpscalingTechnique` | `0` (Off) | Use native for AMD |
| **Intel Frame Gen** | `GstRender.IntelFrameGenerationEnabled` | `0` (Off) | Adds latency |
| **Frame Generation** | `GstRender.FrameGeneration` | `0` (Off) | Master toggle |
| **Future Frame Rendering** | `GstRender.FutureFrameRendering` | `1` (On) | 30-50% FPS uplift |
| **NVIDIA Reflex** | `GstRender.NvidiaLowLatency` | `2` (On+Boost) | Compensates for FFR latency |
| **DRS** | `GstRender.DRSEnabled` | `0` (Off) | Keeps resolution stable |
| **VSync** | `GstRender.VSyncMode` | `0` (Off) | Always off competitive |
| **HDR** | `GstRender.HighDynamicRangeMode` | `0` (Off) | Can add latency |
| **DX12** | `GstRender.Dx12Enabled` | `1` (On) | BF6 runs DX12 natively |
| **GPU Memory** | `GstRender.GpuMemRestriction` | `0` (Off) | Let game use VRAM freely |

### Visual Effects (0=Off, 1=On)

| Setting | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **Motion Blur (World)** | `GstRender.MotionBlurWorld` | `0.0` | Always off |
| **Motion Blur (Weapon)** | `GstRender.MotionBlurWeapon` | `0.0` | Always off |
| **Chromatic Aberration** | `GstRender.ChromaticAberration` | `0` | Removes color fringing |
| **Film Grain** | `GstRender.FilmGrain` | `0` | Removes noise overlay |
| **Vignette** | `GstRender.Vignette` | `0` | Removes edge darkening |
| **Lens Distortion** | `GstRender.LensDistortion` | `0` | Removes barrel distortion |
| **Weapon DOF** | `GstRender.WeaponDOF` | `0` | Removes depth of field on weapon |
| **Screen Space Reflections** | `GstRender.ScreenSpaceReflections` | `0` | No competitive benefit |

### Display / Frame Rate

| Setting | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **Frame Rate Limiter** | `GstRender.FrameRateLimiterEnable` | `1` | Enable for stable pacing |
| **Frame Rate Limit** | `GstRender.FrameRateLimit` | `<refresh-3>` | Cap 3 below monitor Hz |
| **FOV** | `GstRender.FieldOfViewVertical` | `90` | 85-105 common, 90 default |
| **Overall Quality** | `GstRender.OverallGraphicsQuality` | `5` (Custom) | Auto-set when custom values used |

---

## 4. PROFSAVE_profile -- Competitive Preset

```ini
GstRender.OverallGraphicsQuality 5
GstRender.TextureQuality 2
GstRender.TextureFiltering 2
GstRender.LightingQuality 0
GstRender.EffectsQuality 0
GstRender.PostProcessQuality 0
GstRender.MeshQuality 1
GstRender.UndergrowthQuality 0
GstRender.TerrainQuality 1
GstRender.VolumetricQuality 0
GstRender.ShadowQuality 0
GstRender.SunShadowQuality 0
GstRender.LocalLightShadowQuality 0
GstRender.ShadowFiltering 0
GstRender.ReflectionQuality 0
GstRender.SignificanceQuality 0
GstRender.AmbientOcclusion 0
GstRender.NvidiaAntiAliasing 1
GstRender.NvidiaUpscalingTechnique 0
GstRender.NVIDIAFrameGenerationEnabled 0
GstRender.NvidiaMultiFrameGeneration 0
GstRender.AMDFrameGenerationEnabled 0
GstRender.AMDIntelUpscalingTechnique 0
GstRender.IntelFrameGenerationEnabled 0
GstRender.FrameGeneration 0
GstRender.FutureFrameRendering 1
GstRender.NvidiaLowLatency 2
GstRender.DRSEnabled 0
GstRender.VSyncMode 0
GstRender.HighDynamicRangeMode 0
GstRender.Dx12Enabled 1
GstRender.GpuMemRestriction 0
GstRender.MotionBlurWorld 0.000000
GstRender.MotionBlurWeapon 0.000000
GstRender.ChromaticAberration 0
GstRender.FilmGrain 0
GstRender.Vignette 0
GstRender.LensDistortion 0
GstRender.WeaponDOF 0
GstRender.ScreenSpaceReflections 0
GstRender.FrameRateLimiterEnable 1
```

---

## 5. Settings Safety

**Safe to change** (performance keys): All GstRender.* quality, effects, upscaling, and display settings listed above.

**Must preserve**: Resolution, refresh rate, fullscreen mode, aspect ratio, HDR peak luma, color blind mode, HUD colors, shader bundle version, all GstAudio.*, GstInput.*, GstKeyBinding.* keys.

---

## 6. Anti-Cheat (Javelin)

- Config file edits (PROFSAVE_profile) are **safe** -- Javelin does not monitor these files
- Javelin requires Secure Boot + TPM 2.0 enabled
- Avoid kernel-level controller remapping software while playing
- Standard Windows optimizations, GPU driver changes, and registry tweaks are safe

---

## 7. Installation Paths

| Platform | Path |
|---|---|
| **Steam** | `C:\Program Files (x86)\Steam\steamapps\common\Battlefield 6\` |
| **EA App** | `C:\Program Files\EA Games\Battlefield 6\` |
| **Executable** | `bf6.exe` |
| **Steam App ID** | 2807960 |

### Detection Logic

```powershell
# 1. Check EA App registry
$bf6Path = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\EA Games\Battlefield 6" -ErrorAction SilentlyContinue)."Install Dir"

# 2. Check Steam uninstall registry (App ID 2807960)
if (!$bf6Path) {
    $bf6Path = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2807960" -ErrorAction SilentlyContinue).InstallLocation
}

# 3. Check Steam library VDF
# steamFolders: ['Battlefield 6']

# 4. Fallback defaults
if (!$bf6Path -and (Test-Path "C:\Program Files\EA Games\Battlefield 6")) {
    $bf6Path = "C:\Program Files\EA Games\Battlefield 6"
}
```

---

## 8. Key Differences from BF2042

| Feature | BF2042 | BF6 |
|---|---|---|
| VSync key | `GstRender.VSyncEnabled` | `GstRender.VSyncMode` |
| Motion blur | `GstRender.MotionBlurEnabled` | `GstRender.MotionBlurWorld` + `GstRender.MotionBlurWeapon` |
| Reflex key | `GstRender.NvidiaReflex` | `GstRender.NvidiaLowLatency` |
| Frame Gen | Not supported | `GstRender.NVIDIAFrameGenerationEnabled` (DLSS 3) |
| Multi Frame Gen | Not supported | `GstRender.NvidiaMultiFrameGeneration` (DLSS 4) |
| Volumetric Quality | Not present | `GstRender.VolumetricQuality` |
| Shadow keys | Single `ShadowQuality` | Split into Shadow/SunShadow/LocalLightShadow |

---

## Confidence Summary

| Category | Confidence |
|---|---|
| Config file locations | **High** |
| Config file format | **High** |
| PROFSAVE key names | **High** (verified against 3 real configs) |
| Recommended values | **High** (cross-referenced 6+ guides) |
| Anti-cheat safety | **High** (EA official + community confirmed) |
| Steam App ID | **High** (2807960) |
| Installation paths | **High** |

---

## Sources

- [EA Official BF6 Launch Guide](https://www.ea.com/en/games/battlefield/battlefield-6/news/get-ready-for-battlefield-6)
- [Steam Store](https://store.steampowered.com/app/2807960/Battlefield_6/)
- [ProSettings.net BF6 Guide](https://prosettings.net/guides/battlefield-6-options/)
- [Dexerto BF6 Best Settings](https://www.dexerto.com/wikis/battlefield-6/best-pc-settings-for-graphics-fps/)
- [GameWatcher Config Location](https://www.gamewatcher.com/news/battlefield-6-config-file-location-how-to-find-the-folder-and-back-settings-up)
- [Frondtech Save Location](https://frondtech.com/battlefield-6-save-and-config-file-location/)
