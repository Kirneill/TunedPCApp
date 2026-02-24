import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import {
  nvidiaGlobalSettings,
  amdGlobalSettings,
  nvidiaPerGameOverrides,
  gsyncSetupSteps,
} from '../../data/nvidia-guide';

export default function NvidiaGuidePage() {
  const { systemInfo } = useAppStore();
  const isNvidia = systemInfo?.isNvidia ?? true;

  const globalSettings = isNvidia ? nvidiaGlobalSettings : amdGlobalSettings;
  const panelName = isNvidia ? 'NVIDIA Control Panel' : 'AMD Software: Adrenalin Edition';

  return (
    <div className="space-y-5 max-w-4xl">
      <div>
        <h1 className="text-xl font-bold text-sq-text">GPU Control Panel Guide</h1>
        <p className="text-xs text-sq-text-muted mt-1">
          These settings must be applied manually in {panelName}. Right-click desktop to open.
        </p>
        {systemInfo && (
          <div className="mt-2">
            <Badge variant="info">{systemInfo.gpu}</Badge>
          </div>
        )}
      </div>

      {/* Global Settings Table */}
      <Card title={`${isNvidia ? 'NVIDIA' : 'AMD'} Global Settings`}>
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

      {/* Per-Game Overrides (NVIDIA only) */}
      {isNvidia && (
        <Card title="Per-Game Overrides">
          <p className="text-[11px] text-sq-text-dim mb-3">
            Add these games in NVIDIA Control Panel under "Program Settings" and override:
          </p>
          <div className="overflow-x-auto">
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
        </Card>
      )}

      {/* G-SYNC / FreeSync Setup */}
      <Card title={isNvidia ? 'G-SYNC Setup' : 'FreeSync Setup'}>
        <ol className="space-y-2">
          {(isNvidia ? gsyncSetupSteps : [
            'Open AMD Software: Adrenalin Edition',
            'Go to Gaming tab → Display',
            'Enable "AMD FreeSync"',
            'In each game: Set V-Sync OFF',
            'Set in-game frame cap to monitor refresh rate minus 3',
          ]).map((step, i) => (
            <li key={i} className="flex items-start gap-2 text-xs">
              <span className="text-sq-accent font-mono shrink-0 mt-0.5">{i + 1}.</span>
              <span className="text-sq-text-muted">{step}</span>
            </li>
          ))}
        </ol>
      </Card>

      {/* Top 5 Impact */}
      <Card title="Top 5 Changes for Immediate Impact">
        <ol className="space-y-3">
          {[
            { title: 'Power Plan: Ultimate Performance', desc: 'Prevents CPU/GPU clock throttling mid-game' },
            { title: 'GPU: Power Management = Max Performance', desc: 'Stops GPU from downclocking during gameplay' },
            { title: 'Disable V-Sync in every game', desc: 'Removes 16-50ms of input latency' },
            { title: 'Enable NVIDIA Reflex / AMD Anti-Lag', desc: '15-30ms latency reduction per game' },
            { title: 'Disable Mouse Acceleration', desc: 'Critical for consistent aim muscle memory' },
          ].map((item, i) => (
            <li key={i} className="flex items-start gap-3">
              <span className="w-6 h-6 rounded-full bg-sq-accent/20 text-sq-accent text-xs font-bold flex items-center justify-center shrink-0">
                {i + 1}
              </span>
              <div>
                <div className="text-sm font-medium text-sq-text">{item.title}</div>
                <div className="text-[11px] text-sq-text-dim">{item.desc}</div>
              </div>
            </li>
          ))}
        </ol>
      </Card>
    </div>
  );
}
