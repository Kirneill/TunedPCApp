import { create } from 'zustand';
import type { SystemInfo, DetectedGame, BackupInfo, LogEntry, UserConfig } from '../types';

interface AppState {
  // System
  systemInfo: SystemInfo | null;
  detectedGames: DetectedGame[];
  isAdmin: boolean;
  isLoading: boolean;

  // Navigation
  currentPage: 'dashboard' | 'bios-guide' | 'gpu-guide' | 'backups';

  // Optimization toggles
  toggles: Record<string, boolean>;

  // User config
  userConfig: UserConfig;

  // Execution state
  isRunning: boolean;
  progressLog: LogEntry[];
  progress: { completed: number; total: number };

  // Backups
  backups: BackupInfo[];

  // Actions
  setSystemInfo: (info: SystemInfo) => void;
  setDetectedGames: (games: DetectedGame[]) => void;
  setIsAdmin: (admin: boolean) => void;
  setIsLoading: (loading: boolean) => void;
  setCurrentPage: (page: AppState['currentPage']) => void;
  setToggle: (id: string, value: boolean) => void;
  setAllToggles: (value: boolean) => void;
  setUserConfig: (config: Partial<UserConfig>) => void;
  setIsRunning: (running: boolean) => void;
  addLogEntry: (entry: LogEntry) => void;
  clearLog: () => void;
  setProgress: (completed: number, total: number) => void;
  setBackups: (backups: BackupInfo[]) => void;
}

// Load persisted config from localStorage
function loadPersistedConfig(): Partial<{ toggles: Record<string, boolean>; userConfig: UserConfig }> {
  try {
    const stored = localStorage.getItem('sensequality-config');
    if (stored) return JSON.parse(stored);
  } catch {}
  return {};
}

const persisted = loadPersistedConfig();

export const useAppStore = create<AppState>((set, get) => ({
  // Initial state
  systemInfo: null,
  detectedGames: [],
  isAdmin: false,
  isLoading: true,
  currentPage: 'dashboard',

  toggles: persisted.toggles || {
    'win-power-plan': true,
    'win-hags': true,
    'win-game-mode': true,
    'win-mmcss': true,
    'win-network': true,
    'win-visual-fx': true,
    'win-fullscreen': true,
    'win-mouse': true,
    'win-cpu-power': true,
    'game-blackops7': true,
    'game-fortnite': true,
    'game-valorant': true,
    'game-cs2': true,
    'game-arcraiders': true,
  },

  userConfig: persisted.userConfig || {
    monitorWidth: 1920,
    monitorHeight: 1080,
    monitorRefresh: 240,
    nvidiaGpu: true,
    cs2Stretched: false,
  },

  isRunning: false,
  progressLog: [],
  progress: { completed: 0, total: 0 },
  backups: [],

  // Actions
  setSystemInfo: (info) => set({ systemInfo: info }),
  setDetectedGames: (games) => set({ detectedGames: games }),
  setIsAdmin: (admin) => set({ isAdmin: admin }),
  setIsLoading: (loading) => set({ isLoading: loading }),
  setCurrentPage: (page) => set({ currentPage: page }),

  setToggle: (id, value) => {
    const toggles = { ...get().toggles, [id]: value };
    set({ toggles });
    persistConfig(toggles, get().userConfig);
  },

  setAllToggles: (value) => {
    const toggles = { ...get().toggles };
    for (const key of Object.keys(toggles)) {
      toggles[key] = value;
    }
    set({ toggles });
    persistConfig(toggles, get().userConfig);
  },

  setUserConfig: (config) => {
    const userConfig = { ...get().userConfig, ...config };
    set({ userConfig });
    persistConfig(get().toggles, userConfig);
  },

  setIsRunning: (running) => set({ isRunning: running }),
  addLogEntry: (entry) => set((s) => ({ progressLog: [...s.progressLog, entry] })),
  clearLog: () => set({ progressLog: [] }),
  setProgress: (completed, total) => set({ progress: { completed, total } }),
  setBackups: (backups) => set({ backups }),
}));

function persistConfig(toggles: Record<string, boolean>, userConfig: UserConfig) {
  try {
    localStorage.setItem('sensequality-config', JSON.stringify({ toggles, userConfig }));
  } catch {}
}
