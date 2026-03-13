import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const AUTUMN_SECRET_KEY = Deno.env.get("AUTUMN_SECRET_KEY");
const AUTUMN_API_URL = "https://api.useautumn.com/v1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// CORS: Origin "*" is acceptable because every request requires a valid Supabase JWT
// (verified via supabase.auth.getUser). The JWT is the security boundary, not the origin.
// This function is called from an Electron app (no browser origin) so a restrictive
// origin would only block legitimate requests.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

/** Verify the caller's JWT and return their Supabase user ID. */
async function getAuthUserId(authHeader: string | null): Promise<{ userId: string; email: string } | Response> {
  if (!authHeader?.startsWith("Bearer ")) {
    return errorResponse("Missing or invalid Authorization header", 401);
  }

  const token = authHeader.slice(7);
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return errorResponse("Invalid or expired token", 401);
  }

  return { userId: user.id, email: user.email || "" };
}

/** Forward a request to the Autumn API. */
async function autumnFetch(
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<{ data: unknown; status: number }> {
  const res = await fetch(`${AUTUMN_API_URL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${AUTUMN_SECRET_KEY}`,
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  let data: unknown;
  try {
    data = await res.json();
  } catch {
    const text = await res.text().catch(() => "(unreadable body)");
    console.error(`[billing-proxy] Non-JSON response from Autumn: status=${res.status} body=${text.slice(0, 500)}`);
    data = null;
  }
  return { data, status: res.status };
}

// ─── Action Handlers ─────────────────────────────────────

async function handleCheck(userId: string, params: Record<string, unknown>): Promise<Response> {
  const featureId = params.feature_id;
  if (typeof featureId !== "string") {
    return errorResponse("feature_id is required");
  }

  const { data, status } = await autumnFetch("POST", "/check", {
    customer_id: userId,
    feature_id: featureId,
  });

  const allowed = (data as Record<string, unknown>)?.allowed ?? null;
  console.log(`[billing-proxy] check: userId=${userId} featureId=${featureId} status=${status} allowed=${allowed}`);

  return jsonResponse(data, status);
}

async function handleCheckout(userId: string, email: string, params: Record<string, unknown>): Promise<Response> {
  const productId = params.product_id;
  if (typeof productId !== "string") {
    return errorResponse("product_id is required");
  }

  const successUrl = typeof params.success_url === "string" ? params.success_url : undefined;
  const forceCheckout = params.force_checkout === true;

  const body: Record<string, unknown> = {
    customer_id: userId,
    product_id: productId,
    force_checkout: forceCheckout,
  };
  if (successUrl) body.success_url = successUrl;
  if (email) body.customer_data = { email };

  const { data, status } = await autumnFetch("POST", "/checkout", body);

  const respData = data as Record<string, unknown> | null;
  const hasCheckoutUrl = !!(respData?.checkout_url);
  console.log(`[billing-proxy] checkout: userId=${userId} productId=${productId} status=${status} hasCheckoutUrl=${hasCheckoutUrl}`);

  return jsonResponse(data, status);
}

async function handleCancel(userId: string, params: Record<string, unknown>): Promise<Response> {
  const productId = params.product_id;
  if (typeof productId !== "string") {
    return errorResponse("product_id is required");
  }

  const cancelImmediately = params.cancel_immediately === true;

  const { data, status } = await autumnFetch("POST", "/cancel", {
    customer_id: userId,
    product_id: productId,
    cancel_immediately: cancelImmediately,
  });

  console.log(`[billing-proxy] cancel: userId=${userId} productId=${productId} immediately=${cancelImmediately} status=${status}`);

  return jsonResponse(data, status);
}

async function handleGetCustomer(userId: string): Promise<Response> {
  const { data, status } = await autumnFetch("GET", `/customers/${encodeURIComponent(userId)}`);

  const respData = data as Record<string, unknown> | null;
  const products = Array.isArray(respData?.products)
    ? (respData!.products as Array<Record<string, unknown>>).map((p) => ({ id: p.id, status: p.status }))
    : [];
  console.log(`[billing-proxy] getCustomer: userId=${userId} status=${status} products=${JSON.stringify(products)}`);

  return jsonResponse(data, status);
}

async function handleBillingPortal(userId: string): Promise<Response> {
  const { data, status } = await autumnFetch("GET", `/customers/${encodeURIComponent(userId)}/billing-portal`);

  console.log(`[billing-proxy] billingPortal: userId=${userId} status=${status}`);

  return jsonResponse(data, status);
}

// ─── Main Handler ────────────────────────────────────────

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  if (!AUTUMN_SECRET_KEY) {
    return errorResponse("Billing not configured on server", 503);
  }

  // Authenticate
  const authResult = await getAuthUserId(req.headers.get("authorization"));
  if (authResult instanceof Response) return authResult;
  const { userId, email } = authResult;

  // Parse body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (err) {
    console.warn(`[billing-proxy] Invalid JSON body: ${err instanceof Error ? err.message : err}`);
    return errorResponse("Invalid JSON body");
  }

  const action = body.action;
  if (typeof action !== "string") {
    return errorResponse("action is required");
  }

  console.log(`[billing-proxy] action=${action} userId=${userId}`);

  try {
    switch (action) {
      case "check":
        return await handleCheck(userId, body);
      case "checkout":
      case "attach":  // backward compat
        return await handleCheckout(userId, email, body);
      case "cancel":
        return await handleCancel(userId, body);
      case "getCustomer":
        return await handleGetCustomer(userId);
      case "billingPortal":
        return await handleBillingPortal(userId);
      default:
        return errorResponse(`Unknown action: ${action}`);
    }
  } catch (err) {
    console.error(`[billing-proxy] ${action} failed:`, err);
    return errorResponse("Internal server error", 500);
  }
});
