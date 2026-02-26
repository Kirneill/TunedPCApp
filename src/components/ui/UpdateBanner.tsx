import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

export default function UpdateBanner() {
  const updateInfo = useAppStore((s) => s.updateInfo);
  const updateDismissed = useAppStore((s) => s.updateDismissed);
  const updaterState = useAppStore((s) => s.updaterState);
  const dismissUpdate = useAppStore((s) => s.dismissUpdate);
  const [isInstalling, setIsInstalling] = useState(false);
  const [actionMessage, setActionMessage] = useState<string | null>(null);

  if (!updateInfo?.hasUpdate || updateDismissed) return null;

  const isDownloading = updaterState.status === 'downloading' || updaterState.status === 'available';
  const isReadyToInstall = updaterState.status === 'downloaded';

  const statusText = isReadyToInstall
    ? 'Update downloaded and ready to install.'
    : updaterState.status === 'downloading'
      ? `Downloading update... ${updaterState.progress}%`
      : updaterState.status === 'available'
        ? 'Preparing update download...'
        : updaterState.status === 'error'
          ? updaterState.error || updaterState.message
          : null;

  const handlePrimaryAction = async () => {
    setActionMessage(null);

    if (isReadyToInstall) {
      setIsInstalling(true);
      try {
        const result = await window.sensequality.installUpdate();
        if (!result.started) {
          setActionMessage(result.reason || 'Install could not start.');
          setIsInstalling(false);
        }
      } catch {
        setActionMessage('Install failed to start.');
        setIsInstalling(false);
      }
      return;
    }

    try {
      const result = await window.sensequality.downloadUpdate();
      if (!result.started) {
        await window.sensequality.openExternal(updateInfo.releaseUrl);
        if (result.reason) setActionMessage(result.reason);
      }
    } catch {
      await window.sensequality.openExternal(updateInfo.releaseUrl);
      setActionMessage('In-app download failed. Opened release page instead.');
    }
  };

  return (
    <div className="flex items-center justify-between px-4 py-2.5 bg-sq-accent/15 border-b border-sq-accent/30 shrink-0 gap-3">
      <div className="flex items-center gap-3">
        <div className="w-5 h-5 rounded-full bg-sq-accent/20 flex items-center justify-center shrink-0">
          <svg className="w-3 h-3 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
          </svg>
        </div>
        <span className="text-xs text-sq-text">
          <span className="font-bold">Update available!</span>
          {' '}v{updateInfo.latestVersion} is ready —{' '}
          <span className="text-sq-text-muted">you're on v{updateInfo.currentVersion}</span>
          {statusText && (
            <>
              {' '}<span className="text-sq-text-dim">• {statusText}</span>
            </>
          )}
          {actionMessage && (
            <>
              {' '}<span className="text-sq-warning">• {actionMessage}</span>
            </>
          )}
        </span>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={handlePrimaryAction}
          disabled={isDownloading || isInstalling}
          className="px-3 py-1 rounded-lg text-[11px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer disabled:opacity-70 disabled:cursor-wait"
        >
          {isInstalling
            ? 'INSTALLING...'
            : isReadyToInstall
              ? 'INSTALL & RESTART'
              : isDownloading
                ? `DOWNLOADING ${updaterState.progress}%`
                : 'DOWNLOAD'}
        </button>
        <button
          onClick={() => window.sensequality.openExternal(updateInfo.releaseUrl)}
          className="px-3 py-1 rounded-lg text-[11px] font-bold text-sq-text-muted border border-sq-border hover:text-sq-text hover:bg-sq-surface-hover transition-colors cursor-pointer"
        >
          RELEASE PAGE
        </button>
        <button
          onClick={dismissUpdate}
          className="p-1 rounded text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors cursor-pointer"
          title="Dismiss"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
}
