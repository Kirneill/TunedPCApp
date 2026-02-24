import { useAppStore } from '../../store/appStore';
import SystemInfoCard from './SystemInfoCard';
import DetectedGamesCard from './DetectedGamesCard';
import MonitorConfig from './MonitorConfig';
import QuickActions from './QuickActions';
import OptimizationSection from '../optimizations/OptimizationSection';
import LogViewer from '../ui/LogViewer';
import { windowsOptimizations, gameOptimizations } from '../../data/optimizations';

export default function DashboardPage() {
  const { progressLog, isLoading } = useAppStore();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="w-8 h-8 rounded-lg bg-sq-accent mx-auto mb-3 animate-pulse" />
          <p className="text-sm text-sq-text-muted">Detecting system configuration...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-5 max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-sq-text">Performance Dashboard</h1>
        <p className="text-xs text-sq-text-muted mt-1">
          Optimize your PC for competitive FPS gaming. Toggle settings and click Run All to apply.
        </p>
      </div>

      {/* System Info Row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <SystemInfoCard />
        <DetectedGamesCard />
        <MonitorConfig />
      </div>

      {/* Optimization Sections */}
      <OptimizationSection
        title="Windows Optimizations"
        items={windowsOptimizations}
        icon="🪟"
      />

      <OptimizationSection
        title="Game Optimizations"
        items={gameOptimizations}
        icon="🎯"
      />

      {/* Quick Actions */}
      <QuickActions />

      {/* Progress Log */}
      <div>
        <h3 className="text-sm font-semibold text-sq-text mb-2">Progress Log</h3>
        <LogViewer entries={progressLog} maxHeight="280px" />
      </div>
    </div>
  );
}
