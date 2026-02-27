# Apex Legends PC Optimization Settings (2025/2026)
## Competitive / Ranked Play -- Maximum FPS + Visibility

## 1. Config File Locations

### videoconfig.txt (PRIMARY config file)
```
%USERPROFILE%\Saved Games\Respawn\Apex\local\videoconfig.txt
```

### autoexec.cfg (user-created)
```
<GAME_INSTALL_DIR>\cfg\autoexec.cfg
```
- Steam: `C:\Program Files (x86)\Steam\steamapps\common\Apex Legends\cfg\autoexec.cfg`
- EA App: `C:\Program Files\EA Games\Apex Legends\cfg\autoexec.cfg`

**Confidence: HIGH** -- Paths stable since launch.

---

## 2. videoconfig.txt -- Full Competitive Config

**Set file to read-only after editing** or the game will overwrite your changes.

```
"VideoConfig"
{
    "setting.cl_gib_allow"                    "0"
    "setting.cl_particle_fallback_base"       "0"
    "setting.cl_particle_fallback_multiplier" "0"
    "setting.cl_ragdoll_maxcount"             "0"
    "setting.cl_ragdoll_self_collision"       "0"
    "setting.csm_coverage"                    "1"
    "setting.csm_cascade_res"                 "512"
    "setting.fadeDistScale"                   "1.0"
    "setting.gpu_mem_level"                   "0"
    "setting.mat_depthfeather_enable"         "0"
    "setting.mat_forceaniso"                  "2"
    "setting.mat_letterbox_aspect_goal"       "0"
    "setting.mat_letterbox_aspect_threshold"  "0"
    "setting.mat_mip_linear"                  "0"
    "setting.mat_monitorgamma"               "1.6"
    "setting.mat_monitorgamma_tv_enabled"    "0"
    "setting.mat_queue_mode"                 "2"
    "setting.mat_texture_list_txinfo"        "0"
    "setting.mat_vsync"                      "0"
    "setting.mat_vsync_mode"                 "0"
    "setting.model_lod_meshes_enable"        "0"
    "setting.modeldecals_forceAllowed"       "0"
    "setting.r_createmodeldecals"            "0"
    "setting.r_decals"                       "0"
    "setting.r_drawscreenspaceparticles"     "0"
    "setting.r_dynamic"                      "1"
    "setting.r_jiggle_bones"                 "0"
    "setting.r_lod_switch_scale"             "0.6"
    "setting.shadow_enable"                  "0"
    "setting.shadow_depth_dimen_min"         "0"
    "setting.shadow_depth_upres_factor_max"  "0"
    "setting.shadow_maxdynamic"              "0"
    "setting.ssao_enabled"                   "0"
    "setting.ssao_downsample"               "3"
    "setting.stream_memory"                  "300000"
    "setting.defaultres"                     "1920"
    "setting.defaultresheight"               "1080"
    "setting.fullscreen"                     "1"
    "setting.nowindowborder"                "1"
    "setting.volumetric_lighting"           "0"
    "setting.mat_dynamic_tonemapping"       "0"
    "setting.r_particle_low_res_enable"     "0"
    "setting.cl_spot_shadow_detail"         "0"
    "setting.dvs_enable"                    "0"
    "setting.dvs_gpuframetime_min"          "14000"
    "setting.dvs_gpuframetime_max"          "16500"
    "setting.fps_max"                       "0"
}
```

### Key Settings Explained

| Key | In-Game Name | Value | Rationale |
|---|---|---|---|
| `cl_gib_allow` | Gore/gibs | `0` | Removes death clutter |
| `cl_particle_fallback_base` | Effects Detail | `0` | Fewer particles, cleaner view |
| `cl_ragdoll_maxcount` | Ragdolls | `0` | No ragdolls, less clutter + FPS |
| `csm_coverage` | Sun Shadow Coverage | `1` (Low) | Minimum shadows |
| `gpu_mem_level` | Texture Streaming Budget | `0` (None/2GB) | Minimal VRAM usage |
| `mat_forceaniso` | Texture Filtering | `2` (2x) | Sweet spot for seeing enemies at range |
| `mat_monitorgamma` | Brightness | `1.6` | Brighter; reveals enemies in dark areas |
| `mat_queue_mode` | Multithreaded rendering | `2` | Always enable |
| `mat_vsync` | V-Sync | `0` | Always off for competitive |
| `r_lod_switch_scale` | Model Detail | `0.6` | Earlier LOD switch, FPS gain |
| `shadow_enable` | Master shadows | `0` | Major FPS saver |
| `ssao_enabled` | Ambient Occlusion | `0` | Major FPS saver |
| `volumetric_lighting` | Volumetric Lighting | `0` | Removes fog/light shafts |
| `mat_dynamic_tonemapping` | Auto-brightness | `0` | Prevents brightness shifts |
| `dvs_enable` | Adaptive Resolution | `0` | Never use -- blurs unpredictably |
| `fps_max` | Frame cap | `0` | Unlimited |

