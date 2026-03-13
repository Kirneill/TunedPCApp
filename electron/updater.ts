import { app, BrowserWindow, net } from 'electron';
import { autoUpdater } from 'electron-updater';
import type { UpdateInfo, UpdaterStatus, UpdaterState, UpdaterActionResult } from '../src/types/index';
export type { UpdateInfo, UpdaterStatus, UpdaterState, UpdaterActionResult } from '../src/types/index';

const GITHUB_OWNER = 'Kirneill';
const GITHUB_REPO = 'TunedPCApp';
const RELEASES_URL = `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;
const GITHUB_RELEASES_API_URL = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=50`;

let getMainWindow: (() => BrowserWindow | null) | null = null;
let listenersInitialized = false;

let lastKnownUpdate: UpdateInfo | null = null;
let updaterState: UpdaterState = {
  status: 'idle',
  progress: 0,
  message: '',
};

function ensureLastKnownUpdate(): UpdateInfo {
  if (!lastKnownUpdate) {
    lastKnownUpdate = createDefaultUpdateInfo();
  }
  return lastKnownUpdate;
}

function normalizeVersion(version: string): string {
  return version.replace(/^v/i, '').trim();
}

function parseVersionParts(version: string): number[] | null {
  const parts = normalizeVersion(version).split('.');
  if (parts.length === 0) return null;
  const parsed = parts.map((part) => Number(part));
  if (parsed.some((n) => !Number.isFinite(n) || n < 0)) return null;
  return parsed;
}

function compareVersionNumbers(a: string, b: string): number {
  const av = parseVersionParts(a);
  const bv = parseVersionParts(b);
  if (!av || !bv) return 0;

  for (let i = 0; i < Math.max(av.length, bv.length); i++) {
    const ai = av[i] || 0;
    const bi = bv[i] || 0;
    if (ai > bi) return 1;
    if (ai < bi) return -1;
  }
  return 0;
}

function compareVersions(current: string, latest: string): boolean {
  return compareVersionNumbers(latest, current) > 0;
}

function extractReleaseNotes(value: unknown): string {
  if (typeof value === 'string') return value;
  if (!Array.isArray(value)) return '';

  return value
    .map((item) => {
      if (typeof item === 'string') return item;
      if (typeof item === 'object' && item && 'note' in item) {
        const note = (item as { note?: unknown }).note;
        return typeof note === 'string' ? note : '';
      }
      return '';
    })
    .filter(Boolean)
    .join('\n\n');
}

function createDefaultUpdateInfo(): UpdateInfo {
  const currentVersion = normalizeVersion(app.getVersion());
  return {
    hasUpdate: false,
    currentVersion,
    latestVersion: currentVersion,
    releaseUrl: RELEASES_URL,
    releaseNotes: '',
  };
}

function updateLastKnownInfo(latestVersion: string, releaseNotes: string, hasUpdate: boolean) {
  lastKnownUpdate = {
    hasUpdate,
    currentVersion: normalizeVersion(app.getVersion()),
    latestVersion: normalizeVersion(latestVersion),
    releaseUrl: RELEASES_URL,
    releaseNotes,
  };
}

function syncFromAutoUpdaterInfo(info: unknown, hasUpdate: boolean) {
  const record = typeof info === 'object' && info !== null ? info as Record<string, unknown> : {};
  const latest = typeof record.version === 'string' ? record.version : app.getVersion();
  const notes = extractReleaseNotes(record.releaseNotes);
  updateLastKnownInfo(latest, notes, hasUpdate);
}

function broadcastUpdaterState() {
  const window = getMainWindow?.();
  if (!window || window.isDestroyed()) return;
  window.webContents.send('updater:state', updaterState);
}

function setUpdaterState(next: Partial<UpdaterState>) {
  updaterState = { ...updaterState, ...next };
  broadcastUpdaterState();
}

function formatError(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'Unknown updater error';
}

function createUpdateCheckError(primaryError: unknown, fallbackError?: unknown): Error {
  const primaryText = formatError(primaryError);
  if (fallbackError === undefined) {
    return new Error(`Update check failed: ${primaryText}`);
  }
  const fallbackText = formatError(fallbackError);
  return new Error(`Update check failed. Auto-updater: ${primaryText}. GitHub fallback: ${fallbackText}`);
}

interface GitHubReleaseRecord {
  tag_name?: string;
  html_url?: string;
  body?: string;
  draft?: boolean;
  prerelease?: boolean;
}

interface LatestReleaseMeta {
  tag: string;
  version: string;
  htmlUrl: string;
  notes: string;
}

function buildTagFeedUrl(tag: string): string {
  return `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${encodeURIComponent(tag)}`;
}

