import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { app } from 'electron';
import { createHash } from 'crypto';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { SUPABASE_URL, SUPABASE_ANON_KEY, TELEMETRY_CONFIGURED } from './config';

let supabase: SupabaseClient | null = null;
let anonymousId: string = '';
let consentGiven: boolean = false;

// Persistent config file for telemetry consent + anonymous ID
function getConfigPath(): string {
  return path.join(app.getPath('userData'), 'telemetry.json');
}

interface TelemetryConfig {
  anonymousId: string;
  consentGiven: boolean;
  consentDate: string | null;
}

function loadConfig(): TelemetryConfig {
  try {
    const data = fs.readFileSync(getConfigPath(), 'utf-8');
    return JSON.parse(data);
  } catch {
    return { anonymousId: '', consentGiven: false, consentDate: null };
  }
}

function saveConfig(config: TelemetryConfig): void {
  try {
    const dir = path.dirname(getConfigPath());
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(getConfigPath(), JSON.stringify(config, null, 2));
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[telemetry] Failed to save config: ${errorText}`);
  }
}

// Generate a stable anonymous ID from machine characteristics
// NOT personally identifiable — just a consistent hash per machine
export function generateAnonymousId(): string {
  const components = [
    process.env.COMPUTERNAME || '',
    process.env.PROCESSOR_IDENTIFIER || '',
    process.arch,
    os.totalmem().toString(),
  ];
  return createHash('sha256').update(components.join('|')).digest('hex').slice(0, 16);
}

// Get the current anonymous ID (available after initTelemetry)
export function getAnonymousId(): string {
  return anonymousId;
}

// Initialize telemetry system — call after app.whenReady()
export function initTelemetry(): void {
  const config = loadConfig();

  // Generate or load anonymous ID
  if (config.anonymousId) {
    anonymousId = config.anonymousId;
  } else {
    anonymousId = generateAnonymousId();
    config.anonymousId = anonymousId;
    saveConfig(config);
  }

  consentGiven = config.consentGiven;

  // Only create Supabase client if configured and consent given
  if (TELEMETRY_CONFIGURED && consentGiven) {
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
}

// Check if user has made a consent decision (first launch detection)
export function hasConsentDecision(): boolean {
  const config = loadConfig();
  return config.consentDate !== null;
}

// Get current consent status
export function getConsentStatus(): boolean {
  return consentGiven;
}

// Set consent — called from renderer via IPC
export function setConsent(granted: boolean): void {
  consentGiven = granted;

  const config = loadConfig();
  config.consentGiven = granted;
  config.consentDate = new Date().toISOString();
  saveConfig(config);

  if (granted && TELEMETRY_CONFIGURED) {
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } else {
    supabase = null;
  }
}

// ─── Event Types ──────────────────────────────────────────

export interface HardwareInfo {
  gpu: string;
  cpu: string;
  ram_gb: number;
  os_build: string;
  gpu_driver?: string;
  cpu_cores?: number;
  cpu_threads?: number;
  gpu_vram_gb?: number;
  gpu_vendor?: 'nvidia' | 'amd' | 'intel' | 'other';
}

export interface OptimizationEvent {
  event_type: 'optimization_run' | 'optimization_result' | 'optimization_failure' | 'app_launch';
  hardware: HardwareInfo;
  settings_applied?: string[];
  game_id?: string;
  duration_ms?: number;
  success?: boolean;
  error_count?: number;
  failure_stage?: FailureStage | null;
  error_fingerprint?: string | null;
  monitor_resolution?: string;
  monitor_refresh_hz?: number;
  run_id?: string;
}

export type FailureStage = 'restore-point' | 'elevation' | 'script-exit';

function normalizeErrorForFingerprint(input: string): string {
  return input
    .toLowerCase()
    .replace(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/g, '<guid>')
    .replace(/0x[a-f0-9]+/g, '<hex>')
    .replace(/[a-z]:\\[^\s'"`]+/g, '<path>')
    .replace(/\/[^\s'"`]+/g, '<path>')
    .replace(/\b\d+\b/g, '<num>')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 512);
}

function buildErrorFingerprint(stage: FailureStage, message: string): string | null {
  const normalized = normalizeErrorForFingerprint(message || 'unknown');
  if (!normalized) return null;
  return createHash('sha256').update(`${stage}|${normalized}`).digest('hex').slice(0, 24);
}

function getBestEffortHardware(): HardwareInfo {
  return {
    gpu: 'unknown',
    cpu: os.cpus()[0]?.model || 'unknown',
    ram_gb: Math.round(os.totalmem() / (1024 * 1024 * 1024)),
    os_build: os.release(),
  };
}

// ─── Send Telemetry ──────────────────────────────────────

