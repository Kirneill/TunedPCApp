/**
 * Unified Game Registry — the SINGLE source of truth for all game metadata.
 *
 * To add a new game:
 *   1. Add an entry to GAMES below with all required fields.
 *   2. Write the PowerShell script and detection function.
 *   3. Register the detection function in game-detection.ts DETECTION_FUNCTIONS.
 *   That's it — optimizations.ts, handlers.ts, HomePage.tsx, and appStore.ts
 *   all derive their game entries from this array automatically.
 */

export interface GameDefinition {
  /** Short ID without prefix, e.g. 'bf6'. Used as gameId everywhere. */
  id: string;
  /** Display name, e.g. 'Battlefield 6' */
  name: string;
  /** Short display name for game cards on HomePage. Falls back to `name` if omitted. */
  cardName?: string;
  /** Card subtitle on HomePage, e.g. 'PROFSAVE · FFR On · Reflex On+Boost' */
  subtitle: string;
  /** Description for Advanced page tweak cards */
  description: string;
  /** Tailwind gradient classes for game card background */
  gradient: string;
  /** Short label rendered on game card, e.g. 'BF6' */
  letter: string;
  /** Risk level shown on Advanced page */
  risk: 'safe' | 'moderate';
  /** Whether a reboot is needed after optimization */
  requiresReboot: boolean;
  /** PowerShell script filename, e.g. '17_Battlefield6_Settings.ps1' */
  script: string;
  /** Env var name for passing detected install path to the PS1 script. Undefined = no path passing. */
  pathEnvVar?: string;
  /** Steam folder names under steamapps/common/ for VDF detection. Empty = not on Steam. */
  steamFolders: string[];
  /** Maps SQ_CHECK marker keys to human-readable labels for log output */
  checkLabels: Record<string, string>;
  /** Whether this game toggle is enabled by default for new users */
  defaultEnabled: boolean;
}

