import { useEffect, useState } from 'react';
import { useAppStore } from '../../store/appStore';

type Page = 'dashboard' | 'advanced' | 'network' | 'bios-guide' | 'gpu-guide' | 'memory' | 'backups' | 'os-optimizer';

const pageIcons: Record<Page, React.ReactNode> = {
  dashboard: (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875S10.5 3.09 10.5 4.125c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.959.401v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z" />
    </svg>
  ),
  advanced: (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
    </svg>
  ),
  network: (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M8.288 15.038a5.25 5.25 0 017.424 0M5.106 11.856c3.807-3.808 9.98-3.808 13.788 0M1.924 8.674c5.565-5.565 14.587-5.565 20.152 0M12.53 18.22l-.53.53-.53-.53a.75.75 0 011.06 0z" />
    </svg>
  ),
  'bios-guide': (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
    </svg>
  ),
  'gpu-guide': (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z" />
    </svg>
  ),
  memory: (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 003 3h7.5a3 3 0 003-3m-13.5 0V5.25A2.25 2.25 0 017.5 3h9a2.25 2.25 0 012.25 2.25v6m-13.5 3v5.25a2.25 2.25 0 002.25 2.25h9a2.25 2.25 0 002.25-2.25v-5.25" />
    </svg>
  ),
  backups: (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
    </svg>
  ),
  'os-optimizer': (
    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-6.233 0c-1.296 1.296-1.422 2.956-.28 3.791 1.088.8 2.804.408 3.791-.28a4.493 4.493 0 002.72-3.511z" />
    </svg>
  ),
};

const pageNames: Record<Page, string> = {
  dashboard: 'Home',
  advanced: 'Advanced',
  network: 'Network',
  'bios-guide': 'BIOS',
  'gpu-guide': 'GPU Driver',
  memory: 'Memory',
  backups: 'Restore',
  'os-optimizer': 'OS Optimizer',
};

