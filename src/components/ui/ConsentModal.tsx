import { useAppStore } from '../../store/appStore';

export default function ConsentModal() {
  const { showConsentModal, setShowConsentModal, setTelemetryEnabled } = useAppStore();

  if (!showConsentModal) return null;

  const handleChoice = async (granted: boolean) => {
    await window.sensequality.setTelemetryConsent(granted);
    setTelemetryEnabled(granted);
    setShowConsentModal(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="bg-sq-surface border border-sq-border rounded-2xl p-6 max-w-md mx-4 shadow-2xl">
        <h2 className="text-lg font-bold text-sq-text mb-2">Help Improve SENSEQUALITY</h2>
        <p className="text-sm text-sq-text-muted leading-relaxed mb-4">
          Share anonymous usage data to help us build better optimizations for your hardware.
          We collect:
        </p>

        <ul className="text-xs text-sq-text-muted space-y-1.5 mb-5 pl-1">
          <li className="flex items-start gap-2">
            <span className="text-sq-success mt-0.5">&#10003;</span>
            <span>Hardware info (GPU, CPU, RAM — no serial numbers)</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-sq-success mt-0.5">&#10003;</span>
            <span>Which optimizations were applied and if they succeeded</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-sq-success mt-0.5">&#10003;</span>
            <span>App version and OS build number</span>
          </li>
        </ul>

        <ul className="text-xs text-sq-text-muted space-y-1.5 mb-6 pl-1">
          <li className="flex items-start gap-2">
            <span className="text-sq-danger mt-0.5">&#10007;</span>
            <span>No personal info, names, emails, or IP addresses</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-sq-danger mt-0.5">&#10007;</span>
            <span>No game accounts, file paths, or browsing data</span>
          </li>
        </ul>

        <p className="text-[11px] text-sq-text-dim mb-5">
          You can change this anytime in Advanced Settings.
        </p>

        <div className="flex gap-3">
          <button
            onClick={() => handleChoice(false)}
            className="flex-1 py-2.5 rounded-xl text-sm font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors cursor-pointer"
          >
            No Thanks
          </button>
          <button
            onClick={() => handleChoice(true)}
            className="flex-1 py-2.5 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer"
          >
            Yes, Help Improve
          </button>
        </div>
      </div>
    </div>
  );
}
