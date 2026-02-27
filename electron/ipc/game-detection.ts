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

  // CS2 appid = 730
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
          }
        }
      } catch {}
    }

    // Direct check
    const cs2Direct = path.join(steamPath, 'steamapps', 'common', 'Counter-Strike Global Offensive');
    if (fs.existsSync(cs2Direct)) {
      found.set('cs2', cs2Direct);
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
  // Check registry for Battle.net
  const result = await runPowerShellCommand(
    `(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\WOW6432Node\\Blizzard Entertainment\\Battle.net\\Games\\call_of_duty_bops7' -ErrorAction SilentlyContinue).InstallPath`
  );
  if (result.success && result.output.length > 0 && result.output[0]) {
    return result.output[0];
  }

  // Check common paths
  const commonPaths = [
    'C:\\Program Files (x86)\\Call of Duty',
    'D:\\Call of Duty',
    'C:\\Games\\Call of Duty',
  ];
  for (const p of commonPaths) {
    if (fs.existsSync(p)) return p;
  }

  return null;
}

async function findArcRaiders(): Promise<string | null> {
  const localAppData = process.env.LOCALAPPDATA || '';
  if (localAppData) {
    const configCandidates = [
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'Windows'),
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'WindowsClient'),
      path.join(localAppData, 'ArcRaiders', 'Saved', 'Config', 'WinGDK'),
    ];
    const configPath = firstExistingPath(configCandidates);
    if (configPath) return configPath;
  }

  const epicInstall = findEpicInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (epicInstall) return epicInstall;

  const manifestInstall = findEpicManifestInstallPath([/arc\s*raiders/i, /arcraiders/i]);
  if (manifestInstall) return manifestInstall;

  const commonInstallPaths = [
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\ArcRaiders',
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Arc Raiders',
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
  if (commonInstall) return commonInstall;

  return null;
}

export async function detectInstalledGames(): Promise<DetectedGame[]> {
  const [steamGames, fortnitePath, valorantPath, bo7Path, arcPath] = await Promise.all([
    findSteamGames(),
    findFortnite(),
    findValorant(),
    findBlackOps7(),
    findArcRaiders(),
  ]);

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
      case 'arcraiders':
        installed = !!arcPath;
        gamePath = arcPath || undefined;
        break;
    }

    return { id: game.id, name: game.name, installed, path: gamePath };
  });
}
