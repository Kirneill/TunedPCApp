# SENSEQUALITY PC Gaming Optimizer

One-click optimization for competitive FPS gaming on Windows. Automates Windows settings, game configs, and provides guided BIOS/GPU setup — all wrapped in a sleek desktop app.

## Download

Grab the latest installer from [GitHub Releases](https://github.com/Kirneill/sensequality-optimizer/releases/latest).

> Requires **Windows 10/11**. The installer requests admin privileges (needed for registry and system setting changes).

## Supported Games

- Call of Duty: Black Ops 7
- Fortnite
- Valorant
- Counter-Strike 2
- Arc Raiders

## What It Does

### Windows Optimizations
Power plan, HAGS, Game Mode, MMCSS priority, network tweaks, visual effects, fullscreen optimizations, mouse acceleration removal, CPU power management, plus an optional one-click **Standard Windows baseline** profile.

### Windows Update Mode
Includes an in-app **Windows Update ON/OFF** control:
- **ON (recommended):** Updates enabled with security profile (driver updates excluded, no auto-restart while signed in, feature defer 365 days, quality defer 4 days)
- **OFF:** Disables update services/tasks and auto update policy for advanced/manual patch workflows

### Game Optimizations
Applies competitive/performance settings for each supported game — config files, launch options, and registry values tuned for maximum FPS and minimum input lag.

### BIOS & GPU Guides
Interactive checklists for BIOS settings (XMP, Resizable BAR, etc.) and NVIDIA/AMD GPU control panel configuration.

### Backup & Restore
Automatically backs up registry keys and config files before making changes. One-click restore from the Backups page.

### Safety & Diagnostics
- Auto-creates a **System Restore Point** before optimization runs
- Streams live optimization logs in-app
- Persists per-run diagnostic logs to disk
- Provides one-click **Export Diagnostics** ZIP from the Backups page

## Current State Snapshot (Handoff)

This section is intentionally detailed so another model/developer can resume quickly.

### App Version / Installer
- Current package version: **1.0.4**
- Installer output: `release/SENSEQUALITY Optimizer Setup 1.0.4.exe`

### Recently Added Features
1. Standard baseline integration:
   - New Windows toggle: `win-standard`
   - Script: `scripts/08_Standard_Windows_Settings.ps1`
2. Windows Update mode actions:
   - OFF script: `scripts/09_Windows_Update_Off.ps1`
   - ON+security script: `scripts/10_Windows_Update_On.ps1`
   - UI card component: `src/components/windows/WindowsUpdateModeCard.tsx`
3. Restore-point guard:
   - `electron/ipc/handlers.ts` now creates a restore point before any `runOptimization`/`runSelected` change execution.
4. Admin escalation behavior:
   - `electron/main.ts` attempts elevation (`RunAs`) when not admin.
   - If elevation is denied/fails, app continues (no hard-block dialog), and scripts still enforce privileges.
5. Logging/telemetry upgrade:
   - Added per-run `runId`
   - Added JSONL run logs at Electron `app.getPath('userData')/logs/runs/<runId>.jsonl`
   - Normalized run log schema per line:
     - `timestamp, level, runId, component, action, script, success, errorCode, message`
   - Added telemetry failure fields (consent-gated):
     - `failure_stage` (`restore-point` | `elevation` | `script-exit`)
     - `error_fingerprint` (normalized/hash-based error signature)
   - Added telemetry event type: `optimization_failure`
   - Failure-stage telemetry emits from restore-point failures, elevation failures, and script-exit failures
   - Added warning logs where silent catches existed in telemetry/backup paths.
   - Updated `supabase-schema.sql` to be re-runnable on existing projects (`IF NOT EXISTS` indexes, policy recreation safety)
6. Diagnostics export (Phase 2):
   - New IPC route: `diagnostics:export`
   - New UI button: Backups page -> **Export Diagnostics**
   - ZIP output location: `C:\\Users\\<User>\\Documents\\SENSEQUALITY_Diagnostics_<timestamp>.zip`
   - ZIP contains:
     - `logs/` (main + run logs)
     - `telemetry.json` (if present)
     - `summary.json` (versions/platform/included files)

## Privacy

The app collects **anonymous** usage data (hardware specs, which optimizations succeed/fail) to improve recommendations. This is:
- **Opt-in** — you're asked on first launch
- **Anonymous** — no personal info, just a hashed machine ID
- **Toggleable** — turn it off anytime in Advanced Settings

No data is collected without your explicit consent.

## Want More FPS?

For professional 1-on-1 optimization, visit [sensequality.com](https://sensequality.com/products/pc-optimization).

---

## Development

### Prerequisites
- Node.js 20+ (LTS)
- npm 9+
- Windows 10/11

### Setup

```bash
npm install

# Start dev mode (Vite + Electron hot reload)
npm run dev

# Build production
npm run build

# Package as .exe installer
npm run package
```

> **VS Code terminal note:** If Electron fails to launch, run `unset ELECTRON_RUN_AS_NODE` first. VS Code sets this env var which disables Electron APIs.

### Tech Stack

| Technology | Purpose |
|---|---|
| Electron 33 | Desktop shell, admin elevation, PowerShell execution |
| React 19 | UI components |
| Vite 7 | Build tool + dev server |
| Tailwind CSS 4 | Red/black gaming theme |
| Zustand 5 | State management |
| Supabase | Anonymous telemetry backend |
| electron-builder | NSIS installer packaging |

### Architecture

```
electron/
├── main.ts              # Window, admin check, telemetry init, logging
├── preload.ts           # Context bridge (typed IPC API)
├── ipc/
│   ├── handlers.ts      # Optimization orchestration + run logging + diagnostics export
│   ├── powershell.ts    # Script execution with stdout streaming
│   ├── system-info.ts   # GPU/CPU/RAM detection via WMI
│   ├── game-detection.ts# Installed game scanner
│   └── backup-manager.ts# Registry backup/restore
└── telemetry/
    ├── telemetry.ts     # Supabase client, anonymous ID, consent
    └── config.ts        # Supabase credentials

src/
├── App.tsx              # Root layout with top nav
├── store/appStore.ts    # Zustand store
├── data/                # Optimization definitions, guide data
└── components/
    ├── home/            # GameCard grid, OPTIMIZE button
    ├── advanced/        # Per-setting toggles
    ├── guides/          # BIOS + GPU interactive checklists
    ├── backups/         # Backup management
    ├── windows/         # Windows update mode controls
    └── ui/              # Reusable components (LogViewer, Toggle, etc.)

scripts/                 # PowerShell optimization scripts (bundled with app)
```

### Key Design Decisions

- **PowerShell scripts wrapped, not ported** — scripts are tested and working; the app executes them via `child_process.spawn` with env vars for headless mode
- **Frameless window** — custom title bar for gaming aesthetic
- **Admin-aware execution** — startup attempts elevation; scripts still enforce privilege requirements
- **Fire-and-forget telemetry** — never blocks UI; all Supabase calls are wrapped in try/catch
- **Diagnostics-first runs** — each optimize run has a `runId` and persisted JSONL log

### Telemetry Setup (for contributors)

1. Create a [Supabase](https://supabase.com) project
2. Run `supabase-schema.sql` in the SQL Editor
3. If your project already has `telemetry_events`, run the same file anyway; it is migration-safe and idempotent
4. Copy Project URL and Publishable key to `electron/telemetry/config.ts`
5. Set `TELEMETRY_CONFIGURED = true`
