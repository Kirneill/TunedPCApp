# SENSEQUALITY Optimizer

Windows desktop app (Electron + React) that applies PowerShell-based optimizations for competitive FPS gaming.

**Stack:** Electron 33, React 19, Vite 7, Tailwind 4, Zustand 5, TypeScript 5, Supabase (auth + telemetry)

## How to Use This File (for the human)

This CLAUDE.md is read automatically by every new Claude session. It teaches the AI the correct workflow so you don't have to re-explain it each time. Here's what you need to know:

### Adding a new game
Prompt: **"Add [Game Name] as a new game optimization. Follow the CLAUDE.md workflow."**

That's it. The AI will follow all 5 phases (Research, Reference Config, Script, Register, Validate) and run the Pester tests automatically. You don't need to remind it about BOM, key names, or structural envelopes — it's all documented below.

### After the AI writes a new game script
Prompt: **"Run the Pester tests for [gameid]"** — this catches wrong key names, bad encoding, missing structural fields, and wrong value types *before* you ship.

If a test fails, the AI already knows what to fix because the failure message says exactly what's wrong (e.g., "These keys are not in the reference config: ShadowQuality, LobbyFPS").

### Auditing existing games (add tests to a working game)
Prompt: **"Audit [Game] — read the research in Gaming Research/, create a reference config, add Pester tests, and verify the script. Don't modify the script if it's confirmed working."**

The AI reads the existing research first, extracts the correct key names, builds a reference config, and writes tests that validate the script output against it.

### If a user reports a game-breaking bug (config related)
Prompt: **"[Game] settings break the game after optimization. Read the research in Gaming Research/, research the correct config format, fix the script, and run the Pester tests."**

The AI will read your existing research, compare the script's key names against the reference config, check encoding, and validate the structural envelope.

### Releasing a fix
Prompt: **"Commit, build, and release to both repos with user-facing release notes."**

The AI knows the full release checklist (bump version, build, package, copy to hyphenated names, upload to both repos).

### Key things to remember
- **Research files** live under `Gaming Research/` (both top-level and `New Games/` subfolder). The AI should ALWAYS search this entire folder for existing research before writing or auditing a script.
- **Reference configs** (`scripts/reference-configs/`) are the source of truth. If a test fails, check whether the reference config needs updating (new game version) or the script has a typo.
- **Pester 5 is required** (Windows ships with 3.4.0). Already installed on this machine. If running on a new machine: `Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser`
- **Don't use em dashes (—) or bare ampersands (&) in .ps1 comments** — they cause parse errors when PowerShell processes the file in certain contexts (like Pester invocation). Use `--` and `and` instead.

---

## Key Architecture

| Area | Files |
|------|-------|
| Main process | `electron/main.ts`, `electron/ipc/handlers.ts`, `electron/ipc/powershell.ts` |
| Auth | `electron/auth/auth.ts`, `electron/ipc/auth-handlers.ts` |
| Telemetry | `electron/telemetry/telemetry.ts`, `electron/telemetry/config.ts` |
| Renderer | `src/App.tsx`, `src/components/home/HomePage.tsx`, `src/store/appStore.ts` |
| Game data | `src/data/optimizations.ts` (UI metadata), `electron/ipc/game-detection.ts` (install detection) |
| Scripts | `scripts/*.ps1` (PowerShell optimization scripts) |
| Research | `Gaming Research/` and `Gaming Research/New Games/` (settings research per game) |
| Reference configs | `scripts/reference-configs/` (known-good config files for validation) |
| Tests | `scripts/tests/GameSettings.Tests.ps1` (Pester config validation) |

## Data Flow: Optimization Run

1. User toggles games/Windows on in UI (Zustand store)
2. OPTIMIZE button calls `window.sensequality.runSelected(ids, config)` via preload bridge
3. Main process maps IDs to scripts via `SCRIPT_MAP` in `handlers.ts`
4. Spawns PowerShell with `SENSEQUALITY_HEADLESS=1` + monitor/GPU env vars
5. Script stdout streams back via IPC to real-time LogViewer
6. `[SQ_CHECK_OK/WARN/FAIL:KEY]` markers in stdout are parsed for per-setting status

## Build & Release

