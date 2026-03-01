import { useEffect, useState } from 'react';
import Badge from '../ui/Badge';
import type { BackupInfo } from '../../types';
import { useAppStore } from '../../store/appStore';

const CARD_COLORS = ['#e11d2f', '#f59e0b', '#22c55e', '#3b82f6', '#a855f7', '#06b6d4'];

export default function BackupPage() {
  const addLogEntry = useAppStore((s) => s.addLogEntry);
  const [backups, setBackups] = useState<BackupInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionInProgress, setActionInProgress] = useState<string | null>(null);

  const loadBackups = async () => {
    setLoading(true);
    try {
      const list = await window.sensequality.listBackups();
      setBackups(list);
    } catch {}
    setLoading(false);
  };

  useEffect(() => { loadBackups(); }, []);

  const handleCreate = async () => {
    setActionInProgress('creating');
    try {
      const result = await window.sensequality.createBackup();
      if (result.success) {
        await loadBackups();
      }
    } catch (err) {
      console.error('Backup creation failed:', err);
    } finally {
      setActionInProgress(null);
    }
  };

  const handleRestore = async (backupPath: string) => {
    setActionInProgress(backupPath);
    try {
      await window.sensequality.restoreBackup(backupPath);
    } catch (err) {
      console.error('Backup restore failed:', err);
    } finally {
      setActionInProgress(null);
    }
  };

  const handleDelete = async (backupPath: string) => {
    setActionInProgress(backupPath);
    try {
      await window.sensequality.deleteBackup(backupPath);
      await loadBackups();
    } catch (err) {
      console.error('Backup delete failed:', err);
    } finally {
      setActionInProgress(null);
    }
  };

  const handleExportDiagnostics = async () => {
    setActionInProgress('exporting');
    try {
      const result = await window.sensequality.exportDiagnostics();
      if (result.success) {
        addLogEntry({
          type: 'success',
          message: `Diagnostics exported: ${result.path}`,
          timestamp: Date.now(),
          section: 'Diagnostics',
        });
      } else {
        addLogEntry({
          type: 'error',
          message: `Diagnostics export failed: ${result.error || 'Unknown error'}`,
          timestamp: Date.now(),
          section: 'Diagnostics',
        });
      }
    } catch (err) {
      addLogEntry({
        type: 'error',
        message: `Diagnostics export failed: ${String(err)}`,
        timestamp: Date.now(),
        section: 'Diagnostics',
      });
    } finally {
      setActionInProgress(null);
    }
  };

  return (
    <div className="p-5 space-y-5 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold text-sq-text">Restore Points</h1>
          <p className="text-[11px] text-sq-text-muted mt-0.5">
            Create and restore from system restore points to protect your system.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleExportDiagnostics}
            disabled={actionInProgress !== null}
            className="px-3 py-2 rounded-lg text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover text-xs font-medium transition-colors disabled:opacity-50"
          >
            {actionInProgress === 'exporting' ? 'Exporting...' : 'Export Diagnostics'}
          </button>
          <button
            onClick={handleCreate}
            disabled={actionInProgress !== null}
            className="px-4 py-2 rounded-lg bg-sq-accent hover:bg-sq-accent-hover text-white text-xs font-semibold transition-colors disabled:opacity-50 flex items-center gap-1.5"
          >
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            {actionInProgress === 'creating' ? 'Creating...' : 'Create'}
          </button>
        </div>
      </div>

      {/* Two-column: info card + create section */}
      <div className="grid grid-cols-3 gap-4">
        {/* Info card */}
        <div className="col-span-2 sq-glass rounded-xl p-5">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-lg bg-sq-accent/15 flex items-center justify-center text-sq-accent">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
              </svg>
            </div>
            <h3 className="text-sm font-bold text-sq-text">Automatic Protection</h3>
          </div>
          <p className="text-[11px] text-sq-text-muted leading-relaxed">
            Registry and config backups are created automatically before each optimization run.
            You can also create manual snapshots at any time.
          </p>
        </div>

        {/* Why create card */}
        <div className="sq-glass rounded-xl p-5">
          <h4 className="text-xs font-semibold text-sq-text mb-3">Why Create a Restore Point?</h4>
          <div className="space-y-2">
            {[
              'Prevent changes from affecting system performance',
              'Protect configuration in case of power outage',
              'Undo all changes made by the software at any time',
            ].map((reason) => (
              <div key={reason} className="flex items-start gap-2">
                <svg className="w-4 h-4 text-sq-success shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                <span className="text-[10px] text-sq-text-muted leading-relaxed">{reason}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Catalog header */}
      <div className="flex items-center gap-2">
        <svg className="w-4 h-4 text-sq-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z" />
        </svg>
        <span className="text-xs font-semibold text-sq-text-muted tracking-wide">CATALOG</span>
      </div>

      {/* Backup cards */}
      {loading ? (
        <div className="grid grid-cols-4 gap-3">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="sq-glass rounded-xl overflow-hidden animate-pulse">
              <div className="h-2 bg-sq-border" />
              <div className="p-4 space-y-2">
                <div className="h-4 bg-sq-border rounded w-3/4" />
                <div className="h-3 bg-sq-border/60 rounded w-1/2" />
              </div>
            </div>
          ))}
        </div>
      ) : backups.length === 0 ? (
        <div className="sq-glass rounded-xl p-10 text-center">
          <svg className="w-10 h-10 text-sq-text-dim mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m6 4.125l2.25 2.25m0 0l2.25 2.25M12 13.875l2.25-2.25M12 13.875l-2.25 2.25M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
          </svg>
          <p className="text-sm text-sq-text-muted">No backups found.</p>
          <p className="text-[11px] text-sq-text-dim mt-1">Backups are created automatically when you run optimizations.</p>
        </div>
      ) : (
        <div className="grid grid-cols-4 gap-3">
          {backups.map((backup, index) => {
            const color = CARD_COLORS[index % CARD_COLORS.length];
            return (
              <div key={backup.path} className="sq-glass sq-card-hover rounded-xl overflow-hidden flex flex-col">
                {/* Color top bar */}
                <div className="h-1.5 shrink-0" style={{ background: color }} />

                <div className="p-3.5 flex flex-col gap-2 flex-1">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <Badge variant="info">{backup.files.length} files</Badge>
                  </div>

                  <h4 className="text-xs font-semibold text-sq-text leading-tight">{backup.name}</h4>

                  <div className="flex flex-wrap gap-1">
                    {backup.files.slice(0, 3).map(f => (
                      <span key={f} className="text-[9px] px-1.5 py-0.5 bg-sq-bg/60 rounded text-sq-text-dim font-mono truncate max-w-[100px]">{f}</span>
                    ))}
                    {backup.files.length > 3 && (
                      <span className="text-[9px] text-sq-text-dim">+{backup.files.length - 3}</span>
                    )}
                  </div>

                  <div className="mt-auto pt-2 flex items-center justify-between">
                    <span className="text-[10px] text-sq-text-dim">{backup.date}</span>
                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => handleRestore(backup.path)}
                        disabled={actionInProgress !== null}
                        className="px-2 py-1 rounded-md text-[10px] font-semibold text-sq-accent border border-sq-accent/40 hover:bg-sq-accent/10 transition-colors disabled:opacity-50"
                      >
                        Restore
                      </button>
                      <button
                        onClick={() => handleDelete(backup.path)}
                        disabled={actionInProgress !== null}
                        className="px-2 py-1 rounded-md text-[10px] font-semibold text-sq-danger/70 hover:text-sq-danger hover:bg-sq-danger/10 transition-colors disabled:opacity-50"
                      >
                        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
