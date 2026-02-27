import { runPowerShellCommand } from './powershell';
import { generateAnonymousId } from '../telemetry/telemetry';

export interface GpuAdapter {
  id: string;
  name: string;
  vendor: 'nvidia' | 'amd' | 'intel' | 'other';
  vramGB: number;
  isIntegrated: boolean;
}

export interface SystemInfo {
  gpu: string;
  gpuVram: string;
  gpuAdapters: GpuAdapter[];
  primaryGpuId: string;
  cpu: string;
  cpuCores: number;
  cpuThreads: number;
  ramGB: number;
  os: string;
  osBuild: string;
  isNvidia: boolean;
  isAmd: boolean;
  machineId: string;
}

const SYSTEM_INFO_SCRIPT = `
$gpus = Get-CimInstance Win32_VideoController | ForEach-Object {
  $name = [string]$_.Name
  if ([string]::IsNullOrWhiteSpace($name)) { return }
  if ($name -match '(?i)microsoft basic render|remote display|hyper-v') { return }

  $vendor = 'other'
  if ($name -match '(?i)nvidia|geforce|rtx|gtx') {
    $vendor = 'nvidia'
  } elseif ($name -match '(?i)amd|radeon|\\brx\\b') {
    $vendor = 'amd'
  } elseif ($name -match '(?i)intel') {
    $vendor = 'intel'
  }

  $isArc = $name -match '(?i)intel.*arc|\\barc\\b'
  $isIntegrated = $false
  if ($vendor -eq 'intel' -and -not $isArc) {
    $isIntegrated = $true
  } elseif ($name -match '(?i)uhd|iris|vega graphics|radeon graphics') {
    $isIntegrated = $true
  }

  $vram = 0
  if ($_.AdapterRAM -and $_.AdapterRAM -gt 0) {
    $vram = [math]::Round($_.AdapterRAM / 1GB, 1)
  }

  [PSCustomObject]@{
    id = if ([string]::IsNullOrWhiteSpace($_.PNPDeviceID)) { [string]$name } else { [string]$_.PNPDeviceID }
    name = $name.Trim()
    vendor = $vendor
    vramGB = $vram
    isIntegrated = $isIntegrated
  }
}

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors
$ram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
$os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1 Caption, BuildNumber

ConvertTo-Json @{
  gpus = @($gpus)
  cpuName = $cpu.Name
  cpuCores = $cpu.NumberOfCores
  cpuThreads = $cpu.NumberOfLogicalProcessors
  ramGB = [math]::Round($ram / 1GB)
  osCaption = $os.Caption
  osBuild = $os.BuildNumber
} -Compress
`;

function toVendor(value: unknown): GpuAdapter['vendor'] {
  if (value === 'nvidia' || value === 'amd' || value === 'intel' || value === 'other') {
    return value;
  }
  return 'other';
}

function normalizeGpuAdapters(raw: unknown): GpuAdapter[] {
  if (!raw) return [];
  const source = Array.isArray(raw) ? raw : [raw];

  return source
    .map((entry, index) => {
      const record = entry as Record<string, unknown>;
      const name = typeof record.name === 'string' ? record.name.trim() : '';
      if (!name) return null;

      const id = typeof record.id === 'string' && record.id.trim()
        ? record.id.trim()
        : `${name}-${index}`;
      const vendor = toVendor(record.vendor);
      const vramGB = typeof record.vramGB === 'number'
        ? record.vramGB
        : Number(record.vramGB || 0);
      const isIntegrated = Boolean(record.isIntegrated);

      return {
        id,
        name,
        vendor,
        vramGB: Number.isFinite(vramGB) ? Math.max(0, vramGB) : 0,
        isIntegrated,
      } satisfies GpuAdapter;
    })
    .filter((adapter): adapter is GpuAdapter => adapter !== null);
}

function scoreAdapter(adapter: GpuAdapter): number {
  let score = 0;
  if (adapter.vendor === 'nvidia') score += 300;
  else if (adapter.vendor === 'amd') score += 260;
  else if (adapter.vendor === 'intel') score += 120;

  if (!adapter.isIntegrated) score += 120;
  if (/intel.*arc|\barc\b/i.test(adapter.name)) score += 80;
  score += Math.min(64, Math.max(0, adapter.vramGB));
  return score;
}

function pickPrimaryGpu(adapters: GpuAdapter[]): GpuAdapter | null {
  if (adapters.length === 0) return null;
  const sorted = [...adapters].sort((a, b) => scoreAdapter(b) - scoreAdapter(a));
  return sorted[0] || null;
}

export async function getSystemInfo(): Promise<SystemInfo> {
  const result = await runPowerShellCommand(SYSTEM_INFO_SCRIPT);

  if (!result.success || result.output.length === 0) {
    return {
      gpu: 'Unknown', gpuVram: '0 GB', gpuAdapters: [], primaryGpuId: '', cpu: 'Unknown',
      cpuCores: 0, cpuThreads: 0, ramGB: 0,
      os: 'Unknown', osBuild: '', isNvidia: false, isAmd: false,
      machineId: generateAnonymousId(),
    };
  }

  try {
    const jsonStr = result.output.join('');
    const data = JSON.parse(jsonStr);
    const gpuAdapters = normalizeGpuAdapters(data.gpus);
    const primary = pickPrimaryGpu(gpuAdapters);
    const gpuName = primary?.name || 'Unknown';
    const gpuVram = primary?.vramGB ?? 0;

    return {
      gpu: gpuName,
      gpuVram: `${gpuVram} GB`,
      gpuAdapters,
      primaryGpuId: primary?.id || '',
      cpu: (data.cpuName || 'Unknown').trim(),
      cpuCores: data.cpuCores || 0,
      cpuThreads: data.cpuThreads || 0,
      ramGB: data.ramGB || 0,
      os: (data.osCaption || 'Unknown').trim(),
      osBuild: data.osBuild || '',
      isNvidia: primary?.vendor === 'nvidia',
      isAmd: primary?.vendor === 'amd',
      machineId: generateAnonymousId(),
    };
  } catch {
    return {
      gpu: 'Detection failed', gpuVram: '0 GB', gpuAdapters: [], primaryGpuId: '', cpu: 'Detection failed',
      cpuCores: 0, cpuThreads: 0, ramGB: 0,
      os: 'Unknown', osBuild: '', isNvidia: false, isAmd: false,
      machineId: generateAnonymousId(),
    };
  }
}
