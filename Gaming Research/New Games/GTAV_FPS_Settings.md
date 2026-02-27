# GTA V PC FPS Optimization Settings -- Comprehensive Reference

## Config File Locations

GTA V stores its settings in two XML files:

| File | Path | Purpose |
|------|------|---------|
| `settings.xml` | `%USERPROFILE%\Documents\Rockstar Games\GTA V\settings.xml` | Main graphics and game settings |
| `commandline.txt` | Game installation directory root (beside `GTA5.exe`) | Launch arguments |

**Note:** The Documents path may vary if the user has redirected their Documents folder. The canonical environment variable expansion is `%USERPROFILE%\Documents\Rockstar Games\GTA V\`.

**Confidence: High** -- This has been stable since GTA V PC launch in 2015 and is well-documented across PCGamingWiki, Rockstar support, and community sources.

---

## 1. settings.xml Graphics Settings (Main Section)

All values below are within `<graphics>` in `settings.xml`. Values use integer encoding where the in-game slider/dropdown maps to specific integers.

### HIGH-IMPACT SETTINGS (Largest FPS gains)

| XML Element | In-Game Name | Recommended Value | Range | FPS Impact | Confidence |
|---|---|---|---|---|---|
| `<MSAA>` | MSAA | `0` | 0, 2, 4, 8 | **Very High** -- disabling MSAA is the single largest FPS gain | High |
| `<MSAAFragments>` | MSAA Fragments | `0` | 0, 2, 4, 8 (matches MSAA) | **Very High** | High |
| `<TXAA>` | FXAA | `0` (off) or `1` (on as cheap alternative to MSAA) | 0, 1 | Low cost, use as MSAA replacement | High |
| `<PostFX>` | Post FX | `0` (Normal) or `1` (High) | 0-3 (Normal/High/Very High/Ultra) | **High** -- controls motion blur, bloom, HDR | High |
| `<Shadow_Quality>` | Shadow Quality | `0` (Normal) or `1` (High) | 0-3 (Normal/High/Very High/Ultra) | **High** | High |
| `<Reflection_Quality>` | Reflection Quality | `0` (Normal) | 0-3 (Normal/High/Very High/Ultra) | **High** | High |
| `<Reflection_MSAA>` | Reflection MSAA | `0` (off) | 0, 2, 4, 8 | **High** | High |
| `<SSAO>` | Ambient Occlusion | `0` (off) or `1` (Normal) | 0-2 (Off/Normal/High) | **High** | High |
| `<Grass_Quality>` | Grass Quality | `0` (Normal) or `1` (High) | 0-4 (Normal/High/Very High/Ultra/?) | **Medium-High** -- especially outside city | High |
| `<Water_Quality>` | Water Quality | `0` (Normal) | 0-2 (Normal/High/Very High) | **Medium** | High |

### MEDIUM-IMPACT SETTINGS

| XML Element | In-Game Name | Recommended Value | Range | FPS Impact | Confidence |
|---|---|---|---|---|---|
| `<Shader_Quality>` | Shader Quality | `1` (High) | 0-2 (Normal/High/Very High) | **Medium** | High |
| `<Shadow_SoftShadows>` | Soft Shadows | `1` (Softer) | 0-4 (Sharp/Softer/Softest/PCSS-like/AMD CHS) | **Medium** | High |
| `<Particle_Quality>` | Particles Quality | `0` (Normal) or `1` (High) | 0-2 (Normal/High/Very High) | **Medium** (spikes during explosions) | High |
| `<Tessellation>` | Tessellation | `0` (Off) or `1` (Normal) | 0-3 (Off/Normal/High/Very High) | **Medium** | High |
| `<TextureQuality>` | Texture Quality | `1` (High) or `2` (Very High) | 0-2 (Normal/High/Very High) | **Low** (VRAM dependent, not FPS) | High |

### LOW-IMPACT SETTINGS (Keep higher for visual quality)

| XML Element | In-Game Name | Recommended Value | Range | FPS Impact | Confidence |
|---|---|---|---|---|---|
| `<Anisotropic_Filtering>` | Anisotropic Filtering | `16` | 0-16 | **Very Low** -- nearly free on modern GPUs | High |
| `<Texture_Filter_Quality>` | Texture Filtering | `4` (x16) | 0-4 | **Very Low** | Medium |

---

## 2. Advanced Graphics Settings

These are also in `settings.xml` under `<graphics>`, but correspond to the "Advanced Graphics" menu in-game.

| XML Element | In-Game Name | Recommended Value | Default | FPS Impact | Confidence |
|---|---|---|---|---|---|
| `<Shadow_Long_Shadows>` | Long Shadows | `0` (Off) | 0 | **Medium** at dusk/dawn | High |
| `<Shadow_High_Detail>` | High Resolution Shadows | `0` (Off) | 0 | **Medium** | High |
| `<HD_Streaming>` | High Detail Streaming While Flying | `0` (Off) | 0 | **Medium** (VRAM + CPU) | High |
| `<Extended_Distance_Scaling>` | Extended Distance Scaling | `0.00` (0%) | 0.00 | **High** -- significant draw distance cost | High |
| `<Extended_Shadows_Distance>` | Extended Shadows Distance | `0.00` (0%) | 0.00 | **Medium-High** | High |

**Important note on scaling values:** `Extended_Distance_Scaling` and `Extended_Shadows_Distance` are float values from 0.00 to 1.00 (representing 0% to 100%). Setting both to 0.00 provides meaningful FPS gains with minimal visual loss during normal gameplay.

---

## 3. Population and World Density Settings

These are in `settings.xml` but outside `<graphics>`, under the `<video>` or root section.

| XML Element | In-Game Name | Recommended Value | Range | FPS Impact | Confidence |
|---|---|---|---|---|---|
| `<PedLodBias>` | Population Density | `0.00` to `0.50` | 0.00-1.00 (float) | **Medium** -- fewer NPCs = less CPU load | Medium |
| `<PedVarietyMultiplier>` | Population Variety | `0.50` | 0.00-1.00 (float) | **Low-Medium** | Medium |
| `<VehicleLodBias>` | Distance Scaling | `0.00` to `0.50` | 0.00-1.00 (float) | **Medium** | Medium |

---

## 4. Resolution and Upscaling

| XML Element | In-Game Name | Recommended Value | Notes | Confidence |
|---|---|---|---|---|
| `<ScreenWidth>` | Resolution Width | Native or lower | Integer pixel count | High |
| `<ScreenHeight>` | Resolution Height | Native or lower | Integer pixel count | High |
| `<DirectXVersion>` | DirectX Version | `2` (DX11) | 0=DX10, 1=DX10.1, 2=DX11 | High |

**DLSS / FSR Note:** The base GTA V (non-Enhanced Edition) does **not** natively support DLSS or FSR. The "GTA V Enhanced" (released 2025 for PC) is a separate product.

---

## 5. Launch Options (commandline.txt)

Create a file called `commandline.txt` in the GTA V installation directory with these flags:

```
-high
-ignoreDifferentVideoCard
-disableHyperthreading
-noqueryaliasing
```

| Flag | Effect | FPS Impact | Confidence |
|---|---|---|---|
| `-high` | Sets process priority to High | Low-Medium (helps CPU-bound scenarios) | High |
| `-ignoreDifferentVideoCard` | Skips GPU change detection, faster launch | None (stability) | High |
| `-disableHyperthreading` | Can help on some AMD CPUs with scheduling issues | Varies (test both) | Medium |
| `-noqueryaliasing` | Disables query-based AA | Low | Medium |
| `-frameLimit 0` | Uncaps frame rate | Removes artificial cap | Medium |
| `-width X -height Y` | Force resolution | N/A | High |

**Steam launch options** (set in Steam game properties):
```
-high -ignoreDifferentVideoCard
```

---

## 6. NVIDIA-Specific Optimizations

| Setting | Recommended Value | Method | Confidence |
|---|---|---|---|
| Power Management Mode | Prefer Maximum Performance | NVIDIA Control Panel > 3D Settings > GTA5.exe | High |
| Texture Filtering Quality | High Performance | NVIDIA Control Panel | High |
| Threaded Optimization | On | NVIDIA Control Panel | High |
| Shader Cache Size | Unlimited | NVIDIA Control Panel (driver 530+) | High |
| Low Latency Mode | On (not Ultra) | NVIDIA Control Panel or Reflex if supported | Medium |
| Max Frame Rate | Match monitor refresh or uncapped | NVIDIA Control Panel | High |

---

## 7. AMD-Specific Optimizations

| Setting | Recommended Value | Method | Confidence |
|---|---|---|---|
| Radeon Anti-Lag | Enabled | AMD Software: Adrenalin | High |
| Radeon Boost | Enabled (optional) | AMD Software: Adrenalin | Medium |
| Tessellation Mode | Override Application Settings: Off | AMD Software | Medium |
| Surface Format Optimization | Enabled | AMD Software | Medium |
| Shader Cache | Perform Reset, then Enabled | AMD Software | High |

---

## 8. Registry Tweaks (Windows-Level)

| Registry Path | Value | Data | Effect | Confidence |
|---|---|---|---|---|
| `HKCU\System\GameConfigStore` | `GameDVR_Enabled` (DWORD) | `0` | Disable Game DVR/Bar recording overhead | High |
| `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR` | `AppCaptureEnabled` (DWORD) | `0` | Disable Game DVR capture | High |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games` | `GPU Priority` (DWORD) | `8` | Increase GPU scheduling priority for games | Medium |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games` | `Priority` (DWORD) | `6` | Increase CPU scheduling priority | Medium |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games` | `Scheduling Category` (REG_SZ) | `High` | MMCSS scheduling | Medium |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` | `SystemResponsiveness` (DWORD) | `0` | Reserve 0% CPU for background (default 20%) | Medium |

**GTA V does not have its own registry keys for graphics settings.** All graphics config is in `settings.xml`.

---

## 9. Recommended "Max FPS" settings.xml Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Settings>
  <graphics>
    <DirectXVersion value="2" />           <!-- DX11 -->
    <TextureQuality value="1" />           <!-- High (VRAM cheap, big visual win) -->
    <ShaderQuality value="1" />            <!-- High -->
    <Shadow_Quality value="0" />           <!-- Normal -->
    <Reflection_Quality value="0" />       <!-- Normal -->
    <Reflection_MSAA value="0" />          <!-- Off -->
    <Water_Quality value="0" />            <!-- Normal -->
    <Particles_Quality value="0" />        <!-- Normal -->
    <Grass_Quality value="0" />            <!-- Normal -->
    <PostFX value="0" />                   <!-- Normal -->
    <MSAA value="0" />                     <!-- Off -->
    <MSAAFragments value="0" />            <!-- Off -->
    <FXAA value="1" />                     <!-- On (cheap AA replacement) -->
    <SSAO value="0" />                     <!-- Off -->
    <Anisotropic_Filtering value="8" />    <!-- x8 (nearly free) -->
    <Tessellation value="0" />             <!-- Off -->
    <Shadow_SoftShadows value="1" />       <!-- Softer -->
    <Shadow_Long_Shadows value="0" />      <!-- Off -->
    <Shadow_High_Detail value="0" />       <!-- Off -->
    <HD_Streaming value="0" />             <!-- Off -->
    <Extended_Distance_Scaling value="0.000000" />
    <Extended_Shadows_Distance value="0.000000" />
  </graphics>
</Settings>
```

