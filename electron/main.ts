import { app, BrowserWindow, ipcMain, shell, Menu, Tray, nativeImage } from 'electron';
import path from 'path';
import fs from 'fs';
import { execFileSync } from 'child_process';
import { registerIpcHandlers } from './ipc/handlers';
import { registerAuthHandlers } from './ipc/auth-handlers';
import { registerBiosHandlers } from './ipc/bios-handlers';
import { initTelemetry, hasConsentDecision, getConsentStatus, setConsent, trackFailureStage, trackAppLaunch, trackInstalledGames, buildHardwareInfo } from './telemetry/telemetry';
import { initAuth, onAppClosing } from './auth/auth';
import { getSystemInfo } from './ipc/system-info';
import { detectInstalledGames } from './ipc/game-detection';
import { checkForUpdate, initUpdater, getUpdaterState, downloadUpdate, installUpdate } from './updater';
import { startSystemMonitor, stopSystemMonitor } from './ipc/system-monitor';
import { initBilling, registerBillingHandlers } from './billing/autumn';

// --- Diagnostic Logger ---
// app.getPath() is unavailable before 'ready', so defer log path resolution
let LOG_DIR = '';
let LOG_FILE = '';
const APP_SETTINGS_FILE = 'app-settings.json';

interface AppSettings {
  closeToBackground: boolean;
  launchOnStartup: boolean;
}

const DEFAULT_APP_SETTINGS: AppSettings = {
  closeToBackground: true,
  launchOnStartup: true,
};

function ensureLogPaths() {
  if (!LOG_DIR) {
    LOG_DIR = path.join(app.getPath('userData'), 'logs');
    LOG_FILE = path.join(LOG_DIR, `main-${new Date().toISOString().slice(0, 10)}.log`);
  }
}

