interface TabButtonProps {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  badge?: string;
}

export default function TabButton({ active, onClick, icon, label, badge }: TabButtonProps) {
  return (
    <button
      onClick={onClick}
      data-active={active}
      className={`
        sq-card-hover flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-xl text-sm font-bold transition-all cursor-pointer
        ${active
          ? 'sq-glass text-white border-sq-accent shadow-lg shadow-sq-accent/10'
          : 'text-sq-text-muted hover:text-sq-text border border-sq-border/40 bg-sq-surface/40'
        }
      `}
    >
      <span className={`
        w-9 h-9 rounded-lg flex items-center justify-center transition-colors
        ${active ? 'bg-sq-accent/20 text-sq-accent' : 'bg-sq-border/40 text-sq-text-dim'}
      `}>
        {icon}
      </span>
      <span className="text-[14px]">{label}</span>
      {badge && (
        <span className={`text-[9px] font-bold uppercase tracking-wider px-2 py-1 rounded-md ${
          active ? 'bg-sq-accent/25 text-sq-accent border border-sq-accent/30' : 'bg-sq-bg/80 text-sq-text-dim'
        }`}>
          {badge}
        </span>
      )}
    </button>
  );
}
