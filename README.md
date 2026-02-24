# SENSEQUALITY PC Gaming Optimizer

A Windows desktop app that automates BIOS settings guidance, Windows optimizations, and FPS game-specific settings for competitive gaming. Built with Electron + React + Tailwind CSS.

## Project Status

**Current state**: Core app shell is built and launches successfully. All UI components, data models, IPC handlers, and PowerShell integration are implemented. The app needs dev workflow testing and PowerShell script modifications for headless mode.

### What's Done
- [x] Electron main process with admin detection, single-instance lock, diagnostic logging
- [x] Preload script with typed context bridge API (IPC surface)
- [x] React 19 + Tailwind 4 renderer with dark gaming theme
- [x] Dashboard page: System info card, detected games card, monitor config, optimization toggles
- [x] Windows optimization toggles (9 settings from `01_Windows_Optimization.ps1`)
- [x] Game optimization toggles (5 games: BO7, Fortnite, Valorant, CS2, Arc Raiders)
- [x] "Run All Selected" button with real-time log streaming from PowerShell
- [x] BIOS Guide page with interactive checklist (persisted to localStorage)
- [x] GPU Guide page (NVIDIA + AMD settings tables, G-SYNC/FreeSync setup)
- [x] Backup management page (list, create, restore, delete)
- [x] Zustand state management with localStorage persistence
- [x] PowerShell execution engine (spawn with env vars, stdout streaming)
- [x] System info detection via WMI (GPU, CPU, RAM, OS)
- [x] Game detection (Steam VDF, Epic manifests, Riot registry, Battle.net registry)
- [x] Vite + vite-plugin-electron build pipeline
- [x] electron-builder NSIS installer configuration

### What's Remaining
- [ ] Test `npm run dev` end-to-end (Vite dev server + Electron hot reload)
- [ ] Modify PowerShell scripts for headless mode (`$env:SENSEQUALITY_HEADLESS` checks)
- [ ] Add per-section skip env vars to `01_Windows_Optimization.ps1`
- [ ] Test actual optimization execution flow
- [ ] App icon and branding assets
- [ ] electron-builder packaging test (NSIS installer)
- [ ] Test on clean Windows 11 machine

## Architecture

```
Electron Main Process (electron/main.ts)
├── Window management (frameless, custom title bar, admin check)
├── Diagnostic logger → %APPDATA%/sensequality-optimizer/logs/
├── IPC Handlers (electron/ipc/)
│   ├── handlers.ts      → Routes IPC calls, orchestrates optimization runs
│   ├── powershell.ts    → Spawns PowerShell scripts with env vars + stdout streaming
│   ├── system-info.ts   → WMI queries for GPU/CPU/RAM/OS detection
│   ├── game-detection.ts→ Scans Steam/Epic/Riot/Battle.net for installed games
│   └── backup-manager.ts→ Registry export/import, backup lifecycle
│
React Renderer (src/)
├── App.tsx              → Root layout with sidebar navigation
├── store/appStore.ts    → Zustand store (toggles, config, progress, system info)
├── data/                → Static optimization definitions, BIOS guide, GPU guide
├── components/
│   ├── layout/          → TitleBar (custom frameless), Sidebar navigation
│   ├── dashboard/       → SystemInfoCard, DetectedGamesCard, MonitorConfig, QuickActions
│   ├── optimizations/   → OptimizationSection (collapsible), OptimizationToggle
│   ├── guides/          → BiosGuidePage (checklist), NvidiaGuidePage (settings tables)
│   ├── backups/         → BackupPage (list/restore/delete)
│   └── ui/              → Toggle, Card, Badge, LogViewer (reusable primitives)
│
Existing PowerShell Scripts (scripts/)
├── 01_Windows_Optimization.ps1  → 9 Windows tweaks (power plan, HAGS, network, etc.)
├── 02-06_Game_Settings.ps1      → Per-game config file + registry modifications
├── 07_NVIDIA_ControlPanel_Guide.ps1 → GPU settings reference
├── RESTORE_DEFAULTS.ps1         → Undo all changes from backups
└── Gaming Research/             → Detailed research docs per game/topic
```

### Data Flow: "Run All Selected"

