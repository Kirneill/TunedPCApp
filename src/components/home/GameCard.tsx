import { useAppStore } from '../../store/appStore';

interface GameCardProps {
  id: string;
  toggleId: string;
  name: string;
  subtitle: string;
  gradient: string;
  letter: string;
  installed: boolean;
  compact?: boolean;
}

export default function GameCard({ id, toggleId, name, subtitle, gradient, letter, installed, compact = false }: GameCardProps) {
  const { toggles, setToggle, isRunning } = useAppStore();
  const enabled = toggles[toggleId] ?? false;

  return (
    <div
      className={`
        game-card-glow relative rounded-2xl overflow-hidden cursor-pointer select-none flex flex-col
        ${enabled ? 'active' : ''}
      `}
      onClick={() => {
        if (!isRunning) setToggle(toggleId, !enabled);
      }}
    >
      {/* Background gradient */}
      <div className={`flex-1 ${compact ? 'min-h-[120px]' : 'min-h-[200px]'} ${gradient} relative`}>
        {/* Large letter as placeholder */}
        <div className="absolute inset-0 flex items-center justify-center">
          <span className={`${compact ? 'text-6xl' : 'text-8xl'} font-black text-white/8 select-none`}>{letter}</span>
        </div>

        {/* Toggle indicator */}
        <div className="absolute top-3 right-3">
          <div className={`
            w-14 h-8 rounded-full flex items-center px-1 transition-colors
            ${enabled ? 'bg-sq-accent' : 'bg-black/50 backdrop-blur-sm'}
          `}>
            <div className={`
              w-6 h-6 rounded-full bg-white shadow-md transition-transform
              ${enabled ? 'translate-x-6' : 'translate-x-0'}
            `} />
          </div>
        </div>

        {/* Status badge */}
        {enabled && (
          <div className="absolute top-3 left-3 px-2.5 py-1 bg-sq-accent/80 backdrop-blur-sm rounded text-[10px] text-white font-semibold tracking-wide">
            OPTIMIZED
          </div>
        )}

        {/* Install status */}
        <div className="absolute bottom-3 left-3">
          <span className={`
            px-2 py-1 rounded text-[10px] font-semibold tracking-wide border
            ${installed
              ? 'text-sq-success border-sq-success/40 bg-black/45 backdrop-blur-sm'
              : 'text-sq-warning border-sq-warning/40 bg-black/45 backdrop-blur-sm'
            }
          `}>
            {installed ? 'FOUND' : 'NOT FOUND'}
          </span>
        </div>

        {/* Bottom gradient fade */}
        <div className="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-t from-sq-surface to-transparent" />
      </div>

      {/* Info */}
      <div className={`bg-sq-surface px-4 ${compact ? 'pb-3' : 'pb-4'} -mt-1`}>
        <h3 className={`${compact ? 'text-sm' : 'text-base'} font-bold text-sq-text leading-tight`}>{name}</h3>
        <p className="text-[11px] text-sq-text-muted mt-0.5">{subtitle}</p>
      </div>
    </div>
  );
}
