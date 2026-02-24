import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'path';
import fs from 'fs';
import { execFileSync } from 'child_process';
import { registerIpcHandlers } from './ipc/handlers';

// --- Diagnostic Logger ---
const LOG_DIR = path.join(app.getPath('userData'), 'logs');
const LOG_FILE = path.join(LOG_DIR, `main-${new Date().toISOString().slice(0, 10)}.log`);

function log(level: 'INFO' | 'WARN' | 'ERROR', message: string) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] [${level}] ${message}\n`;
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(LOG_FILE, line);
  } catch {}
  if (level === 'ERROR') console.error(line.trim());
}

// Startup diagnostics
log('INFO', `SENSEQUALITY Optimizer starting`);
log('INFO', `Electron: ${process.versions.electron}, Node: ${process.versions.node}, Chrome: ${process.versions.chrome}`);
log('INFO', `process.type: ${process.type}, isPackaged: ${app.isPackaged}`);
log('INFO', `ELECTRON_RUN_AS_NODE: ${process.env.ELECTRON_RUN_AS_NODE ?? 'unset'}`);
log('INFO', `Platform: ${process.platform} ${process.arch}, CWD: ${process.cwd()}`);
log('INFO', `App path: ${app.getAppPath()}, User data: ${app.getPath('userData')}`);

let mainWindow: BrowserWindow | null = null;

function isAdmin(): boolean {
  try {
    execFileSync('net', ['session'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
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
