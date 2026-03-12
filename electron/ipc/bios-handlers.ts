import { IpcMain, BrowserWindow, app } from 'electron';
import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { runPowerShellScript, getScriptPath } from './powershell';
import { parseNvram, matchProfile, patchNvramText } from './scewin-parser';
import { provisionScewin, cancelProvision } from './scewin-provisioner';
import { BIOS_PROFILES } from '../../src/data/bios-profiles';
import { checkRamSafety, filterProfileSettings } from '../../src/data/ram-safety';
import { getSession } from '../auth/auth';
import type { BiosDetectionResult } from '../../src/types/index';

const execFileAsync = promisify(execFile);

/** Run SCEWIN, tolerating non-zero exit codes (some versions exit 1 even on success). */
async function runScewin(scewinDir: string, args: string[]): Promise<void> {
  try {
    await execFileAsync(path.join(scewinDir, 'SCEWIN_64.exe'), args, {
      cwd: scewinDir, timeout: 60000, windowsHide: true,
    });
  } catch (err) {
    // SCEWIN often exits with code 1 but still produces valid output.
    // Only re-throw if it's not an exit-code error (e.g. ENOENT, timeout).
    const execErr = err as { code?: string | number; killed?: boolean; stderr?: string };
    if (typeof execErr.code === 'string' || execErr.killed) {
      throw err;
    }
    // Non-zero exit code — log it; callers verify success via output files + log.
    console.warn(`[bios] SCEWIN exited with code ${execErr.code} (args: ${args.join(' ')})${execErr.stderr ? `. Stderr: ${execErr.stderr}` : ''}`);
  }
}

const SCEWIN_FILES = ['SCEWIN_64.exe', 'amifldrv64.sys', 'amigendrv64.sys'];

function getBackupsDir(): string {
  return path.join(app.getPath('userData'), 'bios-backups');
}

function getUserScewinDir(): string {
  return path.join(app.getPath('userData'), 'scewin');
}

function getBundledScewinDir(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'scewin');
  }
  return path.join(app.getAppPath(), 'resources', 'scewin');
}

/** Find the directory containing SCEWIN binaries, preferring user data over bundled. */
function getScewinDir(): string | null {
  const userDir = getUserScewinDir();
  if (fs.existsSync(path.join(userDir, 'SCEWIN_64.exe'))) return userDir;

  const bundledDir = getBundledScewinDir();
  if (fs.existsSync(path.join(bundledDir, 'SCEWIN_64.exe'))) return bundledDir;

  return null;
}

/** Delete stale SCEWIN log so checkScewinLog only sees errors from the current operation. */
async function clearScewinLog(scewinDir: string): Promise<void> {
  try { await fsp.unlink(path.join(scewinDir, 'log-file.txt')); } catch { /* ignore ENOENT */ }
}

/** Check SCEWIN log file for errors after an operation. */
async function checkScewinLog(scewinDir: string): Promise<string | null> {
  const logPath = path.join(scewinDir, 'log-file.txt');
  try {
    const content = await fsp.readFile(logPath, 'utf-8');
    // Match explicit error markers — avoid false positives on "NO_ERROR", "ERROR_SUCCESS", etc.
    if (/\bERROR\b(?!\s*_?SUCCESS|_?NONE|_?CODE_?NONE)/i.test(content)) {
      return content.trim();
    }
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') {
      return `Failed to read SCEWIN log: ${(e as Error).message}`;
    }
  }
  return null;
}

function timestamp(): string {
  return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

/** Verify the current user has a 'pro' tier. Returns error string if not authorized.
 *  Bypasses check in dev mode. Allows offline usage only for network errors. */
async function requirePro(): Promise<string | null> {
  // Skip tier check in dev mode so developers can test the full flow
  if (!app.isPackaged) return null;

  try {
    const session = await getSession();
    if (!session || session.user.tier !== 'pro') {
      return 'Pro subscription required for BIOS automation';
    }
    return null;
  } catch (err) {
    // Only allow offline access for network-related errors
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes('fetch') || msg.includes('network') || msg.includes('ENOTFOUND') || msg.includes('ETIMEDOUT')) {
      console.warn('[bios] Network error during tier check, allowing offline access:', msg);
      return null;
    }
    console.error('[bios] Unexpected error in requirePro:', err);
    return 'Unable to verify subscription status. Please restart the app.';
  }
}

