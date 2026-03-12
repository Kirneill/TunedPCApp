import { useState } from 'react';
import { useAppStore } from '../../store/appStore';
import { windowsOptimizations, gameOptimizations } from '../../data/optimizations';
import TweakCard from '../ui/TweakCard';
import FilterTabs from '../ui/FilterTabs';
import MonitorConfig from '../dashboard/MonitorConfig';
import LogViewer from '../ui/LogViewer';
import WindowsUpdateModeCard from '../windows/WindowsUpdateModeCard';
import RestorePointControls from '../windows/RestorePointControls';
import CodFpsGuideModal from '../ui/CodFpsGuideModal';

const NETWORK_IDS = new Set(['win-network', 'win-dns', 'win-net-adapter', 'win-tcp-stack', 'win-net-throttle']);
const DEBLOAT_IDS = new Set(['win-deep-debloat', 'win-undo-debloat']);
const allOptimizations = [...windowsOptimizations.filter(o => !NETWORK_IDS.has(o.id) && !DEBLOAT_IDS.has(o.id)), ...gameOptimizations];

const filterTabs = [
  { id: 'all', label: 'All Tweaks' },
  { id: 'windows', label: 'Windows' },
  { id: 'game', label: 'Games' },
  { id: 'monitor', label: 'Monitor' },
];

