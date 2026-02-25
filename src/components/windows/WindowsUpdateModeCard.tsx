import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

interface WindowsUpdateModeCardProps {
  compact?: boolean;
}

export default function WindowsUpdateModeCard({ compact = false }: WindowsUpdateModeCardProps) {
  const {
    windowsUpdateMode,
    setWindowsUpdateMode,
    userConfig,
    addLogEntry,
    isRunning,
  } = useAppStore();

  const [isApplying, setIsApplying] = useState(false);
  const isOn = windowsUpdateMode === 'on';

  const handleToggle = async () => {
    if (isRunning || isApplying) return;

    const nextMode: 'on' | 'off' = isOn ? 'off' : 'on';
    const actionId = nextMode === 'off' ? 'updates-off' : 'updates-on';

    setIsApplying(true);
    addLogEntry({
      type: 'start',
      message: `Applying Windows Update mode: ${nextMode.toUpperCase()}`,
      timestamp: Date.now(),
      section: 'Windows Update',
    });

    try {
      const result = await window.sensequality.runOptimization(actionId, userConfig);
      if (result.success) {
        setWindowsUpdateMode(nextMode);
        addLogEntry({
          type: 'success',
          message: `Windows Update mode set to ${nextMode.toUpperCase()}.`,
          timestamp: Date.now(),
          section: 'Windows Update',
        });
      } else {
        addLogEntry({
          type: 'error',
          message: `Windows Update mode change failed: ${result.errors.join(' | ') || 'Unknown error'}`,
          timestamp: Date.now(),
          section: 'Windows Update',
        });
      }
    } catch (err) {
      addLogEntry({
        type: 'error',
        message: `Windows Update mode change failed: ${String(err)}`,
        timestamp: Date.now(),
        section: 'Windows Update',
      });
    } finally {
      setIsApplying(false);
    }
  };

  return (
    <div className="bg-sq-surface border border-sq-border rounded-xl p-4">
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-sm font-bold text-sq-text">Windows Update Mode</h3>
          <p className="text-[11px] text-sq-text-muted mt-0.5 leading-relaxed">
            {isOn
              ? 'ON (recommended): updates stay enabled with a security profile (driver updates blocked, auto-restart disabled while signed in, feature updates deferred 365 days, quality updates deferred 4 days).'
              : 'OFF: disables Windows Update services/tasks and automatic update checks. Use only if you patch Windows manually.'}
          </p>
        </div>

        <button
          onClick={handleToggle}
          disabled={isRunning || isApplying}
          className={`
            px-4 ${compact ? 'py-2' : 'py-2.5'} rounded-lg text-xs font-semibold tracking-wide transition-colors shrink-0
            ${isOn
              ? 'bg-sq-warning/20 text-sq-warning border border-sq-warning/40 hover:bg-sq-warning/30'
              : 'bg-sq-accent text-white border border-sq-accent hover:bg-sq-accent-hover'}
            ${(isRunning || isApplying) ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
          `}
        >
          {isApplying ? 'APPLYING...' : isOn ? 'TURN OFF' : 'TURN ON'}
        </button>
      </div>
    </div>
  );
}
