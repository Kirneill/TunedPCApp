import CircularProgress from '../ui/CircularProgress';

interface SystemMetricCardProps {
  label: string;
  value: number;
  detail?: string;
  icon: React.ReactNode;
}

export default function SystemMetricCard({ label, value, detail, icon }: SystemMetricCardProps) {
  return (
    <div className="sq-glass rounded-xl p-4 flex items-center gap-4 min-w-0">
      <div className="shrink-0 w-8 h-8 rounded-lg bg-sq-accent/15 flex items-center justify-center text-sq-accent">
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-[10px] text-sq-text-dim uppercase tracking-wider font-semibold">{label}</div>
        {detail && <div className="text-[11px] text-sq-text-muted truncate mt-0.5">{detail}</div>}
      </div>
      <CircularProgress value={value} size={64} strokeWidth={5} />
    </div>
  );
}
