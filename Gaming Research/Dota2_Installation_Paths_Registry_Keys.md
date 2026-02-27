# Comprehensive Dota 2 Installation & Configuration Path Reference

## 1. INSTALLATION PATHS

### 1.1 Steam Registry Detection

**Primary Registry Keys (in order of reliability):**

```
Registry Path: HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam
Value Name: InstallPath
Type: REG_SZ
Example: C:\Program Files (x86)\Steam
```

**User-specific variant (fallback if HKLM fails):**
```
Registry Path: HKEY_CURRENT_USER\Software\Valve\Steam
Value Name: SteamPath
Type: REG_SZ
Example: C:\Program Files (x86)\Steam
```

### 1.2 Default Dota 2 Install Location

Once Steam path is found, Dota 2 is installed at:

```
<SteamPath>\steamapps\common\dota 2 beta\
```

**Steam App ID:** 570 (critical for manifest parsing)

### 1.3 Detecting Custom Steam Libraries

Steam library folders are defined in:
```
<SteamPath>\steamapps\libraryfolders.vdf
```

This is a KeyValues format file. Example structure:
```
"LibraryFolders"
{
	"0"		"C:\Program Files (x86)\Steam"
	"1"		"D:\SteamLibrary2"
	"2"		"E:\Games\SteamApps"
	"path"	"C:\Program Files (x86)\Steam"
	...
}
```

Dota 2 COULD be in ANY of these libraries at:
```
<LibraryPath>\steamapps\common\dota 2 beta\
```

