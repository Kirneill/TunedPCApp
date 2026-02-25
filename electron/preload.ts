import { contextBridge, ipcRenderer } from 'electron';

export interface LogEntry {
  type: 'info' | 'success' | 'error' | 'warning' | 'start' | 'complete';
  message: string;
  timestamp: number;
  section?: string;
  runId?: string;
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
  getAppVersion: () => ipcRenderer.invoke('app:getVersion'),
};

contextBridge.exposeInMainWorld('sensequality', api);

export type SensequalityAPI = typeof api;
