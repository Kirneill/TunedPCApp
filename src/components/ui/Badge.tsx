interface BadgeProps {
  variant: 'safe' | 'moderate' | 'success' | 'error' | 'info' | 'warning';
  children: React.ReactNode;
}

const variants: Record<BadgeProps['variant'], string> = {
  safe: 'bg-sq-success/15 text-sq-success',
  moderate: 'bg-sq-warning/15 text-sq-warning',
  success: 'bg-sq-success/15 text-sq-success',
  error: 'bg-sq-danger/15 text-sq-danger',
  info: 'bg-sq-accent/15 text-sq-accent-hover',
  warning: 'bg-sq-warning/15 text-sq-warning',
};

export default function Badge({ variant, children }: BadgeProps) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-medium uppercase tracking-wide ${variants[variant]}`}>
      {children}
    </span>
  );
}
