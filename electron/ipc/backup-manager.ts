import * as fs from 'fs';
import * as path from 'path';
import { runPowerShellScript, getScriptPath } from './powershell';

export interface BackupInfo {
  name: string;
  path: string;
  date: string;
  files: string[];
}

function getBackupBaseDir(): string {
  return path.join(process.env.USERPROFILE || 'C:\\Users\\Default', 'Documents');
}

export async function listBackups(): Promise<BackupInfo[]> {
  const baseDir = getBackupBaseDir();
  const backups: BackupInfo[] = [];

  try {
    const entries = fs.readdirSync(baseDir);
    const backupDirs = entries.filter(e =>
      e.startsWith('GamingOptimization_Backup_') &&
      fs.statSync(path.join(baseDir, e)).isDirectory()
    );

    for (const dir of backupDirs.sort().reverse()) {
      const fullPath = path.join(baseDir, dir);
      const files = fs.readdirSync(fullPath);
      // Extract date from folder name: GamingOptimization_Backup_YYYY-MM-DD_HH-mm-ss
      const dateMatch = dir.match(/Backup_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2})/);
      const date = dateMatch ? dateMatch[1].replace('_', ' ') : 'Unknown';

      backups.push({
        name: dir,
        path: fullPath,
        date,
        files,
      });
    }
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[backup] Failed to list backups: ${errorText}`);
  }

  return backups;
}

export async function createBackup(): Promise<{ success: boolean; path: string }> {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const backupDir = path.join(getBackupBaseDir(), `GamingOptimization_Backup_${timestamp}`);

  try {
    fs.mkdirSync(backupDir, { recursive: true });

    // Export key registry values
    const registryPaths = [
      { name: 'power_plan.reg', path: 'HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power' },
      { name: 'game_mode.reg', path: 'HKCU\\Software\\Microsoft\\GameBar' },
      { name: 'mmcss.reg', path: 'HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile' },
      { name: 'mouse.reg', path: 'HKCU\\Control Panel\\Mouse' },
      { name: 'visual_fx.reg', path: 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects' },
    ];

    for (const reg of registryPaths) {
      const outFile = path.join(backupDir, reg.name);
      try {
        const { execFileSync } = require('child_process');
        execFileSync('reg', ['export', reg.path, outFile, '/y'], { stdio: 'ignore' });
      } catch (err) {
        const errorText = err instanceof Error ? err.message : String(err);
        console.warn(`[backup] Registry export failed for ${reg.path}: ${errorText}`);
      }
    }

    return { success: true, path: backupDir };
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[backup] Failed to create backup: ${errorText}`);
    return { success: false, path: '' };
  }
}

export async function restoreBackup(backupPath: string): Promise<{ success: boolean }> {
  try {
    const files = fs.readdirSync(backupPath);
    const regFiles = files.filter(f => f.endsWith('.reg'));
    const { execFileSync } = require('child_process');

    for (const regFile of regFiles) {
      const fullPath = path.join(backupPath, regFile);
      try {
        execFileSync('reg', ['import', fullPath], { stdio: 'ignore' });
      } catch (err) {
        const errorText = err instanceof Error ? err.message : String(err);
        console.warn(`[backup] Failed to import ${fullPath}: ${errorText}`);
      }
    }

    return { success: true };
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[backup] Failed to restore backup ${backupPath}: ${errorText}`);
    return { success: false };
  }
}

export async function deleteBackup(backupPath: string): Promise<{ success: boolean }> {
  try {
    fs.rmSync(backupPath, { recursive: true, force: true });
    return { success: true };
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[backup] Failed to delete backup ${backupPath}: ${errorText}`);
    return { success: false };
  }
}
