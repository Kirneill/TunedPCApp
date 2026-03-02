import * as fs from 'fs';
import * as path from 'path';
import { runPowerShellCommand } from './powershell';
export type { DetectedGame } from '../../src/types/index';
import type { DetectedGame } from '../../src/types/index';

// ---------------------------------------------------------------------------
// Unified game registry — the SINGLE source of truth for game detection.
//
// To add a new game:
//   1. Add an entry to GAME_REGISTRY below.
//      - If on Steam, populate steamFolders with the folder name(s) under
//        steamapps/common/. VDF detection handles the rest automatically.
//      - If non-Steam detection is needed (Epic, registry, etc.), write a
//        findX() function and assign it to the detect property.
//   2. No other wiring needed — the pipeline handles VDF lookup, custom
//      detection, and result mapping automatically.
// ---------------------------------------------------------------------------

interface GameDetectionResult {
  installed: boolean;
  gamePath: string | null;
}

interface GameRegistryEntry {
  id: string;
  name: string;
  /** Steam folder names to search via VDF. Empty array = not on Steam. */
  steamFolders: string[];
  /**
   * Custom detection beyond Steam VDF.
   * Only called if VDF didn't find the game. Return:
   *   - a path string if the install directory was found
   *   - null if the game is not installed
   *   - GameDetectionResult for cases where installation is confirmed
   *     but no game root path is available (e.g., only config files found)
   */
  detect?: () => Promise<string | null | GameDetectionResult>;
}

const GAME_REGISTRY: GameRegistryEntry[] = [
  {
    id: 'blackops7', name: 'Call of Duty: Black Ops 7',
    steamFolders: [],
    detect: findBlackOps7,
  },
  {
    id: 'fortnite', name: 'Fortnite',
    steamFolders: [],
    detect: findFortnite,
  },
  {
    id: 'valorant', name: 'Valorant',
    steamFolders: [],
    detect: findValorant,
  },
  {
    id: 'cs2', name: 'Counter-Strike 2',
    steamFolders: ['Counter-Strike Global Offensive'],
  },
  {
    id: 'apexlegends', name: 'Apex Legends',
    steamFolders: ['Apex Legends'],
    detect: findApexLegends,
  },
  {
    id: 'arcraiders', name: 'Arc Raiders',
    steamFolders: ['ArcRaiders', 'Arc Raiders'],
    detect: findArcRaiders,
  },
  {
    id: 'tarkov', name: 'Escape from Tarkov',
    steamFolders: [],
    detect: findTarkov,
  },
  {
    id: 'rust', name: 'Rust',
    steamFolders: ['Rust'],
    detect: findRust,
  },
  {
    id: 'r6siege', name: 'Rainbow Six Siege',
    steamFolders: ["Tom Clancy's Rainbow Six Siege"],
    detect: findR6Siege,
  },
];

// ---------------------------------------------------------------------------
// Helper utilities
// ---------------------------------------------------------------------------

interface EpicInstallation {
  AppName?: string;
  DisplayName?: string;
  InstallLocation?: string;
}

function firstExistingPath(paths: string[]): string | null {
  for (const p of paths) {
    if (fs.existsSync(p)) {
      return p;
    }
  }
  return null;
}

function readEpicLauncherInstallations(): EpicInstallation[] {
  const launcherInstalledPath = 'C:\\ProgramData\\Epic\\UnrealEngineLauncher\\LauncherInstalled.dat';
  if (!fs.existsSync(launcherInstalledPath)) return [];

  try {
    const raw = fs.readFileSync(launcherInstalledPath, 'utf-8');
    const parsed = JSON.parse(raw) as { InstallationList?: EpicInstallation[] };
    return Array.isArray(parsed.InstallationList) ? parsed.InstallationList : [];
  } catch (err) {
    console.warn(`[game-detection] Failed to read Epic launcher installations: ${err instanceof Error ? err.message : err}`);
    return [];
  }
}

function findEpicInstallPath(matchers: RegExp[]): string | null {
  const installations = readEpicLauncherInstallations();
  for (const install of installations) {
    const appName = install.AppName || '';
    const displayName = install.DisplayName || '';
    const installLocation = install.InstallLocation || '';

    if (!installLocation) continue;
    if (matchers.some((matcher) => matcher.test(appName) || matcher.test(displayName))) {
      return installLocation;
    }
  }
  return null;
}

