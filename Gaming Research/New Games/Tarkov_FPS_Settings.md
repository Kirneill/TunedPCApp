# Escape from Tarkov -- FPS Optimization Settings (2025/2026)

## IMPORTANT CAVEATS

- Tarkov receives patches that can change setting behavior. Always verify against your installed version.
- Tarkov's Unity engine has undergone significant changes. Some settings behave differently across versions.
- BSG has been known to rename or relocate config entries between patches.

---

## 1. CONFIG FILE LOCATIONS

**Confidence: HIGH**

| Purpose | Path |
|---|---|
| Game settings (graphics, controls, etc.) | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\` |
| Local.ini / shared.ini | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\Graphics.ini` |
| Launcher logs | `%APPDATA%\Battlestate Games\BsgLauncher\Logs\` |
| Game install (default) | `C:\Battlestate Games\EFT\` |

**CRITICAL NOTE:** As of the 2024-2025 era, Tarkov stores most graphics settings in JSON format within the Settings folder. Some community sources report settings stored as JSON blobs within .ini files despite the extension.

---

## 2. IN-GAME GRAPHICS SETTINGS (Competitive Optimization)

**Confidence: HIGH** for setting names and recommended values.

### Resolution & Scaling

| Setting | Recommended Value | Rationale |
|---|---|---|
| **Screen Resolution** | Native (1920x1080 or 2560x1440) | Clarity for spotting enemies |
| **Screen Mode** | Fullscreen | Lower input lag vs. borderless |
| **DLSS / FSR** | DLSS Quality or FSR Quality | If GPU-bound; avoid Ultra Performance (blurry targets) |
| **DLSS Frame Generation** | OFF | Adds latency; bad for competitive |
| **Reflex Low Latency** | ON + Boost | Reduces render queue latency (NVIDIA only) |

### Core Graphics

| Setting | Config Key (approximate) | Recommended | Notes |
|---|---|---|---|
| **Texture Quality** | `TextureQuality` | Medium or High | Low looks awful; High has minimal FPS cost if VRAM > 6GB |
| **Shadow Quality** | `ShadowQuality` | Low or Medium | Big FPS impact; shadows rarely help competitively |
| **Shadow Visibility** | `ShadowVisibility` | 40-50 | Distance for shadow rendering; lower = better FPS |
| **Object LOD Quality** | `LODQuality` | 2-3 (scale of 2-4) | Affects player model detail at distance |
| **Overall Visibility** | `OverallVisibility` | 400-1000 | Draw distance; 400 min for gameplay; 1000 for sniping maps |
| **Anti-aliasing** | `AntiAliasing` | TAA or FXAA | TAA is softer but reduces shimmer |
| **HBAO (Ambient Occlusion)** | `SSAOMode` | OFF | Significant FPS cost, minimal competitive benefit |
| **SSR (Screen Space Reflections)** | `SSRMode` | OFF | Major FPS hit, purely cosmetic |
| **Anisotropic Filtering** | `AnisotropicFiltering` | Per texture or ON | Negligible FPS cost |
| **Sharpness** | `Sharpness` | 0.6-1.0 | Helps with target clarity |
| **Lobby FPS Limit** | `LobbyFPSLimit` | 60 | Saves GPU thermals in menu |
| **Game FPS Limit** | `GameFPSLimit` | 0 (unlimited) | 0 = uncapped |

### Checkboxes (Toggle Settings)

| Setting | Recommended | FPS Impact |
|---|---|---|
| **Z-Blur** | OFF | Small gain, removes motion blur on aim |
| **Chroma Aberration** | OFF | Small gain, removes color fringing |
| **Noise** | OFF | Small gain, cleaner image |
| **Grass Shadows** | OFF | Moderate gain |
| **MIP Streaming** | ON | Reduces VRAM usage, helps with stutters on 8GB VRAM cards |
| **RAM Cleaner** | OFF if 32GB+ RAM, ON if 16GB | Situational |
| **Only Use Physical Cores** | OFF for modern CPUs (12th gen+/Ryzen 5000+) | Situational |

---

## 3. CRITICAL PERFORMANCE SETTINGS (Stutter Fixes)

**Confidence: MEDIUM-HIGH**

### RAM Cleaner
- OFF if you have 32GB+ RAM. ON if you have 16GB.
- The RAM cleaner triggers garbage collection which can cause micro-stutters.

### Only Use Physical Cores
- OFF for most modern CPUs. ON for older CPUs with SMT/HT scheduling issues.

### MIP Streaming
- ON -- Streams textures on demand. Significantly reduces initial map load stutters and VRAM pressure.

---

## 4. PostFX SETTINGS (Competitive Visibility)

**Confidence: HIGH**

| Setting | Recommended Value | Purpose |
|---|---|---|
| **Brightness** | 0 to +50 | Lighten dark areas; map-dependent |
| **Saturation** | 0 to +30 | Makes colors pop, easier to spot movement |
| **Clarity** | 50-80 | Sharpens details; best single visibility boost |
| **Colorfulness** | 30-50 | Enhances color distinction |
| **Luma Sharpen** | 30-50 | Additional sharpening |
| **Adaptive Sharpen** | 0-30 | More aggressive sharpening |
| **Color Grading** | Cognac or Koda | Warm tones help spot dark-dressed PMCs |
| **Intensity** | 30-50 | Controls color grading strength |

**Key insight:** Clarity is the single most impactful PostFX setting for competitive play.

---

## 5. NVIDIA CONTROL PANEL OPTIMIZATIONS

**Confidence: HIGH**

| Setting | Value |
|---|---|
| **Power Management Mode** | Prefer Maximum Performance |
| **Texture Filtering - Quality** | High Performance |
| **Texture Filtering - Trilinear Optimization** | ON |
| **Texture Filtering - Negative LOD Bias** | Allow |
| **Texture Filtering - Anisotropic Sample Optimization** | ON |
| **Threaded Optimization** | ON |
| **Shader Cache Size** | Unlimited (or 10GB) |
| **Low Latency Mode** | Ultra (or use in-game Reflex instead) |
| **Max Frame Rate** | Match monitor Hz or Off |
| **Vertical Sync** | OFF |

---

## 6. AMD-SPECIFIC OPTIMIZATIONS

**Confidence: MEDIUM**

| Setting | Value |
|---|---|
| **Anti-Lag** | Enabled |
| **Radeon Boost** | OFF |
| **Image Sharpening** | ON, 50-80% |
| **Tessellation Mode** | Override, Off |
| **Texture Filtering Quality** | Performance |
| **Surface Format Optimization** | Enabled |
| **Wait for Vertical Refresh** | Off |
| **Frame Rate Target Control** | Match refresh rate |

---

## 7. REGISTRY TWEAKS

**Confidence: MEDIUM**

### Disable Full-Screen Optimizations
```
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
Key: "C:\Battlestate Games\EFT\EscapeFromTarkov.exe"
Value: "~ DISABLEDXMAXIMIZEDWINDOWEDMODE"
```

### Disable Game Bar / Game DVR
```
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR
  AppCaptureEnabled = 0 (DWORD)

