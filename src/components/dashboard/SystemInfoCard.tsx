import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';

export default function SystemInfoCard() {
  const { systemInfo, isLoading } = useAppStore();

  if (isLoading || !systemInfo) {
    return (
      <Card title="System Information">
        <div className="animate-pulse space-y-2">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-4 bg-sq-border rounded w-3/4" />
          ))}
        </div>
      </Card>
    );
  }

  const primaryGpu = systemInfo.gpuAdapters.find((adapter) => adapter.id === systemInfo.primaryGpuId);
  const gpuSubtitleParts = [systemInfo.gpuVram];
  if (primaryGpu) {
    gpuSubtitleParts.push(primaryGpu.isIntegrated ? 'Integrated' : 'Discrete');
  }
  if (systemInfo.gpuAdapters.length > 1) {
    gpuSubtitleParts.push(`${systemInfo.gpuAdapters.length} GPUs detected`);
  }

  const items = [
    { label: 'GPU', value: systemInfo.gpu, sub: gpuSubtitleParts.join(' • ') },
    { label: 'CPU', value: systemInfo.cpu, sub: `${systemInfo.cpuCores}C / ${systemInfo.cpuThreads}T` },
    { label: 'RAM', value: `${systemInfo.ramGB} GB`, sub: '' },
    { label: 'OS', value: systemInfo.os, sub: `Build ${systemInfo.osBuild}` },
  ];

  return (
    <Card title="System Information">
      <div className="space-y-3">
        {items.map((item) => (
          <div key={item.label} className="flex items-start justify-between">
            <span className="text-xs text-sq-text-muted uppercase tracking-wider w-10 shrink-0 pt-0.5">{item.label}</span>
            <div className="text-right">
              <div className="text-sm text-sq-text">{item.value}</div>
              {item.sub && <div className="text-[11px] text-sq-text-dim">{item.sub}</div>}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}
