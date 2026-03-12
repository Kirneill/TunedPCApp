import { beforeEach, describe, expect, it, vi } from 'vitest';

const mockGetSession = vi.fn();
const mockGetAccessToken = vi.fn();
let mockBillingConfigured = true;

vi.mock('../../auth/auth', () => ({
  getSession: (...args: unknown[]) => mockGetSession(...args),
  getAccessToken: (...args: unknown[]) => mockGetAccessToken(...args),
}));

vi.mock('../config', () => ({
  get BILLING_CONFIGURED() { return mockBillingConfigured; },
  BILLING_PROXY_URL: 'https://test.supabase.co/functions/v1/billing-proxy',
  AUTUMN_FEATURES: { biosOptimizer: 'bios_optimizer' },
}));

vi.mock('../../telemetry/config', () => ({
  SUPABASE_ANON_KEY: 'test-anon-key',
}));

const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

import {
  checkBiosOptimizerAccess,
  invalidateEntitlementCache,
  requireBiosOptimizerAccess,
} from '../entitlements';

function mockSession(
  id = 'user-123',
  email = 'test@example.com',
) {
  mockGetSession.mockResolvedValue({ user: { id, email } });
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

beforeEach(() => {
  vi.clearAllMocks();
  mockBillingConfigured = true;
  invalidateEntitlementCache();
});

describe('checkBiosOptimizerAccess', () => {
  it('returns dev plan when billing is disabled', async () => {
    mockBillingConfigured = false;
    const result = await checkBiosOptimizerAccess();
    expect(result).toEqual({ allowed: true, plan: 'dev' });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('returns free when no session exists', async () => {
    mockNoSession();
    const result = await checkBiosOptimizerAccess();
    expect(result).toEqual({ allowed: false, plan: 'free' });
  });

  it('uses Autumn as the primary entitlement source', async () => {
    mockSession('user-123', 'test@example.com');
    mockFetchResponse({ allowed: true });
    const result = await checkBiosOptimizerAccess();
    expect(result).toEqual({ allowed: true, plan: 'pro' });
  });

  it('falls back to cached entitlement on later fetch failures', async () => {
    mockSession();
    mockFetchResponse({ allowed: true });
    await checkBiosOptimizerAccess();

    mockFetch.mockRejectedValue(new Error('network failure'));
    const result = await checkBiosOptimizerAccess();
    expect(result).toEqual({ allowed: true, plan: 'pro' });
  });

  it('denies access when Autumn is unavailable and no cache exists', async () => {
    mockSession();
    mockFetch.mockResolvedValue({ ok: false, status: 500, json: () => Promise.resolve(null) });
    const result = await checkBiosOptimizerAccess();
    expect(result).toEqual({ allowed: false, plan: 'free' });
  });
});

describe('requireBiosOptimizerAccess', () => {
  it('allows BIOS automation for Autumn-entitled users', async () => {
    mockSession('user-123', 'test@example.com');
    mockFetchResponse({ allowed: true });
    await expect(requireBiosOptimizerAccess()).resolves.toBeNull();
  });

  it('returns a sign-in message when the user is unauthenticated', async () => {
    mockNoSession();
    await expect(requireBiosOptimizerAccess()).resolves.toBe('Sign in required for BIOS automation');
  });

  it('returns the Pro message when entitlement is denied', async () => {
    mockSession();
    mockFetchResponse({ allowed: false });
    await expect(requireBiosOptimizerAccess()).resolves.toBe('Pro subscription required for BIOS automation');
  });
});