HKCU\System\GameConfigStore
  GameDVR_Enabled = 0 (DWORD)
```

### Hardware-Accelerated GPU Scheduling (HAGS)
```
HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers
  HwSchMode = 2 (DWORD, 2=enabled)
```

### Disable Nagle's Algorithm
```
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{adapter-GUID}
  TcpAckFrequency = 1 (DWORD)
  TCPNoDelay = 1 (DWORD)
```

---

## 8. STUTTER-SPECIFIC FIXES

### Virtual Memory / Pagefile
- Set pagefile to System Managed or manual 16384-32768 MB on SSD

### Shader Cache
- Delete periodically: `%LOCALAPPDATA%\NVIDIA\DXCache\` or `%LOCALAPPDATA%\AMD\DXCache\`
- Also delete: `%LOCALAPPDATA%\Temp\Battlestate Games\`

### Process Priority
```powershell
Get-Process "EscapeFromTarkov" | ForEach-Object { $_.PriorityClass = "High" }
```

### Windows Power Plan
```powershell
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
```

---

## 9. PROGRAMMATIC APPLICATION SUMMARY

### Via Config File Editing
```json
{
  "TextureQuality": 1,
  "ShadowQuality": 1,
  "ShadowVisibility": 40,
  "LodQuality": 2,
  "OverallVisibility": 400,
  "AntiAliasing": 1,
  "SSAOMode": 0,
  "SSRMode": 0,
  "AnisotropicFiltering": 1,
  "Sharpness": 0.7,
  "ZBlur": false,
  "ChromaticAberration": false,
  "Noise": false,
  "GrassShadows": false,
  "MIPStreaming": true,
  "LobbyFPS": 60,
  "GameFPS": 0
}
```

**WARNING:** The exact JSON key names above are approximations. BSG obfuscates or renames these periodically. Verify against the actual config file content from a current installation.

---

## Confidence Summary

| Category | Confidence |
|---|---|
| Config file location (AppData path) | **HIGH** |
| In-game graphics setting names | **HIGH** |
| Config file JSON key names | **MEDIUM-LOW** |
| PostFX recommendations | **HIGH** |
| NVIDIA/AMD control panel settings | **HIGH** |
| Registry tweaks | **HIGH** for Windows tweaks |
| Launch options | **LOW** |
| Stutter fixes | **MEDIUM-HIGH** |
| DLSS/FSR | **HIGH** |

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

| Method | Path / Key |
|---|---|
| **BSG Launcher Config** | `%APPDATA%\Battlestate Games\BsgLauncher\settings.ini` or `launcher.ini` — contains install path |
| **Default Install** | `C:\Battlestate Games\EFT\` |
| **Uninstall Registry** | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov` > `InstallLocation` |
| **Alternative** | `HKCU\Software\Battlestate Games\` or `HKLM\SOFTWARE\Battlestate Games\` |

**Common Install Paths:**
```
C:\Battlestate Games\EFT\
D:\Battlestate Games\EFT\
C:\Games\Battlestate Games\EFT\
```

**BSG Launcher detection:**
```powershell
# BSG Launcher stores config here
$bsgLauncherPath = "$env:APPDATA\Battlestate Games\BsgLauncher"
# Parse settings file for game install directory

