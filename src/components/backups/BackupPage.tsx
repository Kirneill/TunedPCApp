import { useEffect, useState } from 'react';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import type { BackupInfo } from '../../types';
import { useAppStore } from '../../store/appStore';

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
    const result = await window.sensequality.createBackup();
    if (result.success) {
      await loadBackups();
    }
    setActionInProgress(null);
  };

  const handleRestore = async (backupPath: string) => {
    setActionInProgress(backupPath);
    await window.sensequality.restoreBackup(backupPath);
    setActionInProgress(null);
  };

  const handleDelete = async (backupPath: string) => {
    setActionInProgress(backupPath);
    await window.sensequality.deleteBackup(backupPath);
    await loadBackups();
    setActionInProgress(null);
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
    <div className="space-y-5 max-w-4xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-sq-text">Backup Management</h1>
          <p className="text-xs text-sq-text-muted mt-1">
            Registry and config backups are created automatically before each optimization run.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleExportDiagnostics}
            disabled={actionInProgress !== null}
            className="px-4 py-2 rounded-lg text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover text-sm font-medium transition-colors disabled:opacity-50"
          >
            {actionInProgress === 'exporting' ? 'Exporting...' : 'Export Diagnostics'}
          </button>
          <button
            onClick={handleCreate}
            disabled={actionInProgress !== null}
            className="px-4 py-2 rounded-lg bg-sq-accent hover:bg-sq-accent-hover text-white text-sm font-medium transition-colors disabled:opacity-50"
          >
            {actionInProgress === 'creating' ? 'Creating...' : 'Create Backup'}
          </button>
        </div>
      </div>

      {loading ? (
        <Card>
          <div className="animate-pulse space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-12 bg-sq-border rounded" />
            ))}
          </div>
        </Card>
      ) : backups.length === 0 ? (
        <Card>
          <div className="text-center py-8">
            <p className="text-sm text-sq-text-muted">No backups found.</p>
            <p className="text-xs text-sq-text-dim mt-1">Backups are created automatically when you run optimizations.</p>
          </div>
        </Card>
      ) : (
        <div className="space-y-3">
          {backups.map((backup) => (
            <Card key={backup.path}>
              <div className="flex items-center justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-sq-text">{backup.date}</span>
                    <Badge variant="info">{backup.files.length} files</Badge>
                  </div>
                  <p className="text-[11px] text-sq-text-dim mt-0.5 font-mono">{backup.name}</p>
                  <div className="flex flex-wrap gap-1 mt-1.5">
                    {backup.files.slice(0, 5).map(f => (
                      <span key={f} className="text-[10px] px-1.5 py-0.5 bg-sq-bg rounded text-sq-text-dim">{f}</span>
                    ))}
                    {backup.files.length > 5 && (
                      <span className="text-[10px] text-sq-text-dim">+{backup.files.length - 5} more</span>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0 ml-4">
                  <button
                    onClick={() => handleRestore(backup.path)}
                    disabled={actionInProgress !== null}
                    className="px-3 py-1.5 rounded-lg text-xs font-medium text-sq-warning border border-sq-warning/30 hover:bg-sq-warning/10 transition-colors disabled:opacity-50"
                  >
                    Restore
                  </button>
                  <button
                    onClick={() => handleDelete(backup.path)}
                    disabled={actionInProgress !== null}
                    className="px-3 py-1.5 rounded-lg text-xs font-medium text-sq-danger border border-sq-danger/30 hover:bg-sq-danger/10 transition-colors disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
