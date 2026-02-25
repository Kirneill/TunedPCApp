import { useEffect } from 'react';
import { useAppStore } from './store/appStore';
import TitleBar from './components/layout/TitleBar';
import HomePage from './components/home/HomePage';
import AdvancedPage from './components/advanced/AdvancedPage';
import BiosGuidePage from './components/guides/BiosGuidePage';
import NvidiaGuidePage from './components/guides/NvidiaGuidePage';
import BackupPage from './components/backups/BackupPage';
import ConsentModal from './components/ui/ConsentModal';

export default function App() {
  const { currentPage, setSystemInfo, setDetectedGames, setIsAdmin, setIsLoading, addLogEntry, setShowConsentModal, setTelemetryEnabled } = useAppStore();

  useEffect(() => {
    async function init() {
      try {
        const [sysInfo, games, admin] = await Promise.all([
          window.sensequality.getSystemInfo(),
          window.sensequality.getInstalledGames(),
          window.sensequality.isAdmin(),
        ]);
        setSystemInfo(sysInfo);
        setDetectedGames(games);
        setIsAdmin(admin);
        if (sysInfo.isNvidia) {
          useAppStore.getState().setUserConfig({ nvidiaGpu: true });
        }

        // Check telemetry consent — show modal on first launch
        const hasDecision = await window.sensequality.hasConsentDecision();
        if (!hasDecision) {
          setShowConsentModal(true);
        } else {
          const consent = await window.sensequality.getTelemetryConsent();
          setTelemetryEnabled(consent);
        }
      } catch (err) {
        console.error('Init failed:', err);
      } finally {
        setIsLoading(false);
      }
    }
    init();
    const unsubscribe = window.sensequality.onProgressLog((entry) => {
      addLogEntry(entry);
    });
    return unsubscribe;
  }, []);

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
      <main className="flex-1 overflow-y-auto">
        {renderPage()}
      </main>
      <ConsentModal />
    </div>
  );
}
