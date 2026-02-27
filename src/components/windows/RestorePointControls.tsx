import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

interface RestorePointControlsProps {
  compact?: boolean;
}

export default function RestorePointControls({ compact = false }: RestorePointControlsProps) {
  const {
    userConfig,
    setUserConfig,
    addLogEntry,
    isRunning,
  } = useAppStore();
  const [isCreating, setIsCreating] = useState(false);
  const autoEnabled = userConfig.restorePointEnabled !== false;

  const handleToggleAuto = () => {
    if (isRunning || isCreating) return;
    setUserConfig({ restorePointEnabled: !autoEnabled });
  };

  const handleCreateNow = async () => {
    if (isRunning || isCreating) return;
    setIsCreating(true);
    addLogEntry({
      type: 'start',
      message: 'Creating system restore point...',
      timestamp: Date.now(),
      section: 'Safety',
    });

    try {
      const result = await window.sensequality.createRestorePoint();
      if (result.success) {
        addLogEntry({
          type: 'success',
          message: 'System restore point created successfully.',
          timestamp: Date.now(),
          section: 'Safety',
        });
      } else {
        addLogEntry({
          type: 'error',
          message: `Restore point creation failed: ${result.errors.join(' | ') || 'Unknown error'}`,
          timestamp: Date.now(),
          section: 'Safety',
        });
      }
    } catch (err) {
      addLogEntry({
        type: 'error',
        message: `Restore point creation failed: ${String(err)}`,
        timestamp: Date.now(),
        section: 'Safety',
      });
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="bg-sq-surface border border-sq-border rounded-xl p-4">
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <h3 className="text-sm font-bold text-sq-text">System Restore Point</h3>
          <p className="text-[11px] text-sq-text-muted mt-0.5 leading-relaxed">
            {autoEnabled
              ? 'Auto-create before optimization is ON.'
              : 'Auto-create before optimization is OFF. Optimizations run without creating a restore point.'}
          </p>
        </div>

        <div className="flex items-center gap-3 shrink-0">
          <button
            onClick={handleCreateNow}
            disabled={isRunning || isCreating}
            className={`
              px-4 ${compact ? 'py-2' : 'py-2.5'} rounded-lg text-xs font-semibold tracking-wide transition-colors border
              ${isRunning || isCreating
                ? 'opacity-50 cursor-not-allowed border-sq-border text-sq-text-muted'
                : 'cursor-pointer border-sq-accent text-white bg-sq-accent hover:bg-sq-accent-hover'}
            `}
          >
            {isCreating ? 'CREATING...' : 'CREATE NOW'}
          </button>

          <button
            onClick={handleToggleAuto}
            disabled={isRunning || isCreating}
            className={`
              w-12 h-7 rounded-full flex items-center px-1 transition-colors
              ${autoEnabled ? 'bg-sq-accent' : 'bg-sq-border'}
              ${isRunning || isCreating ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
            `}
            title={autoEnabled ? 'Auto restore point enabled' : 'Auto restore point disabled'}
          >
            <span
              className={`
                w-5 h-5 rounded-full bg-white shadow-md transition-transform
                ${autoEnabled ? 'translate-x-5' : 'translate-x-0'}
              `}
            />
          </button>
        </div>
      </div>
    </div>
  );
}
