import { AUTUMN_FEATURES, BILLING_CONFIGURED, BILLING_PROXY_URL } from './config';
import { SUPABASE_ANON_KEY } from '../telemetry/config';
import { getSession, getAccessToken } from '../auth/auth';
import type { BillingAccessResult } from '../../src/types/index';

type EntitlementReason =
  | 'billing_disabled'
  | 'not_authenticated'
  | 'autumn_allowed'
  | 'cached'
  | 'not_entitled';

interface FeatureEntitlementResult extends BillingAccessResult {
  reason: EntitlementReason;
}

interface EntitlementCache {
  customerId: string;
  featureId: string;
  allowed: boolean;
  checkedAt: number;
}

const CACHE_TTL_MS = 5 * 60 * 1000;
let entitlementCache: EntitlementCache | null = null;

export function invalidateEntitlementCache(): void {
  entitlementCache = null;
}

async function getCustomerId(): Promise<string | null> {
  const session = await getSession();
  return session?.user?.id || null;
}

async function billingFetch(
  action: string,
  params: Record<string, unknown> = {},
): Promise<{ data: Record<string, unknown> | null; ok: boolean; status: number }> {
  const jwt = await getAccessToken();
  if (!jwt) {
    return { data: null, ok: false, status: 401 };
  }

  const res = await fetch(BILLING_PROXY_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${jwt}`,
      apikey: SUPABASE_ANON_KEY,
    },
    body: JSON.stringify({ action, ...params }),
  });

  const data = await res.json().catch(() => null) as Record<string, unknown> | null;
  return { data, ok: res.ok, status: res.status };
}

function toPlan(allowed: boolean): BillingAccessResult['plan'] {
  return allowed ? 'pro' : 'free';
}

export async function getFeatureAccess(featureId: string): Promise<FeatureEntitlementResult> {
  if (!BILLING_CONFIGURED) {
    return { allowed: true, plan: 'dev', reason: 'billing_disabled' };
  }

  const customerId = await getCustomerId();
  if (!customerId) {
    return { allowed: false, plan: 'free', reason: 'not_authenticated' };
  }

  if (
    entitlementCache &&
    entitlementCache.customerId === customerId &&
    entitlementCache.featureId === featureId &&
    Date.now() - entitlementCache.checkedAt < CACHE_TTL_MS
  ) {
    return {
      allowed: entitlementCache.allowed,
      plan: toPlan(entitlementCache.allowed),
      reason: 'cached',
    };
  }

  try {
    const { data, ok } = await billingFetch('check', { feature_id: featureId });
    if (!ok || !data) throw new Error('Check request failed');

    const allowed = (data as { allowed?: boolean }).allowed ?? false;
    entitlementCache = { customerId, featureId, allowed, checkedAt: Date.now() };

    return {
      allowed,
      plan: toPlan(allowed),
      reason: allowed ? 'autumn_allowed' : 'not_entitled',
    };
  } catch (err) {
    console.error('[billing] getFeatureAccess failed:', err instanceof Error ? err.message : err);

    const STALE_CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes max staleness
    if (
      entitlementCache &&
      entitlementCache.customerId === customerId &&
      entitlementCache.featureId === featureId &&
      Date.now() - entitlementCache.checkedAt < STALE_CACHE_TTL_MS
    ) {
      console.warn(`[billing] Using stale cache (age=${Math.round((Date.now() - entitlementCache.checkedAt) / 1000)}s) for ${featureId}`);
      return {
        allowed: entitlementCache.allowed,
        plan: toPlan(entitlementCache.allowed),
        reason: 'cached',
      };
    }

    return { allowed: false, plan: 'free', reason: 'not_entitled' };
  }
}

export async function checkBiosOptimizerAccess(): Promise<BillingAccessResult> {
  const result = await getFeatureAccess(AUTUMN_FEATURES.biosOptimizer);
  return { allowed: result.allowed, plan: result.plan };
}

export async function requireBiosOptimizerAccess(): Promise<string | null> {
  const result = await getFeatureAccess(AUTUMN_FEATURES.biosOptimizer);
  if (result.allowed) return null;
  if (result.reason === 'not_authenticated') return 'Sign in required for BIOS automation';
  return 'Pro subscription required for BIOS automation';
}
