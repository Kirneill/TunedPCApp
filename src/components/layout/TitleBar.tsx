import { useEffect, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import appLogo from '../../assets/app-logo.ico';

type Page = 'dashboard' | 'advanced' | 'bios-guide' | 'gpu-guide' | 'backups';

const navItems: { id: Page; label: string }[] = [
  { id: 'dashboard', label: 'GAMES' },
  { id: 'advanced', label: 'ADVANCED' },
  { id: 'bios-guide', label: 'BIOS' },
  { id: 'gpu-guide', label: 'GPU' },
  { id: 'backups', label: 'BACKUPS' },
];

export default function TitleBar() {
  const { currentPage, setCurrentPage, isRunning, authUser, clearAuthState, setUpdateInfo } = useAppStore();
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [updateStatus, setUpdateStatus] = useState<{ tone: 'info' | 'success' | 'error'; message: string } | null>(null);

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

  return (
    <div className="drag-region flex items-center justify-between h-11 bg-sq-surface/80 backdrop-blur-sm border-b border-sq-border px-4 select-none shrink-0">
      {/* Logo */}
      <div className="flex items-center gap-3 no-drag">
        <div className="flex items-center gap-2">
          <img src={appLogo} alt="TUNEDPC by SENSEQUALITY.com logo" className="w-6 h-6 rounded" />
          <span className="text-[11px] font-bold text-sq-text tracking-[0.02em]">TUNEDPC by SENSEQUALITY.com</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex items-center gap-1 no-drag">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => setCurrentPage(item.id)}
            disabled={isRunning}
            className={`
              px-4 py-1.5 rounded-lg text-xs font-bold tracking-widest transition-all
              ${currentPage === item.id
                ? 'bg-sq-accent text-white shadow-md shadow-sq-accent/30'
                : 'text-sq-text/60 hover:text-white hover:bg-white/5'
              }
              ${isRunning ? 'opacity-50' : ''}
            `}
          >
            {item.label}
          </button>
        ))}
      </nav>

      {/* User + Window controls */}
      <div className="flex items-center no-drag relative">
        <button
          onClick={handleCheckForUpdates}
          disabled={checkingUpdate}
          title={updateStatus?.message || 'Check for available updates'}
          className={`
            mr-2 px-2.5 py-1.5 rounded-lg text-[10px] font-bold tracking-wide border transition-colors
            ${updateStatus?.tone === 'success'
              ? 'text-sq-accent border-sq-accent/40 bg-sq-accent/10 hover:bg-sq-accent/15'
              : updateStatus?.tone === 'error'
                ? 'text-sq-danger border-sq-danger/40 bg-sq-danger/10 hover:bg-sq-danger/15'
                : 'text-sq-text-muted border-sq-border hover:text-sq-text hover:bg-sq-surface-hover'
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
              className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors border border-transparent hover:border-sq-border"
              title="Account menu"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
              <span className="text-[11px] max-w-[140px] truncate">{authUser.email}</span>
              <svg className={`w-3 h-3 transition-transform ${showUserMenu ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
              </svg>
            </button>
            {showUserMenu && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setShowUserMenu(false)} />
                <div className="absolute right-0 top-full mt-1 z-50 bg-sq-surface border border-sq-border rounded-lg shadow-xl py-1 min-w-[160px]">
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
          className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
        >
          <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.maximizeWindow()}
          className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1"><rect x="0.5" y="0.5" width="9" height="9"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.closeWindow()}
          className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-white hover:bg-sq-danger transition-colors"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
        </button>
      </div>
    </div>
  );
}
