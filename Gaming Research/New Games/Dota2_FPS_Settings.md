# Dota 2 FPS Optimization Settings for Competitive Play (2025/2026)

## 1. Config File Locations

| File | Path | Purpose |
|------|------|---------|
| `video.txt` | `<Steam>/steamapps/common/dota 2 beta/game/dota/cfg/video.txt` | All video/graphics settings |
| `autoexec.cfg` | `<Steam>/steamapps/common/dota 2 beta/game/dota/cfg/autoexec.cfg` | User-created; auto-executed on launch |
| Steam userdata | `<Steam>/userdata/<SteamID>/570/remote/cfg/` | Cloud-synced config (can override local) |

**Confidence: HIGH** -- These paths have been stable across all Source 2 Dota 2 versions.

---

## 2. In-Game Video Settings (via `video.txt`)

### Recommended Competitive video.txt

```
"VideoConfig"
{
    "setting.cl_particle_fallback_base"     "0"
    "setting.cl_particle_fallback_multiplier" "0"
    "setting.defaultres"                    "1920"
    "setting.defaultresheight"              "1080"
    "setting.fullscreen"                    "1"
    "setting.nowindowborder"                "0"
    "setting.aspectratiomode"               "-1"
    "setting.r_deferred_height_fog"         "0"
    "setting.r_deferred_simple_light"       "1"
    "setting.r_screenspace_aa"              "0"
    "setting.mat_queue_mode"                "2"
    "setting.gpu_mem_level"                 "0"
    "setting.cpu_level"                     "0"
    "setting.gpu_level"                     "0"
    "setting.mat_vsync"                     "0"
    "setting.r_texturefilteringquality"     "0"
    "setting.r_shadow_half_update_rate"     "1"
    "setting.r_renderingpipeline"           "0"
    "setting.mat_dynamic_tonemapping"       "0"
    "setting.r_dota_allow_fow_fog"          "1"
    "setting.r_bloom_new"                   "0"
    "setting.r_high_quality_hero_water_lighting" "0"
    "setting.r_screenspace_ground_ao"       "0"
    "setting.r_dota_normal_mapped_ground"   "0"
    "setting.r_world_normal_maps"           "0"
    "setting.r_ambient_occlusion"           "0"
    "setting.r_dota_cheap_water"            "1"
    "setting.r_dota_hdr"                    "0"
    "setting.r_dota_specular"               "0"
    "setting.dota_global_light_world_shadow" "0"
    "setting.r_dota_tree_wind"              "0"
    "setting.r_dota_atmospheric_fog"        "0"
    "setting.r_additive_animation"          "0"
    "setting.r_deferred_additive_pass"      "0"
    "setting.r_deferred_specular"           "0"
    "setting.r_deferred_specular_bloom"     "0"
    "setting.r_grass"                       "0"
    "setting.r_compressedtextures"          "1"
    "setting.mat_software_aa_strength"      "0"
}
```

### Setting-by-Setting Breakdown

| In-Game Name | Config Key | FPS Value | Notes |
|---|---|---|---|
| **Rendering API** | `setting.r_renderingpipeline` | `0` (DX11) or test Vulkan via launch opt | See Vulkan section |
| **Display Mode** | `setting.fullscreen` | `1` (Exclusive Fullscreen) | ~3-5% better than borderless |
| **V-Sync** | `setting.mat_vsync` | `0` (Off) | Always off for competitive |
| **Anti-Aliasing** | `setting.r_screenspace_aa` | `0` (Off) | Moderate FPS cost |
| **Texture Quality** | `setting.gpu_mem_level` | `0` (Low) or `1` (Medium) | Low saves VRAM |
| **Effects Quality** | `setting.cpu_level` | `0` (Low) | Significant FPS gain in teamfights |
| **Shadow Quality** | `setting.dota_global_light_world_shadow` | `0` (Off) | Shadows are purely cosmetic |
| **Ambient Occlusion** | `setting.r_ambient_occlusion` | `0` (Off) | Significant FPS cost |
| **Bloom** | `setting.r_bloom_new` | `0` (Off) | Can obscure ability effects |
| **Grass** | `setting.r_grass` | `0` (Off) | Reduces clutter and saves FPS |
| **Water Quality** | `setting.r_dota_cheap_water` | `1` (Cheap/Low) | No gameplay impact |
| **Threaded Rendering** | `setting.mat_queue_mode` | `2` (Threaded) | Always enable |
| **Fog of War Fog** | `setting.r_dota_allow_fow_fog` | `1` (On) | KEEP ON -- competitive fog of war visual |
| **Compressed Textures** | `setting.r_compressedtextures` | `1` (On) | Reduces VRAM usage |

