import { useState } from 'react';
import { useAppStore } from '../../store/appStore';
import GameCard from './GameCard';
import LogViewer from '../ui/LogViewer';
import WindowsUpdateModeCard from '../windows/WindowsUpdateModeCard';
import RestorePointControls from '../windows/RestorePointControls';
import CodFpsGuideModal from '../ui/CodFpsGuideModal';

const games = [
  {
    id: 'blackops7',
    toggleId: 'game-blackops7',
    name: 'Call of Duty',
    subtitle: 'Black Ops 7 · Competitive Settings',
    gradient: 'bg-gradient-to-br from-orange-900 via-red-950 to-black',
    letter: 'COD',
  },
  {
    id: 'fortnite',
    toggleId: 'game-fortnite',
    name: 'Fortnite',
    subtitle: 'Performance Mode · Competitive',
    gradient: 'bg-gradient-to-br from-blue-900 via-violet-950 to-black',
    letter: 'FN',
  },
  {
    id: 'valorant',
    toggleId: 'game-valorant',
    name: 'Valorant',
    subtitle: 'Low Settings · Reflex On+Boost',
    gradient: 'bg-gradient-to-br from-red-900 via-rose-950 to-black',
    letter: 'VAL',
  },
  {
    id: 'cs2',
    toggleId: 'game-cs2',
    name: 'Counter-Strike 2',
    subtitle: 'Autoexec + Launch Options',
    gradient: 'bg-gradient-to-br from-amber-900 via-yellow-950 to-black',
    letter: 'CS2',
  },
  {
    id: 'apexlegends',
    toggleId: 'game-apexlegends',
    name: 'Apex Legends',
    subtitle: 'Max FPS Config + Read-Only Lock',
    gradient: 'bg-gradient-to-br from-red-900 via-orange-950 to-black',
    letter: 'APX',
  },
  {
    id: 'arcraiders',
    toggleId: 'game-arcraiders',
    name: 'Arc Raiders',
    subtitle: 'DLSS Quality · Shadows Medium',
    gradient: 'bg-gradient-to-br from-cyan-900 via-teal-950 to-black',
    letter: 'ARC',
  },
];

type InstallFilter = 'all' | 'installed' | 'not-installed';

