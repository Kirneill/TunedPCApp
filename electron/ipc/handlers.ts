import { IpcMain, BrowserWindow } from 'electron';
import { getSystemInfo } from './system-info';
import { detectInstalledGames } from './game-detection';
import { listBackups, createBackup, restoreBackup, deleteBackup } from './backup-manager';
import { runPowerShellScript, getScriptPath } from './powershell';
import { trackOptimizationResult, type HardwareInfo } from '../telemetry/telemetry';

interface UserConfig {
  monitorWidth: number;
  monitorHeight: number;
  monitorRefresh: number;
  nvidiaGpu: boolean;
  cs2Stretched: boolean;
}

// Maps optimization IDs to script files and env var configurations
const SCRIPT_MAP: Record<string, { script: string; envPrefix?: string }> = {
  // Windows optimizations — all handled by script 01, controlled by skip env vars
  'win-power-plan': { script: '01_Windows_Optimization.ps1', envPrefix: 'POWER_PLAN' },
  'win-hags': { script: '01_Windows_Optimization.ps1', envPrefix: 'HAGS' },
  'win-game-mode': { script: '01_Windows_Optimization.ps1', envPrefix: 'GAME_MODE' },
  'win-mmcss': { script: '01_Windows_Optimization.ps1', envPrefix: 'MMCSS' },
  'win-network': { script: '01_Windows_Optimization.ps1', envPrefix: 'NETWORK' },
  'win-visual-fx': { script: '01_Windows_Optimization.ps1', envPrefix: 'VISUAL_FX' },
  'win-fullscreen': { script: '01_Windows_Optimization.ps1', envPrefix: 'FULLSCREEN' },
  'win-mouse': { script: '01_Windows_Optimization.ps1', envPrefix: 'MOUSE' },
  'win-cpu-power': { script: '01_Windows_Optimization.ps1', envPrefix: 'CPU_POWER' },
  // Game optimizations
  'game-blackops7': { script: '02_BlackOps7_Settings.ps1' },
  'game-fortnite': { script: '03_Fortnite_Settings.ps1' },
  'game-valorant': { script: '04_Valorant_Settings.ps1' },
  'game-cs2': { script: '05_CS2_Settings.ps1' },
  'game-arcraiders': { script: '06_ArcRaiders_Settings.ps1' },
};

// Maps env prefix (e.g. 'POWER_PLAN') back to optimization ID (e.g. 'win-power-plan')
const PREFIX_TO_ID: Record<string, string> = {};
for (const [id, mapping] of Object.entries(SCRIPT_MAP)) {
  if (mapping.envPrefix) {
    PREFIX_TO_ID[mapping.envPrefix] = id;
  }
}

function sendLog(win: BrowserWindow | null, type: string, message: string, section?: string) {
  win?.webContents.send('optimize:log', {
    type,
    message,
    timestamp: Date.now(),
    section,
  });
}

