import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { app, net, safeStorage } from 'electron';
import fs from 'fs';
import path from 'path';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../telemetry/config';
import { generateAnonymousId } from '../telemetry/telemetry';
export type { AuthUser, AuthResult, MachineRegistrationResult, UserMachine } from '../../src/types/index';
import type { AuthUser, AuthResult, MachineRegistrationResult, UserMachine } from '../../src/types/index';

// ─── State ───────────────────────────────────────────────

let supabase: SupabaseClient | null = null;
let isOffline = false;
let connectivityCache: { checkedAt: number; isOnline: boolean } | null = null;

const CONNECTIVITY_CACHE_MS = 15000;
const CONNECTIVITY_TIMEOUT_MS = 5000;
const CONNECTIVITY_URLS = [
  'https://www.msftconnecttest.com/connecttest.txt',
  'https://www.cloudflare.com/cdn-cgi/trace',
];

function getAuthDir(): string {
  return app.getPath('userData');
}

function getEncryptedPath(): string {
  return path.join(getAuthDir(), 'auth.enc');
}

function getPlaintextPath(): string {
  return path.join(getAuthDir(), 'auth.json');
}

// ─── Secure Token Storage ────────────────────────────────

interface StoredSession {
  access_token: string;
  refresh_token: string;
}

function saveSession(session: StoredSession): void {
  try {
    const dir = getAuthDir();
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const data = JSON.stringify(session);

    if (safeStorage.isEncryptionAvailable()) {
      const encrypted = safeStorage.encryptString(data);
      fs.writeFileSync(getEncryptedPath(), encrypted);
      // Remove plaintext fallback if it exists
      try { fs.unlinkSync(getPlaintextPath()); } catch (unlinkErr) {
        if ((unlinkErr as NodeJS.ErrnoException).code !== 'ENOENT') {
          console.warn('[auth] Failed to remove plaintext session fallback:', (unlinkErr as Error).message);
        }
      }
    } else {
      fs.writeFileSync(getPlaintextPath(), data);
    }
  } catch (err) {
    console.warn('[auth] Failed to save session:', err instanceof Error ? err.message : err);
  }
}

function loadSession(): StoredSession | null {
  try {
    // Try encrypted first
    const encPath = getEncryptedPath();
    if (fs.existsSync(encPath)) {
      const encrypted = fs.readFileSync(encPath);
      const decrypted = safeStorage.decryptString(encrypted);
      return JSON.parse(decrypted);
    }

    // Fallback to plaintext
    const plainPath = getPlaintextPath();
    if (fs.existsSync(plainPath)) {
      const data = fs.readFileSync(plainPath, 'utf-8');
      return JSON.parse(data);
    }
  } catch (err) {
    console.warn('[auth] Failed to load session:', err instanceof Error ? err.message : err);
  }
  return null;
}

function clearSession(): void {
  for (const filePath of [getEncryptedPath(), getPlaintextPath()]) {
    try {
      fs.unlinkSync(filePath);
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        console.warn(`[auth] Failed to clear session file ${filePath}:`, (err as Error).message);
      }
    }
  }
}

// ─── Error Mapping ───────────────────────────────────────

function isNetworkError(err: unknown): boolean {
  if (!err) return false;
  const msg = (err as { message?: string }).message || String(err);
  return (
    msg.includes('fetch') ||
    msg.includes('network') ||
    msg.includes('ENOTFOUND') ||
    msg.includes('ECONNREFUSED') ||
    msg.includes('ETIMEDOUT') ||
    msg.includes('Failed to fetch') ||
    msg.includes('NetworkError')
  );
}

function mapAuthError(error: { message?: string; status?: number } | null): string {
  if (!error) return 'Unknown error';
  const msg = error.message || '';

  if (isNetworkError(error)) return 'No internet connection. Please check your network and try again.';
  if (msg.includes('Invalid login credentials')) return 'Wrong email or password.';
  if (msg.includes('User already registered')) return 'An account with this email already exists. Try signing in.';
  if (msg.includes('Password should be')) return 'Password must be at least 6 characters.';
  if (msg.includes('Unable to validate email')) return 'Please enter a valid email address.';
  if (error.status === 401) return 'Session expired. Please sign in again.';
  if (error.status === 429) return 'Too many attempts. Please wait a moment.';

  return msg || 'Something went wrong. Please try again.';
}

async function probeConnectivityUrl(url: string): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const request = net.request({
      url,
      method: 'HEAD',
    });

    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      try { request.abort(); } catch {}
      resolve(false);
    }, CONNECTIVITY_TIMEOUT_MS);

    request.on('response', (response) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      resolve(Boolean(response.statusCode && response.statusCode > 0));
    });

    request.on('error', () => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      resolve(false);
    });

    request.end();
  });
}

