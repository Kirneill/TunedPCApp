export interface LogEntry {
  type: 'info' | 'success' | 'error' | 'warning' | 'start' | 'complete';
  message: string;
  timestamp: number;
  section?: string;
  runId?: string;
}

export interface GpuAdapter {
  id: string;
  name: string;
  vendor: 'nvidia' | 'amd' | 'intel' | 'other';
  vramGB: number;
  isIntegrated: boolean;
  driverVersion: string;
}

export interface SystemInfo {
  gpu: string;
  gpuVram: string;
  gpuDriver: string;
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
  gpuMode: 'auto' | 'manual';
  selectedGpuId: string;
  cs2Stretched: boolean;
  restorePointEnabled: boolean;
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

// ─── Auth Types ──────────────────────────────────────────

export interface AuthUser {
  id: string;
  email: string;
}

export interface AuthResult {
  success: boolean;
  error?: string;
  user?: AuthUser;
}

export interface UserMachine {
  id: string;
  machine_id: string;
  machine_name: string;
  gpu: string;
  cpu: string;
  ram_gb: number;
  os_build: string;
  registered_at: string;
  last_seen_at: string;
  is_active: boolean;
  deactivated_at?: string;
  app_version?: string;
  gpu_driver?: string;
  gpu_vram_gb?: number;
}

export interface MachineRegistrationResult {
  success: boolean;
  reason?: 'max_devices' | 'registered' | 'new' | 'not_authenticated';
  machines?: UserMachine[];
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
      createRestorePoint: () => Promise<{ success: boolean; errors: string[] }>;
      onProgressLog: (callback: (entry: LogEntry) => void) => () => void;
      listBackups: () => Promise<BackupInfo[]>;
      createBackup: () => Promise<{ success: boolean; path: string }>;
      restoreBackup: (backupPath: string) => Promise<{ success: boolean }>;
      deleteBackup: (backupPath: string) => Promise<{ success: boolean }>;
      exportDiagnostics: () => Promise<{ success: boolean; path: string; error?: string }>;
      minimizeWindow: () => void;
      maximizeWindow: () => void;
      closeWindow: () => void;
      getCloseToBackground: () => Promise<boolean>;
      setCloseToBackground: (enabled: boolean) => Promise<boolean>;
      openExternal: (url: string) => Promise<void>;
      hasConsentDecision: () => Promise<boolean>;
      getTelemetryConsent: () => Promise<boolean>;
      setTelemetryConsent: (granted: boolean) => Promise<void>;
      // Auth
      signUp: (email: string, password: string) => Promise<AuthResult>;
      signIn: (email: string, password: string) => Promise<AuthResult>;
      signOut: () => Promise<void>;
      resetPassword: (email: string) => Promise<AuthResult>;
      getSession: () => Promise<{ user: AuthUser } | null>;
      getAuthUser: () => Promise<AuthUser | null>;
      isOffline: () => Promise<boolean>;
      getMachineId: () => Promise<string>;
      // Machine management
      registerMachine: (info: { machine_name: string; gpu: string; cpu: string; ram_gb: number; os_build: string }) => Promise<MachineRegistrationResult>;
      deactivateMachine: (machineId: string) => Promise<{ success: boolean; error?: string }>;
      // Waitlist
      joinWaitlist: (feature: string) => Promise<{ success: boolean; error?: string }>;
      hasJoinedWaitlist: (feature: string) => Promise<boolean>;
      // Updates
      checkForUpdate: () => Promise<UpdateInfo>;
      getUpdaterState: () => Promise<UpdaterState>;
      downloadUpdate: () => Promise<UpdaterActionResult>;
      installUpdate: () => Promise<UpdaterActionResult>;
      onUpdaterState: (callback: (state: UpdaterState) => void) => () => void;
      getAppVersion: () => Promise<string>;
      // System monitoring
      onSystemUsage: (callback: (usage: { cpu: number; gpu: number; ram: number }) => void) => () => void;
    };
  }
}

export interface UpdateInfo {
  hasUpdate: boolean;
  currentVersion: string;
  latestVersion: string;
  releaseUrl: string;
  releaseNotes: string;
}

export type UpdaterStatus =
  | 'idle'
  | 'checking'
  | 'available'
  | 'downloading'
  | 'downloaded'
  | 'up-to-date'
  | 'error';

export interface UpdaterState {
  status: UpdaterStatus;
  progress: number;
  message: string;
  latestVersion?: string;
  error?: string;
}

export interface UpdaterActionResult {
  started: boolean;
  reason?: string;
}
