import { spawn } from 'child_process';
import * as path from 'path';
import { app } from 'electron';

export interface ScriptResult {
  success: boolean;
  output: string[];
  errors: string[];
  exitCode: number;
}

function getScriptsPath(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'scripts');
  }
  return path.join(app.getAppPath(), 'scripts');
}

export function getScriptPath(scriptName: string): string {
  return path.join(getScriptsPath(), scriptName);
}

export function runPowerShellScript(
  scriptPath: string,
  envVars: Record<string, string> = {},
  onLine?: (line: string) => void
): Promise<ScriptResult> {
  return new Promise((resolve) => {
    const output: string[] = [];
    const errors: string[] = [];

    const ps = spawn('powershell.exe', [
      '-ExecutionPolicy', 'Bypass',
      '-NoProfile',
      '-NonInteractive',
      '-File', scriptPath,
    ], {
      env: { ...process.env, ...envVars },
      windowsHide: true,
    });

    ps.stdout.on('data', (data: Buffer) => {
      const lines = data.toString().split('\n');
      for (const line of lines) {
        const trimmed = line.replace(/\x1b\[[0-9;]*m/g, '').trim();
        if (trimmed) {
          output.push(trimmed);
          onLine?.(trimmed);
        }
      }
    });

    ps.stderr.on('data', (data: Buffer) => {
      const text = data.toString().trim();
      if (text) {
        errors.push(text);
        onLine?.(`[ERROR] ${text}`);
      }
    });

    ps.on('close', (code) => {
      resolve({
        success: code === 0,
        output,
        errors,
        exitCode: code ?? 1,
      });
    });

    ps.on('error', (err) => {
      errors.push(err.message);
      resolve({
        success: false,
        output,
        errors,
        exitCode: 1,
      });
    });
  });
}

export function runPowerShellCommand(
  command: string,
  onLine?: (line: string) => void
): Promise<ScriptResult> {
  return new Promise((resolve) => {
    const output: string[] = [];
    const errors: string[] = [];

    const ps = spawn('powershell.exe', [
      '-ExecutionPolicy', 'Bypass',
      '-NoProfile',
      '-NonInteractive',
      '-Command', command,
    ], {
      windowsHide: true,
    });

    ps.stdout.on('data', (data: Buffer) => {
      const lines = data.toString().split('\n');
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed) {
          output.push(trimmed);
          onLine?.(trimmed);
        }
      }
    });

    ps.stderr.on('data', (data: Buffer) => {
      const text = data.toString().trim();
      if (text) errors.push(text);
    });

    ps.on('close', (code) => {
      resolve({
        success: code === 0,
        output,
        errors,
        exitCode: code ?? 1,
      });
    });

    ps.on('error', (err) => {
      errors.push(err.message);
      resolve({ success: false, output, errors, exitCode: 1 });
    });
  });
}