function findEpicManifestInstallPath(matchers: RegExp[]): string | null {
  const manifestDir = 'C:\\ProgramData\\Epic\\EpicGamesLauncher\\Data\\Manifests';
  if (!fs.existsSync(manifestDir)) return null;

  try {
    const files = fs.readdirSync(manifestDir).filter((f) => f.endsWith('.item'));
    for (const file of files) {
      const fullPath = path.join(manifestDir, file);
      const content = fs.readFileSync(fullPath, 'utf-8');

      try {
        const parsed = JSON.parse(content) as {
          DisplayName?: string;
          AppName?: string;
          InstallLocation?: string;
        };
        const name = `${parsed.DisplayName || ''} ${parsed.AppName || ''}`;
        if (matchers.some((matcher) => matcher.test(name)) && parsed.InstallLocation) {
          return parsed.InstallLocation;
        }
      } catch {
        // JSON parse failed — fall through to regex fallback below
        if (!matchers.some((matcher) => matcher.test(content))) continue;
        const locationMatch = content.match(/"InstallLocation"\s*:\s*"([^"]+)"/);
        if (locationMatch) {
          return locationMatch[1].replace(/\\\\/g, '\\');
        }
      }
    }
  } catch (err) {
    console.warn(`[game-detection] Failed to read Epic manifest directory: ${err instanceof Error ? err.message : err}`);
  }

  return null;
}

// ---------------------------------------------------------------------------
// Steam VDF detection — folder list is derived from GAME_REGISTRY
// ---------------------------------------------------------------------------

async function findSteamGames(): Promise<Map<string, string>> {
  const found = new Map<string, string>();

  const steamPaths = [
    'C:\\Program Files (x86)\\Steam',
    'C:\\Program Files\\Steam',
    'D:\\Steam',
    'D:\\SteamLibrary',
    'E:\\Steam',
    'E:\\SteamLibrary',
  ];

  // Derived from the registry — no separate list to keep in sync
  const steamGameDirs = GAME_REGISTRY.flatMap((game) =>
    game.steamFolders.map((folder) => ({ id: game.id, folder }))
  );

  for (const steamPath of steamPaths) {
    const vdfPath = path.join(steamPath, 'steamapps', 'libraryfolders.vdf');
    if (fs.existsSync(vdfPath)) {
      try {
        const content = fs.readFileSync(vdfPath, 'utf-8');
        // Extract library paths from VDF
        const pathMatches = content.match(/"path"\s+"([^"]+)"/g);
        if (pathMatches) {
          for (const match of pathMatches) {
            const libPath = match.replace(/"path"\s+"/, '').replace(/"$/, '').replace(/\\\\/g, '\\');
            for (const game of steamGameDirs) {
              const gamePath = path.join(libPath, 'steamapps', 'common', game.folder);
              if (fs.existsSync(gamePath)) {
                found.set(game.id, gamePath);
              }
            }
          }
        }
      } catch (err) {
        console.warn(`[game-detection] Failed to parse Steam VDF: ${err instanceof Error ? err.message : err}`);
      }
    }

    // Fallback: check base Steam install directly (VDF may not list it as a library)
    for (const game of steamGameDirs) {
      const directPath = path.join(steamPath, 'steamapps', 'common', game.folder);
      if (fs.existsSync(directPath)) {
        found.set(game.id, directPath);
      }
    }
  }

  return found;
}

// ---------------------------------------------------------------------------
// Per-game custom detection functions
// Called only if Steam VDF detection didn't find the game.
// Steam common/ paths are NOT duplicated here — VDF handles them via steamFolders.
// ---------------------------------------------------------------------------

async function findFortnite(): Promise<string | null> {
  const localAppData = process.env.LOCALAPPDATA || '';
  if (localAppData) {
    const configCandidates = [
      path.join(localAppData, 'FortniteGame', 'Saved', 'Config', 'WindowsClient'),
      path.join(localAppData, 'FortniteGame', 'Saved', 'Config', 'Windows'),
    ];
    const configPath = firstExistingPath(configCandidates);
    if (configPath) return configPath;
  }

  const epicInstall = findEpicInstallPath([/fortnite/i]);
  if (epicInstall) return epicInstall;

  const manifestInstall = findEpicManifestInstallPath([/fortnite/i]);
  if (manifestInstall) return manifestInstall;

  const commonInstallPaths = [
    'C:\\Program Files\\Epic Games\\Fortnite',
    'D:\\Epic Games\\Fortnite',
    'E:\\Epic Games\\Fortnite',
    'C:\\Games\\Fortnite',
  ];
  const commonInstall = firstExistingPath(commonInstallPaths);
  if (commonInstall) return commonInstall;

  return null;
}