function log(level: 'INFO' | 'WARN' | 'ERROR', message: string) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] [${level}] ${message}\n`;
  try {
    ensureLogPaths();
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(LOG_FILE, line);
  } catch {
    if (level === 'ERROR') console.error(line.trim());
    else if (level === 'WARN') console.warn(line.trim());
  }
}

const STARTUP_TASK_NAME = 'SENSEQUALITY Optimizer';
const startHidden = process.argv.includes('--hidden');

let mainWindow: BrowserWindow | null = null;
let appTray: Tray | null = null;
let appSettings: AppSettings = { ...DEFAULT_APP_SETTINGS };
let isQuitting = false;
let pendingDeepLinkUrl: string | null = null;

// ─── Deep Link (sensequality:// protocol) ────────────────

function handleDeepLink(url: string) {
  // Strip hash fragment to avoid logging tokens
  log('INFO', `Deep link received: ${url.split('#')[0]}`);

  // Parse hash fragment tokens from URL like:
  // sensequality://reset-password#access_token=...&refresh_token=...&type=recovery
  try {
    const hashIndex = url.indexOf('#');
    if (hashIndex === -1) {
      log('WARN', 'Deep link has no hash fragment — ignoring');
      return;
    }

    const fragment = url.slice(hashIndex + 1);
    const params = new URLSearchParams(fragment);
    const accessToken = params.get('access_token');
    const refreshToken = params.get('refresh_token');
    const type = params.get('type');

    if (!accessToken || !refreshToken) {
      log('WARN', 'Deep link missing tokens — ignoring');
      return;
    }

    if (type !== 'recovery') {
      log('WARN', `Deep link type is "${type}", not "recovery" — ignoring`);
      return;
    }

    log('INFO', 'Sending password reset tokens to renderer');
    if (mainWindow?.webContents) {
      mainWindow.webContents.send('auth:passwordResetTokens', {
        access_token: accessToken,
        refresh_token: refreshToken,
      });
    } else {
      // Window not ready yet — store for later
      pendingDeepLinkUrl = url;
    }
  } catch (err) {
    log('ERROR', `Failed to parse deep link: ${err instanceof Error ? err.message : err}`);
  }
}

function getAppSettingsPath() {
  return path.join(app.getPath('userData'), APP_SETTINGS_FILE);
}

function loadAppSettings(): AppSettings {
  const settingsPath = getAppSettingsPath();
  try {
    if (!fs.existsSync(settingsPath)) {
      return { ...DEFAULT_APP_SETTINGS };
    }
    const raw = fs.readFileSync(settingsPath, 'utf8');
    const parsed = JSON.parse(raw) as Partial<AppSettings>;
    return {
      closeToBackground: parsed.closeToBackground !== false,
      launchOnStartup: parsed.launchOnStartup !== false,
    };
  } catch (err) {
    log('WARN', `Failed to load app settings, using defaults: ${err instanceof Error ? err.message : err}`);
    return { ...DEFAULT_APP_SETTINGS };
  }
}

function saveAppSettings(settings: AppSettings) {
  try {
    fs.writeFileSync(getAppSettingsPath(), JSON.stringify(settings, null, 2), 'utf8');
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    log('WARN', `Failed to save app settings: ${errorText}`);
  }
}

function syncAutoLaunch(enabled: boolean): boolean {
  if (process.platform !== 'win32' || !app.isPackaged) return true;

  try {
    if (enabled) {
      const exePath = process.execPath;
      execFileSync('schtasks.exe', [
        '/Create',
        '/TN', STARTUP_TASK_NAME,
        '/TR', `"${exePath}" --hidden`,
        '/SC', 'ONLOGON',
        // LIMITED — app will request admin elevation via its manifest when needed, rather than running elevated silently
        '/RL', 'LIMITED',
        '/F',
      ], { stdio: 'ignore' });
      log('INFO', 'Auto-launch scheduled task created');
    } else {
      execFileSync('schtasks.exe', [
        '/Delete',
        '/TN', STARTUP_TASK_NAME,
        '/F',
      ], { stdio: 'ignore' });
      log('INFO', 'Auto-launch scheduled task removed');
    }
    return true;
  } catch (err) {
    log('WARN', `Failed to sync auto-launch: ${err instanceof Error ? err.message : err}`);
    return false;
  }
}

function getTrayIconPath(): string | null {
  const candidates = [
    path.join(process.resourcesPath, 'icon.png'),
    path.join(process.resourcesPath, 'icon.ico'),
    path.join(app.getAppPath(), 'resources', 'icon.png'),
    path.join(app.getAppPath(), 'resources', 'icon.ico'),
    path.join(__dirname, '../resources/icon.png'),
    path.join(__dirname, '../resources/icon.ico'),
    path.join(process.cwd(), 'resources/icon.png'),
    path.join(process.cwd(), 'resources/icon.ico'),
  ];

  for (const iconPath of candidates) {
    try {
      if (fs.existsSync(iconPath)) {
        return iconPath;
      }
    } catch {
      // Continue to next candidate
    }
  }

  return null;
}

function showMainWindow() {
  if (!mainWindow) {
    createWindow();
    return;
  }
  if (!mainWindow.isVisible()) mainWindow.show();
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.focus();
}

function createTray() {
  if (appTray) return;

  const iconPath = getTrayIconPath();
  if (!iconPath) {
    log('WARN', 'Tray icon not found. Tray menu disabled.');
    return;
  }

  const trayIcon = nativeImage.createFromPath(iconPath);
  if (trayIcon.isEmpty()) {
    log('WARN', 'Tray icon failed to load. Tray menu disabled.');
    return;
  }

  appTray = new Tray(trayIcon);
  appTray.setToolTip('SENSEQUALITY Optimizer');
  appTray.on('click', () => showMainWindow());
  appTray.on('double-click', () => showMainWindow());

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Open SENSEQUALITY Optimizer',
      click: () => showMainWindow(),
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        isQuitting = true;
        app.quit();
      },
    },
  ]);
  appTray.setContextMenu(contextMenu);
}

function isAdmin(): boolean {
  if (process.platform !== 'win32') return true;

  // Primary check: elevated token via PowerShell
  try {
    const output = execFileSync('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      '[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
    ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    if (output.trim().toLowerCase() === 'true') return true;
  } catch {
    // fall through to secondary check
  }

  // Secondary check: `fltmc` typically requires elevation.
  // If command is missing/fails for environment reasons, treat as unknown and avoid hard-blocking.
  try {
    execFileSync('fltmc', [], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function escapeSingleQuotedPowerShell(value: string): string {
  return value.replace(/'/g, "''");
}

function relaunchAsAdmin(): boolean {
  try {
    const exePath = process.execPath;
    const args = process.argv.slice(1).filter(arg => arg !== '--sq-elevated-relaunch');
    const argList = args.map(arg => `'${escapeSingleQuotedPowerShell(arg)}'`).join(', ');
    const psCommand = [
      `$exe = '${escapeSingleQuotedPowerShell(exePath)}'`,
      `$args = @(${argList})`,
      'Start-Process -FilePath $exe -ArgumentList $args -Verb RunAs',
    ].join('; ');

    execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', psCommand], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function ensureElevatedOrQuit(): boolean {
  if (process.platform !== 'win32') return true;
  if (isAdmin()) return true;

  log('WARN', 'App is not running as administrator. Requesting elevation...');
  const relaunched = relaunchAsAdmin();
  if (relaunched) {
    log('INFO', 'Elevation prompt accepted; quitting non-elevated instance.');
    app.quit();
    return false;
  }

  // Do not hard-stop on failed/denied elevation because admin detection can be unreliable on some systems.
  // Scripts will still enforce required privileges at execution time.
  log('WARN', 'Elevation prompt was denied or failed. Continuing without forced shutdown.');
  void trackFailureStage('elevation', 'Elevation prompt was denied or failed.').catch(err => {
    log('WARN', `trackFailureStage (elevation) failed: ${err instanceof Error ? err.message : err}`);
  });
  return true;
}

function createWindow() {
  log('INFO', `Creating window, admin: ${isAdmin()}`);

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 1024,
    minHeight: 700,
    frame: false,
    backgroundColor: '#0a0a0f',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false,
    },
  });

  initUpdater(() => mainWindow);

  // vite-plugin-electron sets VITE_DEV_SERVER_URL in dev mode
  const devUrl = process.env.VITE_DEV_SERVER_URL;
  if (devUrl) {
    log('INFO', `Loading dev server: ${devUrl}`);
    mainWindow.loadURL(devUrl);
  } else {
    const indexPath = path.join(__dirname, '../dist/index.html');
    log('INFO', `Loading production build: ${indexPath}`);
    mainWindow.loadFile(indexPath);
  }

  mainWindow.once('ready-to-show', () => {
    log('INFO', `Window ready-to-show (startHidden: ${startHidden})`);
    if (!startHidden) {
      mainWindow?.show();
    }

    // Flush any pending deep link URL after a short delay to ensure renderer is listening
    if (pendingDeepLinkUrl) {
      const url = pendingDeepLinkUrl;
      pendingDeepLinkUrl = null;
      setTimeout(() => handleDeepLink(url), 500);
    }
  });

  mainWindow.on('close', (event) => {
    if (isQuitting || !appSettings.closeToBackground) {
      return;
    }
    if (!appTray) {
      log('WARN', 'Close-to-background requested but tray is unavailable; allowing full exit.');
      return;
    }
    event.preventDefault();
    mainWindow?.hide();
    log('INFO', 'Close intercepted; app remains running in background.');
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  if (devUrl) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }

  mainWindow.webContents.on('did-fail-load', (_event, errorCode, errorDescription) => {
    log('ERROR', `Page failed to load: ${errorCode} ${errorDescription}`);
  });

}

// Single instance lock
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  log('WARN', 'Another instance is already running, quitting');
  app.quit();
} else {
  app.on('second-instance', (_event, argv) => {
    showMainWindow();

    // On Windows, protocol URLs are passed as the last argv entry
    const deepLinkUrl = argv.find(arg => arg.startsWith('sensequality://'));
    if (deepLinkUrl) {
      handleDeepLink(deepLinkUrl);
    }
  });

  app.whenReady().then(async () => {
    log('INFO', `SENSEQUALITY Optimizer starting`);
    log('INFO', `Electron: ${process.versions.electron}, Node: ${process.versions.node}, Chrome: ${process.versions.chrome}`);
    log('INFO', `process.type: ${process.type}, isPackaged: ${app.isPackaged}`);
    log('INFO', `ELECTRON_RUN_AS_NODE: ${process.env.ELECTRON_RUN_AS_NODE ?? 'unset'}`);
    log('INFO', `Platform: ${process.platform} ${process.arch}, CWD: ${process.cwd()}`);
    log('INFO', `App path: ${app.getAppPath()}, User data: ${app.getPath('userData')}`);
    appSettings = loadAppSettings();
    log('INFO', `Close behavior: ${appSettings.closeToBackground ? 'background' : 'full-exit'}`);

    // Phase 1: Init telemetry (anonymous, consent-gated)
    initTelemetry();

    // Phase 2: Init auth (separate Supabase client, always active)
    try {
      await initAuth();
      log('INFO', 'Auth initialized');
    } catch (err) {
      log('WARN', `Auth init failed: ${err instanceof Error ? err.message : err}`);
    }

    // Register custom protocol for deep links (dev mode only — packaged builds use electron-builder config)
    if (!app.isPackaged) {
      app.setAsDefaultProtocolClient('sensequality');
      log('INFO', 'Registered sensequality:// protocol (dev mode)');
    }

    // Check if app was launched via a protocol URL (cold start)
    const protocolArg = process.argv.find(arg => arg.startsWith('sensequality://'));
    if (protocolArg) {
      pendingDeepLinkUrl = protocolArg;
      log('INFO', `Found protocol URL in launch args: ${protocolArg.split('#')[0]}`);
    }

    if (!ensureElevatedOrQuit()) {
      return;
    }

    // Phase 3: Init billing (Autumn + Stripe)
    initBilling();

    // Phase 3b: Register IPC handlers
    log('INFO', 'App ready, registering IPC handlers');
    registerIpcHandlers(ipcMain);
    registerAuthHandlers(ipcMain);
    registerBiosHandlers(ipcMain, () => mainWindow);
    registerBillingHandlers(ipcMain);

    // Window controls & app-level IPC (registered once, outside createWindow to avoid double-registration)
    ipcMain.on('window:minimize', () => mainWindow?.minimize());
    ipcMain.on('window:maximize', () => {
      if (mainWindow?.isMaximized()) {
        mainWindow.unmaximize();
      } else {
        mainWindow?.maximize();
      }
    });
    ipcMain.on('window:close', () => mainWindow?.close());
    ipcMain.handle('app:getCloseToBackground', () => appSettings.closeToBackground);
    ipcMain.handle('app:setCloseToBackground', (_event, enabled: boolean) => {
      appSettings.closeToBackground = Boolean(enabled);
      saveAppSettings(appSettings);
      log('INFO', `Close behavior updated: ${appSettings.closeToBackground ? 'background' : 'full-exit'}`);
      return appSettings.closeToBackground;
    });
    ipcMain.handle('app:getLaunchOnStartup', () => appSettings.launchOnStartup);
    ipcMain.handle('app:setLaunchOnStartup', (_event, enabled: boolean) => {
      appSettings.launchOnStartup = Boolean(enabled);
      saveAppSettings(appSettings);
      const synced = syncAutoLaunch(appSettings.launchOnStartup);
      if (!synced) {
        log('WARN', `Launch on startup setting saved but scheduled task sync failed`);
      }
      log('INFO', `Launch on startup updated: ${appSettings.launchOnStartup} (synced: ${synced})`);
      return appSettings.launchOnStartup;
    });
    ipcMain.handle('system:isAdmin', () => isAdmin());
    ipcMain.handle('shell:openExternal', (_event, url: string) => {
      if (url.startsWith('https://')) shell.openExternal(url);
    });
    ipcMain.handle('system:restart', () => {
      try {
        execFileSync('shutdown', ['/r', '/t', '5'], { windowsHide: true });
        return { success: true };
      } catch (err) {
        return { success: false, error: err instanceof Error ? err.message : String(err) };
      }
    });
    ipcMain.handle('updater:check', () => checkForUpdate());
    ipcMain.handle('updater:getState', () => getUpdaterState());
    ipcMain.handle('updater:download', () => downloadUpdate());
    ipcMain.handle('updater:install', () => installUpdate());
    ipcMain.handle('app:getVersion', () => app.getVersion());
    ipcMain.handle('telemetry:hasConsentDecision', () => hasConsentDecision());
    ipcMain.handle('telemetry:getConsent', () => getConsentStatus());
    ipcMain.handle('telemetry:setConsent', (_event, granted: boolean) => {
      setConsent(granted);
      log('INFO', `Telemetry consent: ${granted ? 'granted' : 'declined'}`);
    });

    // Phase 4: Create window
    createWindow();
    createTray();

    // Phase 4b: Sync auto-launch scheduled task with settings (deferred to avoid blocking window creation)
    setTimeout(() => syncAutoLaunch(appSettings.launchOnStartup), 0);

    // Phase 5: Start live system monitoring (CPU/GPU/RAM → renderer every 2s)
    startSystemMonitor(() => mainWindow);

    // Phase 6: Detached IIFE — telemetry calls are consent-gated internally
    void (async () => {
      try {
        const sysInfo = await getSystemInfo();
        const hw = buildHardwareInfo(sysInfo);
        trackAppLaunch(hw).catch(err => {
          log('WARN', `app_launch telemetry failed: ${err instanceof Error ? err.message : err}`);
        });

        try {
          const games = await detectInstalledGames();
          trackInstalledGames(games.map(g => ({ id: g.id, installed: g.installed }))).catch(err => {
            log('WARN', `installed games telemetry failed: ${err instanceof Error ? err.message : err}`);
          });
        } catch (err) {
          log('WARN', `Game detection failed: ${err instanceof Error ? err.message : err}`);
        }
      } catch (err) {
        log('WARN', `System info unavailable, skipping launch telemetry: ${err instanceof Error ? err.message : err}`);
      }
    })();
  });
}

app.on('before-quit', () => {
  isQuitting = true;
  try {
    onAppClosing();
  } catch (err) {
    log('WARN', `onAppClosing failed: ${err instanceof Error ? err.message : err}`);
  }
  stopSystemMonitor();
  if (appTray) {
    appTray.destroy();
    appTray = null;
  }
});

app.on('activate', () => {
  showMainWindow();
});

app.on('window-all-closed', () => {
  log('INFO', 'All windows closed, quitting');
  app.quit();
});

process.on('uncaughtException', (error) => {
  log('ERROR', `Uncaught exception: ${error.message}\n${error.stack}`);
});

process.on('unhandledRejection', (reason) => {
  log('ERROR', `Unhandled rejection: ${reason}`);
});