```bash
npm run dev          # Vite dev + Electron hot reload
npm run build        # Production build -> dist/ + dist-electron/
npx electron-builder --win nsis  # NSIS installer -> release/
```

**Release checklist:**
1. Bump version: `npm version patch --no-git-tag-version`
2. Build + package
3. Copy release files to hyphenated names (electron-builder outputs spaces)
4. Upload `.exe`, `.exe.blockmap`, `latest.yml` to BOTH repos via `gh release create`
5. Repos: `Kirneill/sensequality-optimizer` (private) and `Kirneill/TunedPCApp` (public)

**ELECTRON_RUN_AS_NODE:** VS Code sets this env var which breaks Electron APIs. `npm run dev` clears it via `cross-env ELECTRON_RUN_AS_NODE=`.

---

## Adding a New Game Optimization

### CRITICAL RULES (learned from bugs)

1. **NEVER guess config key names.** Always verify against a REAL config file from an actual installation or a community GitHub repo. Store the reference in `scripts/reference-configs/`.
2. **NEVER blind-overwrite config files.** Always read-merge-write: parse existing config, override only performance keys, preserve everything else (resolution, display, account data).
3. **JSON config files: write UTF-8 WITHOUT BOM.** PowerShell 5.1's `Set-Content -Encoding UTF8` adds a BOM (`EF BB BF`) that breaks Unity's JSON parser. Use `[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))`.
4. **Validate structural requirements.** Some games require specific top-level fields to load (e.g., Tarkov needs `Version`, `Stored[]`, `DisplaySettings{}` in Graphics.ini). Missing these causes infinite loading screens.
5. **Guide text must match config values.** If the script writes `DLSSMode = "Off"`, the printed guide must NOT say "DLSS: Quality".

### Step-by-step Checklist

#### Phase 1: Research

**FIRST: Search `Gaming Research/` for existing research** (check both the top-level folder and the `New Games/` subfolder). Look for files matching the game name — e.g., `*Tarkov*`, `*BO7*`, `*Fortnite*`. If research exists, READ IT — it contains the recommended settings, config format details, and key names from a prior research session. Use it as your primary source and only do fresh research to fill gaps.

If no research file exists, use `Gaming Research/RESEARCH_TEMPLATE.md` as the template.

The research (existing or new) MUST capture:

- [ ] **Exact config file path** and format (JSON, INI, ConVar, XML)
- [ ] **A REAL reference config file** — full, not excerpted. Fetch from GitHub, community repos, or a real installation. Store in `scripts/reference-configs/`
- [ ] **Every config key** with its exact name (case-sensitive), data type, and valid values
- [ ] **Structural requirements** — what top-level fields must exist for the game to load
- [ ] **Which keys are safe to change** (performance) vs which must be preserved (resolution, display, account)
- [ ] **Anti-cheat safety** — confirm config file edits are safe
- [ ] **Source URL** where key names were verified

Save to: `Gaming Research/New Games/<GameName>_FPS_Settings.md`

#### Phase 2: Reference Config

Copy the real config file to `scripts/reference-configs/<gameid>-<filename>`:
```
scripts/reference-configs/tarkov-Graphics.ini
scripts/reference-configs/rust-client.cfg
scripts/reference-configs/r6siege-GameSettings.ini
```

This file is used by Pester tests to validate script output and by future developers as ground truth.

#### Phase 3: PowerShell Script

Create `scripts/XX_<GameName>_Settings.ps1` following this pattern:

