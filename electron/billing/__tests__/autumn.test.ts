import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock electron modules before importing the module under test
vi.mock('electron', () => ({
  IpcMain: {},
  shell: { openExternal: vi.fn() },
}));

// Mock auth module
const mockGetSession = vi.fn();
const mockGetAccessToken = vi.fn();

vi.mock('../../auth/auth', () => ({
  getSession: (...args: unknown[]) => mockGetSession(...args),
  getAccessToken: (...args: unknown[]) => mockGetAccessToken(...args),
}));

// Mock config -- use a factory that returns dynamic values
let mockBillingConfigured = true;

vi.mock('../config', () => ({
  get BILLING_CONFIGURED() { return mockBillingConfigured; },
  BILLING_PROXY_URL: 'https://test.supabase.co/functions/v1/billing-proxy',
  AUTUMN_PRODUCTS: { pro: 'pro' },
  AUTUMN_FEATURES: { biosOptimizer: 'bios_optimizer' },
}));

// Mock global fetch
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

// Now import the module under test
import {
  checkBiosAccess,
  getSubscription,
  createCheckout,
  cancelSubscription,
  openBillingPortal,
  invalidateEntitlementCache,
} from '../autumn';

beforeEach(() => {
  vi.clearAllMocks();
  mockBillingConfigured = true;
  invalidateEntitlementCache();
});

// ─── Helpers ─────────────────────────────────────────────

function mockSession(id = 'user-123', email = 'test@example.com') {
  mockGetSession.mockResolvedValue({ user: { id, email, tier: 'free' } });
  mockGetAccessToken.mockResolvedValue('jwt-token-abc');
}

function mockNoSession() {
  mockGetSession.mockResolvedValue(null);
  mockGetAccessToken.mockResolvedValue(null);
}

function mockFetchResponse(data: unknown, ok = true, status = 200) {
  mockFetch.mockResolvedValue({
    ok,
    status,
    json: () => Promise.resolve(data),
  });
}

// ─── Tests ───────────────────────────────────────────────

describe('checkBiosAccess', () => {
  it('returns dev plan when billing is disabled', async () => {
    mockBillingConfigured = false;
    const result = await checkBiosAccess();
    expect(result).toEqual({ allowed: true, plan: 'dev' });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('returns free when no session', async () => {
    mockNoSession();
    const result = await checkBiosAccess();
    expect(result).toEqual({ allowed: false, plan: 'free' });
  });

  it('returns pro when check succeeds with allowed=true', async () => {
    mockSession();
    mockFetchResponse({ allowed: true });
    const result = await checkBiosAccess();
    expect(result).toEqual({ allowed: true, plan: 'pro' });
  });

  it('returns free when check succeeds with allowed=false', async () => {
    mockSession();
    mockFetchResponse({ allowed: false });
    const result = await checkBiosAccess();
    expect(result).toEqual({ allowed: false, plan: 'free' });
  });

  it('uses cache on second call within TTL', async () => {
    mockSession();
    mockFetchResponse({ allowed: true });
    await checkBiosAccess();
    await checkBiosAccess();
    // Only one fetch call -- second used cache
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('cache is scoped by customerId', async () => {
    mockSession('user-A');
    mockFetchResponse({ allowed: true });
    await checkBiosAccess();

    // Switch to different user
    mockSession('user-B');
    mockFetchResponse({ allowed: false });
    const result = await checkBiosAccess();
    expect(result.allowed).toBe(false);
    expect(mockFetch).toHaveBeenCalledTimes(2);
  });

  it('falls back to cached value on API error', async () => {
    mockSession();
    mockFetchResponse({ allowed: true });
    await checkBiosAccess(); // populate cache

    mockFetch.mockRejectedValue(new Error('network failure'));
    const result = await checkBiosAccess();
    // Should use cached value
    expect(result.allowed).toBe(true);
  });

  it('returns free on error with no cache', async () => {
    invalidateEntitlementCache();
    mockSession();
    mockFetch.mockResolvedValue({ ok: false, status: 500, json: () => Promise.resolve(null) });
    const result = await checkBiosAccess();
    expect(result).toEqual({ allowed: false, plan: 'free' });
  });
});

describe('getSubscription', () => {
  it('returns pro/active in dev mode', async () => {
    mockBillingConfigured = false;
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'pro', status: 'active' });
  });

  it('returns free when no session', async () => {
    mockNoSession();
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'free', status: 'free' });
  });

  it('detects active subscription', async () => {
    mockSession();
    mockFetchResponse({ products: [{ id: 'pro', status: 'active' }] });
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'pro', status: 'active' });
  });

  it('detects canceled_at on active subscription', async () => {
    mockSession();
    mockFetchResponse({
      products: [{ id: 'pro', status: 'active', canceled_at: 1700000000 }],
    });
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'pro', status: 'canceled' });
  });

  it('detects past_due subscription', async () => {
    mockSession();
    mockFetchResponse({ products: [{ id: 'pro', status: 'past_due' }] });
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'pro', status: 'past_due' });
  });

  it('detects trialing subscription', async () => {
    mockSession();
    mockFetchResponse({ products: [{ id: 'pro', status: 'trialing' }] });
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'pro', status: 'trialing' });
  });

  it('returns free when no pro product found', async () => {
    mockSession();
    mockFetchResponse({ products: [{ id: 'other', status: 'active' }] });
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'free', status: 'free' });
  });

  it('returns free on API error', async () => {
    mockSession();
    mockFetch.mockRejectedValue(new Error('timeout'));
    const result = await getSubscription();
    expect(result).toEqual({ plan: 'free', status: 'free' });
  });
});

