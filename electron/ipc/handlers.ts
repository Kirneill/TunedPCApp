import { IpcMain, BrowserWindow, app } from 'electron';
import { getSystemInfo } from './system-info';
import { detectInstalledGames } from './game-detection';
import { runPowerShellScript, runPowerShellCommand, getScriptPath } from './powershell';
import { trackOptimizationResult, trackFailureStage, sendRunDetail, buildHardwareInfo } from '../telemetry/telemetry';
import { GAMES } from '../../src/data/game-registry';
import { parseScriptCheck, mergeScriptCheck } from '../utils/sq-check';
import type { CheckStatus, ScriptCheck } from '../utils/sq-check';
import type { RestorePointInfo } from '../../src/types/index';
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

// Derived from the unified game registry -- no manual sync needed
const GAME_PATH_ENV_VARS: Record<string, string> = Object.fromEntries(
  GAMES.filter(g => g.pathEnvVar).map(g => [`game-${g.id}`, g.pathEnvVar!])
);

// Maps optimization IDs to script files and env var configurations
// Game entries are derived from the unified game registry
const SCRIPT_MAP: Record<string, { script: string; envPrefix?: string }> = {
  // Windows optimizations -- all handled by script 01, controlled by skip env vars
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
  'win-gpu-profile': { script: '13_GPU_Optimization.ps1' },
  'win-dns': { script: '21_Network_Optimization.ps1', envPrefix: 'DNS' },
  'win-net-adapter': { script: '21_Network_Optimization.ps1', envPrefix: 'NET_ADAPTER_TUNE' },
  'win-tcp-stack': { script: '21_Network_Optimization.ps1', envPrefix: 'TCP_STACK' },
  'win-net-throttle': { script: '21_Network_Optimization.ps1', envPrefix: 'NET_THROTTLE' },
  'win-memory': { script: '22_Memory_Optimization.ps1' },
  'win-timer-res': { script: '23_Latency_Reduction.ps1', envPrefix: 'TIMER_RES' },
  'win-power-throttle': { script: '23_Latency_Reduction.ps1', envPrefix: 'POWER_THROTTLE' },
  'win-priority-sep': { script: '23_Latency_Reduction.ps1', envPrefix: 'PRIORITY_SEP' },
  'win-dynamic-tick': { script: '23_Latency_Reduction.ps1', envPrefix: 'DYNAMIC_TICK' },
  'win-hpet': { script: '23_Latency_Reduction.ps1', envPrefix: 'HPET' },
  // Deep debloat (Lightweight OS Mode)
  'win-deep-debloat': { script: '30_Deep_Debloat.ps1' },
  'win-undo-debloat': { script: '31_Undo_Deep_Debloat.ps1' },
  // Windows Update mode actions
  'updates-off': { script: '09_Windows_Update_Off.ps1' },
  'updates-on': { script: '10_Windows_Update_On.ps1' },
  // Game optimizations -- derived from game registry
  ...Object.fromEntries(GAMES.map(g => [`game-${g.id}`, { script: g.script }])),
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

// Check labels: game-specific labels derived from registry, non-game labels kept here
const CHECK_LABELS: Record<string, string> = {
  // GPU profile labels (not game-specific, stay hardcoded)
  GPU_PROFILE_APPLIED: 'GPU driver profile import completed',
  GPU_PROFILE_POWER_MODE: 'GPU Power Management Mode set to Prefer Maximum Performance',
  GPU_PROFILE_TEXTURE_FILTER_QUALITY: 'GPU Texture Filtering Quality set to High Performance',
  GPU_PROFILE_BACKUP_CREATED: 'GPU profile backup exported',
  GPU_PROFILE_BACKUP_SKIPPED: 'GPU profile backup skipped',
  GPU_PROFILE_TOOL_MISSING: 'GPU profile tool executable available',
  GPU_PROFILE_PRESET_MISSING: 'GPU profile preset file available',
  GPU_PROFILE_AMD_NOT_IMPLEMENTED: 'AMD GPU auto-profile not implemented',
  GPU_PROFILE_PRESET_READY: 'GPU profile preset ready',
  GPU_PROFILE_TOOL_READY: 'GPU profile tool ready',
  GPU_PROFILE_TOOL_DOWNLOADED: 'GPU profile tool downloaded automatically',
  GPU_PROFILE_TOOL_DOWNLOAD_FAILED: 'GPU profile tool download failed',
  // Game check labels -- derived from game registry
  ...Object.fromEntries(GAMES.flatMap(g => Object.entries(g.checkLabels))),
};

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

function getGpuToolsPath(): string {
  return path.join(app.getPath('userData'), 'tools');
}

function getBundledGpuToolsPath(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'tools');
  }
  return path.join(app.getAppPath(), 'resources/tools');
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

