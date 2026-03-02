-- ============================================================
-- SENSEQUALITY Optimizer — Schema Improvements v2
-- Run in Supabase SQL Editor AFTER supabase-schema.sql and supabase-schema-auth.sql
-- All statements are idempotent (safe to re-run)
-- ============================================================

-- ─── 1. ADD MISSING COLUMNS TO telemetry_events ─────────────

ALTER TABLE telemetry_events
  ADD COLUMN IF NOT EXISTS cpu_cores SMALLINT,
  ADD COLUMN IF NOT EXISTS cpu_threads SMALLINT,
  ADD COLUMN IF NOT EXISTS gpu_vram_gb SMALLINT,
  ADD COLUMN IF NOT EXISTS gpu_vendor VARCHAR(16),
  ADD COLUMN IF NOT EXISTS monitor_resolution VARCHAR(20),
  ADD COLUMN IF NOT EXISTS monitor_refresh_hz SMALLINT,
  ADD COLUMN IF NOT EXISTS run_id VARCHAR(64),
  ADD COLUMN IF NOT EXISTS user_id UUID;

COMMENT ON COLUMN telemetry_events.cpu_cores IS 'Physical CPU cores';
COMMENT ON COLUMN telemetry_events.cpu_threads IS 'Logical CPU threads';
COMMENT ON COLUMN telemetry_events.gpu_vram_gb IS 'GPU VRAM in GB';
COMMENT ON COLUMN telemetry_events.gpu_vendor IS 'nvidia, amd, intel, or other';
COMMENT ON COLUMN telemetry_events.monitor_resolution IS 'e.g. 1920x1080';
COMMENT ON COLUMN telemetry_events.monitor_refresh_hz IS 'e.g. 240';
COMMENT ON COLUMN telemetry_events.run_id IS 'Client-generated run ID for correlating events';
COMMENT ON COLUMN telemetry_events.user_id IS 'Optional: authenticated user UUID (null if anonymous-only)';

-- ─── 2. ADD MISSING COLUMNS TO user_machines ────────────────

ALTER TABLE user_machines
  ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS app_version VARCHAR(32),
  ADD COLUMN IF NOT EXISTS gpu_driver VARCHAR(128),
  ADD COLUMN IF NOT EXISTS gpu_vram_gb SMALLINT;

-- Partial index for JOINs on run_id (used by gpu_failure_patterns view)
CREATE INDEX IF NOT EXISTS idx_telemetry_run_id
  ON telemetry_events (run_id)
  WHERE run_id IS NOT NULL;

-- ─── 3. TIGHTEN CONSTRAINTS ─────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'telemetry_events_duration_ms_check'
  ) THEN
    ALTER TABLE telemetry_events
      ADD CONSTRAINT telemetry_events_duration_ms_check CHECK (duration_ms >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'telemetry_events_error_count_check'
  ) THEN
    ALTER TABLE telemetry_events
      ADD CONSTRAINT telemetry_events_error_count_check CHECK (error_count >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'telemetry_events_ram_gb_check'
  ) THEN
    ALTER TABLE telemetry_events
      ADD CONSTRAINT telemetry_events_ram_gb_check CHECK (ram_gb IS NULL OR (ram_gb >= 0 AND ram_gb <= 1024));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'telemetry_events_settings_applied_size_check'
  ) THEN
    ALTER TABLE telemetry_events
      ADD CONSTRAINT telemetry_events_settings_applied_size_check
      CHECK (cardinality(settings_applied) <= 50);
  END IF;
END;
$$;

-- ─── 4. REPLACE LOW-VALUE INDEXES WITH TARGETED ONES ────────

-- Drop low-selectivity / unused indexes
DROP INDEX IF EXISTS idx_telemetry_event_type;
DROP INDEX IF EXISTS idx_telemetry_success;
DROP INDEX IF EXISTS idx_telemetry_failure_stage;
DROP INDEX IF EXISTS idx_telemetry_error_fingerprint;

-- Partial index: optimization results only (filters to event_type = 'optimization_result')
CREATE INDEX IF NOT EXISTS idx_telemetry_opt_results
  ON telemetry_events (gpu, success, created_at DESC)
  WHERE event_type = 'optimization_result';

