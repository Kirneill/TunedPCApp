import { useMemo, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import LogViewer from '../ui/LogViewer';
import {
  nvidiaGlobalSettings,
  amdGlobalSettings,
  nvidiaPerGameOverrides,
  gsyncSetupSteps,
} from '../../data/nvidia-guide';

type GpuRunState = 'idle' | 'running' | 'success' | 'error';

export default function NvidiaGuidePage() {
  const {
    systemInfo,
    userConfig,
    isRunning,
    setIsRunning,
    clearLog,
    progressLog,
  } = useAppStore();

  const [runState, setRunState] = useState<GpuRunState>('idle');
  const [statusText, setStatusText] = useState('Not optimized yet.');

  const isNvidia = systemInfo?.isNvidia ?? true;
  const globalSettings = isNvidia ? nvidiaGlobalSettings : amdGlobalSettings;
  const panelName = isNvidia ? 'NVIDIA Control Panel' : 'AMD Software: Adrenalin Edition';

  const stateBadge = useMemo(() => {
    if (runState === 'running') return { label: 'Running...', className: 'text-sq-accent' };
    if (runState === 'success') return { label: 'Optimized', className: 'text-sq-success' };
    if (runState === 'error') return { label: 'Failed', className: 'text-sq-danger' };
    return { label: 'Not Optimized', className: 'text-sq-text-muted' };
  }, [runState]);

  const handleApply = async () => {
    if (isRunning) return;

    setRunState('running');
    setStatusText(isNvidia
      ? 'Applying NVIDIA competitive profile...'
      : 'Checking AMD GPU profile automation path...');

    setIsRunning(true);
    clearLog();

    try {
      const result = await window.sensequality.runOptimization('win-gpu-profile', userConfig);
      if (result.success) {
        setRunState('success');
        setStatusText(isNvidia
          ? 'GPU profile applied. Restart any running games to pick up driver changes.'
          : 'AMD path is not automated yet. No settings were changed.');
      } else {
        setRunState('error');
        setStatusText(result.errors.join(' | ') || 'GPU profile apply failed.');
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setRunState('error');
      setStatusText(`GPU profile apply failed: ${message}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <div className="space-y-5 max-w-4xl">
      <div>
        <h1 className="text-xl font-bold text-sq-text">GPU Driver Optimization</h1>
        <p className="text-xs text-sq-text-muted mt-1">
          One-click GPU profile plus {panelName} reference values.
        </p>
        {systemInfo && (
          <div className="mt-2 flex items-center gap-2">
            <Badge variant="info">{systemInfo.gpu}</Badge>
            <span className={`text-xs font-semibold ${stateBadge.className}`}>{stateBadge.label}</span>
          </div>
        )}
      </div>

      <Card title="One-Click Profile Apply">
        <div className="space-y-3">
          <p className="text-xs text-sq-text-muted">
            {isNvidia
              ? 'This runs the bundled NVIDIA profile import. Required values include Power Management Mode = Prefer Maximum Performance and Texture Filtering Quality = High Performance.'
              : 'AMD auto-profile path is not implemented yet. This action currently performs a capability check only.'}
          </p>

          <button
            onClick={handleApply}
            disabled={isRunning}
            className={`
              w-full py-3 rounded-xl font-bold text-sm tracking-wide transition-all
              ${isRunning
                ? 'bg-sq-accent/50 text-white/70 cursor-wait'
                : 'bg-sq-accent hover:bg-sq-accent-hover text-white shadow-lg shadow-sq-accent/25 cursor-pointer active:scale-[0.99]'
              }
            `}
          >
            {isRunning ? 'APPLYING GPU PROFILE...' : 'APPLY GPU PROFILE'}
          </button>

          <div className="text-xs text-sq-text-dim">{statusText}</div>
        </div>
      </Card>

      <Card title="Settings Preview (What Will Be Applied)">
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-sq-border text-left">
                <th className="pb-2 text-sq-text-muted font-medium">Setting</th>
                <th className="pb-2 text-sq-text-muted font-medium">Value</th>
                <th className="pb-2 text-sq-text-muted font-medium">Reason</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-sq-border/50">
              {globalSettings.map((s) => (
                <tr key={s.setting}>
                  <td className="py-2.5 pr-3">
                    <span className={`font-medium ${s.critical ? 'text-sq-accent-hover' : 'text-sq-text'}`}>
                      {s.setting}
                    </span>
                    {s.critical && <span className="ml-1 text-[9px] text-sq-danger font-bold">CRITICAL</span>}
                  </td>
                  <td className="py-2.5 pr-3 font-mono text-sq-success whitespace-nowrap">{s.value}</td>
                  <td className="py-2.5 text-sq-text-muted">{s.reason}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {isNvidia && (
        <details className="bg-sq-surface border border-sq-border rounded-xl px-4 py-3">
          <summary className="text-sm font-semibold text-sq-text cursor-pointer">Per-Game Overrides</summary>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="border-b border-sq-border text-left">
                  <th className="pb-2 text-sq-text-muted font-medium">Game</th>
                  <th className="pb-2 text-sq-text-muted font-medium">Setting</th>
                  <th className="pb-2 text-sq-text-muted font-medium">Value</th>
                  <th className="pb-2 text-sq-text-muted font-medium">Reason</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-sq-border/50">
                {nvidiaPerGameOverrides.map((o, i) => (
                  <tr key={i}>
                    <td className="py-2 pr-3 text-sq-text font-medium">{o.game}</td>
                    <td className="py-2 pr-3 text-sq-text-muted">{o.setting}</td>
                    <td className="py-2 pr-3 font-mono text-sq-success">{o.value}</td>
                    <td className="py-2 text-sq-text-muted">{o.reason}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </details>
      )}

      <details className="bg-sq-surface border border-sq-border rounded-xl px-4 py-3">
        <summary className="text-sm font-semibold text-sq-text cursor-pointer">G-SYNC / FreeSync Reference</summary>
        <ol className="space-y-2 mt-3">
          {(isNvidia ? gsyncSetupSteps : [
            'Open AMD Software: Adrenalin Edition',
            'Go to Gaming tab -> Display',
            'Enable AMD FreeSync',
            'In each game: Set V-Sync OFF',
            'Set in-game frame cap to monitor refresh rate minus 3',
          ]).map((step, i) => (
            <li key={i} className="flex items-start gap-2 text-xs">
              <span className="text-sq-accent font-mono shrink-0 mt-0.5">{i + 1}.</span>
              <span className="text-sq-text-muted">{step}</span>
            </li>
          ))}
        </ol>
      </details>

      <Card title="Run Log">
        <LogViewer entries={progressLog} maxHeight="260px" />
      </Card>
    </div>
  );
}