**Important:** This is a partial template. When programmatically modifying, parse the existing XML and update only the targeted elements rather than replacing the entire file.

---

## 10. Programmatic Application Strategy

1. **settings.xml modifications:** Parse XML with a proper XML parser (PowerShell `[xml]` or Node.js `xml2js`). Back up the original first. Modify specific element values. Write back.

2. **commandline.txt:** Write/overwrite the file in the GTA V installation directory.

3. **Game installation path detection:**
   - Steam: Parse `C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf` for app ID `271590`
   - Epic: Registry `HKLM\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher` > `AppDataPath`, then check manifests
   - Rockstar: `HKLM\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V` > `InstallFolder`

4. **NVIDIA settings:** Use `nvidia-smi` or call NVIDIA Profile Inspector CLI

5. **Registry tweaks:** Direct registry writes via PowerShell `Set-ItemProperty`

---

## Confidence Summary

| Category | Overall Confidence | Justification |
|---|---|---|
| Config file location | **High** | Unchanged since 2015, universally documented |
| Graphics setting names in XML | **High** | Well-established, cross-referenced across PCGamingWiki, NVIDIA guides, community |
| Recommended FPS values | **High** | Consistent across NVIDIA benchmarks, Digital Foundry, Hardware Unboxed |
| Advanced graphics settings | **High** | Documented in NVIDIA's official guide |
| Population/density XML names | **Medium** | May have slight naming variations; verify against actual file |
| Launch options | **Medium-High** | Community-documented, some flags are version-sensitive |
| Registry tweaks | **Medium** | Windows-generic, not GTA-specific; impact varies by hardware |
| DLSS/FSR for base GTA V | **Low** | Not natively supported in original GTA V; Enhanced Edition is a separate product |
| Installation path detection | **High** | Registry and file paths are stable for Steam/Epic/Rockstar |

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

