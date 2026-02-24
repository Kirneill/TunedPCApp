import Toggle from '../ui/Toggle';
import Badge from '../ui/Badge';
import type { OptimizationItem } from '../../types';

interface OptimizationToggleProps {
  item: OptimizationItem;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}

export default function OptimizationToggle({ item, checked, onChange, disabled }: OptimizationToggleProps) {
  return (
    <div className="flex items-start gap-3 py-2.5 px-1">
      <Toggle checked={checked} onChange={onChange} disabled={disabled} />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className={`text-sm font-medium ${checked ? 'text-sq-text' : 'text-sq-text-muted'}`}>
            {item.label}
          </span>
          <Badge variant={item.risk}>{item.risk}</Badge>
          {item.requiresReboot && (
            <span className="text-[10px] text-sq-warning">reboot</span>
          )}
        </div>
        <p className="text-[11px] text-sq-text-dim mt-0.5 leading-relaxed">{item.description}</p>
      </div>
    </div>
  );
}
