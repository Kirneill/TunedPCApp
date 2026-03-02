import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

export default function MaxDevicesScreen() {
  const { machines, setShowMaxDevices, clearAuthState } = useAppStore();
  const [deactivating, setDeactivating] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleDeactivate = async (machineId: string) => {
    setDeactivating(machineId);
    setError(null);
    try {
      const result = await window.sensequality.deactivateMachine(machineId);

      if (result.success) {
        // Now try to register current machine
        const sysInfo = useAppStore.getState().systemInfo;
        if (sysInfo) {
          const adapters = sysInfo.gpuAdapters || [];
          const primaryAdapter = adapters.find((a) => a.id === sysInfo.primaryGpuId) || adapters[0];
          const regResult = await window.sensequality.registerMachine({
            machine_name: sysInfo.cpu,
            gpu: sysInfo.gpu,
            cpu: sysInfo.cpu,
            ram_gb: sysInfo.ramGB,
            os_build: sysInfo.osBuild,
            gpu_driver: sysInfo.gpuDriver || undefined,
            gpu_vram_gb: primaryAdapter ? Math.round(primaryAdapter.vramGB) : undefined,
          });

          if (regResult.success) {
            setShowMaxDevices(false);
          } else {
            setError('Deactivated device but failed to register this one. Please restart the app.');
          }
        }
      } else {
        setError(result.error || 'Failed to deactivate device.');
      }
    } catch (err) {
      setError('An unexpected error occurred. Please restart the app and try again.');
      console.error('[MaxDevicesScreen] handleDeactivate failed:', err);
    } finally {
      setDeactivating(null);
    }
  };

  const handleSignOut = async () => {
    await window.sensequality.signOut();
    clearAuthState();
  };

  const formatDate = (dateStr: string) => {
    try {
      return new Date(dateStr).toLocaleDateString(undefined, {
        year: 'numeric', month: 'short', day: 'numeric',
      });
    } catch {
      return dateStr;
    }
  };

  return (
    <div className="flex flex-col h-full bg-sq-bg">
      {/* Window controls */}
      <div className="drag-region flex items-center justify-end h-11 px-4 shrink-0">
        <div className="flex items-center no-drag">
          <button
            onClick={() => window.sensequality.minimizeWindow()}
            className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
          >
            <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
          </button>
          <button
            onClick={() => window.sensequality.closeWindow()}
            className="w-10 h-11 flex items-center justify-center text-sq-text-muted hover:text-white hover:bg-sq-danger transition-colors"
          >
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex items-center justify-center">
        <div className="w-full max-w-lg mx-4">
          <div className="bg-sq-surface border border-sq-border rounded-2xl p-6 shadow-2xl">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 rounded-full bg-sq-warning/20 flex items-center justify-center">
                <svg className="w-5 h-5 text-sq-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-2.694-.833-3.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <div>
                <h2 className="text-base font-bold text-sq-text">Maximum Devices Reached</h2>
                <p className="text-xs text-sq-text-muted">Your account is limited to 2 active machines.</p>
              </div>
            </div>

            <p className="text-xs text-sq-text-muted mb-4">
              Deactivate one of your registered machines to use SENSEQUALITY on this device.
            </p>

            <div className="space-y-3 mb-5">
              {machines.map((machine) => (
                <div key={machine.id} className="bg-sq-bg rounded-xl p-4 border border-sq-border">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <svg className="w-4 h-4 text-sq-text-muted shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z" />
                        </svg>
                        <span className="text-sm font-medium text-sq-text truncate">{machine.gpu || 'Unknown GPU'}</span>
                      </div>
                      <div className="text-[11px] text-sq-text-muted space-y-0.5 pl-6">
                        <p className="truncate">{machine.cpu || 'Unknown CPU'}</p>
                        <p>{machine.ram_gb ? `${machine.ram_gb} GB RAM` : ''}{machine.os_build ? ` · Build ${machine.os_build}` : ''}</p>
                        <p className="text-sq-text-dim">Last seen: {formatDate(machine.last_seen_at)}</p>
                      </div>
                    </div>
                    <button
                      onClick={() => handleDeactivate(machine.machine_id)}
                      disabled={deactivating !== null}
                      className="px-3 py-1.5 rounded-lg text-xs font-medium text-sq-danger border border-sq-danger/30 hover:bg-sq-danger/10 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed shrink-0"
                    >
                      {deactivating === machine.machine_id ? (
                        <span className="flex items-center gap-1.5">
                          <svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                          </svg>
                          Removing...
                        </span>
                      ) : 'Deactivate'}
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {error && (
              <div className="text-xs text-sq-danger bg-sq-danger/10 border border-sq-danger/20 rounded-lg px-3 py-2 mb-4">
                {error}
              </div>
            )}

            <button
              onClick={handleSignOut}
              className="w-full py-2.5 rounded-xl text-sm font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors cursor-pointer"
            >
              Sign Out
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