**Detection Algorithm:**
1. Read `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam\InstallPath` → `<SteamPath>`
2. Open `<SteamPath>\steamapps\libraryfolders.vdf`
3. Parse all library paths (both numbered entries and "path" keys)
4. For each library, check if `<path>\steamapps\common\dota 2 beta\` exists
5. Also check for the Steam manifest file: `<path>\steamapps\appmanifest_570.acf`

### 1.4 Alternative: appmanifest_570.acf

If you locate the manifest file directly:
```
<LibraryPath>\steamapps\appmanifest_570.acf
```

This KeyValues file contains metadata:
```
"AppState"
{
	"appid"		"570"
	"Universe"	"1"
	"name"		"Dota 2"
	"StateFlags"	"4"
	"LastUpdated"	"1234567890"
	"UpdateResult"	"0"
	"SizeOnDisk"	"20000000000"
	"buildid"	"12345678"
	"LastMaintenance"	"1234567890"
	"installdir"	"dota 2 beta"
}
```

Parse the `installdir` field (usually `"dota 2 beta"`) and combine with library path:
```
<LibraryPath>\steamapps\<installdir>\
```

---

## 2. CONFIGURATION FILE PATHS

All paths relative to: `<DotaInstallPath>` = `<SteamPath>\steamapps\common\dota 2 beta\`

### 2.1 Video Settings File

```
<DotaInstallPath>\game\dota\cfg\video.txt
```

**Format:** KeyValues (Valve's VDF-style config format)

**Writable:** YES (critical caveat below)

**Does Dota 2 overwrite it?**
- YES. When you close the game OR change graphics settings in-game, the engine writes the current state back to this file.

**Should you set it read-only?**
- NO. If read-only, the game will fail to save in-game settings changes. Users will lose preferences.
- Instead: Write optimal settings here, then create autoexec.cfg to override them, OR programmatically re-apply settings after each session.

**Steam Cloud behavior:**
- If Steam Cloud is enabled for Dota 2, the Cloud version takes precedence
- File may be downloaded from cloud and overwrite your local version

### 2.2 Autoexec Config

```
<DotaInstallPath>\game\dota\cfg\autoexec.cfg
```

**Format:** Plaintext ConVar commands (one per line)

**Auto-executed:** YES, automatically executed on each game startup AFTER video.txt is read and parsed

**Writable:** YES

**Read-only impact:** Game can read and execute it, cannot overwrite it (which is fine—it's designed to be user-edited and persistent)

**Advantage:** Commands here override video.txt settings and persist across sessions

### 2.3 Steam Cloud Sync Paths

```
<SteamPath>\userdata\<SteamID64>\570\remote\cfg\
```

**What syncs here:**
- User-specific controller configurations
- Local preferences and keybinds
- May override local `cfg/` files if Steam Cloud sync is active

**How to detect SteamID64:**
- Parse `<SteamPath>\config\loginusers.vdf` (binary VDF)
- OR call Valve's Steam Web API with the account name
- OR read from running Steam process via IPC

**Does Steam Cloud override local files?**
- YES. If Steam Cloud is enabled for app 570:
  - Cloud files are downloaded first (before game launch)
  - Local files are overwritten by cloud copies if newer
  - Newer local changes are uploaded after game closes
- **Implication for optimizer:** Warn users that cloud-synced settings may override your optimizations if they play on multiple machines

---

## 3. EXECUTABLE NAME(S)

**Primary executable:**
```
dota2.exe
```

**Full path:**
```
<DotaInstallPath>\game\bin\win64\dota2.exe
```

**For GPU driver profiles (NVIDIA/AMD):**
- Use ONLY the executable name: `dota2.exe`
- Do NOT use the full path
- GPU drivers auto-detect running processes by name
- Both NVIDIA and AMD will recognize `dota2.exe`

**Alternate launch points (for reference only—NOT for optimization):**
- `steam.exe` (when launched via Steam—but GPU profiles don't target this)
- `SteamApps.exe` (legacy, rarely used)

---

## 4. STEAM LAUNCH OPTIONS

Launch options are stored in:

```
<SteamPath>\config\localconfig.vdf
```

**Format:** Binary KeyValues (NOT plaintext)

**Structure within the file:**
```
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"Apps"
				{
					"570"
					{
						"LaunchOptions"	"-novid -high +fps_max 0"
					}
				}
			}
		}
	}
}
```

**Parsing this requires:**
- A KV (KeyValues) VDF parser library (cannot edit as plaintext due to binary format)
- Cannot be edited with a text editor

**Recommended libraries:**
- **Python:** `vdf` (pip install vdf)
- **.NET/C#:** `VdfParser` (NuGet)
- **JavaScript/Node:** `vdf` (npm)
- **PowerShell:** Manual binary parsing OR call third-party tool

**Path to extract:**
```
UserLocalConfigStore > Software > Valve > Steam > Apps > 570 > LaunchOptions
```

---

## 5. DETAILED BEHAVIOR: VIDEO.TXT OVERWRITE

**Timeline of when video.txt is written:**

1. Game starts
   - Reads `video.txt`
   - Applies all settings

2. User changes graphics settings in-game menu
   - Game immediately marks the config as "dirty"

3. User closes game OR applies settings
   - Engine serializes current state to `video.txt`
   - File is flushed to disk

**If you set video.txt read-only:**
- Game attempt to write → fails → error logged (or silent fail)
- User's in-game settings changes are LOST
- On next launch, the read-only (old) version is read
- Result: User experience is broken

**Best practice for your optimizer:**
1. Write optimal `video.txt` before user plays
2. Do NOT set read-only
3. Create a robust `autoexec.cfg` to override critical settings
4. After detecting game closure, re-apply your optimizations to `video.txt`
5. OR document to users: "Your in-game settings will be overridden by our autoexec.cfg"

**Steam Cloud complication:**
- If user has Steam Cloud enabled, closing the game uploads settings to Valve's servers
- Next launch on a different machine downloads cloud config
- Your local optimizations are wiped

**Solution:**
- Check Steam Cloud status before applying optimizations
- Warn users to disable Steam Cloud for app 570 if using your optimizer
- OR re-apply optimizations in a game launch hook (if possible)

---

## 6. SUMMARY TABLE: ALL PATHS & KEYS

| Item | Full Path / Registry Key | Type | Notes |
|---|---|---|---|
| **Steam Root (Registry)** | `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam\InstallPath` | REG_SZ | Primary; fallback to HKCU variant |
| **Steam Root (Fallback)** | `HKEY_CURRENT_USER\Software\Valve\Steam\SteamPath` | REG_SZ | Use if HKLM fails |
| **Library Folders** | `<SteamPath>\steamapps\libraryfolders.vdf` | File (KV) | Enumerate ALL libraries here |
| **Dota 2 Manifest** | `<LibraryPath>\steamapps\appmanifest_570.acf` | File (KV) | Contains `installdir` metadata |
| **Dota 2 Install** | `<LibraryPath>\steamapps\common\dota 2 beta\` | Directory | Final install location |
| **video.txt** | `<DotaPath>\game\dota\cfg\video.txt` | File (KV) | Graphics settings; overwritten on exit |
| **autoexec.cfg** | `<DotaPath>\game\dota\cfg\autoexec.cfg` | File (plaintext) | Console commands; auto-executed |
| **Launch Options** | `<SteamPath>\config\localconfig.vdf` (binary) | File (KV binary) | Path: Apps > 570 > LaunchOptions |
| **Steam Cloud Sync** | `<SteamPath>\userdata\<SteamID64>\570\remote\cfg\` | Directory | May override local files |
| **GPU Executable** | `<DotaPath>\game\bin\win64\dota2.exe` | File | Use `dota2.exe` (name only) in GPU profiles |

---

## 7. COMPLETE IMPLEMENTATION CHECKLIST

For your SENSEQUALITY optimizer (Dota 2 support):

### Registry & Path Detection
- [ ] Query `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam\InstallPath`
- [ ] Fallback to `HKEY_CURRENT_USER\Software\Valve\Steam\SteamPath`
- [ ] Handle case where Steam is not installed (graceful error)

### Library Discovery
- [ ] Read `<SteamPath>\steamapps\libraryfolders.vdf` with KV parser
- [ ] Extract all library paths (both numbered keys like "0", "1" and "path" keys)
- [ ] For each library, check if `<Library>\steamapps\common\dota 2 beta\` directory exists
- [ ] Cache the discovered path for future optimization runs

### Configuration Application
- [ ] Write optimal `video.txt` with KeyValues format (use provided template from Dota2_FPS_Settings.md)
- [ ] Create/append `autoexec.cfg` with ConVar optimizations
- [ ] Parse `localconfig.vdf` (binary) with VDF library
- [ ] Read/write `Apps.570.LaunchOptions` with recommended flags: `-novid -high -dx11 +fps_max 0 -prewarm`

### GPU Driver Profiles
- [ ] Add `dota2.exe` to NVIDIA GeForce Experience / Control Panel
- [ ] Apply: Power Management Mode = Maximum Performance, Texture Filtering = High Performance, etc.
- [ ] Add to AMD Radeon Software profiles similarly
- [ ] Document: These are per-machine profiles, not stored with game

### User Warnings
- [ ] Warn: "Steam Cloud may override your optimizations. Disable it for Dota 2 or accept cloud sync."
- [ ] Warn: "In-game graphics changes will overwrite optimizations. Use autoexec.cfg for persistent overrides."
- [ ] Inform: "You can manually edit autoexec.cfg with console commands for advanced tuning."

### Steam Cloud Handling
- [ ] Detect if Steam Cloud is enabled for app 570
- [ ] Option 1: Warn user and suggest disabling
- [ ] Option 2: Place all critical settings in `autoexec.cfg` (executed AFTER cloud sync)
- [ ] Option 3: Provide a "re-optimize" button to reapply after detecting game closure

---

## 8. KEY TECHNICAL NOTES

### KeyValues (VDF) Format
- Used by Valve/Steam for config files
- Binary and text variants exist
- `libraryfolders.vdf`, `appmanifest_570.acf` = text KV
- `localconfig.vdf` = **binary** KV (requires parser)

### Environment Variable Expansion
- `<SteamPath>` typically = `C:\Program Files (x86)\Steam`
- `<DotaPath>` = `<SteamPath>\steamapps\common\dota 2 beta`
- No environment variables used in Steam config paths—resolve explicitly

### PowerShell Registry Access
```powershell
$steamPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
}
```

### Confidence Ratings
- **Registry paths:** HIGH (stable across Steam versions)
- **video.txt/autoexec.cfg locations:** HIGH (stable since Source 2 engine)
- **video.txt overwrite behavior:** HIGH (documented in community guides)
- **Steam Cloud override:** HIGH (Steam documentation confirms)
- **Launch options in localconfig.vdf:** HIGH (standard Steam behavior)
- **FPS impact:** MEDIUM (varies by hardware; see Dota2_FPS_Settings.md)

---

## References

- **Source:** `f:\CLAUDE\APPGaming\Gaming Research\New Games\Dota2_FPS_Settings.md` (comprehensive optimization guide)
- **Steam Documentation:** Community VDF parsing guides, Steam technical forums
- **Dota 2 Engine:** Source 2 (Valve's engine; stable since 2015 Reborn update)

