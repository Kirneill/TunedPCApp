import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

interface UpgradeModalProps {
  onClose: () => void;
}

export default function UpgradeModal({ onClose }: UpgradeModalProps) {
  const { authUser } = useAppStore();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleUpgrade = async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await window.sensequality.billingCheckout();
      if (result.error) {
        setError(result.error);
        setLoading(false);
        return;
      }

      if (result.url) {
        // Checkout opened in browser — show waiting state
        // User will return to app after payment
        // Poll for access after a short delay
        setTimeout(async () => {
          const access = await window.sensequality.billingRefreshAccess();
          if (access.allowed) {
            const sub = await window.sensequality.billingGetSubscription();
            useAppStore.getState().setSubscription(sub);
          }
          onClose();
        }, 3000);
      } else {
        // Product attached directly (card on file) — refresh immediately
        const sub = await window.sensequality.billingGetSubscription();
        useAppStore.getState().setSubscription(sub);
        onClose();
      }
    } catch (err) {
      console.error('[upgrade] Checkout failed:', err);
      setError('Something went wrong. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
      <div
        className="relative w-full max-w-md mx-4 rounded-2xl sq-panel border sq-subtle-divider overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="relative px-6 pt-6 pb-4">
          <button
            onClick={onClose}
            className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-lg text-sq-text-dim hover:text-sq-text hover:bg-white/[0.05] transition-colors cursor-pointer"
          >
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.5">
              <line x1="1" y1="1" x2="9" y2="9" /><line x1="9" y1="1" x2="1" y2="9" />
            </svg>
          </button>

          <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-sq-accent/10 border border-sq-accent/20 mb-3">
            <span className="text-[10px] font-bold text-sq-accent tracking-[0.15em] uppercase">TunedPC Pro</span>
          </div>
          <h2 className="text-lg font-bold text-sq-text">Unlock BIOS Optimization</h2>
          <p className="text-sm text-sq-text-muted mt-1">
            Overclock your BIOS for maximum competitive FPS performance.
          </p>
        </div>

        {/* Features */}
        <div className="px-6 pb-4">
          <div className="space-y-2.5">
            {[
              'Interactive BIOS optimization checklist',
              'Automated BIOS settings via SCEWIN',
              'Per-CPU profiles (Ryzen, Intel)',
              'Auto-backup and restore safety net',
              'RAM safety rules and XMP validation',
            ].map((feature) => (
              <div key={feature} className="flex items-start gap-2.5">
                <svg className="w-4 h-4 text-sq-accent mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                <span className="text-sm text-sq-text-muted">{feature}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Price */}
        <div className="px-6 pb-4">
          <div className="flex items-baseline gap-1.5 justify-center py-3 rounded-xl bg-sq-bg/60 border border-white/[0.04]">
            <span className="text-3xl font-bold text-sq-text">$10</span>
            <span className="text-sm text-sq-text-dim">/ month</span>
          </div>
        </div>

        {/* CTA */}
        <div className="px-6 pb-6">
          <button
            onClick={handleUpgrade}
            disabled={loading}
            className="w-full py-3 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <span className="flex items-center justify-center gap-2">
                <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Opening checkout...
              </span>
            ) : (
              'Upgrade to Pro - $10/mo'
            )}
          </button>
          <p className="text-[10px] text-sq-text-dim text-center mt-2">
            Secure checkout powered by Stripe. Cancel anytime.
          </p>

          {error && (
            <p className="text-xs text-sq-danger text-center mt-2">{error}</p>
          )}
        </div>

        {/* Signed in as */}
        {authUser?.email && (
          <div className="px-6 pb-4 text-center">
            <p className="text-[10px] text-sq-text-dim">
              Billing for {authUser.email}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
