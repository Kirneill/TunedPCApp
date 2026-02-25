import { useState, useEffect } from 'react';
import { useAppStore } from '../../store/appStore';

export default function BiosGuidePage() {
  const authUser = useAppStore((s) => s.authUser);
  const [hasJoined, setHasJoined] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checkingStatus, setCheckingStatus] = useState(true);

  // Check waitlist status on mount — DB is source of truth, localStorage is cache
  useEffect(() => {
    const userId = authUser?.id || '';
    const cacheKey = `sensequality-waitlist-bios:${userId}`;

    // Check local cache first for instant UI
    try {
      if (localStorage.getItem(cacheKey) === 'true') {
        setHasJoined(true);
        setCheckingStatus(false);
      }
    } catch {}

    // Then verify against DB
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
    <div className="flex items-center justify-center min-h-[calc(100vh-3rem)] px-4">
      <div className="text-center max-w-md">
        {/* Coming Soon badge */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-sq-accent/10 border border-sq-accent/20 mb-6">
          <div className="w-2 h-2 rounded-full bg-sq-accent animate-pulse" />
          <span className="text-xs font-bold text-sq-accent tracking-widest uppercase">Coming Soon</span>
        </div>

        <h1 className="text-3xl font-bold text-sq-text mb-3 tracking-tight">
          BIOS Optimization Guide
        </h1>
        <p className="text-sm text-sq-text-muted leading-relaxed mb-8 max-w-sm mx-auto">
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
              className="px-8 py-3 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-sq-accent/20 hover:shadow-sq-accent/40"
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
              <p className="text-[11px] text-sq-text-dim mt-3">
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
