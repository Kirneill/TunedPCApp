import { useState, useEffect } from 'react';
import type { Subscription } from '../../types';

export default function PastDueBanner() {
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [dismissed, setDismissed] = useState(false);
  const [opening, setOpening] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    window.sensequality.billingGetSubscription()
      .then(setSubscription)
      .catch((err: unknown) => {
        console.error('[PastDueBanner] Failed to fetch subscription:', err instanceof Error ? err.message : err);
      });
  }, []);

  if (!subscription || subscription.status !== 'past_due' || dismissed) return null;

  const handleUpdatePayment = async () => {
    setOpening(true);
    setError(null);
    try {
      const result = await window.sensequality.billingOpenPortal();
      if (!result.success) {
        setError(result.error || 'Could not open payment page. Please try again.');
      }
    } catch (err) {
      console.error('[PastDueBanner] Failed to open billing portal:', err instanceof Error ? err.message : err);
      setError('Could not open payment page. Please try again.');
    } finally {
      setOpening(false);
    }
  };

  return (
    <div className="flex items-center justify-between px-4 py-2.5 bg-sq-warning/15 border-b border-sq-warning/30 shrink-0 gap-3">
      <div className="flex items-center gap-3">
        <div className="w-5 h-5 rounded-full bg-sq-warning/20 flex items-center justify-center shrink-0">
          <svg className="w-3 h-3 text-sq-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
          </svg>
        </div>
        <span className="text-xs text-sq-text">
          <span className="font-bold">Your payment method needs updating.</span>
          {' '}Your Pro subscription is past due. Update your payment to keep access.
          {error && <span className="text-sq-danger ml-1">{error}</span>}
        </span>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={handleUpdatePayment}
          disabled={opening}
          className="px-3 py-1 rounded-lg text-[11px] font-bold text-black bg-sq-warning hover:brightness-110 transition-all cursor-pointer disabled:opacity-70 disabled:cursor-wait"
        >
          {opening ? 'OPENING...' : 'UPDATE PAYMENT'}
        </button>
        <button
          onClick={() => setDismissed(true)}
          className="p-1 rounded text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors cursor-pointer"
          title="Dismiss"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
}
