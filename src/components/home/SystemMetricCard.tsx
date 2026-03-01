import type { ReactNode } from 'react';
import CircularProgress from '../ui/CircularProgress';

interface SystemMetricCardProps {
  label: string;
  value: number;
  detail?: string;
  icon: ReactNode;
}

function getAccentColor(value: number): string {
  if (value < 50) return 'rgba(38, 194, 103, 0.5)';
  if (value < 80) return 'rgba(255, 176, 32, 0.5)';
  return 'rgba(255, 77, 87, 0.55)';
}

export default function SystemMetricCard({ label, value, detail, icon }: SystemMetricCardProps) {
  const borderColor = getAccentColor(value);

  return (
    <div
      className="sq-glass sq-noise relative rounded-xl p-4 flex items-center gap-4 min-w-0 overflow-hidden sq-fade-up"
      style={{ borderLeft: `3px solid ${borderColor}` }}
    >
      <div className="relative z-10 shrink-0 w-8 h-8 rounded-lg bg-white/[0.04] flex items-center justify-center text-sq-text-muted">
        {icon}
      </div>
      <div className="relative z-10 flex-1 min-w-0">
        <div className="text-[10px] text-sq-text-dim uppercase tracking-[0.15em] font-semibold">{label}</div>
        {detail && <div className="text-[11px] text-sq-text-muted truncate mt-0.5 font-medium">{detail}</div>}
      </div>
      <div className="relative z-10">
        <CircularProgress value={value} size={60} strokeWidth={4.5} colorMode="tier" />
      </div>
    </div>
  );
}
