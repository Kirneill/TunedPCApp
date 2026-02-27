# Battlefield 2042 -- Competitive FPS Optimization Settings (2025/2026)

**Status**: BF2042 remains the latest mainline Battlefield title. EA/DICE ended live-service content with Season 7 (early 2024). Settings architecture has been stable since ~Season 4/5.

---

## 1. Config File Locations

**Confidence: High**

| File | Path | Purpose |
|------|------|---------|
| PROFSAVE_profile | `%USERPROFILE%\Documents\Battlefield 2042\settings\PROFSAVE_profile` | All graphics, audio, input settings |
| PROFSAVE_profile_synced | Same directory | Cloud-synced copy |
| Startup config | `%USERPROFILE%\Documents\Battlefield 2042\settings\startup.cfg` | Launch-time overrides |
| Cache | `%LOCALAPPDATA%\Battlefield 2042\cache` | Shader cache (safe to delete) |

The `PROFSAVE_profile` is a plaintext key-value file. Settings use the pattern `GstRender.SettingName Value`.

---

## 2. In-Game Graphics Settings -- Competitive Values

### Core Graphics Settings

| Setting (In-Game) | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **Texture Quality** | `GstRender.TextureQuality` | `Medium` (1) | Minimal FPS impact above Medium |
| **Texture Filtering** | `GstRender.TextureFiltering` | `Ultra` (4) | Near-zero FPS cost; improves readability |
| **Lighting Quality** | `GstRender.LightingQuality` | `Low` (0) | Major FPS gain |
| **Effects Quality** | `GstRender.EffectsQuality` | `Low` (0) | Large FPS impact in 128p; reduces clutter |
| **Post-Process Quality** | `GstRender.PostProcessQuality` | `Low` (0) | Removes blur, bloom, lens effects |
| **Mesh Quality** | `GstRender.MeshQuality` | `Medium` (1) | Low causes pop-in at range |
| **Undergrowth Quality** | `GstRender.UndergrowthQuality` | `Low` (0) | Critical for visibility |
| **Terrain Quality** | `GstRender.TerrainQuality` | `Medium` (1) | Low causes terrain pop-in |
| **Anti-Aliasing** | `GstRender.AntiAliasingPost` | `TAA Low` (1) | TAA is mandatory in Frostbite |
| **Ambient Occlusion** | `GstRender.AmbientOcclusion` | `Off` (0) | No competitive benefit |

PROFSAVE value mapping: 0=Low/Off, 1=Medium/Low, 2=High/Medium, 3=Ultra/High, 4=Ultra

### Rendering / Upscaling

| Setting | PROFSAVE Key | Competitive Value | Notes |
|---|---|---|---|
| **DLSS** | `GstRender.DlssEnabled` / `GstRender.DlssQuality` | `Quality` or `Balanced` | NVIDIA GPUs |
| **FSR 2.0** | `GstRender.Fsr2Enabled` / `GstRender.Fsr2Quality` | `Quality` | AMD GPUs |
| **Future Frame Rendering** | `GstRender.FutureFrameRendering` | `On` (1) | **Critical** -- 30-50% FPS uplift |
| **NVIDIA Reflex** | `GstRender.NvidiaReflex` | `On + Boost` (2) | Compensates for FFR latency |
| **Ray Tracing** | `GstRender.RayTracedAmbientOcclusion` | `Off` (0) | 15-25% FPS cost |
| **GPU Memory Restriction** | `GstRender.GpuMemRestriction` | `Off` (0) | Let game use VRAM freely |
| **Vertical Sync** | `GstRender.VSyncEnabled` | `Off` (0) | Always off |
| **HDR** | `GstRender.HDREnabled` | `Off` (0) | Can add latency |

---

## 3. PROFSAVE_profile -- Competitive Preset

