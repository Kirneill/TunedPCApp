import { contextBridge, ipcRenderer } from 'electron';
import type { LogEntry, GpuAdapter, SystemInfo, DetectedGame, BackupInfo, UserConfig, UpdaterState, UpdaterActionResult } from '../src/types/index';

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
  createRestorePoint: (): Promise<{ success: boolean; errors: string[] }> =>
    ipcRenderer.invoke('safety:createRestorePoint'),

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
  getLaunchOnStartup: (): Promise<boolean> => ipcRenderer.invoke('app:getLaunchOnStartup'),
  setLaunchOnStartup: (enabled: boolean): Promise<boolean> => ipcRenderer.invoke('app:setLaunchOnStartup', enabled),

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
  registerMachine: (info: { machine_name: string; gpu: string; cpu: string; ram_gb: number; os_build: string; gpu_driver?: string; gpu_vram_gb?: number }) =>
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

  // System monitoring
  onSystemUsage: (callback: (usage: { cpu: number; gpu: number; ram: number }) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, usage: { cpu: number; gpu: number; ram: number }) => callback(usage);
    ipcRenderer.on('system:usage', handler);
    return () => { ipcRenderer.removeListener('system:usage', handler); };
  },
};

contextBridge.exposeInMainWorld('sensequality', api);

export type SensequalityAPI = typeof api;
