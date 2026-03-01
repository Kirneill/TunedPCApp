-- SENSEQUALITY Optimizer — Telemetry Schema
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard → SQL Editor
--
-- Setup steps:
-- 1. Create a free project at https://supabase.com
-- 2. Go to SQL Editor and run this entire file (views may fail — that's expected)
-- 3. Run supabase-schema-auth.sql (creates user_machines + waitlist tables)
-- 4. Run supabase-schema-v2.sql (adds columns to telemetry_events & user_machines, creates optimization_run_details)
-- 5. Re-run this file (views will now succeed since v2.sql tables/columns exist)
-- 6. Go to Settings → API, copy the Project URL and anon/public key
-- 7. Paste them into electron/telemetry/config.ts
-- 8. Set TELEMETRY_CONFIGURED = true

-- Main telemetry events table
CREATE TABLE IF NOT EXISTS telemetry_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  -- Anonymous machine identifier (SHA-256 hash, not personally identifiable)
  anonymous_id TEXT NOT NULL,

  -- Event classification
  event_type TEXT NOT NULL CHECK (event_type IN ('app_launch', 'optimization_run', 'optimization_result', 'optimization_failure')),

  -- Hardware fingerprint
  gpu TEXT,
  cpu TEXT,
  ram_gb INTEGER,
  os_build TEXT,
  gpu_driver TEXT,

  -- Optimization details
  settings_applied TEXT[] DEFAULT '{}',
  game_id TEXT,
  duration_ms INTEGER,
  success BOOLEAN,
  error_count INTEGER DEFAULT 0,
  failure_stage TEXT,
  error_fingerprint TEXT,

  -- App metadata
  app_version TEXT
);

-- Migration safety for existing projects:
-- 1) Ensure event_type constraint includes optimization_failure
ALTER TABLE telemetry_events
  DROP CONSTRAINT IF EXISTS telemetry_events_event_type_check;

ALTER TABLE telemetry_events
  ADD CONSTRAINT telemetry_events_event_type_check
  CHECK (event_type IN ('app_launch', 'optimization_run', 'optimization_result', 'optimization_failure'));

-- 2) Ensure new failure telemetry columns exist
ALTER TABLE telemetry_events
  ADD COLUMN IF NOT EXISTS failure_stage TEXT;

ALTER TABLE telemetry_events
  ADD COLUMN IF NOT EXISTS error_fingerprint TEXT;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_telemetry_anonymous_id ON telemetry_events (anonymous_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_event_type ON telemetry_events (event_type);
CREATE INDEX IF NOT EXISTS idx_telemetry_created_at ON telemetry_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_gpu ON telemetry_events (gpu);
CREATE INDEX IF NOT EXISTS idx_telemetry_success ON telemetry_events (success);
CREATE INDEX IF NOT EXISTS idx_telemetry_failure_stage ON telemetry_events (failure_stage);
CREATE INDEX IF NOT EXISTS idx_telemetry_error_fingerprint ON telemetry_events (error_fingerprint);

-- Row Level Security: allow anonymous inserts, restrict reads to service role
ALTER TABLE telemetry_events ENABLE ROW LEVEL SECURITY;

-- Allow the anon key to INSERT (the app sends data)
-- Basic validation: require anonymous_id and event_type (columns are NOT NULL anyway)
-- and limit payload size by constraining text field lengths
DROP POLICY IF EXISTS "Allow anonymous inserts" ON telemetry_events;
CREATE POLICY "Allow anonymous inserts"
  ON telemetry_events
  FOR INSERT
  TO anon
  WITH CHECK (
    anonymous_id IS NOT NULL
    AND length(anonymous_id) <= 128
    AND event_type IS NOT NULL
    AND (app_version IS NULL OR length(app_version) <= 32)
  );

-- Only the service_role (your dashboard / backend) can read data
DROP POLICY IF EXISTS "Service role can read all" ON telemetry_events;
CREATE POLICY "Service role can read all"
  ON telemetry_events
  FOR SELECT
  TO service_role
  USING (true);

-- ─── Useful Views for Analysis ───────────────────────────
-- IMPORTANT: These views require tables and columns from supabase-schema-v2.sql:
-- - optimization_run_details table (optimization_success_rates, gpu_failure_patterns)
-- - run_id and gpu_vendor columns on telemetry_events (gpu_failure_patterns)
-- On fresh deployments, run auth.sql then v2.sql first, then re-run this file.

-- Hardware distribution: what GPU/CPU combos are your users on?
-- SECURITY INVOKER: view respects caller's RLS (access restricted to service_role via GRANT below)
CREATE OR REPLACE VIEW hardware_distribution
  WITH (security_invoker = true)
AS
SELECT
  gpu,
  cpu,
  ram_gb,
  COUNT(DISTINCT anonymous_id) AS unique_users,
  COUNT(*) AS total_events
FROM telemetry_events
WHERE event_type = 'app_launch'
GROUP BY gpu, cpu, ram_gb
ORDER BY unique_users DESC;

-- Optimization success rates: per-setting accuracy via optimization_run_details
-- (Uses granular per-setting success, NOT the misleading overall run success flag)
CREATE OR REPLACE VIEW optimization_success_rates
  WITH (security_invoker = true)
AS
SELECT
  rd.setting_id,
  COUNT(*) AS total_runs,
  COUNT(*) FILTER (WHERE rd.success = true) AS successful,
  COUNT(*) FILTER (WHERE rd.success = false) AS failed,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE rd.success = true) / NULLIF(COUNT(*), 0),
    1
  ) AS success_rate_pct,
  COUNT(DISTINCT rd.anonymous_id) AS unique_machines,
  mode() WITHIN GROUP (ORDER BY rd.failure_reason) AS most_common_failure
