import { useAppStore } from '../../store/appStore';
import { windowsOptimizations } from '../../data/optimizations';
import TweakCard from '../ui/TweakCard';
import LogViewer from '../ui/LogViewer';

const NETWORK_IDS = new Set(['win-network', 'win-dns', 'win-net-adapter', 'win-tcp-stack', 'win-net-throttle']);
const networkOptimizations = windowsOptimizations.filter(o => NETWORK_IDS.has(o.id));

export default function NetworkPage() {
  const {
    toggles,
    userConfig,
    isRunning,
    setIsRunning,
    clearLog,
    progressLog,
    setToggle,
  } = useAppStore();

  const enabledIds = networkOptimizations
    .filter((o) => toggles[o.id])
    .map((o) => o.id);

  const handleRun = async () => {
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
    <div className="p-5 space-y-4 overflow-y-auto h-full">
      {/* Header */}
      <div>
        <h1 className="text-lg font-bold text-sq-text">Network Optimization</h1>
        <p className="text-[11px] text-sq-text-muted mt-0.5">
          Reduce network latency and improve connection stability for online gaming
        </p>
      </div>

      {/* Info banner */}
      <div className="sq-glass rounded-xl px-4 py-3 flex items-start gap-3">
        <svg className="w-5 h-5 text-sq-accent mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M8.288 15.038a5.25 5.25 0 017.424 0M5.106 11.856c3.807-3.808 9.98-3.808 13.788 0M1.924 8.674c5.565-5.565 14.587-5.565 20.152 0M12.53 18.22l-.53.53-.53-.53a.75.75 0 011.06 0z" />
        </svg>
        <div>
          <h3 className="text-xs font-semibold text-sq-text">How it works</h3>
          <p className="text-[10px] text-sq-text-muted mt-0.5 leading-relaxed">
            These tweaks target the Windows TCP/IP stack and network adapter driver settings to minimize round-trip latency.
            Toggle each card individually to control exactly which optimizations are applied.
            <strong className="text-sq-text-muted"> Nagle's Algorithm</strong> batches small TCP packets, adding up to 200 ms of delay per send.
            <strong className="text-sq-text-muted"> DNS, Adapter, TCP Stack, and Throttling</strong> tweaks can be enabled or disabled independently.
          </p>
        </div>
      </div>

      {/* Tweak cards */}
      <div className="grid grid-cols-2 gap-3">
        {networkOptimizations.map((item) => (
          <TweakCard
            key={item.id}
            title={item.label}
            description={item.description}
            enabled={toggles[item.id] ?? false}
            onToggle={(val) => setToggle(item.id, val)}
            disabled={isRunning}
            risk={item.risk}
            warning={item.requiresReboot ? 'Requires reboot' : undefined}
            icon={
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
              </svg>
            }
          />
        ))}
      </div>

      {/* Run button */}
      <button
        onClick={handleRun}
        disabled={isRunning || enabledIds.length === 0}
        className={`
          w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.08em] transition-all border uppercase
          ${isRunning
            ? 'bg-sq-accent/50 border-sq-accent/40 text-white/70 cursor-wait'
            : enabledIds.length === 0
              ? 'bg-sq-border border-sq-border text-sq-text-dim cursor-not-allowed'
              : 'bg-gradient-to-r from-sq-accent to-sq-accent-dim border-sq-accent/60 hover:brightness-110 text-white sq-pulse-glow cursor-pointer active:scale-[0.98]'
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
          `RUN SELECTED (${enabledIds.length})`
        )}
      </button>

      {progressLog.length > 0 && (
        <LogViewer entries={progressLog} maxHeight="200px" />
      )}
    </div>
  );
}
