import { useAppStore } from '../../store/appStore';

export default function QuickActions() {
  const { toggles, userConfig, isRunning, setIsRunning, clearLog, setAllToggles } = useAppStore();

  const enabledIds = Object.entries(toggles)
    .filter(([id, enabled]) => id !== 'win-all' && enabled)
    .map(([id]) => id);

  const handleRunAll = async () => {
    if (isRunning || enabledIds.length === 0) return;

    setIsRunning(true);
    clearLog();

    try {
      await window.sensequality.runSelected(enabledIds, userConfig);
    } catch (err) {
      console.error('Run failed:', err);
    } finally {
      setIsRunning(false);
    }
  };

  const handleCreateRestorePoint = async () => {
    try {
      const result = await window.sensequality.createRestorePoint();
      if (result.success) {
        useAppStore.getState().addLogEntry({
          type: 'success',
          message: 'System restore point created successfully.',
          timestamp: Date.now(),
        });
      } else {
        useAppStore.getState().addLogEntry({
          type: 'error',
          message: `Restore point creation failed: ${result.errors?.join(', ') || 'Unknown error'}`,
          timestamp: Date.now(),
        });
      }
    } catch (err) {
      useAppStore.getState().addLogEntry({
        type: 'error',
        message: `Restore point creation failed: ${String(err)}`,
        timestamp: Date.now(),
      });
    }
  };

  return (
    <div className="flex items-center gap-3 flex-wrap">
      <button
        onClick={handleRunAll}
        disabled={isRunning || enabledIds.length === 0}
        className={`
          flex-1 min-w-[200px] py-3 px-6 rounded-xl font-semibold text-sm transition-all
          ${isRunning
            ? 'bg-sq-accent/50 text-white/70 cursor-wait'
            : enabledIds.length === 0
              ? 'bg-sq-border text-sq-text-dim cursor-not-allowed'
              : 'bg-sq-accent hover:bg-sq-accent-hover text-white shadow-lg shadow-sq-accent/20 cursor-pointer'
          }
        `}
      >
        {isRunning ? (
          <span className="flex items-center justify-center gap-2">
            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Optimizing...
          </span>
        ) : (
          `Run All Selected (${enabledIds.length})`
        )}
      </button>

      <button
        onClick={() => setAllToggles(true)}
        disabled={isRunning}
        className="px-4 py-3 rounded-xl text-xs font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
      >
        Select All
      </button>

      <button
        onClick={() => setAllToggles(false)}
        disabled={isRunning}
        className="px-4 py-3 rounded-xl text-xs font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
      >
        Deselect All
      </button>

      <button
        onClick={handleCreateRestorePoint}
        disabled={isRunning}
        className="px-4 py-3 rounded-xl text-xs font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
      >
        Restore Point
      </button>
    </div>
  );
}