describe('createCheckout', () => {
  it('returns error when billing disabled', async () => {
    mockBillingConfigured = false;
    const result = await createCheckout();
    expect(result.error).toBe('Billing not configured');
  });

  it('returns error when not authenticated', async () => {
    mockNoSession();
    const result = await createCheckout();
    expect(result.error).toBe('Not authenticated');
  });

  it('returns checkout URL on success', async () => {
    mockSession();
    mockFetchResponse({ checkout_url: 'https://checkout.stripe.com/abc' });
    const result = await createCheckout();
    expect(result.url).toBe('https://checkout.stripe.com/abc');
  });

  it('returns undefined url when product attached without redirect', async () => {
    mockSession();
    mockFetchResponse({});
    const result = await createCheckout();
    expect(result.url).toBeUndefined();
    expect(result.error).toBeUndefined();
  });
});

describe('cancelSubscription', () => {
  it('returns error when billing disabled', async () => {
    mockBillingConfigured = false;
    const result = await cancelSubscription();
    expect(result).toEqual({ success: false, error: 'Billing not configured' });
  });

  it('succeeds on OK response', async () => {
    mockSession();
    mockFetchResponse({});
    const result = await cancelSubscription();
    expect(result.success).toBe(true);
  });

  it('passes cancel_immediately flag', async () => {
    mockSession();
    mockFetchResponse({});
    await cancelSubscription(true);
    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.cancel_immediately).toBe(true);
  });
});

describe('openBillingPortal', () => {
  it('returns error when billing disabled', async () => {
    mockBillingConfigured = false;
    const result = await openBillingPortal();
    expect(result).toEqual({ success: false, error: 'Billing not configured' });
  });

  it('rejects non-https URLs', async () => {
    mockSession();
    mockFetchResponse({ url: 'http://evil.com' });
    const result = await openBillingPortal();
    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid billing portal URL');
  });

  it('opens valid portal URL', async () => {
    mockSession();
    mockFetchResponse({ url: 'https://billing.stripe.com/portal/abc' });
    const { shell } = await import('electron');
    const result = await openBillingPortal();
    expect(result.success).toBe(true);
    expect(shell.openExternal).toHaveBeenCalledWith('https://billing.stripe.com/portal/abc');
  });
});
