/**
 * SCEWIN Auto-Provisioner
 * Downloads and extracts SCEWIN binaries from MSI Center automatically.
 * Port of BiosTuner's setup_scewin.py extraction chain.
 */

import https from 'https';
import http from 'http';
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import os from 'os';
import { execFile, ChildProcess } from 'child_process';
import { promisify } from 'util';
import { app } from 'electron';

const execFileAsync = promisify(execFile);

const MSI_CENTER_URL = 'https://download.msi.com/uti_exe/desktop/MSI-Center.zip';
const INNOEXTRACT_FALLBACK_URL = 'https://github.com/dscharrer/innoextract/releases/download/1.9/innoextract-1.9-windows.zip';
const INNOEXTRACT_API = 'https://api.github.com/repos/dscharrer/innoextract/releases/latest';

const REQUIRED_FILES = ['SCEWIN_64.exe', 'amifldrv64.sys', 'amigendrv64.sys'];

export type ProvisionStep =
  | 'idle'
  | 'checking-local'
  | 'downloading-tools'
  | 'downloading-msi-center'
  | 'extracting'
  | 'copying'
  | 'verifying'
  | 'complete'
  | 'error';

export interface ProvisionProgress {
  step: ProvisionStep;
  progress: number;
  message: string;
  error?: string;
}

type ProgressFn = (progress: ProvisionProgress) => void;

let activeProcess: ChildProcess | null = null;
let cancelled = false;

export function cancelProvision() {
  cancelled = true;
  if (activeProcess) {
    activeProcess.kill();
    activeProcess = null;
  }
}

/** Search common local paths for existing SCEWIN installation. */
async function checkLocalScewin(): Promise<string | null> {
  const searchPaths = [
    path.join('C:', 'Program Files (x86)', 'MSI', 'MSI Center', 'Hardware Diagnosis', 'SCEWIN'),
    path.join('C:', 'Program Files', 'MSI', 'MSI Center', 'Hardware Diagnosis', 'SCEWIN'),
    path.join('C:', 'Program Files (x86)', 'MSI', 'MSI Center SDK', 'Lib', 'SCEWIN'),
    path.join('C:', 'Program Files', 'MSI', 'MSI Center SDK', 'Lib', 'SCEWIN'),
  ];

  for (const basePath of searchPaths) {
    try {
      if (!fs.existsSync(basePath)) continue;
      // SCEWIN may be in a version subfolder
      const entries = await fsp.readdir(basePath);
      // Check base path directly
      if (REQUIRED_FILES.every(f => fs.existsSync(path.join(basePath, f)))) {
        return basePath;
      }
      // Check version subfolders
      for (const entry of entries) {
        const subPath = path.join(basePath, entry);
        const stat = await fsp.stat(subPath);
        if (stat.isDirectory() && REQUIRED_FILES.every(f => fs.existsSync(path.join(subPath, f)))) {
          return subPath;
        }
      }
    } catch { /* skip inaccessible paths */ }
  }
  return null;
}

