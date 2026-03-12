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

export type RestorePointType =
  | 'APPLICATION_INSTALL'
  | 'APPLICATION_UNINSTALL'
  | 'DEVICE_DRIVER_INSTALL'
  | 'MODIFY_SETTINGS'
  | 'CANCELLED_OPERATION';

export interface RestorePointInfo {
  sequenceNumber: number;
  description: string;
  createdAt: string;
  type: RestorePointType | `TYPE_${number}`;
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

export interface BiosCategory {
  id: string;
  title: string;
  description: string;
  platform: 'both' | 'amd' | 'intel';
  order: number;
}

export interface BiosSetting {
  id: string;
  categoryId: string;
  title: string;
  description: string;
  details: string;
  recommendedValue: string;
  impact: 'high' | 'medium' | 'low';
  risk: 'safe' | 'caution' | 'advanced';
  platform: 'both' | 'amd' | 'intel';
  requiresReboot: boolean;
  vendorNav: { asus: string; msi: string; gigabyte: string; asrock: string };
  warning?: string;
  detectable?: boolean;
  automatable?: boolean;
}

export interface BiosDetectionResult {
  cpuName: string | null;
  cpuManufacturer: string | null;
  motherboardVendor: string | null;
  motherboardModel: string | null;
  biosVendor: string | null;
  biosVersion: string | null;
  isAmiBios: boolean | null;
  ramCurrentSpeed: number | null;
  ramRatedSpeed: number | null;
  ramSticks: number | null;
  ramTotalGB: number | null;
  xmpLikelyEnabled: boolean | null;
  vbsRunning: boolean | null;
  memoryIntegrityEnabled: boolean | null;
  memoryIntegrityRegistry: boolean | null;
  hyperVInstalled: boolean | null;
  virtualizationEnabled: boolean | null;
  secureBootEnabled: boolean | null;
  rebarDetected: boolean | null;
  bar1TotalMB: number | null;
}

// ─── BIOS Automation Types (Phase 3) ──────────────────────

export interface NvramSetting {
  name: string;
  token: string;
  offset: string;
  width: string;
  biosDefault: string;
  currentValue: string;
  options: Record<string, string>; // label → value
  isNumeric: boolean;
  numericMin?: string;
  numericMax?: string;
  numericStep?: string;
  rawBlock: string;
}

export interface ProfileSetting {
  name: string;
  targetValue: string;
  riskLevel: 'safe' | 'low' | 'medium' | 'high';
  description: string;
  matchPattern: string;
}

export interface ProfileChange {
  name: string;
  nvramName: string;
  currentValue: string;
  targetValue: string;
  resolvedValue: string;
  riskLevel: string;
  description: string;
  applied: boolean;
  found: boolean;
}

export interface BiosProfile {
  id: string;
  label: string;
  description: string;
  targetCpus: string[];
  coolingRequirement: string;
  criticalNote?: string;
  settings: ProfileSetting[];
}

export interface BiosBackupInfo {
  filename: string;
  timestamp: string;
  sizeBytes: number;
}

export interface ScewinProvisionStatus {
  ready: boolean;
  missingFiles: string[];
  scewinDir: string;
}

export interface ApplyProfileResult {
  success: boolean;
  changes: ProfileChange[];
  backupPath?: string;
  error?: string;
}

export interface ScewinProvisionProgress {
  step: string;
  progress: number;
  message: string;
  error?: string;
}

export interface GpuGuideSetting {
  setting: string;
  value: string;
  reason: string;
  critical?: boolean;
}

// ─── Subscription Types ──────────────────────────────────

import type { Plan } from '../data/feature-tiers';

/** Statuses Autumn can report, plus internal-only values */
export type SubscriptionStatus = 'free' | 'active' | 'trialing' | 'past_due' | 'canceled' | 'expired';

export interface Subscription {
  plan: Plan;
  status: SubscriptionStatus;
}

export interface BillingAccessResult {
  allowed: boolean;
  plan: Plan;
}

export interface BillingCheckoutResult {
  url?: string;
  error?: string;
}

// ─── Auth Types ──────────────────────────────────────────

export type UserTier = 'free' | 'pro';

export interface AuthUser {
  id: string;
  email: string;
  tier: UserTier;
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
  reason?: 'max_devices' | 'registered' | 'new' | 'not_authenticated' | 'rpc_error' | 'network_error';
  machines?: UserMachine[];
}

/** Token pair received from a Supabase password-recovery deep link. */
export interface PasswordResetTokens {
  access_token: string;
  refresh_token: string;
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
      listRestorePoints: () => Promise<{ points: RestorePointInfo[]; error?: string }>;
      launchSystemRestore: () => Promise<{ success: boolean; error?: string }>;
      exportDiagnostics: () => Promise<{ success: boolean; path: string; error?: string }>;
      minimizeWindow: () => void;
      maximizeWindow: () => void;
      closeWindow: () => void;
      getCloseToBackground: () => Promise<boolean>;
      setCloseToBackground: (enabled: boolean) => Promise<boolean>;
      getLaunchOnStartup: () => Promise<boolean>;
      setLaunchOnStartup: (enabled: boolean) => Promise<boolean>;
      openExternal: (url: string) => Promise<void>;
      hasConsentDecision: () => Promise<boolean>;
      getTelemetryConsent: () => Promise<boolean>;
      setTelemetryConsent: (granted: boolean) => Promise<void>;
      // Auth
      signUp: (email: string, password: string) => Promise<AuthResult>;
      signIn: (email: string, password: string, rememberMe?: boolean) => Promise<AuthResult>;
      signOut: () => Promise<void>;
      resetPassword: (email: string) => Promise<AuthResult>;
      getSession: () => Promise<{ user: AuthUser } | null>;
      getAuthUser: () => Promise<AuthUser | null>;
      isOffline: () => Promise<boolean>;
      getMachineId: () => Promise<string>;
      getRememberMe: () => Promise<boolean>;
      setRememberMe: (value: boolean) => Promise<void>;
      setSessionFromTokens: (tokens: PasswordResetTokens) => Promise<AuthResult>;
      updatePassword: (newPassword: string) => Promise<AuthResult>;
      onPasswordResetTokens: (callback: (tokens: PasswordResetTokens) => void) => () => void;
      // Machine management
      registerMachine: (info: { machine_name: string; gpu: string; cpu: string; ram_gb: number; os_build: string; gpu_driver?: string; gpu_vram_gb?: number }) => Promise<MachineRegistrationResult>;
      deactivateMachine: (machineId: string) => Promise<{ success: boolean; error?: string }>;
      // Waitlist
      joinWaitlist: (feature: string) => Promise<{ success: boolean; error?: string }>;
      hasJoinedWaitlist: (feature: string) => Promise<boolean>;
      // Billing
      billingCheckAccess: () => Promise<BillingAccessResult>;
      billingCheckout: (successUrl?: string) => Promise<BillingCheckoutResult>;
      billingCancelSubscription: (immediately?: boolean) => Promise<{ success: boolean; error?: string }>;
      billingGetSubscription: () => Promise<Subscription>;
      billingOpenPortal: () => Promise<{ success: boolean; error?: string }>;
      billingRefreshAccess: () => Promise<BillingAccessResult>;
      // Updates
      checkForUpdate: () => Promise<UpdateInfo>;
      getUpdaterState: () => Promise<UpdaterState>;
      downloadUpdate: () => Promise<UpdaterActionResult>;
      installUpdate: () => Promise<UpdaterActionResult>;
      onUpdaterState: (callback: (state: UpdaterState) => void) => () => void;
      getAppVersion: () => Promise<string>;
      // BIOS
      scanBiosState: () => Promise<{ success: boolean; data: BiosDetectionResult | null; error?: string }>;
      getBiosProvisionStatus: () => Promise<ScewinProvisionStatus>;
      exportNvram: () => Promise<{ success: boolean; settings?: NvramSetting[]; settingsCount?: number; error?: string }>;
      backupBios: () => Promise<{ success: boolean; path?: string; filename?: string; error?: string }>;
      listBiosBackups: () => Promise<BiosBackupInfo[]>;
      previewBiosProfile: (profileId: string) => Promise<{ success: boolean; changes?: ProfileChange[]; error?: string }>;
      applyBiosProfile: (profileId: string) => Promise<ApplyProfileResult>;
      restoreBiosBackup: (filename: string) => Promise<{ success: boolean; error?: string }>;
      provisionScewin: () => Promise<{ success: boolean; error?: string }>;
      cancelScewinProvision: () => Promise<{ success: boolean }>;
      onScewinProvisionProgress: (callback: (progress: ScewinProvisionProgress) => void) => () => void;
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
