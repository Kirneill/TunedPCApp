import { create } from 'zustand';
import type { SystemInfo, DetectedGame, LogEntry, UserConfig, AuthUser, UserMachine, UpdateInfo, UpdaterState, PasswordResetTokens, Subscription, BiosDetectionResult, ScewinProvisionStatus, BiosBackupInfo, ProfileChange, ApplyProfileResult, ScewinProvisionProgress } from '../types';
import { isProActive } from '../data/feature-tiers';
import { GAMES } from '../data/game-registry';

interface AppState {
  // Auth
  authUser: AuthUser | null;
  authLoading: boolean;
  authError: string | null;
  machines: UserMachine[];
  showAuthGate: boolean;
  showMaxDevices: boolean;
  isOffline: boolean;

  // System
  systemInfo: SystemInfo | null;
  systemUsage: { cpu: number; gpu: number; ram: number } | null;
  detectedGames: DetectedGame[];
  isAdmin: boolean;
  isLoading: boolean;

  // Navigation
  currentPage: 'dashboard' | 'advanced' | 'network' | 'bios-guide' | 'gpu-guide' | 'memory' | 'backups';

  // Optimization toggles
  toggles: Record<string, boolean>;
  windowsUpdateMode: 'on' | 'off';

  // User config
  userConfig: UserConfig;

  // Execution state
  isRunning: boolean;
  progressLog: LogEntry[];
  progress: { completed: number; total: number };

  // Telemetry
  showConsentModal: boolean;
  telemetryEnabled: boolean;

  // Updates
  updateInfo: UpdateInfo | null;
  updateDismissed: boolean;
  updaterState: UpdaterState;
  closeToBackground: boolean;

  // Subscription
  subscription: Subscription;
  isPro: () => boolean;
  setSubscription: (sub: Subscription) => void;

  // Password reset deep link
  passwordResetTokens: PasswordResetTokens | null;

  // BIOS detection
  biosDetection: BiosDetectionResult | null;
  biosScanLoading: boolean;
  biosScanError: string | null;

  // BIOS automation (Phase 3)
  scewinStatus: ScewinProvisionStatus | null;
  biosBackups: BiosBackupInfo[];
  selectedBiosProfile: string | null;
  profilePreview: ProfileChange[] | null;
  profilePreviewLoading: boolean;
  biosApplying: boolean;
  biosApplyResult: ApplyProfileResult | null;
  scewinProvisionProgress: ScewinProvisionProgress | null;

  // BIOS UI state
  biosActiveTab: 'overview' | 'guide' | 'automate';
  biosHasAutoScanned: boolean;
  checkedBiosSettings: Record<string, boolean>;
  biosExpandedCategories: Record<string, boolean>;
  biosExpandedSettings: Record<string, boolean>;

  // Auth actions
  setAuthUser: (user: AuthUser | null) => void;
  setAuthLoading: (loading: boolean) => void;
  setAuthError: (error: string | null) => void;
  setMachines: (machines: UserMachine[]) => void;
  setShowAuthGate: (show: boolean) => void;
  setShowMaxDevices: (show: boolean) => void;
  setIsOffline: (offline: boolean) => void;
  clearAuthState: () => void;

