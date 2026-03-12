import { useEffect, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import LogViewer from '../ui/LogViewer';

type OsTab = 'debloat' | 'undo';

interface ManifestData {
  exists: boolean;
  timestamp?: string;
  servicesChanged?: number;
  appxRemoved?: number;
  tasksDisabled?: number;
  capabilitiesRemoved?: number;
}

const optimizations = [
  { text: 'Disable 34 unnecessary services (telemetry, sync, compatibility)' },
  { text: 'Remove 30 bloatware apps (Cortana, Teams, Clipchamp, Bing)' },
  { text: 'Disable 14 telemetry scheduled tasks' },
  { text: 'Remove 8 unused capabilities (IE, Fax, WordPad, WMP)' },
  { text: 'NTFS and filesystem optimizations' },
  { text: 'Defer feature updates 365 days (security updates continue)' },
  { text: '25+ privacy and performance registry tweaks' },
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

  // Check manifest on mount
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const result = await window.sensequality.checkDebloatManifest();
        if (!cancelled) {
          setManifest(result);
        }
      } catch (err) {
        console.error('Failed to check debloat manifest:', err);
        if (!cancelled) {
          setManifest({ exists: false });
        }
      } finally {
        if (!cancelled) setManifestLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  // Re-check manifest after a run completes
  const refreshManifest = async () => {
    try {
      const result = await window.sensequality.checkDebloatManifest();
      setManifest(result);
    } catch {
      // ignore
    }
  };

  const handleDebloat = async () => {
    setShowConfirm(false);
    if (isRunning) return;
    setIsRunning(true);
    clearLog();
    try {
      await window.sensequality.runSelected(['win-deep-debloat'], userConfig);
      await refreshManifest();
    } catch (err) {
      console.error('Debloat run failed:', err);
    } finally {
      setIsRunning(false);
    }
  };

  const handleUndo = async () => {
    setShowUndoConfirm(false);
    if (isRunning) return;
    setIsRunning(true);
    clearLog();
    try {
      await window.sensequality.runSelected(['win-undo-debloat'], userConfig);
      await refreshManifest();
    } catch (err) {
      console.error('Undo run failed:', err);
    } finally {
      setIsRunning(false);
    }
  };

  const manifestTimestamp = manifest?.timestamp
    ? new Date(manifest.timestamp).toLocaleDateString('en-US', {
        month: 'short', day: 'numeric', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
      })
    : null;

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
        <StatusTile
          label="System"
          value="Ready"
          status="good"
        />
        <StatusTile
          label="Manifest"
          value={
            manifestLoading
              ? 'Checking...'
              : manifest?.exists
                ? 'Active'
                : 'Clean (no prior debloat)'
          }
          status={manifestLoading ? 'unknown' : manifest?.exists ? 'warning' : 'good'}
        />
        <StatusTile
          label="Admin"
          value="Elevated"
          status="good"
        />
        <StatusTile
          label="Duration"
          value="2-5 min"
          status="neutral"
        />
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
              {optimizations.map((item, i) => (
                <div key={i} className="flex items-center gap-2 text-[12px] text-sq-text-muted">
                  <svg className="w-3.5 h-3.5 text-sq-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                  {item.text}
                </div>
              ))}
            </div>
          </div>

          {/* Safety Box */}
          <div className="rounded-lg border border-sq-success/20 bg-sq-success/5 p-3 space-y-1.5">
            <p className="text-[11px] font-bold text-sq-success">Safety Guarantees</p>
            <ul className="text-[11px] text-sq-text-muted space-y-1">
              <li className="flex items-start gap-2">
                <span className="text-sq-success mt-0.5 shrink-0">&#10003;</span>
                <span>Full system backup created before any changes</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-sq-success mt-0.5 shrink-0">&#10003;</span>
                <span>One-click undo available after debloat</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-sq-success mt-0.5 shrink-0">&#10003;</span>
                <span>Anti-cheat safe: Secure Boot, TPM, Defender untouched</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-sq-success mt-0.5 shrink-0">&#10003;</span>
                <span>Reboot required after completion</span>
              </li>
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
                  <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  APPLYING...
                </span>
              ) : (
                'APPLY LIGHTWEIGHT MODE'
              )}
            </button>
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
                  <div className="flex items-center justify-between text-[12px]">
                    <span className="text-sq-text-muted">Applied on</span>
                    <span className="text-sq-text font-medium">{manifestTimestamp}</span>
                  </div>
                )}
                {manifest.servicesChanged != null && (
                  <div className="flex items-center justify-between text-[12px]">
                    <span className="text-sq-text-muted">Services changed</span>
                    <span className="text-sq-text font-medium">{manifest.servicesChanged}</span>
                  </div>
                )}
                {manifest.appxRemoved != null && (
                  <div className="flex items-center justify-between text-[12px]">
                    <span className="text-sq-text-muted">Apps removed</span>
                    <span className="text-sq-text font-medium">{manifest.appxRemoved}</span>
                  </div>
                )}
                {manifest.tasksDisabled != null && (
                  <div className="flex items-center justify-between text-[12px]">
                    <span className="text-sq-text-muted">Tasks disabled</span>
                    <span className="text-sq-text font-medium">{manifest.tasksDisabled}</span>
                  </div>
                )}
                {manifest.capabilitiesRemoved != null && (
                  <div className="flex items-center justify-between text-[12px]">
                    <span className="text-sq-text-muted">Capabilities removed</span>
                    <span className="text-sq-text font-medium">{manifest.capabilitiesRemoved}</span>
                  </div>
                )}
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
                    <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                    </svg>
                    RESTORING...
                  </span>
                ) : (
                  'UNDO ALL CHANGES'
                )}
              </button>

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
          <div className="mt-3 rounded-lg border border-sq-border/50 p-4 space-y-2 sq-fade-up">
            <p className="text-xs text-sq-text-muted leading-relaxed">
              For even deeper optimization, power users can use the AME Wizard playbook included in this repo.
              It uses TrustedInstaller-level access to remove WinSxS components that PowerShell cannot reach.
            </p>
            <p className="text-xs text-sq-text-dim">
              Requires AME Wizard from ameliorated.io. See the playbook/Executables/README.txt for instructions.
            </p>
          </div>
        )}
      </div>

      {/* Debloat Confirmation Modal */}
      {showConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-sq-surface border border-sq-border rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-sq-text">Apply Lightweight OS Mode?</h2>
            <p className="text-sm text-sq-text-muted leading-relaxed">
              This will make significant changes to Windows. A full system backup will be created automatically.
            </p>
            <ul className="text-xs text-sq-text-muted space-y-1 list-disc list-inside">
              <li>34 services will be disabled</li>
              <li>30 bloatware apps will be removed</li>
              <li>14 scheduled tasks will be disabled</li>
              <li>Requires reboot after completion</li>
            </ul>
            <div className="flex gap-3 justify-end pt-2">
              <button
                onClick={() => setShowConfirm(false)}
                className="px-4 py-2.5 rounded-xl text-sm font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleDebloat}
                className="px-4 py-2.5 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer"
              >
                Yes, Optimize
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Undo Confirmation Modal */}
      {showUndoConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
          <div className="bg-sq-surface border border-sq-border rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-sq-text">Undo Lightweight Mode?</h2>
            <p className="text-sm text-sq-text-muted leading-relaxed">
              This will restore Windows to its pre-debloat state. All disabled services and tasks will be re-enabled.
            </p>
            <ul className="text-xs text-sq-text-muted space-y-1 list-disc list-inside">
              <li>Some removed apps may need manual reinstall from the Microsoft Store</li>
              <li>Requires reboot after completion</li>
            </ul>
            <div className="flex gap-3 justify-end pt-2">
              <button
                onClick={() => setShowUndoConfirm(false)}
                className="px-4 py-2.5 rounded-xl text-sm font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleUndo}
                className="px-4 py-2.5 rounded-xl text-sm font-bold text-white bg-sq-warning hover:brightness-110 transition-colors cursor-pointer"
              >
                Yes, Restore
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* --- Subcomponents --- */

function TabButton({ active, onClick, icon, label, badge }: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  badge?: string;
}) {
  return (
    <button
      onClick={onClick}
      data-active={active}
      className={`
        sq-card-hover flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-xl text-sm font-bold transition-all cursor-pointer
        ${active
          ? 'sq-glass text-white border-sq-accent shadow-lg shadow-sq-accent/10'
          : 'text-sq-text-muted hover:text-sq-text border border-sq-border/40 bg-sq-surface/40'
        }
      `}
    >
      <span className={`
        w-9 h-9 rounded-lg flex items-center justify-center transition-colors
        ${active ? 'bg-sq-accent/20 text-sq-accent' : 'bg-sq-border/40 text-sq-text-dim'}
      `}>
        {icon}
      </span>
      <span className="text-[14px]">{label}</span>
      {badge && (
        <span className={`text-[9px] font-bold uppercase tracking-wider px-2 py-1 rounded-md ${
          active ? 'bg-sq-accent/25 text-sq-accent border border-sq-accent/30' : 'bg-sq-bg/80 text-sq-text-dim'
        }`}>
          {badge}
        </span>
      )}
    </button>
  );
}

