type TileStatus = 'good' | 'warning' | 'unknown' | 'neutral';

interface StatusTileProps {
  label: string;
  value: string;
  status: TileStatus;
}

const STATUS_STYLES: Record<TileStatus, { border: string; dot: string; bg: string; glow: React.CSSProperties }> = {
  good: {
    border: 'border-sq-success/30',
    dot: 'bg-sq-success',
    bg: 'bg-sq-success/5',
    glow: { boxShadow: '0 0 6px var(--color-sq-success)' },
  },
  warning: {
    border: 'border-sq-warning/30',
    dot: 'bg-sq-warning',
    bg: 'bg-sq-warning/5',
    glow: { boxShadow: '0 0 6px var(--color-sq-warning)' },
  },
  neutral: {
    border: 'border-sq-accent/20',
    dot: 'bg-sq-accent',
    bg: 'bg-sq-accent/5',
    glow: { boxShadow: '0 0 6px var(--color-sq-accent)' },
  },
  unknown: {
    border: 'border-sq-border/40',
    dot: 'bg-sq-text-dim',
    bg: '',
    glow: {},
  },
};

export default function StatusTile({ label, value, status }: StatusTileProps) {
  const styles = STATUS_STYLES[status];

  return (
    <div className={`sq-glass border ${styles.border} rounded-xl px-3.5 py-3 ${styles.bg}`}>
      <div className="flex items-center gap-1.5 mb-1">
        <div className={`w-2 h-2 rounded-full ${styles.dot}`} style={styles.glow} />
        <span className="text-[10px] font-bold text-sq-text-muted uppercase tracking-wider">{label}</span>
      </div>
      <span className="text-[12px] font-semibold text-sq-text">{value}</span>
    </div>
  );
}