async function findValorant(): Promise<string | null> {
  // Check for config file
  const configPath = path.join(
    process.env.LOCALAPPDATA || '',
    'VALORANT', 'Saved', 'Config'
  );
  if (fs.existsSync(configPath)) return configPath;

  // Check Riot install
  const riotPaths = ['C:\\Riot Games\\VALORANT', 'D:\\Riot Games\\VALORANT'];
  for (const p of riotPaths) {
    if (fs.existsSync(p)) return p;
  }

  // Registry check
  const result = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKCU:\\Software\\Riot Games\\VALORANT' -ErrorAction SilentlyContinue).product_install_full_path`
  );
  if (result.success && result.output.length > 0 && result.output[0]) {
    return result.output[0];
  }

  return null;
}

async function findBlackOps7(): Promise<string | null> {
  // Check Battle.net registry variants
  const registryQueries = [
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Blizzard Entertainment\\Battle.net\\Games\\call_of_duty_bops7' -ErrorAction SilentlyContinue).InstallPath`,
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Blizzard Entertainment\\Battle.net\\Games\\call_of_duty' -ErrorAction SilentlyContinue).InstallPath`,
  ];
  for (const query of registryQueries) {
    const result = await runPowerShellCommand(query);
    if (result.success && result.output.length > 0 && result.output[0]) {
      return result.output[0];
    }
  }

  // Check direct executable paths across Battle.net/Steam/Game Pass layouts
  const exeCandidates = [
    'C:\\Program Files (x86)\\Call of Duty\\_retail_\\cod.exe',
    'C:\\Program Files (x86)\\Call of Duty\\_retail_\\cod24\\cod24-cod.exe',
    'C:\\Program Files (x86)\\Call of Duty\\_retail_\\cod25\\cod25-cod.exe',
    'C:\\Program Files\\Call of Duty\\_retail_\\cod.exe',
    'D:\\Call of Duty\\_retail_\\cod.exe',
    'E:\\Call of Duty\\_retail_\\cod.exe',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty HQ\\cod.exe',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty HQ\\cod24\\cod24-cod.exe',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty HQ\\cod25\\cod25-cod.exe',
    'D:\\Steam\\steamapps\\common\\Call of Duty HQ\\cod.exe',
    'D:\\SteamLibrary\\steamapps\\common\\Call of Duty HQ\\cod.exe',
    'E:\\Steam\\steamapps\\common\\Call of Duty HQ\\cod.exe',
    'E:\\SteamLibrary\\steamapps\\common\\Call of Duty HQ\\cod.exe',
    'C:\\XboxGames\\Call of Duty\\Content\\cod.exe',
    'C:\\XboxGames\\Call of Duty_1\\Content\\cod.exe',
    'C:\\XboxGames\\Call of Duty\\Content\\cod24\\cod24-cod.exe',
    'C:\\XboxGames\\Call of Duty_1\\Content\\cod24\\cod24-cod.exe',
    'C:\\XboxGames\\Call of Duty\\Content\\cod25\\cod25-cod.exe',
    'C:\\XboxGames\\Call of Duty_1\\Content\\cod25\\cod25-cod.exe',
    'D:\\XboxGames\\Call of Duty\\Content\\cod.exe',
    'D:\\XboxGames\\Call of Duty_1\\Content\\cod.exe',
    'E:\\XboxGames\\Call of Duty\\Content\\cod.exe',
    'E:\\XboxGames\\Call of Duty_1\\Content\\cod.exe',
  ];
  for (const exePath of exeCandidates) {
    if (fs.existsSync(exePath)) return path.dirname(exePath);
  }

  // Dynamic Xbox Game Pass scan for "Call of Duty*" installs
  const xboxRoots = ['C:\\XboxGames', 'D:\\XboxGames', 'E:\\XboxGames'];
  for (const root of xboxRoots) {
    if (!fs.existsSync(root)) continue;
    try {
      const installDirs = fs.readdirSync(root, { withFileTypes: true })
        .filter((d) => d.isDirectory() && /^Call of Duty/i.test(d.name))
        .map((d) => path.join(root, d.name));

      for (const installDir of installDirs) {
        const dynamicCandidates = [
          path.join(installDir, 'Content', 'cod.exe'),
          path.join(installDir, 'Content', 'cod24', 'cod24-cod.exe'),
          path.join(installDir, 'Content', 'cod25', 'cod25-cod.exe'),
          path.join(installDir, 'Content', '_retail_', 'cod.exe'),
          path.join(installDir, 'Content', '_retail_', 'cod24', 'cod24-cod.exe'),
          path.join(installDir, 'Content', '_retail_', 'cod25', 'cod25-cod.exe'),
        ];
        const hit = firstExistingPath(dynamicCandidates);
        if (hit) return path.dirname(hit);
      }
    } catch (err) {
      console.warn(`[game-detection] Failed to scan Xbox games directory: ${err instanceof Error ? err.message : err}`);
    }
  }

  // Fallback root checks
  const commonRoots = [
    'C:\\Program Files (x86)\\Call of Duty',
    'C:\\Program Files\\Call of Duty',
    'D:\\Call of Duty',
    'E:\\Call of Duty',
    'C:\\Games\\Call of Duty',
  ];
  const fallback = firstExistingPath(commonRoots);
  return fallback || null;
}

