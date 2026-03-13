/**
 * Feature tier gating for SENSEQUALITY Pro.
 *
 * Free tier: All Windows optimizations + all game configs
 * Pro tier ($20/mo): BIOS Optimization (interactive guide + guided automatic tuning)
 */

import type { SubscriptionStatus } from '../types';

export type Plan = 'free' | 'pro' | 'dev';

/** Subscription statuses that grant Pro access. Includes 'past_due' for payment grace period
 *  and 'canceled' so users retain access until their billing period ends. */
const ACTIVE_STATUSES: ReadonlySet<SubscriptionStatus> = new Set(['active', 'trialing', 'past_due', 'canceled']);

/** Page IDs that require Pro subscription */
export const PRO_PAGES = new Set<string>([
  'bios-guide',
]);

/** Check if a page requires Pro */
export function requiresPro(pageId: string): boolean {
  return PRO_PAGES.has(pageId);
}

/** Check if a subscription status grants access to Pro features */
export function isProActive(status: SubscriptionStatus): boolean {
  return ACTIVE_STATUSES.has(status);
}