# Remove the 24-hour cooldown between restore points
New-Item -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Type DWord -Value 0

# Ensure System Restore is enabled on the system drive
# Try PowerShell cmdlet first (Pro/Enterprise), fall back to WMI (Home)
try {
    Enable-ComputerRestore -Drive $Env:SystemDrive -ErrorAction Stop | Out-Null
} catch {
    try {
        ([wmiclass]"\\\\.\\root\\default:SystemRestore").Enable($Env:SystemDrive) | Out-Null
    } catch {
        Write-Warning "Could not enable System Restore: $_"
    }
}

$description = "SENSEQUALITY Auto Restore Point $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"

# Create the restore point
# Try PowerShell cmdlet first (Pro/Enterprise), fall back to WMI (Home)
try {
    Checkpoint-Computer -Description $description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
} catch {
    # 12 = MODIFY_SETTINGS, 100 = BEGIN_SYSTEM_CHANGE
    $result = ([wmiclass]"\\\\.\\root\\default:SystemRestore").CreateRestorePoint($description, 12, 100)
    if ($result.ReturnValue -ne 0) {
        throw "Failed to create restore point (WMI error code: $($result.ReturnValue))"
    }
}

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
    void trackFailureStage('restore-point', errorText).catch(err => {
      console.warn(`[telemetry] trackFailureStage failed: ${err instanceof Error ? err.message : err}`);
    });
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

/** Get the path to the bundled wallpaper image. */
function getWallpaperSource(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'wallpaper.png');
  }
  return path.join(app.getAppPath(), 'resources', 'wallpaper.png');
}

/** Marker file so the wallpaper is only set once (first successful optimization). */
function getWallpaperMarkerPath(): string {
  return path.join(app.getPath('userData'), 'wallpaper', '.wallpaper-set');
}

/** Copy bundled wallpaper to a persistent location and set it as the Windows desktop background.
 *  Only runs once (first successful optimization). Never throws -- errors are logged as warnings. */
