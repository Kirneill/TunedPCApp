import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

type Page = 'dashboard' | 'advanced' | 'bios-guide' | 'gpu-guide' | 'backups';

const navItems: { id: Page; label: string }[] = [
  { id: 'dashboard', label: 'GAMES' },
  { id: 'advanced', label: 'ADVANCED' },
  { id: 'bios-guide', label: 'BIOS' },
  { id: 'gpu-guide', label: 'GPU' },
  { id: 'backups', label: 'BACKUPS' },
];

export default function TitleBar() {
  const { currentPage, setCurrentPage, isRunning, authUser, clearAuthState } = useAppStore();
  const [showUserMenu, setShowUserMenu] = useState(false);

  const handleSignOut = async () => {
    await window.sensequality.signOut();
    clearAuthState();
  };

  return (
    <div className="drag-region flex items-center justify-between h-11 bg-sq-surface/80 backdrop-blur-sm border-b border-sq-border px-4 select-none shrink-0">
      {/* Logo */}
      <div className="flex items-center gap-3 no-drag">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded bg-sq-accent flex items-center justify-center text-[10px] font-bold text-white tracking-tight">
            SQ
          </div>
          <span className="text-sm font-bold text-sq-text tracking-wide">SENSEQUALITY</span>
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
        {authUser && (
          <div className="relative mr-2">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
              <span className="text-[10px] max-w-[120px] truncate">{authUser.email}</span>
            </button>
            {showUserMenu && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setShowUserMenu(false)} />
                <div className="absolute right-0 top-full mt-1 z-50 bg-sq-surface border border-sq-border rounded-lg shadow-xl py-1 min-w-[140px]">
                  <button
                    onClick={() => { setShowUserMenu(false); handleSignOut(); }}
                    className="w-full px-3 py-2 text-left text-xs text-sq-text-muted hover:text-white hover:bg-sq-surface-hover transition-colors flex items-center gap-2"
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
