import { useEffect, useState } from 'react';
import type { RestorePointInfo } from '../../types';
import { useAppStore } from '../../store/appStore';

export default function BackupPage() {
  const addLogEntry = useAppStore((s) => s.addLogEntry);
  const [latestPoint, setLatestPoint] = useState<RestorePointInfo | null>(null);
  const [loadingPoints, setLoadingPoints] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionInProgress, setActionInProgress] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const result = await window.sensequality.listRestorePoints();
        if (result.error) setError(result.error);
        if (result.points.length > 0) {
          const sorted = [...result.points].sort(
            (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
          );
          setLatestPoint(sorted[0]);
        }
      } catch {
        setError('Failed to load restore points.');
      }
      setLoadingPoints(false);
    })();
  }, []);

  const handleCreate = async () => {
    setActionInProgress('creating');
    try {
      const result = await window.sensequality.createRestorePoint();
      if (result.success) {
        addLogEntry({ type: 'success', message: 'System restore point created successfully.', timestamp: Date.now(), section: 'Safety' });
        // Refresh latest point
        const refreshed = await window.sensequality.listRestorePoints();
        if (refreshed.points.length > 0) {
          const sorted = [...refreshed.points].sort(
            (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
          );
          setLatestPoint(sorted[0]);
        }
      } else {
        addLogEntry({ type: 'error', message: `Restore point creation failed: ${result.errors?.join(', ') || 'Unknown error'}`, timestamp: Date.now(), section: 'Safety' });
      }
    } catch (err) {
      addLogEntry({ type: 'error', message: `Restore point creation failed: ${String(err)}`, timestamp: Date.now(), section: 'Safety' });
    } finally {
      setActionInProgress(null);
    }
  };

  const handleRestore = async () => {
    setActionInProgress('launching');
    try {
      const result = await window.sensequality.launchSystemRestore();
      if (!result.success) {
        addLogEntry({ type: 'error', message: `Failed to open System Restore: ${result.error || 'Unknown error'}`, timestamp: Date.now(), section: 'Safety' });
      }
    } catch (err) {
      addLogEntry({ type: 'error', message: `Failed to open System Restore: ${String(err)}`, timestamp: Date.now(), section: 'Safety' });
    } finally {
      setActionInProgress(null);
    }
  };

  const handleExport = async () => {
    setActionInProgress('exporting');
    try {
      const result = await window.sensequality.exportDiagnostics();
      if (result.success) {
        addLogEntry({ type: 'success', message: `Diagnostics exported: ${result.path}`, timestamp: Date.now(), section: 'Diagnostics' });
      } else {
        addLogEntry({ type: 'error', message: `Diagnostics export failed: ${result.error || 'Unknown error'}`, timestamp: Date.now(), section: 'Diagnostics' });
      }
    } catch (err) {
      addLogEntry({ type: 'error', message: `Diagnostics export failed: ${String(err)}`, timestamp: Date.now(), section: 'Diagnostics' });
    } finally {
      setActionInProgress(null);
    }
  };

  const formatDate = (iso: string) => {
    try {
      const d = new Date(iso);
      if (isNaN(d.getTime())) return iso;
      return d.toLocaleDateString(undefined, {
        year: 'numeric', month: 'short', day: 'numeric',
        hour: '2-digit', minute: '2-digit',
      });
    } catch {
      return iso;
    }
  };

  const Spinner = () => (
    <svg className="w-5 h-5 animate-spin" viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  );

  return (
    <div className="flex flex-col items-center justify-center h-full p-8 gap-6">
      {/* Error banner */}
      {error && (
        <div className="w-full max-w-2xl rounded-lg px-4 py-2.5 border border-sq-danger/30 bg-sq-danger/5 flex items-center gap-2">
          <svg className="w-4 h-4 text-sq-danger shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
          </svg>
          <span className="text-xs text-sq-danger">{error}</span>
        </div>
      )}

      {/* Two big action cards */}
      <div className="grid grid-cols-2 gap-6 w-full max-w-2xl">
        {/* Create Restore Point */}
        <button
          onClick={handleCreate}
          disabled={actionInProgress !== null}
          className="group relative rounded-2xl p-8 bg-gradient-to-br from-sq-accent to-sq-accent-dim text-white shadow-lg shadow-sq-accent/25 hover:shadow-xl hover:shadow-sq-accent/35 active:scale-[0.98] transition-all duration-200 disabled:opacity-60 disabled:pointer-events-none flex flex-col items-center gap-4 cursor-pointer"
        >
          {actionInProgress === 'creating' ? (
            <Spinner />
          ) : (
            <svg className="w-10 h-10 opacity-90" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
          )}
          <div className="text-center">
            <div className="text-sm font-bold tracking-wide">
              {actionInProgress === 'creating' ? 'Creating...' : 'Create Restore Point'}
            </div>
            <div className="text-xs opacity-70 mt-1.5">Snapshot your current system state</div>
          </div>
        </button>

        {/* Restore System */}
        <button
          onClick={handleRestore}
          disabled={actionInProgress !== null}
          className="group relative sq-glass rounded-2xl p-8 border border-sq-border hover:border-sq-accent/40 hover:bg-white/[0.03] active:scale-[0.98] transition-all duration-200 disabled:opacity-60 disabled:pointer-events-none flex flex-col items-center gap-4 cursor-pointer"
        >
          {actionInProgress === 'launching' ? (
            <Spinner />
          ) : (
            <svg className="w-10 h-10 text-sq-text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          )}
          <div className="text-center">
            <div className="text-sm font-bold text-sq-text tracking-wide">
              {actionInProgress === 'launching' ? 'Opening...' : 'Restore System'}
            </div>
            <div className="text-xs text-sq-text-muted mt-1.5">
              {loadingPoints ? (
                'Loading...'
              ) : latestPoint ? (
                <>
                  <span className="block truncate max-w-[200px] mx-auto">Roll back to: {latestPoint.description}</span>
                  <span className="block opacity-60 mt-0.5">{formatDate(latestPoint.createdAt)}</span>
                </>
              ) : (
                'No restore points yet'
              )}
            </div>
          </div>
        </button>
      </div>

      {/* Export Diagnostics */}
      <button
        onClick={handleExport}
        disabled={actionInProgress !== null}
        className="px-4 py-2 rounded-lg text-xs font-medium text-sq-text-muted border border-sq-border hover:border-sq-accent/40 hover:text-sq-text hover:bg-white/[0.03] transition-all disabled:opacity-50 flex items-center gap-2"
      >
        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
        </svg>
        {actionInProgress === 'exporting' ? 'Exporting...' : 'Export Diagnostics'}
      </button>
    </div>
  );
}