/** Full provisioning pipeline. */
export async function provisionScewin(outputDir: string, onProgress: ProgressFn): Promise<void> {
  cancelled = false;
  const tmpDir = path.join(os.tmpdir(), `scewin_setup_${Date.now()}`);
  await fsp.mkdir(tmpDir, { recursive: true });
  await fsp.mkdir(outputDir, { recursive: true });

  try {
    // Step 1: Check local installations
    onProgress({ step: 'checking-local', progress: 0, message: 'Checking for existing SCEWIN installation...' });
    const localPath = await checkLocalScewin();
    if (localPath) {
      onProgress({ step: 'copying', progress: 80, message: 'Found local SCEWIN, copying files...' });
      for (const f of REQUIRED_FILES) {
        await fsp.copyFile(path.join(localPath, f), path.join(outputDir, f));
      }
      onProgress({ step: 'complete', progress: 100, message: 'SCEWIN setup complete (from local MSI Center)' });
      return;
    }
    throwIfCancelled();

    // Step 2: Download innoextract
    onProgress({ step: 'downloading-tools', progress: 2, message: 'Downloading extraction tools...' });
    const innoPath = await downloadInnoextract(tmpDir, (pct) => {
      onProgress({ step: 'downloading-tools', progress: 2 + Math.round(pct * 0.03), message: `Downloading extraction tools... ${pct}%` });
    });
    throwIfCancelled();

    // Step 3: Download MSI Center (~300MB)
    onProgress({ step: 'downloading-msi-center', progress: 5, message: 'Downloading MSI Center...' });
    const msiZipPath = path.join(tmpDir, 'MSI-Center.zip');
    await downloadFile(MSI_CENTER_URL, msiZipPath, (pct) => {
      onProgress({ step: 'downloading-msi-center', progress: 5 + Math.round(pct * 0.55), message: `Downloading MSI Center... ${pct}%` });
    });
    throwIfCancelled();

    // Step 4: Extract chain
    onProgress({ step: 'extracting', progress: 60, message: 'Extracting MSI Center archive...' });
    await extractScewinChain(tmpDir, msiZipPath, innoPath, outputDir, onProgress);
    throwIfCancelled();

    // Step 5: Verify
    onProgress({ step: 'verifying', progress: 95, message: 'Verifying SCEWIN files...' });
    const missing = REQUIRED_FILES.filter(f => !fs.existsSync(path.join(outputDir, f)));
    if (missing.length > 0) {
      throw new Error(`Missing files after extraction: ${missing.join(', ')}`);
    }

    onProgress({ step: 'complete', progress: 100, message: 'SCEWIN setup complete' });
  } catch (err) {
    if (cancelled) {
      onProgress({ step: 'error', progress: 0, message: 'Setup cancelled', error: 'Cancelled by user' });
    } else {
      const msg = err instanceof Error ? err.message : String(err);
      onProgress({ step: 'error', progress: 0, message: 'Setup failed', error: msg });
    }
    throw err;
  } finally {
    activeProcess = null;
    await fsp.rm(tmpDir, { recursive: true, force: true }).catch(() => {});
  }
}

function throwIfCancelled() {
  if (cancelled) throw new Error('Cancelled');
}

async function downloadInnoextract(tmpDir: string, onProgress: (pct: number) => void): Promise<string> {
  const exePath = path.join(tmpDir, 'innoextract.exe');

  // Try GitHub API for latest release, fall back to known URL
  let downloadUrl = INNOEXTRACT_FALLBACK_URL;
  try {
    const data = await fetchJson(INNOEXTRACT_API);
    const asset = data.assets?.find((a: any) => a.name?.endsWith('windows.zip'));
    if (asset?.browser_download_url) downloadUrl = asset.browser_download_url;
  } catch { /* use fallback */ }

  const zipPath = path.join(tmpDir, 'innoextract.zip');
  await downloadFile(downloadUrl, zipPath, onProgress);
  await extractZip(zipPath, tmpDir);

  if (!fs.existsSync(exePath)) {
    // May be in a subdirectory
    const found = await findFile(tmpDir, 'innoextract.exe');
    if (!found) throw new Error('innoextract.exe not found after extraction');
    await fsp.copyFile(found, exePath);
  }
  return exePath;
}

