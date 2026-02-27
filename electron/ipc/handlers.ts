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
  gpuMode: 'auto' | 'manual';
  selectedGpuId: string;
  cs2Stretched: boolean;
  restorePointEnabled: boolean;
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
  'win-bg-apps': { script: '01_Windows_Optimization.ps1', envPrefix: 'BG_APPS' },
  'win-mpo': { script: '01_Windows_Optimization.ps1', envPrefix: 'MPO' },
  'win-visual-extras': { script: '01_Windows_Optimization.ps1', envPrefix: 'VISUAL_EXTRAS' },
  'win-copilot': { script: '11_Disable_Copilot.ps1' },
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

type CheckStatus = 'ok' | 'fail' | 'warn';

interface ScriptCheck {
  key: string;
  status: CheckStatus;
  detail: string;
}

const CHECK_LABELS: Record<string, string> = {
  COD_EXE_FLAGS: 'COD EXE compatibility flags',
  COD_GAME_MODE_ON: 'Windows Game Mode is ON',
  COD_GAME_DVR_OFF: 'Game DVR is OFF',
  COD_CONFIG_FILES_COPIED: 'COD config template copy step',
  COD_RENDERER_WORKER_COUNT: 'COD RendererWorkerCount patch step',
  COD_RENDER_SCALE_PRESERVED: 'COD render scale unchanged',
  COD_RENDER_SCALE_DETECTED: 'COD render scale detected',
  ARC_EXE_FLAGS: 'Arc Raiders EXE compatibility flags',
  ARC_CONFIG_FILES_WRITTEN: 'Arc Raiders config files written',
  ARC_SETTINGS_APPLIED: 'Arc Raiders settings applied',
};

function parseScriptCheck(line: string): ScriptCheck | null {
  const match = line.match(/^\[SQ_CHECK_(OK|FAIL|WARN):([A-Z0-9_]+)(?::(.*))?\]$/);
  if (!match) return null;
  return {
    key: match[2],
    status: match[1] === 'OK' ? 'ok' : (match[1] === 'FAIL' ? 'fail' : 'warn'),
    detail: (match[3] || '').trim(),
  };
}

function mergeScriptCheck(checks: Record<string, ScriptCheck>, next: ScriptCheck) {
  const current = checks[next.key];
  if (!current) {
    checks[next.key] = next;
    return;
  }

  const priority: Record<CheckStatus, number> = { fail: 3, warn: 2, ok: 1 };
  if (priority[next.status] >= priority[current.status]) {
    checks[next.key] = next;
  }
}

function summarizeScriptChecks(log: RunLogFn, checks: Record<string, ScriptCheck>, script: string): { hasFailures: boolean; failedKeys: string[] } {
  const values = Object.values(checks);
  if (values.length === 0) {
    return { hasFailures: false, failedKeys: [] };
  }

  log('start', `Verification summary (${script}):`, {
    component: 'Validation',
    action: 'validation-start',
    script,
  });

  const ordered = values.sort((a, b) => a.key.localeCompare(b.key));
  const failedKeys: string[] = [];

  for (const check of ordered) {
    const label = CHECK_LABELS[check.key] || check.key;
    const suffix = check.detail ? ` (${check.detail})` : '';
    if (check.status === 'ok') {
      log('success', `${label}: PASS${suffix}`, {
        component: 'Validation',
        action: 'validation-item',
        script,
        success: true,
      });
      continue;
    }

    if (check.status === 'warn') {
      log('warning', `${label}: WARN${suffix}`, {
        component: 'Validation',
        action: 'validation-item',
        script,
        errorCode: `CHECK_WARN_${check.key}`,
      });
      continue;
    }

    failedKeys.push(check.key);
    log('error', `${label}: FAIL${suffix}`, {
      component: 'Validation',
      action: 'validation-item',
      script,
      success: false,
      errorCode: `CHECK_FAIL_${check.key}`,
    });
  }

  return { hasFailures: failedKeys.length > 0, failedKeys };
}

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

interface RestorePointOptions {
  mode: 'auto' | 'manual';
}

interface RestorePointResult {
  success: boolean;
  errors: string[];
}

