-- SENSEQUALITY Optimizer — Telemetry Schema
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard → SQL Editor
--
-- Setup steps:
-- 1. Create a free project at https://supabase.com
-- 2. Go to SQL Editor and run this entire file
-- 3. Go to Settings → API, copy the Project URL and anon/public key
-- 4. Paste them into electron/telemetry/config.ts
-- 5. Set TELEMETRY_CONFIGURED = true

-- Main telemetry events table
CREATE TABLE IF NOT EXISTS telemetry_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  -- Anonymous machine identifier (SHA-256 hash, not personally identifiable)
  anonymous_id TEXT NOT NULL,

  -- Event classification
  event_type TEXT NOT NULL CHECK (event_type IN ('app_launch', 'optimization_run', 'optimization_result')),

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

  -- App metadata
  app_version TEXT
);

-- Indexes for common queries
CREATE INDEX idx_telemetry_anonymous_id ON telemetry_events (anonymous_id);
CREATE INDEX idx_telemetry_event_type ON telemetry_events (event_type);
CREATE INDEX idx_telemetry_created_at ON telemetry_events (created_at DESC);
CREATE INDEX idx_telemetry_gpu ON telemetry_events (gpu);
CREATE INDEX idx_telemetry_success ON telemetry_events (success);

-- Row Level Security: allow anonymous inserts, restrict reads to service role
ALTER TABLE telemetry_events ENABLE ROW LEVEL SECURITY;

-- Allow the anon key to INSERT (the app sends data)
CREATE POLICY "Allow anonymous inserts"
  ON telemetry_events
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Only the service_role (your dashboard / backend) can read data
CREATE POLICY "Service role can read all"
  ON telemetry_events
  FOR SELECT
  TO service_role
  USING (true);

-- ─── Useful Views for Analysis ───────────────────────────

-- Hardware distribution: what GPU/CPU combos are your users on?
CREATE OR REPLACE VIEW hardware_distribution AS
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

-- Optimization success rates: which settings fail most often?
CREATE OR REPLACE VIEW optimization_success_rates AS
SELECT
  unnest(settings_applied) AS setting_id,
  COUNT(*) AS total_runs,
  COUNT(*) FILTER (WHERE success = true) AS successful,
  COUNT(*) FILTER (WHERE success = false) AS failed,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE success = true) / NULLIF(COUNT(*), 0),
    1
  ) AS success_rate_pct,
  ROUND(AVG(duration_ms)) AS avg_duration_ms
FROM telemetry_events
WHERE event_type = 'optimization_result'
GROUP BY setting_id
ORDER BY failed DESC;

-- GPU-specific failure patterns
CREATE OR REPLACE VIEW gpu_failure_patterns AS
SELECT
  gpu,
  unnest(settings_applied) AS setting_id,
  COUNT(*) AS total_runs,
  COUNT(*) FILTER (WHERE success = false) AS failures,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE success = false) / NULLIF(COUNT(*), 0),
    1
  ) AS failure_rate_pct
FROM telemetry_events
WHERE event_type = 'optimization_result'
GROUP BY gpu, setting_id
HAVING COUNT(*) FILTER (WHERE success = false) > 0
ORDER BY failures DESC;

-- Daily active users
CREATE OR REPLACE VIEW daily_active_users AS
SELECT
  DATE(created_at) AS day,
  COUNT(DISTINCT anonymous_id) AS unique_users,
  COUNT(*) FILTER (WHERE event_type = 'optimization_result') AS optimizations_run
FROM telemetry_events
GROUP BY DATE(created_at)
ORDER BY day DESC;
