import os from 'os';
import path from 'path';
import { execFile } from 'child_process';
import { BrowserWindow } from 'electron';

interface CpuSnapshot {
  idle: number;
  total: number;
}

function getCpuSnapshot(): CpuSnapshot {
  const cpus = os.cpus();
  let idle = 0;
  let total = 0;
  for (const cpu of cpus) {
    idle += cpu.times.idle;
    total += cpu.times.user + cpu.times.nice + cpu.times.sys + cpu.times.idle + cpu.times.irq;
  }
  return { idle, total };
}

let lastCpuSnapshot: CpuSnapshot = getCpuSnapshot();

function getCpuUsage(): number {
  const current = getCpuSnapshot();
  const idleDelta = current.idle - lastCpuSnapshot.idle;
  const totalDelta = current.total - lastCpuSnapshot.total;
  lastCpuSnapshot = current;
  if (totalDelta === 0) return 0;
  return Math.round((1 - idleDelta / totalDelta) * 100);
}

function getRamUsage(): number {
  const total = os.totalmem();
  const free = os.freemem();
  return Math.round(((total - free) / total) * 100);
}

// nvidia-smi paths to try (the system PATH entry often works, but fallback to known install locations)
const NVIDIA_SMI_PATHS = [
  'nvidia-smi',
  path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'nvidia-smi.exe'),
  'C:\\Program Files\\NVIDIA Corporation\\NVSMI\\nvidia-smi.exe',
];

let resolvedNvidiaSmiPath: string | null = null;
let nvidiaSmiChecked = false;

function getGpuUsage(): Promise<number> {
  // If we already know nvidia-smi isn't available, skip
  if (nvidiaSmiChecked && resolvedNvidiaSmiPath === null) {
    return Promise.resolve(0);
  }

  const pathsToTry = resolvedNvidiaSmiPath ? [resolvedNvidiaSmiPath] : NVIDIA_SMI_PATHS;

  return new Promise((resolve) => {
    let tried = 0;

    function tryNext() {
      if (tried >= pathsToTry.length) {
        nvidiaSmiChecked = true;
        resolvedNvidiaSmiPath = null;
        resolve(0);
        return;
      }

      const smiPath = pathsToTry[tried++];
      execFile(
        smiPath,
        ['--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
        { timeout: 3000 },
        (err, stdout) => {
          if (err || !stdout) {
            tryNext();
            return;
          }
          // Cache the working path
          resolvedNvidiaSmiPath = smiPath;
          nvidiaSmiChecked = true;
          const value = parseInt(stdout.trim().split('\n')[0], 10);
          resolve(Number.isNaN(value) ? 0 : value);
        },
      );
    }

    tryNext();
  });
}

let intervalId: ReturnType<typeof setInterval> | null = null;

export function startSystemMonitor(getWindow: () => BrowserWindow | null) {
  if (intervalId) return;

  intervalId = setInterval(async () => {
    const win = getWindow();
    if (!win || win.isDestroyed()) return;

    try {
      const gpu = await getGpuUsage();
      const cpu = getCpuUsage();
      const ram = getRamUsage();

      // Ensure webContents is still valid before sending
      if (!win.isDestroyed() && win.webContents && !win.webContents.isDestroyed()) {
        win.webContents.send('system:usage', { cpu, gpu, ram });
      }
    } catch {
      // Silently skip this tick
    }
  }, 2000);
}

export function stopSystemMonitor() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
  }
}