FROM optimization_run_details rd
GROUP BY rd.setting_id
ORDER BY failed DESC;

-- GPU-specific failure patterns: JOINs per-setting results with hardware info
-- Uses a CTE to deduplicate telemetry_events to one row per run_id,
-- preventing count inflation when multiple events share the same run_id.
CREATE OR REPLACE VIEW gpu_failure_patterns
  WITH (security_invoker = true)
AS
WITH run_hardware AS (
  SELECT DISTINCT ON (run_id)
    run_id,
    gpu,
    gpu_vendor
  FROM telemetry_events
  WHERE event_type = 'optimization_result'
    AND run_id IS NOT NULL
  ORDER BY run_id, created_at DESC
)
SELECT
  rh.gpu,
  rh.gpu_vendor,
  rd.setting_id,
  COUNT(*) AS total_runs,
  COUNT(*) FILTER (WHERE rd.success = false) AS failures,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE rd.success = false) / NULLIF(COUNT(*), 0),
    1
  ) AS failure_rate_pct,
  COUNT(DISTINCT rd.anonymous_id) AS unique_machines,
  mode() WITHIN GROUP (ORDER BY rd.failure_reason) AS most_common_failure
FROM optimization_run_details rd
JOIN run_hardware rh ON rh.run_id = rd.run_id
GROUP BY rh.gpu, rh.gpu_vendor, rd.setting_id
HAVING COUNT(*) FILTER (WHERE rd.success = false) > 0
ORDER BY failures DESC;

-- Daily active users
CREATE OR REPLACE VIEW daily_active_users
  WITH (security_invoker = true)
AS
SELECT
  DATE(created_at) AS day,
  COUNT(DISTINCT anonymous_id) AS unique_users,
  COUNT(*) FILTER (WHERE event_type = 'optimization_result') AS optimizations_run
FROM telemetry_events
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- Restrict view access to service_role only (admin/dashboard)
REVOKE ALL ON hardware_distribution FROM anon, authenticated;
REVOKE ALL ON optimization_success_rates FROM anon, authenticated;
REVOKE ALL ON gpu_failure_patterns FROM anon, authenticated;
REVOKE ALL ON daily_active_users FROM anon, authenticated;
GRANT SELECT ON hardware_distribution TO service_role;
GRANT SELECT ON optimization_success_rates TO service_role;
GRANT SELECT ON gpu_failure_patterns TO service_role;
GRANT SELECT ON daily_active_users TO service_role;
