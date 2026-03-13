import { useState, useEffect } from 'react';
import { useAppStore } from '../../store/appStore';
import UpgradeModal from './UpgradeModal';

interface ProGateProps {
  feature: string;
  children: React.ReactNode;
}

/**
 * Wraps a page component and shows an upgrade screen if the user is on the free plan.
 * Checks entitlement via the Autumn API (cached for 5 minutes).
 */
export default function ProGate({ feature, children }: ProGateProps) {
  const isPro = useAppStore((s) => s.isPro);
  const [showModal, setShowModal] = useState(false);
  const [checking, setChecking] = useState(true);
  const [allowed, setAllowed] = useState(false);

  useEffect(() => {
    // If store already knows we're Pro, skip the API check
    if (isPro()) {
      setAllowed(true);
      setChecking(false);
      return;
    }

    // Otherwise check with Autumn
    window.sensequality.billingCheckAccess().then((result) => {
      setAllowed(result.allowed);
      if (result.allowed) {
        // Sync store
        useAppStore.getState().setSubscription({ plan: 'pro', status: 'active' });
      }
      setChecking(false);
    }).catch(() => {
      setChecking(false);
    });
  }, [isPro]);

  if (checking) {
    return (
      <div className="h-full flex items-center justify-center">
        <svg className="w-6 h-6 animate-spin text-sq-accent" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      </div>
    );
  }

  if (allowed) {
    return <>{children}</>;
  }

  return (
    <div className="h-full flex flex-col items-center justify-center p-8 relative">
      {/* Upgrade prompt */}
      <div className="relative z-10 text-center max-w-md">
        {/* Lock icon */}
        <div className="w-16 h-16 mx-auto mb-5 rounded-2xl bg-sq-accent/10 border border-sq-accent/20 flex items-center justify-center">
          <svg className="w-7 h-7 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
          </svg>
        </div>

        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-sq-accent/10 border border-sq-accent/20 mb-4">
          <span className="text-[10px] font-bold text-sq-accent tracking-[0.15em] uppercase">Pro Feature</span>
        </div>

        <h2 className="text-xl font-bold text-sq-text mb-2">
          BIOS Optimization
        </h2>
        <p className="text-sm text-sq-text-muted mb-6 leading-relaxed">
          Unlock the step-by-step BIOS guide and guided tuning tools built to boost FPS without the usual BIOS guesswork.
        </p>

        <button
          onClick={() => setShowModal(true)}
          className="px-8 py-3 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer shadow-lg shadow-sq-accent/20"
        >
          Upgrade to Pro - $20/mo
        </button>

        <p className="text-[10px] text-sq-text-dim mt-3">
          Cancel anytime. BIOS settings auto-restore on cancellation.
        </p>
      </div>

      {showModal && <UpgradeModal onClose={() => setShowModal(false)} />}
    </div>
  );
}