export default function AdvancedPage() {
  const {
    toggles,
    userConfig,
    isRunning,
    setIsRunning,
    clearLog,
    progressLog,
    setToggle,
    setAllToggles,
    telemetryEnabled,
    setTelemetryEnabled,
    closeToBackground,
    setCloseToBackground,
  } = useAppStore();
  const [showCodFpsGuide, setShowCodFpsGuide] = useState(false);
  const [activeFilter, setActiveFilter] = useState('all');

  const enabledIds = Object.entries(toggles)
    .filter(([id, enabled]) => id !== 'win-all' && enabled)
    .map(([id]) => id);

  const enabledCount = enabledIds.length;
  const totalCount = allOptimizations.length;

  const filteredItems = activeFilter === 'all'
    ? allOptimizations
    : activeFilter === 'monitor'
      ? []
      : allOptimizations.filter((item) => item.category === activeFilter);

  const handleRunAll = async () => {
    if (isRunning || enabledIds.length === 0) return;
    setIsRunning(true);
    clearLog();
    try {
      const runResult = await window.sensequality.runSelected(enabledIds, userConfig);
      const codSelected = enabledIds.includes('game-blackops7');
      const codSucceeded = runResult.results['game-blackops7'] === true;
      if (codSelected && codSucceeded) {
        setShowCodFpsGuide(true);
      }
    } catch (err) {
      console.error('Run failed:', err);
    } finally {
      setIsRunning(false);
    }
  };

  const showMonitorSection = activeFilter === 'all' || activeFilter === 'monitor';
  const showTweakCards = activeFilter !== 'monitor';

  return (
    <div className="p-5 space-y-4 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold text-sq-text">Advanced Tweaks</h1>
          <p className="text-[11px] text-sq-text-muted mt-0.5">
            Fine-tune your system with individual performance optimizations
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-[11px] text-sq-text-dim">
            {enabledCount}/{totalCount} tweaks enabled
          </span>
          <button
            onClick={() => setAllToggles(true)}
            disabled={isRunning}
            className="px-3 py-1.5 rounded-full text-[11px] font-semibold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors disabled:opacity-50 border border-sq-accent/60"
          >
            Apply All
          </button>
          <button
            onClick={() => setAllToggles(false)}
            disabled={isRunning}
            className="px-3 py-1.5 rounded-full text-[11px] font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors disabled:opacity-50"
          >
            Revert All
          </button>
        </div>
      </div>

      {/* Filter tabs */}
      <FilterTabs
        tabs={filterTabs}
        activeId={activeFilter}
        onChange={setActiveFilter}
        disabled={isRunning}
      />

      {/* Copilot warning */}
      {toggles['win-copilot'] && showTweakCards && (
        <div className="sq-glass rounded-xl px-4 py-3 flex items-start gap-3 border-sq-warning/30">
          <svg className="w-5 h-5 text-sq-warning mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z" />
          </svg>
          <div>
            <h3 className="text-xs font-semibold text-sq-warning">Copilot Disable Warning</h3>
            <p className="text-[10px] text-sq-text-muted mt-0.5 leading-relaxed">
              Disabling Copilot removes the appx package and applies policy restrictions.
              This <strong className="text-sq-text">may affect apps</strong> that rely on Copilot/Bing AI integration. A reboot is required.
            </p>
          </div>
        </div>
      )}

      {/* Tweak cards grid */}
      {showTweakCards && filteredItems.length > 0 && (
        <div className="grid grid-cols-3 gap-3">
          {filteredItems.map((item) => (
            <TweakCard
              key={item.id}
              title={item.label}
              description={item.description}
              enabled={toggles[item.id] ?? false}
              onToggle={(val) => setToggle(item.id, val)}
              disabled={isRunning}
              risk={item.risk}
              warning={item.risk === 'moderate' && item.requiresReboot ? 'Requires reboot' : undefined}
              icon={
                item.category === 'game' ? (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875S10.5 3.09 10.5 4.125c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.959.401v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z" />
                  </svg>
                ) : (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                  </svg>
                )
              }
            />
          ))}
        </div>
      )}

      {/* Windows Update + Restore Point */}
      {(activeFilter === 'all' || activeFilter === 'windows') && (
        <>
          <WindowsUpdateModeCard />
          <RestorePointControls />
        </>
      )}

      {/* Monitor Config */}
      {showMonitorSection && <MonitorConfig />}

      {/* Settings toggles */}
      {activeFilter === 'all' && (
        <div className="grid grid-cols-2 gap-3">
          <div className="sq-glass rounded-xl px-4 py-3.5">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xs font-semibold text-sq-text">Close Behavior</h3>
                <p className="text-[10px] text-sq-text-dim mt-0.5">
                  {closeToBackground ? 'Minimize to tray on close' : 'Exit app on close'}
                </p>
              </div>
              <div
                className={`
                  w-11 h-6 rounded-full flex items-center px-0.5 transition-colors shrink-0 cursor-pointer
                  ${closeToBackground ? 'bg-sq-accent' : 'bg-sq-border'}
                `}
                onClick={async () => {
                  const next = !closeToBackground;
                  try {
                    const saved = await window.sensequality.setCloseToBackground(next);
                    setCloseToBackground(saved);
                  } catch (err) {
                    console.error('Failed to update close behavior:', err);
                  }
                }}
              >
                <div className={`
                  w-5 h-5 rounded-full bg-white shadow-md transition-transform
                  ${closeToBackground ? 'translate-x-5' : 'translate-x-0'}
                `} />
              </div>
            </div>
          </div>

          <div className="sq-glass rounded-xl px-4 py-3.5">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xs font-semibold text-sq-text">Anonymous Usage Data</h3>
                <p className="text-[10px] text-sq-text-dim mt-0.5">
                  Share anonymous hardware & optimization stats
                </p>
              </div>
              <div
                className={`
                  w-11 h-6 rounded-full flex items-center px-0.5 transition-colors shrink-0 cursor-pointer
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
        </div>
      )}

      {/* Run button */}
      <button
        onClick={handleRunAll}
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
          `RUN ALL SELECTED (${enabledIds.length})`
        )}
      </button>

      {progressLog.length > 0 && (
        <LogViewer entries={progressLog} maxHeight="200px" />
      )}
      <CodFpsGuideModal open={showCodFpsGuide} onClose={() => setShowCodFpsGuide(false)} />
    </div>
  );
}