/** Cached detection result for RAM safety checks in preview/apply handlers. */
let lastDetection: BiosDetectionResult | null = null;

/** Run the BIOS detection script and cache the result. Shared by the IPC handler and the null-guard in preview/apply. */
async function runBiosScan(): Promise<{
  success: boolean;
  data: BiosDetectionResult | null;
  error?: string;
}> {
  try {
    const scriptPath = getScriptPath('Detect-BiosState.ps1');
    const result = await runPowerShellScript(scriptPath);

    if (!result.success) {
      return {
        success: false,
        data: null,
        error: result.errors.join(' | ') || `Script exited with code ${result.exitCode}`,
      };
    }

    const fullOutput = result.output.join('');
    const jsonMatch = fullOutput.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { success: false, data: null, error: 'No JSON output from detection script' };
    }

    const data = JSON.parse(jsonMatch[0]) as BiosDetectionResult;
    lastDetection = data;
    return { success: true, data };
  } catch (err) {
    return {
      success: false,
      data: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

/** Ensure lastDetection is populated. Auto-scans if null. Returns error string on failure. */
async function ensureDetection(): Promise<string | null> {
  if (lastDetection) return null;
  const scanResult = await runBiosScan();
  if (!scanResult.success) {
    return `Auto-scan failed: ${scanResult.error || 'unknown error'}. Please run a manual BIOS scan first.`;
  }
  return null;
}

export function registerBiosHandlers(ipcMain: IpcMain, getWindow?: () => BrowserWindow | null) {
  // ─── Phase 2: System Detection ────────────────────────────

  ipcMain.handle('bios:scan', async () => runBiosScan());

  // ─── Phase 3: SCEWIN Automation (Pro only) ─────────────────

  ipcMain.handle('bios:provisionStatus', async () => {
    const scewinDir = getScewinDir();
    if (scewinDir) {
      const missing = SCEWIN_FILES.filter(f => !fs.existsSync(path.join(scewinDir, f)));
      return { ready: missing.length === 0, missingFiles: missing, scewinDir };
    }
    return { ready: false, missingFiles: [...SCEWIN_FILES], scewinDir: getUserScewinDir() };
  });

  ipcMain.handle('bios:export', async () => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, error: tierError };
      const scewinDir = getScewinDir();
      if (!scewinDir) return { success: false, error: 'SCEWIN not found. Place binaries in: ' + getUserScewinDir() };

      const outFile = 'nvram.txt';
      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/o', '/s', outFile, '/d']);

      const logError = await checkScewinLog(scewinDir);
      if (logError) return { success: false, error: `SCEWIN error: ${logError}` };

      const nvramPath = path.join(scewinDir, outFile);
      if (!fs.existsSync(nvramPath)) return { success: false, error: 'SCEWIN export file not created' };

      const text = await fsp.readFile(nvramPath, 'utf-8');
      const settings = parseNvram(text);

      if (settings.length === 0) {
        return {
          success: false,
          error: 'No BIOS settings found. Your motherboard may require "Publish HII Resources" enabled in BIOS. Check: ASUS (Setup > Tool), MSI (works by default), Gigabyte (may need BIOS mod), ASRock (Security tab).',
        };
      }

      return { success: true, settings, settingsCount: settings.length };
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  });

  ipcMain.handle('bios:backup', async () => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, error: tierError };
      const scewinDir = getScewinDir();
      if (!scewinDir) return { success: false, error: 'SCEWIN not found' };

      const backupsDir = getBackupsDir();
      await fsp.mkdir(backupsDir, { recursive: true });

      const ts = timestamp();
      const backupName = `backup_${ts}.txt`;

      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/o', '/s', backupName, '/d']);

      const logError = await checkScewinLog(scewinDir);
      if (logError) return { success: false, error: `SCEWIN backup error: ${logError}` };

      const src = path.join(scewinDir, backupName);
      if (!fs.existsSync(src)) return { success: false, error: 'Backup file not created' };

      const dst = path.join(backupsDir, backupName);
      await fsp.copyFile(src, dst);
      // Clean up from scewin dir
      await fsp.unlink(src).catch(() => {});

      return { success: true, path: dst, filename: backupName };
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  });

  ipcMain.handle('bios:listBackups', async () => {
    try {
      const backupsDir = getBackupsDir();
      await fsp.mkdir(backupsDir, { recursive: true });
      const files = await fsp.readdir(backupsDir);
      const backups = [];

      for (const f of files) {
        if (!f.startsWith('backup_') || !f.endsWith('.txt')) continue;
        const fullPath = path.join(backupsDir, f);
        const stat = await fsp.stat(fullPath);
        backups.push({
          filename: f,
          timestamp: f.replace('backup_', '').replace('.txt', '').replace(/-/g, ':'),
          sizeBytes: stat.size,
        });
      }

      return backups.sort((a, b) => b.filename.localeCompare(a.filename));
    } catch {
      return [];
    }
  });

  ipcMain.handle('bios:previewProfile', async (_, profileId: string) => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, error: tierError };
      const profile = BIOS_PROFILES.find(p => p.id === profileId);
      if (!profile) return { success: false, error: `Unknown profile: ${profileId}` };

      const scewinDir = getScewinDir();
      if (!scewinDir) return { success: false, error: 'SCEWIN not found' };

      // Export current NVRAM
      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/o', '/s', 'nvram.txt', '/d']);

      const logError = await checkScewinLog(scewinDir);
      if (logError) return { success: false, error: `SCEWIN error: ${logError}` };

      const nvramPath = path.join(scewinDir, 'nvram.txt');
      if (!fs.existsSync(nvramPath)) return { success: false, error: 'SCEWIN export failed' };

      const text = await fsp.readFile(nvramPath, 'utf-8');
      const nvram = parseNvram(text);

      if (nvram.length === 0) {
        return { success: false, error: 'No BIOS settings found. Enable "Publish HII Resources" in BIOS.' };
      }

      // Auto-scan if no cached detection (ensures RAM safety has real hardware data)
      const scanError = await ensureDetection();
      if (scanError) return { success: false, error: scanError };

      // Apply RAM safety rules — filter out dangerous settings
      const safety = checkRamSafety(lastDetection);
      const safeSettings = filterProfileSettings(profile.settings, safety);

      const changes = matchProfile(nvram, safeSettings);
      return { success: true, changes };
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  });

  ipcMain.handle('bios:applyProfile', async (_, profileId: string) => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, changes: [], error: tierError };
      const profile = BIOS_PROFILES.find(p => p.id === profileId);
      if (!profile) return { success: false, changes: [], error: `Unknown profile: ${profileId}` };

      const scewinDir = getScewinDir();
      if (!scewinDir) return { success: false, changes: [], error: 'SCEWIN not found' };

      // 1. Auto-backup first
      const backupsDir = getBackupsDir();
      await fsp.mkdir(backupsDir, { recursive: true });
      const ts = timestamp();
      const backupName = `backup_${ts}.txt`;

      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/o', '/s', backupName, '/d']);

      const backupLogError = await checkScewinLog(scewinDir);
      if (backupLogError) {
        return { success: false, changes: [], error: `Auto-backup failed: ${backupLogError}` };
      }

      const backupSrc = path.join(scewinDir, backupName);
      if (!fs.existsSync(backupSrc)) {
        return { success: false, changes: [], error: 'Auto-backup failed: export file not created' };
      }

      const backupDst = path.join(backupsDir, backupName);
      await fsp.copyFile(backupSrc, backupDst);
      await fsp.unlink(backupSrc).catch(() => {});

      // 2. Export current NVRAM for parsing
      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/o', '/s', 'nvram.txt', '/d']);

      const exportLogError = await checkScewinLog(scewinDir);
      if (exportLogError) {
        return { success: false, changes: [], backupPath: backupDst, error: `NVRAM export failed: ${exportLogError}` };
      }

      const nvramPath = path.join(scewinDir, 'nvram.txt');
      if (!fs.existsSync(nvramPath)) {
        return { success: false, changes: [], backupPath: backupDst, error: 'NVRAM export file not created' };
      }
      const originalText = await fsp.readFile(nvramPath, 'utf-8');
      const nvram = parseNvram(originalText);

      if (nvram.length === 0) {
        return { success: false, changes: [], backupPath: backupDst, error: 'No settings found in NVRAM export' };
      }

      // 3. Auto-scan if no cached detection (ensures RAM safety has real hardware data)
      const scanError = await ensureDetection();
      if (scanError) return { success: false, changes: [], backupPath: backupDst, error: scanError };

      const safety = checkRamSafety(lastDetection);
      const safeSettings = filterProfileSettings(profile.settings, safety);
      const changes = matchProfile(nvram, safeSettings);
      const appliedCount = changes.filter(c => c.applied).length;

      if (appliedCount === 0) {
        return { success: true, changes, backupPath: backupDst, error: 'All settings already at target values' };
      }

      const patchedText = patchNvramText(originalText, nvram, changes);
      const patchedPath = path.join(scewinDir, 'nvram_patched.txt');
      await fsp.writeFile(patchedPath, patchedText, 'utf-8');

      // 4. Import patched settings
      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/i', '/s', 'nvram_patched.txt', '/q']);

      const logError = await checkScewinLog(scewinDir);
      if (logError) {
        return { success: false, changes, backupPath: backupDst, error: `SCEWIN import error: ${logError}` };
      }

      return { success: true, changes, backupPath: backupDst };
    } catch (err) {
      return {
        success: false,
        changes: [],
        error: err instanceof Error ? err.message : String(err),
      };
    }
  });

  ipcMain.handle('bios:restore', async (_, backupFilename: string) => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, error: tierError };
      // Sanitize: strip path separators, allow only expected pattern
      const sanitized = path.basename(backupFilename);
      if (sanitized !== backupFilename || !sanitized.startsWith('backup_') || !sanitized.endsWith('.txt')) {
        return { success: false, error: 'Invalid backup filename' };
      }

      const scewinDir = getScewinDir();
      if (!scewinDir) return { success: false, error: 'SCEWIN not found' };

      const backupsDir = getBackupsDir();
      const backupPath = path.join(backupsDir, sanitized);
      if (!path.resolve(backupPath).startsWith(path.resolve(backupsDir))) {
        return { success: false, error: 'Invalid backup path' };
      }
      if (!fs.existsSync(backupPath)) return { success: false, error: `Backup not found: ${sanitized}` };

      const restoreName = 'restore.txt';
      await fsp.copyFile(backupPath, path.join(scewinDir, restoreName));

      await clearScewinLog(scewinDir);
      await runScewin(scewinDir, ['/i', '/s', restoreName, '/q']);

      const logError = await checkScewinLog(scewinDir);
      // Clean up temp restore file
      await fsp.unlink(path.join(scewinDir, restoreName)).catch(() => {});
      if (logError) return { success: false, error: `SCEWIN restore error: ${logError}` };

      return { success: true };
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  });

  // ─── SCEWIN Auto-Provisioning ─────────────────────────────

  ipcMain.handle('bios:provisionScewin', async (event) => {
    try {
      const tierError = await requirePro();
      if (tierError) return { success: false, error: tierError };
      const outputDir = getUserScewinDir();
      await provisionScewin(outputDir, (progress) => {
        // Send progress to the renderer that initiated the request
        try { event.sender.send('bios:provisionProgress', progress); } catch { /* window may be closed */ }
        // Also broadcast to main window if different
        const win = getWindow?.();
        if (win && !win.isDestroyed() && win.webContents !== event.sender) {
          try { win.webContents.send('bios:provisionProgress', progress); } catch { /* ignore */ }
        }
      });
      return { success: true };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg === 'Cancelled') return { success: false, error: 'Cancelled by user' };
      return { success: false, error: msg };
    }
  });

  ipcMain.handle('bios:cancelProvision', async () => {
    cancelProvision();
    return { success: true };
  });
}
