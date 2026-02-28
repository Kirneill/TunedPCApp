interface CircularProgressProps {
  value: number;       // 0-100
  size?: number;       // px, default 80
  strokeWidth?: number; // px, default 6
  label?: string;
  icon?: React.ReactNode;
}

export default function CircularProgress({
  value,
  size = 80,
  strokeWidth = 6,
  label,
  icon,
}: CircularProgressProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.min(100, Math.max(0, value));
  const offset = circumference - (clamped / 100) * circumference;

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
            stroke="rgba(255,255,255,0.06)"
            strokeWidth={strokeWidth}
          />
          {/* Progress */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="var(--color-sq-accent)"
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            className="transition-[stroke-dashoffset] duration-700 ease-out"
            style={{
              filter: clamped > 0 ? 'drop-shadow(0 0 4px rgba(225, 29, 47, 0.4))' : undefined,
            }}
          />
        </svg>
        {/* Center content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          {icon && <div className="text-sq-text-muted mb-0.5">{icon}</div>}
          <span className="text-lg font-bold text-sq-text leading-none">{Math.round(clamped)}%</span>
        </div>
      </div>
      {label && (
        <span className="text-[11px] text-sq-text-muted font-medium">{label}</span>
      )}
    </div>
  );
}
