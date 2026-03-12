import { useMemo, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import LogViewer from '../ui/LogViewer';

type RunState = 'idle' | 'running' | 'success' | 'error';

interface OptimizationCard {
  id: string;
  title: string;
  description: string;
  getRecommendation: (ramGB: number, isHDD: boolean) => { action: string; badge: 'safe' | 'moderate' | 'warning' | 'info'; reason: string };
  requiresReboot: boolean;
}

const optimizations: OptimizationCard[] = [
  {
    id: 'standby',
    title: 'Free Cached RAM',
    description: 'Windows holds onto old data in RAM "just in case." This clears it out so your game gets all the memory it needs.',
    getRecommendation: (ramGB, _isHDD) => {
      if (ramGB >= 64) return { action: 'Skip', badge: 'info', reason: 'You have so much RAM that this cache actually helps. No need to clear it.' };
      if (ramGB >= 32) return { action: 'Clear if needed', badge: 'safe', reason: 'Only kicks in if your free RAM drops below 2 GB. Otherwise leaves it alone.' };
      if (ramGB >= 16) return { action: 'Clear', badge: 'safe', reason: 'Stops the stutter you get when Chrome + Discord eat your RAM while gaming.' };
      return { action: 'Clear', badge: 'safe', reason: 'Huge impact on 8 GB. This is the #1 fix for random stutters mid-game.' };
    },
    requiresReboot: false,
  },
  {
    id: 'compression',
    title: 'RAM Compression',
    description: 'Windows uses your CPU to squeeze more into RAM. Helpful if you\'re low on memory, but eats CPU on bigger systems.',
    getRecommendation: (ramGB, isHDD) => {
      if (ramGB < 16) return { action: 'Keep On', badge: 'warning', reason: 'Your system needs this. Turning it off with 8 GB would cause freezes and crashes.' };
      if (isHDD) return { action: 'Keep On', badge: 'warning', reason: 'Your main drive is an HDD. Better to use a little CPU than wait on slow disk reads.' };
      if (ramGB >= 64) return { action: 'Turn Off', badge: 'safe', reason: 'You have so much RAM that compression is unnecessary. Frees up a tiny bit of CPU.' };
      return { action: 'Keep On', badge: 'safe', reason: 'Compression uses ~2-4% CPU (unnoticeable in-game) but provides a safety net against out-of-memory crashes.' };
    },
    requiresReboot: true,
  },
  {
    id: 'pagefile',
    title: 'Virtual Memory',
    description: 'Locks your pagefile to a fixed size so Windows doesn\'t resize it while you\'re in a match. Resizing causes lag spikes.',
    getRecommendation: (ramGB, isHDD) => {
      const size = '8 GB';
      const extra = isHDD ? ' Pro tip: move your pagefile to an SSD if you can.' : '';
      if (ramGB <= 8) return { action: `Lock to ${size}`, badge: 'moderate', reason: `Matches your RAM size. Games like Warzone and Tarkov need this to avoid crashes.${extra}` };
      if (ramGB <= 16) return { action: `Lock to ${size}`, badge: 'safe', reason: `Prevents mid-game lag spikes from Windows resizing your virtual memory.${extra}` };
      return { action: `Lock to ${size}`, badge: 'safe', reason: `Safe floor for heavy games. Modern titles like BO7 can use 15-20 GB commit charge.${extra}` };
    },
    requiresReboot: true,
  },
  {
    id: 'workingset',
    title: 'Background Cleanup',
    description: 'Frees RAM from apps running in the background. Only used on low-memory systems when things get critical.',
    getRecommendation: (ramGB, _isHDD) => {
      if (ramGB >= 16) return { action: 'Skip', badge: 'info', reason: 'You have enough RAM. The cached RAM fix above handles this better without side effects.' };
      return { action: 'Light Cleanup', badge: 'moderate', reason: 'Only touches background apps using 200 MB+. Never touches your game, Discord, or anticheat.' };
    },
    requiresReboot: false,
  },
];

// Determine RAM tier label for the hero badge
function getRamTier(ramGB: number): { label: string; badge: 'safe' | 'moderate' | 'warning' } {
  if (ramGB >= 32) return { label: `${ramGB}GB -- Optimal`, badge: 'safe' };
  if (ramGB >= 16) return { label: `${ramGB}GB -- Good`, badge: 'safe' };
  return { label: `${ramGB}GB -- Constrained`, badge: 'warning' };
}

export default function MemoryPage() {
  const {
    systemInfo,
    userConfig,
    isRunning,
    setIsRunning,
    clearLog,
    progressLog,
    systemUsage,
  } = useAppStore();

  const [runState, setRunState] = useState<RunState>('idle');
  const [statusText, setStatusText] = useState('Run the optimizer to apply hardware-specific memory tuning.');

  const ramGB = systemInfo?.ramGB ?? 16;
  // We don't have storage type in SystemInfo yet, so assume SSD (safe default)
  const isHDD = false;
  const isHighRam = ramGB > 16;

  const ramTier = useMemo(() => getRamTier(ramGB), [ramGB]);
  const ramUsagePercent = systemUsage?.ram ?? 0;

  const stateBadge = useMemo(() => {
    if (isHighRam) return { label: 'Not Needed', className: 'text-sq-success' };
    if (runState === 'running') return { label: 'Optimizing...', className: 'text-sq-accent' };
    if (runState === 'success') return { label: 'Optimized', className: 'text-sq-success' };
    if (runState === 'error') return { label: 'Failed', className: 'text-sq-danger' };
    return { label: 'Not Optimized', className: 'text-sq-text-muted' };
  }, [runState, isHighRam]);

  const handleOptimize = async () => {
    if (isRunning) return;

    setRunState('running');
    setStatusText('Detecting hardware and applying optimizations...');
    setIsRunning(true);
    clearLog();

    try {
      const result = await window.sensequality.runOptimization('win-memory', userConfig);
      if (result.success) {
        setRunState('success');
        setStatusText('Memory optimization complete. Check the log below for details.');
      } else {
        setRunState('error');
        setStatusText(result.errors.join(' | ') || 'Memory optimization failed.');
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setRunState('error');
      setStatusText(`Memory optimization failed: ${message}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <div className="space-y-5 max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-sq-text">Memory Optimization</h1>
        <p className="text-xs text-sq-text-muted mt-1">
          Frees up RAM, stops background bloat, and prevents lag spikes. Tuned to your hardware -- won't break anything.
        </p>
        <div className="mt-2 flex items-center gap-2">
          <span className={`text-xs font-semibold ${stateBadge.className}`}>{stateBadge.label}</span>
        </div>
      </div>

      {/* System Profile Card */}
      <Card title="Your System Profile">
        <div className="grid grid-cols-3 gap-4">
          {/* RAM */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 003 3h7.5a3 3 0 003-3m-13.5 0V5.25A2.25 2.25 0 017.5 3h9a2.25 2.25 0 012.25 2.25v6m-13.5 3v5.25a2.25 2.25 0 002.25 2.25h9a2.25 2.25 0 002.25-2.25v-5.25" />
              </svg>
              <span className="text-xs font-semibold text-sq-text uppercase tracking-wider">RAM</span>
            </div>
            <div className="text-2xl font-bold text-sq-text">{ramGB} GB</div>
            <Badge variant={ramTier.badge}>{ramTier.label}</Badge>
            {systemUsage && (
              <div className="space-y-1">
                <div className="flex justify-between text-[10px] text-sq-text-dim">
                  <span>Usage</span>
                  <span>{ramUsagePercent}%</span>
                </div>
                <div className="h-1.5 rounded-full bg-sq-bg overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      ramUsagePercent > 85 ? 'bg-sq-danger' : ramUsagePercent > 60 ? 'bg-sq-warning' : 'bg-sq-success'
                    }`}
                    style={{ width: `${ramUsagePercent}%` }}
                  />
                </div>
              </div>
            )}
          </div>

          {/* CPU */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
              </svg>
              <span className="text-xs font-semibold text-sq-text uppercase tracking-wider">CPU</span>
            </div>
            <div className="text-sm font-bold text-sq-text truncate" title={systemInfo?.cpu}>
              {systemInfo?.cpu || 'Detecting...'}
            </div>
            <div className="text-xs text-sq-text-dim">
              {systemInfo ? `${systemInfo.cpuCores} cores / ${systemInfo.cpuThreads} threads` : '...'}
            </div>
          </div>

          {/* Storage */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 17.25v-.228a4.5 4.5 0 00-.12-1.03l-2.268-9.64a3.375 3.375 0 00-3.285-2.602H7.923a3.375 3.375 0 00-3.285 2.602l-2.268 9.64a4.5 4.5 0 00-.12 1.03v.228m19.5 0a3 3 0 01-3 3H5.25a3 3 0 01-3-3m19.5 0a3 3 0 00-3-3H5.25a3 3 0 00-3 3m16.5 0h.008v.008h-.008v-.008zm-3 0h.008v.008h-.008v-.008z" />
              </svg>
              <span className="text-xs font-semibold text-sq-text uppercase tracking-wider">Storage</span>
            </div>
            <div className="text-sm font-bold text-sq-text">
              Auto-detected
            </div>
            <div className="text-xs text-sq-text-dim">
              Checked at runtime by the script
            </div>
          </div>
        </div>
      </Card>

      {/* HIGH RAM BLOCK: Show "not needed" message for 16GB+ systems */}
      {isHighRam ? (
        <div className="flex items-start gap-4 px-5 py-5 rounded-xl bg-sq-success/8 border border-sq-success/20">
          <svg className="w-8 h-8 text-sq-success shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div>
            <p className="text-sm font-bold text-sq-success">Your system doesn't need this</p>
            <p className="text-xs text-sq-text-muted mt-1.5 leading-relaxed">
              With <span className="text-sq-text font-semibold">{ramGB} GB of RAM</span>, your system already has more than enough memory for any game.
              This optimizer is designed for systems with 16 GB or less, where Windows memory management can cause stutters and lag spikes.
            </p>
            <p className="text-xs text-sq-text-muted mt-2 leading-relaxed">
              Running memory optimizations on high-RAM systems can actually cause problems -- like reducing your virtual memory below what modern games need.
              Your PC is already in great shape for gaming.
            </p>
          </div>
        </div>
      ) : (
        <>
          {/* Optimization Cards */}
          <Card title="What We'll Do">
            <div className="space-y-4">
              {optimizations.map((opt) => {
                const rec = opt.getRecommendation(ramGB, isHDD);
                return (
                  <div
                    key={opt.id}
                    className="flex items-start gap-4 p-3 rounded-xl bg-sq-bg/50 border border-sq-border/40"
                  >
                    {/* Action badge -- fixed width so titles align */}
                    <div className="shrink-0 pt-0.5 w-[130px]">
                      <Badge variant={rec.badge}>{rec.action}</Badge>
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-sq-text">{opt.title}</span>
                        {opt.requiresReboot && (
                          <span className="text-[9px] text-sq-warning font-bold uppercase tracking-wider">Reboot</span>
                        )}
                      </div>
                      <p className="text-xs text-sq-text-dim mt-0.5">{opt.description}</p>
                      <p className="text-xs text-sq-text-muted mt-1.5">
                        <span className="font-medium text-sq-accent-hover">With {ramGB} GB RAM:</span>{' '}
                        {rec.reason}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </Card>

          {/* Safety notice */}
          <div className="flex items-start gap-3 px-4 py-3 rounded-xl bg-sq-success/8 border border-sq-success/20">
            <svg className="w-5 h-5 text-sq-success shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
            <div>
              <p className="text-xs font-semibold text-sq-success">System Restore Point Required</p>
              <p className="text-xs text-sq-text-muted mt-0.5">
                A restore point is created automatically before any changes are made. If it fails, the optimization will <span className="text-sq-text font-medium">stop and won't touch anything</span>. Make sure System Protection is turned on for your C: drive (search "Create a restore point" in Windows).
              </p>
            </div>
          </div>

          {/* Optimize Button */}
          <Card title="Run It">
            <div className="space-y-3">
              <p className="text-xs text-sq-text-muted">
                Scans your PC and only applies what's safe for your setup. Nothing is changed without checking your hardware first.
                {ramGB < 16 && (
                  <span className="text-sq-warning font-medium"> RAM compression stays ON because your system needs it at {ramGB} GB.</span>
                )}
              </p>

              <button
                onClick={handleOptimize}
                disabled={isRunning}
                className={`
                  w-full py-3 rounded-xl font-bold text-sm tracking-wide transition-all
                  ${isRunning
                    ? 'bg-sq-accent/50 text-white/70 cursor-wait'
                    : 'bg-sq-accent hover:bg-sq-accent-hover text-white shadow-lg shadow-sq-accent/25 cursor-pointer active:scale-[0.99]'
                  }
                `}
              >
                {isRunning ? 'OPTIMIZING MEMORY...' : 'OPTIMIZE MEMORY'}
              </button>

              <div className="text-xs text-sq-text-dim">{statusText}</div>
            </div>
          </Card>

          {/* Run Log */}
          <Card title="Run Log">
            <LogViewer entries={progressLog} maxHeight="260px" />
          </Card>
        </>
      )}
    </div>
  );
}
