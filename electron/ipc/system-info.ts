import { runPowerShellCommand } from './powershell';
import { generateAnonymousId } from '../telemetry/telemetry';

export type { GpuAdapter, SystemInfo } from '../../src/types/index';
import type { GpuAdapter, SystemInfo } from '../../src/types/index';

const SYSTEM_INFO_SCRIPT = `
# Build a lookup of 64-bit VRAM values from the display adapter registry.
# Win32_VideoController.AdapterRAM is uint32, so it wraps modulo 2^32 (4 GB).
# Common VRAM sizes (4, 8, 12, 16, 24 GB) wrap to exactly 0; other sizes
# above 4 GB report incorrect but nonzero values (e.g. 6 GB reports as 2 GB).
$vramLookup = @{}
try {
  $classPath = 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}'
  Get-ChildItem $classPath -ErrorAction SilentlyContinue | ForEach-Object {
    $r = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
    if ($r -and $r.MatchingDeviceId) {
      $qw = $r.'HardwareInformation.qwMemorySize'
      if ($qw -and [int64]$qw -gt 0) {
        $vramLookup[$r.MatchingDeviceId.ToLower()] = [math]::Round([int64]$qw / 1GB, 1)
      }
    }
  }
} catch {
  Write-Warning "[VRAM-LOOKUP] Registry VRAM detection failed: $_"
}

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

  # Fix uint32 overflow: look up 64-bit VRAM from registry when WMI reports 0
  # or suspiciously low values (<2 GB) for a discrete GPU
  $pnpId = $_.PNPDeviceID
  if ($pnpId -and ($vram -le 0 -or ($vendor -ne 'intel' -and -not $isIntegrated -and $vram -lt 2))) {
    $pnpLower = $pnpId.ToLower()
    foreach ($matchId in $vramLookup.Keys) {
      if ($pnpLower -like "*$matchId*") {
        $vram = $vramLookup[$matchId]
        break
      }
    }
  }

  [PSCustomObject]@{
    id = if ([string]::IsNullOrWhiteSpace($pnpId)) { [string]$name } else { [string]$pnpId }
    name = $name.Trim()
    vendor = $vendor
    vramGB = $vram
    isIntegrated = $isIntegrated
    driverVersion = if ($_.DriverVersion) { [string]$_.DriverVersion } else { '' }
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
      const driverVersion = typeof record.driverVersion === 'string' ? record.driverVersion.trim() : '';

      return {
        id,
        name,
        vendor,
        vramGB: Number.isFinite(vramGB) ? Math.max(0, vramGB) : 0,
        isIntegrated,
        driverVersion,
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
    console.warn(
      `[system-info] PowerShell system info script failed. success=${result.success}, outputLines=${result.output.length}`,
    );
    return {
      gpu: 'Unknown', gpuVram: '0 GB', gpuDriver: '', gpuAdapters: [], primaryGpuId: '', cpu: 'Unknown',
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

    // Log all detected adapters and their scores for debugging GPU selection issues
    if (gpuAdapters.length > 0) {
      const adapterLog = gpuAdapters.map((a) => {
        const score = scoreAdapter(a);
        const tag = a === primary ? ' [PRIMARY]' : '';
        return `  ${a.name} (${a.vendor}, ${a.vramGB}GB, ${a.isIntegrated ? 'integrated' : 'discrete'}, score=${score})${tag}`;
      });
      console.log(`[system-info] Detected ${gpuAdapters.length} GPU(s):\n${adapterLog.join('\n')}`);
    }

    return {
      gpu: gpuName,
      gpuVram: `${gpuVram} GB`,
      gpuDriver: primary?.driverVersion || '',
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
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[system-info] Failed to parse system info: ${errorText}`);
    return {
      gpu: 'Detection failed', gpuVram: '0 GB', gpuDriver: '', gpuAdapters: [], primaryGpuId: '', cpu: 'Detection failed',
      cpuCores: 0, cpuThreads: 0, ramGB: 0,
      os: 'Unknown', osBuild: '', isNvidia: false, isAmd: false,
      machineId: generateAnonymousId(),
    };
  }
}
