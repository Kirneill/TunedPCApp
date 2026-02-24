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
  const { currentPage, setCurrentPage, isRunning } = useAppStore();

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

      {/* Window controls */}
      <div className="flex items-center no-drag">
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