function pickHighestStableRelease(records: GitHubReleaseRecord[]): LatestReleaseMeta | null {
  let best: LatestReleaseMeta | null = null;

  for (const record of records) {
    if (record.draft || record.prerelease) continue;
    const tag = typeof record.tag_name === 'string' ? record.tag_name.trim() : '';
    const version = normalizeVersion(tag);
    if (!tag || !parseVersionParts(version)) continue;

    const candidate: LatestReleaseMeta = {
      tag,
      version,
      htmlUrl: typeof record.html_url === 'string' ? record.html_url : RELEASES_URL,
      notes: typeof record.body === 'string' ? record.body : '',
    };

    if (!best || compareVersionNumbers(candidate.version, best.version) > 0) {
      best = candidate;
    }
  }

  return best;
}

async function fetchLatestReleaseMeta(): Promise<LatestReleaseMeta> {
  const currentVersion = normalizeVersion(app.getVersion());

  const response = await new Promise<string>((resolve, reject) => {
    const request = net.request({
      url: GITHUB_RELEASES_API_URL,
      method: 'GET',
    });

    request.setHeader('Accept', 'application/vnd.github.v3+json');
    request.setHeader('User-Agent', `SENSEQUALITY-Optimizer/${currentVersion}`);

    let body = '';

    request.on('response', (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`GitHub API returned ${res.statusCode}`));
        return;
      }
      res.on('data', (chunk) => { body += chunk.toString(); });
      res.on('end', () => resolve(body));
      res.on('error', reject);
    });

    request.on('error', reject);
    request.end();
  });

  const releases = JSON.parse(response);
  if (!Array.isArray(releases)) {
    throw new Error('GitHub releases API returned an unexpected payload.');
  }

  const latest = pickHighestStableRelease(releases as GitHubReleaseRecord[]);
  if (!latest) {
    throw new Error('No stable semantic-version release found.');
  }

  return latest;
}

async function checkForUpdateViaGitHub(): Promise<UpdateInfo> {
  const currentVersion = normalizeVersion(app.getVersion());
  const latest = await fetchLatestReleaseMeta();
  const hasUpdate = compareVersions(currentVersion, latest.version);

  return {
    hasUpdate,
    currentVersion,
    latestVersion: latest.version,
    releaseUrl: latest.htmlUrl || RELEASES_URL,
    releaseNotes: latest.notes,
  };
}

export function initUpdater(windowGetter: () => BrowserWindow | null): void {
  getMainWindow = windowGetter;

  if (listenersInitialized || !app.isPackaged) return;
  listenersInitialized = true;

  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = false;

  autoUpdater.on('checking-for-update', () => {
    setUpdaterState({
      status: 'checking',
      progress: 0,
      message: 'Checking for updates...',
      error: undefined,
    });
  });

  autoUpdater.on('update-available', (info) => {
    syncFromAutoUpdaterInfo(info, true);
    const known = ensureLastKnownUpdate();
    setUpdaterState({
      status: 'available',
      progress: 0,
      latestVersion: known.latestVersion,
      message: `Update v${known.latestVersion} available. Downloading...`,
      error: undefined,
    });
  });

  autoUpdater.on('download-progress', (progress) => {
    const known = ensureLastKnownUpdate();
    setUpdaterState({
      status: 'downloading',
      progress: Math.max(0, Math.min(100, Math.round(progress.percent))),
      latestVersion: known.latestVersion,
      message: `Downloading update... ${Math.round(progress.percent)}%`,
      error: undefined,
    });
  });

  autoUpdater.on('update-not-available', (info) => {
    syncFromAutoUpdaterInfo(info, false);
    const known = ensureLastKnownUpdate();
    setUpdaterState({
      status: 'up-to-date',
      progress: 100,
      latestVersion: known.latestVersion,
      message: `You're on the latest version (v${known.currentVersion}).`,
      error: undefined,
    });
  });

  autoUpdater.on('update-downloaded', (info) => {
    syncFromAutoUpdaterInfo(info, true);
    const known = ensureLastKnownUpdate();
    setUpdaterState({
      status: 'downloaded',
      progress: 100,
      latestVersion: known.latestVersion,
      message: `Update v${known.latestVersion} is ready to install.`,
      error: undefined,
    });
  });

  autoUpdater.on('error', (error) => {
    setUpdaterState({
      status: 'error',
      message: 'Update failed.',
      error: formatError(error),
    });
  });
}

export function getUpdaterState(): UpdaterState {
  return updaterState;
}