export default function TitleBar() {
  const { currentPage, isRunning, authUser, clearAuthState, setUpdateInfo } = useAppStore();
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [updateStatus, setUpdateStatus] = useState<{ tone: 'info' | 'success' | 'error'; message: string } | null>(null);
  const [appVersion, setAppVersion] = useState('v?');

  const handleSignOut = async () => {
    await window.sensequality.signOut();
    clearAuthState();
  };

  const handleCheckForUpdates = async () => {
    if (checkingUpdate) return;
    setCheckingUpdate(true);
    setUpdateStatus(null);

    try {
      const info = await window.sensequality.checkForUpdate();
      if (info.hasUpdate) {
        setUpdateInfo(info);
        setUpdateStatus({ tone: 'success', message: `Update available: v${info.latestVersion}` });
      } else {
        setUpdateStatus({ tone: 'info', message: `You're on the latest version (v${info.currentVersion})` });
      }
    } catch (error) {
      const message = error instanceof Error && error.message
        ? error.message
        : 'Update check failed. Please try again.';
      setUpdateStatus({ tone: 'error', message });
    } finally {
      setCheckingUpdate(false);
    }
  };

  useEffect(() => {
    if (!updateStatus) return;
    const timer = window.setTimeout(() => setUpdateStatus(null), 6000);
    return () => window.clearTimeout(timer);
  }, [updateStatus]);

  useEffect(() => {
    let mounted = true;

    window.sensequality.getAppVersion()
      .then((version) => {
        if (!mounted) return;
        const normalized = version.trim();
        if (!normalized) {
          setAppVersion('v?');
          return;
        }
        setAppVersion(normalized.startsWith('v') ? normalized : `v${normalized}`);
      })
      .catch(() => {
        if (mounted) setAppVersion('v?');
      });

    return () => {
      mounted = false;
    };
  }, []);

  const page = currentPage as Page;
  const pageIcon = pageIcons[page] || pageIcons.dashboard;
  const pageName = pageNames[page] || 'Home';

  return (
    <div className="drag-region relative z-[120] overflow-visible flex items-center justify-between h-12 bg-sq-surface/60 backdrop-blur-sm border-b sq-subtle-divider px-4 select-none shrink-0">
      {/* Breadcrumb navigation */}
      <div className="flex items-center gap-2 no-drag text-sq-text-muted">
        <span className="text-sq-text-dim">{pageIcon}</span>
        <svg className="w-3 h-3 text-sq-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
        </svg>
        <span className="text-sm font-semibold text-sq-text">{pageName}</span>
      </div>

      {/* Right controls */}
      <div className="flex items-center no-drag relative z-[130]">
        <div
          className="mr-2 px-2 py-1 rounded-md text-[10px] font-bold tracking-[0.08em] border border-sq-border/60 bg-sq-bg/60 text-sq-text-dim"
          title="Installed app version"
        >
          {appVersion}
        </div>
        <button
          onClick={handleCheckForUpdates}
          disabled={checkingUpdate}
          title={updateStatus?.message || 'Check for available updates'}
          className={`
            mr-2 px-2 py-1 rounded-md text-[10px] font-bold tracking-wide border transition-colors
            ${updateStatus?.tone === 'success'
              ? 'text-sq-accent-hover border-sq-accent/40 bg-sq-accent/14 hover:bg-sq-accent/20'
              : updateStatus?.tone === 'error'
                ? 'text-sq-danger border-sq-danger/40 bg-sq-danger/10 hover:bg-sq-danger/15'
                : 'text-sq-text-dim border-sq-border/60 hover:text-sq-text-muted hover:bg-sq-surface-hover/70'
            }
            ${checkingUpdate ? 'opacity-80 cursor-wait' : ''}
          `}
        >
          {checkingUpdate ? 'CHECKING...' : updateStatus?.tone === 'success' ? 'UPDATE READY' : 'CHECK UPDATE'}
        </button>
        {authUser && (
          <div className="relative mr-2">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-1.5 px-2 py-1 rounded-md text-sq-text-dim hover:text-sq-text-muted hover:bg-sq-surface-hover transition-colors border border-transparent hover:border-sq-border/60"
              title="Account menu"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
              <svg className={`w-3 h-3 transition-transform ${showUserMenu ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
              </svg>
            </button>
            {showUserMenu && (
              <>
                <div className="fixed inset-0 z-[190]" onClick={() => setShowUserMenu(false)} />
                <div className="absolute right-0 top-full mt-2 z-[200] no-drag bg-sq-surface border border-sq-border rounded-lg shadow-xl shadow-black/45 py-1 min-w-[220px]">
                  <div className="px-3 py-2 text-[10px] text-sq-text-dim border-b border-sq-border mb-1">
                    Signed in as<br />
                    <span className="text-sq-text-muted font-medium">{authUser.email}</span>
                  </div>
                  <button
                    onClick={handleCheckForUpdates}
                    disabled={checkingUpdate}
                    className="w-full px-3 py-2 text-left text-xs text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors flex items-center gap-2 font-medium disabled:opacity-60 disabled:cursor-wait"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-.001h4.992m0 0a8.25 8.25 0 0013.803-3.7M4.031 8.25a8.25 8.25 0 0113.803-3.7l.341.342m-10.14 14.75l-.34-.34m0 0l-3.16-3.16m3.16 3.16l3.16-3.16m8.318-10.818l3.16 3.16m-3.16-3.16l-3.16 3.16" />
                    </svg>
                    {checkingUpdate ? 'Checking updates...' : 'Check for Updates'}
                  </button>
                  {updateStatus && (
                    <div
                      className={`
                        px-3 py-2 text-[10px] border-t border-sq-border
                        ${updateStatus.tone === 'success'
                          ? 'text-sq-accent'
                          : updateStatus.tone === 'error'
                            ? 'text-sq-danger'
                            : 'text-sq-text-dim'
                        }
                      `}
                    >
                      {updateStatus.message}
                    </div>
                  )}
                  <button
                    onClick={() => { setShowUserMenu(false); handleSignOut(); }}
                    className="w-full px-3 py-2 text-left text-xs text-sq-danger/80 hover:text-sq-danger hover:bg-sq-danger/10 transition-colors flex items-center gap-2 font-medium"
                  >
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
                    </svg>
                    Sign Out
                  </button>
                </div>
              </>
            )}
          </div>
        )}
        <button
          onClick={() => window.sensequality.minimizeWindow()}
          className="w-9 h-10 flex items-center justify-center text-sq-text-dim hover:text-sq-text-muted hover:bg-sq-surface-hover transition-colors rounded"
        >
          <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.maximizeWindow()}
          className="w-9 h-10 flex items-center justify-center text-sq-text-dim hover:text-sq-text-muted hover:bg-sq-surface-hover transition-colors rounded"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1"><rect x="0.5" y="0.5" width="9" height="9"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.closeWindow()}
          className="w-9 h-10 flex items-center justify-center text-sq-text-dim hover:text-white hover:bg-sq-danger transition-colors rounded"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
        </button>
      </div>
    </div>
  );
}