```powershell
#Requires -RunAsAdministrator

# --- HEADLESS MODE ---
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"
if ($Headless -and $env:MONITOR_WIDTH) {
    $MonitorWidth   = [int]$env:MONITOR_WIDTH
    $MonitorHeight  = [int]$env:MONITOR_HEIGHT
    $MonitorRefresh = [int]$env:MONITOR_REFRESH
    $NvidiaGPU      = $env:NVIDIA_GPU -eq '1'
} else {
    $MonitorWidth = 1920; $MonitorHeight = 1080; $MonitorRefresh = 240; $NvidiaGPU = $true
}

# SECTION 1: LOCATE GAME AND SET EXE FLAGS
# - Check $env:<GAME>_PATH from host, registry keys, common paths
# - Set AppCompat flags: HIGHDPIAWARE DISABLEFULLSCREENOPTIMIZATIONS
# - Output: [SQ_CHECK_OK:<GAME>_EXE_FLAGS] or [SQ_CHECK_WARN:...:EXE_NOT_FOUND]

# SECTION 2: WRITE OPTIMIZED CONFIG
# - READ existing config (preserve resolution/display/structural envelope)
# - VALIDATE structural envelope (reject if required fields missing)
# - MERGE competitive settings (only override performance keys)
# - WRITE with correct encoding (UTF-8 no BOM for JSON)
# - LOCK read-only
# - Output: [SQ_CHECK_OK:<GAME>_CONFIG_WRITTEN] or [SQ_CHECK_FAIL:...]

# SECTION 3: PRINT IN-GAME SETTINGS GUIDE
# - List settings that can't be set via config (PostFX, etc.)
# - Guide text MUST match actual config values written
```

Key implementation details:
- Use `[ordered]@{}` for competitive settings with correct key names from reference config
- Backup existing config with timestamp before writing
- Wrap all file operations in try-catch
- Emit `[SQ_CHECK_OK/WARN/FAIL:KEY]` markers for every section (never skip)

#### Phase 4: Register in App

Three files need entries:

**`src/data/optimizations.ts`** — UI metadata:
```typescript
{ id: 'game-<gameid>', label: '<Game Name>', description: '...', category: 'game', risk: 'safe', requiresReboot: false, gameId: '<gameid>' }
```

**`electron/ipc/handlers.ts`** — Script mapping + env var:
```typescript
// In GAME_PATH_ENV_VARS:
'game-<gameid>': '<GAME>_PATH',
// In SCRIPT_MAP:
'game-<gameid>': { script: 'XX_<GameName>_Settings.ps1' },
```

**`electron/ipc/game-detection.ts`** — Install detection:
```typescript
// In GAME_REGISTRY:
{ id: '<gameid>', name: '<Game Name>', steamFolders: ['<Steam folder>'], detect: find<Game> }
```

#### Phase 5: Validate

Run Pester 5 tests to verify the script produces valid config output:
```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester scripts/tests/GameSettings.Tests.ps1 -Tag '<gameid>'
```

**Requires Pester 5+** (Windows ships with 3.4.0). Install once:
```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

Tests verify: parseable output, no BOM, required keys exist, key names match reference, value types match.

---

## Config Format Reference

| Game | Format | Config Path | Structural Requirements |
|------|--------|-------------|------------------------|
| Tarkov | JSON (`.ini` ext) | `%APPDATA%\Battlestate Games\Escape from Tarkov\Settings\Graphics.ini` | Must have `Version`, `Stored[]`, `DisplaySettings{}` |
| Rust | ConVar key-value | `<Steam>\steamapps\common\Rust\cfg\client.cfg` | One `convar "value"` per line |
| R6 Siege | INI sections | `%USERPROFILE%\Documents\My Games\Rainbow Six - Siege\<uuid>\GameSettings.ini` | Must have `[DISPLAY]`, `[GRAPHICS]`, `[AUDIO]` sections |
| CS2 | CFG commands | `<Steam>\steamapps\common\...\cs2\cfg\autoexec.cfg` | Standard Source 2 CFG |
| Fortnite | INI sections | `%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini` | UE4 INI with `[/Script/...]` sections |
| Valorant | INI sections | `%LOCALAPPDATA%\VALORANT\Saved\Config\*\GameUserSettings.ini` | UE4 INI format |
| COD BO7 | INI + YAML | `%USERPROFILE%\Documents\Call of Duty\players\options4.ini` | Standard INI |

## SQ_CHECK Marker Convention

Scripts output structured markers that `handlers.ts` parses for per-setting status:

```
[SQ_CHECK_OK:<KEY>]                    — Setting applied successfully
[SQ_CHECK_WARN:<KEY>:<REASON>]         — Applied with warnings (e.g., EXE not found)
[SQ_CHECK_FAIL:<KEY>:<REASON>]         — Failed to apply
```

Every code path in a script section MUST emit exactly one marker. If an exception could skip the marker, wrap the section in a try-catch that emits `SQ_CHECK_FAIL` in the catch block.
