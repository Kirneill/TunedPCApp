interface CircularProgressProps {
  value: number;       // 0-100
  size?: number;       // px, default 80
  strokeWidth?: number; // px, default 6
  label?: string;
  icon?: React.ReactNode;
  colorMode?: 'accent' | 'tier'; // 'tier' = green/amber/red based on value
}

function getTierColor(value: number): { stroke: string; glow: string; text: string } {
  if (value < 50) return { stroke: 'var(--color-sq-metric-low)', glow: 'rgba(38, 194, 103, 0.35)', text: 'text-sq-metric-low' };
  if (value < 80) return { stroke: 'var(--color-sq-metric-mid)', glow: 'rgba(255, 176, 32, 0.35)', text: 'text-sq-metric-mid' };
  return { stroke: 'var(--color-sq-metric-high)', glow: 'rgba(255, 77, 87, 0.4)', text: 'text-sq-metric-high' };
}

export default function CircularProgress({
  value,
  size = 80,
  strokeWidth = 6,
  label,
  icon,
  colorMode = 'accent',
}: CircularProgressProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.min(100, Math.max(0, value));
  const offset = circumference - (clamped / 100) * circumference;

  const tier = colorMode === 'tier' ? getTierColor(clamped) : null;
  const strokeColor = tier ? tier.stroke : 'var(--color-sq-accent)';
  const glowColor = tier ? tier.glow : 'rgba(225, 29, 47, 0.35)';
  const valueTextClass = tier ? tier.text : 'text-sq-text';

  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90">
          {/* Track */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="rgba(255,255,255,0.05)"
            strokeWidth={strokeWidth}
          />
          {/* Faint track glow */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={strokeColor}
            strokeWidth={strokeWidth}
            opacity={0.08}
          />
          {/* Progress */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={strokeColor}
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            className="transition-[stroke-dashoffset,stroke] duration-700 ease-out"
            style={{
              filter: clamped > 0 ? `drop-shadow(0 0 5px ${glowColor})` : undefined,
            }}
          />
        </svg>
        {/* Center content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          {icon && <div className="text-sq-text-dim mb-0.5">{icon}</div>}
          <span className={`text-lg font-bold leading-none ${valueTextClass}`}>
            {Math.round(clamped)}
            <span className="text-[10px] font-semibold opacity-60">%</span>
          </span>
        </div>
      </div>
      {label && (
        <span className="text-[10px] text-sq-text-dim font-semibold uppercase tracking-wider">{label}</span>
      )}
    </div>
  );
}
