import { useEffect, useMemo, useState } from 'react';
import { useAppStore } from '../../store/appStore';
import { biosCategories, getSettingsForPlatform, groupByCategory } from '../../data/bios-settings';
import type { BiosDetectionResult, BiosSetting } from '../../types';
import BiosSettingRow from './BiosSettingRow';
import BiosAutomateTab from './BiosAutomateTab';

type DetectionState = 'optimized' | 'needs-attention' | 'unknown';

export function deriveDetectionStatus(setting: BiosSetting, detection: BiosDetectionResult | null): DetectionState {
  if (!detection || !setting.detectable) return 'unknown';
  switch (setting.id) {
    case 'xmp-expo':
      return detection.xmpLikelyEnabled == null ? 'unknown' : detection.xmpLikelyEnabled ? 'optimized' : 'needs-attention';
    case 'vbs-hvci':
      if (detection.vbsRunning == null && detection.memoryIntegrityEnabled == null && detection.memoryIntegrityRegistry == null) return 'unknown';
      return (detection.vbsRunning || detection.memoryIntegrityEnabled || detection.memoryIntegrityRegistry) ? 'needs-attention' : 'optimized';
    case 'secure-boot-tpm':
      return detection.secureBootEnabled == null ? 'unknown' : 'optimized';
    case 'rebar-sam':
      return detection.rebarDetected == null ? 'unknown' : detection.rebarDetected ? 'optimized' : 'needs-attention';
    case 'virtualization':
      return detection.virtualizationEnabled == null ? 'unknown' : 'optimized';
    default:
      return 'unknown';
  }
}

type BiosTab = 'optimize' | 'guide';