**CRITICAL**: Set read-only after editing:
```powershell
Set-ItemProperty -Path "$env:USERPROFILE\Saved Games\Respawn\Apex\local\videoconfig.txt" -Name IsReadOnly -Value $true
```

**Confidence: HIGH**

---

## 3. TSAA vs Off

**Recommendation: Keep TSAA ON**

- Apex only offers TSAA or nothing (no MSAA, FXAA-only, DLSS, or FSR)
- TSAA costs 1-3% FPS and significantly smooths character outlines
- Nearly all ALGS pros keep TSAA enabled
- Controlled in-game only; no reliable videoconfig.txt toggle

**Confidence: HIGH**

---

## 4. autoexec.cfg Commands

```cfg
fps_max 0
cl_forcepreload 1
cl_interp_ratio 1
cl_interp 0.0
mat_screen_blur_enabled 0
mat_bloomscale 0
mat_bloom_scalefactor_scalar 0
mat_queue_mode 2
miles_occlusion 0
```

**Confidence: MEDIUM** -- Respawn patches these regularly without notice.

---

## 5. Launch Options

```
+fps_max 0 -novid -preload -high
```

| Option | Effect | Confidence |
|---|---|---|
| `+fps_max 0` | Uncap framerate | HIGH |
| `-novid` | Skip intro videos | HIGH |
| `-preload` | Preload assets | HIGH |
| `-high` | Set process priority to High | MEDIUM |

---

## 6. NVIDIA Reflex

**Recommendation: Enabled + Boost** (in-game only, cannot be set via config)

- Reduces system latency by 20-40ms
- "Boost" keeps GPU clocks elevated

**Confidence: HIGH**

---

## 7. NVIDIA Control Panel (per-application for r5apex.exe)

| Setting | Value |
|---|---|
| Low Latency Mode | Ultra |
| Power Management Mode | Prefer Maximum Performance |
| Texture Filtering - Quality | High Performance |
| Vertical Sync | Off |
| Threaded Optimization | Auto or On |
| Triple Buffering | Off |
| Preferred Refresh Rate | Highest Available |
| Monitor Technology | G-SYNC (if available) |

**Confidence: HIGH**

---

## 8. AMD Radeon Software

| Setting | Value |
|---|---|
| Radeon Anti-Lag | Enabled |
| Radeon Boost | Off |
| Radeon Chill | Off |
| Wait for Vertical Refresh | Always Off |
| Texture Filtering Quality | Performance |

**Confidence: MEDIUM**

---

## 9. Windows Registry Tweaks

### Disable Fullscreen Optimizations
```
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
  "C:\<PATH_TO>\r5apex.exe" = "~ DISABLEDXMAXIMIZEDWINDOWEDMODE"
```

### Game Mode
```
HKCU\Software\Microsoft\GameBar
  AllowAutoGameMode = 1 (DWORD)
  AutoGameModeEnabled = 1 (DWORD)
```

### HAGS
```
HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers
  HwSchMode = 2 (DWORD)
```

### Nagle's Algorithm Disable
```
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{ADAPTER-GUID}
  TcpAckFrequency = 1 (DWORD)
  TCPNoDelay = 1 (DWORD)
```

### MMCSS Gaming Priority
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
  GPU Priority = 8 (DWORD)
  Priority = 6 (DWORD)
  Scheduling Category = "High" (REG_SZ)
  SFIO Priority = "High" (REG_SZ)
