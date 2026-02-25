import { useAppStore } from '../../store/appStore';

export default function UpdateBanner() {
  const updateInfo = useAppStore((s) => s.updateInfo);
  const updateDismissed = useAppStore((s) => s.updateDismissed);
  const dismissUpdate = useAppStore((s) => s.dismissUpdate);

  if (!updateInfo?.hasUpdate || updateDismissed) return null;

  return (
    <div className="flex items-center justify-between px-4 py-2.5 bg-sq-accent/15 border-b border-sq-accent/30 shrink-0">
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
        </span>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={() => window.sensequality.openExternal(updateInfo.releaseUrl)}
          className="px-3 py-1 rounded-lg text-[11px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer"
        >
          DOWNLOAD
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
