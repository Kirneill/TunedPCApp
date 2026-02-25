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
Power plan, HAGS, Game Mode, MMCSS priority, network tweaks, visual effects, fullscreen optimizations, mouse acceleration removal, CPU power management.

### Game Optimizations
Applies competitive/performance settings for each supported game — config files, launch options, and registry values tuned for maximum FPS and minimum input lag.

### BIOS & GPU Guides
Interactive checklists for BIOS settings (XMP, Resizable BAR, etc.) and NVIDIA/AMD GPU control panel configuration.

### Backup & Restore
Automatically backs up registry keys and config files before making changes. One-click restore from the Backups page.

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
│   ├── handlers.ts      # Optimization orchestration
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
    └── ui/              # Reusable components (LogViewer, Toggle, etc.)

scripts/                 # PowerShell optimization scripts (bundled with app)
```

### Key Design Decisions

- **PowerShell scripts wrapped, not ported** — scripts are tested and working; the app executes them via `child_process.spawn` with env vars for headless mode
- **Frameless window** — custom title bar for gaming aesthetic
- **Admin required** — registry and system setting changes need elevation
- **Fire-and-forget telemetry** — never blocks UI; all Supabase calls are wrapped in try/catch

### Telemetry Setup (for contributors)

1. Create a [Supabase](https://supabase.com) project
2. Run `supabase-schema.sql` in the SQL Editor
3. Copy Project URL and Publishable key to `electron/telemetry/config.ts`
4. Set `TELEMETRY_CONFIGURED = true`
