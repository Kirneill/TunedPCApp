# EA Sports FC 26 -- FPS Optimization Settings

> **Research date:** March 2026
> **Game version:** EA SPORTS FC 26 (Frostbite engine, DirectX 12 mandatory)
> **Confidence:** HIGH for in-game setting names (verified against official EA Pitch Notes PC Deep Dive)
> **Confidence:** MEDIUM for fcsetup.ini key names (community-verified; no official key-list document)

---

## Important Caveats

- EA SPORTS FC 26 uses the Frostbite engine with mandatory DirectX 12 (no DX11 fallback).
- **EA Javelin Anticheat** -- kernel-level, runs only while the game is active. Config file edits
  to fcsetup.ini are SAFE (confirmed by community: read-only trick is widely used and not flagged).
- There is NO DLSS, NO FSR, NO XeSS, and NO ray tracing in FC 26 (unlike most 2025+ titles).
  EA confirmed this in the official PC Deep Dive Pitch Notes.
- The game ships with four preset tiers: Auto, Low, Medium, High, Ultra.
- KNOWN BUG (present at launch, partially patched): The in-game "RenderingQuality" preset
  flag can override custom per-setting values at halftime or on match load. Workaround: set
  fcsetup.ini to read-only after configuring settings, OR set Graphics Preset to "Custom".
- The game's built-in FPS limiter and VSync implementation are considered unreliable by the
  community. Preferred approach: disable in-game VSync, manage cap via NVCP/AMD Software.
- Active Monitor Selection is new in FC 26 (multi-monitor setups).
- Aspect Ratio Filter is new in FC 26.
- Render Scale is new in FC 26 (previously not available in FC 24/25).

---

## 1. Config File Specification

**Confidence: HIGH** (path confirmed by multiple independent community sources and EA forum posts)