async function extractScewinChain(
  tmpDir: string,
  msiZipPath: string,
  innoPath: string,
  outputDir: string,
  onProgress: ProgressFn
): Promise<void> {
  const extractDir = path.join(tmpDir, 'extracted');
  await fsp.mkdir(extractDir, { recursive: true });

  // 1. Extract MSI-Center.zip
  onProgress({ step: 'extracting', progress: 62, message: 'Extracting MSI Center archive...' });
  await extractZip(msiZipPath, extractDir);
  throwIfCancelled();

  // 2. Find MSI Center installer
  const topFiles = await fsp.readdir(extractDir);
  const installer = topFiles.find(f => f.startsWith('MSI Center_') && f.endsWith('.exe'));
  if (!installer) throw new Error('MSI Center installer not found in archive');

  const versionMatch = installer.match(/_([\d.]+)\.exe$/);
  if (!versionMatch) throw new Error('Cannot parse MSI Center version from filename');
  const version = versionMatch[1];

  // 3. Run innoextract on installer
  onProgress({ step: 'extracting', progress: 68, message: 'Extracting installer contents...' });
  await runInnoextract(innoPath, path.join(extractDir, installer), extractDir);
  throwIfCancelled();

  // 4. Find and extract .appxbundle
  onProgress({ step: 'extracting', progress: 74, message: 'Extracting app bundle...' });
  const appDir = path.join(extractDir, 'app');
  const appxBundle = await findFileInDir(appDir, '.appxbundle');
  if (!appxBundle) throw new Error('Appx bundle not found after innoextract');

  const bundleDir = path.join(tmpDir, 'bundle');
  await extractZip(appxBundle, bundleDir);
  throwIfCancelled();

  // 5. Find and extract x64 .appx
  onProgress({ step: 'extracting', progress: 78, message: 'Extracting app package...' });
  const appxFile = await findAppx(bundleDir, version);
  if (!appxFile) throw new Error('x64 appx not found in bundle');

  const appxDir = path.join(tmpDir, 'appx');
  await extractZip(appxFile, appxDir);
  throwIfCancelled();

  // 6. Find and extract SDK installer
  onProgress({ step: 'extracting', progress: 82, message: 'Extracting SDK...' });
  const sdkExe = await findFile(appxDir, 'SDK.exe') ?? await findFileByPattern(appxDir, /SDK.*\.exe$/i);
  if (!sdkExe) throw new Error('MSI Center SDK.exe not found in appx');

  const sdkDir = path.join(tmpDir, 'sdk');
  await runInnoextract(innoPath, sdkExe, sdkDir);
  throwIfCancelled();

  // 7. Find and extract Engine Lib
  onProgress({ step: 'extracting', progress: 88, message: 'Extracting Engine Lib...' });
  const engineExe = await findFileByPattern(sdkDir, /Engine\s*Lib.*\.exe$/i);
  if (!engineExe) throw new Error('Engine Lib installer not found in SDK');

  const engineDir = path.join(tmpDir, 'engine');
  await runInnoextract(innoPath, engineExe, engineDir);
  throwIfCancelled();

  // 8. Find SCEWIN files
  onProgress({ step: 'copying', progress: 93, message: 'Copying SCEWIN binaries...' });
  const scewinExe = await findFile(engineDir, 'SCEWIN_64.exe');
  if (!scewinExe) throw new Error('SCEWIN_64.exe not found in Engine Lib extraction');

  const scewinSrcDir = path.dirname(scewinExe);
  for (const f of REQUIRED_FILES) {
    const src = path.join(scewinSrcDir, f);
    if (!fs.existsSync(src)) throw new Error(`Required file ${f} not found in ${scewinSrcDir}`);
    await fsp.copyFile(src, path.join(outputDir, f));
  }
}

// ─── File Utilities ──────────────────────────────────────

async function runInnoextract(innoPath: string, target: string, outDir: string): Promise<void> {
  await fsp.mkdir(outDir, { recursive: true });
  const proc = execFile(innoPath, [target, '--output-dir', outDir], {
    timeout: 180000, windowsHide: true,
  });
  activeProcess = proc;
  await new Promise<void>((resolve, reject) => {
    proc.on('close', (code) => {
      activeProcess = null;
      if (code === 0) resolve();
      else reject(new Error(`innoextract exited with code ${code}`));
    });
    proc.on('error', (err) => { activeProcess = null; reject(err); });
  });
}

