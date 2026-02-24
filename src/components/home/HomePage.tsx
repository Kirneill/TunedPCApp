import { useAppStore } from '../../store/appStore';
import GameCard from './GameCard';
import LogViewer from '../ui/LogViewer';

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
    id: 'arcraiders',
    toggleId: 'game-arcraiders',
    name: 'Arc Raiders',
    subtitle: 'DLSS Quality · Shadows Medium',
    gradient: 'bg-gradient-to-br from-cyan-900 via-teal-950 to-black',
    letter: 'ARC',
  },
];

export default function HomePage() {
  const {
    toggles, setToggle, userConfig, detectedGames, systemInfo,
    isRunning, setIsRunning, clearLog, progressLog, isLoading,
    setCurrentPage,
  } = useAppStore();

  const windowsEnabled = toggles['win-all'] ?? true;
  const enabledGameIds = games
    .filter((g) => toggles[g.toggleId])
    .map((g) => g.toggleId);

  const allWindowsIds = [
    'win-power-plan', 'win-hags', 'win-game-mode', 'win-mmcss',
    'win-network', 'win-visual-fx', 'win-fullscreen', 'win-mouse', 'win-cpu-power',
  ];
  const idsToRun = [
    ...(windowsEnabled ? allWindowsIds : []),
    ...enabledGameIds,
  ];

  const handleOptimize = async () => {
    if (isRunning || idsToRun.length === 0) return;
    setIsRunning(true);
    clearLog();
    try {
      await window.sensequality.runSelected(idsToRun, userConfig);
    } catch (err) {
      console.error('Run failed:', err);
    } finally {
      setIsRunning(false);
    }
  };

  const installedMap = new Map(detectedGames.map((g) => [g.id, g.installed]));

  return (
    <div className="flex flex-col h-full">
      {/* System info bar */}
      <div className="flex items-center justify-between px-6 py-2.5 bg-sq-surface/50 border-b border-sq-border text-[11px] text-sq-text-muted shrink-0">
        <div className="flex items-center gap-6">
          {isLoading ? (
            <span>Detecting system...</span>
          ) : systemInfo ? (
            <>
              <span title={systemInfo.gpu}>
                <span className="text-sq-text font-medium">GPU</span> {systemInfo.gpu}
              </span>
              <span title={systemInfo.cpu}>
                <span className="text-sq-text font-medium">CPU</span> {systemInfo.cpu}
              </span>
              <span>
                <span className="text-sq-text font-medium">RAM</span> {systemInfo.ramGB}GB
              </span>
            </>
          ) : (
            <span>System info unavailable</span>
          )}
        </div>
        <button
          onClick={() => setCurrentPage('advanced')}
          className="text-sq-text-muted hover:text-sq-accent transition-colors text-[11px] font-medium tracking-wide"
        >
          ADVANCED SETTINGS →
        </button>
      </div>

      {/* Main content — flex column fills remaining space */}
      <div className="flex-1 flex flex-col p-5 gap-4 min-h-0">
        {/* Windows optimization toggle */}
        <div
          className={`
            flex items-center justify-between p-4 rounded-xl border cursor-pointer transition-all shrink-0
            ${windowsEnabled
              ? 'bg-sq-accent/10 border-sq-accent/40'
              : 'bg-sq-surface border-sq-border hover:border-sq-text-dim'
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
              Power plan, GPU scheduling, network latency, mouse accel, visual effects &mdash; 9 tweaks
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

        {/* Game cards grid — grows to fill available space */}
        <div className="flex-1 grid grid-cols-5 gap-4 min-h-0">
          {games.map((game) => (
            <GameCard
              key={game.id}
              {...game}
              installed={installedMap.get(game.id) ?? true}
            />
          ))}
        </div>

        {/* Optimize button */}
        <button
          onClick={handleOptimize}
          disabled={isRunning || idsToRun.length === 0}
          className={`
            w-full py-4 rounded-xl font-bold text-base tracking-wide transition-all shrink-0
            ${isRunning
              ? 'bg-sq-accent/50 text-white/70 cursor-wait'
              : idsToRun.length === 0
                ? 'bg-sq-border text-sq-text-dim cursor-not-allowed'
                : 'bg-sq-accent hover:bg-sq-accent-hover text-white shadow-lg shadow-sq-accent/25 cursor-pointer active:scale-[0.99]'
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

        {/* Progress log */}
        {progressLog.length > 0 && (
          <div className="shrink-0">
            <LogViewer entries={progressLog} maxHeight="160px" />
          </div>
        )}
      </div>
    </div>
  );
}
