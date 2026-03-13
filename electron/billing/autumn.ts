import { IpcMain, shell } from 'electron';
import { BILLING_PROXY_URL, AUTUMN_PRODUCTS, BILLING_CONFIGURED } from './config';
import { SUPABASE_ANON_KEY } from '../telemetry/config';
import { getSession, getAccessToken } from '../auth/auth';
import type { Subscription, BillingAccessResult } from '../../src/types/index';
import { checkBiosOptimizerAccess, invalidateEntitlementCache } from './entitlements';

export { invalidateEntitlementCache } from './entitlements';

// ─── Helpers ─────────────────────────────────────────────

async function getCustomerId(): Promise<string | null> {
  const session = await getSession();
  return session?.user?.id || null;
}

async function getCustomerEmail(): Promise<string | null> {
  const session = await getSession();
  return session?.user?.email || null;
}

/** POST to the billing-proxy Edge Function with the user's JWT. */
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

// ─── Init (no-op, kept for call-site compatibility) ──────

export function initBilling(): void {
  if (!BILLING_CONFIGURED) {
    console.warn('[billing] Billing disabled (AUTUMN_BILLING=0)');
    return;
  }
  console.log('[billing] Billing configured (Edge Function proxy)');
}

// ─── Public API ──────────────────────────────────────────

/**
 * Check if the current user has access to the BIOS optimizer feature.
 * Returns { allowed, plan } -- used by renderer to show/hide content.
 */
export async function checkBiosAccess(): Promise<BillingAccessResult> {
  return checkBiosOptimizerAccess();
}

/**
 * Create a checkout session for the Pro subscription.
 * Returns a Stripe checkout URL to open in the user's browser.
 */
export async function createCheckout(successUrl?: string): Promise<{ url?: string; error?: string }> {
  if (!BILLING_CONFIGURED) {
    return { error: 'Billing not configured' };
  }

  const customerId = await getCustomerId();
  if (!customerId) {
    return { error: 'Not authenticated' };
  }

  const email = await getCustomerEmail();

  try {
    const { data, ok } = await billingFetch('attach', {
      product_id: AUTUMN_PRODUCTS.pro,
      success_url: successUrl || 'https://tunedpc.com/pages/billing-success',
      force_checkout: true,
      ...(email ? { email } : {}),
    });

    if (!ok || !data) {
      return { error: (data as { error?: string })?.error || 'Checkout failed' };
    }

    const checkoutUrl = (data as { url?: string; checkout_url?: string }).url || (data as { checkout_url?: string }).checkout_url;
    if (checkoutUrl) {
      return { url: checkoutUrl };
    }

    // If no checkout URL, the product was attached directly (card already on file)
    invalidateEntitlementCache();
    return { url: undefined }; // Success without redirect
  } catch (err) {
    console.error('[billing] createCheckout failed:', err instanceof Error ? err.message : err);
    return { error: err instanceof Error ? err.message : 'Checkout failed' };
  }
}

/**
 * Cancel the Pro subscription at end of billing period.
 */
export async function cancelSubscription(immediately = false): Promise<{ success: boolean; error?: string }> {
  if (!BILLING_CONFIGURED) {
    return { success: false, error: 'Billing not configured' };
  }

  const customerId = await getCustomerId();
  if (!customerId) {
    return { success: false, error: 'Not authenticated' };
  }

  try {
    const { ok, data } = await billingFetch('cancel', {
      product_id: AUTUMN_PRODUCTS.pro,
      cancel_immediately: immediately,
    });

    if (!ok) {
      return { success: false, error: (data as { error?: string })?.error || 'Cancel failed' };
    }

    invalidateEntitlementCache();
    return { success: true };
  } catch (err) {
    console.error('[billing] cancelSubscription failed:', err instanceof Error ? err.message : err);
    return { success: false, error: err instanceof Error ? err.message : 'Cancel failed' };
  }
}

/**
 * Get the current user's subscription data from Autumn.
 */
export async function getSubscription(): Promise<Subscription> {
  const FREE_SUB: Subscription = { plan: 'free', status: 'free' };

  if (!BILLING_CONFIGURED) {
    return { plan: 'pro', status: 'active' }; // Dev mode: always pro
  }

  const customerId = await getCustomerId();
  if (!customerId) {
    return FREE_SUB;
  }

  try {
    const { data, ok } = await billingFetch('getCustomer');

    if (!ok || !data) {
      console.error('[billing] getSubscription: API returned not-ok or null data');
      return FREE_SUB;
    }

    const products = (data as { products?: Array<{ id: string; status: string; canceled_at?: number | null }> }).products || [];
    const proPlan = products.find(
      (p) => p.id === AUTUMN_PRODUCTS.pro
    );

    if (!proPlan) {
      console.log('[billing] getSubscription: no pro product found for customer');
      return FREE_SUB;
    }

    // Map Autumn status to our SubscriptionStatus
    if (proPlan.status === 'active') {
      // Autumn represents cancellation as active + canceled_at set (Unix timestamp)
      const isCanceled = !!(proPlan.canceled_at);
      return { plan: 'pro', status: isCanceled ? 'canceled' : 'active' };
    }

    if (proPlan.status === 'trialing') return { plan: 'pro', status: 'trialing' };
    if (proPlan.status === 'past_due') return { plan: 'pro', status: 'past_due' };

    return FREE_SUB;
  } catch (err) {
    console.error('[billing] getSubscription failed:', err instanceof Error ? err.message : err);
    return FREE_SUB;
  }
}

/**
 * Open the Stripe billing portal for the customer to manage their subscription.
 */
export async function openBillingPortal(): Promise<{ success: boolean; error?: string }> {
  if (!BILLING_CONFIGURED) {
    return { success: false, error: 'Billing not configured' };
  }

  const customerId = await getCustomerId();
  if (!customerId) {
    return { success: false, error: 'Not authenticated' };
  }

  try {
    const { data, ok } = await billingFetch('billingPortal');

    if (!ok || !data) {
      return { success: false, error: 'No billing portal URL returned' };
    }

    const url = (data as { url?: string }).url;
    if (url) {
      if (!url.startsWith('https://')) {
        return { success: false, error: 'Invalid billing portal URL' };
      }
      await shell.openExternal(url);
      return { success: true };
    }
    return { success: false, error: 'No billing portal URL returned' };
  } catch (err) {
    console.error('[billing] openBillingPortal failed:', err instanceof Error ? err.message : err);
    return { success: false, error: err instanceof Error ? err.message : 'Failed to open billing portal' };
  }
}

// ─── IPC Handlers ────────────────────────────────────────

export function registerBillingHandlers(ipcMain: IpcMain): void {
  ipcMain.handle('billing:checkAccess', () => checkBiosAccess());

  ipcMain.handle('billing:checkout', async (_e, successUrl?: string) => {
    const result = await createCheckout(successUrl);
    // If we got a checkout URL, open it in the default browser
    if (result.url) {
      if (!result.url.startsWith('https://')) {
        return { error: 'Invalid checkout URL' };
      }
      await shell.openExternal(result.url);
    }
    return result;
  });

  ipcMain.handle('billing:cancelSubscription', (_e, immediately?: boolean) =>
    cancelSubscription(immediately)
  );

  ipcMain.handle('billing:getSubscription', () => getSubscription());

  ipcMain.handle('billing:openBillingPortal', () => openBillingPortal());

  ipcMain.handle('billing:refreshAccess', async () => {
    invalidateEntitlementCache();
    return checkBiosAccess();
  });
}