export default function BiosGuidePage() {
  const biosDetection = useAppStore((s) => s.biosDetection);
  const biosScanLoading = useAppStore((s) => s.biosScanLoading);
  const biosHasAutoScanned = useAppStore((s) => s.biosHasAutoScanned);
  const setBiosHasAutoScanned = useAppStore((s) => s.setBiosHasAutoScanned);
  const setBiosDetection = useAppStore((s) => s.setBiosDetection);
  const setBiosScanLoading = useAppStore((s) => s.setBiosScanLoading);
  const setBiosScanError = useAppStore((s) => s.setBiosScanError);
  const biosScanError = useAppStore((s) => s.biosScanError);
  const systemInfo = useAppStore((s) => s.systemInfo);

  const [activeTab, setActiveTab] = useState<BiosTab>('optimize');

  useEffect(() => {
    const state = useAppStore.getState();
    if (state.biosHasAutoScanned || state.biosDetection || state.biosScanLoading) return;
    state.setBiosHasAutoScanned(true);
    handleScan();
  }, []);

  const handleScan = async () => {
    setBiosScanLoading(true);
    setBiosScanError(null);
    try {
      const result = await window.sensequality.scanBiosState();
      if (result.success && result.data) {
        setBiosDetection(result.data);
      } else {
        setBiosScanError(result.error || 'Scan failed');
      }
    } catch (err) {
      setBiosScanError(err instanceof Error ? err.message : String(err));
    } finally {
      setBiosScanLoading(false);
    }
  };

  const isAmd = systemInfo?.cpu?.toLowerCase().includes('amd') ?? false;
  const cpuVendor: 'amd' | 'intel' = isAmd ? 'amd' : 'intel';
  const filteredSettings = useMemo(() => getSettingsForPlatform(cpuVendor), [cpuVendor]);
  const grouped = useMemo(() => groupByCategory(filteredSettings), [filteredSettings]);
  const sortedCategories = useMemo(
    () => biosCategories
      .filter((c) => c.platform === 'both' || c.platform === cpuVendor)
      .sort((a, b) => a.order - b.order),
    [cpuVendor],
  );

  const detectedVendor = biosDetection?.motherboardVendor ?? undefined;

  const attentionCount = useMemo(() => {
    if (!biosDetection) return 0;
    return filteredSettings.filter((s) => deriveDetectionStatus(s, biosDetection) === 'needs-attention').length;
  }, [filteredSettings, biosDetection]);

  const optimizedCount = useMemo(() => {
    if (!biosDetection) return 0;
    return filteredSettings.filter((s) => deriveDetectionStatus(s, biosDetection) === 'optimized').length;
  }, [filteredSettings, biosDetection]);

  return (
    <div className="h-full overflow-y-auto px-6 py-5 space-y-4">
      {/* ─── Header ─── */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-sm font-bold text-sq-text tracking-wide">BIOS Optimization</h1>
          {biosDetection && (
            <p className="text-[11px] text-sq-text-muted mt-0.5">
              {[biosDetection.cpuName, biosDetection.motherboardVendor, biosDetection.motherboardModel].filter(Boolean).join(' \u00B7 ')}
            </p>
          )}
        </div>
        <button
          onClick={handleScan}
          disabled={biosScanLoading}
          className="flex items-center gap-1.5 px-4 py-2 rounded-full text-xs font-bold text-sq-text-muted hover:text-white bg-sq-bg/60 hover:bg-sq-accent/20 border border-sq-border hover:border-sq-accent/50 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed tracking-wide"
        >
          {biosScanLoading ? (
            <svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          ) : (
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          )}
          {biosScanLoading ? 'SCANNING' : 'RESCAN'}
        </button>
      </div>

      {/* ─── Scan error ─── */}
      {biosScanError && (
        <div className="flex items-center gap-2 bg-sq-danger/10 border border-sq-danger/20 rounded-lg px-3 py-2">
          <svg className="w-3.5 h-3.5 text-sq-danger shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-[11px] text-sq-danger">{biosScanError}</span>
        </div>
      )}

      {/* ─── Loading skeleton ─── */}
      {biosScanLoading && !biosDetection && (
        <div className="space-y-4 sq-fade-up">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-2.5">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="sq-panel rounded-lg h-16 sq-shimmer" />
            ))}
          </div>
          <div className="sq-panel rounded-lg h-10 sq-shimmer" />
          {[1, 2, 3].map((i) => (
            <div key={i} className="sq-panel rounded-lg h-12 sq-shimmer" />
          ))}
        </div>
      )}

      {/* ─── Not scanned fallback ─── */}
      {!biosDetection && !biosScanLoading && !biosScanError && (
        <div className="flex flex-col items-center justify-center py-16 text-center sq-fade-up">
          <svg className="w-10 h-10 text-sq-text-dim mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          <p className="text-sm text-sq-text-muted">Click RESCAN to detect your BIOS settings</p>
        </div>
      )}

      {/* ═══ Scanned content ═══ */}
      {biosDetection && (
        <div className="space-y-4 sq-fade-up">
          {/* ─── Status tiles ─── */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-2.5">
            <StatusTile
              label="RAM Speed"
              value={biosDetection.xmpLikelyEnabled == null ? 'Unknown' : biosDetection.xmpLikelyEnabled ? `Full Speed (${biosDetection.ramCurrentSpeed ?? '?'} MHz)` : `Slow (${biosDetection.ramCurrentSpeed}/${biosDetection.ramRatedSpeed} MHz)`}
              status={biosDetection.xmpLikelyEnabled == null ? 'unknown' : biosDetection.xmpLikelyEnabled ? 'good' : 'warning'}
            />
            <StatusTile
              label="Security Layer"
              value={biosDetection.memoryIntegrityEnabled == null ? 'Unknown' : biosDetection.memoryIntegrityEnabled ? 'On (costs FPS)' : 'Off (best FPS)'}
              status={biosDetection.memoryIntegrityEnabled == null ? 'unknown' : biosDetection.memoryIntegrityEnabled ? 'warning' : 'good'}
            />
            <StatusTile
              label="Anti-Cheat"
              value={biosDetection.secureBootEnabled == null ? 'Unknown' : biosDetection.secureBootEnabled ? 'Ready' : 'Not Ready'}
              status={biosDetection.secureBootEnabled == null ? 'unknown' : 'good'}
            />
            <StatusTile
              label="GPU Memory"
              value={biosDetection.rebarDetected == null ? 'Unknown' : biosDetection.rebarDetected ? `Full Access (${biosDetection.bar1TotalMB ?? '?'} MB)` : 'Limited'}
              status={biosDetection.rebarDetected == null ? 'unknown' : biosDetection.rebarDetected ? 'good' : 'warning'}
            />
          </div>

          {/* ─── Status summary banner ─── */}
          {attentionCount > 0 ? (
            <div className="flex items-center gap-2 bg-sq-warning/5 border border-sq-warning/20 rounded-lg px-3 py-2">
              <div className="w-1.5 h-1.5 rounded-full bg-sq-warning shrink-0" />
              <span className="text-[11px] font-bold text-sq-warning">
                {attentionCount} setting{attentionCount > 1 ? 's' : ''} need attention
              </span>
              {optimizedCount > 0 && (
                <span className="text-[10px] text-sq-text-dim">{'\u00B7'} {optimizedCount} verified</span>
              )}
            </div>
          ) : (
            <div className="flex items-center gap-2 bg-sq-success/5 border border-sq-success/20 rounded-lg px-3 py-2">
              <svg className="w-3.5 h-3.5 text-sq-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span className="text-[11px] font-bold text-sq-success">All detected settings look good</span>
              {optimizedCount > 0 && (
                <span className="text-[10px] text-sq-text-dim">{'\u00B7'} {optimizedCount} verified</span>
              )}
            </div>
          )}

          {/* ═══ Tab Bar ═══ */}
          <div className="flex items-center gap-2">
            <TabButton
              active={activeTab === 'optimize'}
              onClick={() => setActiveTab('optimize')}
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
              }
              label="Auto Optimize"
              badge="1-CLICK"
            />
            <TabButton
              active={activeTab === 'guide'}
              onClick={() => setActiveTab('guide')}
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
                </svg>
              }
              label="Manual Guide"
              badge={`${filteredSettings.length} SETTINGS`}
            />
          </div>

          {/* ═══ Tab Content ═══ */}
          {activeTab === 'optimize' && (
            <div className="sq-fade-up">
              <BiosAutomateTab />
            </div>
          )}

          {activeTab === 'guide' && (
            <div className="space-y-5 sq-fade-up">
              {/* How to enter BIOS */}
              <div className="sq-glass border border-sq-accent/15 rounded-xl px-4 py-3 space-y-2">
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-[12px] font-bold text-sq-text">How to enter BIOS</span>
                </div>
                <p className="text-[11px] text-sq-text-muted leading-relaxed">
                  Restart your PC and repeatedly press <span className="font-bold text-sq-text">DEL</span> or <span className="font-bold text-sq-text">F2</span> as soon as the screen turns on. If that doesn't work, try <span className="font-bold text-sq-text">F10</span>, <span className="font-bold text-sq-text">F12</span>, or <span className="font-bold text-sq-text">ESC</span>. The correct key usually flashes on screen for a split second during startup.
                </p>
                <p className="text-[11px] text-sq-text-dim">
                  Your detected motherboard: <span className="font-semibold text-sq-accent">{biosDetection?.motherboardVendor ?? 'Unknown'} {biosDetection?.motherboardModel ?? ''}</span>
                  {biosDetection?.motherboardVendor && (
                    <span> — most {biosDetection.motherboardVendor} boards use <span className="font-bold text-sq-text">{biosDetection.motherboardVendor.toLowerCase().includes('msi') ? 'DEL' : biosDetection.motherboardVendor.toLowerCase().includes('gigabyte') ? 'DEL' : biosDetection.motherboardVendor.toLowerCase().includes('asrock') ? 'F2' : 'DEL or F2'}</span></span>
                  )}
                </p>
              </div>

              {sortedCategories.map((category) => {
                const settings = grouped[category.id] || [];
                if (settings.length === 0) return null;

                const sorted = [...settings].sort((a, b) => {
                  const priority = { 'needs-attention': 0, 'optimized': 1, 'unknown': 2 } as const;
                  const aState = deriveDetectionStatus(a, biosDetection);
                  const bState = deriveDetectionStatus(b, biosDetection);
                  return (priority[aState] ?? 2) - (priority[bState] ?? 2);
                });

                return (
                  <div key={category.id}>
                    <div className="flex items-center gap-3 mb-1.5">
                      <span className="text-[10px] font-bold text-sq-text-dim uppercase tracking-wider whitespace-nowrap">{category.title}</span>
                      <div className="flex-1 h-px bg-sq-border/50" />
                    </div>
                    <div className="space-y-1">
                      {sorted.map((setting) => (
                        <BiosSettingRow
                          key={setting.id}
                          setting={setting}
                          detectedVendor={detectedVendor}
                          detectionState={deriveDetectionStatus(setting, biosDetection)}
                        />
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

/* ─── Subcomponents ─── */

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

function StatusTile({ label, value, status }: { label: string; value: string; status: 'good' | 'warning' | 'unknown' }) {
  const borderColor = status === 'good' ? 'border-sq-success/30' : status === 'warning' ? 'border-sq-warning/30' : 'border-sq-border/40';
  const dotColor = status === 'good' ? 'bg-sq-success' : status === 'warning' ? 'bg-sq-warning' : 'bg-sq-text-dim';
  const glowBg = status === 'good' ? 'bg-sq-success/5' : status === 'warning' ? 'bg-sq-warning/5' : '';
  return (
    <div className={`sq-glass border ${borderColor} rounded-xl px-3.5 py-3 ${glowBg}`}>
      <div className="flex items-center gap-1.5 mb-1">
        <div className={`w-2 h-2 rounded-full ${dotColor} ${status !== 'unknown' ? 'shadow-sm' : ''}`} style={status === 'good' ? { boxShadow: '0 0 6px var(--color-sq-success)' } : status === 'warning' ? { boxShadow: '0 0 6px var(--color-sq-warning)' } : {}} />
        <span className="text-[10px] font-bold text-sq-text-muted uppercase tracking-wider">{label}</span>
      </div>
      <span className="text-[12px] font-semibold text-sq-text">{value}</span>
    </div>
  );
}