| Property | Value |
|----------|-------|
| **Primary config path** | `%LOCALAPPDATA%\EA SPORTS FC 26\fcsetup.ini` |
| **Secondary config folder** | `%LOCALAPPDATA%\EA SPORTS FC 26\settings\` (profile/save data) |
| **File format** | Plain-text INI (key = value pairs, no section headers) |
| **File encoding** | UTF-8 (no BOM) |
| **File extension** | `.ini` |

**Note on path capitalization:** The folder is named `EA SPORTS FC 26` (with spaces, all caps for
"EA SPORTS FC"). The previous title was `EA SPORTS FC 25`. Verify exact folder name on first run.

**Note on secondary path:** Some sources also list `%USERPROFILE%\Documents\EA SPORTS FC 26\` as
a possible config location. The `%LOCALAPPDATA%` path is the confirmed primary settings file for
display/graphics. Documents may contain save data and additional profile files.

### Structural Requirements

The fcsetup.ini file uses a flat key=value format with no INI sections (no `[Section]` headers).
The game reads all keys at launch and applies them. If the file is missing or corrupt, the game
regenerates it from defaults.

Required structural fields (all optional -- game regenerates if absent):
- None strictly required; the game creates defaults for any missing key.
- Deleting the file entirely causes the game to recreate it on next launch.

This means the script can safely write ONLY the performance keys it changes, provided the file
already exists (i.e., game was launched at least once). The safest approach is read-merge-write.

### File Ownership

- The game WRITES to fcsetup.ini on exit (it saves any in-game settings changes back to disk).
- **Setting the file to read-only prevents the game from overwriting it** -- this is the standard
  community workaround and is not flagged by EA Javelin. Set read-only AFTER writing settings.
- There is one fcsetup.ini per Windows user (not per EA account or game profile).
- The known "preset override" bug means the game may apply a preset internally at match start
  even when fcsetup.ini is read-only. The read-only fix prevents settings from REVERTING after
  the bug; it does not eliminate the mid-match override.

---

## 2. Reference Config File

**Source:** Reconstructed from community sources (EA Forums, Hone Blog, PCGamesN, AllThings.How).
Key names verified against: EA Pitch Notes PC Deep Dive (official), and multiple FC 25/26 community
threads. No complete raw file dump was publicly available -- this is the best-effort reference.

**IMPORTANT WARNING FOR CODING AGENT:** The key names below are MEDIUM confidence for the INI file.
The IN-GAME setting names (from official EA documentation) are HIGH confidence. The fcsetup.ini
key names follow an UPPER_SNAKE_CASE convention confirmed by community sources. Verify against an
actual installation before shipping. The in-game guide section of the script is HIGH confidence.

```ini
WAITFORVSYNC = 0
MAX_FRAME_RATE = 0
REFRESH_RATE = 144
RENDERING_QUALITY = 2
GRASS_QUALITY = 1
CROWD_QUALITY = 1
CLOTH_QUALITY = 1
AMBIENT_OCCLUSION_QUALITY = 0
MOTION_BLUR = 0
STRAND_BASED_HAIR = 0
DYNAMIC_RESOLUTION = 0
DYNAMIC_RESOLUTION_FPS_TARGET = 60
RENDER_SCALE = 100
DISPLAY_MODE = 1
```

**Key name confidence notes:**
- `WAITFORVSYNC`, `MAX_FRAME_RATE`, `REFRESH_RATE` -- HIGH confidence (cited verbatim in multiple
  community sources including Hone Blog and AllThings.How).
- `RENDERING_QUALITY`, `GRASS_QUALITY`, `CROWD_QUALITY`, `CLOTH_QUALITY`, `AMBIENT_OCCLUSION_QUALITY`,
  `MOTION_BLUR`, `STRAND_BASED_HAIR`, `DYNAMIC_RESOLUTION`, `RENDER_SCALE` -- MEDIUM confidence
  (follow observed UPPER_SNAKE_CASE pattern; official in-game names confirmed from EA Pitch Notes).
- `DISPLAY_MODE` -- MEDIUM confidence (present in similar Frostbite titles).

---

## 3. Config Key Reference

### Performance Keys (safe to override)

| Config Key (exact) | Type | Valid Values | Competitive Value | FPS Impact | Notes |
|---------------------|------|-------------|-------------------|------------|-------|
| `WAITFORVSYNC` | int | `0` = Off, `1` = On | `0` | HIGH (latency) | Must be 0 for competitive; adds input lag when On |
| `MAX_FRAME_RATE` | int | `0` = unlimited, `144`, `165`, `240` | `0` | MED | Let NVCP/AMD control the cap; in-game limiter unreliable |
| `REFRESH_RATE` | int | Your monitor Hz (e.g. `60`, `120`, `144`, `165`, `240`) | Match monitor | LOW | Game may cap frame rate to this if set wrong |
| `RENDERING_QUALITY` | int | `0`=Low, `1`=Medium, `2`=High, `3`=Ultra | `1` (Medium) | HIGH (GPU+CPU+VRAM) | Single highest-impact setting; affects textures, shadows, object complexity |
| `GRASS_QUALITY` | int | `0`=Low, `1`=Medium, `2`=High | `1` (Medium) | LOW-MED | Minimal competitive benefit from High; Low saves GPU budget |
| `CROWD_QUALITY` | int | `0`=Low, `1`=Medium, `2`=High | `1` (Medium) | MED (CPU+GPU) | High has moderate CPU cost from crowd simulation |
| `CLOTH_QUALITY` | int | `0`=Low, `1`=Medium, `2`=High | `0` (Low) | MED (CPU) | Jersey physics; Low is indistinguishable during gameplay |
| `AMBIENT_OCCLUSION_QUALITY` | int | `0`=Low, `1`=Medium, `2`=High, `3`=Ray Tracing | `0` (Low) | HIGH (GPU+CPU+VRAM) | Biggest single GPU load outside RenderingQuality; Low gives ~20% FPS gain vs High |
| `MOTION_BLUR` | int | `0`=Off, `1`=On | `0` | LOW | Always Off for competitive; reduces input clarity |
| `STRAND_BASED_HAIR` | int | `0`=Off, `1`=On | `0` | HIGH (GPU+VRAM) | Hair simulation; 4%+ FPS gain when Off; no competitive benefit |
| `DYNAMIC_RESOLUTION` | int | `0`=Off, `1`=On | `0` | N/A | Dynamic resolution scaling; Off at native; On only for sub-native budget setups |
| `DYNAMIC_RESOLUTION_FPS_TARGET` | int | FPS value (e.g. `60`, `90`, `120`) | `0` or `60` | N/A | Only relevant when DYNAMIC_RESOLUTION=1 |
| `RENDER_SCALE` | int | `65`-`100` (percentage) | `100` | HIGH | 100 = native; lower values render at sub-native resolution. Only reduce below 100 on severely GPU-bound systems |

### Structural/Display Keys (preserve or set carefully)

| Config Key (exact) | Type | Purpose / Notes |
|---------------------|------|----------------|
| `DISPLAY_MODE` | int | `0`=Windowed, `1`=Fullscreen exclusive, `2`=Borderless. Prefer `1` for best performance. Some users report windowed borderless (2) improves refresh rate detection. |
| `REFRESH_RATE` | int | Must match monitor. Script should read monitor refresh rate from environment and write this value. |

### Keys NOT in Config (must set in-game only)

| In-Game Setting | Notes |
|-----------------|-------|
| Anti-Aliasing mode (TAA/FXAA) | No fcsetup.ini key found. Set in-game. FC 26 uses TAA by default. |
| Aspect Ratio Filter | New FC 26 feature; no confirmed config key. Set in-game. |
| Active Monitor selection | New FC 26 feature; no confirmed config key. Set in-game. |
| Cutscene Performance | Set in-game (Full Frame Rate is recommended for cutscene smoothness). |
| In-game VSync percentage modes (50%, 33%, 25%) | In-game only. WAITFORVSYNC=0 disables VSync entirely. |
| Graphics Preset selection | The RENDERING_QUALITY key maps to individual quality; the preset dropdown is an in-game UI concept. |

---

## 4. Key Name Verification

| Source | URL | Confidence | Notes |
|--------|-----|------------|-------|
| EA Official PC Deep Dive Pitch Notes | https://www.ea.com/en/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-pc-deep-dive | HIGH | Confirms all in-game setting NAMES (not INI keys) |
| Hone Blog NVIDIA Settings Guide | https://hone.gg/blog/nvidia-settings-ea-fc-26/ | HIGH (WAITFORVSYNC, MAX_FRAME_RATE, REFRESH_RATE) | Verbatim INI keys cited with values |
| AllThings.How FC 26 PC Guide | https://allthings.how/ea-fc-26-on-pc-dependable-settings-for-high-fps-and-low-latency/ | MED | Confirms fcsetup.ini path and key editing approach |
| EA Forums Graphics Settings Bug Thread | https://forums.ea.com/discussions/fc-26-technical-issues-en/graphics-settings-not-applying--game-forces-presets-even-after-full-reset/12680020 | MED | Confirms RenderingQuality is a config key; confirms read-only workaround |
| PCGamesN Best Settings Guide | https://www.pcgamesn.com/ea-sports-fc-26/best-settings | MED | In-game setting names confirmed; no INI keys |
| Steam Community FC 25 Config Thread | https://steamcommunity.com/app/2669320/discussions/0/4847651553826969642/ | LOW-MED | FC 25 path is AppData\Local\EA SPORTS FC 25 -- same pattern |
| Advanced Uninstaller Info | https://www.advanceduninstaller.com/EA-SPORTS-FC-26-0e79403295f6847d8ed43ed6f939f6f9-application.htm | HIGH (executable name and install path) | FC26.exe confirmed, install path confirmed |

---

## 5. Installation Detection

**Confidence: HIGH for executable and install paths; MEDIUM for registry key**

### Registry Keys

```powershell
# EA App (primary launcher) uninstall registry key
# HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{CC38BDAB-B776-4908-9A26-CC27C96404C2}