export function registerIpcHandlers(ipcMain: IpcMain) {
  // System info
  ipcMain.handle('system:getInfo', async () => {
    return getSystemInfo();
  });

  ipcMain.handle('system:getGames', async () => {
    return detectInstalledGames();
  });

  // Run a single optimization
  ipcMain.handle('optimize:run', async (event, id: string, config: UserConfig) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    const mapping = SCRIPT_MAP[id];
    if (!mapping) {
      return { success: false, errors: [`Unknown optimization: ${id}`] };
    }

    const scriptPath = getScriptPath(mapping.script);
    const envVars: Record<string, string> = {
      SENSEQUALITY_HEADLESS: '1',
      MONITOR_WIDTH: String(config.monitorWidth),
      MONITOR_HEIGHT: String(config.monitorHeight),
      MONITOR_REFRESH: String(config.monitorRefresh),
      NVIDIA_GPU: config.nvidiaGpu ? '1' : '0',
      CS2_STRETCHED: config.cs2Stretched ? '1' : '0',
    };

    sendLog(win, 'start', `Running: ${id}`, mapping.script);
    const result = await runPowerShellScript(scriptPath, envVars, (line) => {
      sendLog(win, 'info', line, mapping.script);
    });

    sendLog(win, result.success ? 'success' : 'error',
      result.success ? `Completed: ${id}` : `Failed: ${id}`,
      mapping.script
    );

    return { success: result.success, errors: result.errors };
  });

  // Run selected optimizations
  ipcMain.handle('optimize:runSelected', async (event, ids: string[], config: UserConfig) => {
    const startTime = Date.now();
    const win = BrowserWindow.fromWebContents(event.sender);
    const results: Record<string, boolean> = {};

    // Group Windows optimizations — they share the same script
    const windowsIds = ids.filter(id => id.startsWith('win-'));
    const gameIds = ids.filter(id => id.startsWith('game-'));

    // Build env vars
    const envVars: Record<string, string> = {
      SENSEQUALITY_HEADLESS: '1',
      MONITOR_WIDTH: String(config.monitorWidth),
      MONITOR_HEIGHT: String(config.monitorHeight),
      MONITOR_REFRESH: String(config.monitorRefresh),
      NVIDIA_GPU: config.nvidiaGpu ? '1' : '0',
      CS2_STRETCHED: config.cs2Stretched ? '1' : '0',
    };

    // Run Windows optimizations (single script, skip flags for unselected)
    if (windowsIds.length > 0) {
      const allWindowsKeys = Object.keys(SCRIPT_MAP).filter(k => k.startsWith('win-'));
      for (const key of allWindowsKeys) {
        const prefix = SCRIPT_MAP[key].envPrefix;
        if (prefix) {
          envVars[`SKIP_${prefix}`] = windowsIds.includes(key) ? '0' : '1';
        }
      }

      // Track per-section results via structured markers from PowerShell stdout
      const sectionResults: Record<string, boolean> = {};

      sendLog(win, 'start', 'Applying Windows optimizations...', 'Windows');
      const scriptPath = getScriptPath('01_Windows_Optimization.ps1');
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        // Parse structured markers: [SQ_OK:POWER_PLAN], [SQ_FAIL:POWER_PLAN], [SQ_SKIP:POWER_PLAN]
        const okMatch = line.match(/\[SQ_OK:(\w+)\]/);
        const failMatch = line.match(/\[SQ_FAIL:(\w+)\]/);
        const skipMatch = line.match(/\[SQ_SKIP:(\w+)\]/);

        if (okMatch) {
          const id = PREFIX_TO_ID[okMatch[1]];
          if (id) sectionResults[id] = true;
        } else if (failMatch) {
          const id = PREFIX_TO_ID[failMatch[1]];
          if (id) sectionResults[id] = false;
        } else if (skipMatch) {
          // Skipped sections are not failures — don't track them
        } else {
          // Regular log line — forward to UI
          sendLog(win, 'info', line, 'Windows');
        }
      });

      // Assign per-section results; fall back to overall script result for sections without markers
      for (const id of windowsIds) {
        results[id] = sectionResults[id] !== undefined ? sectionResults[id] : result.success;
      }

      const winFailed = windowsIds.filter(id => !results[id]);
      if (winFailed.length === 0) {
        sendLog(win, 'success', 'Windows optimizations applied!', 'Windows');
      } else {
        sendLog(win, 'error',
          `Windows optimizations: ${winFailed.length} section(s) had errors`,
          'Windows'
        );
      }
    }

    // Run each game script sequentially
    for (const id of gameIds) {
      const mapping = SCRIPT_MAP[id];
      if (!mapping) continue;

      sendLog(win, 'start', `Optimizing ${id.replace('game-', '')}...`, mapping.script);
      const scriptPath = getScriptPath(mapping.script);
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        sendLog(win, 'info', line, mapping.script);
      });

      results[id] = result.success;
      sendLog(win, result.success ? 'success' : 'error',
        result.success ? `${id.replace('game-', '')} optimized!` : `${id.replace('game-', '')} had errors`,
        mapping.script
      );
    }

    const allSuccess = Object.values(results).every(Boolean);
    const errorCount = Object.values(results).filter(v => !v).length;
    sendLog(win, 'complete',
      allSuccess ? 'All optimizations applied successfully!' : 'Completed with some errors',
      'Summary'
    );

    // Telemetry — fire and forget, never blocks the UI
    try {
      const sysInfo = await getSystemInfo();
      const hw: HardwareInfo = {
        gpu: sysInfo.gpu,
        cpu: sysInfo.cpu,
        ram_gb: sysInfo.ramGB,
        os_build: sysInfo.osBuild,
      };
      trackOptimizationResult(hw, ids, allSuccess, Date.now() - startTime, errorCount);
    } catch {}

    return { success: allSuccess, results };
  });

  // Backups
  ipcMain.handle('backup:list', () => listBackups());
  ipcMain.handle('backup:create', () => createBackup());
  ipcMain.handle('backup:restore', (_, backupPath: string) => restoreBackup(backupPath));
  ipcMain.handle('backup:delete', (_, backupPath: string) => deleteBackup(backupPath));
}
