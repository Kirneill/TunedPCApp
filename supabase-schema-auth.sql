-- SENSEQUALITY Optimizer — Auth & Waitlist Schema
-- Run this in your Supabase SQL Editor AFTER supabase-schema.sql
-- This is additive — does NOT modify telemetry_events table.
--
-- Prereqs:
-- 1. Enable email/password auth in Supabase Dashboard (Settings > Authentication)
-- 2. Disable email confirmation for frictionless desktop sign-up

-- ─── User Machines (hardware tie-in) ─────────────────────

CREATE TABLE IF NOT EXISTS user_machines (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  machine_id TEXT NOT NULL,
  machine_name TEXT,
  gpu TEXT,
  cpu TEXT,
  ram_gb INTEGER,
  os_build TEXT,
  registered_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  last_seen_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  is_active BOOLEAN DEFAULT true NOT NULL,
  UNIQUE(user_id, machine_id)
);

ALTER TABLE user_machines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own machines" ON user_machines;
CREATE POLICY "Users read own machines"
  ON user_machines FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users update own machines" ON user_machines;
CREATE POLICY "Users update own machines"
  ON user_machines FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id);

-- No direct INSERT policy — all inserts go through register_machine RPC
DROP POLICY IF EXISTS "Service role full access machines" ON user_machines;
CREATE POLICY "Service role full access machines"
  ON user_machines FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_user_machines_user_id ON user_machines(user_id);
CREATE INDEX IF NOT EXISTS idx_user_machines_machine_id ON user_machines(machine_id);

-- ─── Feature Waitlist ────────────────────────────────────

CREATE TABLE IF NOT EXISTS waitlist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  feature_name TEXT NOT NULL,
  UNIQUE(user_id, feature_name)
);

ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own waitlist" ON waitlist;
CREATE POLICY "Users read own waitlist"
  ON waitlist FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

-- No direct INSERT policy — all inserts go through join_waitlist RPC
DROP POLICY IF EXISTS "Service role full access waitlist" ON waitlist;
CREATE POLICY "Service role full access waitlist"
  ON waitlist FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ─── RPCs (SECURITY DEFINER) ─────────────────────────────
-- These run as the function owner (postgres), not the calling user.
-- This ensures transactional enforcement of business rules.

-- Register a machine with max-2-active enforcement
CREATE OR REPLACE FUNCTION register_machine(
  p_machine_id TEXT,
  p_machine_name TEXT DEFAULT NULL,
  p_gpu TEXT DEFAULT NULL,
  p_cpu TEXT DEFAULT NULL,
  p_ram_gb INTEGER DEFAULT NULL,
  p_os_build TEXT DEFAULT NULL
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

  -- Check if this exact machine is already registered for this user
  SELECT * INTO v_existing
  FROM user_machines
  WHERE user_id = v_user_id AND machine_id = p_machine_id;

  IF FOUND THEN
    -- Machine exists — update last_seen and reactivate if needed
    UPDATE user_machines
    SET last_seen_at = now(),
        is_active = true,
        deactivated_at = NULL,
        machine_name = COALESCE(p_machine_name, machine_name),
        gpu = COALESCE(p_gpu, gpu),
        cpu = COALESCE(p_cpu, cpu),
        ram_gb = COALESCE(p_ram_gb, ram_gb),
        os_build = COALESCE(p_os_build, os_build)
    WHERE user_id = v_user_id AND machine_id = p_machine_id;

    RETURN jsonb_build_object('success', true, 'reason', 'registered');
  END IF;

  -- New machine — check active count
  SELECT COUNT(*) INTO v_active_count
  FROM user_machines
  WHERE user_id = v_user_id AND is_active = true;

  IF v_active_count >= 2 THEN
    -- Return list of active machines so client can show deactivation UI
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

  -- Insert new machine
  INSERT INTO user_machines (user_id, machine_id, machine_name, gpu, cpu, ram_gb, os_build)
  VALUES (v_user_id, p_machine_id, p_machine_name, p_gpu, p_cpu, p_ram_gb, p_os_build);

  RETURN jsonb_build_object('success', true, 'reason', 'new');
END;
$$;

-- Deactivate a machine
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
  SET is_active = false
  WHERE user_id = v_user_id AND machine_id = p_machine_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Join a feature waitlist (derives email from auth context)
CREATE OR REPLACE FUNCTION join_waitlist(p_feature_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  INSERT INTO waitlist (user_id, email, feature_name)
  VALUES (v_user_id, v_email, p_feature_name)
  ON CONFLICT (user_id, feature_name) DO NOTHING;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Check if user has joined a waitlist
CREATE OR REPLACE FUNCTION has_joined_waitlist(p_feature_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM waitlist
    WHERE user_id = v_user_id AND feature_name = p_feature_name
  );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION register_machine TO authenticated;
GRANT EXECUTE ON FUNCTION deactivate_machine TO authenticated;
GRANT EXECUTE ON FUNCTION join_waitlist TO authenticated;
GRANT EXECUTE ON FUNCTION has_joined_waitlist TO authenticated;
