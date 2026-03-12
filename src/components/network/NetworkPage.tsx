import { useState } from 'react';
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
    isReverting,
    setIsRunning,
    setIsReverting,
    clearLog,
    progressLog,
    setToggle,
  } = useAppStore();

  const [showRevertConfirm, setShowRevertConfirm] = useState(false);

  const enabledIds = networkOptimizations
    .filter((o) => toggles[o.id])
    .map((o) => o.id);

  const handleRun = async () => {
    if (isRunning || isReverting || enabledIds.length === 0) return;
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

  const handleRevert = async () => {
    if (isRunning || isReverting) return;
    setIsReverting(true);
    clearLog();
    setShowRevertConfirm(false);
    try {
      await window.sensequality.revertNetwork();
    } catch (err) {
      console.error('Revert failed:', err);
    } finally {
      setIsReverting(false);
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
            disabled={isRunning || isReverting}
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
        disabled={isRunning || isReverting || enabledIds.length === 0}
        className={`
          w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.08em] transition-all border uppercase
          ${isRunning || isReverting
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

      {/* Revert to defaults */}
      <div className="space-y-2">
        {!showRevertConfirm ? (
          <button
            onClick={() => setShowRevertConfirm(true)}
            disabled={isRunning || isReverting}
            className="w-full py-2.5 rounded-xl font-semibold text-xs tracking-[0.05em] transition-all border uppercase
              border-amber-500/40 text-amber-400 hover:bg-amber-500/10 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isReverting ? (
              <span className="flex items-center justify-center gap-2">
                <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                REVERTING...
              </span>
            ) : (
              'REVERT NETWORK TO DEFAULTS'
            )}
          </button>
        ) : (
          <div className="sq-glass rounded-xl p-4 border border-amber-500/30 space-y-3">
            <div className="flex items-start gap-3">
              <svg className="w-5 h-5 text-amber-400 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z" />
              </svg>
              <div>
                <h3 className="text-xs font-semibold text-amber-400">Revert Network Settings?</h3>
                <p className="text-[10px] text-sq-text-muted mt-1 leading-relaxed">
                  This will restore all network settings to Windows defaults: adapter properties, DNS (back to automatic),
                  registry tweaks, and TCP/IP stack settings. A reboot is required for some changes to take effect.
                </p>
              </div>
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleRevert}
                className="flex-1 py-2 rounded-lg font-semibold text-xs bg-amber-500/20 text-amber-400 border border-amber-500/40 hover:bg-amber-500/30 transition-colors"
              >
                Yes, Revert
              </button>
              <button
                onClick={() => setShowRevertConfirm(false)}
                className="flex-1 py-2 rounded-lg font-semibold text-xs text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>

      {progressLog.length > 0 && (
        <LogViewer entries={progressLog} maxHeight="200px" />
      )}
    </div>
  );
}
