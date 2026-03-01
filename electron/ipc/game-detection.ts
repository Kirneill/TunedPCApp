import * as fs from 'fs';
import * as path from 'path';
import { runPowerShellCommand } from './powershell';

export interface DetectedGame {
  id: string;
  name: string;
  installed: boolean;
  path?: string;
}

const GAMES = [
  { id: 'blackops7', name: 'Call of Duty: Black Ops 7', scriptId: '02' },
  { id: 'fortnite', name: 'Fortnite', scriptId: '03' },
  { id: 'valorant', name: 'Valorant', scriptId: '04' },
  { id: 'cs2', name: 'Counter-Strike 2', scriptId: '05' },
  { id: 'apexlegends', name: 'Apex Legends', scriptId: '12' },
  { id: 'arcraiders', name: 'Arc Raiders', scriptId: '06' },
];

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
  } catch {
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
        if (!matchers.some((matcher) => matcher.test(content))) continue;
        const locationMatch = content.match(/"InstallLocation"\s*:\s*"([^"]+)"/);
        if (locationMatch) {
          return locationMatch[1].replace(/\\\\/g, '\\');
        }
      }
    }
  } catch {}

  return null;
}

async function findSteamGames(): Promise<Map<string, string>> {
  const found = new Map<string, string>();

  // CS2 appid = 730, Apex Legends appid = 1172470
  const steamPaths = [
    'C:\\Program Files (x86)\\Steam',
    'C:\\Program Files\\Steam',
    'D:\\Steam',
    'D:\\SteamLibrary',
    'E:\\Steam',
    'E:\\SteamLibrary',
  ];

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
            // Check for CS2
            const cs2Path = path.join(libPath, 'steamapps', 'common', 'Counter-Strike Global Offensive');
            if (fs.existsSync(cs2Path)) {
              found.set('cs2', cs2Path);
            }
            const apexPath = path.join(libPath, 'steamapps', 'common', 'Apex Legends');
            if (fs.existsSync(apexPath)) {
              found.set('apexlegends', apexPath);
            }
          }
        }
      } catch {}
    }

    // Direct check
    const cs2Direct = path.join(steamPath, 'steamapps', 'common', 'Counter-Strike Global Offensive');
    if (fs.existsSync(cs2Direct)) {
      found.set('cs2', cs2Direct);
    }
    const apexDirect = path.join(steamPath, 'steamapps', 'common', 'Apex Legends');
    if (fs.existsSync(apexDirect)) {
      found.set('apexlegends', apexDirect);
    }
  }

  return found;
}

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
    } catch {}
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

interface ArcRaidersResult {
  installed: boolean;
  gamePath: string | null;
}

async function findArcRaiders(): Promise<ArcRaidersResult> {
  // Priority 1: Actual game installation directories (safe to pass as ARC_RAIDERS_PATH)
  const epicInstall = findEpicInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (epicInstall) return { installed: true, gamePath: epicInstall };

  const manifestInstall = findEpicManifestInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (manifestInstall) return { installed: true, gamePath: manifestInstall };

  const commonInstallPaths = [
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\ArcRaiders',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Arc Raiders',
    'C:\\Steam\\steamapps\\common\\ArcRaiders',
    'C:\\Steam\\steamapps\\common\\Arc Raiders',
    'C:\\SteamLibrary\\steamapps\\common\\ArcRaiders',
    'C:\\SteamLibrary\\steamapps\\common\\Arc Raiders',
    'D:\\Steam\\steamapps\\common\\ArcRaiders',
    'D:\\Steam\\steamapps\\common\\Arc Raiders',
    'D:\\SteamLibrary\\steamapps\\common\\ArcRaiders',
    'D:\\SteamLibrary\\steamapps\\common\\Arc Raiders',
    'E:\\Steam\\steamapps\\common\\ArcRaiders',
    'E:\\Steam\\steamapps\\common\\Arc Raiders',
    'E:\\SteamLibrary\\steamapps\\common\\ArcRaiders',
    'E:\\SteamLibrary\\steamapps\\common\\Arc Raiders',
    'C:\\Program Files\\Epic Games\\ArcRaiders',
    'D:\\Epic Games\\ArcRaiders',
    'E:\\Epic Games\\ArcRaiders',
  ];
  const commonInstall = firstExistingPath(commonInstallPaths);
  if (commonInstall) return { installed: true, gamePath: commonInstall };

  // Priority 2: Config folder existence proves the game is installed,
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

async function findApexLegends(steamGames: Map<string, string>): Promise<string | null> {
  const steamPath = steamGames.get('apexlegends');
  if (steamPath) return steamPath;

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
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Apex Legends',
    'C:\\Program Files\\Steam\\steamapps\\common\\Apex Legends',
    'D:\\Steam\\steamapps\\common\\Apex Legends',
    'D:\\SteamLibrary\\steamapps\\common\\Apex Legends',
    'E:\\Steam\\steamapps\\common\\Apex Legends',
    'E:\\SteamLibrary\\steamapps\\common\\Apex Legends',
    'C:\\Program Files\\EA Games\\Apex Legends',
    'D:\\EA Games\\Apex Legends',
    'E:\\EA Games\\Apex Legends',
    'C:\\Program Files (x86)\\Origin Games\\Apex',
    'D:\\Origin Games\\Apex',
    'E:\\Origin Games\\Apex',
  ];
  return firstExistingPath(commonInstallPaths);
}

export async function detectInstalledGames(): Promise<DetectedGame[]> {
  const [steamGames, fortnitePath, valorantPath, bo7Path, arcResult] = await Promise.all([
    findSteamGames(),
    findFortnite(),
    findValorant(),
    findBlackOps7(),
    findArcRaiders(),
  ]);
  const apexPath = await findApexLegends(steamGames);

  return GAMES.map((game) => {
    let installed = false;
    let gamePath: string | undefined;

    switch (game.id) {
      case 'cs2':
        installed = steamGames.has('cs2');
        gamePath = steamGames.get('cs2');
        break;
      case 'fortnite':
        installed = !!fortnitePath;
        gamePath = fortnitePath || undefined;
        break;
      case 'valorant':
        installed = !!valorantPath;
        gamePath = valorantPath || undefined;
        break;
      case 'blackops7':
        installed = !!bo7Path;
        gamePath = bo7Path || undefined;
        break;
      case 'apexlegends':
        installed = !!apexPath;
        gamePath = apexPath || undefined;
        break;
      case 'arcraiders':
        installed = arcResult.installed;
        gamePath = arcResult.gamePath || undefined;
        break;
    }

    return { id: game.id, name: game.name, installed, path: gamePath };
  });
}
