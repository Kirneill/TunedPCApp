import { useAppStore } from '../../store/appStore';

type Page = 'dashboard' | 'bios-guide' | 'gpu-guide' | 'backups';

const navItems: { id: Page; label: string; icon: string }[] = [
  { id: 'dashboard', label: 'Dashboard', icon: '⚡' },
  { id: 'bios-guide', label: 'BIOS Guide', icon: '🔧' },
  { id: 'gpu-guide', label: 'GPU Guide', icon: '🎮' },
  { id: 'backups', label: 'Backups', icon: '💾' },
];

export default function Sidebar() {
  const { currentPage, setCurrentPage, isRunning } = useAppStore();

  return (
    <aside className="w-48 bg-sq-surface border-r border-sq-border flex flex-col shrink-0">
      <nav className="flex-1 py-4 px-2 space-y-1">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => setCurrentPage(item.id)}
            disabled={isRunning}
            className={`
              w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors
              ${currentPage === item.id
                ? 'bg-sq-accent/15 text-sq-accent-hover'
                : 'text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover'
              }
              ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
            `}
          >
            <span className="text-base">{item.icon}</span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      <div className="px-3 py-4 border-t border-sq-border">
        <div className="text-[10px] text-sq-text-dim uppercase tracking-wider mb-1">SENSEQUALITY</div>
        <div className="text-[10px] text-sq-text-dim">v1.0.4</div>
      </div>
    </aside>
  );
}