  // Actions
  setSystemInfo: (info: SystemInfo) => void;
  setSystemUsage: (usage: { cpu: number; gpu: number; ram: number }) => void;
  setDetectedGames: (games: DetectedGame[]) => void;
  setIsAdmin: (admin: boolean) => void;
  setIsLoading: (loading: boolean) => void;
  setCurrentPage: (page: AppState['currentPage']) => void;
  setToggle: (id: string, value: boolean) => void;
  setAllToggles: (value: boolean) => void;
  setWindowsUpdateMode: (mode: 'on' | 'off') => void;
  setUserConfig: (config: Partial<UserConfig>) => void;
  setIsRunning: (running: boolean) => void;
  addLogEntry: (entry: LogEntry) => void;
  clearLog: () => void;
  setProgress: (completed: number, total: number) => void;
  setShowConsentModal: (show: boolean) => void;
  setTelemetryEnabled: (enabled: boolean) => void;
  setUpdateInfo: (info: UpdateInfo | null) => void;
  setUpdaterState: (state: UpdaterState) => void;
  dismissUpdate: () => void;
  setCloseToBackground: (enabled: boolean) => void;
  setPasswordResetTokens: (tokens: PasswordResetTokens | null) => void;
  setBiosDetection: (data: BiosDetectionResult | null) => void;
  setBiosScanLoading: (loading: boolean) => void;
  setBiosScanError: (error: string | null) => void;
  setScewinStatus: (status: ScewinProvisionStatus | null) => void;
  setBiosBackups: (backups: BiosBackupInfo[]) => void;
  setSelectedBiosProfile: (profileId: string | null) => void;
  setProfilePreview: (changes: ProfileChange[] | null) => void;
  setProfilePreviewLoading: (loading: boolean) => void;
  setBiosApplying: (applying: boolean) => void;
  setBiosApplyResult: (result: ApplyProfileResult | null) => void;
  setScewinProvisionProgress: (progress: ScewinProvisionProgress | null) => void;
  setBiosActiveTab: (tab: AppState['biosActiveTab']) => void;
  setBiosHasAutoScanned: (v: boolean) => void;
  setCheckedBiosSetting: (id: string, value: boolean) => void;
  toggleBiosCategoryExpanded: (categoryId: string) => void;
  toggleBiosSettingExpanded: (settingId: string) => void;
}

// User-namespaced localStorage key
let storageUserId = '';

function getStorageKey(): string {
  return storageUserId ? `sensequality-config:${storageUserId}` : 'sensequality-config';
}

// Load persisted config from localStorage
function loadPersistedConfig(userId?: string): Partial<{
  toggles: Record<string, boolean>;
  userConfig: Partial<UserConfig>;
  windowsUpdateMode: 'on' | 'off';
}> {
  try {
    const key = userId ? `sensequality-config:${userId}` : 'sensequality-config';
    const stored = localStorage.getItem(key);
    if (stored) return JSON.parse(stored);
  } catch {}
  return {};
}

// Game toggle defaults derived from the unified game registry -- no manual sync needed
const gameToggles = Object.fromEntries(
  GAMES.map(g => [`game-${g.id}`, g.defaultEnabled])
);

const DEFAULT_TOGGLES: Record<string, boolean> = {
  'win-all': true,
  'win-power-plan': true,
  'win-hags': true,
  'win-game-mode': true,
  'win-mmcss': true,
  'win-network': true,
  'win-visual-fx': true,
  'win-fullscreen': true,
  'win-mouse': true,
  'win-cpu-power': true,
  'win-bg-apps': true,
  'win-mpo': true,
  'win-visual-extras': true,
  'win-copilot': true,
  'win-standard': true,
  'win-gpu-profile': true,
  'win-dns': true,
  'win-net-adapter': true,
  'win-tcp-stack': true,
  'win-net-throttle': true,
  'win-timer-res': true,
  'win-power-throttle': true,
  'win-priority-sep': true,
  'win-dynamic-tick': false,   // bcdedit change -- hardware-dependent, opt-in only
  'win-hpet': false,           // bcdedit change -- hardware-dependent, opt-in only
  ...gameToggles,
};

const DEFAULT_USER_CONFIG: UserConfig = {
  monitorWidth: 1920,
  monitorHeight: 1080,
  monitorRefresh: 240,
  nvidiaGpu: true,
  gpuMode: 'auto',
  selectedGpuId: '',
  cs2Stretched: false,
  restorePointEnabled: true,
};

function normalizePersistedToggles(toggles?: Record<string, boolean>): Record<string, boolean> {
  return { ...DEFAULT_TOGGLES, ...(toggles || {}) };
}

