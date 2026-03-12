import { useAppStore } from '../../store/appStore';
import type { BiosSetting } from '../../types';

type DetectionState = 'optimized' | 'needs-attention' | 'unknown';

const vendorLabels: { key: keyof BiosSetting['vendorNav']; label: string }[] = [
  { key: 'asus', label: 'ASUS' },
  { key: 'msi', label: 'MSI' },
  { key: 'gigabyte', label: 'Gigabyte' },
  { key: 'asrock', label: 'ASRock' },
];

interface Props {
  setting: BiosSetting;
  detectedVendor?: string;
  detectionState: DetectionState;
}

export default function BiosSettingRow({ setting, detectedVendor, detectionState }: Props) {
  const expanded = useAppStore((s) => s.biosExpandedSettings[setting.id] ?? false);
  const toggleExpanded = useAppStore((s) => s.toggleBiosSettingExpanded);
  const normalizedVendor = detectedVendor?.toLowerCase();

  const dotClass = detectionState === 'optimized' ? 'bg-sq-success' : detectionState === 'needs-attention' ? 'bg-sq-warning' : 'bg-sq-text-dim/40';
  const borderClass = detectionState === 'needs-attention' ? 'border-sq-warning/20' : 'border-transparent';

  return (
    <div className={`border rounded-lg transition-colors ${borderClass} hover:bg-sq-surface-hover/30`}>
      {/* Clickable row */}
      <button
        onClick={() => toggleExpanded(setting.id)}
        className="w-full flex items-center gap-3 px-3 py-2.5 cursor-pointer text-left"
      >
        <div className={`w-2 h-2 rounded-full shrink-0 ${dotClass}`} />

        <span className="flex-1 min-w-0 text-[13px] font-medium text-sq-text truncate">
          {setting.title}
        </span>

        {detectionState === 'needs-attention' && (
          <span className="text-[9px] font-bold text-sq-warning bg-sq-warning/10 px-1.5 py-0.5 rounded shrink-0">
            FIX
          </span>
        )}

        <span className="text-[10px] text-sq-text-dim font-mono shrink-0 hidden sm:block">{setting.recommendedValue}</span>

        <svg className={`w-3.5 h-3.5 text-sq-text-muted transition-transform shrink-0 ${expanded ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {/* Expanded details */}
      {expanded && (
        <div className="px-3 pb-3 pt-0 ml-6 space-y-2.5">
          <p className="text-xs text-sq-text-muted leading-relaxed">{setting.description}</p>

          <div className="bg-sq-bg rounded-lg p-2.5 text-[11px] text-sq-text-muted leading-relaxed">{setting.details}</div>

          <div className="flex items-center gap-2 text-[10px]">
            <span className={`font-bold px-1.5 py-0.5 rounded ${
              setting.impact === 'high' ? 'text-sq-success bg-sq-success/10' :
              setting.impact === 'medium' ? 'text-sq-accent bg-sq-accent/10' :
              'text-sq-text-dim bg-sq-text-dim/10'
            }`}>
              {setting.impact === 'high' ? 'BIG FPS BOOST' : setting.impact === 'medium' ? 'MODERATE BOOST' : 'SMALL BOOST'}
            </span>
            <span className={`font-bold px-1.5 py-0.5 rounded ${
              setting.risk === 'safe' ? 'text-sq-success bg-sq-success/10' :
              setting.risk === 'caution' ? 'text-sq-warning bg-sq-warning/10' :
              'text-sq-danger bg-sq-danger/10'
            }`}>
              {setting.risk === 'safe' ? 'NO RISK' : setting.risk === 'caution' ? 'TEST AFTER APPLYING' : 'EXPERT'}
            </span>
            {setting.platform !== 'both' && (
              <span className="font-bold text-sq-accent bg-sq-accent/10 px-1.5 py-0.5 rounded uppercase">{setting.platform === 'amd' ? 'AMD ONLY' : 'INTEL ONLY'}</span>
            )}
          </div>

          {setting.warning && (
            <div className="flex items-start gap-2 bg-sq-warning/5 border border-sq-warning/20 rounded-lg px-2.5 py-2">
              <svg className="w-3.5 h-3.5 text-sq-warning shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <span className="text-[11px] text-sq-warning">{setting.warning}</span>
            </div>
          )}

          <div className="space-y-1">
            <span className="text-[9px] font-bold text-sq-text-dim uppercase tracking-wider">Where to find this in BIOS</span>
            <div className="grid gap-0.5">
              {vendorLabels.map(({ key, label }) => {
                const isDetected = normalizedVendor && normalizedVendor.includes(key);
                return (
                  <div key={key} className={`flex items-start gap-2 text-[11px] px-2 py-1 rounded ${isDetected ? 'bg-sq-accent/10 border border-sq-accent/20' : 'bg-sq-bg'}`}>
                    <span className={`font-semibold shrink-0 w-14 ${isDetected ? 'text-sq-accent' : 'text-sq-text-muted'}`}>
                      {label}
                      {isDetected && <span className="text-[8px] ml-0.5 text-sq-accent-hover">(you)</span>}
                    </span>
                    <span className="text-sq-text-dim font-mono text-[10px]">{setting.vendorNav[key]}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