export async function sendEvent(event: OptimizationEvent): Promise<void> {
  // Respect user's choice — never send without consent
  if (!consentGiven || !supabase) return;

  try {
    const { error } = await supabase.from('telemetry_events').insert({
      anonymous_id: anonymousId,
      event_type: event.event_type,
      gpu: event.hardware.gpu,
      cpu: event.hardware.cpu,
      ram_gb: event.hardware.ram_gb,
      os_build: event.hardware.os_build,
      gpu_driver: event.hardware.gpu_driver ?? null,
      cpu_cores: event.hardware.cpu_cores ?? null,
      cpu_threads: event.hardware.cpu_threads ?? null,
      gpu_vram_gb: event.hardware.gpu_vram_gb ?? null,
      gpu_vendor: event.hardware.gpu_vendor ?? null,
      settings_applied: event.settings_applied || [],
      game_id: event.game_id || null,
      duration_ms: event.duration_ms ?? null,
      success: event.success ?? null,
      error_count: event.error_count ?? 0,
      failure_stage: event.failure_stage || null,
      error_fingerprint: event.error_fingerprint || null,
      monitor_resolution: event.monitor_resolution || null,
      monitor_refresh_hz: event.monitor_refresh_hz ?? null,
      run_id: event.run_id || null,
      app_version: app.getVersion(),
    });
    if (error) {
      console.warn(`[telemetry] Supabase error on ${event.event_type}: ${error.message} (${error.code})`);
    }
  } catch (err) {
    // Telemetry should never break the app.
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[telemetry] Failed to send event ${event.event_type}: ${errorText}`);
  }
}

// Convenience: track app launch
export async function trackAppLaunch(hardware: HardwareInfo): Promise<void> {
  await sendEvent({ event_type: 'app_launch', hardware });
}

// Convenience: track optimization run start
export async function trackOptimizationStart(
  hardware: HardwareInfo,
  settingsApplied: string[],
): Promise<void> {
  await sendEvent({
    event_type: 'optimization_run',
    hardware,
    settings_applied: settingsApplied,
  });
}

export interface RunContext {
  run_id: string;
  monitor_resolution?: string;
  monitor_refresh_hz?: number;
}

// Convenience: track optimization result
export async function trackOptimizationResult(
  hardware: HardwareInfo,
  settingsApplied: string[],
  success: boolean,
  durationMs: number,
  errorCount: number,
  context?: RunContext,
): Promise<void> {
  await sendEvent({
    event_type: 'optimization_result',
    hardware,
    settings_applied: settingsApplied,
    success,
    duration_ms: durationMs,
    error_count: errorCount,
    monitor_resolution: context?.monitor_resolution,
    monitor_refresh_hz: context?.monitor_refresh_hz,
    run_id: context?.run_id,
  });
}

export async function trackFailureStage(
  failureStage: FailureStage,
  errorMessage: string,
  hardware?: HardwareInfo,
  settingsApplied: string[] = [],
): Promise<void> {
  await sendEvent({
    event_type: 'optimization_failure',
    hardware: hardware || getBestEffortHardware(),
    settings_applied: settingsApplied,
    success: false,
    error_count: 1,
    failure_stage: failureStage,
    error_fingerprint: buildErrorFingerprint(failureStage, errorMessage),
  });
}

// Send per-setting result to optimization_run_details table (consent-gated).
// Callers should use `void sendRunDetail(...)` for fire-and-forget behavior.
export async function sendRunDetail(detail: {
  run_id: string;
  setting_id: string;
  success: boolean;
  failure_reason?: string | null;
}): Promise<void> {
  if (!consentGiven || !supabase) return;
  try {
    const { error } = await supabase.from('optimization_run_details').insert({
      anonymous_id: anonymousId,
      run_id: detail.run_id,
      setting_id: detail.setting_id,
      success: detail.success,
      failure_reason: detail.failure_reason || null,
      app_version: app.getVersion(),
    });
    if (error) {
      console.warn(`[telemetry] Supabase error on run detail ${detail.setting_id}: ${error.message} (${error.code})`);
    }
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[telemetry] Failed to send run detail: ${errorText}`);
  }
}

// Upsert installed games snapshot to machine_installed_games (single batch request, consent-gated)
export async function trackInstalledGames(games: { id: string; installed: boolean }[]): Promise<void> {
  if (!consentGiven || !supabase || games.length === 0) return;
  try {
    const now = new Date().toISOString();
    const { error } = await supabase.from('machine_installed_games').upsert(
      games.map(game => ({
        anonymous_id: anonymousId,
        game_id: game.id,
        installed: game.installed,
        detected_at: now,
      })),
      { onConflict: 'anonymous_id,game_id' },
    );
    if (error) {
      console.warn(`[telemetry] Supabase error on installed games: ${error.message} (${error.code})`);
    }
  } catch (err) {
    const errorText = err instanceof Error ? err.message : String(err);
    console.warn(`[telemetry] Failed to send installed games: ${errorText}`);
  }
}