| Platform | Registry Key / Method | Value |
|---|---|---|
| **Steam** | Parse `libraryfolders.vdf` for app ID `271590` | Steam install: `HKLM\SOFTWARE\WOW6432Node\Valve\Steam` > `InstallPath` or `HKCU\Software\Valve\Steam` > `SteamPath` |
| **Epic** | `HKLM\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher` > `AppDataPath` | Then parse `.item` manifest files in `Manifests/` for `InstallLocation` |
| **Rockstar** | `HKLM\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto V` > `InstallFolder` | Direct path to game directory |
| **Uninstall** | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{GTA V GUID}` | `InstallLocation` value |

**Default Install Paths:**
```
Steam:     C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V\
Epic:      C:\Program Files\Epic Games\GTAV\
Rockstar:  C:\Program Files\Rockstar Games\Grand Theft Auto V\
```

**Steam libraryfolders.vdf parsing:**
```powershell
# Find Steam install path
$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (!$steamPath) { $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath }

# Parse libraryfolders.vdf for app 271590
$vdfPath = "$steamPath\steamapps\libraryfolders.vdf"
# Each library folder entry contains "apps" with app IDs — find the folder containing "271590"
```

### Config File Paths (User-Specific, NOT in Game Directory)

| File | Full Path | Read-Only Needed? |
|---|---|---|
| `settings.xml` | `%USERPROFILE%\Documents\Rockstar Games\GTA V\settings.xml` | **No** — GTA V respects manual edits made while game is closed |
| `commandline.txt` | `<GAME_INSTALL_DIR>\commandline.txt` (beside GTA5.exe) | **No** — read on launch only |

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `GTA5.exe` | `<GAME_INSTALL_DIR>\GTA5.exe` | **YES** — primary game process, target this for NVIDIA/AMD profiles |
| `GTAVLauncher.exe` | `<GAME_INSTALL_DIR>\GTAVLauncher.exe` | No — launcher only |
| `PlayGTAV.exe` | `<GAME_INSTALL_DIR>\PlayGTAV.exe` | No — Rockstar social club bridge |

### Read-Only Config Behavior

**settings.xml does NOT need to be set read-only.** GTA V reads settings.xml on launch and writes changes back on exit. If you edit while the game is closed, your changes persist. The game will not overwrite values you changed unless the user modifies those same settings in-game.

### Anti-Cheat Considerations

GTA V (Story Mode) has no anti-cheat. GTA Online uses Rockstar's proprietary anti-cheat but it does **not** monitor config file changes or registry tweaks. All optimizations listed here are safe for both modes.
