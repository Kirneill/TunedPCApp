# League of Legends FPS Optimization Settings (2025/2026)

## 1. Config File Locations

**Base Path:** `C:\Riot Games\League of Legends\Config\`

| File | Purpose |
|------|---------|
| `game.cfg` | Graphics, sound, and gameplay settings (written on game close) |
| `input.ini` | Keybindings and input settings |
| `PersistedSettings.json` | Client-side persistent settings (JSON format) |

**Important:** `game.cfg` is rewritten each time a game ends. Set files to read-only after editing if you want to enforce values.

**Confidence: HIGH**

---

## 2. game.cfg Graphics Settings for Maximum FPS

### Section: [General]

| Setting | Recommended Value | Description |
|---------|-------------------|-------------|
| `WindowMode` | `2` | 2 = Fullscreen for best FPS; 1 = Borderless for easy alt-tab |
| `Width` | Native res (e.g., `1920`) | Match monitor native resolution |
| `Height` | Native res (e.g., `1080`) | Match monitor native resolution |
| `EnableScreenShake` | `0` | Disable screen shake |

### Section: [Performance]

| Setting | Recommended Value | Description |
|---------|-------------------|-------------|
| `GraphicsSlider` | `1` | Very Low preset (1-6 scale) |
| `ShadowsEnabled` | `0` | Disable shadows -- biggest FPS gain |
| `CharacterQuality` | `1` | Very Low (1-4 scale) |
| `EnvironmentQuality` | `1` | Very Low (1-4 scale) |
| `EffectsQuality` | `1` | Very Low (1-4 scale) |
| `ShadowQuality` | `0` | Off |
| `EnableGrassSwaying` | `0` | Disable grass animation |
| `EnableFXAA` | `0` | Disable anti-aliasing |
| `Antialiasing` | `0` | Disable all AA |
| `WaitForVerticalSync` | `0` | **Critical** -- disable VSync |
| `FrameCapType` | `6` | 6 = Uncapped (1=25, 2=30, 3=60, 4=80, 5=120, 6=Uncapped, 7=144, 8=200, 9=240) |
| `CharacterInking` | `0` | Disable black outline on characters |
| `EnableHUDAnimations` | `0` | Disable HUD animations |
| `HideEyeCandy` | `1` | Hide extra visual effects |
| `EnableParticleOptimizations` | `1` | Enable particle optimizations |
| `BudgetOverdrawAverage` | `10` | Lower overdraw budget |
| `BudgetSkinnedVertexCount` | `40000` | Lower skinned vertex budget |
| `BudgetTextureUsage` | `20000` | Lower texture memory budget |

**Confidence: HIGH** for core settings. **MEDIUM** for budget values.

---

## 3. Low Spec Mode

**Location:** `C:\Riot Games\League of Legends\Config\PersistedSettings.json`

```json
{
  "name": "LowSpecMode",
  "value": "1"
}
```

Enables Low Spec Mode which disables client animations and transitions.

**Confidence: MEDIUM** -- JSON schema changes occasionally.

---

## 4. Complete Optimized game.cfg Template

```ini
[General]
WindowMode=2
Width=1920
Height=1080
EnableScreenShake=0
[Performance]
GraphicsSlider=1
ShadowsEnabled=0
CharacterQuality=1
EnvironmentQuality=1
EffectsQuality=1
ShadowQuality=0
EnableGrassSwaying=0
EnableFXAA=0
Antialiasing=0
WaitForVerticalSync=0
FrameCapType=6
CharacterInking=0
EnableHUDAnimations=0
HideEyeCandy=1
EnableParticleOptimizations=1
BudgetOverdrawAverage=10
BudgetSkinnedVertexCount=40000
BudgetTextureUsage=20000
[HUD]
FlashScreenWhenDamaged=0
```

---

## 5. NVIDIA Driver Settings

| Setting | Value |
|---------|-------|
| Power Management Mode | Prefer Maximum Performance |
| Texture Filtering Quality | High Performance |
| Low Latency Mode | Ultra (or On) |
| Threaded Optimization | On |
| Maximum Pre-Rendered Frames | 1 |
| VSync (driver level) | Off |
| Triple Buffering | Off |
| Shader Cache Size | Unlimited |

Target executable: `League of Legends.exe` (NOT the Riot Client)

**Confidence: HIGH**

---

## 6. AMD Driver Settings

| Setting | Value |
|---------|-------|
| Anti-Lag | Enabled |
| Radeon Chill | Disabled |
| Radeon Boost | Disabled |
| Wait for Vertical Refresh | Always Off |
| Texture Filtering Quality | Performance |
| Surface Format Optimization | Enabled |
| Tessellation Mode | Override / Off |
| Shader Cache | On |

**Confidence: MEDIUM**

---

## 7. Windows Registry Tweaks

### Disable Fullscreen Optimizations
```
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
  "C:\Riot Games\League of Legends\Game\League of Legends.exe" = "~ DISABLEDXMAXIMIZEDWINDOWEDMODE"
```

### Disable Game DVR
```
HKCU\System\GameConfigStore
  GameDVR_Enabled = 0 (DWORD)

HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR
  AllowGameDVR = 0 (DWORD)
```

### GPU Hardware Scheduling
```
HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers
  HwSchMode = 2 (DWORD)
```

### Nagle Algorithm Disable
```
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{adapter-GUID}
  TcpAckFrequency = 1 (REG_DWORD)
  TCPNoDelay = 1 (REG_DWORD)