function StatusTile({ label, value, status }: { label: string; value: string; status: 'good' | 'warning' | 'unknown' | 'neutral' }) {
  const borderColor =
    status === 'good' ? 'border-sq-success/30'
    : status === 'warning' ? 'border-sq-warning/30'
    : status === 'neutral' ? 'border-sq-accent/20'
    : 'border-sq-border/40';
  const dotColor =
    status === 'good' ? 'bg-sq-success'
    : status === 'warning' ? 'bg-sq-warning'
    : status === 'neutral' ? 'bg-sq-accent'
    : 'bg-sq-text-dim';
  const glowBg =
    status === 'good' ? 'bg-sq-success/5'
    : status === 'warning' ? 'bg-sq-warning/5'
    : status === 'neutral' ? 'bg-sq-accent/5'
    : '';
  const dotGlow =
    status === 'good' ? { boxShadow: '0 0 6px var(--color-sq-success)' }
    : status === 'warning' ? { boxShadow: '0 0 6px var(--color-sq-warning)' }
    : status === 'neutral' ? { boxShadow: '0 0 6px var(--color-sq-accent)' }
    : {};

  return (
    <div className={`sq-glass border ${borderColor} rounded-xl px-3.5 py-3 ${glowBg}`}>
      <div className="flex items-center gap-1.5 mb-1">
        <div className={`w-2 h-2 rounded-full ${dotColor}`} style={dotGlow} />
        <span className="text-[10px] font-bold text-sq-text-muted uppercase tracking-wider">{label}</span>
      </div>
      <span className="text-[12px] font-semibold text-sq-text">{value}</span>
    </div>
  );
}