async function hasLiveInternetConnectivity(): Promise<boolean> {
  for (const url of CONNECTIVITY_URLS) {
    if (await probeConnectivityUrl(url)) {
      return true;
    }
  }
  return false;
}

// ─── Public API ──────────────────────────────────────────

export async function initAuth(): Promise<void> {
  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: true,
      persistSession: false, // We handle persistence ourselves via safeStorage
    },
  });

  isOffline = false;

  const stored = loadSession();
  if (stored) {
    try {
      const { error } = await supabase.auth.setSession({
        access_token: stored.access_token,
        refresh_token: stored.refresh_token,
      });

      if (error) {
        if (isNetworkError(error)) {
          isOffline = true;
          console.warn('[auth] Offline — could not refresh session');
        } else {
          // Token is invalid/expired beyond refresh — clear it
          clearSession();
        }
      } else {
        // Session restored successfully — re-persist (tokens may have been refreshed)
        const { data } = await supabase.auth.getSession();
        if (data.session) {
          saveSession({
            access_token: data.session.access_token,
            refresh_token: data.session.refresh_token,
          });
        }
      }
    } catch (err) {
      if (isNetworkError(err)) {
        isOffline = true;
        console.warn('[auth] Offline — network error during init');
      } else {
        clearSession();
      }
    }
  }
}

export async function getIsOffline(): Promise<boolean> {
  const now = Date.now();
  if (connectivityCache && now - connectivityCache.checkedAt < CONNECTIVITY_CACHE_MS) {
    return !connectivityCache.isOnline;
  }

  const isOnline = await hasLiveInternetConnectivity();
  connectivityCache = { checkedAt: now, isOnline };

  // Keep the auth-level flag in sync so we don't carry stale offline state.
  isOffline = !isOnline;
  return !isOnline;
}

export async function signUp(email: string, password: string): Promise<AuthResult> {
  if (!supabase) return { success: false, error: 'Auth not initialized' };

  try {
    const { data, error } = await supabase.auth.signUp({ email, password });

    if (error) return { success: false, error: mapAuthError(error) };
    if (!data.user) return { success: false, error: 'Sign up failed. Please try again.' };

    if (data.session) {
      saveSession({
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token,
      });
    }

    isOffline = false;
    return { success: true, user: { id: data.user.id, email: data.user.email || email } };
  } catch (err) {
    if (isNetworkError(err)) return { success: false, error: 'No internet connection. Please check your network and try again.' };
    return { success: false, error: mapAuthError(err as { message?: string }) };
  }
}

export async function signIn(email: string, password: string): Promise<AuthResult> {
  if (!supabase) return { success: false, error: 'Auth not initialized' };

  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) return { success: false, error: mapAuthError(error) };
    if (!data.session) return { success: false, error: 'Sign in failed. Please try again.' };

    saveSession({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
    });

    isOffline = false;
    return { success: true, user: { id: data.user.id, email: data.user.email || email } };
  } catch (err) {
    if (isNetworkError(err)) return { success: false, error: 'No internet connection. Please check your network and try again.' };
    return { success: false, error: mapAuthError(err as { message?: string }) };
  }
}

export async function signOut(): Promise<void> {
  if (supabase) {
    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.warn('[auth] signOut server call failed (local session cleared anyway):', err instanceof Error ? err.message : err);
    }
  }
  clearSession();
  isOffline = false;
}

export async function resetPassword(email: string): Promise<AuthResult> {
  if (!supabase) return { success: false, error: 'Auth not initialized' };

  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: 'https://sensequality.com/reset-password',
    });
    if (error) return { success: false, error: mapAuthError(error) };
    return { success: true };
  } catch (err) {
    if (isNetworkError(err)) return { success: false, error: 'No internet connection. Please check your network and try again.' };
    return { success: false, error: mapAuthError(err as { message?: string }) };
  }
}

export async function getSession(): Promise<{ user: AuthUser } | null> {
  if (!supabase) return null;

  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) {
      if (isNetworkError(error)) {
        console.warn('[auth] getSession failed due to network error — preserving session');
        throw error;
      }
      console.warn('[auth] getSession error:', error.message);
      return null;
    }
    if (!data.session?.user) return null;
    return {
      user: {
        id: data.session.user.id,
        email: data.session.user.email || '',
      },
    };
  } catch (err) {
    if (isNetworkError(err)) {
      console.warn('[auth] getSession network error — preserving session');
      throw err;
    }
    console.warn('[auth] getSession failed:', err instanceof Error ? err.message : err);
    return null;
  }
}

export async function getAuthUser(): Promise<AuthUser | null> {
  const session = await getSession();
  return session?.user || null;
}

export function getMachineId(): string {
  return generateAnonymousId();
}