```ini
GstRender.TextureQuality 1
GstRender.TextureFiltering 4
GstRender.LightingQuality 0
GstRender.EffectsQuality 0
GstRender.PostProcessQuality 0
GstRender.MeshQuality 1
GstRender.UndergrowthQuality 0
GstRender.TerrainQuality 1
GstRender.AntiAliasingPost 1
GstRender.AmbientOcclusion 0
GstRender.FutureFrameRendering 1
GstRender.VSyncEnabled 0
GstRender.NvidiaReflex 2
GstRender.RayTracedAmbientOcclusion 0
GstRender.GpuMemRestriction 0
GstRender.HDREnabled 0
GstRender.MotionBlurEnabled 0
GstRender.ChromaticAberrationEnabled 0
GstRender.VignetteEnabled 0
GstRender.FilmGrainEnabled 0
GstRender.LensDistortionEnabled 0
```

**Important**: Set file to **read-only** after editing to prevent overwrites:
```powershell
Set-ItemProperty -Path "$env:USERPROFILE\Documents\Battlefield 2042\settings\PROFSAVE_profile" -Name IsReadOnly -Value $true
```

---

## 4. Launch Options

### EA App / Steam
| Argument | Effect |
|---|---|
| `-high` | Sets process priority to High |
| `-dx12` | Force DX12 (default anyway) |
| `-malloc=system` | System memory allocator (helps stuttering) |
| `-refresh <Hz>` | Force specific refresh rate |

---

## 5. NVIDIA Driver Settings (per bf2042.exe)

| Setting | Value |
|---|---|
| Power Management Mode | Prefer Maximum Performance |
| Texture Filtering Quality | High Performance |
| Threaded Optimization | On |
| Low Latency Mode | Ultra (if not using in-game Reflex) |
| Shader Cache Size | Unlimited |
| V-Sync | Off |
| Max Frame Rate | Match monitor Hz |

**Confidence: High**

---

## 6. AMD Driver Settings

| Setting | Value |
|---|---|
| Radeon Anti-Lag | Enabled |
| Radeon Boost | Off |
| Radeon Chill | Off |
| Wait for Vertical Refresh | Off |
| Texture Filtering Quality | Performance |
| Shader Cache | Reset, then Enabled |
| Tessellation Mode | Override / Off |

---

## 7. Windows Registry / OS Tweaks

| Tweak | Path | Value |
|---|---|---|
| Disable Game DVR | `HKCU\Software\Microsoft\GameBar` > `AllowAutoGameDVR` | `0` (DWORD) |
| HAGS | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` > `HwSchMode` | `2` (DWORD) |
| Disable fullscreen optimizations | `HKCU\...\AppCompatFlags\Layers` for bf2042.exe | `~ DISABLEDXMAXIMIZEDWINDOWEDMODE` |
| Nagle's Algorithm | `HKLM\...\Tcpip\Parameters\Interfaces\{GUID}` | `TcpAckFrequency=1`, `TCPNoDelay=1` |
| Timer resolution | `bcdedit /set useplatformtick yes` | Reduces timer granularity |

---

## 8. Visual Clutter Reduction (128-Player Modes)

1. **Effects Quality = Low** -- Reduces explosion particles, smoke density, debris
2. **Undergrowth Quality = Low** -- Removes most ground foliage
3. **Post-Process Quality = Low** -- Eliminates bloom, lens flare, blur
4. **Lighting Quality = Low** -- Reduces dynamic shadow complexity
5. **Motion Blur = Off** -- Essential for target acquisition
6. **Chromatic Aberration = Off** -- Removes color fringing
7. **Film Grain = Off** -- Removes noise overlay
8. **Vignette = Off** -- Removes darkening at edges
9. **Lens Distortion = Off** -- Removes barrel distortion

---

## 9. Shader Cache Management

```powershell
# Delete BF2042 shader cache
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Battlefield 2042\cache\*"

# Delete NVIDIA DX12 shader cache
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\NVIDIA\DXCache\*"

