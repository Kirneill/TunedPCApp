import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

interface UpgradeModalProps {
  onClose: () => void;
}

export default function UpgradeModal({ onClose }: UpgradeModalProps) {
  const { authUser } = useAppStore();
  const [loading, setLoading] = useState(false);
  const [polling, setPolling] = useState(false);
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
        // Checkout opened in browser — poll for confirmation
        setPolling(true);
        for (let i = 0; i < 5; i++) {
          await new Promise((r) => setTimeout(r, 4000));
          try {
            const access = await window.sensequality.billingRefreshAccess();
            if (access.allowed) {
              const sub = await window.sensequality.billingGetSubscription();
              useAppStore.getState().setSubscription(sub);
              onClose();
              return;
            }
          } catch {
            // Keep polling
          }
        }
        // Payment likely went through but Autumn hasn't synced yet
        setError('Payment processing — tap Retry to check again.');
        setLoading(false);
        setPolling(false);
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
      setPolling(false);
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
            Get the BIOS settings that matter for smoother FPS, lower input delay, and less trial and error.
          </p>
        </div>

        {/* Features */}
        <div className="px-6 pb-4">
          <div className="space-y-2.5">
            {[
              'Step-by-step BIOS checklist for gamers',
              'Guided automatic tuning',
              'CPU-matched profiles for Ryzen and Intel',
              'Backup and restore safety net',
              'RAM safety checks before changes',
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
            <span className="text-3xl font-bold text-sq-text">$20</span>
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
                {polling ? 'Waiting for payment confirmation...' : 'Opening checkout...'}
              </span>
            ) : (
              'Upgrade to Pro - $20/mo'
            )}
          </button>
          <p className="text-[10px] text-sq-text-dim text-center mt-2">
            Secure checkout powered by Stripe. Cancel anytime.
          </p>

          {error && (
            <div className="text-center mt-2">
              <p className="text-xs text-sq-danger">{error}</p>
              {!loading && (
                <button
                  onClick={handleUpgrade}
                  className="mt-2 text-xs font-semibold text-sq-accent hover:text-sq-accent-hover transition-colors cursor-pointer"
                >
                  Retry
                </button>
              )}
            </div>
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