**Confidence: HIGH**

---

## 3. Autoexec.cfg Optimizations

```
// === FPS & PERFORMANCE ===
fps_max 0
engine_no_focus_sleep 0
r_dynamic_lod 1
r_lod_switch_scale 0.5
dota_cheap_water 1
dota_embers 0
cl_globallight_shadow_mode 0
mat_vsync 0
mat_queue_mode 2

// === NETWORK (Competitive) ===
rate 786432
cl_cmdrate 60
cl_updaterate 60
cl_interp 0
cl_interp_ratio 1
cl_lagcompensation 1
cl_smooth 1
cl_smoothtime 0.01

// === VISUAL CLUTTER REDUCTION ===
dota_hud_healthbar_number 1
dota_sf_game_end_delay 0
dota_disable_range_finder 0
```

**Confidence: HIGH** for network settings. **MEDIUM** for some render convars (Valve may lock them).

---

## 4. Steam Launch Options

```
-novid -high -dx11 +fps_max 0 -prewarm -map dota
```

| Option | Effect | Confidence |
|---|---|---|
| `-novid` | Skips intro video | HIGH |
| `-high` | Sets process priority to High | HIGH |
| `-dx11` | Forces DirectX 11 renderer | HIGH |
| `-vulkan` | Forces Vulkan renderer (test this) | HIGH |
| `+fps_max 0` | Uncaps FPS at launch | HIGH |
| `-prewarm` | Pre-loads shaders/assets | HIGH |
| `-map dota` | Pre-loads the Dota map on launch | MEDIUM |
| `-softparticlesdefaultoff` | Disables soft particles | MEDIUM |

---

## 5. Vulkan vs DirectX 11 Performance

| Aspect | DirectX 11 | Vulkan |
|---|---|---|
| **Average FPS** | Baseline | +5-15% on NVIDIA 10xx+ and AMD RX 400+ |
| **1% Low FPS** | Baseline | Generally better (fewer frame drops) |
| **Stability** | Very stable | Stable since ~2022 |
| **CPU Overhead** | Higher | Lower (better for CPU-bottlenecked systems) |

**Recommendation:** Test Vulkan first (`-vulkan`). If stable, keep it.

---

## 6. Windows Registry Tweaks

### Disable Nagle's Algorithm
```
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{adapter-GUID}
  TcpAckFrequency = 1 (REG_DWORD)
  TCPNoDelay = 1 (REG_DWORD)
```

### GPU Scheduling
```
HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers
  HwSchMode = 2 (REG_DWORD)
```

### Multimedia Throttling
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
  SystemResponsiveness = 0 (REG_DWORD)
  NetworkThrottlingIndex = 0xFFFFFFFF (REG_DWORD)
```

### MMCSS Games Priority
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
  GPU Priority = 8 (REG_DWORD)
  Priority = 6 (REG_DWORD)
  Scheduling Category = "High" (REG_SZ)
```

**Confidence: HIGH** for paths. **MEDIUM** for FPS impact (typically 1-3% in Dota 2).

---

## 7. NVIDIA Driver Settings

| Setting | Value |
|---|---|
| Power Management Mode | Prefer Maximum Performance |
| Texture Filtering - Quality | High Performance |
| Threaded Optimization | On |
| Vertical Sync | Off |
| Low Latency Mode | On or Ultra |
| Shader Cache Size | Unlimited |

---

## 8. AMD Driver Settings