1. User toggles optimizations on/off → stored in Zustand + localStorage
2. Clicks "Run All Selected" → `QuickActions.tsx` calls `window.sensequality.runSelected(ids, config)`
3. Preload forwards via `ipcRenderer.invoke('optimize:runSelected', ...)`
4. `handlers.ts` groups Windows toggles (they share one script), sets skip env vars for unchecked
5. Spawns `powershell.exe -File 01_Windows_Optimization.ps1` with `SENSEQUALITY_HEADLESS=1`
6. Each stdout line streams back via `BrowserWindow.webContents.send('optimize:log', ...)`
7. Renderer's `onProgressLog` callback appends to Zustand `progressLog`
8. `LogViewer` component auto-scrolls and renders with timestamps
9. Game scripts run sequentially after Windows optimizations complete
10. Summary sent on completion

### Key Environment Variables

| Variable | Purpose |
|---|---|
| `ELECTRON_RUN_AS_NODE` | **MUST be unset** for Electron to work. VS Code sets this to `1` in its terminal. Our npm scripts use `cross-env ELECTRON_RUN_AS_NODE=` to clear it. |
| `VITE_DEV_SERVER_URL` | Set automatically by `vite-plugin-electron` in dev mode. Main process uses this to load the Vite dev server instead of the built HTML. |
| `SENSEQUALITY_HEADLESS` | Tells PowerShell scripts to skip `Read-Host` prompts and reboot confirmations. Set to `1` by the app. |
| `SKIP_POWER_PLAN`, `SKIP_HAGS`, etc. | Per-section skip flags for `01_Windows_Optimization.ps1`. `0` = apply, `1` = skip. |
| `MONITOR_WIDTH/HEIGHT/REFRESH` | User's monitor config passed to game scripts for resolution settings. |
| `NVIDIA_GPU` | `1` for NVIDIA, `0` for AMD. Controls which GPU-specific settings are applied. |

## Development Setup

### Prerequisites
- Node.js 20+ (LTS)
- npm 9+
- Windows 10/11 (the app uses PowerShell and Windows-specific APIs)

### Install and Run

```bash
# Install dependencies
npm install

# IMPORTANT: If running from VS Code terminal, you MUST unset ELECTRON_RUN_AS_NODE:
unset ELECTRON_RUN_AS_NODE

# Start dev mode (Vite dev server + Electron with hot reload)
npm run dev

# Build for production
npm run build

# Package as NSIS installer
npm run package
```

### Known Issues

1. **`ELECTRON_RUN_AS_NODE=1`**: VS Code's integrated terminal sets this env var, which makes Electron run as plain Node.js (disabling all Electron APIs). Our npm scripts handle this via `cross-env`, but if you run `electron .` directly, you must `unset ELECTRON_RUN_AS_NODE` first.

2. **GPU process errors on exit**: `GPU process exited unexpectedly: exit_code=143` is normal when force-killing the app (e.g., via `timeout` or Ctrl+C). It means the GPU subprocess was terminated.

3. **PowerShell scripts need headless mode**: The existing `.ps1` scripts use `Read-Host` for user prompts. They need `$env:SENSEQUALITY_HEADLESS` checks added to skip prompts when run from the app.

## File Structure

```
f:\CLAUDE\APPGaming\
├── package.json              # Dependencies + scripts
├── vite.config.ts            # Vite + React + Tailwind + Electron plugin config
├── tsconfig.json             # TypeScript config for React renderer
├── electron-builder.yml      # NSIS installer packaging config
├── index.html                # Vite entry HTML
│
├── electron/                 # Electron main process (TypeScript, built by Vite)
│   ├── main.ts               # App entry, window, admin check, logging
│   ├── preload.ts            # Context bridge (typed IPC API)
│   └── ipc/
│       ├── handlers.ts       # All IPC handler registration
│       ├── powershell.ts     # PowerShell execution engine
│       ├── system-info.ts    # Hardware detection via WMI
│       ├── game-detection.ts # Installed game scanner
│       └── backup-manager.ts # Backup create/restore/list
│
├── src/                      # React renderer (TypeScript + JSX)
│   ├── main.tsx              # React entry point
│   ├── App.tsx               # Root component with sidebar navigation
│   ├── index.css             # Tailwind 4 config + custom dark theme
│   ├── store/appStore.ts     # Zustand state management
│   ├── types/index.ts        # TypeScript interfaces + global Window augmentation
│   ├── data/
│   │   ├── optimizations.ts  # Windows + game optimization definitions
│   │   ├── bios-guide.ts     # BIOS checklist data (8 steps)
│   │   └── nvidia-guide.ts   # NVIDIA/AMD GPU settings data
│   └── components/
│       ├── layout/           # TitleBar, Sidebar
│       ├── dashboard/        # SystemInfoCard, DetectedGamesCard, MonitorConfig, QuickActions, DashboardPage
│       ├── optimizations/    # OptimizationSection, OptimizationToggle
│       ├── guides/           # BiosGuidePage, NvidiaGuidePage
│       ├── backups/          # BackupPage
│       └── ui/               # Toggle, Card, Badge, LogViewer
│
├── scripts/                  # EXISTING PowerShell optimization scripts
│   ├── 01_Windows_Optimization.ps1
│   ├── 02_BlackOps7_Settings.ps1
│   ├── 03_Fortnite_Settings.ps1
│   ├── 04_Valorant_Settings.ps1
│   ├── 05_CS2_Settings.ps1
│   ├── 06_ArcRaiders_Settings.ps1
│   ├── 07_NVIDIA_ControlPanel_Guide.ps1
│   ├── RESTORE_DEFAULTS.ps1
│   └── Gaming Research/      # Detailed research docs per game
│
└── resources/                # Electron-builder resources (icons, etc.)
```

## Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| Electron | 33.x | Desktop shell, admin elevation, PowerShell execution |
| React | 19.x | UI components |
| Vite | 7.x | Build tool + dev server |
| Tailwind CSS | 4.x | Styling (dark theme) |
| Zustand | 5.x | State management |
| vite-plugin-electron | 0.29.x | Electron + Vite integration |
| electron-builder | 26.x | NSIS installer packaging |
| TypeScript | 5.x | Type safety |

## Design Decisions

### Why Electron + React (not Tauri)
- **Ship speed**: Largest ecosystem, most Stack Overflow answers, most forgiving
- **Reliability**: Battle-tested by Discord, VS Code, Slack
- **PowerShell integration**: `child_process.spawn` is straightforward in Node.js
- **Trade-off**: ~150MB install size, ~80-120MB RAM. Acceptable for a gaming optimization tool.

### Why execute existing .ps1 scripts (not port to JS)
- Scripts are already tested and working
- Registry operations via PowerShell are more reliable than npm packages
- Scripts remain usable standalone for advanced users
- 5x faster to ship than rewriting in JavaScript
- Can port to JS incrementally in v2

### Why Zustand (not Redux/Context)
- Single file, zero boilerplate
- Perfect for this scale (~15 state fields)
- Built-in devtools support

### Why `cross-env ELECTRON_RUN_AS_NODE=`
- VS Code sets `ELECTRON_RUN_AS_NODE=1` which disables all Electron APIs
- `cross-env` ensures this is cleared on all platforms
- This was the root cause of a multi-hour debugging session during initial setup

## Diagnostic Logging

The app writes structured logs to `%APPDATA%/sensequality-optimizer/logs/main-YYYY-MM-DD.log`:

```
[2026-02-24T19:53:21.810Z] [INFO] SENSEQUALITY Optimizer starting
[2026-02-24T19:53:21.810Z] [INFO] Electron: 33.4.11, Node: 20.18.3, Chrome: 130.0.6723.191
[2026-02-24T19:53:21.811Z] [INFO] process.type: browser, isPackaged: false
[2026-02-24T19:53:21.811Z] [INFO] ELECTRON_RUN_AS_NODE: unset
[2026-02-24T19:53:21.839Z] [INFO] App ready, registering IPC handlers
[2026-02-24T19:53:21.864Z] [INFO] Creating window, admin: true
```

These logs capture:
- Electron/Node/Chrome versions
- Admin privilege status
- Whether `ELECTRON_RUN_AS_NODE` was properly unset
- Window creation, page load, and IPC handler registration
- Uncaught exceptions and unhandled promise rejections

## For New Agents / Continuing Work

If you're picking up this project on another machine:

1. **Read this README** for architecture context
2. **Check the "What's Remaining" section** above for next steps
3. **Key files to understand**:
   - `electron/main.ts` — App entry, window creation, logging
   - `electron/ipc/handlers.ts` — All IPC routing, the "brain" of optimization flow
   - `src/store/appStore.ts` — All state management
   - `src/data/optimizations.ts` — Optimization toggle definitions
4. **Critical env var**: Always `unset ELECTRON_RUN_AS_NODE` before running Electron
5. **The existing PowerShell scripts in `scripts/`** are the source of truth for what settings to apply. The app wraps them.
6. **Next major task**: Modify the `.ps1` scripts to support headless mode (check `$env:SENSEQUALITY_HEADLESS` to skip `Read-Host` prompts)
