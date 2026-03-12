import { useAppStore } from '../../store/appStore';
import { requiresPro } from '../../data/feature-tiers';
import appLogo from '../../assets/app-logo.ico';

type Page = 'dashboard' | 'advanced' | 'network' | 'bios-guide' | 'gpu-guide' | 'backups' | 'os-optimizer';

const LockIcon = () => (
  <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
  </svg>
);

const GamepadIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875S10.5 3.09 10.5 4.125c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.959.401v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z" />
  </svg>
);

const SlidersIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
  </svg>
);

const ChipIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
  </svg>
);

const GpuIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z" />
  </svg>
);

const NetworkIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M8.288 15.038a5.25 5.25 0 017.424 0M5.106 11.856c3.807-3.808 9.98-3.808 13.788 0M1.924 8.674c5.565-5.565 14.587-5.565 20.152 0M12.53 18.22l-.53.53-.53-.53a.75.75 0 011.06 0z" />
  </svg>
);

const RocketIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-6.233 0c-1.296 1.296-1.422 2.956-.28 3.791 1.088.8 2.804.408 3.791-.28a4.493 4.493 0 002.72-3.511z" />
  </svg>
);

const ShieldIcon = () => (
  <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
  </svg>
);

const sections = [
  {
    label: 'General',
    items: [
      { id: 'dashboard' as Page, label: 'Optimizer', hint: 'Games and Windows tuning', icon: <GamepadIcon /> },
    ],
  },
  {
    label: 'Tweaks',
    items: [
      { id: 'advanced' as Page, label: 'Advanced', hint: 'Fine-grained controls', icon: <SlidersIcon /> },
      { id: 'network' as Page, label: 'Network', hint: 'Latency optimization', icon: <NetworkIcon /> },
      { id: 'os-optimizer' as Page, label: 'OS Optimizer', hint: 'Lightweight Windows mode', icon: <RocketIcon /> },
    ],
  },
  {
    label: 'System',
    items: [
      { id: 'bios-guide' as Page, label: 'BIOS Guide', hint: 'Firmware setup', icon: <ChipIcon /> },
      { id: 'gpu-guide' as Page, label: 'GPU Driver', hint: 'One-click GPU profile', icon: <GpuIcon /> },
      { id: 'backups' as Page, label: 'Restore', hint: 'System restore points', icon: <ShieldIcon /> },
    ],
  },
];

export default function Sidebar() {
  const { currentPage, setCurrentPage, isRunning, authUser, isPro } = useAppStore();

  return (
    <aside className="w-60 sq-panel border-r sq-subtle-divider flex flex-col shrink-0 sq-aurora">
      {/* App branding */}
      <div className="px-4 pt-4 pb-3 border-b sq-subtle-divider relative z-10">
        <div className="flex items-center gap-2.5">
          <div className="relative">
            <img src={appLogo} alt="TunedPC" className="w-8 h-8 rounded-lg" />
            <div className="absolute -inset-0.5 rounded-lg bg-sq-accent/15 blur-sm -z-10" />
          </div>
          <div className="flex flex-col min-w-0">
            <span className="text-sm font-bold text-sq-text tracking-[0.12em]">TUNEDPC</span>
            <span className="text-[9px] text-sq-text-dim tracking-[0.08em] uppercase">by Sensequality</span>
          </div>
        </div>
      </div>

      {/* Navigation sections */}
      <nav className="flex-1 py-3 px-2.5 space-y-4 overflow-y-auto relative z-10">
        {sections.map((section) => (
          <div key={section.label}>
            <div className="px-3 mb-2 text-[9px] uppercase tracking-[0.22em] text-sq-text-dim/70 font-bold">
              {section.label}
            </div>
            <div className="space-y-1">
              {section.items.map((item) => {
                const isProPage = requiresPro(item.id);
                const isLocked = isProPage && !isPro();

                return (
                  <button
                    key={item.id}
                    onClick={() => setCurrentPage(item.id)}
                    disabled={isRunning}
                    className={`
                      relative w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200
                      ${currentPage === item.id
                        ? 'bg-gradient-to-r from-sq-accent/18 via-sq-accent/8 to-transparent text-sq-text border border-sq-accent/30 shadow-[inset_0_0_12px_rgba(225,29,47,0.06)]'
                        : 'text-sq-text-muted hover:text-sq-text hover:bg-white/[0.03] border border-transparent'
                      }
                      ${isRunning ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
                    `}
                  >
                    {currentPage === item.id && (
                      <span className="absolute left-0 top-2 bottom-2 w-[3px] bg-sq-accent rounded-r" />
                    )}
                    <span className={`
                      w-8 h-8 rounded-lg flex items-center justify-center shrink-0 transition-colors
                      ${currentPage === item.id
                        ? 'bg-sq-accent/18 text-sq-accent-hover'
                        : 'bg-sq-bg/60 text-sq-text-dim'
                      }
                    `}>
                      {item.icon}
                    </span>
                    <span className="flex flex-col items-start min-w-0 flex-1">
                      <span className="truncate leading-snug flex items-center gap-1.5">
                        {item.label}
                        {isLocked && (
                          <span className="text-sq-text-dim/60"><LockIcon /></span>
                        )}
                      </span>
                      <span className="text-[10px] text-sq-text-dim font-normal truncate">
                        {isLocked ? 'Pro feature' : item.hint}
                      </span>
                    </span>
                    {isLocked && (
                      <span className="text-[8px] font-bold uppercase tracking-wider text-sq-accent/70 bg-sq-accent/10 px-1.5 py-0.5 rounded shrink-0">
                        PRO
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* User profile footer */}
      <div className="px-3 py-3 border-t sq-subtle-divider relative z-10">
        <div className="flex items-center gap-2.5 px-2 py-2 rounded-lg hover:bg-white/[0.03] transition-colors">
          <div className="relative shrink-0">
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-sq-accent/25 to-sq-accent/10 flex items-center justify-center text-sq-accent text-xs font-bold">
              {authUser?.email?.charAt(0).toUpperCase() || 'U'}
            </div>
            <div className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-sq-success border-2 border-sq-bg" />
          </div>
          <div className="flex flex-col min-w-0">
            <span className="text-[11px] text-sq-text font-medium truncate">
              {authUser?.email || 'Not signed in'}
            </span>
            <span className={`text-[9px] font-semibold uppercase tracking-wider ${isPro() ? 'text-sq-accent/70' : 'text-sq-text-dim/50'}`}>
              {isPro() ? 'Pro' : 'Free'}
            </span>
          </div>
        </div>
      </div>
    </aside>
  );
}