async function setTunedPCWallpaper(log: RunLogFn): Promise<void> {
  try {
    // Only set wallpaper once -- skip if already done
    const markerPath = getWallpaperMarkerPath();
    if (fs.existsSync(markerPath)) return;

    const source = getWallpaperSource();
    if (!fs.existsSync(source)) {
      log('warning', 'Wallpaper image not found, skipping.', {
        component: 'Wallpaper',
        action: 'wallpaper-missing',
      });
      return;
    }

    // Copy to a persistent path so Windows can always reference it
    const destDir = path.join(app.getPath('userData'), 'wallpaper');
    fs.mkdirSync(destDir, { recursive: true });
    const destPath = path.join(destDir, 'TunedPC_Wallpaper.png');
    fs.copyFileSync(source, destPath);

    // Use PowerShell + P/Invoke to set the wallpaper via SystemParametersInfo
    const escapedPath = escapePowerShellSingleQuoted(destPath);
    const psScript = `
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

# Set wallpaper style to Fill (10) -- best for gaming wallpapers
Set-ItemProperty -Path 'HKCU:\\Control Panel\\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path 'HKCU:\\Control Panel\\Desktop' -Name TileWallpaper -Value '0'

# SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 0x03
[Wallpaper]::SystemParametersInfo(0x0014, 0, '${escapedPath}', 0x03) | Out-Null
Write-Output 'Wallpaper set successfully'
`;

    const result = await runPowerShellCommand(psScript, (line) => {
      log('info', line, {
        component: 'Wallpaper',
        action: 'wallpaper-output',
      });
    });

    if (result.success) {
      // Write marker so we don't overwrite the user's wallpaper on future runs
      fs.writeFileSync(markerPath, new Date().toISOString(), 'utf-8');
      log('success', 'TunedPC wallpaper applied!', {
        component: 'Wallpaper',
        action: 'wallpaper-set',
        success: true,
      });
    } else {
      log('warning', 'Could not set wallpaper. ' + (result.errors[0] || ''), {
        component: 'Wallpaper',
        action: 'wallpaper-failed',
      });
    }
  } catch (err) {
    log('warning', 'Could not set wallpaper: ' + (err instanceof Error ? err.message : String(err)), {
      component: 'Wallpaper',
      action: 'wallpaper-error',
    });
  }
}

/**
 * Detects installed games and populates envVars with paths for any games
 * in `requestedIds` that need path env vars (per GAME_PATH_ENV_VARS).
 * Logs a warning on failure but never throws.
 */