```

**Confidence: MEDIUM**

---

## 10. Visibility-Specific Settings

| Setting | Value | Impact |
|---|---|---|
| `mat_monitorgamma` | `1.6` | Brightens dark areas |
| Ambient Occlusion | Disabled | Removes dark corner shading |
| Volumetric Lighting | Disabled | Removes fog/light shafts |
| `mat_dynamic_tonemapping` | `0` | No sudden brightness shifts |
| Effects Detail | Low | Thinner ability/grenade particles |
| TSAA | On | Smoother character silhouettes |
| Digital Vibrance (NVIDIA) | 70-80% | Makes enemies pop |
| Colorblind Mode | Tritanopia | Many pros use this for visibility |

---

## 11. Programmatic Implementation

### File Modifications
1. **videoconfig.txt** at `%USERPROFILE%\Saved Games\Respawn\Apex\local\videoconfig.txt` -- write config, set read-only
2. **autoexec.cfg** at `<GAME_DIR>\cfg\autoexec.cfg` -- create if not exists

### Game Install Path Detection
- **Steam**: `HKLM:\SOFTWARE\WOW6432Node\Valve\Steam` > `InstallPath`, parse `libraryfolders.vdf` for appid `1172470`
- **EA App**: Check `HKLM:\SOFTWARE\Respawn\Apex` or `C:\Program Files\EA Games\Apex Legends`

### Cannot Automate (display in UI)
- Launch options (fragile config formats)
- NVIDIA Reflex (in-game only)
- Colorblind mode (in-game only)
- Digital Vibrance (driver-level per-monitor)

---

## Confidence Summary

| Section | Rating |
|---|---|
| Config file paths | HIGH |
| videoconfig.txt values | HIGH |
| TSAA recommendation | HIGH |
| Launch options (core) | HIGH |
| autoexec.cfg | MEDIUM |
| NVIDIA Reflex | HIGH |
| NVIDIA/AMD driver settings | HIGH / MEDIUM |
| Registry tweaks | MEDIUM |
| Visibility settings | HIGH |

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

| Platform | Registry Key / Method |
|---|---|
| **Steam** | Parse `libraryfolders.vdf` for app ID `1172470` |
| **EA App** | `HKLM\SOFTWARE\Respawn\Apex` > `Install Dir` |
| **EA App (alt)** | `HKLM\SOFTWARE\WOW6432Node\Electronic Arts\EA Desktop\InstallLocation` — then check game manifests |
| **Origin (legacy)** | `HKLM\SOFTWARE\WOW6432Node\Origin\` or Origin manifest XML files |
| **Uninstall** | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{Apex GUID}` > `InstallLocation` |

**Default Install Paths:**
```
Steam:  C:\Program Files (x86)\Steam\steamapps\common\Apex Legends\
EA App: C:\Program Files\EA Games\Apex Legends\
Origin: C:\Program Files (x86)\Origin Games\Apex\
```

**Detection logic:**
```powershell
# 1. Check EA App registry
$apexPath = (Get-ItemProperty "HKLM:\SOFTWARE\Respawn\Apex" -ErrorAction SilentlyContinue)."Install Dir"

# 2. Check Steam
if (!$apexPath) {
    $steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    $defaultSteam = "$steamPath\steamapps\common\Apex Legends"
    if (Test-Path $defaultSteam) { $apexPath = $defaultSteam }
    # Else: parse libraryfolders.vdf for app 1172470
}

# 3. Check default EA App path
if (!$apexPath -and (Test-Path "C:\Program Files\EA Games\Apex Legends")) {
    $apexPath = "C:\Program Files\EA Games\Apex Legends"
}
```

### Config File Paths

| File | Full Path | Read-Only Needed? |
|---|---|---|
| `videoconfig.txt` | `%USERPROFILE%\Saved Games\Respawn\Apex\local\videoconfig.txt` | **YES — CRITICAL** — Apex overwrites this on every game exit |
| `autoexec.cfg` | `<GAME_INSTALL_DIR>\cfg\autoexec.cfg` | **No** — user-created, never overwritten |
| `settings.cfg` | `%USERPROFILE%\Saved Games\Respawn\Apex\local\settings.cfg` | No |
| `profile.cfg` | `%USERPROFILE%\Saved Games\Respawn\Apex\profile\profile.cfg` | No |

**Note:** Config files are stored in `Saved Games`, NOT in the game install directory. This path is the same regardless of Steam/EA App install location.

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `r5apex.exe` | `<GAME_INSTALL_DIR>\r5apex.exe` | **YES** — primary game process |
| `EADesktop.exe` | N/A | No — EA client |
| `Origin.exe` | N/A | No — legacy launcher |

### Read-Only Config Behavior

**videoconfig.txt MUST be set read-only.** Apex Legends overwrites videoconfig.txt every time the game exits, reverting any manual changes. This is the #1 thing to do when applying Apex optimizations.

```powershell
$vcPath = "$env:USERPROFILE\Saved Games\Respawn\Apex\local\videoconfig.txt"
# Write optimized config first, THEN set read-only
Set-ItemProperty -Path $vcPath -Name IsReadOnly -Value $true
```

**To allow in-game changes later, remove read-only:**
```powershell
Set-ItemProperty -Path $vcPath -Name IsReadOnly -Value $false
```

### Anti-Cheat Considerations (EAC)

**Easy Anti-Cheat (EAC)** is Apex's anti-cheat. Key considerations:
- **Config file edits are safe** — EAC does not monitor videoconfig.txt or autoexec.cfg
- **Registry tweaks are safe** — OS-level gaming optimizations are not flagged
- **GPU driver changes are safe** — NVIDIA/AMD control panel changes are fine
- **autoexec.cfg commands are safe** — only whitelisted commands execute; blocked ones silently fail
- **DO NOT** use DLL injection, memory tools, or unauthorized overlays