| Setting | Value |
|---|---|
| Radeon Anti-Lag | Enabled |
| Radeon Chill | Disabled |
| Radeon Boost | Disabled |
| Wait for Vertical Refresh | Off |
| Texture Filtering Quality | Performance |

---

## 9. Competitive Clarity Settings

| Setting | Value | Why |
|---|---|---|
| Grass | Off | Removes ground clutter |
| Tree Wind | Off | Static trees are easier to read |
| Atmospheric Fog | Off | Cleaner visual field |
| Bloom | Off | Prevents bright ability effects from washing out |
| Particle Fallback | 0 | Simpler particles = easier to read teamfights |

---

## 10. Programmatic Application

| Category | Method |
|---|---|
| Video Settings | Write `video.txt` (KeyValues format) |
| Autoexec | Write `autoexec.cfg` (plaintext) |
| Launch Options | Parse Steam `localconfig.vdf` for app 570 |
| Registry Tweaks | PowerShell `Set-ItemProperty` |
| NVIDIA Settings | `nvidia-smi` or NVIDIA Profile Inspector CLI |

**Confidence: HIGH** overall.

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

Dota 2 is **Steam-only** (app ID `570`).

| Method | Path / Key |
|---|---|
| **Steam Registry** | `HKLM\SOFTWARE\WOW6432Node\Valve\Steam` > `InstallPath` |
| **Steam Registry (HKCU)** | `HKCU\Software\Valve\Steam` > `SteamPath` |
| **libraryfolders.vdf** | `<SteamPath>\steamapps\libraryfolders.vdf` — parse for app `570` |
| **Direct appmanifest** | `<LibraryPath>\steamapps\appmanifest_570.acf` — contains `installdir` |

**Default Install Path:**
```
C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\
```

**Detection logic:**
```powershell
# Find Steam
$steamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (!$steamPath) { $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath }

# Check default location first
$defaultPath = "$steamPath\steamapps\common\dota 2 beta"
if (Test-Path $defaultPath) { $dotaPath = $defaultPath }
# Else: parse libraryfolders.vdf for other library locations containing app 570
```

### Config File Paths

| File | Full Path | Read-Only Needed? |
|---|---|---|
| `video.txt` | `<DOTA_DIR>\game\dota\cfg\video.txt` | **No** — Dota 2 respects manual edits, but Steam Cloud may override (see below) |
| `autoexec.cfg` | `<DOTA_DIR>\game\dota\cfg\autoexec.cfg` | **No** — user-created, never overwritten |
| Steam Cloud cfg | `<SteamPath>\userdata\<SteamID>\570\remote\cfg\` | N/A — this is the cloud copy |

**Steam Cloud Sync Warning:** Steam Cloud can override local `video.txt` changes. To prevent this:
1. Disable Steam Cloud for Dota 2: Steam > Dota 2 > Properties > General > uncheck "Keep game saves in the Steam Cloud"
2. Or: modify the cloud copy in `userdata/<SteamID>/570/remote/cfg/` as well

### Steam Launch Options Path

Launch options are stored in:
```
<SteamPath>\userdata\<SteamID>\config\localconfig.vdf
```
Under key: `UserLocalConfigStore/Software/Valve/Steam/apps/570/LaunchOptions`

**Note:** Modifying `localconfig.vdf` while Steam is running will be overwritten. Close Steam first.

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `dota2.exe` | `<DOTA_DIR>\game\bin\win64\dota2.exe` | **YES** — primary game process |
| `steamwebhelper.exe` | N/A | No — Steam overlay process |

### Read-Only Config Behavior

**video.txt does NOT need read-only** — Dota 2 reads it on launch and respects values. However, changing settings in-game will overwrite video.txt on exit. The bigger concern is **Steam Cloud Sync** overriding local changes on launch.

### Anti-Cheat Considerations

**Valve Anti-Cheat (VAC)** — Dota 2 uses VAC but it does **not** monitor:
- Config file changes (video.txt, autoexec.cfg)
- Registry tweaks
- GPU driver settings
- Steam launch options
- Console commands (even those in autoexec.cfg)

All optimizations listed here are **completely safe** for VAC.
