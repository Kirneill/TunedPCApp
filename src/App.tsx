import { useEffect } from 'react';
import { useAppStore } from './store/appStore';
import TitleBar from './components/layout/TitleBar';
import Sidebar from './components/layout/Sidebar';
import DashboardPage from './components/dashboard/DashboardPage';
import BiosGuidePage from './components/guides/BiosGuidePage';
import NvidiaGuidePage from './components/guides/NvidiaGuidePage';
import BackupPage from './components/backups/BackupPage';

export default function App() {
  const { currentPage, setSystemInfo, setDetectedGames, setIsAdmin, setIsLoading, addLogEntry } = useAppStore();

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

        // Auto-detect GPU type
        if (sysInfo.isNvidia) {
          useAppStore.getState().setUserConfig({ nvidiaGpu: true });
        }
      } catch (err) {
        console.error('Init failed:', err);
      } finally {
        setIsLoading(false);
      }
    }

    init();

    // Subscribe to progress logs from main process
    const unsubscribe = window.sensequality.onProgressLog((entry) => {
      addLogEntry(entry);
    });

    return unsubscribe;
  }, []);

  const renderPage = () => {
    switch (currentPage) {
      case 'bios-guide': return <BiosGuidePage />;
      case 'gpu-guide': return <NvidiaGuidePage />;
      case 'backups': return <BackupPage />;
      default: return <DashboardPage />;
    }
  };

  return (
    <div className="flex flex-col h-full">
      <TitleBar />
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />
        <main className="flex-1 overflow-y-auto p-6">
          {renderPage()}
        </main>
      </div>
    </div>
  );
}