async function createSystemRestorePoint(log: RunLogFn, options: RestorePointOptions): Promise<RestorePointResult> {
  const isManual = options.mode === 'manual';

  log('start', isManual
    ? 'Creating system restore point on demand...'
    : 'Creating system restore point before applying changes...', {
    component: 'Safety',
    action: isManual ? 'restore-point-manual-start' : 'restore-point-start',
  });

  const result = await runPowerShellCommand(AUTO_RESTORE_POINT_SCRIPT, (line) => {
    log('info', line, {
      component: 'Safety',
      action: isManual ? 'restore-point-manual-output' : 'restore-point-output',
    });
  });

  if (!result.success) {
    const errorText = result.errors.join(' | ') || 'Unknown restore point error';
    const failureMessage = isManual
      ? `Manual restore point creation failed. ${errorText}`
      : `Restore point failed. No changes were applied. ${errorText}`;
    log('error', failureMessage, {
      component: 'Safety',
      action: isManual ? 'restore-point-manual-failed' : 'restore-point-failed',
      success: false,
      errorCode: 'RESTORE_POINT_FAILED',
    });
    void trackFailureStage('restore-point', errorText);
    return { success: false, errors: result.errors };
  }

  log('success', isManual
    ? 'System restore point created successfully (manual).'
    : 'System restore point created successfully.', {
    component: 'Safety',
    action: isManual ? 'restore-point-manual-success' : 'restore-point-success',
    success: true,
  });
  return { success: true, errors: [] };
}

