import { useEffect, useRef } from 'react';
import { useAppStore } from './store/appStore';
import TitleBar from './components/layout/TitleBar';
import HomePage from './components/home/HomePage';
import AdvancedPage from './components/advanced/AdvancedPage';
import BiosGuidePage from './components/guides/BiosGuidePage';
import NvidiaGuidePage from './components/guides/NvidiaGuidePage';
import BackupPage from './components/backups/BackupPage';
import ConsentModal from './components/ui/ConsentModal';
import AuthGate from './components/auth/AuthGate';
import MaxDevicesScreen from './components/auth/MaxDevicesScreen';
import UpdateBanner from './components/ui/UpdateBanner';
import appLogo from './assets/app-logo.ico';

export default function App() {
  const {
    currentPage, authLoading, showAuthGate, showMaxDevices, isOffline,
    setAuthUser, setAuthLoading, setShowAuthGate, setShowMaxDevices,
    setIsOffline, setMachines, clearAuthState,
    setSystemInfo, setDetectedGames, setIsAdmin, setIsLoading,
    addLogEntry, setShowConsentModal, setTelemetryEnabled,
    setUpdateInfo, setUpdaterState, setCloseToBackground, setUserConfig,
  } = useAppStore();

  // StrictMode guard — prevent double-init in dev
  const initCalledRef = useRef(false);

  const initializeAuthenticatedApp = async () => {
    setIsLoading(true);
    try {
      // Phase 3: Get system info + register machine
      const sysInfo = await window.sensequality.getSystemInfo();
      setSystemInfo(sysInfo);

      const currentConfig = useAppStore.getState().userConfig;
      const adapters = sysInfo.gpuAdapters || [];
      const primaryAdapter = adapters.find((adapter) => adapter.id === sysInfo.primaryGpuId) || adapters[0];
      const manualAdapter = adapters.find((adapter) => adapter.id === currentConfig.selectedGpuId);
      const effectiveAdapter = currentConfig.gpuMode === 'manual'
        ? (manualAdapter || primaryAdapter)
        : primaryAdapter;

      const gpuUpdates: Partial<typeof currentConfig> = {};
      if (currentConfig.gpuMode === 'manual' && !manualAdapter && primaryAdapter) {
        gpuUpdates.selectedGpuId = primaryAdapter.id;
      }
      if (effectiveAdapter) {
        gpuUpdates.nvidiaGpu = effectiveAdapter.vendor === 'nvidia';
      } else {
        gpuUpdates.nvidiaGpu = sysInfo.isNvidia;
      }

      if (Object.keys(gpuUpdates).length > 0) {
        setUserConfig(gpuUpdates);
      }

      const regResult = await window.sensequality.registerMachine({
        machine_name: sysInfo.cpu,
        gpu: sysInfo.gpu,
        cpu: sysInfo.cpu,
        ram_gb: sysInfo.ramGB,
        os_build: sysInfo.osBuild,
      });

      if (!regResult.success) {
        if (regResult.reason === 'max_devices') {
          setMachines(regResult.machines || []);
          setShowMaxDevices(true);
          return;
        }

        try {
          await window.sensequality.signOut();
        } catch {}
        clearAuthState();
        return;
      }

      setShowMaxDevices(false);

      // Phase 4: Normal app init
      const [games, admin, updaterState] = await Promise.all([
        window.sensequality.getInstalledGames(),
        window.sensequality.isAdmin(),
        window.sensequality.getUpdaterState(),
      ]);
      setDetectedGames(games);
      setIsAdmin(admin);
      setUpdaterState(updaterState);

      // Phase 5: Telemetry consent check
      const hasDecision = await window.sensequality.hasConsentDecision();
      if (!hasDecision) {
        setShowConsentModal(true);
      } else {
        const consent = await window.sensequality.getTelemetryConsent();
        setTelemetryEnabled(consent);
      }

      // Phase 6: Check for updates (fire-and-forget)
      window.sensequality.checkForUpdate().then((info) => {
        if (info.hasUpdate) setUpdateInfo(info);
      }).catch(() => {});
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (initCalledRef.current) return;
    initCalledRef.current = true;

    async function bootstrap() {
      try {
        try {
          const closeToBackground = await window.sensequality.getCloseToBackground();
          setCloseToBackground(closeToBackground);
        } catch {}

        // Phase 1: Check for offline state
        const offline = await window.sensequality.isOffline();
        if (offline) {
          setIsOffline(true);
          setAuthLoading(false);
          return;
        }

        // Phase 2: Check auth session
        const session = await window.sensequality.getSession();
        if (!session) {
          setShowAuthGate(true);
          setAuthLoading(false);
          return;
        }

        setAuthUser(session.user);
        await initializeAuthenticatedApp();
      } catch (err) {
        console.error('Bootstrap failed:', err);
        // If bootstrap fails entirely, show auth gate as fallback
        setShowAuthGate(true);
      } finally {
        setAuthLoading(false);
      }
    }

    bootstrap();

    const unsubscribeLogs = window.sensequality.onProgressLog((entry) => {
      addLogEntry(entry);
    });
    const unsubscribeUpdater = window.sensequality.onUpdaterState((state) => {
      setUpdaterState(state);
    });
    return () => {
      unsubscribeLogs();
      unsubscribeUpdater();
    };
  }, []);

  const handleRetry = () => {
    setIsOffline(false);
    setAuthLoading(true);
    initCalledRef.current = false;
    // Force re-run by toggling a state — the useEffect won't re-fire on its own
    // so we reload the window
    window.location.reload();
  };

  // ─── Render states ────────────────────────────────

  // Loading spinner
  if (authLoading) {
    return (
      <div className="flex flex-col h-full bg-sq-bg">
        <div className="drag-region flex items-center justify-end h-11 px-4 shrink-0">
          <div className="flex items-center no-drag">
            <button
              onClick={() => window.sensequality.minimizeWindow()}
              className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
            >
              <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
            </button>
            <button
              onClick={() => window.sensequality.closeWindow()}
              className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-white hover:bg-sq-danger transition-colors"
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
            </button>
          </div>
        </div>
        <div className="flex-1 flex items-center justify-center">
          <div className="flex flex-col items-center gap-4">
            <img src={appLogo} alt="SENSEQUALITY logo" className="w-12 h-12 rounded-xl shadow-lg shadow-sq-accent/30" />
            <svg className="w-6 h-6 animate-spin text-sq-accent" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          </div>
        </div>
      </div>
    );
  }

  // Offline screen
  if (isOffline) {
    return (
      <div className="flex flex-col h-full bg-sq-bg">
        <div className="drag-region flex items-center justify-end h-11 px-4 shrink-0">
          <div className="flex items-center no-drag">
            <button
              onClick={() => window.sensequality.minimizeWindow()}
              className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
            >
              <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
            </button>
            <button
              onClick={() => window.sensequality.closeWindow()}
              className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-white hover:bg-sq-danger transition-colors"
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
            </button>
          </div>
        </div>
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center max-w-sm mx-4">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-sq-warning/20 flex items-center justify-center">
              <svg className="w-8 h-8 text-sq-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h2 className="text-lg font-bold text-sq-text mb-2">No Internet Connection</h2>
            <p className="text-sm text-sq-text-muted mb-6">
              SENSEQUALITY requires an internet connection to verify your account. Please check your network and try again.
            </p>
            <button
              onClick={handleRetry}
              className="px-6 py-2.5 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Auth gate
  if (showAuthGate) {
    return (
      <AuthGate
        onAuthenticated={async () => {
          await initializeAuthenticatedApp();
        }}
      />
    );
  }

  // Max devices
  if (showMaxDevices) return <MaxDevicesScreen />;

  // Normal app
  const renderPage = () => {
    switch (currentPage) {
      case 'advanced': return <AdvancedPage />;
      case 'bios-guide': return <BiosGuidePage />;
      case 'gpu-guide': return <NvidiaGuidePage />;
      case 'backups': return <BackupPage />;
      default: return <HomePage />;
    }
  };

  return (
    <div className="flex flex-col h-full bg-sq-bg">
      <TitleBar />
      <UpdateBanner />
      <main className="flex-1 overflow-y-auto">
        {renderPage()}
      </main>
      <ConsentModal />
    </div>
  );
}
