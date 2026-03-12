import { useEffect, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import ConfirmModal from '../ui/ConfirmModal';
import LogViewer from '../ui/LogViewer';
import Spinner from '../ui/Spinner';
import StatusTile from '../ui/StatusTile';
import TabButton from '../ui/TabButton';

type OsTab = 'debloat' | 'undo';

interface ManifestData {
  exists: boolean;
  timestamp?: string;
  servicesChanged?: number;
  appxRemoved?: number;
  tasksDisabled?: number;
  capabilitiesRemoved?: number;
}

const OPTIMIZATIONS = [
  'Disable 34 unnecessary services (telemetry, sync, compatibility)',
  'Remove 30 bloatware apps (Cortana, Teams, Clipchamp, Bing)',
  'Disable 14 telemetry scheduled tasks',
  'Remove 8 unused capabilities (IE, Fax, WordPad, WMP)',
  'NTFS and filesystem optimizations',
  'Defer feature updates 365 days (security updates continue)',
  '25+ privacy and performance registry tweaks',
];

const SAFETY_ITEMS = [
  'Full system backup created before any changes',
  'One-click undo available after debloat',
  'Anti-cheat safe: Secure Boot, TPM, Defender untouched',
  'Reboot required after completion',
];

const MANIFEST_STATS: { key: keyof ManifestData; label: string }[] = [
  { key: 'servicesChanged', label: 'Services changed' },
  { key: 'appxRemoved', label: 'Apps removed' },
  { key: 'tasksDisabled', label: 'Tasks disabled' },
  { key: 'capabilitiesRemoved', label: 'Capabilities removed' },
];

export default function OSOptimizerPage() {
  const userConfig = useAppStore((s) => s.userConfig);
  const isRunning = useAppStore((s) => s.isRunning);
  const setIsRunning = useAppStore((s) => s.setIsRunning);
  const progressLog = useAppStore((s) => s.progressLog);
  const clearLog = useAppStore((s) => s.clearLog);

  const [activeTab, setActiveTab] = useState<OsTab>('debloat');
  const [manifest, setManifest] = useState<ManifestData | null>(null);
  const [manifestLoading, setManifestLoading] = useState(true);
  const [showConfirm, setShowConfirm] = useState(false);
  const [showUndoConfirm, setShowUndoConfirm] = useState(false);
  const [expertOpen, setExpertOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [exportStatus, setExportStatus] = useState<'idle' | 'exporting' | 'success' | 'error'>('idle');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const result = await window.sensequality.checkDebloatManifest();
        if (!cancelled) setManifest(result);
      } catch (err) {
        console.error('Failed to check debloat manifest:', err);
        if (!cancelled) setManifest({ exists: false });
      } finally {
        if (!cancelled) setManifestLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const refreshManifest = async () => {
    try {
      const result = await window.sensequality.checkDebloatManifest();
      setManifest(result);
    } catch (err) {
      console.error('Failed to refresh debloat manifest:', err);
      // Don't update state -- keep current data rather than showing stale/wrong info
    }
  };

  const runScript = async (scriptId: string, label: string) => {
    if (isRunning) return;
    setError(null);
    setIsRunning(true);
    clearLog();
    try {
      await window.sensequality.runSelected([scriptId], userConfig);
      await refreshManifest();
    } catch (err) {
      console.error(`${label} failed:`, err);
      setError(`${label} failed: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsRunning(false);
    }
  };

  const handleDebloat = async () => {
    setShowConfirm(false);
    await runScript('win-deep-debloat', 'Debloat run');
  };

  const handleUndo = async () => {
    setShowUndoConfirm(false);
    await runScript('win-undo-debloat', 'Undo run');
  };

  const handleExportPlaybook = async () => {
    setExportStatus('exporting');
    try {
      const result = await window.sensequality.exportPlaybook();
      if (result.success) {
        setExportStatus('success');
        setTimeout(() => setExportStatus('idle'), 3000);
      } else {
        setExportStatus('error');
        console.error('Export failed:', result.error);
        setTimeout(() => setExportStatus('idle'), 5000);
      }
    } catch (err) {
      setExportStatus('error');
      console.error('Export failed:', err);
      setTimeout(() => setExportStatus('idle'), 5000);
    }
  };

  const manifestTimestamp = manifest?.timestamp
    ? new Date(manifest.timestamp).toLocaleDateString('en-US', {
        month: 'short', day: 'numeric', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
      })
    : null;

  function getManifestValue(): string {
    if (manifestLoading) return 'Checking...';
    if (manifest?.exists) return 'Active';
    return 'Clean (no prior debloat)';
  }

  function getManifestStatus(): 'good' | 'warning' | 'unknown' {
    if (manifestLoading) return 'unknown';
    return manifest?.exists ? 'warning' : 'good';
  }

  return (
    <div className="h-full overflow-y-auto px-6 py-5 space-y-4">
      {/* Header */}
      <div>
        <h1 className="text-sm font-bold text-sq-text tracking-wide">OS Optimizer</h1>
        <p className="text-[11px] text-sq-text-muted mt-0.5">
          Make Windows ultra-lightweight for competitive gaming
        </p>
      </div>

      {/* Status Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-2.5">
        <StatusTile label="System" value="Ready" status="good" />
        <StatusTile label="Manifest" value={getManifestValue()} status={getManifestStatus()} />
        <StatusTile label="Admin" value="Elevated" status="good" />
        <StatusTile label="Duration" value="2-5 min" status="neutral" />
      </div>

      {/* Tab Bar */}
      <div className="flex items-center gap-2">
        <TabButton
          active={activeTab === 'debloat'}
          onClick={() => setActiveTab('debloat')}
          icon={
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
            </svg>
          }
          label="Debloat"
          badge="DEEP CLEAN"
        />
        <TabButton
          active={activeTab === 'undo'}
          onClick={() => setActiveTab('undo')}
          icon={
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3" />
            </svg>
          }
          label="Undo"
          badge="RESTORE"
        />
      </div>

      {/* Tab Content */}
      {activeTab === 'debloat' && (
        <div className="space-y-4 sq-fade-up">
          {/* What Gets Optimized */}
          <div className="space-y-2">
            <span className="text-[10px] font-bold text-sq-text-dim uppercase tracking-wider">What Gets Optimized</span>
            <div className="space-y-1.5">
              {OPTIMIZATIONS.map((text, i) => (
                <div key={i} className="flex items-center gap-2 text-[12px] text-sq-text-muted">
                  <svg className="w-3.5 h-3.5 text-sq-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                  {text}
                </div>
              ))}
            </div>
          </div>

          {/* Safety Box */}
          <div className="rounded-lg border border-sq-success/20 bg-sq-success/5 p-3 space-y-1.5">
            <p className="text-[11px] font-bold text-sq-success">Safety Guarantees</p>
            <ul className="text-[11px] text-sq-text-muted space-y-1">
              {SAFETY_ITEMS.map((text, i) => (
                <li key={i} className="flex items-start gap-2">
                  <span className="text-sq-success mt-0.5 shrink-0">&#10003;</span>
                  <span>{text}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Action Button */}
          {manifest?.exists && !isRunning ? (
            <div className="space-y-2">
              <button
                disabled
                className="w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.1em] transition-all border uppercase bg-sq-border border-sq-border text-sq-text-dim cursor-not-allowed"
              >
                ALREADY APPLIED
              </button>
              <p className="text-[10px] text-sq-text-dim text-center">
                Go to the Undo tab to revert, or re-run below to refresh optimizations
              </p>
              <button
                onClick={() => setShowConfirm(true)}
                className="w-full py-2.5 rounded-xl font-bold text-xs tracking-[0.1em] transition-all border uppercase bg-sq-surface/60 border-sq-border text-sq-text-muted hover:text-sq-text hover:border-sq-text-dim cursor-pointer"
              >
                RE-RUN LIGHTWEIGHT MODE
              </button>
            </div>
          ) : (
            <button
              onClick={() => !isRunning && setShowConfirm(true)}
              disabled={isRunning}
              className={`
                w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.1em] transition-all border uppercase
                ${isRunning
                  ? 'bg-sq-accent/50 border-sq-accent/40 text-white/70 cursor-wait'
                  : 'bg-gradient-to-r from-sq-accent to-sq-accent-dim border-sq-accent/60 hover:brightness-110 text-white sq-pulse-glow cursor-pointer active:scale-[0.98]'
                }
              `}
            >
              {isRunning ? (
                <span className="flex items-center justify-center gap-2">
                  <Spinner />
                  APPLYING...
                </span>
              ) : (
                'APPLY LIGHTWEIGHT MODE'
              )}
            </button>
          )}

          {/* Error Display */}
          {error && (
            <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2">
              <svg className="w-4 h-4 text-red-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
              </svg>
              <p className="text-xs text-red-400">{error}</p>
            </div>
          )}

          {/* Log Output */}
          {progressLog.length > 0 && (
            <LogViewer entries={progressLog} maxHeight="200px" />
          )}
        </div>
      )}

      {activeTab === 'undo' && (
        <div className="sq-fade-up">
          {!manifest?.exists ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <svg className="w-10 h-10 text-sq-text-dim mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <p className="text-sq-text-muted text-sm">No debloat to undo</p>
              <p className="text-sq-text-dim text-xs mt-1">Run Lightweight Mode first, then come back here to revert if needed.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {/* Manifest Info */}
              <div className="sq-glass border border-sq-border rounded-xl p-4 space-y-2">
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-2 h-2 rounded-full bg-sq-warning" style={{ boxShadow: '0 0 6px var(--color-sq-warning)' }} />
                  <span className="text-[11px] font-bold text-sq-warning uppercase tracking-wider">Active Debloat</span>
                </div>
                {manifestTimestamp && (
                  <ManifestRow label="Applied on" value={manifestTimestamp} />
                )}
                {MANIFEST_STATS.map(({ key, label }) => {
                  const value = manifest[key] as string | number | undefined;
                  if (value == null) return null;
                  return <ManifestRow key={key} label={label} value={value} />;
                })}
              </div>

              {/* Undo Button */}
              <button
                onClick={() => !isRunning && setShowUndoConfirm(true)}
                disabled={isRunning}
                className={`
                  w-full py-3.5 rounded-xl font-bold text-sm tracking-[0.1em] transition-all border uppercase
                  ${isRunning
                    ? 'bg-sq-warning/30 border-sq-warning/30 text-white/70 cursor-wait'
                    : 'bg-sq-warning/20 border-sq-warning/40 text-sq-warning hover:bg-sq-warning/30 hover:border-sq-warning/60 cursor-pointer active:scale-[0.98]'
                  }
                `}
              >
                {isRunning ? (
                  <span className="flex items-center justify-center gap-2">
                    <Spinner />
                    RESTORING...
                  </span>
                ) : (
                  'UNDO ALL CHANGES'
                )}
              </button>

              {/* Error Display */}
              {error && (
                <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2">
                  <svg className="w-4 h-4 text-red-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
                  </svg>
                  <p className="text-xs text-red-400">{error}</p>
                </div>
              )}

              {/* Log Output (undo tab) */}
              {progressLog.length > 0 && (
                <LogViewer entries={progressLog} maxHeight="200px" />
              )}
            </div>
          )}
        </div>
      )}

      {/* Expert Section */}
      <div className="border-t border-sq-border/50 pt-4">
        <button
          onClick={() => setExpertOpen(!expertOpen)}
          className="flex items-center gap-2 text-sm text-sq-text-muted hover:text-sq-text transition-colors cursor-pointer"
        >
          <svg
            className={`w-3.5 h-3.5 transition-transform ${expertOpen ? 'rotate-90' : ''}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
          </svg>
          AME Wizard Playbook (Advanced Users)
        </button>
        {expertOpen && (
          <div className="mt-3 rounded-lg border border-sq-border/50 p-4 space-y-3 sq-fade-up">
            <p className="text-xs text-sq-text-muted leading-relaxed">
              For even deeper optimization, power users can run the TUNEDPC playbook with AME Wizard.
              It goes beyond what the in-app optimizer can do by using system-level access to permanently
              remove unused Windows components from the component store, freeing additional disk space and
              reducing background overhead.
            </p>
            <div className="flex items-center gap-3 text-xs">
              <p className="text-sq-text-dim">1. Export the playbook</p>
              <svg className="w-3 h-3 text-sq-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" /></svg>
              <p className="text-sq-text-dim">2. Download AME Wizard</p>
              <svg className="w-3 h-3 text-sq-text-dim" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" /></svg>
              <p className="text-sq-text-dim">3. Drag the .apbx file into AME Wizard</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={handleExportPlaybook}
                disabled={exportStatus === 'exporting'}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                  exportStatus === 'success'
                    ? 'bg-sq-success/10 text-sq-success border-sq-success/20'
                    : exportStatus === 'error'
                      ? 'bg-red-500/10 text-red-400 border-red-500/20'
                      : exportStatus === 'exporting'
                        ? 'bg-sq-accent/10 text-sq-accent/60 border-sq-accent/20 cursor-wait'
                        : 'bg-sq-accent/10 text-sq-accent border-sq-accent/20 hover:bg-sq-accent/20 cursor-pointer'
                }`}
              >
                <span className="flex items-center gap-1.5">
                  {exportStatus === 'exporting' ? (
                    <>
                      <Spinner />
                      Exporting...
                    </>
                  ) : exportStatus === 'success' ? (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>
                      Exported!
                    </>
                  ) : exportStatus === 'error' ? (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>
                      Export Failed
                    </>
                  ) : (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" /></svg>
                      Export Playbook to Downloads
                    </>
                  )}
                </span>
              </button>
              <button
                onClick={() => window.sensequality.openExternal('https://ameliorated.io')}
                className="px-3 py-1.5 rounded-lg text-xs font-medium text-sq-text-muted border border-sq-border/50 hover:border-sq-border hover:text-sq-text-secondary transition-colors"
              >
                <span className="flex items-center gap-1.5">
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                  Download AME Wizard
                </span>
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Debloat Confirmation Modal */}
      {showConfirm && (
        <ConfirmModal
          title="Apply Lightweight OS Mode?"
          description="This will make significant changes to Windows. A full system backup will be created automatically."
          bullets={[
            '34 services will be disabled',
            '30 bloatware apps will be removed',
            '14 scheduled tasks will be disabled',
            'Requires reboot after completion',
          ]}
          confirmLabel="Yes, Optimize"
          confirmClassName="bg-sq-accent hover:bg-sq-accent-hover"
          onConfirm={handleDebloat}
          onCancel={() => setShowConfirm(false)}
        />
      )}

      {/* Undo Confirmation Modal */}
      {showUndoConfirm && (
        <ConfirmModal
          title="Undo Lightweight Mode?"
          description="This will restore Windows to its pre-debloat state. All disabled services and tasks will be re-enabled."
          bullets={[
            'Some removed apps may need manual reinstall from the Microsoft Store',
            'Requires reboot after completion',
          ]}
          confirmLabel="Yes, Restore"
          confirmClassName="bg-sq-warning hover:brightness-110"
          onConfirm={handleUndo}
          onCancel={() => setShowUndoConfirm(false)}
        />
      )}
    </div>
  );
}

/* --- Subcomponents --- */

function ManifestRow({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="flex items-center justify-between text-[12px]">
      <span className="text-sq-text-muted">{label}</span>
      <span className="text-sq-text font-medium">{value}</span>
    </div>
  );
}