// ─── Machine Management (via RPCs) ──────────────────────

export async function registerMachine(info: {
  machine_name: string;
  gpu: string;
  cpu: string;
  ram_gb: number;
  os_build: string;
  gpu_driver?: string;
  gpu_vram_gb?: number;
}): Promise<MachineRegistrationResult> {
  if (!supabase) return { success: false, reason: 'not_authenticated' };

  const baseParams = {
    p_machine_id: getMachineId(),
    p_machine_name: info.machine_name,
    p_gpu: info.gpu,
    p_cpu: info.cpu,
    p_ram_gb: info.ram_gb,
    p_os_build: info.os_build,
  };

  const v2Params = {
    ...baseParams,
    p_app_version: app.getVersion(),
    p_gpu_driver: info.gpu_driver || null,
    p_gpu_vram_gb: info.gpu_vram_gb != null ? Math.round(info.gpu_vram_gb) : null,
  };

  try {
    // Try v2 schema first (with extra columns), fall back to v1 if function signature doesn't match
    let data: unknown;
    let error: { message?: string; code?: string } | null;

    ({ data, error } = await supabase.rpc('register_machine', v2Params));

    if (error?.code === '42883' || error?.code === '42725') {
      // 42883 = "function does not exist", 42725 = "function is not unique" — retry with v1 params
      console.warn(`[auth] register_machine v2 RPC error (${error.code}), falling back to v1 params`);
      ({ data, error } = await supabase.rpc('register_machine', baseParams));
    }

    if (error) {
      console.error('[auth] registerMachine RPC error:', error.message, error.code);
      if (isNetworkError(error)) return { success: false, reason: 'network_error' };
      // RPC infrastructure error — don't treat as auth failure
      return { success: false, reason: 'rpc_error' };
    }

    const result = data as { success: boolean; reason: string; machines?: UserMachine[] };
    return {
      success: result.success,
      reason: result.reason as MachineRegistrationResult['reason'],
      machines: result.machines,
    };
  } catch (err) {
    console.error('[auth] registerMachine exception:', err instanceof Error ? err.message : err);
    if (isNetworkError(err)) return { success: false, reason: 'network_error' };
    return { success: false, reason: 'rpc_error' };
  }
}

export async function deactivateMachine(machineId: string): Promise<{ success: boolean; error?: string }> {
  if (!supabase) return { success: false, error: 'Not authenticated' };

  try {
    const { data, error } = await supabase.rpc('deactivate_machine', {
      p_machine_id: machineId,
    });

    if (error) return { success: false, error: mapAuthError(error) };
    const result = data as { success: boolean; reason?: string };
    return { success: result.success, error: result.reason };
  } catch (err) {
    console.error('[auth] deactivateMachine exception:', err instanceof Error ? err.message : err);
    return { success: false, error: 'Failed to deactivate machine' };
  }
}

// ─── Waitlist (via RPCs) ─────────────────────────────────

export async function joinWaitlist(feature: string): Promise<{ success: boolean; error?: string }> {
  if (!supabase) return { success: false, error: 'Not authenticated' };

  // Verify we have a valid session before calling the RPC
  try {
    const { data: sessionData } = await supabase.auth.getSession();
    if (!sessionData.session) {
      return { success: false, error: 'Session expired. Please sign out and sign in again.' };
    }
  } catch (err) {
    console.warn('[auth] joinWaitlist session check failed:', err instanceof Error ? err.message : err);
    return { success: false, error: 'Could not verify session.' };
  }

  try {
    const { data, error } = await supabase.rpc('join_waitlist', {
      p_feature_name: feature,
    });

    if (error) {
      console.error('[auth] joinWaitlist RPC error:', error.message, error.code, error.details, error.hint);
      // Surface the actual error for debugging
      if (error.code === '42883') {
        return { success: false, error: 'Waitlist feature not set up yet. Run supabase-schema-auth.sql in your Supabase SQL Editor.' };
      }
      return { success: false, error: mapAuthError(error) };
    }
    const result = data as { success: boolean };
    return { success: result.success };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[auth] joinWaitlist exception:', msg);
    if (isNetworkError(err)) return { success: false, error: 'No internet connection.' };
    return { success: false, error: `Failed to join waitlist: ${msg}` };
  }
}

export async function hasJoinedWaitlist(feature: string): Promise<boolean> {
  if (!supabase) return false;

  try {
    const { data, error } = await supabase.rpc('has_joined_waitlist', {
      p_feature_name: feature,
    });

    if (error) {
      console.error('[auth] hasJoinedWaitlist RPC error:', error.message, error.code);
      return false;
    }
    return data === true;
  } catch (err) {
    console.error('[auth] hasJoinedWaitlist exception:', err instanceof Error ? err.message : err);
    return false;
  }
}
