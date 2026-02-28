interface TweakCardProps {
  title: string;
  description: string;
  enabled: boolean;
  onToggle: (value: boolean) => void;
  disabled?: boolean;
  icon?: React.ReactNode;
  risk?: 'safe' | 'moderate';
  warning?: string;
}

export default function TweakCard({
  title,
  description,
  enabled,
  onToggle,
  disabled,
  icon,
  risk,
  warning,
}: TweakCardProps) {
  return (
    <div
      onClick={() => !disabled && onToggle(!enabled)}
      data-active={enabled}
      className={`
        sq-glass sq-card-hover rounded-xl p-4 flex flex-col gap-3 min-h-[140px]
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
      `}
    >
      {/* Header row: icon + badges */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2.5">
          {icon && (
            <div className={`
              w-8 h-8 rounded-lg flex items-center justify-center shrink-0
              ${enabled ? 'bg-sq-accent/20 text-sq-accent-hover' : 'bg-sq-border/60 text-sq-text-dim'}
              transition-colors
            `}>
              {icon}
            </div>
          )}
          <h4 className="text-sm font-semibold text-sq-text leading-snug">{title}</h4>
        </div>
        {risk === 'moderate' && (
          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wider bg-sq-warning/15 text-sq-warning border border-sq-warning/30 shrink-0">
            Moderate
          </span>
        )}
      </div>

      {/* Description */}
      <p className="text-[11px] text-sq-text-muted leading-relaxed flex-1">{description}</p>

      {/* Warning */}
      {warning && (
        <div className="flex items-center gap-1.5 text-[10px] text-sq-warning font-semibold">
          <svg className="w-3.5 h-3.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z" />
          </svg>
          {warning}
        </div>
      )}

      {/* Bottom row: toggle */}
      <div className="flex items-center justify-end mt-auto">
        <div className={`
          w-11 h-6 rounded-full flex items-center px-0.5 transition-colors shrink-0
          ${enabled ? 'bg-sq-accent' : 'bg-sq-border'}
        `}>
          <div className={`
            w-5 h-5 rounded-full bg-white shadow-md transition-transform
            ${enabled ? 'translate-x-5' : 'translate-x-0'}
          `} />
        </div>
      </div>
    </div>
  );
}
