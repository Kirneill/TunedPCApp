import { IpcMain, BrowserWindow, app } from 'electron';
import { getSystemInfo } from './system-info';
import { detectInstalledGames } from './game-detection';
import { listBackups, createBackup, restoreBackup, deleteBackup } from './backup-manager';
import { runPowerShellScript, runPowerShellCommand, getScriptPath } from './powershell';
import { trackOptimizationResult, trackFailureStage, type HardwareInfo } from '../telemetry/telemetry';
import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { execFileSync } from 'child_process';

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
  'win-standard': { script: '08_Standard_Windows_Settings.ps1' },
  // Windows Update mode actions
  'updates-off': { script: '09_Windows_Update_Off.ps1' },
  'updates-on': { script: '10_Windows_Update_On.ps1' },
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

type LogType = 'info' | 'success' | 'error' | 'warning' | 'start' | 'complete';

interface NormalizedRunLogLine {
  timestamp: string;
  level: 'INFO' | 'WARN' | 'ERROR';
  runId: string;
  component: string;
  action: string;
  script: string | null;
  success: boolean | null;
  errorCode: string | null;
  message: string;
}

interface RunLogOptions {
  component?: string;
  action?: string;
  script?: string | null;
  success?: boolean | null;
  errorCode?: string | null;
}

type RunLogFn = (type: LogType, message: string, options?: RunLogOptions) => void;

function toLogLevel(type: LogType): 'INFO' | 'WARN' | 'ERROR' {
  if (type === 'error') return 'ERROR';
  if (type === 'warning') return 'WARN';
  return 'INFO';
}

function getRunLogFilePath(runId: string): string {
  const dir = path.join(app.getPath('userData'), 'logs', 'runs');
  fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, `${runId}.jsonl`);
}

function createRunLogger(win: BrowserWindow | null, runId: string): { runId: string; filePath: string; log: RunLogFn } {
  const filePath = getRunLogFilePath(runId);

  const log: RunLogFn = (type, message, options = {}) => {
    const timestamp = Date.now();
    const component = options.component || 'OptimizationEngine';
    const script = options.script === undefined
      ? (component.endsWith('.ps1') ? component : null)
      : options.script;
    const success = options.success !== undefined
      ? options.success
      : (type === 'success' ? true : (type === 'error' ? false : null));
    const action = options.action || type;
    const errorCode = options.errorCode ?? null;

    win?.webContents.send('optimize:log', {
      type,
      message,
      timestamp,
      section: component,
      runId,
    });

    const line: NormalizedRunLogLine = {
      timestamp: new Date(timestamp).toISOString(),
      level: toLogLevel(type),
      runId,
      component,
      action,
      script,
      success,
      errorCode,
      message,
    };

    try {
      fs.appendFileSync(filePath, `${JSON.stringify(line)}\n`);
    } catch (err) {
      const errorText = err instanceof Error ? err.message : String(err);
      console.warn(`[run-log] Failed to write run log ${filePath}: ${errorText}`);
    }
  };

  return { runId, filePath, log };
}

const AUTO_RESTORE_POINT_SCRIPT = `
$ErrorActionPreference = 'Stop'

New-Item -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Type DWord -Value 0

if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
    Enable-ComputerRestore -Drive $Env:SystemDrive | Out-Null
}

$description = "SENSEQUALITY Auto Restore Point $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
Checkpoint-Computer -Description $description -RestorePointType MODIFY_SETTINGS
Write-Output "Restore point created: $description"
`;

async function ensureSystemRestorePoint(log: RunLogFn): Promise<boolean> {
  log('start', 'Creating system restore point before applying changes...', {
    component: 'Safety',
    action: 'restore-point-start',
  });

  const result = await runPowerShellCommand(AUTO_RESTORE_POINT_SCRIPT, (line) => {
    log('info', line, {
      component: 'Safety',
      action: 'restore-point-output',
    });
  });

  if (!result.success) {
    const errorText = result.errors.join(' | ') || 'Unknown restore point error';
    log('error', `Restore point failed. No changes were applied. ${errorText}`, {
      component: 'Safety',
      action: 'restore-point-failed',
      success: false,
      errorCode: 'RESTORE_POINT_FAILED',
    });
    void trackFailureStage('restore-point', errorText);
    return false;
  }

  log('success', 'System restore point created successfully.', {
    component: 'Safety',
    action: 'restore-point-success',
    success: true,
  });
  return true;
}