# Fallback: search uninstall registry
$uninstall = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov" -ErrorAction SilentlyContinue
$installPath = $uninstall.InstallLocation
```

### Config File Paths

| File | Full Path | Read-Only Needed? |
|---|---|---|
| Graphics settings | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\Graphics.ini` | **Recommended** — Tarkov overwrites on exit |
| Controls | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\Control.ini` | No |
| Sound | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\Sound.ini` | No |
| PostFX | Stored within Graphics.ini / in-game only | Cannot set programmatically (in-game UI only) |

**Note:** Config files may contain JSON blobs despite the `.ini` extension. Parse carefully.

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `EscapeFromTarkov.exe` | `<GAME_INSTALL_DIR>\EscapeFromTarkov.exe` | **YES** — primary game process |
| `BsgLauncher.exe` | `<GAME_INSTALL_DIR>\..\BsgLauncher\BsgLauncher.exe` | No — launcher only |

### Read-Only Config Behavior

**Set Graphics.ini to read-only after editing.** Tarkov writes settings back to the config file on game exit, which will overwrite your manual changes. Setting the file to read-only prevents this. Be aware this also prevents in-game settings changes from saving.

```powershell
$configPath = "$env:APPDATA\Battlestate Games\Escape from Tarkov\Settings\Graphics.ini"
Set-ItemProperty -Path $configPath -Name IsReadOnly -Value $true
```

### Anti-Cheat Considerations

**BattlEye** is Tarkov's anti-cheat. Key considerations:
- Config file modifications are **safe** — BattlEye does not monitor settings files
- Registry tweaks (Game DVR, Nagle, HAGS) are **safe** — these are OS-level settings
- **DO NOT** use process injection, memory editing, or overlay tools — BattlEye will flag these
- Timer resolution tools (e.g., ISLC) may trigger BattlEye on some versions — test carefully
- Process priority changes via PowerShell are generally **safe**