async function extractZip(zipPath: string, destDir: string): Promise<void> {
  await fsp.mkdir(destDir, { recursive: true });
  // Expand-Archive only accepts .zip -- rename non-.zip archives (e.g. .appxbundle, .appx)
  let pathToExtract = zipPath;
  if (!zipPath.toLowerCase().endsWith('.zip')) {
    pathToExtract = zipPath + '.zip';
    await fsp.copyFile(zipPath, pathToExtract);
  }
  await execFileAsync('powershell.exe', [
    '-NoProfile', '-Command',
    `Expand-Archive -LiteralPath '${pathToExtract.replace(/'/g, "''")}' -DestinationPath '${destDir.replace(/'/g, "''")}' -Force`,
  ], { timeout: 300000, windowsHide: true });
  // Clean up the renamed copy
  if (pathToExtract !== zipPath) {
    await fsp.rm(pathToExtract, { force: true }).catch(() => {});
  }
}

/** Recursively find a file by exact name. */
async function findFile(dir: string, filename: string): Promise<string | null> {
  try {
    const entries = await fsp.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isFile() && entry.name === filename) return fullPath;
      if (entry.isDirectory()) {
        const found = await findFile(fullPath, filename);
        if (found) return found;
      }
    }
  } catch { /* skip inaccessible */ }
  return null;
}

/** Recursively find a file matching a regex pattern. */
async function findFileByPattern(dir: string, pattern: RegExp): Promise<string | null> {
  try {
    const entries = await fsp.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isFile() && pattern.test(entry.name)) return fullPath;
      if (entry.isDirectory()) {
        const found = await findFileByPattern(fullPath, pattern);
        if (found) return found;
      }
    }
  } catch { /* skip inaccessible */ }
  return null;
}

/** Find a file ending with a given extension in a directory (non-recursive). */
async function findFileInDir(dir: string, ext: string): Promise<string | null> {
  try {
    const entries = await fsp.readdir(dir);
    const match = entries.find(f => f.endsWith(ext));
    return match ? path.join(dir, match) : null;
  } catch { return null; }
}

/** Find the x64 appx file, handling URL-encoded names. */
async function findAppx(bundleDir: string, version: string): Promise<string | null> {
  const candidates = [
    `MSI%20Center_${version}_x64.appx`,
    `MSI Center_${version}_x64.appx`,
    decodeURIComponent(`MSI%20Center_${version}_x64.appx`),
  ];
  for (const name of candidates) {
    const p = path.join(bundleDir, name);
    if (fs.existsSync(p)) return p;
  }
  // Fallback: search for any x64 appx
  return findFileByPattern(bundleDir, /x64.*\.appx$/i);
}

// ─── HTTP Utilities ──────────────────────────────────────

function downloadFile(url: string, dest: string, onProgress: (pct: number) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    const follow = (url: string, redirects = 0) => {
      if (cancelled) { reject(new Error('Cancelled')); return; }
      if (redirects > 5) { reject(new Error('Too many redirects')); return; }

      const mod = url.startsWith('https') ? https : http;
      const req = mod.get(url, { headers: { 'User-Agent': 'SenseQuality/1.0' } }, (res) => {
        if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume(); // drain response
          follow(res.headers.location, redirects + 1);
          return;
        }
        if (res.statusCode !== 200) {
          res.resume();
          reject(new Error(`HTTP ${res.statusCode} from ${url}`));
          return;
        }

        const total = parseInt(res.headers['content-length'] || '0', 10);
        let downloaded = 0;
        const file = fs.createWriteStream(dest);

        res.on('data', (chunk: Buffer) => {
          downloaded += chunk.length;
          if (total > 0) onProgress(Math.round((downloaded / total) * 100));
        });

        res.pipe(file);
        file.on('finish', () => { file.close(); resolve(); });
        file.on('error', (err) => { file.close(); reject(err); });
        res.on('error', reject);
      });
      req.on('error', reject);
    };
    follow(url);
  });
}

function fetchJson(url: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const follow = (url: string, redirects = 0) => {
      if (redirects > 5) { reject(new Error('Too many redirects')); return; }

      const mod = url.startsWith('https') ? https : http;
      mod.get(url, { headers: { 'User-Agent': 'SenseQuality/1.0' } }, (res) => {
        if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          follow(res.headers.location, redirects + 1);
          return;
        }
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
        });
        res.on('error', reject);
      }).on('error', reject);
    };
    follow(url);
  });
}