-- Partial index: app launches for hardware distribution
CREATE INDEX IF NOT EXISTS idx_telemetry_launches
  ON telemetry_events (anonymous_id, gpu, cpu, ram_gb)
  WHERE event_type = 'app_launch';

-- Partial index: failures only (small subset, high-value for debugging)
CREATE INDEX IF NOT EXISTS idx_telemetry_failures
  ON telemetry_events (failure_stage, error_fingerprint, created_at DESC)
  WHERE success = false;

-- Note: DATE(created_at) expression index is not possible on TIMESTAMPTZ
-- (DATE is STABLE, not IMMUTABLE due to timezone dependence).
-- The existing idx_telemetry_created_at covers time-range queries adequately.

-- ─── 5. OPTIMIZATION RUN DETAILS TABLE ──────────────────────
-- Captures per-setting success/failure within a run

CREATE TABLE IF NOT EXISTS optimization_run_details (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  anonymous_id VARCHAR(128) NOT NULL,
  run_id VARCHAR(64) NOT NULL,
  setting_id VARCHAR(64) NOT NULL,
  success BOOLEAN NOT NULL,
  failure_reason TEXT,
  duration_ms INTEGER CHECK (duration_ms >= 0),
  app_version VARCHAR(32)
);

ALTER TABLE optimization_run_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anonymous inserts on run details" ON optimization_run_details;
CREATE POLICY "Allow anonymous inserts on run details"
  ON optimization_run_details
  FOR INSERT TO anon
  WITH CHECK (
    anonymous_id IS NOT NULL
    AND length(anonymous_id) <= 128
    AND setting_id IS NOT NULL
    AND (failure_reason IS NULL OR length(failure_reason) <= 2048)
    AND length(run_id) <= 64
  );

DROP POLICY IF EXISTS "Service role reads run details" ON optimization_run_details;
CREATE POLICY "Service role reads run details"
  ON optimization_run_details
  FOR SELECT TO service_role
  USING (true);

CREATE INDEX IF NOT EXISTS idx_run_details_run_id
  ON optimization_run_details (run_id);

CREATE INDEX IF NOT EXISTS idx_run_details_setting_success
  ON optimization_run_details (setting_id, success);

-- ─── 6. USER PREFERENCES TABLE ──────────────────────────────
-- Server-side backup of user config (monitor, GPU mode, etc.)

CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  machine_id VARCHAR(128) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  monitor_width SMALLINT,
  monitor_height SMALLINT,
  monitor_refresh_hz SMALLINT,
  gpu_mode VARCHAR(16) CHECK (gpu_mode IN ('auto', 'manual')),
  selected_gpu_id TEXT,
  cs2_stretched BOOLEAN DEFAULT false,
  restore_point_enabled BOOLEAN DEFAULT true,
  enabled_optimizations TEXT[] DEFAULT '{}',
  UNIQUE(user_id, machine_id)
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own preferences" ON user_preferences;
CREATE POLICY "Users read own preferences"
  ON user_preferences FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users upsert own preferences" ON user_preferences;
CREATE POLICY "Users upsert own preferences"
  ON user_preferences FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users update own preferences" ON user_preferences;
CREATE POLICY "Users update own preferences"
  ON user_preferences FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Service role full access preferences" ON user_preferences;
CREATE POLICY "Service role full access preferences"
  ON user_preferences FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ─── 7. INSTALLED GAMES SNAPSHOT TABLE ───────────────────────

CREATE TABLE IF NOT EXISTS machine_installed_games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  anonymous_id VARCHAR(128) NOT NULL,
  detected_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  game_id VARCHAR(64) NOT NULL,
  installed BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(anonymous_id, game_id)
);

ALTER TABLE machine_installed_games ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anonymous inserts on installed games" ON machine_installed_games;
CREATE POLICY "Allow anonymous inserts on installed games"
  ON machine_installed_games
  FOR INSERT TO anon
  WITH CHECK (
    anonymous_id IS NOT NULL
    AND length(anonymous_id) <= 128
  );

