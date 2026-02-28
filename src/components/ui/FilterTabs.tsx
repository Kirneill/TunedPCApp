interface FilterTab {
  id: string;
  label: string;
  icon?: React.ReactNode;
}

interface FilterTabsProps {
  tabs: FilterTab[];
  activeId: string;
  onChange: (id: string) => void;
  disabled?: boolean;
}

export default function FilterTabs({ tabs, activeId, onChange, disabled }: FilterTabsProps) {
  return (
    <div className="flex items-center gap-1.5 flex-wrap">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onChange(tab.id)}
          disabled={disabled}
          className={`
            sq-focus-ring flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-semibold tracking-wide transition-all
            ${activeId === tab.id
              ? 'bg-sq-accent/20 text-sq-accent-hover border border-sq-accent/50 shadow-sm shadow-sq-accent/10'
              : 'bg-sq-bg/80 text-sq-text-muted border border-sq-border hover:text-sq-text hover:border-sq-text-dim'
            }
            ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
          `}
        >
          {tab.icon}
          {tab.label}
        </button>
      ))}
    </div>
  );
}