async function findArcRaiders(): Promise<GameDetectionResult> {
  // Epic launcher
  const epicInstall = findEpicInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (epicInstall) return { installed: true, gamePath: epicInstall };

  const manifestInstall = findEpicManifestInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (manifestInstall) return { installed: true, gamePath: manifestInstall };

  // Hardcoded fallback paths (Epic installs not covered by manifest)
  const commonInstallPaths = [
    'C:\\Program Files\\Epic Games\\ArcRaiders',
    'D:\\Epic Games\\ArcRaiders',
    'E:\\Epic Games\\ArcRaiders',
  ];
  const commonInstall = firstExistingPath(commonInstallPaths);
  if (commonInstall) return { installed: true, gamePath: commonInstall };

  // Config folder existence proves the game is installed,
  // but config paths must NOT be passed as ARC_RAIDERS_PATH (the PS1
  // script expects a game root dir and would construct invalid exe paths).
  // The PS1 script has its own independent config folder detection.
  const localAppData = process.env.LOCALAPPDATA || '';
  if (localAppData) {
    const configCandidates = [
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'Windows'),
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'WindowsClient'),
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'WinGDK'),
    ];
    const configPath = firstExistingPath(configCandidates);
    if (configPath) {
      console.log(`[game-detection] Arc Raiders config found at ${configPath} but no install directory located. PS1 script will use its own detection.`);
      return { installed: true, gamePath: null };
    }
  }

  return { installed: false, gamePath: null };
}

async function findApexLegends(): Promise<string | null> {
  const registryQueries = [
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Respawn\\Apex' -ErrorAction SilentlyContinue).'Install Dir'`,
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Respawn\\Apex' -ErrorAction SilentlyContinue).InstallDir`,
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Respawn\\Apex' -ErrorAction SilentlyContinue).'Install Dir'`,
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Respawn\\Apex' -ErrorAction SilentlyContinue).InstallDir`,
  ];
  for (const query of registryQueries) {
    const result = await runPowerShellCommand(query);
    if (result.success && result.output.length > 0 && result.output[0] && fs.existsSync(result.output[0])) {
      return result.output[0];
    }
  }

  const commonInstallPaths = [
    'C:\\Program Files\\EA Games\\Apex Legends',
    'D:\\EA Games\\Apex Legends',
    'E:\\EA Games\\Apex Legends',
    'C:\\Program Files (x86)\\Origin Games\\Apex',
    'D:\\Origin Games\\Apex',
    'E:\\Origin Games\\Apex',
  ];
  return firstExistingPath(commonInstallPaths);
}

async function findTarkov(): Promise<GameDetectionResult> {
  // Registry: BSG uninstall key
  const result = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EscapeFromTarkov' -ErrorAction SilentlyContinue).InstallLocation`
  );
  if (result.success && result.output.length > 0 && result.output[0] && fs.existsSync(result.output[0])) {
    return { installed: true, gamePath: result.output[0] };
  }

  // Common install paths
  const commonPaths = [
    'C:\\Battlestate Games\\EFT',
    'D:\\Battlestate Games\\EFT',
    'E:\\Battlestate Games\\EFT',
    'C:\\Games\\Battlestate Games\\EFT',
    'D:\\Games\\Battlestate Games\\EFT',
  ];
  const commonInstall = firstExistingPath(commonPaths);
  if (commonInstall) return { installed: true, gamePath: commonInstall };

  // Config folder proves installation but is NOT a valid game path
  // (PS1 script has its own config folder detection)
  const appData = process.env.APPDATA || '';
  if (appData) {
    const settingsDir = path.join(appData, 'Battlestate Games', 'Escape from Tarkov', 'Settings');
    if (fs.existsSync(settingsDir)) {
      console.log(`[game-detection] Tarkov config found at ${settingsDir} but no install directory located. PS1 script will use its own detection.`);
      return { installed: true, gamePath: null };
    }
  }

  return { installed: false, gamePath: null };
}

