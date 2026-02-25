import { useAppStore } from '../../store/appStore';
import { windowsOptimizations, gameOptimizations } from '../../data/optimizations';
import OptimizationSection from '../optimizations/OptimizationSection';
import MonitorConfig from '../dashboard/MonitorConfig';
import LogViewer from '../ui/LogViewer';

export default function AdvancedPage() {
  const { toggles, userConfig, isRunning, setIsRunning, clearLog, progressLog, setAllToggles, telemetryEnabled, setTelemetryEnabled } = useAppStore();

  const enabledIds = Object.entries(toggles)
    .filter(([, enabled]) => enabled)
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

  return (
    <div className="p-6 max-w-4xl mx-auto space-y-5 overflow-y-auto h-full">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold text-sq-text">Advanced Settings</h1>
          <p className="text-xs text-sq-text-muted mt-0.5">
            Granular control over every optimization. Toggle individual settings on or off.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setAllToggles(true)}
            disabled={isRunning}
            className="px-3 py-1.5 rounded-lg text-[11px] font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
          >
            Select All
          </button>
          <button
            onClick={() => setAllToggles(false)}
            disabled={isRunning}
            className="px-3 py-1.5 rounded-lg text-[11px] font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
          >
            Deselect All
          </button>
        </div>
      </div>

      <OptimizationSection
        title="Windows Optimizations"
        items={windowsOptimizations}
        icon="⚡"
      />

      <OptimizationSection
        title="Game Optimizations"
        items={gameOptimizations}
        icon="🎮"
      />

      <MonitorConfig />

      {/* Telemetry toggle */}
      <div className="bg-sq-surface border border-sq-border rounded-xl px-5 py-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-semibold text-sq-text">Anonymous Usage Data</h3>
            <p className="text-[11px] text-sq-text-dim mt-0.5">
              Help improve SENSEQUALITY by sharing anonymous hardware and optimization results.
              No personal info is ever collected.
            </p>
          </div>
          <div
            className={`
              w-12 h-7 rounded-full flex items-center px-1 transition-colors shrink-0 cursor-pointer
              ${telemetryEnabled ? 'bg-sq-accent' : 'bg-sq-border'}
            `}
            onClick={async () => {
              const next = !telemetryEnabled;
              await window.sensequality.setTelemetryConsent(next);
              setTelemetryEnabled(next);
            }}
          >
            <div className={`
              w-5 h-5 rounded-full bg-white shadow-md transition-transform
              ${telemetryEnabled ? 'translate-x-5' : 'translate-x-0'}
            `} />
          </div>
        </div>
      </div>

      {/* Run button */}
      <button
        onClick={handleRunAll}
        disabled={isRunning || enabledIds.length === 0}
        className={`
          w-full py-3 rounded-xl font-bold text-sm tracking-wide transition-all
          ${isRunning
            ? 'bg-sq-accent/50 text-white/70 cursor-wait'
            : enabledIds.length === 0
              ? 'bg-sq-border text-sq-text-dim cursor-not-allowed'
              : 'bg-sq-accent hover:bg-sq-accent-hover text-white shadow-lg shadow-sq-accent/25 cursor-pointer active:scale-[0.99]'
          }
        `}
      >
        {isRunning ? (
          <span className="flex items-center justify-center gap-2">
            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            OPTIMIZING...
          </span>
        ) : (
          `RUN ALL SELECTED (${enabledIds.length})`
        )}
      </button>

      {progressLog.length > 0 && (
        <LogViewer entries={progressLog} maxHeight="240px" />
      )}
    </div>
  );
}
