import { runPowerShellCommand } from './powershell';
import { generateAnonymousId } from '../telemetry/telemetry';

export interface SystemInfo {
  gpu: string;
  gpuVram: string;
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
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name, @{N='VRAM';E={[math]::Round($_.AdapterRAM / 1GB, 1)}}
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors
$ram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
$os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1 Caption, BuildNumber
ConvertTo-Json @{
  gpuName = $gpu.Name
  gpuVram = $gpu.VRAM
  cpuName = $cpu.Name
  cpuCores = $cpu.NumberOfCores
  cpuThreads = $cpu.NumberOfLogicalProcessors
  ramGB = [math]::Round($ram / 1GB)
  osCaption = $os.Caption
  osBuild = $os.BuildNumber
} -Compress
`;

export async function getSystemInfo(): Promise<SystemInfo> {
  const result = await runPowerShellCommand(SYSTEM_INFO_SCRIPT);

  if (!result.success || result.output.length === 0) {
    return {
      gpu: 'Unknown', gpuVram: '0', cpu: 'Unknown',
      cpuCores: 0, cpuThreads: 0, ramGB: 0,
      os: 'Unknown', osBuild: '', isNvidia: false, isAmd: false,
      machineId: generateAnonymousId(),
    };
  }

  try {
    const jsonStr = result.output.join('');
    const data = JSON.parse(jsonStr);
    const gpuName = (data.gpuName || 'Unknown').trim();

    return {
      gpu: gpuName,
      gpuVram: `${data.gpuVram || 0} GB`,
      cpu: (data.cpuName || 'Unknown').trim(),
      cpuCores: data.cpuCores || 0,
      cpuThreads: data.cpuThreads || 0,
      ramGB: data.ramGB || 0,
      os: (data.osCaption || 'Unknown').trim(),
      osBuild: data.osBuild || '',
      isNvidia: /nvidia|geforce|rtx|gtx/i.test(gpuName),
      isAmd: /amd|radeon|rx\s/i.test(gpuName),
      machineId: generateAnonymousId(),
    };
  } catch {
    return {
      gpu: 'Detection failed', gpuVram: '0', cpu: 'Detection failed',
      cpuCores: 0, cpuThreads: 0, ramGB: 0,
      os: 'Unknown', osBuild: '', isNvidia: false, isAmd: false,
      machineId: generateAnonymousId(),
    };
  }
}