export default function HomePage() {
  const {
    toggles, setToggle, userConfig, detectedGames, systemInfo,
    isRunning, setIsRunning, clearLog, progressLog, isLoading,
    setCurrentPage, setUserConfig,
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
    'win-bg-apps', 'win-mpo', 'win-visual-extras', 'win-copilot', 'win-standard',
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
    const installed = installedMap.get(game.id) ?? true;
    const enabled = toggles[game.toggleId] ?? false;
    return { ...game, installed, enabled };
  });
  const selectedGameCount = gamesWithState.filter((game) => game.enabled).length;

  const quickPicks = [...gamesWithState]
    .sort((a, b) => {
      if (a.enabled !== b.enabled) return a.enabled ? -1 : 1;
      if (a.installed !== b.installed) return a.installed ? -1 : 1;
      return a.name.localeCompare(b.name);
    })
    .slice(0, Math.min(4, gamesWithState.length));

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

  return (
    <div className="flex flex-col h-full">
      {/* System info bar */}
      <div className="flex items-center justify-between px-6 py-3 bg-black/20 border-b sq-subtle-divider text-[11px] text-sq-text-muted shrink-0 backdrop-blur-sm">
        <div className="flex items-center gap-5">
          {isLoading ? (
            <span>Detecting system...</span>
          ) : systemInfo ? (
            <>
              <div className="flex items-center gap-2 rounded-lg border border-sq-border/70 bg-sq-bg/70 px-2.5 py-1">
                <span className="text-sq-text font-semibold">GPU</span>
                {gpuAdapters.length > 1 ? (
                  <select
                    value={gpuSelectValue}
                    onChange={(e) => handleGpuSelection(e.target.value)}
                    disabled={isRunning}
                    className="sq-focus-ring bg-sq-bg border border-sq-border rounded px-2 py-0.5 text-[11px] text-sq-text focus:outline-none focus:border-sq-accent disabled:opacity-60"
                    title={effectiveGpu?.name || systemInfo.gpu}
                  >
                    <option value="auto">
                      Auto ({primaryGpu ? primaryGpu.name : systemInfo.gpu})
                    </option>
                    {gpuAdapters.map((adapter) => (
                      <option key={adapter.id} value={adapter.id}>
                        {adapter.name}
                      </option>
                    ))}
                  </select>
                ) : (
                  <span title={effectiveGpu?.name || systemInfo.gpu}>
                    {effectiveGpu?.name || systemInfo.gpu}
                  </span>
                )}
              </div>
              <span className="rounded-lg border border-sq-border/70 bg-sq-bg/70 px-2.5 py-1" title={systemInfo.cpu}>
                <span className="text-sq-text font-semibold">CPU</span> {systemInfo.cpu}
              </span>
              <span className="rounded-lg border border-sq-border/70 bg-sq-bg/70 px-2.5 py-1">
                <span className="text-sq-text font-semibold">RAM</span> {systemInfo.ramGB}GB
              </span>
            </>
          ) : (
            <span>System info unavailable</span>
          )}
        </div>
        <button
          onClick={() => setCurrentPage('advanced')}
          className="sq-focus-ring px-2.5 py-1 rounded-md border border-sq-border text-sq-text-muted hover:text-sq-accent hover:border-sq-accent/40 transition-colors text-[11px] font-semibold tracking-wide"
        >
          ADVANCED SETTINGS →
        </button>
      </div>

      {/* Main content — flex column fills remaining space */}
      <div className="flex-1 flex flex-col p-5 md:p-6 gap-3 min-h-0">
        {/* Windows optimization toggle */}
        <div
          className={`
            sq-panel-muted flex items-center justify-between p-4 rounded-xl border cursor-pointer transition-all shrink-0
            ${windowsEnabled
              ? 'bg-gradient-to-r from-sq-accent/16 via-sq-accent/8 to-transparent border-sq-accent/40'
              : 'border-sq-border hover:border-sq-text-dim'
            }
            ${isRunning ? 'pointer-events-none opacity-60' : ''}
          `}
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
          <div>
            <h3 className="text-sm font-bold text-sq-text">Windows Optimization</h3>
            <p className="text-[11px] text-sq-text-muted mt-0.5">
              Gaming latency tweaks plus a standard baseline in one pass
            </p>
          </div>
          <div className={`
            w-14 h-8 rounded-full flex items-center px-1 transition-colors shrink-0
            ${windowsEnabled ? 'bg-sq-accent' : 'bg-sq-border'}
          `}>
            <div className={`
              w-6 h-6 rounded-full bg-white shadow-md transition-transform
              ${windowsEnabled ? 'translate-x-6' : 'translate-x-0'}
            `} />
          </div>
        </div>

        <WindowsUpdateModeCard compact />
        <RestorePointControls compact />

        {/* Scalable game selector */}
        <div className="flex-1 min-h-0 rounded-xl border sq-subtle-divider sq-panel p-4 flex flex-col gap-3">
          <div className="flex items-start justify-between gap-4 shrink-0">
            <div>
              <h3 className="text-sm font-bold text-sq-text tracking-wide">Game Optimizations</h3>
              <p className="text-[11px] text-sq-text-muted mt-0.5">
                {selectedGameCount} selected
              </p>
            </div>
            <div className="text-[11px] text-sq-text-muted text-right">
              {visibleSelectedCount} selected in current view
            </div>
          </div>

          <div className="shrink-0 flex flex-col md:flex-row gap-2">
            <input
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              disabled={isRunning}
              placeholder="Search games..."
              className="sq-focus-ring flex-1 bg-sq-bg border border-sq-border rounded-lg px-3 py-2 text-xs text-sq-text placeholder:text-sq-text-dim focus:outline-none focus:border-sq-accent disabled:opacity-60"
            />
            <div className="flex items-center gap-1.5">
              {[
                { id: 'all', label: 'All' },
                { id: 'installed', label: 'Installed' },
                { id: 'not-installed', label: 'Not Installed' },
              ].map((filter) => (
                <button
                  key={filter.id}
                  onClick={() => setInstallFilter(filter.id as InstallFilter)}
                  disabled={isRunning}
                  className={`
                    px-2.5 py-2 rounded-lg text-[11px] font-semibold transition-colors
                    ${installFilter === filter.id
                      ? 'bg-sq-accent/20 text-sq-accent border border-sq-accent/50'
                      : 'bg-sq-bg text-sq-text-muted border border-sq-border hover:text-sq-text hover:border-sq-text-dim'
                    }
                    ${isRunning ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
                  `}
                >
                  {filter.label}
                </button>
              ))}
            </div>
          </div>

          <div className="shrink-0">
            <div className="text-[11px] font-semibold text-sq-text-muted tracking-[0.12em] mb-2">QUICK PICKS</div>
            <div className="grid grid-cols-2 xl:grid-cols-4 gap-3">
              {quickPicks.map((game) => (
                <GameCard
                  key={game.id}
                  {...game}
                  compact
                  installed={game.installed}
                />
              ))}
            </div>
          </div>

          <div className="shrink-0 flex items-center justify-between gap-4">
            <div className="text-[11px] font-semibold text-sq-text-muted tracking-[0.12em]">
              ALL GAMES ({filteredGames.length})
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setVisibleGames(true)}
                disabled={isRunning || filteredGames.length === 0}
                className="sq-focus-ring px-2.5 py-1.5 text-[11px] rounded-md border border-sq-border text-sq-text-muted hover:text-sq-text hover:border-sq-text-dim disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Select Visible
              </button>
              <button
                onClick={() => setVisibleGames(false)}
                disabled={isRunning || filteredGames.length === 0}
                className="sq-focus-ring px-2.5 py-1.5 text-[11px] rounded-md border border-sq-border text-sq-text-muted hover:text-sq-text hover:border-sq-text-dim disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Clear Visible
              </button>
            </div>
          </div>

          <div className="flex-1 min-h-0 rounded-lg border border-sq-border bg-sq-bg/60 overflow-hidden">
            <div className="h-full overflow-y-auto">
              {filteredGames.length === 0 ? (
                <div className="h-full flex items-center justify-center text-xs text-sq-text-dim">
                  No games match this filter.
                </div>
              ) : (
                <div className="divide-y divide-sq-border">
                  {filteredGames.map((game) => (
                    <button
                      key={game.id}
                      onClick={() => !isRunning && setToggle(game.toggleId, !game.enabled)}
                      disabled={isRunning}
                      className={`
                        sq-focus-ring w-full px-3 py-2.5 flex items-center justify-between gap-3 text-left transition-colors
                        ${game.enabled ? 'bg-gradient-to-r from-sq-accent/12 to-transparent' : 'hover:bg-sq-surface-hover/60'}
                        ${isRunning ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
                      `}
                    >
                      <div className="min-w-0">
                        <div className="text-sm font-semibold text-sq-text truncate">{game.name}</div>
                        <div className="text-[11px] text-sq-text-muted truncate">{game.subtitle}</div>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        <span className={`
                          px-2 py-0.5 rounded text-[10px] font-semibold tracking-wide border
                          ${game.installed
                            ? 'text-sq-success border-sq-success/40 bg-sq-success/10'
                            : 'text-sq-warning border-sq-warning/40 bg-sq-warning/10'
                          }
                        `}>
                          {game.installed ? 'FOUND' : 'NOT FOUND'}
                        </span>
                        <div className={`
                          w-12 h-7 rounded-full flex items-center px-1 transition-colors
                          ${game.enabled ? 'bg-sq-accent' : 'bg-sq-border'}
                        `}>
                          <div className={`
                            w-5 h-5 rounded-full bg-white shadow-md transition-transform
                            ${game.enabled ? 'translate-x-5' : 'translate-x-0'}
                          `} />
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Optimize button */}
        <div className="shrink-0 text-xs text-sq-text-muted">
          {selectedGameCount} game{selectedGameCount === 1 ? '' : 's'} selected
          {windowsEnabled ? ' + Windows optimization enabled' : ' + Windows optimization disabled'}
        </div>
        <button
          onClick={handleOptimize}
          disabled={isRunning || idsToRun.length === 0}
          className={`
            w-full py-4 rounded-xl font-bold text-base tracking-[0.08em] transition-all shrink-0 border
            ${isRunning
              ? 'bg-sq-accent/50 border-sq-accent/40 text-white/70 cursor-wait'
              : idsToRun.length === 0
                ? 'bg-sq-border border-sq-border text-sq-text-dim cursor-not-allowed'
                : 'bg-gradient-to-r from-sq-accent to-sq-accent-dim border-sq-accent/60 hover:brightness-110 text-white shadow-lg shadow-sq-accent/30 cursor-pointer active:scale-[0.99]'
            }
          `}
        >
          {isRunning ? (
            <span className="flex items-center justify-center gap-2">
              <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24" fill="none">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              OPTIMIZING...
            </span>
          ) : (
            `OPTIMIZE (${idsToRun.length} ${idsToRun.length === 1 ? 'setting' : 'settings'})`
          )}
        </button>

        {/* Pro CTA */}
        <button
          onClick={() => window.sensequality.openExternal('https://sensequality.com/products/pc-optimization')}
          className="w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.08em] bg-gradient-to-r from-sq-accent/24 via-sq-accent/12 to-sq-accent/24 border border-sq-accent/55 text-white hover:border-sq-accent hover:from-sq-accent/34 hover:to-sq-accent/34 transition-all shrink-0 cursor-pointer shadow-md shadow-sq-accent/12"
        >
          WANT MORE FPS? GET PRO OPTIMIZATION →
        </button>

        {/* Progress log */}
        {progressLog.length > 0 && (
          <div className="shrink-0">
            <LogViewer entries={progressLog} maxHeight="160px" />
          </div>
        )}
      </div>
      <CodFpsGuideModal open={showCodFpsGuide} onClose={() => setShowCodFpsGuide(false)} />
    </div>
  );
}