```

**Note:** League uses TCP for game data, making Nagle tweaks particularly relevant.

**Confidence: HIGH**

---

## 8. Network Optimization

### Process Priority
```powershell
Get-Process "League of Legends" | ForEach-Object { $_.PriorityClass = 'High' }
```

### Multimedia Throttling
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
  NetworkThrottlingIndex = 0xFFFFFFFF (DWORD)
  SystemResponsiveness = 0 (DWORD)
```

---

## 9. Programmatic Application

| Category | Method |
|---|---|
| Graphics Settings | Write `game.cfg` [Performance] section |
| Low Spec Mode | Modify `PersistedSettings.json` |
| Registry | PowerShell `Set-ItemProperty` |
| GPU Profiles | NVIDIA Profile Inspector / AMD Adrenalin CLI |

**Highest-impact programmatic changes:**
1. Writing the game.cfg `[Performance]` section
2. Disabling VSync at both game and driver level
3. Windows registry tweaks for Game DVR / fullscreen optimizations / Nagle
4. NVIDIA/AMD driver profile creation for the League executable

---

## Confidence Summary

| Category | Confidence |
|----------|-----------|
| Config file paths | HIGH |
| Core graphics settings | HIGH |
| Budget/particle settings | MEDIUM |
| Low Spec Mode | MEDIUM |
| NVIDIA driver settings | HIGH |
| AMD driver settings | MEDIUM |
| Windows registry tweaks | HIGH |
| Network tweaks (Nagle, DNS) | HIGH |

**Note:** Vanguard anti-cheat (deployed for LoL mid-2024) may restrict certain driver-level tweaks or process priority changes.

---

## APPENDIX: Installation Path Detection & Implementation Notes

### Game Install Path Detection

| Method | Path / Key |
|---|---|
| **RiotClientInstalls.json** | `C:\ProgramData\Riot Games\RiotClientInstalls.json` — parse `services.league_of_legends.install_dir` |
| **Registry** | `HKLM\SOFTWARE\WOW6432Node\Riot Games\League of Legends` > `InstallPath` |
| **Riot Client Registry** | `HKLM\SOFTWARE\WOW6432Node\Riot Games\Riot Client` > `InstallPath` |
| **Uninstall Registry** | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\League of Legends` > `InstallLocation` |

**Default Install Path:**
```
C:\Riot Games\League of Legends\
```

**Detection logic (recommended order):**
```powershell
# 1. Best: RiotClientInstalls.json
$riotJson = "C:\ProgramData\Riot Games\RiotClientInstalls.json"
if (Test-Path $riotJson) {
    $json = Get-Content $riotJson | ConvertFrom-Json
    $lolPath = $json.services.league_of_legends.install_dir
}

# 2. Fallback: Registry
if (!$lolPath) {
    $lolPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Riot Games\League of Legends" -ErrorAction SilentlyContinue).InstallPath
}

# 3. Fallback: Default path
if (!$lolPath) { $lolPath = "C:\Riot Games\League of Legends" }
```

### Config File Paths

| File | Full Path | Read-Only Needed? |
|---|---|---|
| `game.cfg` | `<LOL_DIR>\Game\Config\game.cfg` | **Optional but recommended** — LoL overwrites on game exit |
| `input.ini` | `<LOL_DIR>\Game\Config\input.ini` | No |
| `PersistedSettings.json` | `<LOL_DIR>\Game\Config\PersistedSettings.json` | No |
| Riot Client config | `%LOCALAPPDATA%\Riot Games\` | No |

**Note:** Config files are under `Game\Config\`, NOT directly under the install root.

### GPU Driver Profile — Target Executable

| Executable | Path | Use For GPU Profile? |
|---|---|---|
| `League of Legends.exe` | `<LOL_DIR>\Game\League of Legends.exe` | **YES** — primary game process |
| `RiotClientServices.exe` | `C:\Riot Games\Riot Client\RiotClientServices.exe` | No — client service |
| `RiotClientUx.exe` | `C:\Riot Games\Riot Client\RiotClientUx.exe` | No — client UI |
| `LeagueClientUx.exe` | `<LOL_DIR>\LeagueClientUx.exe` | No — lobby client |

### Read-Only Config Behavior

**Setting game.cfg to read-only is recommended** if you want to enforce optimized settings. League of Legends rewrites game.cfg every time a game ends. Without read-only, any in-game settings changes (even accidental) will overwrite your optimized config.

```powershell
$cfgPath = "$lolPath\Game\Config\game.cfg"
Set-ItemProperty -Path $cfgPath -Name IsReadOnly -Value $true
```

**Caveat:** Read-only may cause a silent failure when the game tries to save settings. This is generally harmless but prevents players from changing settings in-game until read-only is removed.

### Anti-Cheat Considerations (Vanguard)

**Riot Vanguard** runs as a kernel driver (`vgk.sys`) at boot time. Key considerations:
- **Config file edits are safe** — Vanguard does not monitor game config files
- **Registry tweaks (HKCU)** — Safe (Game DVR, Game Bar, Nagle)
- **Registry tweaks (HKLM)** — Generally safe for gaming optimizations (MMCSS, HAGS)
- **GPU driver profile changes** — Safe when done via NVIDIA Control Panel / AMD Adrenalin
- **Process priority changes** — May be restricted; test before shipping
- **DO NOT** use kernel-mode overlays, injection tools, or memory modification tools
- Vanguard location: `C:\Program Files\Riot Vanguard\` and `C:\Windows\System32\drivers\vgk.sys`