async function ensureSystemRestorePoint(log: RunLogFn): Promise<boolean> {
  const result = await createSystemRestorePoint(log, { mode: 'auto' });
  return result.success;
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
      SENSEQUALITY_SKIP_INTERNAL_RESTORE_POINT: '1',
      MONITOR_WIDTH: String(config.monitorWidth),
      MONITOR_HEIGHT: String(config.monitorHeight),
      MONITOR_REFRESH: String(config.monitorRefresh),
      NVIDIA_GPU: config.nvidiaGpu ? '1' : '0',
      CS2_STRETCHED: config.cs2Stretched ? '1' : '0',
    };

    if (id === 'game-arcraiders') {
      try {
        const detectedGames = await detectInstalledGames();
        const arcGame = detectedGames.find((game) => game.id === 'arcraiders' && !!game.path);
        if (arcGame?.path) {
          envVars.ARC_RAIDERS_PATH = arcGame.path;
        }
      } catch {}
    }

    log('start', `Run started for optimization: ${id}`, {
      component: 'Run',
      action: 'run-start',
    });
    if (config.restorePointEnabled !== false) {
      const restorePointReady = await ensureSystemRestorePoint(log);
      if (!restorePointReady) {
        return { success: false, errors: ['Failed to create restore point.'] };
      }
    } else {
      log('info', 'Automatic restore point is disabled. Continuing without restore point.', {
        component: 'Safety',
        action: 'restore-point-skipped',
      });
    }

    log('start', `Running: ${id}`, {
      component: 'Optimization',
      action: 'script-start',
      script: mapping.script,
    });
    const scriptChecks: Record<string, ScriptCheck> = {};
    const result = await runPowerShellScript(scriptPath, envVars, (line) => {
      const check = parseScriptCheck(line);
      if (check) {
        mergeScriptCheck(scriptChecks, check);
        return;
      }
      log('info', line, {
        component: 'Optimization',
        action: 'script-output',
        script: mapping.script,
      });
    });

    const validationSummary = summarizeScriptChecks(log, scriptChecks, mapping.script);
    const finalSuccess = result.success && !validationSummary.hasFailures;

    log(finalSuccess ? 'success' : 'error',
      finalSuccess ? `Completed: ${id}` : `Failed: ${id}`,
      {
        component: 'Optimization',
        action: 'script-exit',
        script: mapping.script,
        success: finalSuccess,
        errorCode: finalSuccess
          ? null
          : (result.success ? 'SCRIPT_VALIDATION_FAILED' : `SCRIPT_EXIT_${result.exitCode}`),
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
    const combinedErrors = [...result.errors];
    if (validationSummary.hasFailures) {
      combinedErrors.push(`Validation failed: ${validationSummary.failedKeys.join(', ')}`);
    }
    log('complete', `Run finished for ${id}.`, {
      component: 'Summary',
      action: 'run-finish',
      success: finalSuccess,
      errorCode: finalSuccess
        ? null
        : (result.success ? 'SCRIPT_VALIDATION_FAILED' : `SCRIPT_EXIT_${result.exitCode}`),
    });

    if (!finalSuccess) {
      const failureText = combinedErrors.join(' | ') || `Script exited with code ${result.exitCode}`;
      void trackFailureStage('script-exit', failureText, undefined, [id]);
    }

    return { success: finalSuccess, errors: combinedErrors };
  });

  // Run selected optimizations
  ipcMain.handle('optimize:runSelected', async (event, ids: string[], config: UserConfig) => {
    const startTime = Date.now();
    const win = BrowserWindow.fromWebContents(event.sender);
    const runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`;
    const runLogger = createRunLogger(win, runId);
    const log = runLogger.log;
    const results: Record<string, boolean> = {};
    const failureReasons: Record<string, string> = {};

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
      SENSEQUALITY_SKIP_INTERNAL_RESTORE_POINT: '1',
      MONITOR_WIDTH: String(config.monitorWidth),
      MONITOR_HEIGHT: String(config.monitorHeight),
      MONITOR_REFRESH: String(config.monitorRefresh),
      NVIDIA_GPU: config.nvidiaGpu ? '1' : '0',
      CS2_STRETCHED: config.cs2Stretched ? '1' : '0',
    };

    if (ids.includes('game-arcraiders')) {
      try {
        const detectedGames = await detectInstalledGames();
        const arcGame = detectedGames.find((game) => game.id === 'arcraiders' && !!game.path);
        if (arcGame?.path) {
          envVars.ARC_RAIDERS_PATH = arcGame.path;
        }
      } catch {}
    }

    log('start', `Run started for ${ids.length} optimization(s).`, {
      component: 'Run',
      action: 'run-start',
    });

    if (config.restorePointEnabled !== false) {
      const restorePointReady = await ensureSystemRestorePoint(log);
      if (!restorePointReady) {
        for (const id of ids) {
          results[id] = false;
          failureReasons[id] = 'Restore point creation failed before any changes were applied.';
        }
        log('complete', 'Aborted: restore point creation failed.', {
          component: 'Summary',
          action: 'run-abort',
          success: false,
          errorCode: 'RESTORE_POINT_FAILED',
        });
        return { success: false, results };
      }
    } else {
      log('info', 'Automatic restore point is disabled. Continuing without restore point.', {
        component: 'Safety',
        action: 'restore-point-skipped',
      });
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
        if (!results[id]) {
          const stderrHint = result.errors[0] || '';
          failureReasons[id] = stderrHint
            ? `Windows optimization section failed. ${stderrHint}`
            : 'Windows optimization section failed.';
        }
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
      if (!result.success) {
        const stderrHint = result.errors[0] || '';
        failureReasons[id] = stderrHint ? stderrHint : 'Script failed.';
      }
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
      const scriptChecks: Record<string, ScriptCheck> = {};
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        const check = parseScriptCheck(line);
        if (check) {
          mergeScriptCheck(scriptChecks, check);
          return;
        }
        log('info', line, {
          component: 'Game',
          action: 'script-output',
          script: mapping.script,
        });
      });

      const validationSummary = summarizeScriptChecks(log, scriptChecks, mapping.script);
      const finalSuccess = result.success && !validationSummary.hasFailures;
      const gameName = id.replace('game-', '');

      results[id] = finalSuccess;
      if (!finalSuccess) {
        const validationReason = validationSummary.hasFailures
          ? `Validation failed: ${validationSummary.failedKeys.join(', ')}`
          : '';
        const stderrHint = result.errors[0] || '';
        failureReasons[id] = [validationReason, stderrHint].filter(Boolean).join(' | ') || 'Game optimization failed.';
      }
      log(finalSuccess ? 'success' : 'error',
        finalSuccess ? `${gameName} optimized!` : `${gameName} had errors`,
        {
          component: 'Game',
          action: 'script-exit',
          script: mapping.script,
          success: finalSuccess,
          errorCode: finalSuccess
            ? null
            : (result.success ? 'SCRIPT_VALIDATION_FAILED' : `SCRIPT_EXIT_${result.exitCode}`),
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
      if (!finalSuccess) {
        const validationError = validationSummary.hasFailures
          ? [`Validation failed: ${validationSummary.failedKeys.join(', ')}`]
          : [];
        const failureText = [...result.errors, ...validationError].join(' | ') || `Script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, [id]);
      }
    }

    const allSuccess = Object.values(results).every(Boolean);
    const errorCount = Object.values(results).filter(v => !v).length;
    if (!allSuccess) {
      const failedIds = Object.keys(results).filter((id) => !results[id]);
      log('error', `Failed optimizations (${failedIds.length}):`, {
        component: 'Summary',
        action: 'run-failure-list',
        success: false,
        errorCode: 'RUN_PARTIAL_FAILURE',
      });
      for (const failedId of failedIds) {
        const reason = failureReasons[failedId] || 'No detailed error captured. Check script output above.';
        log('error', `${failedId}: ${reason}`, {
          component: 'Summary',
          action: 'run-failure-item',
          success: false,
          errorCode: 'RUN_ITEM_FAILED',
        });
      }
    }
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
  ipcMain.handle('safety:createRestorePoint', async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    const runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`;
    const runLogger = createRunLogger(win, runId);
    const log = runLogger.log;
    const result = await createSystemRestorePoint(log, { mode: 'manual' });
    return { success: result.success, errors: result.errors };
  });
  ipcMain.handle('diagnostics:export', () => exportDiagnosticsBundle());
}
