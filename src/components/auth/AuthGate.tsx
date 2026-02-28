import { useState } from 'react';
import { useAppStore } from '../../store/appStore';

type Mode = 'signin' | 'signup' | 'reset';

interface AuthGateProps {
  onAuthenticated: () => Promise<void>;
}

export default function AuthGate({ onAuthenticated }: AuthGateProps) {
  const { setAuthUser, setShowAuthGate, setAuthLoading } = useAppStore();

  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [resetSent, setResetSent] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (mode === 'reset') {
      if (!email.trim()) { setError('Please enter your email address.'); return; }
      setIsSubmitting(true);
      const result = await window.sensequality.resetPassword(email.trim());
      setIsSubmitting(false);
      if (result.success) {
        setResetSent(true);
      } else {
        setError(result.error || 'Failed to send reset email.');
      }
      return;
    }

    if (!email.trim() || !password) {
      setError('Please fill in all fields.');
      return;
    }

    if (mode === 'signup' && password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    if (mode === 'signup' && password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }

    setIsSubmitting(true);

    const result = mode === 'signup'
      ? await window.sensequality.signUp(email.trim(), password)
      : await window.sensequality.signIn(email.trim(), password);

    setIsSubmitting(false);

    if (result.success && result.user) {
      setAuthUser(result.user);
      setShowAuthGate(false);
      setAuthLoading(true);
      try {
        await onAuthenticated();
      } catch (err) {
        console.error('Post-auth initialization failed:', err);
        setShowAuthGate(true);
        setError('Signed in, but initialization failed. Please try again.');
      } finally {
        setAuthLoading(false);
      }
    } else {
      setError(result.error || 'Authentication failed.');
    }
  };

  const switchMode = (newMode: Mode) => {
    setMode(newMode);
    setError(null);
    setResetSent(false);
  };

  return (
    <div className="flex flex-col h-full bg-sq-bg">
      {/* Window controls (frameless app) */}
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

      {/* Auth form */}
      <div className="flex-1 flex items-center justify-center">
        <div className="w-full max-w-sm mx-4">
          {/* Logo */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-14 h-14 rounded-xl bg-sq-accent/90 flex items-center justify-center text-xl font-bold text-white tracking-tight mb-3 shadow-lg shadow-sq-accent/30 backdrop-blur-sm">
              SQ
            </div>
            <h1 className="text-lg font-bold text-sq-text tracking-wide">SENSEQUALITY</h1>
            <p className="text-xs text-sq-text-muted mt-1">PC Gaming Optimizer</p>
          </div>

          <div className="sq-glass rounded-2xl p-6 shadow-2xl">
            <h2 className="text-base font-bold text-sq-text mb-1">
              {mode === 'signin' ? 'Sign In' : mode === 'signup' ? 'Create Account' : 'Reset Password'}
            </h2>
            <p className="text-xs text-sq-text-muted mb-5">
              {mode === 'signin' && 'Sign in to access your optimizations.'}
              {mode === 'signup' && 'Create an account to get started.'}
              {mode === 'reset' && (resetSent ? 'Check your email for a reset link.' : 'Enter your email to receive a reset link.')}
            </p>

            {resetSent ? (
              <div className="text-center py-4">
                <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-sq-success/20 flex items-center justify-center">
                  <svg className="w-6 h-6 text-sq-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <p className="text-sm text-sq-text mb-4">Reset email sent!</p>
                <button
                  onClick={() => switchMode('signin')}
                  className="text-xs text-sq-accent hover:underline cursor-pointer"
                >
                  Back to Sign In
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-3">
                <div>
                  <label className="block text-[11px] text-sq-text-muted mb-1 uppercase tracking-wider">Email</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-3 py-2.5 rounded-lg bg-sq-bg border border-sq-border text-sm text-sq-text placeholder:text-sq-text-dim focus:outline-none focus:border-sq-accent transition-colors"
                    placeholder="you@example.com"
                    autoFocus
                    disabled={isSubmitting}
                  />
                </div>

                {mode !== 'reset' && (
                  <div>
                    <label className="block text-[11px] text-sq-text-muted mb-1 uppercase tracking-wider">Password</label>
                    <input
                      type="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full px-3 py-2.5 rounded-lg bg-sq-bg border border-sq-border text-sm text-sq-text placeholder:text-sq-text-dim focus:outline-none focus:border-sq-accent transition-colors"
                      placeholder={mode === 'signup' ? 'Min 6 characters' : 'Your password'}
                      disabled={isSubmitting}
                    />
                  </div>
                )}

                {mode === 'signup' && (
                  <div>
                    <label className="block text-[11px] text-sq-text-muted mb-1 uppercase tracking-wider">Confirm Password</label>
                    <input
                      type="password"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      className="w-full px-3 py-2.5 rounded-lg bg-sq-bg border border-sq-border text-sm text-sq-text placeholder:text-sq-text-dim focus:outline-none focus:border-sq-accent transition-colors"
                      placeholder="Confirm your password"
                      disabled={isSubmitting}
                    />
                  </div>
                )}

                {error && (
                  <div className="text-xs text-sq-danger bg-sq-danger/10 border border-sq-danger/20 rounded-lg px-3 py-2">
                    {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-2.5 rounded-xl text-sm font-bold text-white bg-sq-accent hover:bg-sq-accent-hover transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? (
                    <span className="flex items-center justify-center gap-2">
                      <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                      </svg>
                      {mode === 'reset' ? 'Sending...' : mode === 'signup' ? 'Creating Account...' : 'Signing In...'}
                    </span>
                  ) : (
                    mode === 'reset' ? 'Send Reset Link' : mode === 'signup' ? 'Create Account' : 'Sign In'
                  )}
                </button>
              </form>
            )}

            {!resetSent && (
              <div className="mt-4 text-center space-y-2">
                {mode === 'signin' && (
                  <>
                    <button onClick={() => switchMode('reset')} className="text-xs text-sq-text-dim hover:text-sq-accent transition-colors cursor-pointer">
                      Forgot password?
                    </button>
                    <p className="text-xs text-sq-text-muted">
                      Don't have an account?{' '}
                      <button onClick={() => switchMode('signup')} className="text-sq-accent hover:underline cursor-pointer">
                        Sign up
                      </button>
                    </p>
                  </>
                )}
                {mode === 'signup' && (
                  <p className="text-xs text-sq-text-muted">
                    Already have an account?{' '}
                    <button onClick={() => switchMode('signin')} className="text-sq-accent hover:underline cursor-pointer">
                      Sign in
                    </button>
                  </p>
                )}
                {mode === 'reset' && (
                  <p className="text-xs text-sq-text-muted">
                    Remember your password?{' '}
                    <button onClick={() => switchMode('signin')} className="text-sq-accent hover:underline cursor-pointer">
                      Sign in
                    </button>
                  </p>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