export async function checkForUpdate(): Promise<UpdateInfo> {
  lastKnownUpdate = createDefaultUpdateInfo();

  if (!app.isPackaged) {
    setUpdaterState({
      status: 'checking',
      progress: 0,
      message: 'Checking for updates...',
      error: undefined,
    });
    try {
      const info = await checkForUpdateViaGitHub();
      lastKnownUpdate = info;
      if (info.hasUpdate) {
        setUpdaterState({
          status: 'available',
          progress: 0,
          latestVersion: info.latestVersion,
          message: `Update v${info.latestVersion} available. In-app install requires packaged build.`,
          error: undefined,
        });
      } else {
        setUpdaterState({
          status: 'up-to-date',
          progress: 100,
          latestVersion: info.latestVersion,
          message: `You're on the latest version (v${info.currentVersion}).`,
          error: undefined,
        });
      }
      return info;
    } catch (error) {
      const checkError = createUpdateCheckError(error);
      setUpdaterState({
        status: 'error',
        progress: 0,
        message: 'Update check failed.',
        error: checkError.message,
      });
      throw checkError;
    }
  }

  try {
    // Force feed metadata to the highest stable semver tag so older clients can jump directly to newest.
    try {
      const latestMeta = await fetchLatestReleaseMeta();
      if (compareVersions(app.getVersion(), latestMeta.version)) {
        autoUpdater.setFeedURL({
          provider: 'generic',
          url: buildTagFeedUrl(latestMeta.tag),
        });
      }
    } catch {
      // If GitHub API probing fails, continue with default provider config.
    }

    const checkResult = await autoUpdater.checkForUpdates();
    if (!checkResult?.updateInfo) {
      throw new Error('No update metadata was returned by the updater provider.');
    }

    const latestVersion = normalizeVersion(checkResult.updateInfo.version || app.getVersion());
    const hasUpdate = compareVersions(app.getVersion(), latestVersion);
    const releaseNotes = extractReleaseNotes(checkResult.updateInfo.releaseNotes);
    updateLastKnownInfo(latestVersion, releaseNotes, hasUpdate);

    if (hasUpdate) {
      setUpdaterState({
        status: 'available',
        progress: 0,
        latestVersion,
        message: `Update v${latestVersion} available. Downloading...`,
        error: undefined,
      });
    } else {
      setUpdaterState({
        status: 'up-to-date',
        progress: 100,
        latestVersion,
        message: `You're on the latest version (v${lastKnownUpdate!.currentVersion}).`,
        error: undefined,
      });
    }
    return lastKnownUpdate!;
  } catch (autoUpdaterError) {
    setUpdaterState({
      status: 'error',
      progress: 0,
      message: 'Update check failed.',
      error: formatError(autoUpdaterError),
    });
    try {
      const fallbackInfo = await checkForUpdateViaGitHub();
      lastKnownUpdate = fallbackInfo;
      if (fallbackInfo.hasUpdate) {
        setUpdaterState({
          status: 'available',
          progress: 0,
          latestVersion: fallbackInfo.latestVersion,
          message: `Update v${fallbackInfo.latestVersion} available.`,
          error: undefined,
        });
      } else {
        setUpdaterState({
          status: 'up-to-date',
          progress: 100,
          latestVersion: fallbackInfo.latestVersion,
          message: `You're on the latest version (v${fallbackInfo.currentVersion}).`,
          error: undefined,
        });
      }
      return fallbackInfo;
    } catch (fallbackError) {
      const checkError = createUpdateCheckError(autoUpdaterError, fallbackError);
      setUpdaterState({
        status: 'error',
        progress: 0,
        message: 'Update check failed.',
        error: checkError.message,
      });
      throw checkError;
    }
  }
}

export async function downloadUpdate(): Promise<UpdaterActionResult> {
  if (!app.isPackaged) {
    return {
      started: false,
      reason: 'In-app download is available in packaged builds only.',
    };
  }

  if (updaterState.status === 'downloaded') {
    return { started: false, reason: 'Update already downloaded.' };
  }

  if (updaterState.status === 'downloading') {
    return { started: true };
  }

  try {
    await autoUpdater.downloadUpdate();
    return { started: true };
  } catch (error) {
    setUpdaterState({
      status: 'error',
      message: 'Update download failed.',
      error: formatError(error),
    });
    return { started: false, reason: formatError(error) };
  }
}

export async function installUpdate(): Promise<UpdaterActionResult> {
  if (!app.isPackaged) {
    return {
      started: false,
      reason: 'In-app install is available in packaged builds only.',
    };
  }

  if (updaterState.status !== 'downloaded') {
    return {
      started: false,
      reason: 'No downloaded update is ready to install.',
    };
  }

  setTimeout(() => {
    autoUpdater.quitAndInstall();
  }, 50);

  return { started: true };
}