-- Restrict anon UPDATE to rows matching the same anonymous_id (prevents cross-user overwrites).
-- The anonymous_id column is included in the ON CONFLICT for upserts, so the USING clause
-- effectively scopes updates to the caller's own rows.
DROP POLICY IF EXISTS "Allow anonymous updates on installed games" ON machine_installed_games;
CREATE POLICY "Allow anonymous updates on installed games"
  ON machine_installed_games
  FOR UPDATE TO anon
  USING (anonymous_id IS NOT NULL AND length(anonymous_id) <= 128)
  WITH CHECK (anonymous_id IS NOT NULL AND length(anonymous_id) <= 128);

DROP POLICY IF EXISTS "Service role reads installed games" ON machine_installed_games;
CREATE POLICY "Service role reads installed games"
  ON machine_installed_games
  FOR SELECT TO service_role
  USING (true);

-- ─── 8. AUDIT LOG TABLE ─────────────────────────────────────
-- Tracks auth events and machine management actions

CREATE TABLE IF NOT EXISTS audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action VARCHAR(64) NOT NULL,
  detail JSONB DEFAULT '{}'::jsonb,
  ip_address INET
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access audit" ON audit_log;
CREATE POLICY "Service role full access audit"
  ON audit_log FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);

-- ─── 9. UPDATE deactivate_machine TO RECORD TIMESTAMP ───────

