import { contextBridge, ipcRenderer } from 'electron';

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
}

export interface UpdaterState {
  status: 'idle' | 'checking' | 'available' | 'downloading' | 'downloaded' | 'up-to-date' | 'error';
  progress: number;
  message: string;
  latestVersion?: string;
  error?: string;
}

export interface UpdaterActionResult {
  started: boolean;
  reason?: string;
}

const api = {
  // System
  getSystemInfo: (): Promise<SystemInfo> => ipcRenderer.invoke('system:getInfo'),
  getInstalledGames: (): Promise<DetectedGame[]> => ipcRenderer.invoke('system:getGames'),
  isAdmin: (): Promise<boolean> => ipcRenderer.invoke('system:isAdmin'),

  // Optimizations
  runOptimization: (id: string, config: UserConfig): Promise<{ success: boolean; errors: string[] }> =>
    ipcRenderer.invoke('optimize:run', id, config),
  runSelected: (ids: string[], config: UserConfig): Promise<{ success: boolean; results: Record<string, boolean> }> =>
    ipcRenderer.invoke('optimize:runSelected', ids, config),

  // Progress/Log streaming
  onProgressLog: (callback: (entry: LogEntry) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, entry: LogEntry) => callback(entry);
    ipcRenderer.on('optimize:log', handler);
    return () => { ipcRenderer.removeListener('optimize:log', handler); };
  },

  // Backups
  listBackups: (): Promise<BackupInfo[]> => ipcRenderer.invoke('backup:list'),
  createBackup: (): Promise<{ success: boolean; path: string }> => ipcRenderer.invoke('backup:create'),
  restoreBackup: (backupPath: string): Promise<{ success: boolean }> => ipcRenderer.invoke('backup:restore', backupPath),
  deleteBackup: (backupPath: string): Promise<{ success: boolean }> => ipcRenderer.invoke('backup:delete', backupPath),
  exportDiagnostics: (): Promise<{ success: boolean; path: string; error?: string }> => ipcRenderer.invoke('diagnostics:export'),

  // Window controls
  minimizeWindow: () => ipcRenderer.send('window:minimize'),
  maximizeWindow: () => ipcRenderer.send('window:maximize'),
  closeWindow: () => ipcRenderer.send('window:close'),
  getCloseToBackground: (): Promise<boolean> => ipcRenderer.invoke('app:getCloseToBackground'),
  setCloseToBackground: (enabled: boolean): Promise<boolean> => ipcRenderer.invoke('app:setCloseToBackground', enabled),

  // External links
  openExternal: (url: string) => ipcRenderer.invoke('shell:openExternal', url),

  // Telemetry
  hasConsentDecision: (): Promise<boolean> => ipcRenderer.invoke('telemetry:hasConsentDecision'),
  getTelemetryConsent: (): Promise<boolean> => ipcRenderer.invoke('telemetry:getConsent'),
  setTelemetryConsent: (granted: boolean): Promise<void> => ipcRenderer.invoke('telemetry:setConsent', granted),

  // Auth
  signUp: (email: string, password: string) => ipcRenderer.invoke('auth:signUp', email, password),
  signIn: (email: string, password: string) => ipcRenderer.invoke('auth:signIn', email, password),
  signOut: () => ipcRenderer.invoke('auth:signOut'),
  resetPassword: (email: string) => ipcRenderer.invoke('auth:resetPassword', email),
  getSession: () => ipcRenderer.invoke('auth:getSession'),
  getAuthUser: () => ipcRenderer.invoke('auth:getUser'),
  isOffline: () => ipcRenderer.invoke('auth:isOffline'),
  getMachineId: () => ipcRenderer.invoke('auth:getMachineId'),

  // Machine management
  registerMachine: (info: { machine_name: string; gpu: string; cpu: string; ram_gb: number; os_build: string }) =>
    ipcRenderer.invoke('auth:registerMachine', info),
  deactivateMachine: (machineId: string) => ipcRenderer.invoke('auth:deactivateMachine', machineId),

  // Waitlist
  joinWaitlist: (feature: string) => ipcRenderer.invoke('waitlist:join', feature),
  hasJoinedWaitlist: (feature: string) => ipcRenderer.invoke('waitlist:hasJoined', feature),

  // Updates
  checkForUpdate: () => ipcRenderer.invoke('updater:check'),
  getUpdaterState: (): Promise<UpdaterState> => ipcRenderer.invoke('updater:getState'),
  downloadUpdate: (): Promise<UpdaterActionResult> => ipcRenderer.invoke('updater:download'),
  installUpdate: (): Promise<UpdaterActionResult> => ipcRenderer.invoke('updater:install'),
  onUpdaterState: (callback: (state: UpdaterState) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, state: UpdaterState) => callback(state);
    ipcRenderer.on('updater:state', handler);
    return () => { ipcRenderer.removeListener('updater:state', handler); };
  },
  getAppVersion: () => ipcRenderer.invoke('app:getVersion'),
};

contextBridge.exposeInMainWorld('sensequality', api);

export type SensequalityAPI = typeof api;
