import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';

export default function MonitorConfig() {
  const { userConfig, setUserConfig, isRunning } = useAppStore();

  const inputClass = `
    w-full bg-sq-bg border border-sq-border rounded-lg px-3 py-1.5 text-sm text-sq-text
    focus:outline-none focus:border-sq-accent transition-colors
    disabled:opacity-50
  `;

  return (
    <Card title="Monitor & Hardware">
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="block text-[11px] text-sq-text-muted mb-1">Width</label>
          <input
            type="number"
            value={userConfig.monitorWidth}
            onChange={(e) => setUserConfig({ monitorWidth: parseInt(e.target.value) || 1920 })}
            disabled={isRunning}
            className={inputClass}
          />
        </div>
        <div>
          <label className="block text-[11px] text-sq-text-muted mb-1">Height</label>
          <input
            type="number"
            value={userConfig.monitorHeight}
            onChange={(e) => setUserConfig({ monitorHeight: parseInt(e.target.value) || 1080 })}
            disabled={isRunning}
            className={inputClass}
          />
        </div>
        <div>
          <label className="block text-[11px] text-sq-text-muted mb-1">Refresh Rate (Hz)</label>
          <input
            type="number"
            value={userConfig.monitorRefresh}
            onChange={(e) => setUserConfig({ monitorRefresh: parseInt(e.target.value) || 144 })}
            disabled={isRunning}
            className={inputClass}
          />
        </div>
        <div>
          <label className="block text-[11px] text-sq-text-muted mb-1">GPU Brand</label>
          <select
            value={userConfig.nvidiaGpu ? 'nvidia' : 'amd'}
            onChange={(e) => setUserConfig({ nvidiaGpu: e.target.value === 'nvidia' })}
            disabled={isRunning}
            className={inputClass}
          >
            <option value="nvidia">NVIDIA</option>
            <option value="amd">AMD</option>
          </select>
        </div>
      </div>
      <div className="mt-3 flex items-center gap-2">
        <input
          type="checkbox"
          id="cs2stretched"
          checked={userConfig.cs2Stretched}
          onChange={(e) => setUserConfig({ cs2Stretched: e.target.checked })}
          disabled={isRunning}
          className="rounded border-sq-border bg-sq-bg text-sq-accent focus:ring-sq-accent"
        />
        <label htmlFor="cs2stretched" className="text-xs text-sq-text-muted">
          CS2: Use 4:3 stretched (1280x960)
        </label>
      </div>
    </Card>
  );
}