function escapePowerShellSingleQuoted(value: string): string {
  return value.replace(/'/g, "''");
}

function exportDiagnosticsBundle(): { success: boolean; path: string; error?: string } {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const userDataDir = app.getPath('userData');
  const tempBundleDir = path.join(app.getPath('temp'), `SENSEQUALITY_Diagnostics_${timestamp}`);
  const diagnosticsZipPath = path.join(app.getPath('documents'), `SENSEQUALITY_Diagnostics_${timestamp}.zip`);

  const included: Record<string, boolean> = {
    logs: false,
    telemetryConfig: false,
  };

  try {
    fs.mkdirSync(tempBundleDir, { recursive: true });

    const logsDir = path.join(userDataDir, 'logs');
    if (fs.existsSync(logsDir)) {
      fs.cpSync(logsDir, path.join(tempBundleDir, 'logs'), { recursive: true });
      included.logs = true;
    }

    const telemetryConfigPath = path.join(userDataDir, 'telemetry.json');
    if (fs.existsSync(telemetryConfigPath)) {
      fs.copyFileSync(telemetryConfigPath, path.join(tempBundleDir, 'telemetry.json'));
      included.telemetryConfig = true;
    }

    const summary = {
      generatedAt: new Date().toISOString(),
      appVersion: app.getVersion(),
      electronVersion: process.versions.electron,
      nodeVersion: process.versions.node,
      chromeVersion: process.versions.chrome,
      platform: process.platform,
      arch: process.arch,
      userDataDir,
      included,
    };
    fs.writeFileSync(path.join(tempBundleDir, 'summary.json'), JSON.stringify(summary, null, 2), 'utf8');

    const sourcePath = `${tempBundleDir}\\*`;
    const psCmd = [
      `$src='${escapePowerShellSingleQuoted(sourcePath)}'`,
      `$dest='${escapePowerShellSingleQuoted(diagnosticsZipPath)}'`,
      'Compress-Archive -Path $src -DestinationPath $dest -Force',
    ].join('; ');
    execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', psCmd], { stdio: 'ignore' });

    try {
      fs.rmSync(tempBundleDir, { recursive: true, force: true });
    } catch (cleanupErr) {
      const cleanupText = cleanupErr instanceof Error ? cleanupErr.message : String(cleanupErr);
      console.warn(`[diagnostics] Temp cleanup failed: ${cleanupText}`);
    }

    return { success: true, path: diagnosticsZipPath };
  } catch (err) {
    try {
      fs.rmSync(tempBundleDir, { recursive: true, force: true });
    } catch {}
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[diagnostics] Export failed: ${errorText}`);
    return { success: false, path: '', error: errorText };
  }
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
    const runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`;
    const runLogger = createRunLogger(win, runId);
    const log = runLogger.log;

    const mapping = SCRIPT_MAP[id];
    if (!mapping) {
      log('error', `Unknown optimization requested: ${id}`, {
        component: 'Validation',
        action: 'unknown-optimization',
        success: false,
        errorCode: 'UNKNOWN_OPTIMIZATION',
      });
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

    log('start', `Run started for optimization: ${id}`, {
      component: 'Run',
      action: 'run-start',
    });
    const restorePointReady = await ensureSystemRestorePoint(log);
    if (!restorePointReady) {
      return { success: false, errors: ['Failed to create restore point.'] };
    }

    log('start', `Running: ${id}`, {
      component: 'Optimization',
      action: 'script-start',
      script: mapping.script,
    });
    const result = await runPowerShellScript(scriptPath, envVars, (line) => {
      log('info', line, {
        component: 'Optimization',
        action: 'script-output',
        script: mapping.script,
      });
    });

    log(result.success ? 'success' : 'error',
      result.success ? `Completed: ${id}` : `Failed: ${id}`,
      {
        component: 'Optimization',
        action: 'script-exit',
        script: mapping.script,
        success: result.success,
        errorCode: result.success ? null : `SCRIPT_EXIT_${result.exitCode}`,
      }
    );

    if (result.errors.length > 0) {
      log('warning', `Script stderr captured (${result.errors.length} line(s)).`, {
        component: 'Optimization',
        action: 'script-stderr',
        script: mapping.script,
        success: result.success,
        errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
      });
    }
    log('complete', `Run finished for ${id}.`, {
      component: 'Summary',
      action: 'run-finish',
      success: result.success,
      errorCode: result.success ? null : `SCRIPT_EXIT_${result.exitCode}`,
    });

    if (!result.success) {
      const failureText = result.errors.join(' | ') || `Script exited with code ${result.exitCode}`;
      void trackFailureStage('script-exit', failureText, undefined, [id]);
    }

    return { success: result.success, errors: result.errors };
  });

  // Run selected optimizations
  ipcMain.handle('optimize:runSelected', async (event, ids: string[], config: UserConfig) => {
    const startTime = Date.now();
    const win = BrowserWindow.fromWebContents(event.sender);
    const runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`;
    const runLogger = createRunLogger(win, runId);
    const log = runLogger.log;
    const results: Record<string, boolean> = {};

    // Group Windows optimizations:
    // - Section-based IDs run through script 01 with SKIP_* env flags
    // - Standalone IDs run their own scripts
    const windowsIds = ids.filter(id => id.startsWith('win-'));
    const windowsSectionIds = windowsIds.filter(id => SCRIPT_MAP[id]?.script === '01_Windows_Optimization.ps1');
    const windowsStandaloneIds = windowsIds.filter(id => SCRIPT_MAP[id] && SCRIPT_MAP[id].script !== '01_Windows_Optimization.ps1');
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

    log('start', `Run started for ${ids.length} optimization(s).`, {
      component: 'Run',
      action: 'run-start',
    });

    const restorePointReady = await ensureSystemRestorePoint(log);
    if (!restorePointReady) {
      for (const id of ids) {
        results[id] = false;
      }
      log('complete', 'Aborted: restore point creation failed.', {
        component: 'Summary',
        action: 'run-abort',
        success: false,
        errorCode: 'RESTORE_POINT_FAILED',
      });
      return { success: false, results };
    }

    // Run Windows optimizations (single script, skip flags for unselected)
    if (windowsSectionIds.length > 0) {
      const allWindowsSectionKeys = Object.keys(SCRIPT_MAP).filter(
        k => k.startsWith('win-') && SCRIPT_MAP[k].script === '01_Windows_Optimization.ps1'
      );
      for (const key of allWindowsSectionKeys) {
        const prefix = SCRIPT_MAP[key]?.envPrefix;
        if (prefix) {
          envVars[`SKIP_${prefix}`] = windowsSectionIds.includes(key) ? '0' : '1';
        }
      }

      // Track per-section results via structured markers from PowerShell stdout
      const sectionResults: Record<string, boolean> = {};

      log('start', 'Applying Windows optimizations...', {
        component: 'Windows',
        action: 'script-start',
        script: '01_Windows_Optimization.ps1',
      });
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
          log('info', line, {
            component: 'Windows',
            action: 'script-output',
            script: '01_Windows_Optimization.ps1',
          });
        }
      });

      // Assign per-section results; fall back to overall script result for sections without markers
      for (const id of windowsSectionIds) {
        results[id] = sectionResults[id] !== undefined ? sectionResults[id] : result.success;
      }

      const winFailed = windowsSectionIds.filter(id => !results[id]);
      if (winFailed.length === 0) {
        log('success', 'Windows optimizations applied!', {
          component: 'Windows',
          action: 'script-exit',
          script: '01_Windows_Optimization.ps1',
          success: true,
        });
      } else {
        log('error',
          `Windows optimizations: ${winFailed.length} section(s) had errors`,
          {
            component: 'Windows',
            action: 'script-exit',
            script: '01_Windows_Optimization.ps1',
            success: false,
            errorCode: `SCRIPT_EXIT_${result.exitCode}`,
          }
        );
      }

      if (result.errors.length > 0) {
        log('warning', `Windows script stderr captured (${result.errors.length} line(s)).`, {
          component: 'Windows',
          action: 'script-stderr',
          script: '01_Windows_Optimization.ps1',
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
        });
      }

      if (!result.success) {
        const failureText = result.errors.join(' | ') || `Windows script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, windowsSectionIds);
      }
    }

    // Run standalone Windows scripts sequentially
    for (const id of windowsStandaloneIds) {
      const mapping = SCRIPT_MAP[id];
      if (!mapping) continue;

      log('start', `Running ${id}...`, {
        component: 'Windows',
        action: 'script-start',
        script: mapping.script,
      });
      const scriptPath = getScriptPath(mapping.script);
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        log('info', line, {
          component: 'Windows',
          action: 'script-output',
          script: mapping.script,
        });
      });

      results[id] = result.success;
      log(result.success ? 'success' : 'error',
        result.success ? `${id} applied!` : `${id} had errors`,
        {
          component: 'Windows',
          action: 'script-exit',
          script: mapping.script,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_EXIT_${result.exitCode}`,
        }
      );
      if (result.errors.length > 0) {
        log('warning', `Script stderr captured (${result.errors.length} line(s)).`, {
          component: 'Windows',
          action: 'script-stderr',
          script: mapping.script,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
        });
      }
      if (!result.success) {
        const failureText = result.errors.join(' | ') || `Script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, [id]);
      }
    }

    // Run each game script sequentially
    for (const id of gameIds) {
      const mapping = SCRIPT_MAP[id];
      if (!mapping) continue;

      log('start', `Optimizing ${id.replace('game-', '')}...`, {
        component: 'Game',
        action: 'script-start',
        script: mapping.script,
      });
      const scriptPath = getScriptPath(mapping.script);
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        log('info', line, {
          component: 'Game',
          action: 'script-output',
          script: mapping.script,
        });
      });

      results[id] = result.success;
      log(result.success ? 'success' : 'error',
        result.success ? `${id.replace('game-', '')} optimized!` : `${id.replace('game-', '')} had errors`,
        {
          component: 'Game',
          action: 'script-exit',
          script: mapping.script,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_EXIT_${result.exitCode}`,
        }
      );
      if (result.errors.length > 0) {
        log('warning', `Script stderr captured (${result.errors.length} line(s)).`, {
          component: 'Game',
          action: 'script-stderr',
          script: mapping.script,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
        });
      }
      if (!result.success) {
        const failureText = result.errors.join(' | ') || `Script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, [id]);
      }
    }

    const allSuccess = Object.values(results).every(Boolean);
    const errorCount = Object.values(results).filter(v => !v).length;
    log('complete',
      allSuccess ? 'All optimizations applied successfully!' : 'Completed with some errors',
      {
        component: 'Summary',
        action: 'run-finish',
        success: allSuccess,
        errorCode: allSuccess ? null : 'RUN_PARTIAL_FAILURE',
      }
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
    } catch (err) {
      const errorText = err instanceof Error ? err.message : String(err);
      log('warning', `Telemetry tracking failed: ${errorText}`, {
        component: 'Telemetry',
        action: 'telemetry-failed',
        errorCode: 'TELEMETRY_SEND_FAILED',
      });
    }

    return { success: allSuccess, results };
  });

  // Backups
  ipcMain.handle('backup:list', () => listBackups());
  ipcMain.handle('backup:create', () => createBackup());
  ipcMain.handle('backup:restore', (_, backupPath: string) => restoreBackup(backupPath));
  ipcMain.handle('backup:delete', (_, backupPath: string) => deleteBackup(backupPath));
  ipcMain.handle('diagnostics:export', () => exportDiagnosticsBundle());
}
