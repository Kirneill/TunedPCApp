import { app, BrowserWindow, ipcMain, shell } from 'electron';
import path from 'path';
import fs from 'fs';
import { execFileSync } from 'child_process';
import { registerIpcHandlers } from './ipc/handlers';
import { initTelemetry, hasConsentDecision, getConsentStatus, setConsent, trackFailureStage } from './telemetry/telemetry';

// --- Diagnostic Logger ---
// app.getPath() is unavailable before 'ready', so defer log path resolution
let LOG_DIR = '';
let LOG_FILE = '';

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
    // Before app ready, just write to stderr
    if (level === 'ERROR') console.error(line.trim());
  }
}

let mainWindow: BrowserWindow | null = null;

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
  void trackFailureStage('elevation', 'Elevation prompt was denied or failed.');
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
    log('INFO', 'Window ready-to-show');
    mainWindow?.show();
  });

  if (devUrl) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }

  mainWindow.webContents.on('did-fail-load', (_event, errorCode, errorDescription) => {
    log('ERROR', `Page failed to load: ${errorCode} ${errorDescription}`);
  });

  // Window controls via IPC
  ipcMain.on('window:minimize', () => mainWindow?.minimize());
  ipcMain.on('window:maximize', () => {
    if (mainWindow?.isMaximized()) {
      mainWindow.unmaximize();
    } else {
      mainWindow?.maximize();
    }
  });
  ipcMain.on('window:close', () => mainWindow?.close());

  ipcMain.handle('system:isAdmin', () => isAdmin());
  ipcMain.handle('shell:openExternal', (_event, url: string) => {
    if (url.startsWith('https://')) shell.openExternal(url);
  });

  // Telemetry IPC
  ipcMain.handle('telemetry:hasConsentDecision', () => hasConsentDecision());
  ipcMain.handle('telemetry:getConsent', () => getConsentStatus());
  ipcMain.handle('telemetry:setConsent', (_event, granted: boolean) => {
    setConsent(granted);
    log('INFO', `Telemetry consent: ${granted ? 'granted' : 'declined'}`);
  });
}

// Single instance lock
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  log('WARN', 'Another instance is already running, quitting');
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  app.whenReady().then(() => {
    log('INFO', `SENSEQUALITY Optimizer starting`);
    log('INFO', `Electron: ${process.versions.electron}, Node: ${process.versions.node}, Chrome: ${process.versions.chrome}`);
    log('INFO', `process.type: ${process.type}, isPackaged: ${app.isPackaged}`);
    log('INFO', `ELECTRON_RUN_AS_NODE: ${process.env.ELECTRON_RUN_AS_NODE ?? 'unset'}`);
    log('INFO', `Platform: ${process.platform} ${process.arch}, CWD: ${process.cwd()}`);
    log('INFO', `App path: ${app.getAppPath()}, User data: ${app.getPath('userData')}`);

    initTelemetry();
    if (!ensureElevatedOrQuit()) {
      return;
    }

    log('INFO', 'App ready, registering IPC handlers');
    registerIpcHandlers(ipcMain);
    createWindow();
  });
}

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
