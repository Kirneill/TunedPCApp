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
  const configPath = path.join(
    process.env.LOCALAPPDATA || '',
    'FortniteGame', 'Saved', 'Config', 'WindowsClient', 'GameUserSettings.ini'
  );
  if (fs.existsSync(configPath)) {
    return path.dirname(configPath);
  }

  // Check Epic manifests
  const manifestDir = 'C:\\ProgramData\\Epic\\EpicGamesLauncher\\Data\\Manifests';
  if (fs.existsSync(manifestDir)) {
    try {
      const files = fs.readdirSync(manifestDir).filter(f => f.endsWith('.item'));
      for (const file of files) {
        const content = fs.readFileSync(path.join(manifestDir, file), 'utf-8');
        if (content.includes('Fortnite')) {
          const match = content.match(/"InstallLocation"\s*:\s*"([^"]+)"/);
          if (match) return match[1].replace(/\\\\/g, '\\');
        }
      }
    } catch {}
  }

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
  const configPath = path.join(
    process.env.LOCALAPPDATA || '',
    'ArcRaiders', 'Saved', 'Config', 'Windows'
  );
  if (fs.existsSync(configPath)) return configPath;
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