async function populateGamePathEnvVars(
  requestedIds: string[],
  envVars: Record<string, string>,
  log: RunLogFn,
): Promise<void> {
  const idsNeedingPaths = requestedIds.filter((id) => GAME_PATH_ENV_VARS[id]);
  if (idsNeedingPaths.length === 0) return;

  try {
    const detectedGames = await detectInstalledGames();
    for (const gameOptId of idsNeedingPaths) {
      const envKey = GAME_PATH_ENV_VARS[gameOptId];
      if (!envKey) continue;
      const gameId = gameOptId.replace('game-', '');
      const game = detectedGames.find((g) => g.id === gameId && !!g.path);
      if (game?.path) envVars[envKey] = game.path;
    }
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    log('warning', `Game path detection failed: ${errorText}`, {
      component: 'Game',
      action: 'game-path-detection-failed',
    });
  }
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

const LIST_RESTORE_POINTS_SCRIPT = `
$ErrorActionPreference = 'Stop'

# Try PowerShell cmdlet first (Pro/Enterprise), fall back to WMI (Home)
try {
    $points = Get-ComputerRestorePoint -ErrorAction Stop
} catch {
    $points = Get-WmiObject -Namespace "root\\default" -Class SystemRestorePoint -ErrorAction Stop
}

$result = @()
foreach ($p in $points) {
    # WMI returns CreationTime as a DMTF string; cmdlet returns a DateTime
    if ($p.CreationTime -is [string]) {
        $dt = [System.Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime)
    } else {
        $dt = $p.CreationTime
    }
    $result += [pscustomobject]@{
        SequenceNumber = $p.SequenceNumber
        Description    = $p.Description
        CreatedAt      = $dt.ToString('o')
        RestorePointType = switch ($p.RestorePointType) {
            0  { 'APPLICATION_INSTALL' }
            1  { 'APPLICATION_UNINSTALL' }
            10 { 'DEVICE_DRIVER_INSTALL' }
            12 { 'MODIFY_SETTINGS' }
            13 { 'CANCELLED_OPERATION' }
            default { "TYPE_$($p.RestorePointType)" }
        }
    }
}

$result | ConvertTo-Json -Compress
`;

async function listSystemRestorePoints(): Promise<{ points: RestorePointInfo[]; error?: string }> {
  // NOTE: runPowerShellCommand() always resolves (never rejects).
  // The catch block is defensive only. Primary error handling is via result.success.
  try {
    const lines: string[] = [];
    const result = await runPowerShellCommand(LIST_RESTORE_POINTS_SCRIPT, (line) => {
      lines.push(line);
    });

    if (!result.success) {
      const errorText = result.errors.join(' | ') || 'PowerShell exited with a non-zero code';
      console.warn('[restore-point] Failed to list restore points:', errorText);
      return { points: [], error: `Could not retrieve restore points: ${errorText}` };
    }

    const raw = lines.join('');
    if (!raw.trim()) return { points: [] };

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (parseErr) {
      const parseMsg = parseErr instanceof Error ? parseErr.message : String(parseErr);
      console.warn(`[restore-point] Failed to parse JSON: ${parseMsg}. Raw: ${raw.slice(0, 200)}`);
      return { points: [], error: 'Restore point data was unreadable.' };
    }

    // PowerShell ConvertTo-Json returns a single object if there's only one item
    const arr = Array.isArray(parsed) ? parsed : [parsed];

    const points = arr
      .filter((p: Record<string, unknown>) =>
        typeof p.SequenceNumber === 'number' &&
        typeof p.Description === 'string' &&
        typeof p.CreatedAt === 'string' &&
        typeof p.RestorePointType === 'string'
      )
      .map((p: { SequenceNumber: number; Description: string; CreatedAt: string; RestorePointType: string }) => ({
        sequenceNumber: p.SequenceNumber,
        description: p.Description,
        createdAt: p.CreatedAt,
        type: p.RestorePointType,
      }));

    return { points };
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[restore-point] Failed to list restore points: ${errorText}`);
    return { points: [], error: `Unexpected error: ${errorText}` };
  }
}

async function launchSystemRestoreUI(): Promise<{ success: boolean; error?: string }> {
  // NOTE: runPowerShellCommand() always resolves (never rejects).
  // The catch block is defensive only. Primary error handling is via result.success.
  try {
    const result = await runPowerShellCommand('Start-Process rstrui.exe', () => {});
    if (!result.success) {
      const errorText = result.errors.join(' | ') || 'System Restore UI failed to launch';
      console.warn(`[restore-point] Failed to launch System Restore UI: ${errorText}`);
      return { success: false, error: errorText };
    }
    return { success: true };
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[restore-point] Failed to launch System Restore UI: ${errorText}`);
    return { success: false, error: errorText };
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
      GPU_TOOLS_PATH: getGpuToolsPath(),
      GPU_BUNDLED_TOOLS_PATH: getBundledGpuToolsPath(),
    };

    await populateGamePathEnvVars([id], envVars, log);

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
      void trackFailureStage('script-exit', failureText, undefined, [id]).catch(err => {
        console.warn(`[telemetry] trackFailureStage failed: ${err instanceof Error ? err.message : err}`);
      });
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
    // - IDs with envPrefix are grouped by script (run once with SKIP_* env flags)
    // - IDs without envPrefix run their own scripts standalone
    const windowsIds = ids.filter(id => id.startsWith('win-'));
    const groupedScripts: Record<string, string[]> = {};
    const windowsStandaloneIds: string[] = [];
    for (const id of windowsIds) {
      const mapping = SCRIPT_MAP[id];
      if (!mapping) continue;
      if (mapping.envPrefix) {
        (groupedScripts[mapping.script] ??= []).push(id);
      } else {
        windowsStandaloneIds.push(id);
      }
    }
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
      GPU_TOOLS_PATH: getGpuToolsPath(),
      GPU_BUNDLED_TOOLS_PATH: getBundledGpuToolsPath(),
    };

    await populateGamePathEnvVars(ids, envVars, log);

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

    // Run grouped Windows scripts (each grouped script runs once with SKIP_* env flags)
    for (const [groupScript, groupIds] of Object.entries(groupedScripts)) {
      // Set SKIP flags: enabled sections get '0', all other sections in the same script get '1'
      const allKeysForScript = Object.keys(SCRIPT_MAP).filter(
        k => k.startsWith('win-') && SCRIPT_MAP[k].script === groupScript && SCRIPT_MAP[k].envPrefix
      );
      const groupEnvVars = { ...envVars };
      for (const key of allKeysForScript) {
        const prefix = SCRIPT_MAP[key]?.envPrefix;
        if (prefix) {
          groupEnvVars[`SKIP_${prefix}`] = groupIds.includes(key) ? '0' : '1';
        }
      }

      // Track per-section results via structured markers from PowerShell stdout
      const sectionResults: Record<string, boolean> = {};

      log('start', `Applying ${groupScript}...`, {
        component: 'Windows',
        action: 'script-start',
        script: groupScript,
      });
      const scriptPath = getScriptPath(groupScript);
      const result = await runPowerShellScript(scriptPath, groupEnvVars, (line) => {
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
          // Skipped sections are not failures -- don't track them
        } else {
          // Regular log line -- forward to UI
          log('info', line, {
            component: 'Windows',
            action: 'script-output',
            script: groupScript,
          });
        }
      });

      // Assign per-section results; fall back to overall script result for sections without markers
      for (const id of groupIds) {
        results[id] = sectionResults[id] !== undefined ? sectionResults[id] : result.success;
        if (!results[id]) {
          const stderrHint = result.errors[0] || '';
          failureReasons[id] = stderrHint
            ? `Optimization section failed. ${stderrHint}`
            : 'Optimization section failed.';
        }
      }

      const failed = groupIds.filter(id => !results[id]);
      if (failed.length === 0) {
        log('success', `${groupScript} applied!`, {
          component: 'Windows',
          action: 'script-exit',
          script: groupScript,
          success: true,
        });
      } else {
        log('error',
          `${groupScript}: ${failed.length} section(s) had errors`,
          {
            component: 'Windows',
            action: 'script-exit',
            script: groupScript,
            success: false,
            errorCode: `SCRIPT_EXIT_${result.exitCode}`,
          }
        );
      }

      if (result.errors.length > 0) {
        log('warning', `Script stderr captured (${result.errors.length} line(s)).`, {
          component: 'Windows',
          action: 'script-stderr',
          script: groupScript,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
        });
      }

      if (!result.success) {
        const failureText = result.errors.join(' | ') || `Script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, groupIds).catch(err => {
          console.warn(`[telemetry] trackFailureStage failed: ${err instanceof Error ? err.message : err}`);
        });
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
      const scriptChecks: Record<string, ScriptCheck> = {};
      const result = await runPowerShellScript(scriptPath, envVars, (line) => {
        const check = parseScriptCheck(line);
        if (check) {
          mergeScriptCheck(scriptChecks, check);
          return;
        }
        log('info', line, {
          component: 'Windows',
          action: 'script-output',
          script: mapping.script,
        });
      });

      const validationSummary = summarizeScriptChecks(log, scriptChecks, mapping.script);
      const finalSuccess = result.success && !validationSummary.hasFailures;
      results[id] = finalSuccess;
      if (!finalSuccess) {
        const validationReason = validationSummary.hasFailures
          ? `Validation failed: ${validationSummary.failedKeys.join(', ')}`
          : '';
        const stderrHint = result.errors[0] || '';
        failureReasons[id] = [validationReason, stderrHint].filter(Boolean).join(' | ') || 'Script failed.';
      }
      log(finalSuccess ? 'success' : 'error',
        finalSuccess ? `${id} applied!` : `${id} had errors`,
        {
          component: 'Windows',
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
          component: 'Windows',
          action: 'script-stderr',
          script: mapping.script,
          success: result.success,
          errorCode: result.success ? null : `SCRIPT_STDERR_${result.exitCode}`,
        });
      }
      if (!finalSuccess) {
        const validationError = validationSummary.hasFailures
          ? `Validation failed: ${validationSummary.failedKeys.join(', ')}`
          : '';
        const failureText = [validationError, ...result.errors].filter(Boolean).join(' | ') || `Script exited with code ${result.exitCode}`;
        void trackFailureStage('script-exit', failureText, undefined, [id]).catch(err => {
          console.warn(`[telemetry] trackFailureStage failed: ${err instanceof Error ? err.message : err}`);
        });
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
        void trackFailureStage('script-exit', failureText, undefined, [id]).catch(err => {
          console.warn(`[telemetry] trackFailureStage failed: ${err instanceof Error ? err.message : err}`);
        });
      }
    }

    const allSuccess = Object.values(results).every(Boolean);
    const errorCount = Object.values(results).filter(v => !v).length;

    // Set TunedPC wallpaper after a successful optimization run
    if (allSuccess) {
      await setTunedPCWallpaper(log);
    }

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

    // Telemetry — detached IIFE so it never delays the IPC response.
    // Snapshot mutable objects before the IIFE runs asynchronously after return.
    const telemetryResults = { ...results };
    const telemetryReasons = { ...failureReasons };
    void (async () => {
      try {
        const sysInfo = await getSystemInfo();
        const hw = buildHardwareInfo(sysInfo);
        trackOptimizationResult(hw, ids, allSuccess, Date.now() - startTime, errorCount, {
          monitor_resolution: `${config.monitorWidth}x${config.monitorHeight}`,
          monitor_refresh_hz: config.monitorRefresh,
          run_id: runId,
        }).catch(err => {
          console.warn(`[telemetry] trackOptimizationResult failed: ${err instanceof Error ? err.message : err}`);
        });

        // Per-setting granular results
        for (const [settingId, success] of Object.entries(telemetryResults)) {
          sendRunDetail({
            run_id: runId,
            setting_id: settingId,
            success,
            failure_reason: telemetryReasons[settingId] || null,
          }).catch(err => {
            console.warn(`[telemetry] sendRunDetail failed for ${settingId}: ${err instanceof Error ? err.message : err}`);
          });
        }
      } catch (err) {
        const errorText = err instanceof Error ? err.message : String(err);
        log('warning', `Telemetry tracking failed: ${errorText}`, {
          component: 'Telemetry',
          action: 'telemetry-failed',
          errorCode: 'TELEMETRY_SEND_FAILED',
        });
      }
    })();

    return { success: allSuccess, results };
  });

  // System Restore Points
  ipcMain.handle('restore-point:list', async () => {
    return listSystemRestorePoints();
  });
  ipcMain.handle('restore-point:launch', async () => {
    return launchSystemRestoreUI();
  });
  ipcMain.handle('safety:createRestorePoint', async (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    const runId = `run-${Date.now()}-${randomUUID().slice(0, 8)}`;
    const runLogger = createRunLogger(win, runId);
    const log = runLogger.log;
    const result = await createSystemRestorePoint(log, { mode: 'manual' });
    return { success: result.success, errors: result.errors };
  });

  // Diagnostics
  ipcMain.handle('diagnostics:export', () => exportDiagnosticsBundle());

  // Debloat manifest check
  ipcMain.handle('debloat:checkManifest', async () => {
    const manifestPath = path.join(process.env.APPDATA || '', 'SENSEQUALITY', 'debloat-manifest.json');
    try {
      if (fs.existsSync(manifestPath)) {
        const content = fs.readFileSync(manifestPath, 'utf-8');
        const manifest = JSON.parse(content);
        return {
          exists: true,
          timestamp: manifest.Timestamp || null,
          servicesChanged: Array.isArray(manifest.Services) ? manifest.Services.length : 0,
          appxRemoved: Array.isArray(manifest.AppxRemoved) ? manifest.AppxRemoved.length : 0,
          tasksDisabled: Array.isArray(manifest.Tasks) ? manifest.Tasks.length : 0,
          capabilitiesRemoved: Array.isArray(manifest.Capabilities) ? manifest.Capabilities.length : 0,
        };
      }
      return { exists: false };
    } catch {
      return { exists: false };
    }
  });
}