# EA App install location (check EA App registry for game library path)
# HKLM:\SOFTWARE\Electronic Arts\EA Desktop
# Look for InstallLocation or similar under EA Games subkeys

# Standard uninstall key search pattern:
# HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like "*FC 26*"
# HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like "*FC 26*"
```

### Common Install Paths

```
C:\Program Files\EA Games\EA SPORTS FC 26\
C:\Program Files (x86)\EA Sports\EA SPORTS FC 26\
D:\EA Games\EA SPORTS FC 26\
<CustomEALibrary>\EA SPORTS FC 26\
```

For EA App installs, the library root is configurable. The game folder name is `EA SPORTS FC 26`.

### Steam Detection

- Steam folder name: `FC 26`
- Steam App ID: `3405690`
- Steam common path: `<SteamLibrary>\steamapps\common\FC 26\`
- Steam registry: `HKCU:\Software\Valve\Steam\Apps\3405690`

### Other Launchers

- **EA App (primary)**: Detection via registry key above or by checking for `FC26.exe` in common EA paths.
- **EA App library path registry**: `HKLM:\SOFTWARE\Electronic Arts\EA Desktop` -- check `InstallLocation` value or scan default paths.
- No Epic Games Store or Xbox Game Pass versions confirmed as of March 2026. EA App and Steam are the two distribution methods.

---

## 6. EXE Flags

| Executable | Path relative to install | AppCompat Flags |
|------------|--------------------------|-----------------|
| `FC26.exe` | `FC26.exe` (root of install directory) | `HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS` |
| `FC26_Showcase.exe` | `FC26_Showcase.exe` | `HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS` |
| `EAAntiCheat.GameServiceLauncher.exe` | `EAAntiCheat.GameServiceLauncher.exe` | DO NOT MODIFY (anti-cheat launcher) |

**Note:** Do NOT set CPU priority or AppCompat flags on the anti-cheat launcher. Only set flags on
the main game executables.

---

## 7. GPU-Specific Settings

### NVIDIA (Verified via Hone Blog + community guides)

| NVCP Setting | Recommended Value | Notes |
|--------------|-------------------|-------|
| Low Latency Mode | Ultra | FC 26 does not have NVIDIA Reflex; Ultra is the next best latency reduction |
| Max Frame Rate | Monitor Hz - 3 (e.g. 141 for 144Hz, 237 for 240Hz) | Prevents VRR drop-out; more stable than in-game limiter |
| Background App Max Frame Rate | Off | Avoids hidden background throttling |
| Power Management Mode | Prefer Maximum Performance | Prevents GPU downclocking during match load |
| Texture Filtering -- Quality | High Performance | Minor visual cost, FPS gain |
| Texture Filtering -- Anisotropic Sample Optimization | On | Additional texture FPS gain |
| Texture Filtering -- Trilinear Optimization | On | Additional texture FPS gain |
| Threaded Optimization | On | Efficient CPU core scheduling with Frostbite |
| Vertical Sync (NVCP) | On (if using G-Sync) / Off (if no G-Sync) | With G-Sync: NVCP VSync On + In-game VSync Off prevents tearing. Without G-Sync: both Off. |
| G-Sync | Enable for windowed and full screen | Use if monitor supports it |
| Digital Vibrance | 65-70% | Optional; improves kit color contrast with no performance cost |

**No DLSS, No Reflex support confirmed in FC 26 (as of March 2026).**

### AMD

| Adrenalin Setting | Recommended Value | Notes |
|-------------------|-------------------|-------|
| Radeon Anti-Lag | Enabled | Latency reduction equivalent for AMD; use instead of NVCP Low Latency |
| Radeon Chill | Off | Frame pacing tool; interferes with sustained high FPS gaming |
| Enhanced Sync | Off | Can cause single-frame stutter; use standard VSync Off |
| Image Sharpening | On (default strength) | Optional clarity boost |
| FPS Cap | Monitor Hz - 3 | Same principle as NVCP Max Frame Rate |

**No FSR confirmed in FC 26 (as of March 2026).**

---

## 8. Anti-Cheat Safety

| Anti-Cheat | Config file edits | Registry edits | Process priority | EXE flags | Details |
|------------|-------------------|----------------|------------------|-----------|---------|
| EA Javelin Anticheat | SAFE | SAFE | SAFE | SAFE | Kernel-level, but monitors game binary integrity and online behavior -- NOT config files. The read-only fcsetup.ini trick is widely used without reports of bans. |

**EA Javelin key facts:**
- Runs at kernel level ONLY while FC 26 is active; unloads when game closes.
- Monitors: game binary integrity, memory, and suspicious online behavior.
- Does NOT monitor: user config files (fcsetup.ini), Windows registry, or process priority settings.
- Mods that modify game files (pak files, etc.) DO trigger Javelin in online modes. Config-only
  edits do not.
- Source: EA official anti-cheat help page (https://help.ea.com/en/articles/platforms/pc-ea-anticheat/)

---

## 9. In-Game Settings Guide (for script output)

These settings must be set manually in-game. Print these in the script's guide section.

### Display Configuration Tab

| Setting | Recommended Value | Why |
|---------|-------------------|-----|
| Display Mode | Fullscreen (Exclusive) | Lowest input latency; GPU has direct display control |
| Screen Resolution | Native monitor resolution | Never reduce native res; use Render Scale instead |
| Refresh Rate | Highest supported | Match monitor maximum |
| Frame Rate Limit | No Limit | Control via GPU driver instead; in-game limiter is unreliable |
| V-Sync | Off | Managed by GPU driver; in-game VSync adds input lag |
| Cutscene Performance | Full Frame Rate | Eliminates stutters during goal cutscenes |
| Render Scale | 100% | Native rendering; only reduce on severely GPU-limited systems |
| Dynamic Resolution Scaling | Off | Causes resolution fluctuations mid-match; Off for consistent performance |

### Graphics/Fidelity Tab

| Setting | Competitive Value | Notes |
|---------|-------------------|-------|
| Graphics Preset | Custom | Prevents game from overriding individual settings |
| Rendering Quality | Medium | Largest single performance gain; Mid/High are nearly identical in-match |
| Strand-Based Hair | Off | 4%+ FPS gain; invisible during actual gameplay |
| Grass Quality | Medium | Low looks obviously bad on pitch; Medium/High identical in-match |
| Crowd Quality | Medium | Low degrades atmosphere; High adds CPU load |
| Cloth Quality | Low | Jersey physics; Low is indistinguishable at 60+ FPS |
| Ambient Occlusion Quality | Low | Up to 20% FPS gain vs High; shadow contact softening irrelevant in-match |
| Motion Blur | Off | Always Off for competitive; reduces ball and player tracking clarity |

---

## 10. Performance Benchmarks (Community-sourced, March 2026)

Tested on RTX 4070 at 1080p (PCGamesN):
- Ultra preset: ~153 FPS avg (94 FPS 1% low)
- High preset: ~170 FPS avg
- Medium preset: ~185 FPS avg
- Low preset: ~195 FPS avg

Key individual setting impacts (community estimates):
- Rendering Quality Medium vs Ultra: ~15-20% FPS gain
- Ambient Occlusion Low vs High: ~12-20% FPS gain
- Strand-Based Hair Off vs On: ~4% FPS gain
- Cloth Quality Low vs High: ~5% FPS gain (mostly CPU)

---

## 11. Known Issues and Workarounds

### Preset Override Bug (Partially Patched)
**Symptom:** Custom graphics settings revert to a preset at halftime or after a goal cutscene.
**Root cause:** Internal RenderingQuality flag overrides per-setting values.
**Workaround:** Set fcsetup.ini to read-only after editing. Set Graphics Preset to "Custom" in-game.
**Status:** Community reports this is less frequent after patches but not fully resolved.

### Refresh Rate Detection Bug
**Symptom:** Game locks to 60 FPS or wrong refresh rate despite monitor being 144Hz+.
**Fix:** Set `REFRESH_RATE = <your monitor Hz>` in fcsetup.ini manually.
**Alternative:** Use Windowed Borderless mode -- some users report it fixes refresh rate detection.

### FPS Instability Above ~190 FPS
**Symptom:** Micro-stutters, erratic frame pacing at very high frame rates.
**Fix:** Cap FPS to 190 max (or monitor Hz - 3) via NVCP/AMD.
**Note:** This is a Frostbite engine behavior on this title -- not a driver issue.

### Settings Won't Save
**Fix sequence:** Exit game, delete fcsetup.ini from `%LOCALAPPDATA%\EA SPORTS FC 26\`,
repair game in EA App, relaunch, set settings, exit, set file to read-only.

---

## 12. Competitive (eSports/FUT Champions) Settings Summary

These are the settings used by competitive FUT players and those chasing lowest latency:

**In-game:**
- Display Mode: Fullscreen Exclusive
- Frame Rate Limit: No Limit (manage via NVCP)
- V-Sync: Off
- Cutscene Performance: Full Frame Rate
- Render Scale: 100
- Dynamic Resolution: Off
- Graphics Preset: Custom
- Rendering Quality: Medium
- Strand-Based Hair: Off
- Grass Quality: Medium
- Crowd Quality: Medium (or Low on budget hardware)
- Cloth Quality: Low
- Ambient Occlusion: Low
- Motion Blur: Off

**fcsetup.ini:**
```ini
WAITFORVSYNC = 0
MAX_FRAME_RATE = 0
REFRESH_RATE = <monitor Hz>
RENDERING_QUALITY = 1
GRASS_QUALITY = 1
CROWD_QUALITY = 1
CLOTH_QUALITY = 0
AMBIENT_OCCLUSION_QUALITY = 0
MOTION_BLUR = 0
STRAND_BASED_HAIR = 0
DYNAMIC_RESOLUTION = 0
RENDER_SCALE = 100
```

**Note:** There are NO competitive-advantage settings from pro players equivalent to CS2 stretched
resolution or Valorant sens tuning. EA FC 26 competitive settings are purely about latency and
frame rate consistency. Controller settings (Timed Finishing On/Off, Sprint type, etc.) are
purely preference and not covered in this document.

---

## Sources

- [EA Official PC Deep Dive Pitch Notes](https://www.ea.com/en/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-pc-deep-dive) -- Official setting names, system requirements, anti-cheat
- [PCGamingWiki EA Sports FC 26](https://www.pcgamingwiki.com/wiki/EA_Sports_FC_26) -- Config paths, system info
- [Hone Blog -- Best NVIDIA Settings for EA FC 26](https://hone.gg/blog/nvidia-settings-ea-fc-26/) -- fcsetup.ini keys (WAITFORVSYNC, MAX_FRAME_RATE, REFRESH_RATE), NVCP settings
- [PCGamesN -- Best EA Sports FC 26 settings](https://www.pcgamesn.com/ea-sports-fc-26/best-settings) -- In-game settings with benchmark data
- [AllThings.How -- EA FC 26 on PC](https://allthings.how/ea-fc-26-on-pc-dependable-settings-for-high-fps-and-low-latency/) -- fcsetup.ini confirmation, performance settings
- [Beebom -- Best EA FC 26 PC Settings](https://beebom.com/best-ea-fc-26-pc-settings/) -- Graphics setting names and values
- [EA Forums -- Graphics Settings Not Applying](https://forums.ea.com/discussions/fc-26-technical-issues-en/graphics-settings-not-applying--game-forces-presets-even-after-full-reset/12680020) -- Preset override bug, fcsetup.ini path
- [EA Forums -- EA FC 26 PC Fix Community Guide](https://forums.ea.com/discussions/fc-26-technical-issues-en/ea-sports-fc-26-pc-fix-%E2%80%93-community-guide/12830000) -- AppData paths
- [EA Help -- EA Javelin Anticheat](https://help.ea.com/en/articles/platforms/pc-ea-anticheat/) -- Anti-cheat system details
- [Advanced Uninstaller -- FC 26](https://www.advanceduninstaller.com/EA-SPORTS-FC-26-0e79403295f6847d8ed43ed6f939f6f9-application.htm) -- FC26.exe name, install path
- [Steam Store -- EA SPORTS FC 26 (App 3405690)](https://store.steampowered.com/app/3405690/EA_SPORTS_FC_26/) -- Steam App ID confirmed
- [LagoFast -- FC 26 Graphic Settings Guide](https://www.lagofast.com/en/blog/fc-26-graphic-settings-guide-on-pc/) -- Additional in-game setting names