function normalizePersistedUserConfig(userConfig?: Partial<UserConfig>): UserConfig {
  if (!userConfig) return { ...DEFAULT_USER_CONFIG };
  const gpuMode = userConfig.gpuMode === 'manual' ? 'manual' : 'auto';
  const selectedGpuId = typeof userConfig.selectedGpuId === 'string' ? userConfig.selectedGpuId : '';
  const restorePointEnabled = userConfig.restorePointEnabled !== false;

  return {
    ...DEFAULT_USER_CONFIG,
    ...userConfig,
    gpuMode,
    selectedGpuId,
    restorePointEnabled,
  };
}

const persisted = loadPersistedConfig();

export const useAppStore = create<AppState>((set, get) => ({
  // Auth state
  authUser: null,
  authLoading: true,
  authError: null,
  machines: [],
  showAuthGate: false,
  showMaxDevices: false,
  isOffline: false,

  // Initial state
  systemInfo: null,
  systemUsage: null,
  detectedGames: [],
  isAdmin: false,
  isLoading: true,
  currentPage: 'dashboard',

  toggles: normalizePersistedToggles(persisted.toggles),
  windowsUpdateMode: persisted.windowsUpdateMode || 'on',

  userConfig: normalizePersistedUserConfig(persisted.userConfig),

  isRunning: false,
  progressLog: [],
  progress: { completed: 0, total: 0 },
  showConsentModal: false,
  telemetryEnabled: false,
  updateInfo: null,
  updateDismissed: false,
  updaterState: {
    status: 'idle',
    progress: 0,
    message: '',
  },
  closeToBackground: true,
  passwordResetTokens: null,
  subscription: { plan: 'free', status: 'free' },
  isPro: () => {
    const sub = get().subscription;
    return sub.plan === 'pro' || sub.plan === 'dev' || isProActive(sub.status);
  },
  setSubscription: (sub) => set({ subscription: sub }),
  biosDetection: null,
  biosScanLoading: false,
  biosScanError: null,
  scewinStatus: null,
  biosBackups: [],
  selectedBiosProfile: null,
  profilePreview: null,
  profilePreviewLoading: false,
  biosApplying: false,
  biosApplyResult: null,
  scewinProvisionProgress: null,
  biosActiveTab: 'overview',
  biosHasAutoScanned: false,
  checkedBiosSettings: {},
  biosExpandedCategories: {},
  biosExpandedSettings: {},

  // Auth actions
  setAuthUser: (user) => {
    if (user) {
      storageUserId = user.id;
      // Reload config for this user
      const userConfig = loadPersistedConfig(user.id);
      set({ toggles: normalizePersistedToggles(userConfig.toggles) });
      if (userConfig.userConfig) set({ userConfig: normalizePersistedUserConfig(userConfig.userConfig) });
      if (userConfig.windowsUpdateMode) set({ windowsUpdateMode: userConfig.windowsUpdateMode });
    } else {
      storageUserId = '';
    }
    set({ authUser: user });
  },
  setAuthLoading: (loading) => set({ authLoading: loading }),
  setAuthError: (error) => set({ authError: error }),
  setMachines: (machines) => set({ machines }),
  setShowAuthGate: (show) => set({ showAuthGate: show }),
  setShowMaxDevices: (show) => set({ showMaxDevices: show }),
  setIsOffline: (offline) => set({ isOffline: offline }),
  clearAuthState: () => {
    storageUserId = '';
    set({
      authUser: null,
      authError: null,
      machines: [],
      showAuthGate: true,
      showMaxDevices: false,
      isOffline: false,
      systemInfo: null,
      detectedGames: [],
      progressLog: [],
      currentPage: 'dashboard',
      subscription: { plan: 'free', status: 'free' },
    });
  },

  // Actions
  setSystemInfo: (info) => set({ systemInfo: info }),
  setSystemUsage: (usage) => set({ systemUsage: usage }),
  setDetectedGames: (games) => set({ detectedGames: games }),
  setIsAdmin: (admin) => set({ isAdmin: admin }),
  setIsLoading: (loading) => set({ isLoading: loading }),
  setCurrentPage: (page) => set({ currentPage: page }),

  setToggle: (id, value) => {
    const toggles = { ...get().toggles, [id]: value };
    set({ toggles });
    persistConfig(toggles, get().userConfig, get().windowsUpdateMode);
  },

  setAllToggles: (value) => {
    const toggles = { ...get().toggles };
    for (const key of Object.keys(toggles)) {
      toggles[key] = value;
    }
    set({ toggles });
    persistConfig(toggles, get().userConfig, get().windowsUpdateMode);
  },

  setWindowsUpdateMode: (mode) => {
    set({ windowsUpdateMode: mode });
    persistConfig(get().toggles, get().userConfig, mode);
  },

  setUserConfig: (config) => {
    const userConfig = { ...get().userConfig, ...config };
    set({ userConfig });
    persistConfig(get().toggles, userConfig, get().windowsUpdateMode);
  },

  setIsRunning: (running) => set({ isRunning: running }),
  addLogEntry: (entry) => set((s) => ({ progressLog: [...s.progressLog, entry] })),
  clearLog: () => set({ progressLog: [] }),
  setProgress: (completed, total) => set({ progress: { completed, total } }),
  setShowConsentModal: (show) => set({ showConsentModal: show }),
  setTelemetryEnabled: (enabled) => set({ telemetryEnabled: enabled }),
  setUpdateInfo: (info) => set({
    updateInfo: info,
    // If an update is found again via manual check, show the banner even if it was dismissed before.
    updateDismissed: info?.hasUpdate ? false : get().updateDismissed,
  }),
  setUpdaterState: (state) => set({ updaterState: state }),
  dismissUpdate: () => set({ updateDismissed: true }),
  setCloseToBackground: (enabled) => set({ closeToBackground: enabled }),
  setPasswordResetTokens: (tokens) => set({ passwordResetTokens: tokens }),
  setBiosDetection: (data) => set({ biosDetection: data }),
  setBiosScanLoading: (loading) => set({ biosScanLoading: loading }),
  setBiosScanError: (error) => set({ biosScanError: error }),
  setScewinStatus: (status) => set({ scewinStatus: status }),
  setBiosBackups: (backups) => set({ biosBackups: backups }),
  setSelectedBiosProfile: (profileId) => set({ selectedBiosProfile: profileId, profilePreview: null, biosApplyResult: null }),
  setProfilePreview: (changes) => set({ profilePreview: changes }),
  setProfilePreviewLoading: (loading) => set({ profilePreviewLoading: loading }),
  setBiosApplying: (applying) => set({ biosApplying: applying }),
  setBiosApplyResult: (result) => set({ biosApplyResult: result }),
  setScewinProvisionProgress: (progress) => set({ scewinProvisionProgress: progress }),
  setBiosActiveTab: (tab) => set({ biosActiveTab: tab }),
  setBiosHasAutoScanned: (v) => set({ biosHasAutoScanned: v }),
  setCheckedBiosSetting: (id, value) => set((s) => ({
    checkedBiosSettings: { ...s.checkedBiosSettings, [id]: value },
  })),
  toggleBiosCategoryExpanded: (categoryId) => set((s) => ({
    biosExpandedCategories: { ...s.biosExpandedCategories, [categoryId]: !s.biosExpandedCategories[categoryId] },
  })),
  toggleBiosSettingExpanded: (settingId) => set((s) => ({
    biosExpandedSettings: { ...s.biosExpandedSettings, [settingId]: !s.biosExpandedSettings[settingId] },
  })),
}));

function persistConfig(
  toggles: Record<string, boolean>,
  userConfig: UserConfig,
  windowsUpdateMode: 'on' | 'off'
) {
  try {
    localStorage.setItem(getStorageKey(), JSON.stringify({ toggles, userConfig, windowsUpdateMode }));
  } catch {}
}