CREATE OR REPLACE FUNCTION deactivate_machine(p_machine_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  UPDATE user_machines
  SET is_active = false,
      deactivated_at = now()
  WHERE user_id = v_user_id AND machine_id = p_machine_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;

  -- Audit trail
  INSERT INTO audit_log (user_id, action, detail)
  VALUES (v_user_id, 'machine_deactivated', jsonb_build_object(
    'machine_id', p_machine_id
  ));

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION deactivate_machine TO authenticated;

-- ─── 9B. UPDATE register_machine TO POPULATE V2 COLUMNS ────

-- Drop the old 6-param overload so we don't end up with two ambiguous functions
DROP FUNCTION IF EXISTS register_machine(TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT);

CREATE OR REPLACE FUNCTION register_machine(
  p_machine_id TEXT,
  p_machine_name TEXT DEFAULT NULL,
  p_gpu TEXT DEFAULT NULL,
  p_cpu TEXT DEFAULT NULL,
  p_ram_gb INTEGER DEFAULT NULL,
  p_os_build TEXT DEFAULT NULL,
  p_app_version VARCHAR(32) DEFAULT NULL,
  p_gpu_driver VARCHAR(128) DEFAULT NULL,
  p_gpu_vram_gb SMALLINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_existing RECORD;
  v_active_count INTEGER;
  v_machines JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_existing
  FROM user_machines
  WHERE user_id = v_user_id AND machine_id = p_machine_id;

  IF FOUND THEN
    UPDATE user_machines
    SET last_seen_at = now(),
        is_active = true,
        deactivated_at = NULL,
        machine_name = COALESCE(p_machine_name, machine_name),
        gpu = COALESCE(p_gpu, gpu),
        cpu = COALESCE(p_cpu, cpu),
        ram_gb = COALESCE(p_ram_gb, ram_gb),
        os_build = COALESCE(p_os_build, os_build),
        app_version = COALESCE(p_app_version, app_version),
        gpu_driver = COALESCE(p_gpu_driver, gpu_driver),
        gpu_vram_gb = COALESCE(p_gpu_vram_gb, gpu_vram_gb)
    WHERE user_id = v_user_id AND machine_id = p_machine_id;

    RETURN jsonb_build_object('success', true, 'reason', 'registered');
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM user_machines
  WHERE user_id = v_user_id AND is_active = true;

  IF v_active_count >= 2 THEN
    SELECT jsonb_agg(jsonb_build_object(
      'id', id::text,
      'machine_id', machine_id,
      'machine_name', machine_name,
      'gpu', gpu,
      'cpu', cpu,
      'ram_gb', ram_gb,
      'os_build', os_build,
      'registered_at', registered_at,
      'last_seen_at', last_seen_at,
      'is_active', is_active
    )) INTO v_machines
    FROM user_machines
    WHERE user_id = v_user_id AND is_active = true;

    RETURN jsonb_build_object(
      'success', false,
      'reason', 'max_devices',
      'machines', COALESCE(v_machines, '[]'::jsonb)
    );
  END IF;

  INSERT INTO user_machines (
    user_id, machine_id, machine_name, gpu, cpu, ram_gb, os_build,
    app_version, gpu_driver, gpu_vram_gb
  )
  VALUES (
    v_user_id, p_machine_id, p_machine_name, p_gpu, p_cpu, p_ram_gb, p_os_build,
    p_app_version, p_gpu_driver, p_gpu_vram_gb
  );

  RETURN jsonb_build_object('success', true, 'reason', 'new');
END;
$$;

GRANT EXECUTE ON FUNCTION register_machine(TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, VARCHAR, VARCHAR, SMALLINT) TO authenticated;

-- ─── 10. IMPROVED ANALYTICS VIEWS ───────────────────────────

-- Version adoption tracking
CREATE OR REPLACE VIEW version_adoption
  WITH (security_invoker = true)
AS
SELECT
  app_version,
  DATE(MIN(created_at)) AS first_seen,
  COUNT(DISTINCT anonymous_id) AS unique_machines,
  COUNT(*) AS total_events,
  DATE(MAX(created_at)) AS last_seen
FROM telemetry_events
WHERE app_version IS NOT NULL
GROUP BY app_version
ORDER BY first_seen DESC;

REVOKE ALL ON version_adoption FROM anon, authenticated;
GRANT SELECT ON version_adoption TO service_role;

-- Per-setting failure rates (uses optimization_run_details table)
CREATE OR REPLACE VIEW setting_failure_rates
  WITH (security_invoker = true)
AS
SELECT
  setting_id,
  COUNT(*) AS total_runs,
  COUNT(*) FILTER (WHERE success = true) AS successful,
  COUNT(*) FILTER (WHERE success = false) AS failed,
  ROUND(100.0 * COUNT(*) FILTER (WHERE success = false) / NULLIF(COUNT(*), 0), 1) AS failure_rate_pct,
  COUNT(DISTINCT anonymous_id) AS unique_machines,
  mode() WITHIN GROUP (ORDER BY failure_reason) AS most_common_failure
FROM optimization_run_details
GROUP BY setting_id
ORDER BY failed DESC;

REVOKE ALL ON setting_failure_rates FROM anon, authenticated;
GRANT SELECT ON setting_failure_rates TO service_role;

-- Weekly retention cohorts
CREATE OR REPLACE VIEW weekly_retention_cohorts
  WITH (security_invoker = true)
AS
WITH first_seen AS (
  SELECT
    anonymous_id,
    DATE_TRUNC('week', MIN(created_at))::DATE AS cohort_week
  FROM telemetry_events
  WHERE event_type = 'app_launch'
  GROUP BY anonymous_id
),
activity AS (
  SELECT DISTINCT
    anonymous_id,
    DATE_TRUNC('week', created_at)::DATE AS active_week
  FROM telemetry_events
  WHERE event_type = 'app_launch'
)
SELECT
  fs.cohort_week,
  COUNT(DISTINCT fs.anonymous_id) AS cohort_size,
  (a.active_week - fs.cohort_week) / 7 AS weeks_since_signup,
  COUNT(DISTINCT a.anonymous_id) AS retained_users,
  ROUND(
    100.0 * COUNT(DISTINCT a.anonymous_id) / NULLIF(COUNT(DISTINCT fs.anonymous_id), 0),
    1
  ) AS retention_pct
FROM first_seen fs
JOIN activity a ON fs.anonymous_id = a.anonymous_id
  AND a.active_week >= fs.cohort_week
GROUP BY fs.cohort_week, (a.active_week - fs.cohort_week) / 7
ORDER BY fs.cohort_week DESC, weeks_since_signup;

REVOKE ALL ON weekly_retention_cohorts FROM anon, authenticated;
GRANT SELECT ON weekly_retention_cohorts TO service_role;

-- Game popularity: which games are installed most
CREATE OR REPLACE VIEW game_popularity
  WITH (security_invoker = true)
AS
SELECT
  game_id,
  COUNT(*) FILTER (WHERE installed = true) AS installed_count,
  COUNT(*) AS total_machines,
  ROUND(100.0 * COUNT(*) FILTER (WHERE installed = true) / NULLIF(COUNT(*), 0), 1) AS install_rate_pct
FROM machine_installed_games
GROUP BY game_id
ORDER BY installed_count DESC;

REVOKE ALL ON game_popularity FROM anon, authenticated;
GRANT SELECT ON game_popularity TO service_role;

-- Error fingerprint clustering: which errors hit which hardware
CREATE OR REPLACE VIEW error_hotspots
  WITH (security_invoker = true)
AS
SELECT
  error_fingerprint,
  failure_stage,
  gpu,
  gpu_vendor,
  COUNT(*) AS occurrences,
  COUNT(DISTINCT anonymous_id) AS affected_machines,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen,
  MAX(app_version) AS latest_app_version
FROM telemetry_events
WHERE success = false
  AND error_fingerprint IS NOT NULL
GROUP BY error_fingerprint, failure_stage, gpu, gpu_vendor
ORDER BY occurrences DESC;

REVOKE ALL ON error_hotspots FROM anon, authenticated;
GRANT SELECT ON error_hotspots TO service_role;

-- Per-setting failure rates broken down by GPU model.
-- JOINs optimization_run_details (per-setting success) with
-- telemetry_events (hardware info) via run_id.
CREATE OR REPLACE VIEW gpu_failure_patterns
  WITH (security_invoker = true)
AS
SELECT
  te.gpu,
  te.gpu_vendor,
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
JOIN telemetry_events te
  ON te.run_id = rd.run_id
  AND te.event_type = 'optimization_result'
GROUP BY te.gpu, te.gpu_vendor, rd.setting_id
HAVING COUNT(*) FILTER (WHERE rd.success = false) > 0
ORDER BY failures DESC;

REVOKE ALL ON gpu_failure_patterns FROM anon, authenticated;
GRANT SELECT ON gpu_failure_patterns TO service_role;

-- Optimization combo popularity: what do users run together
CREATE OR REPLACE VIEW optimization_combos
  WITH (security_invoker = true)
AS
SELECT
  settings_applied,
  cardinality(settings_applied) AS num_settings,
  COUNT(*) AS times_run,
  COUNT(DISTINCT anonymous_id) AS unique_machines,
  ROUND(100.0 * COUNT(*) FILTER (WHERE success = true) / NULLIF(COUNT(*), 0), 1) AS success_rate_pct
FROM telemetry_events
WHERE event_type = 'optimization_result'
  AND cardinality(settings_applied) > 0
GROUP BY settings_applied
ORDER BY times_run DESC
LIMIT 50;

REVOKE ALL ON optimization_combos FROM anon, authenticated;
GRANT SELECT ON optimization_combos TO service_role;

-- Monitor resolution distribution
CREATE OR REPLACE VIEW monitor_distribution
  WITH (security_invoker = true)
AS
SELECT
  monitor_resolution,
  monitor_refresh_hz,
  COUNT(DISTINCT anonymous_id) AS unique_machines,
  COUNT(*) AS total_events
FROM telemetry_events
WHERE event_type IN ('app_launch', 'optimization_result')
  AND monitor_resolution IS NOT NULL
GROUP BY monitor_resolution, monitor_refresh_hz
ORDER BY unique_machines DESC;

REVOKE ALL ON monitor_distribution FROM anon, authenticated;
GRANT SELECT ON monitor_distribution TO service_role;

-- ─── 11. UPDATE RLS POLICY FOR NEW COLUMNS ──────────────────

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
    AND (gpu_vendor IS NULL OR length(gpu_vendor) <= 16)
    AND (monitor_resolution IS NULL OR length(monitor_resolution) <= 20)
    AND (run_id IS NULL OR length(run_id) <= 64)
  );