# Delete AMD shader cache
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\AMD\DxCache\*"
```

Expect 1-2 matches of compilation stuttering after clearing.

---

## 10. DLSS / FSR Decision Matrix

| GPU | Recommendation |
|---|---|
| NVIDIA RTX 40-series | DLSS Quality or Balanced |
| NVIDIA RTX 30-series | DLSS Quality |
| NVIDIA RTX 20-series | DLSS Quality |
| AMD RX 7000-series | FSR 2.0 Quality |
| AMD RX 6000-series | FSR 2.0 Quality/Balanced |
| Below 1080p | Neither -- run native |

**Note**: BF2042 supports DLSS 2.x but does NOT support DLSS 3 Frame Generation natively.

---

## Confidence Summary

| Category | Confidence |
|---|---|
| Config file locations | **High** |
| In-game setting names | **High** |
| PROFSAVE key names | **Medium** |
| Recommended values | **High** |
| Launch options | **Medium** |
| Driver settings | **High** |
| Registry tweaks | **High** |
| DLSS/FSR support | **High** |

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

| Platform | Registry Key / Method |
|---|---|
| **Steam** | Parse `libraryfolders.vdf` for app ID `1517290` |
| **EA App** | `HKLM\SOFTWARE\WOW6432Node\EA Games\Battlefield 2042` > `Install Dir` |
| **EA App (alt)** | Check `C:\Program Files\EA Games\Battlefield 2042\` or EA Desktop manifest files |
| **Origin (legacy)** | `HKLM\SOFTWARE\WOW6432Node\Origin\` then parse `C:\ProgramData\Origin\LocalContent\` manifests |
| **Uninstall** | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{BF2042 GUID}` > `InstallLocation` |

**Default Install Paths:**
```
Steam:  C:\Program Files (x86)\Steam\steamapps\common\Battlefield 2042\
EA App: C:\Program Files\EA Games\Battlefield 2042\
Origin: C:\Program Files (x86)\Origin Games\Battlefield 2042\
```

**Detection logic:**
```powershell
# 1. Check EA registry
$bf2042Path = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\EA Games\Battlefield 2042" -ErrorAction SilentlyContinue)."Install Dir"

# 2. Check Steam
if (!$bf2042Path) {
    $steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    $defaultSteam = "$steamPath\steamapps\common\Battlefield 2042"
    if (Test-Path $defaultSteam) { $bf2042Path = $defaultSteam }
}

# 3. Fallback defaults
if (!$bf2042Path -and (Test-Path "C:\Program Files\EA Games\Battlefield 2042")) {
    $bf2042Path = "C:\Program Files\EA Games\Battlefield 2042"
}
```

### Config File Paths

| File | Full Path | Read-Only Needed? |
|---|---|---|
| `PROFSAVE_profile` | `%USERPROFILE%\Documents\Battlefield 2042\settings\PROFSAVE_profile` | **Recommended** — BF2042 can overwrite on exit |
| `startup.cfg` | `%USERPROFILE%\Documents\Battlefield 2042\settings\startup.cfg` | No |
| Shader cache | `%LOCALAPPDATA%\Battlefield 2042\cache\` | N/A — safe to delete for rebuilds |

**Note:** Config files are in `Documents\`, NOT in the game install directory. This path is the same regardless of Steam/EA App install.

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `BF2042.exe` | `<GAME_INSTALL_DIR>\BF2042.exe` | **YES** — primary game process |
| `BF2042_Trial.exe` | `<GAME_INSTALL_DIR>\BF2042_Trial.exe` | No — trial version only |
| `EADesktop.exe` | N/A | No — EA client |

### Read-Only Config Behavior

**Setting PROFSAVE_profile to read-only is recommended.** BF2042 rewrites this file when you change settings in-game or exit. Without read-only, manual edits may be overwritten.

```powershell
$profPath = "$env:USERPROFILE\Documents\Battlefield 2042\settings\PROFSAVE_profile"
# Write optimized config first, THEN set read-only
Set-ItemProperty -Path $profPath -Name IsReadOnly -Value $true
```

**Caveat:** Read-only prevents the game from saving ANY settings changes made in-game. Players must remove read-only to adjust settings through the UI.

### Anti-Cheat Considerations (EA Anti-Cheat)

**EA Anti-Cheat (EAAC)** replaced FairFight in BF2042. Key considerations:
- **Config file edits are safe** — EAAC does not monitor PROFSAVE_profile
- **Registry tweaks are safe** — standard Windows gaming optimizations are not flagged
- **GPU driver changes are safe** — NVIDIA/AMD control panel changes are fine
- **Shader cache deletion is safe** — game rebuilds automatically
- **DO NOT** use memory editing, packet manipulation, or unauthorized injection tools
