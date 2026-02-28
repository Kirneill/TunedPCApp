import { useState, useEffect } from 'react';
import { useAppStore } from '../../store/appStore';

export default function BiosGuidePage() {
  const authUser = useAppStore((s) => s.authUser);
  const [hasJoined, setHasJoined] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checkingStatus, setCheckingStatus] = useState(true);

  useEffect(() => {
    const userId = authUser?.id || '';
    const cacheKey = `sensequality-waitlist-bios:${userId}`;

    try {
      if (localStorage.getItem(cacheKey) === 'true') {
        setHasJoined(true);
        setCheckingStatus(false);
      }
    } catch {}

    window.sensequality.hasJoinedWaitlist('bios-guide').then((joined) => {
      setHasJoined(joined);
      if (joined) {
        try { localStorage.setItem(cacheKey, 'true'); } catch {}
      }
      setCheckingStatus(false);
    }).catch(() => {
      setCheckingStatus(false);
    });
  }, [authUser?.id]);

  const handleJoin = async () => {
    setIsSubmitting(true);
    setError(null);

    const result = await window.sensequality.joinWaitlist('bios-guide');

    if (result.success) {
      setHasJoined(true);
      const userId = authUser?.id || '';
      try { localStorage.setItem(`sensequality-waitlist-bios:${userId}`, 'true'); } catch {}
    } else {
      setError(result.error || 'Failed to join waitlist. Please try again.');
    }

    setIsSubmitting(false);
  };

  return (
    <div className="relative flex items-center justify-center h-full overflow-hidden">
      {/* Gradient background */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute inset-0 bg-gradient-to-b from-sq-accent/8 via-transparent to-sq-accent/4" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] rounded-full bg-sq-accent/6 blur-[100px]" />
      </div>

      <div className="relative z-10 text-center max-w-md px-4">
        {/* PC icon with glow rings */}
        <div className="relative w-24 h-24 mx-auto mb-8">
          {/* Outer glow ring */}
          <div className="absolute inset-0 rounded-full border border-sq-accent/20 animate-pulse" />
          <div className="absolute inset-2 rounded-full border border-sq-accent/15" />
          {/* Icon center */}
          <div className="absolute inset-4 rounded-full bg-sq-accent/10 flex items-center justify-center">
            <svg className="w-10 h-10 text-sq-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z" />
            </svg>
          </div>
        </div>

        {/* Coming Soon badge */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-sq-accent/10 border border-sq-accent/20 mb-5">
          <div className="w-2 h-2 rounded-full bg-sq-accent animate-pulse" />
          <span className="text-[10px] font-bold text-sq-accent tracking-[0.2em] uppercase">Coming Soon</span>
        </div>

        <h1 className="text-2xl font-bold text-sq-text mb-3 tracking-tight">
          BIOS Optimization Guide
        </h1>
        <p className="text-xs text-sq-text-muted leading-relaxed mb-8 max-w-xs mx-auto">
          Interactive, step-by-step BIOS optimization with per-motherboard recommendations. Get notified when it launches.
        </p>

        {checkingStatus ? (
          <div className="flex justify-center">
            <svg className="w-5 h-5 animate-spin text-sq-text-muted" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          </div>
        ) : hasJoined ? (
          <div className="inline-flex items-center gap-2.5 px-6 py-3 rounded-xl bg-sq-success/10 border border-sq-success/20">
            <svg className="w-5 h-5 text-sq-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            <span className="text-sm font-semibold text-sq-success">You're on the waitlist!</span>
          </div>
        ) : (
          <div>
            <button
              onClick={handleJoin}
              disabled={isSubmitting}
              className="sq-glass px-8 py-3 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-sq-accent/25 hover:shadow-sq-accent/40"
            >
              {isSubmitting ? (
                <span className="flex items-center gap-2">
                  <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Joining...
                </span>
              ) : (
                'JOIN THE WAITLIST'
              )}
            </button>

            {authUser?.email && (
              <p className="text-[10px] text-sq-text-dim mt-3">
                We'll notify you at {authUser.email}
              </p>
            )}

            {error && (
              <div className="text-xs text-sq-danger mt-3">{error}</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
