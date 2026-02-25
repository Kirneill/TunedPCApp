import { app, net } from 'electron';

export interface UpdateInfo {
  hasUpdate: boolean;
  currentVersion: string;
  latestVersion: string;
  releaseUrl: string;
  releaseNotes: string;
}

const GITHUB_OWNER = 'Kirneill';
const GITHUB_REPO = 'sensequality-optimizer';

function compareVersions(current: string, latest: string): boolean {
  const c = current.replace(/^v/, '').split('.').map(Number);
  const l = latest.replace(/^v/, '').split('.').map(Number);

  for (let i = 0; i < Math.max(c.length, l.length); i++) {
    const cv = c[i] || 0;
    const lv = l[i] || 0;
    if (lv > cv) return true;
    if (lv < cv) return false;
  }
  return false;
}

export async function checkForUpdate(): Promise<UpdateInfo> {
  const currentVersion = app.getVersion();
  const apiUrl = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;

  const result: UpdateInfo = {
    hasUpdate: false,
    currentVersion,
    latestVersion: currentVersion,
    releaseUrl: `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases`,
    releaseNotes: '',
  };

  try {
    const response = await new Promise<string>((resolve, reject) => {
      const request = net.request({
        url: apiUrl,
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

    const release = JSON.parse(response);
    const latestVersion = (release.tag_name || '').replace(/^v/, '');

    result.latestVersion = latestVersion;
    result.releaseUrl = release.html_url || result.releaseUrl;
    result.releaseNotes = release.body || '';
    result.hasUpdate = compareVersions(currentVersion, latestVersion);
  } catch (err) {
    // Silently fail — update check is non-critical
    console.warn('[updater] Update check failed:', err instanceof Error ? err.message : err);
  }

  return result;
}
