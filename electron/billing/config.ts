// Billing configuration -- no secrets here, those live in the Supabase Edge Function.
import { SUPABASE_URL } from '../telemetry/config';

// Edge Function URL derived from the existing Supabase project URL
export const BILLING_PROXY_URL = `${SUPABASE_URL}/functions/v1/billing-proxy`;

// Product IDs -- must match what you create in the Autumn dashboard
export const AUTUMN_PRODUCTS = {
  pro: 'pro', // $10/month subscription
} as const;

// Feature IDs -- must match what you create in the Autumn dashboard
export const AUTUMN_FEATURES = {
  biosOptimizer: 'bios_optimizer', // Boolean feature gating the BIOS tab
} as const;

// Whether billing is enabled. Defaults true; set AUTUMN_BILLING=0 to disable in dev.
export const BILLING_CONFIGURED = process.env.AUTUMN_BILLING !== '0';