export const GAMES: GameDefinition[] = [
  {
    id: 'blackops7',
    name: 'Call of Duty: Black Ops 7',
    cardName: 'Call of Duty',
    subtitle: 'Black Ops 7 · Competitive Settings',
    description: 'Applies Windows EXE compatibility flags. In-game settings shown as reference guide (Ricochet protects config files).',
    gradient: 'from-orange-900 via-red-950 to-black',
    letter: 'COD',
    risk: 'safe',
    requiresReboot: false,
    script: '02_BlackOps7_Settings.ps1',
    pathEnvVar: undefined,
    steamFolders: ['Call of Duty HQ'],
    checkLabels: {
      COD_EXE_FLAGS: 'COD EXE compatibility flags',
      COD_GAME_MODE_ON: 'Windows Game Mode is ON',
      COD_GAME_DVR_OFF: 'Game DVR is OFF',
      COD_CONFIG_FILES_COPIED: 'COD config template copy step',
      COD_RENDERER_WORKER_COUNT: 'COD RendererWorkerCount patch step',
      COD_RENDER_SCALE_PRESERVED: 'COD render scale unchanged',
      COD_RENDER_SCALE_DETECTED: 'COD render scale detected',
    },
    defaultEnabled: true,
  },
  {
    id: 'fortnite',
    name: 'Fortnite',
    subtitle: 'Performance Mode · Competitive',
    description: 'Optimizes GameUserSettings.ini — Performance Mode (DX11), all competitive settings, NVIDIA Reflex On+Boost.',
    gradient: 'from-blue-900 via-violet-950 to-black',
    letter: 'FN',
    risk: 'safe',
    requiresReboot: false,
    script: '03_Fortnite_Settings.ps1',
    pathEnvVar: undefined,
    steamFolders: [],
    checkLabels: {
      FN_CONFIG_FILES_WRITTEN: 'Fortnite config files written',
      FN_CONFIG_WRITABLE: 'Fortnite config writable state',
    },
    defaultEnabled: true,
  },
  {
    id: 'valorant',
    name: 'Valorant',
    subtitle: 'Low Settings · Reflex On+Boost',
    description: 'Optimizes GameUserSettings.ini and EXE flags. Low materials, no shadows, NVIDIA Reflex On+Boost.',
    gradient: 'from-red-900 via-rose-950 to-black',
    letter: 'VAL',
    risk: 'safe',
    requiresReboot: false,
    script: '04_Valorant_Settings.ps1',
    pathEnvVar: undefined,
    steamFolders: [],
    checkLabels: {},
    defaultEnabled: true,
  },
  {
    id: 'cs2',
    name: 'Counter-Strike 2',
    subtitle: 'Autoexec + Launch Options',
    description: 'Creates autoexec.cfg with pro network settings, sets launch options via registry, applies EXE flags.',
    gradient: 'from-amber-900 via-yellow-950 to-black',
    letter: 'CS2',
    risk: 'safe',
    requiresReboot: false,
    script: '05_CS2_Settings.ps1',
    pathEnvVar: undefined,
    steamFolders: ['Counter-Strike Global Offensive'],
    checkLabels: {},
    defaultEnabled: true,
  },
  {
    id: 'apexlegends',
    name: 'Apex Legends',
    subtitle: 'Max FPS Config + Read-Only Lock',
    description: 'Writes max-FPS videoconfig.txt, locks it read-only, creates autoexec.cfg, and applies r5apex.exe EXE flags.',
    gradient: 'from-red-900 via-orange-950 to-black',
    letter: 'APX',
    risk: 'safe',
    requiresReboot: false,
    script: '12_ApexLegends_Settings.ps1',
    pathEnvVar: 'APEX_PATH',
    steamFolders: ['Apex Legends'],
    checkLabels: {
      APEX_VIDEOCONFIG_WRITTEN: 'Apex videoconfig.txt written',
      APEX_VIDEOCONFIG_READONLY: 'Apex videoconfig.txt read-only lock',
      APEX_AUTOEXEC_WRITTEN: 'Apex autoexec.cfg written',
      APEX_EXE_FLAGS: 'Apex r5apex.exe compatibility flags',
    },
    defaultEnabled: true,
  },
  {
    id: 'arcraiders',
    name: 'Arc Raiders',
    subtitle: 'DLSS Quality · Shadows Medium',
    description: 'Optimizes Engine.ini — Shadows MEDIUM minimum (player shadows), DLSS/FSR Quality, Frame Gen OFF.',
    gradient: 'from-cyan-900 via-teal-950 to-black',
    letter: 'ARC',
    risk: 'safe',
    requiresReboot: false,
    script: '06_ArcRaiders_Settings.ps1',
    pathEnvVar: 'ARC_RAIDERS_PATH',
    steamFolders: ['ArcRaiders', 'Arc Raiders'],
    checkLabels: {
      ARC_EXE_FLAGS: 'Arc Raiders EXE compatibility flags',
      ARC_CONFIG_FILES_WRITTEN: 'Arc Raiders config files written',
      ARC_SETTINGS_APPLIED: 'Arc Raiders settings applied',
    },
    defaultEnabled: true,
  },
  {
    id: 'tarkov',
    name: 'Escape from Tarkov',
    subtitle: 'Graphics.ini + PostFX Guide',
    description: 'Writes optimized Graphics.ini (read-only lock), applies EXE flags. PostFX must be set in-game.',
    gradient: 'from-stone-800 via-zinc-900 to-black',
    letter: 'EFT',
    risk: 'safe',
    requiresReboot: false,
    script: '14_Tarkov_Settings.ps1',
    pathEnvVar: 'TARKOV_PATH',
    steamFolders: [],
    checkLabels: {
      TARKOV_EXE_FLAGS: 'Tarkov EXE compatibility flags',
      TARKOV_CONFIG_WRITTEN: 'Tarkov Graphics.ini written',
      TARKOV_SETTINGS_APPLIED: 'Tarkov settings applied',
    },
    defaultEnabled: true,
  },
  {
    id: 'rust',
    name: 'Rust',
    subtitle: 'Max FPS Config + GC Tuning',
    description: 'Writes competitive client.cfg with max FPS settings, GC tuning, and read-only lock.',
    gradient: 'from-orange-800 via-amber-950 to-black',
    letter: 'RST',
    risk: 'safe',
    requiresReboot: false,
    script: '15_Rust_Settings.ps1',
    pathEnvVar: 'RUST_PATH',
    steamFolders: ['Rust'],
    checkLabels: {
      RUST_EXE_FLAGS: 'Rust EXE compatibility flags',
      RUST_CONFIG_WRITTEN: 'Rust client.cfg written',
      RUST_SETTINGS_APPLIED: 'Rust settings applied',
    },
    defaultEnabled: true,
  },
  {
    id: 'r6siege',
    name: 'Rainbow Six Siege',
    subtitle: 'Vulkan · Low Shadows · Reflex',
    description: 'Optimizes GameSettings.ini — Low shadows, TAA, Reflex On+Boost. Vulkan renderer recommended.',
    gradient: 'from-indigo-900 via-blue-950 to-black',
    letter: 'R6',
    risk: 'safe',
    requiresReboot: false,
    script: '16_RainbowSixSiege_Settings.ps1',
    pathEnvVar: 'R6_PATH',
    steamFolders: ["Tom Clancy's Rainbow Six Siege"],
    checkLabels: {
      R6_EXE_FLAGS: 'R6 Siege EXE compatibility flags',
      R6_CONFIG_WRITTEN: 'R6 Siege GameSettings.ini written',
      R6_SETTINGS_APPLIED: 'R6 Siege settings applied',
    },
    defaultEnabled: true,
  },
  {
    id: 'bf6',
    name: 'Battlefield 6',
    subtitle: 'PROFSAVE · FFR On · Reflex On+Boost',
    description: 'Optimizes PROFSAVE_profile — Low shadows/effects, FFR On, Reflex On+Boost, all visual clutter off.',
    gradient: 'from-emerald-900 via-green-950 to-black',
    letter: 'BF6',
    risk: 'safe',
    requiresReboot: false,
    script: '17_Battlefield6_Settings.ps1',
    pathEnvVar: 'BF6_PATH',
    steamFolders: ['Battlefield 6'],
    checkLabels: {
      BF6_EXE_FLAGS: 'Battlefield 6 EXE compatibility flags',
      BF6_CONFIG_WRITTEN: 'Battlefield 6 PROFSAVE_profile written',
    },
    defaultEnabled: true,
  },
  {
    id: 'marvelrivals',
    name: 'Marvel Rivals',
    subtitle: 'All Low · DLSS/FSR Quality · Clutter Off',
    description: 'Optimizes GameUserSettings.ini and Engine.ini -- All Low quality, DLSS/FSR Quality, visual clutter off, NVIDIA Reflex On.',
    gradient: 'from-purple-900 via-fuchsia-950 to-black',
    letter: 'MR',
    risk: 'safe',
    requiresReboot: false,
    script: '18_MarvelRivals_Settings.ps1',
    pathEnvVar: 'MARVEL_RIVALS_PATH',
    steamFolders: ['MarvelRivals'],
    checkLabels: {
      MR_EXE_FLAGS: 'Marvel Rivals EXE compatibility flags',
      MR_CONFIG_WRITTEN: 'Marvel Rivals config files written',
      MR_SETTINGS_APPLIED: 'Marvel Rivals settings applied',
    },
    defaultEnabled: true,
  },
  {
    id: 'lol',
    name: 'League of Legends',
    subtitle: 'All Low · Shadows Off · Uncapped FPS',
    description: 'Optimizes game.cfg -- Shadows off, all Low quality, uncapped FPS, particle budget tuning. Read-only lock prevents overwrite.',
    gradient: 'from-yellow-900 via-amber-950 to-black',
    letter: 'LoL',
    risk: 'safe',
    requiresReboot: false,
    script: '19_LeagueOfLegends_Settings.ps1',
    pathEnvVar: 'LOL_PATH',
    steamFolders: [],
    checkLabels: {
      LOL_EXE_FLAGS: 'League of Legends EXE compatibility flags',
      LOL_CONFIG_WRITTEN: 'League of Legends game.cfg written',
    },
    defaultEnabled: true,
  },
  {
    id: 'dota2',
    name: 'Dota 2',
    subtitle: 'All Low · Autoexec + Launch Options',
    description: 'Writes optimized video.txt and autoexec.cfg -- All Low quality, uncapped FPS, competitive network settings, launch options.',
    gradient: 'from-red-800 via-rose-950 to-black',
    letter: 'D2',
    risk: 'safe',
    requiresReboot: false,
    script: '20_Dota2_Settings.ps1',
    pathEnvVar: 'DOTA2_PATH',
    steamFolders: ['dota 2 beta'],
    checkLabels: {
      DOTA2_EXE_FLAGS: 'Dota 2 EXE compatibility flags',
      DOTA2_CONFIG_WRITTEN: 'Dota 2 video.txt written',
      DOTA2_AUTOEXEC_WRITTEN: 'Dota 2 autoexec.cfg written',
      DOTA2_LAUNCH_OPTIONS: 'Dota 2 Steam launch options set',
    },
    defaultEnabled: true,
  },
  {
    id: 'eafc26',
    name: 'EA Sports FC 26',
    cardName: 'EA FC 26',
    subtitle: 'Medium Quality · VSync Off · Uncapped FPS',
    description: 'Optimizes fcsetup.ini -- Medium rendering, AO Low, Strand Hair Off, VSync Off, uncapped FPS. Read-only lock prevents overwrite.',
    gradient: 'from-green-900 via-emerald-950 to-black',
    letter: 'FC',
    risk: 'safe',
    requiresReboot: false,
    script: '24_EAFC26_Settings.ps1',
    pathEnvVar: 'EAFC26_PATH',
    steamFolders: ['FC 26'],
    checkLabels: {
      EAFC26_EXE_FLAGS: 'EA FC 26 EXE compatibility flags',
      EAFC26_CONFIG_WRITTEN: 'EA FC 26 fcsetup.ini written',
    },
    defaultEnabled: true,
  },
];
