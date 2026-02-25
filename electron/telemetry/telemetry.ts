import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { app } from 'electron';
import { createHash, randomUUID } from 'crypto';
import fs from 'fs';
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
  } catch {}
}

// Generate a stable anonymous ID from machine characteristics
// NOT personally identifiable — just a consistent hash per machine
function generateAnonymousId(): string {
  const components = [
    process.env.COMPUTERNAME || '',
    process.env.PROCESSOR_IDENTIFIER || '',
    process.arch,
    require('os').totalmem().toString(),
  ];
  return createHash('sha256').update(components.join('|')).digest('hex').slice(0, 16);
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
}

export interface OptimizationEvent {
  event_type: 'optimization_run' | 'optimization_result' | 'app_launch';
  hardware: HardwareInfo;
  settings_applied?: string[];
  game_id?: string;
  duration_ms?: number;
  success?: boolean;
  error_count?: number;
}

// ─── Send Telemetry ──────────────────────────────────────

export async function sendEvent(event: OptimizationEvent): Promise<void> {
  // Respect user's choice — never send without consent
  if (!consentGiven || !supabase) return;

  try {
    await supabase.from('telemetry_events').insert({
      anonymous_id: anonymousId,
      event_type: event.event_type,
      gpu: event.hardware.gpu,
      cpu: event.hardware.cpu,
      ram_gb: event.hardware.ram_gb,
      os_build: event.hardware.os_build,
      gpu_driver: event.hardware.gpu_driver || null,
      settings_applied: event.settings_applied || [],
      game_id: event.game_id || null,
      duration_ms: event.duration_ms || null,
      success: event.success ?? null,
      error_count: event.error_count || 0,
      app_version: app.getVersion(),
    });
  } catch {
    // Telemetry should never break the app — silently fail
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

// Convenience: track optimization result
export async function trackOptimizationResult(
  hardware: HardwareInfo,
  settingsApplied: string[],
  success: boolean,
  durationMs: number,
  errorCount: number,
): Promise<void> {
  await sendEvent({
    event_type: 'optimization_result',
    hardware,
    settings_applied: settingsApplied,
    success,
    duration_ms: durationMs,
    error_count: errorCount,
  });
}
