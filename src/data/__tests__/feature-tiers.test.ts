import { describe, it, expect } from 'vitest';
import { isProActive, requiresPro, PRO_PAGES } from '../feature-tiers';
import type { SubscriptionStatus } from '../../types';

describe('isProActive', () => {
  const activeStatuses: SubscriptionStatus[] = ['active', 'trialing', 'past_due', 'canceled'];
  const inactiveStatuses: SubscriptionStatus[] = ['free', 'expired'];

  for (const status of activeStatuses) {
    it(`returns true for "${status}"`, () => {
      expect(isProActive(status)).toBe(true);
    });
  }

  for (const status of inactiveStatuses) {
    it(`returns false for "${status}"`, () => {
      expect(isProActive(status)).toBe(false);
    });
  }
});

describe('requiresPro', () => {
  it('returns true for bios-guide', () => {
    expect(requiresPro('bios-guide')).toBe(true);
  });

  it('returns false for non-pro pages', () => {
    expect(requiresPro('dashboard')).toBe(false);
    expect(requiresPro('advanced')).toBe(false);
    expect(requiresPro('gpu-guide')).toBe(false);
  });
});

describe('PRO_PAGES', () => {
  it('contains bios-guide', () => {
    expect(PRO_PAGES.has('bios-guide')).toBe(true);
  });

  it('does not contain non-pro pages', () => {
    expect(PRO_PAGES.has('dashboard')).toBe(false);
  });
});
