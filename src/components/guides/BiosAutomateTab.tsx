import { useState, useEffect, useCallback, useMemo } from 'react';
import { useAppStore } from '../../store/appStore';
import { getProfilesForCpu } from '../../data/bios-profiles';
import { checkRamSafety, filterProfileSettings } from '../../data/ram-safety';
import type { ProfileChange } from '../../types';

export default function BiosAutomateTab() {
  const biosDetection = useAppStore((s) => s.biosDetection);
  const systemInfo = useAppStore((s) => s.systemInfo);
  const scewinStatus = useAppStore((s) => s.scewinStatus);
  const setScewinStatus = useAppStore((s) => s.setScewinStatus);
  const biosBackups = useAppStore((s) => s.biosBackups);
  const setBiosBackups = useAppStore((s) => s.setBiosBackups);
  const selectedBiosProfile = useAppStore((s) => s.selectedBiosProfile);
  const setSelectedBiosProfile = useAppStore((s) => s.setSelectedBiosProfile);
  const profilePreview = useAppStore((s) => s.profilePreview);
  const setProfilePreview = useAppStore((s) => s.setProfilePreview);
  const profilePreviewLoading = useAppStore((s) => s.profilePreviewLoading);
  const setProfilePreviewLoading = useAppStore((s) => s.setProfilePreviewLoading);
  const biosApplying = useAppStore((s) => s.biosApplying);
  const setBiosApplying = useAppStore((s) => s.setBiosApplying);
  const biosApplyResult = useAppStore((s) => s.biosApplyResult);
  const setBiosApplyResult = useAppStore((s) => s.setBiosApplyResult);
  const scewinProvisionProgress = useAppStore((s) => s.scewinProvisionProgress);

  const cpuName = biosDetection?.cpuName ?? systemInfo?.cpu;
  const isAmiBios = biosDetection?.isAmiBios;
  const profiles = useMemo(() => getProfilesForCpu(cpuName), [cpuName]);
  const selectedProfile = profiles.find((p) => p.id === selectedBiosProfile);
  const ramSafety = useMemo(() => checkRamSafety(biosDetection), [biosDetection]);

  // Static settings list (from profile definition, filtered by RAM safety)
  const safeSettings = useMemo(
    () => selectedProfile ? filterProfileSettings(selectedProfile.settings, ramSafety) : [],
    [selectedProfile, ramSafety],
  );

  const [error, setError] = useState<string | null>(null);
  const [confirmApply, setConfirmApply] = useState(false);
  const [provisioning, setProvisioning] = useState(false);
  const [backupsOpen, setBackupsOpen] = useState(false);
  const [detailsOpen, setDetailsOpen] = useState(false);

  // Auto-select first matching profile
  useEffect(() => {
    if (profiles.length > 0 && !selectedBiosProfile) {
      setSelectedBiosProfile(profiles[0].id);
    }
  }, [profiles, selectedBiosProfile]);

  // Check SCEWIN provision on mount
  useEffect(() => {
    window.sensequality.getBiosProvisionStatus().then(setScewinStatus).catch(() => {});
    window.sensequality.listBiosBackups().then(setBiosBackups).catch(() => {});
  }, []);

  // Auto-preview when profile changes
  useEffect(() => {
    if (!selectedBiosProfile || !scewinStatus?.ready) return;
    setProfilePreviewLoading(true);
    setError(null);
    setBiosApplyResult(null);
    window.sensequality.previewBiosProfile(selectedBiosProfile)
      .then((result) => {
        if (result.success && result.changes) {
          setProfilePreview(result.changes);
        } else {
          setError(result.error || 'Preview failed');
        }
      })
      .catch((err) => setError(err instanceof Error ? err.message : String(err)))
      .finally(() => setProfilePreviewLoading(false));
  }, [selectedBiosProfile]);

  const handleProvision = useCallback(async () => {
    setError(null);
    setProvisioning(true);
    try {
      const result = await window.sensequality.provisionScewin();
      if (result.success) {
        window.sensequality.getBiosProvisionStatus().then(setScewinStatus).catch(() => {});
      } else {
        setError(result.error || 'Setup failed');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setProvisioning(false);
    }
  }, []);

  const handleApply = useCallback(async () => {
    if (!selectedBiosProfile) return;
    setConfirmApply(false);
    setBiosApplying(true);
    setError(null);
    try {
      const result = await window.sensequality.applyBiosProfile(selectedBiosProfile);
      setBiosApplyResult(result);
      if (!result.success) setError(result.error || 'Apply failed');
      window.sensequality.listBiosBackups().then(setBiosBackups).catch(() => {});
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBiosApplying(false);
    }
  }, [selectedBiosProfile]);

  const handleBackup = useCallback(async () => {
    setError(null);
    try {
      const result = await window.sensequality.backupBios();
      if (result.success) {
        window.sensequality.listBiosBackups().then(setBiosBackups).catch(() => {});
      } else {
        setError(result.error || 'Backup failed');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  const handleRestore = useCallback(async (filename: string) => {
    if (!confirm(`Restore your motherboard to these saved settings? Your current settings will be replaced.`)) return;
    setError(null);
    try {
      const result = await window.sensequality.restoreBiosBackup(filename);
      if (!result.success) setError(result.error || 'Restore failed');
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  // Not AMI BIOS
  if (isAmiBios === false) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center sq-fade-up">
        <svg className="w-10 h-10 text-sq-text-dim mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
        </svg>
        <p className="text-sm font-semibold text-sq-text">Automatic Optimization Not Available</p>
        <p className="text-xs text-sq-text-muted mt-1 max-w-xs">
          Your motherboard doesn't support automatic optimization. No worries -- you can get the same results by following the step-by-step Manual Guide.
        </p>
      </div>
    );
  }

  const isProvisionActive = provisioning || (scewinProvisionProgress && !['idle', 'complete', 'error'].includes(scewinProvisionProgress.step));
  const isProvisionComplete = scewinProvisionProgress?.step === 'complete';
  const isProvisionError = scewinProvisionProgress?.step === 'error';

  const changesCount = profilePreview?.filter((c) => c.applied).length ?? 0;
  const alreadyCorrectCount = profilePreview?.filter((c) => c.found && !c.applied).length ?? 0;

  return (
    <div className="space-y-4 sq-fade-up">
      {/* ─── One-Time Setup (if not ready) ─── */}
      {scewinStatus && !scewinStatus.ready && !isProvisionComplete && (
        <div className="sq-panel rounded-lg px-4 py-4 border border-sq-accent/20 space-y-3">
          <div>
            <p className="text-xs text-sq-text font-bold mb-0.5">One-Time Setup Required</p>
            <p className="text-[10px] text-sq-text-muted">
              We need to download a small tool (~300 MB, one-time) that lets us optimize your motherboard settings automatically. This takes about 2 minutes.
            </p>
          </div>

          {isProvisionActive && (
            <div className="space-y-1.5">
              <div className="h-1.5 bg-sq-bg rounded-full overflow-hidden">
                <div
                  className={`h-full bg-sq-accent rounded-full transition-all duration-300 ${!scewinProvisionProgress ? 'animate-pulse' : ''}`}
                  style={{ width: `${scewinProvisionProgress?.progress ?? 2}%` }}
                />
              </div>
              <div className="flex items-center justify-between">
                <span className="text-[10px] text-sq-text-muted">{scewinProvisionProgress?.message ?? 'Starting...'}</span>
                <span className="text-[10px] font-bold text-sq-accent">{scewinProvisionProgress?.progress ?? 0}%</span>
              </div>
            </div>
          )}

          {isProvisionError && scewinProvisionProgress?.error && (
            <p className="text-[10px] text-sq-danger">{scewinProvisionProgress.error}</p>
          )}

          <div>
            {isProvisionActive ? (
              <button
                onClick={() => window.sensequality.cancelScewinProvision().catch(() => {})}
                className="px-3 py-1.5 rounded-lg text-[11px] font-bold text-sq-text-muted hover:text-sq-text bg-sq-bg hover:bg-sq-panel transition-all cursor-pointer"
              >
                CANCEL
              </button>
            ) : (
              <button
                onClick={handleProvision}
                className="px-4 py-2 rounded-lg text-[11px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer flex items-center gap-2"
              >
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                {isProvisionError ? 'RETRY SETUP' : 'DOWNLOAD & SET UP'}
              </button>
            )}
          </div>
        </div>
      )}

      {/* Setup complete banner */}
      {isProvisionComplete && (
        <div className="sq-panel rounded-lg px-4 py-2.5 border border-sq-success/30 bg-sq-success/5 flex items-center gap-2">
          <svg className="w-4 h-4 text-sq-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
          </svg>
          <span className="text-xs text-sq-success font-bold">Setup complete -- ready to optimize</span>
        </div>
      )}

      {/* ─── No profiles for this CPU ─── */}
      {(scewinStatus?.ready || isProvisionComplete) && profiles.length === 0 && (
        <div className="sq-panel rounded-lg px-4 py-4 text-center">
          <p className="text-xs text-sq-text font-semibold mb-1">We're still adding support for your processor</p>
          <p className="text-[10px] text-sq-text-muted max-w-sm mx-auto">
            {cpuName ? `Automatic optimization for "${cpuName}" is coming soon.` : 'CPU not detected.'}{' '}
            Switch to the <span className="font-semibold text-sq-text">Manual Guide</span> tab -- enabling RAM Speed (the first setting) alone can give you a 10-20% FPS boost.
          </p>
        </div>
      )}

      {/* ═══ Profile ready + apply flow ═══ */}
      {(scewinStatus?.ready || isProvisionComplete) && profiles.length > 0 && (
        <div className="space-y-3">
          {/* ─── Auto-detected hero ─── */}
          {profiles.length === 1 && selectedProfile && (
            <div className="sq-panel rounded-xl px-4 py-4 border border-sq-accent/15">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 rounded-xl bg-sq-accent/10 flex items-center justify-center shrink-0">
                  <svg className="w-5 h-5 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />
                  </svg>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-sq-text">{selectedProfile.label}</p>
                  <p className="text-[10px] text-sq-text-muted mt-0.5">{selectedProfile.description}</p>
                  <p className="text-[10px] text-sq-text-dim mt-1">
                    Detected: <span className="font-semibold text-sq-text">{cpuName}</span>
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Multiple profiles (future) */}
          {profiles.length > 1 && (
            <div className="flex gap-2 flex-wrap">
              {profiles.map((profile) => (
                <button
                  key={profile.id}
                  onClick={() => setSelectedBiosProfile(profile.id)}
                  className={`flex-1 min-w-0 px-3 py-2.5 rounded-lg text-left transition-all cursor-pointer border ${
                    selectedBiosProfile === profile.id
                      ? 'border-sq-accent bg-sq-accent/10'
                      : 'border-sq-text-dim/10 bg-sq-panel hover:border-sq-text-dim/30'
                  }`}
                >
                  <div className={`text-xs font-bold truncate ${selectedBiosProfile === profile.id ? 'text-sq-accent' : 'text-sq-text'}`}>
                    {profile.label}
                  </div>
                  <div className="text-[10px] text-sq-text-dim mt-0.5 truncate">{profile.description}</div>
                </button>
              ))}
            </div>
          )}

          {/* Critical note */}
          {selectedProfile?.criticalNote && (
            <div className="flex items-start gap-2 bg-sq-warning/10 border border-sq-warning/20 rounded-lg px-3 py-2">
              <svg className="w-3.5 h-3.5 text-sq-warning shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <span className="text-[10px] text-sq-warning">{selectedProfile.criticalNote}</span>
            </div>
          )}

          {/* ─── RAM Safety Warnings ─── */}
          {ramSafety.warnings.map((warning) => (
            <div
              key={warning.id}
              className={`rounded-xl px-4 py-3.5 border ${
                warning.severity === 'danger'
                  ? 'bg-sq-danger/10 border-sq-danger/30'
                  : 'bg-sq-warning/10 border-sq-warning/20'
              }`}
            >
              <div className="flex items-start gap-2.5">
                <svg className={`w-4 h-4 shrink-0 mt-0.5 ${warning.severity === 'danger' ? 'text-sq-danger' : 'text-sq-warning'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
                <div>
                  <p className={`text-[11px] font-bold ${warning.severity === 'danger' ? 'text-sq-danger' : 'text-sq-warning'}`}>
                    {warning.title}
                  </p>
                  <p className={`text-[10px] mt-0.5 leading-relaxed ${warning.severity === 'danger' ? 'text-sq-danger/80' : 'text-sq-warning/80'}`}>
                    {warning.message}
                  </p>
                </div>
              </div>
              {warning.steps && warning.steps.length > 0 && (
                <ol className="mt-2.5 ml-7 space-y-1.5">
                  {warning.steps.map((step, i) => (
                    <li key={i} className="flex items-start gap-2 text-[10px] leading-relaxed">
                      <span className={`shrink-0 w-4 h-4 rounded-full flex items-center justify-center text-[9px] font-bold ${
                        warning.severity === 'danger'
                          ? 'bg-sq-danger/20 text-sq-danger'
                          : 'bg-sq-warning/20 text-sq-warning'
                      }`}>
                        {i + 1}
                      </span>
                      <span className="text-sq-text-muted">{step}</span>
                    </li>
                  ))}
                </ol>
              )}
            </div>
          ))}

          {/* Preview loading */}
          {profilePreviewLoading && (
            <div className="sq-panel rounded-lg h-24 sq-shimmer" />
          )}

          {/* ─── Preview summary + apply ─── */}
          {!profilePreviewLoading && (profilePreview && profilePreview.length > 0 ? (
            /* Live NVRAM preview available */
            <div className="sq-panel rounded-lg overflow-hidden">
              {/* Summary bar */}
              <div className="px-4 py-3 flex items-center justify-between">
                <div>
                  <span className="text-sm font-bold text-sq-text">
                    {changesCount} optimization{changesCount !== 1 ? 's' : ''} ready
                  </span>
                  {alreadyCorrectCount > 0 && (
                    <span className="text-[10px] text-sq-success ml-2">
                      {alreadyCorrectCount} already correct
                    </span>
                  )}
                </div>
                <button
                  onClick={() => setDetailsOpen(!detailsOpen)}
                  className="text-[10px] font-bold text-sq-text-muted hover:text-sq-text transition-colors cursor-pointer flex items-center gap-1"
                >
                  {detailsOpen ? 'HIDE' : 'SHOW'} DETAILS
                  <svg className={`w-3 h-3 transition-transform ${detailsOpen ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>

              {/* Expandable details table */}
              {detailsOpen && (
                <div className="divide-y divide-sq-text-dim/5 max-h-64 overflow-y-auto border-t border-sq-text-dim/10">
                  {profilePreview.map((change, i) => (
                    <ChangeRow key={i} change={change} />
                  ))}
                </div>
              )}
            </div>
          ) : selectedProfile && safeSettings.length > 0 && (
            /* Fallback: static settings list from profile definition */
            <div className="sq-panel rounded-lg overflow-hidden">
              <div className="px-4 py-3 flex items-center justify-between">
                <span className="text-sm font-bold text-sq-text">
                  {safeSettings.length} optimization{safeSettings.length !== 1 ? 's' : ''} will be applied
                </span>
                <button
                  onClick={() => setDetailsOpen(!detailsOpen)}
                  className="text-[10px] font-bold text-sq-text-muted hover:text-sq-text transition-colors cursor-pointer flex items-center gap-1"
                >
                  {detailsOpen ? 'HIDE' : 'SHOW'} DETAILS
                  <svg className={`w-3 h-3 transition-transform ${detailsOpen ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>

              {detailsOpen && (
                <div className="divide-y divide-sq-text-dim/5 max-h-64 overflow-y-auto border-t border-sq-text-dim/10">
                  {safeSettings.map((setting, i) => (
                    <div key={i} className="px-4 py-1.5 flex items-center gap-3">
                      <div className={`w-1.5 h-1.5 rounded-full shrink-0 ${
                        setting.riskLevel === 'medium' || setting.riskLevel === 'high' ? 'bg-sq-warning' : 'bg-sq-accent'
                      }`} />
                      <span className="flex-1 min-w-0 text-[11px] font-medium text-sq-text truncate">{setting.name}</span>
                      <div className="text-[10px] font-mono text-right shrink-0">
                        <span className="text-sq-accent font-bold">{setting.targetValue}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}

          {/* ─── Apply button (shown for both live preview and static fallback) ─── */}
          {!profilePreviewLoading && selectedProfile && !confirmApply && !biosApplyResult?.success && (
            <div className="flex flex-col items-center gap-2 py-2">
              <button
                onClick={() => setConfirmApply(true)}
                disabled={biosApplying}
                className="w-full max-w-sm px-8 py-4 rounded-xl text-[15px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2.5"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
                {biosApplying ? 'OPTIMIZING...' : 'OPTIMIZE NOW'}
              </button>
              <span className="text-[10px] text-sq-text-dim">Your current settings are backed up automatically.</span>
            </div>
          )}

          {/* Confirmation */}
          {confirmApply && (
            <div className="sq-panel rounded-lg px-4 py-3 border border-sq-accent/20 bg-sq-accent/5">
              <p className="text-[11px] text-sq-text font-bold mb-1">Confirm Optimization</p>
              <p className="text-[10px] text-sq-text-muted mb-2.5">
                We'll save a backup of your current settings first, then apply the optimizations. You'll need to restart your PC for the changes to take effect.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={handleApply}
                  className="px-4 py-2 rounded-lg text-[11px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer flex items-center gap-1.5"
                >
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                  YES, OPTIMIZE
                </button>
                <button
                  onClick={() => setConfirmApply(false)}
                  className="px-3 py-1.5 rounded-lg text-[10px] font-bold text-sq-text-muted hover:text-sq-text transition-all cursor-pointer"
                >
                  CANCEL
                </button>
              </div>
            </div>
          )}

          {/* ─── Apply result ─── */}
          {biosApplyResult && (
            <div className={`rounded-lg px-4 py-4 border ${biosApplyResult.success ? 'border-sq-success/30 bg-sq-success/5' : 'border-sq-danger/30 bg-sq-danger/5'}`}>
              {biosApplyResult.success ? (
                <div className="space-y-3">
                  <div className="flex items-center gap-2">
                    <svg className="w-5 h-5 text-sq-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <p className="text-sm font-bold text-sq-success">Optimizations saved!</p>
                  </div>
                  <p className="text-xs text-sq-text-muted">
                    Restart your PC now for the changes to take effect. Your previous settings have been backed up and can be restored anytime.
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => window.sensequality.restartComputer()}
                      className="px-4 py-2 rounded-lg text-[11px] font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer flex items-center gap-1.5"
                    >
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
                      </svg>
                      RESTART NOW
                    </button>
                    <button
                      onClick={() => setBiosApplyResult(null)}
                      className="px-3 py-1.5 rounded-lg text-[10px] font-bold text-sq-text-muted hover:text-sq-text transition-all cursor-pointer"
                    >
                      I'LL DO IT LATER
                    </button>
                  </div>
                </div>
              ) : (
                <>
                  <p className="text-xs font-bold text-sq-danger">Optimization failed</p>
                  {biosApplyResult.error && <p className="text-[10px] text-sq-danger mt-0.5">{biosApplyResult.error}</p>}
                </>
              )}
            </div>
          )}
        </div>
      )}

      {/* ─── Error ─── */}
      {error && (
        <div className="flex items-center gap-2 bg-sq-danger/10 border border-sq-danger/20 rounded-lg px-3 py-2">
          <svg className="w-3.5 h-3.5 text-sq-danger shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-[11px] text-sq-danger">{error}</span>
        </div>
      )}

      {/* ─── Safety Backups ─── */}
      <div>
        <button
          onClick={() => setBackupsOpen(!backupsOpen)}
          className="flex items-center gap-2 text-[11px] font-bold text-sq-text-muted hover:text-sq-text transition-colors cursor-pointer px-1 py-1"
        >
          <svg className={`w-3 h-3 transition-transform ${backupsOpen ? 'rotate-90' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
          Safety Backups ({biosBackups.length})
          <button
            onClick={(e) => { e.stopPropagation(); handleBackup(); }}
            className="text-[10px] font-bold text-sq-accent hover:text-sq-accent-hover transition-colors ml-2"
          >
            + SAVE CURRENT SETTINGS
          </button>
        </button>

        {backupsOpen && biosBackups.length > 0 && (
          <div className="sq-panel rounded-lg overflow-hidden mt-1 ml-1">
            <div className="divide-y divide-sq-text-dim/5">
              {biosBackups.slice(0, 5).map((backup) => (
                <div key={backup.filename} className="px-3 py-2 flex items-center justify-between">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-[10px] font-mono text-sq-text truncate">{backup.filename}</span>
                    <span className="text-[9px] text-sq-text-dim shrink-0">{(backup.sizeBytes / 1024).toFixed(0)} KB</span>
                  </div>
                  <button
                    onClick={() => handleRestore(backup.filename)}
                    className="text-[9px] font-bold text-sq-accent hover:text-sq-accent-hover transition-colors cursor-pointer shrink-0 ml-2"
                  >
                    RESTORE
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {backupsOpen && biosBackups.length === 0 && (
          <p className="text-[10px] text-sq-text-dim ml-6 mt-1">No backups yet. One is created automatically when you optimize.</p>
        )}
      </div>
    </div>
  );
}

function ChangeRow({ change }: { change: ProfileChange }) {
  return (
    <div className={`px-4 py-1.5 flex items-center gap-3 ${!change.found ? 'opacity-35' : ''}`}>
      <div className={`w-1.5 h-1.5 rounded-full shrink-0 ${
        !change.found ? 'bg-sq-text-dim' : change.applied ? 'bg-sq-accent' : 'bg-sq-success'
      }`} />
      <span className="flex-1 min-w-0 text-[11px] font-medium text-sq-text truncate">{change.name}</span>
      <div className="text-[10px] font-mono text-right shrink-0">
        {change.found ? (
          change.applied ? (
            <>
              <span className="text-sq-text-dim">{change.currentValue}</span>
              <span className="text-sq-text-dim mx-1">&rarr;</span>
              <span className="text-sq-accent font-bold">{change.targetValue}</span>
            </>
          ) : (
            <span className="text-sq-success">{change.currentValue}</span>
          )
        ) : (
          <span className="text-sq-text-dim italic">not found</span>
        )}
      </div>
    </div>
  );
}
