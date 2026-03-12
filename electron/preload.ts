import { contextBridge, ipcRenderer } from 'electron';
import type { LogEntry, GpuAdapter, SystemInfo, DetectedGame, RestorePointInfo, UserConfig, UpdaterState, UpdaterActionResult } from '../src/types/index';

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

  // Restore Points
  listRestorePoints: (): Promise<{ points: RestorePointInfo[]; error?: string }> => ipcRenderer.invoke('restore-point:list'),
  launchSystemRestore: (): Promise<{ success: boolean; error?: string }> => ipcRenderer.invoke('restore-point:launch'),

  // Diagnostics
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
  signIn: (email: string, password: string, rememberMe?: boolean) => ipcRenderer.invoke('auth:signIn', email, password, rememberMe),
  signOut: () => ipcRenderer.invoke('auth:signOut'),
  resetPassword: (email: string) => ipcRenderer.invoke('auth:resetPassword', email),
  getSession: () => ipcRenderer.invoke('auth:getSession'),
  getAuthUser: () => ipcRenderer.invoke('auth:getUser'),
  isOffline: () => ipcRenderer.invoke('auth:isOffline'),
  getMachineId: () => ipcRenderer.invoke('auth:getMachineId'),
  getRememberMe: () => ipcRenderer.invoke('auth:getRememberMe'),
  setRememberMe: (value: boolean) => ipcRenderer.invoke('auth:setRememberMe', value),
  setSessionFromTokens: (tokens: { access_token: string; refresh_token: string }) =>
    ipcRenderer.invoke('auth:setSessionFromTokens', tokens),
  updatePassword: (newPassword: string) => ipcRenderer.invoke('auth:updatePassword', newPassword),
  onPasswordResetTokens: (callback: (tokens: { access_token: string; refresh_token: string }) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, tokens: { access_token: string; refresh_token: string; }) => callback(tokens);
    ipcRenderer.on('auth:passwordResetTokens', handler);
    return () => { ipcRenderer.removeListener('auth:passwordResetTokens', handler); };
  },

  // Machine management
  registerMachine: (info: { machine_name: string; gpu: string; cpu: string; ram_gb: number; os_build: string; gpu_driver?: string; gpu_vram_gb?: number }) =>
    ipcRenderer.invoke('auth:registerMachine', info),
  deactivateMachine: (machineId: string) => ipcRenderer.invoke('auth:deactivateMachine', machineId),

  // Waitlist
  joinWaitlist: (feature: string) => ipcRenderer.invoke('waitlist:join', feature),
  hasJoinedWaitlist: (feature: string) => ipcRenderer.invoke('waitlist:hasJoined', feature),

  // Billing
  billingCheckAccess: () => ipcRenderer.invoke('billing:checkAccess'),
  billingCheckout: (successUrl?: string) => ipcRenderer.invoke('billing:checkout', successUrl),
  billingCancelSubscription: (immediately?: boolean) => ipcRenderer.invoke('billing:cancelSubscription', immediately),
  billingGetSubscription: () => ipcRenderer.invoke('billing:getSubscription'),
  billingOpenPortal: () => ipcRenderer.invoke('billing:openBillingPortal'),
  billingRefreshAccess: () => ipcRenderer.invoke('billing:refreshAccess'),

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

  // BIOS
  scanBiosState: () => ipcRenderer.invoke('bios:scan'),
  getBiosProvisionStatus: () => ipcRenderer.invoke('bios:provisionStatus'),
  exportNvram: () => ipcRenderer.invoke('bios:export'),
  backupBios: () => ipcRenderer.invoke('bios:backup'),
  listBiosBackups: () => ipcRenderer.invoke('bios:listBackups'),
  previewBiosProfile: (profileId: string) => ipcRenderer.invoke('bios:previewProfile', profileId),
  applyBiosProfile: (profileId: string) => ipcRenderer.invoke('bios:applyProfile', profileId),
  restoreBiosBackup: (filename: string) => ipcRenderer.invoke('bios:restore', filename),
  provisionScewin: () => ipcRenderer.invoke('bios:provisionScewin'),
  cancelScewinProvision: () => ipcRenderer.invoke('bios:cancelProvision'),
  onScewinProvisionProgress: (callback: (progress: { step: string; progress: number; message: string; error?: string }) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, progress: { step: string; progress: number; message: string; error?: string }) => callback(progress);
    ipcRenderer.on('bios:provisionProgress', handler);
    return () => { ipcRenderer.removeListener('bios:provisionProgress', handler); };
  },

  // Debloat
  exportPlaybook: (): Promise<{ success: boolean; path?: string; error?: string }> =>
    ipcRenderer.invoke('debloat:exportPlaybook'),
  checkDebloatManifest: (): Promise<{ exists: boolean; timestamp?: string; servicesChanged?: number; appxRemoved?: number; tasksDisabled?: number; capabilitiesRemoved?: number }> =>
    ipcRenderer.invoke('debloat:checkManifest'),

  // System monitoring
  onSystemUsage: (callback: (usage: { cpu: number; gpu: number; ram: number }) => void): (() => void) => {
    const handler = (_: Electron.IpcRendererEvent, usage: { cpu: number; gpu: number; ram: number }) => callback(usage);
    ipcRenderer.on('system:usage', handler);
    return () => { ipcRenderer.removeListener('system:usage', handler); };
  },
};

contextBridge.exposeInMainWorld('sensequality', api);

export type SensequalityAPI = typeof api;