async function findRust(): Promise<string | null> {
  // Uninstall registry (Steam App 252490)
  const result = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Steam App 252490' -ErrorAction SilentlyContinue).InstallLocation`
  );
  if (result.success && result.output.length > 0 && result.output[0] && fs.existsSync(result.output[0])) {
    return result.output[0];
  }

  return null;
}

async function findR6Siege(): Promise<GameDetectionResult> {
  // Uninstall registry (Steam App 359550)
  const result = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Steam App 359550' -ErrorAction SilentlyContinue).InstallLocation`
  );
  if (result.success && result.output.length > 0 && result.output[0] && fs.existsSync(result.output[0])) {
    return { installed: true, gamePath: result.output[0] };
  }

  // Ubisoft Connect registry
  const ubisoftResult = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Ubisoft\\Launcher' -ErrorAction SilentlyContinue).InstallDir`
  );
  if (ubisoftResult.success && ubisoftResult.output.length > 0 && ubisoftResult.output[0]) {
    const ubisoftR6 = path.join(ubisoftResult.output[0], 'games', "Tom Clancy's Rainbow Six Siege");
    if (fs.existsSync(ubisoftR6)) return { installed: true, gamePath: ubisoftR6 };
  }

  // Config folder detection (proves game is installed but is NOT a valid game path)
  // The PS1 script has its own config folder detection.
  const userProfile = process.env.USERPROFILE || '';
  if (!userProfile) {
    console.warn('[game-detection] USERPROFILE env var is empty, skipping R6 Siege config detection');
  }
  const docsBase = userProfile ? path.join(userProfile, 'Documents', 'My Games', 'Rainbow Six - Siege') : '';
  if (docsBase && fs.existsSync(docsBase)) {
    try {
      const accountFolders = fs.readdirSync(docsBase, { withFileTypes: true })
        .filter((d) => d.isDirectory());
      for (const folder of accountFolders) {
        const settingsFile = path.join(docsBase, folder.name, 'GameSettings.ini');
        if (fs.existsSync(settingsFile)) {
          console.log(`[game-detection] R6 Siege config found at ${docsBase} but no install directory located. PS1 script will use its own detection.`);
          return { installed: true, gamePath: null };
        }
      }
    } catch (err) {
      console.warn(`[game-detection] Failed to scan R6 Siege config: ${err instanceof Error ? err.message : err}`);
    }
  }

  // Common install paths
  const commonPaths = [
    "C:\\Program Files (x86)\\Ubisoft\\Ubisoft Game Launcher\\games\\Tom Clancy's Rainbow Six Siege",
  ];
  const commonInstall = firstExistingPath(commonPaths);
  if (commonInstall) return { installed: true, gamePath: commonInstall };

  return { installed: false, gamePath: null };
}

// ---------------------------------------------------------------------------
// Detection pipeline — data-driven from GAME_REGISTRY
// ---------------------------------------------------------------------------

function isGameDetectionResult(value: unknown): value is GameDetectionResult {
  return typeof value === 'object' && value !== null
    && 'installed' in value && typeof (value as GameDetectionResult).installed === 'boolean';
}

export async function detectInstalledGames(): Promise<DetectedGame[]> {
  // Step 1: Resolve all Steam library folders via VDF (must complete first —
  // per-game checks use Map.get on this result)
  const steamGames = await findSteamGames().catch((err) => {
    console.warn(`[game-detection] Steam library detection failed: ${err instanceof Error ? err.message : err}`);
    return new Map<string, string>();
  });

  // Step 2: For each game, check Steam VDF first, then custom detection
  return Promise.all(
    GAME_REGISTRY.map(async (entry): Promise<DetectedGame> => {
      // Steam VDF hit — already resolved, no async needed
      const steamPath = steamGames.get(entry.id);
      if (steamPath) {
        return { id: entry.id, name: entry.name, installed: true, path: steamPath };
      }

      // Custom detection fallback
      if (entry.detect) {
        try {
          const result = await entry.detect();
          if (isGameDetectionResult(result)) {
            return { id: entry.id, name: entry.name, installed: result.installed, path: result.gamePath || undefined };
          }
          if (typeof result === 'string') {
            return { id: entry.id, name: entry.name, installed: true, path: result };
          }
        } catch (err) {
          console.warn(`[game-detection] ${entry.name} detection failed: ${err instanceof Error ? err.message : err}`);
        }
      }

      return { id: entry.id, name: entry.name, installed: false, path: undefined };
    })
  );
}
