import { useState } from 'react';
import { useAppStore } from '../../store/appStore';
import { GAMES } from '../../data/game-registry';
import SystemMetricCard from './SystemMetricCard';
import LogViewer from '../ui/LogViewer';
import WindowsUpdateModeCard from '../windows/WindowsUpdateModeCard';
import RestorePointControls from '../windows/RestorePointControls';
import CodFpsGuideModal from '../ui/CodFpsGuideModal';

// Derived from the unified game registry -- no manual sync needed
const games = GAMES.map(g => ({
  id: g.id,
  toggleId: `game-${g.id}`,
  name: g.cardName ?? g.name,
  subtitle: g.subtitle,
  gradient: g.gradient,
  letter: g.letter,
}));

type InstallFilter = 'all' | 'installed' | 'not-installed';

export default function HomePage() {
  const {
    toggles, setToggle, userConfig, detectedGames, systemInfo,
    isRunning, setIsRunning, clearLog, progressLog, isLoading,
    setCurrentPage, setUserConfig, systemUsage,
  } = useAppStore();
  const [showCodFpsGuide, setShowCodFpsGuide] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [installFilter, setInstallFilter] = useState<InstallFilter>('all');

  const windowsEnabled = toggles['win-all'] ?? true;
  const enabledGameIds = games
    .filter((g) => toggles[g.toggleId])
    .map((g) => g.toggleId);

  const allWindowsIds = [
    'win-power-plan', 'win-hags', 'win-game-mode', 'win-mmcss',
    'win-network', 'win-visual-fx', 'win-fullscreen', 'win-mouse', 'win-cpu-power',
    'win-bg-apps', 'win-mpo', 'win-visual-extras', 'win-copilot', 'win-standard', 'win-gpu-profile',
  ];
  const idsToRun = [
    ...(windowsEnabled ? allWindowsIds : []),
    ...enabledGameIds,
  ];

  const gpuAdapters = systemInfo?.gpuAdapters || [];
  const primaryGpu = gpuAdapters.find((adapter) => adapter.id === systemInfo?.primaryGpuId) || gpuAdapters[0];
  const manualGpu = gpuAdapters.find((adapter) => adapter.id === userConfig.selectedGpuId);
  const effectiveGpu = userConfig.gpuMode === 'manual'
    ? (manualGpu || primaryGpu)
    : primaryGpu;
  const gpuSelectValue = userConfig.gpuMode === 'manual' && manualGpu ? manualGpu.id : 'auto';

  const handleGpuSelection = (value: string) => {
    if (value === 'auto') {
      setUserConfig({
        gpuMode: 'auto',
        nvidiaGpu: primaryGpu?.vendor === 'nvidia',
      });
      return;
    }

    const selected = gpuAdapters.find((adapter) => adapter.id === value);
    setUserConfig({
      gpuMode: 'manual',
      selectedGpuId: selected?.id || '',
      nvidiaGpu: selected?.vendor === 'nvidia',
    });
  };

  const handleOptimize = async () => {
    if (isRunning || idsToRun.length === 0) return;
    setIsRunning(true);
    clearLog();
    try {
      const runResult = await window.sensequality.runSelected(idsToRun, userConfig);
      const codSelected = idsToRun.includes('game-blackops7');
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

  const installedMap = new Map(detectedGames.map((g) => [g.id, g.installed]));
  const gamesWithState = games.map((game) => {
    const installed = installedMap.get(game.id) ?? false;
    const enabled = toggles[game.toggleId] ?? false;
    return { ...game, installed, enabled };
  });
  const selectedGameCount = gamesWithState.filter((game) => game.enabled).length;

  const searchValue = searchQuery.trim().toLowerCase();
  const filteredGames = [...gamesWithState]
    .filter((game) => {
      if (installFilter === 'installed' && !game.installed) return false;
      if (installFilter === 'not-installed' && game.installed) return false;
      if (!searchValue) return true;
      return `${game.name} ${game.subtitle}`.toLowerCase().includes(searchValue);
    })
    .sort((a, b) => {
      if (a.installed !== b.installed) return a.installed ? -1 : 1;
      return a.name.localeCompare(b.name);
    });

  const visibleSelectedCount = filteredGames.filter((game) => game.enabled).length;

  const setVisibleGames = (value: boolean) => {
    if (isRunning) return;
    for (const game of filteredGames) {
      setToggle(game.toggleId, value);
    }
  };

  const cpuUsage = systemUsage?.cpu ?? 0;
  const gpuUsage = systemUsage?.gpu ?? 0;
  const ramUsage = systemUsage?.ram ?? 0;

  return (
    <div className="flex flex-col h-full">
      {/* System metrics row */}
      <div className="shrink-0 grid grid-cols-3 gap-3 px-5 pt-5 pb-2">
        <SystemMetricCard
          label="CPU Usage"
          value={cpuUsage}
          detail={systemInfo?.cpu || 'Detecting...'}
          icon={
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
            </svg>
          }
        />
        <SystemMetricCard
          label="GPU Usage"
          value={gpuUsage}
          detail={effectiveGpu?.name || systemInfo?.gpu || 'Detecting...'}
          icon={
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z" />
            </svg>
          }
        />
        <SystemMetricCard
          label="RAM Usage"
          value={ramUsage}
          detail={systemInfo ? `${systemInfo.ramGB}GB` : 'Detecting...'}
          icon={
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 6.878V6a2.25 2.25 0 012.25-2.25h7.5A2.25 2.25 0 0118 6v.878m-12 0c.235-.083.487-.128.75-.128h10.5c.263 0 .515.045.75.128m-12 0A2.25 2.25 0 004.5 9v.878m13.5-3A2.25 2.25 0 0119.5 9v.878m0 0a2.246 2.246 0 00-.75-.128H5.25c-.263 0-.515.045-.75.128m15 0A2.25 2.25 0 0121 12v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6c0-.98.626-1.813 1.5-2.122" />
            </svg>
          }
        />
      </div>

      {/* GPU selector (if multiple GPUs) */}
      {gpuAdapters.length > 1 && (
        <div className="shrink-0 px-5 pb-2">
          <div className="flex items-center gap-2 text-[11px] text-sq-text-muted">
            <span className="text-sq-text font-semibold">GPU</span>
            <select
              value={gpuSelectValue}
              onChange={(e) => handleGpuSelection(e.target.value)}
              disabled={isRunning}
              className="sq-focus-ring bg-sq-bg border border-sq-border rounded-lg px-2.5 py-1 text-[11px] text-sq-text focus:outline-none focus:border-sq-accent disabled:opacity-60"
              title={effectiveGpu?.name || systemInfo?.gpu}
            >
              <option value="auto">Auto ({primaryGpu ? primaryGpu.name : systemInfo?.gpu})</option>
              {gpuAdapters.map((adapter) => (
                <option key={adapter.id} value={adapter.id}>{adapter.name}</option>
              ))}
            </select>
          </div>
        </div>
      )}

      {/* Pro CTA banner */}
      <div className="shrink-0 px-5 pb-2">
        <button
          onClick={() => window.sensequality.openExternal('https://sensequality.com/products/pc-optimization')}
          className="w-full group relative overflow-hidden rounded-xl border border-sq-accent/30 hover:border-sq-accent/60 transition-all cursor-pointer"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-sq-accent/12 via-sq-accent/6 to-sq-accent/12 group-hover:from-sq-accent/18 group-hover:to-sq-accent/18 transition-all" />
          <div className="relative flex items-center justify-between px-4 py-2.5">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-lg bg-sq-accent/20 flex items-center justify-center">
                <svg className="w-4 h-4 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
                </svg>
              </div>
              <div className="text-left">
                <span className="text-[11px] font-bold text-white tracking-wide">Want even more FPS?</span>
                <span className="text-[10px] text-sq-text-muted ml-2">Get Pro optimization with advanced tweaks</span>
              </div>
            </div>
            <span className="text-[11px] font-bold text-sq-accent tracking-wide group-hover:text-sq-accent-hover transition-colors">
              UPGRADE →
            </span>
          </div>
        </button>
      </div>

      {/* Main 2-column layout */}
      <div className="flex-1 min-h-0 flex gap-3 px-5 pb-5">
        {/* Left: Game Optimizations */}
        <div className="flex-1 min-h-0 rounded-xl sq-panel relative overflow-hidden p-4 flex flex-col gap-3">
          <div className="relative z-10 flex items-start justify-between gap-4 shrink-0">
            <div>
              <h3 className="text-sm font-bold text-sq-text tracking-wide">Game Optimizations</h3>
              <p className="text-[11px] text-sq-text-muted mt-0.5">
                {selectedGameCount > 0
                  ? `${selectedGameCount} game${selectedGameCount === 1 ? '' : 's'} selected`
                  : 'Click on a game card below to select it'
                }
              </p>
            </div>
            <div className="flex items-center gap-1.5">
              {[
                { id: 'all', label: 'All' },
                { id: 'installed', label: 'Installed' },
                { id: 'not-installed', label: 'Not Found' },
              ].map((filter) => (
                <button
                  key={filter.id}
                  onClick={() => setInstallFilter(filter.id as InstallFilter)}
                  disabled={isRunning}
                  className={`
                    px-3.5 py-2 rounded-full text-xs font-bold transition-colors tracking-wide
                    ${installFilter === filter.id
                      ? 'bg-sq-accent/25 text-white border border-sq-accent/60'
                      : 'bg-sq-bg/60 text-sq-text-muted border border-sq-border hover:text-sq-text hover:border-sq-text-dim'
                    }
                    ${isRunning ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
                  `}
                >
                  {filter.label}
                </button>
              ))}
            </div>
          </div>

          <input
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            disabled={isRunning}
            placeholder="Search games..."
            className="sq-focus-ring shrink-0 relative z-10 bg-sq-bg/60 border border-sq-border rounded-lg px-3 py-2 text-xs text-sq-text placeholder:text-sq-text-dim focus:outline-none focus:border-sq-accent disabled:opacity-60"
          />

          {/* Game cards grid */}
          <div className="flex-1 min-h-0 overflow-y-auto relative z-10">
            <div className="grid grid-cols-3 gap-2">
              {filteredGames.map((game) => (
                <button
                  key={game.id}
                  onClick={() => !isRunning && setToggle(game.toggleId, !game.enabled)}
                  disabled={isRunning}
                  className={`
                    sq-card-hover relative rounded-xl overflow-hidden text-left transition-all group
                    ${game.enabled ? 'border-sq-accent' : ''}
                    ${isRunning ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
                  `}
                  data-active={game.enabled}
                >
                  <div className={`bg-gradient-to-br ${game.gradient} p-3 min-h-[80px] relative ${!game.enabled ? 'opacity-60 saturate-50' : ''}`}>
                    <span className="absolute top-0.5 right-1 text-3xl font-black text-white/[0.06] group-hover:text-white/[0.1] transition-colors select-none">{game.letter}</span>
                    {game.enabled ? (
                      <span className="absolute top-2 left-2 px-2.5 py-1.5 bg-sq-success backdrop-blur-sm rounded-md text-[11px] text-white font-bold tracking-[0.1em] uppercase shadow-md shadow-sq-success/40">Optimize</span>
                    ) : (
                      <span className="absolute top-2 left-2 px-2 py-1 bg-black/50 backdrop-blur-sm rounded text-[9px] text-white/60 font-medium tracking-wide">Click to select</span>
                    )}
                    <div className="absolute bottom-0 left-0 right-0 h-12 bg-gradient-to-t from-black/70 to-transparent" />
                  </div>
                  <div className={`px-3 py-2 -mt-px ${game.enabled ? 'bg-sq-surface/90' : 'bg-sq-surface/60'}`}>
                    <div className={`text-[11px] font-semibold leading-tight truncate ${game.enabled ? 'text-sq-text' : 'text-sq-text-muted'}`}>{game.name}</div>
                    <div className="flex items-center justify-between gap-1 mt-0.5">
                      <div className="text-[9px] text-sq-text-dim truncate">{game.subtitle}</div>
                      <span className={`
                        px-1.5 py-0.5 rounded text-[9px] font-bold tracking-wide shrink-0
                        ${game.installed
                          ? 'text-sq-success bg-sq-success/20'
                          : 'text-sq-warning bg-sq-warning/20'
                        }
                      `}>
                        {game.installed ? 'Installed' : 'N/A'}
                      </span>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Select/Clear buttons */}
          <div className="shrink-0 flex items-center justify-between gap-2 relative z-10">
            <div className="text-[10px] text-sq-text-dim">
              {visibleSelectedCount}/{filteredGames.length} selected
            </div>
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setVisibleGames(true)}
                disabled={isRunning || filteredGames.length === 0}
                className="sq-focus-ring px-2 py-1 text-[10px] rounded-md border border-sq-border text-sq-text-dim hover:text-sq-text-muted hover:border-sq-text-dim disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Select All
              </button>
              <button
                onClick={() => setVisibleGames(false)}
                disabled={isRunning || filteredGames.length === 0}
                className="sq-focus-ring px-2 py-1 text-[10px] rounded-md border border-sq-border text-sq-text-dim hover:text-sq-text-muted hover:border-sq-text-dim disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Clear All
              </button>
            </div>
          </div>
        </div>

        {/* Right: Windows & Controls */}
        <div className="w-[320px] shrink-0 flex flex-col gap-3 min-h-0">
          {/* Windows Optimization power card */}
          <div
            className={`
              sq-glass sq-card-hover rounded-xl p-4 shrink-0
              ${windowsEnabled ? 'border-sq-accent' : ''}
              ${isRunning ? 'pointer-events-none opacity-60' : 'cursor-pointer'}
            `}
            data-active={windowsEnabled}
            onClick={() => {
              if (!isRunning) {
                const next = !windowsEnabled;
                setToggle('win-all', next);
                for (const id of allWindowsIds) {
                  setToggle(id, next);
                }
              }
            }}
          >
            <div className="flex items-center gap-3 mb-3">
              <div className={`
                w-10 h-10 rounded-xl flex items-center justify-center transition-colors
                ${windowsEnabled ? 'bg-sq-accent/20 text-sq-accent' : 'bg-sq-border/60 text-sq-text-dim'}
              `}>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
              </div>
              <div>
                <h3 className="text-sm font-bold text-sq-text">Windows Optimization</h3>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className={`
                    px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                    ${windowsEnabled
                      ? 'bg-sq-success/25 text-sq-success border border-sq-success/30'
                      : 'bg-sq-text-dim/20 text-sq-text-dim border border-sq-text-dim/20'
                    }
                  `}>
                    {windowsEnabled ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                  <span className="text-[9px] text-sq-text-dim">Enabled by default</span>
                </div>
              </div>
            </div>
            <p className="text-[11px] text-sq-text-muted leading-relaxed mb-3">
              Gaming latency tweaks plus a standard baseline in one pass
            </p>
            <div className="flex items-center justify-between">
              <button
                onClick={(e) => { e.stopPropagation(); setCurrentPage('advanced'); }}
                className="text-[10px] text-sq-accent hover:text-sq-accent-hover font-semibold transition-colors"
              >
                Configure →
              </button>
              <div className={`
                w-12 h-7 rounded-full flex items-center px-1 transition-colors
                ${windowsEnabled ? 'bg-sq-accent' : 'bg-sq-border'}
              `}>
                <div className={`
                  w-5 h-5 rounded-full bg-white shadow-md transition-transform
                  ${windowsEnabled ? 'translate-x-5' : 'translate-x-0'}
                `} />
              </div>
            </div>
          </div>

          {/* Windows Update + Restore Point */}
          <WindowsUpdateModeCard compact />
          <RestorePointControls compact />

          {/* Spacer */}
          <div className="flex-1" />

          {/* Summary + Optimize */}
          <div className="shrink-0 text-[10px] text-sq-text-muted text-center leading-relaxed">
            {idsToRun.length === 0 ? (
              <span className="text-sq-warning">Select games or enable Windows tweaks to optimize</span>
            ) : (
              <>
                <span className="text-sq-text font-medium">{idsToRun.length} setting{idsToRun.length === 1 ? '' : 's'}</span>
                {' ready · '}
                {selectedGameCount > 0 && `${selectedGameCount} game${selectedGameCount === 1 ? '' : 's'}`}
                {selectedGameCount > 0 && windowsEnabled && ' + '}
                {windowsEnabled && 'Windows'}
              </>
            )}
          </div>
          <button
            onClick={handleOptimize}
            disabled={isRunning || idsToRun.length === 0}
            className={`
              w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.1em] transition-all shrink-0 border uppercase
              ${isRunning
                ? 'bg-sq-accent/50 border-sq-accent/40 text-white/70 cursor-wait'
                : idsToRun.length === 0
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
              `OPTIMIZE (${idsToRun.length})`
            )}
          </button>

        </div>
      </div>

      {/* Progress log */}
      {progressLog.length > 0 && (
        <div className="shrink-0 px-5 pb-4">
          <LogViewer entries={progressLog} maxHeight="140px" />
        </div>
      )}
      <CodFpsGuideModal open={showCodFpsGuide} onClose={() => setShowCodFpsGuide(false)} />
    </div>
  );
}
