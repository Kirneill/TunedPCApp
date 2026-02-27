import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';

export default function MonitorConfig() {
  const { userConfig, setUserConfig, systemInfo, isRunning } = useAppStore();
  const gpuAdapters = systemInfo?.gpuAdapters || [];
  const primaryGpu = gpuAdapters.find((adapter) => adapter.id === systemInfo?.primaryGpuId) || gpuAdapters[0];
  const manualGpu = gpuAdapters.find((adapter) => adapter.id === userConfig.selectedGpuId);
  const effectiveGpu = userConfig.gpuMode === 'manual'
    ? (manualGpu || primaryGpu)
    : primaryGpu;

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
          <label className="block text-[11px] text-sq-text-muted mb-1">GPU Mode</label>
          <select
            value={userConfig.gpuMode}
            onChange={(e) => {
              const mode = e.target.value === 'manual' ? 'manual' : 'auto';
              if (mode === 'manual') {
                const nextManual = manualGpu || primaryGpu;
                setUserConfig({
                  gpuMode: mode,
                  selectedGpuId: nextManual?.id || '',
                  nvidiaGpu: nextManual?.vendor === 'nvidia',
                });
                return;
              }

              setUserConfig({
                gpuMode: mode,
                nvidiaGpu: primaryGpu?.vendor === 'nvidia',
              });
            }}
            disabled={isRunning}
            className={inputClass}
          >
            <option value="auto">Auto (Prefer Discrete)</option>
            <option value="manual" disabled={gpuAdapters.length === 0}>Manual Select</option>
          </select>
        </div>
      </div>

      {userConfig.gpuMode === 'manual' && (
        <div className="mt-3">
          <label className="block text-[11px] text-sq-text-muted mb-1">Manual GPU Selection</label>
          <select
            value={manualGpu?.id || ''}
            onChange={(e) => {
              const selected = gpuAdapters.find((adapter) => adapter.id === e.target.value);
              setUserConfig({
                selectedGpuId: e.target.value,
                nvidiaGpu: selected?.vendor === 'nvidia',
              });
            }}
            disabled={isRunning || gpuAdapters.length === 0}
            className={inputClass}
          >
            {gpuAdapters.length === 0 && <option value="">No GPU adapters detected</option>}
            {gpuAdapters.map((adapter) => (
              <option key={adapter.id} value={adapter.id}>
                {adapter.name}{adapter.isIntegrated ? ' (Integrated)' : ' (Discrete)'}
              </option>
            ))}
          </select>
        </div>
      )}

      <p className="mt-3 text-[11px] text-sq-text-dim leading-relaxed">
        Active GPU target: {effectiveGpu ? effectiveGpu.name : 'Unknown'}.
        {' '}
        {effectiveGpu
          ? `Detected as ${effectiveGpu.isIntegrated ? 'integrated' : 'discrete'} ${effectiveGpu.vendor.toUpperCase()}.`
          : 'Detection fallback is in use.'}
      </p>
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
