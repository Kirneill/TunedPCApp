export interface LogEntry {
  type: 'info' | 'success' | 'error' | 'warning' | 'start' | 'complete';
  message: string;
  timestamp: number;
  section?: string;
}

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
}

export interface DetectedGame {
  id: string;
  name: string;
  installed: boolean;
  path?: string;
}

export interface BackupInfo {
  name: string;
  path: string;
  date: string;
  files: string[];
}

export interface UserConfig {
  monitorWidth: number;
  monitorHeight: number;
  monitorRefresh: number;
  nvidiaGpu: boolean;
  cs2Stretched: boolean;
}

export interface OptimizationItem {
  id: string;
  label: string;
  description: string;
  category: 'windows' | 'game';
  risk: 'safe' | 'moderate';
  requiresReboot: boolean;
  gameId?: string;
}

export interface BiosGuideStep {
  id: string;
  title: string;
  description: string;
  details: string;
  warning?: string;
  impact: string;
}

export interface GpuGuideSetting {
  setting: string;
  value: string;
  reason: string;
  critical?: boolean;
}

// Extend window for the preload API
declare global {
  interface Window {
    sensequality: {
      getSystemInfo: () => Promise<SystemInfo>;
      getInstalledGames: () => Promise<DetectedGame[]>;
      isAdmin: () => Promise<boolean>;
      runOptimization: (id: string, config: UserConfig) => Promise<{ success: boolean; errors: string[] }>;
      runSelected: (ids: string[], config: UserConfig) => Promise<{ success: boolean; results: Record<string, boolean> }>;
      onProgressLog: (callback: (entry: LogEntry) => void) => () => void;
      listBackups: () => Promise<BackupInfo[]>;
      createBackup: () => Promise<{ success: boolean; path: string }>;
      restoreBackup: (backupPath: string) => Promise<{ success: boolean }>;
      deleteBackup: (backupPath: string) => Promise<{ success: boolean }>;
      minimizeWindow: () => void;
      maximizeWindow: () => void;
      closeWindow: () => void;
      openExternal: (url: string) => Promise<void>;
      hasConsentDecision: () => Promise<boolean>;
      getTelemetryConsent: () => Promise<boolean>;
      setTelemetryConsent: (granted: boolean) => Promise<void>;
    };
  }
}
