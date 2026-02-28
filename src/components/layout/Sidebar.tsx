import { useAppStore } from '../../store/appStore';

type Page = 'dashboard' | 'advanced' | 'bios-guide' | 'gpu-guide' | 'backups';

const navItems: { id: Page; label: string; hint: string; icon: string }[] = [
  { id: 'dashboard', label: 'Optimizer', hint: 'Games and Windows tuning', icon: 'OP' },
  { id: 'advanced', label: 'Advanced', hint: 'Fine-grained controls', icon: 'AD' },
  { id: 'bios-guide', label: 'BIOS Guide', hint: 'Recommended firmware setup', icon: 'BI' },
  { id: 'gpu-guide', label: 'GPU Driver', hint: 'One-click GPU profile', icon: 'GP' },
  { id: 'backups', label: 'Backups', hint: 'Restore and rollback points', icon: 'BK' },
];

export default function Sidebar() {
  const { currentPage, setCurrentPage, isRunning } = useAppStore();

  return (
    <aside className="w-60 sq-panel border-r sq-subtle-divider flex flex-col shrink-0">
      <div className="px-4 pt-4 pb-3 border-b sq-subtle-divider">
        <div className="rounded-xl sq-panel-muted px-3 py-3">
          <div className="text-[10px] uppercase tracking-[0.2em] text-sq-text-dim">Control Center</div>
          <div className="text-sm font-semibold text-sq-text mt-1">Navigation</div>
          <div className="text-[11px] text-sq-text-muted mt-1">Move between optimization, guides, and recovery tools.</div>
        </div>
      </div>

      <nav className="flex-1 py-4 px-2.5 space-y-1.5">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => setCurrentPage(item.id)}
            disabled={isRunning}
            className={`
              relative w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all
              ${currentPage === item.id
                ? 'bg-gradient-to-r from-sq-accent/20 via-sq-accent/12 to-transparent text-sq-text border border-sq-accent/40'
                : 'text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover border border-transparent'
              }
              ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
            `}
          >
            {currentPage === item.id && (
              <span className="absolute left-0 top-2.5 bottom-2.5 w-[2px] bg-sq-accent rounded-r" />
            )}
            <span className={`
              text-[10px] font-bold min-w-[2.25rem] text-center px-1.5 py-1 rounded-md border
              ${currentPage === item.id
                ? 'border-sq-accent/60 bg-sq-accent/18 text-sq-accent-hover'
                : 'border-sq-border bg-sq-bg text-sq-text-muted'
              }
            `}>
              {item.icon}
            </span>
            <span className="flex flex-col items-start min-w-0">
              <span className="truncate">{item.label}</span>
              <span className="text-[10px] text-sq-text-dim font-medium truncate">{item.hint}</span>
            </span>
          </button>
        ))}
      </nav>

      <div className="px-3 py-4 border-t sq-subtle-divider">
        <div className="rounded-lg border border-sq-border/70 bg-sq-bg/70 px-3 py-2">
          <div className="text-[10px] text-sq-text-dim uppercase tracking-wider mb-1">SENSEQUALITY</div>
          <div className="text-[11px] text-sq-text-muted">Performance Workspace</div>
        </div>
      </div>
    </aside>
  );
}
