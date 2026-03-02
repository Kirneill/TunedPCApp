# <Game Name> -- FPS Optimization Settings

> **Instructions for research agent:** Fill in ALL sections below. Do NOT skip sections.
> The coding agent will use this document to write the PowerShell optimization script.
> Incomplete research (especially missing reference configs or guessed key names) causes game-breaking bugs.

## Important Caveats

- <Game engine, update frequency, anything that could change settings behavior>
- <Anti-cheat name>. Config file edits are safe / NOT safe.

---

## 1. Config File Specification

**Confidence: HIGH / MEDIUM / LOW**

| Property | Value |
|----------|-------|
| **Config file path** | `<exact path with env vars>` |
| **File format** | JSON / INI / ConVar / XML / other |
| **File encoding** | UTF-8 / UTF-8 with BOM / UTF-16 |
| **File extension** | `.ini` / `.cfg` / `.json` / other |

### Structural Requirements

> What top-level fields / sections MUST exist for the game to load?
> If these are missing, what happens? (crash, reset to defaults, infinite loading, etc.)

```
<List required structural fields, e.g.:
- "Version" (int) — schema version, currently 5
- "Stored" (array) — resolution presets, at least one entry
- "DisplaySettings" (object) — active display config
>
```

### File Ownership

> Does the game overwrite this file on exit? On launch? Does read-only lock work?
> Are there multiple config files per user/account?

---

## 2. Reference Config File

> **REQUIRED:** Paste a COMPLETE, REAL config file below. This must be from:
> - An actual game installation, OR
> - A verified community GitHub repo (provide URL)
>
> Do NOT excerpt or abbreviate. Do NOT invent key names.
> This reference will be stored in `scripts/reference-configs/` and used for validation.

**Source:** `<URL or "extracted from local installation">`

```
<PASTE COMPLETE CONFIG FILE HERE>
```

---

## 3. Config Key Reference

> For EVERY key in the reference config, document:

### Performance Keys (safe to override)

| Config Key (exact) | Type | Valid Values | Recommended | FPS Impact | Notes |
|---------------------|------|-------------|-------------|------------|-------|
| `<ExactKeyName>` | int / string / bool / float | `0-5` or `"Off"/"Low"/"Medium"` | `<value>` | HIGH/MED/LOW | <notes> |

### Structural Keys (must preserve, never override)

| Config Key (exact) | Type | Purpose |
|---------------------|------|---------|
| `<ExactKeyName>` | object/array/int | <why this must be preserved> |

### Keys NOT in Config (must set in-game)

| In-Game Setting | Notes |
|-----------------|-------|
| `<Setting Name>` | <why it can't be set via config> |

---

## 4. Key Name Verification

> How were the key names verified? Provide at least one source.

| Source | URL | Notes |
|--------|-----|-------|
| GitHub repo | `<url>` | <what version of the game> |
| Community wiki | `<url>` | |
| Decompiled source | N/A | <how verified> |
| Local installation | N/A | Extracted from `<path>` |

---

## 5. Installation Detection

**Confidence: HIGH / MEDIUM / LOW**

### Registry Keys
```powershell
# <Registry paths where the game stores its install location>
```

### Common Install Paths
```
<List common install directories>
```

### Steam Detection
- Steam folder name: `<folder name under steamapps/common/>`
- Steam App ID: `<number>`

### Other Launchers
- <Epic, Ubisoft, BSG Launcher, etc. — detection methods>

---

## 6. EXE Flags

| Executable | Path relative to install | Flags |
|------------|--------------------------|-------|
| `<Game.exe>` | `<relative path>` | `HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS` |

---

## 7. GPU-Specific Settings

### NVIDIA
| Setting | Recommended | Notes |
|---------|-------------|-------|
| Reflex | ON + Boost | <if supported> |
| DLSS | <mode> | <notes> |

### AMD
| Setting | Recommended | Notes |
|---------|-------------|-------|
| FSR | <mode> | <notes> |

---

## 8. Anti-Cheat Safety

| Anti-Cheat | Safe to modify | Details |
|------------|---------------|---------|
| `<Name>` | Config files: YES/NO | <what it monitors> |
| | Registry: YES/NO | |
| | Process priority: YES/NO | |

---

## 9. Additional Notes

> Stutter fixes, known issues, community workarounds, etc.
