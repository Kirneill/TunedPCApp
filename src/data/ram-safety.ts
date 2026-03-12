/**
 * RAM Safety Rules — prevents auto-optimization from crashing systems.
 *
 * These rules are critical. DO NOT weaken them without real hardware testing.
 *
 * Rule 1: Ryzen 9000 + RAM > 6000 MHz → skip auto-XMP (would crash)
 * Rule 2: Intel + RAM > 6800 MHz → warn (high crash risk)
 * Rule 3: Ryzen 9000 / Intel 13-14 + >2 sticks → block CPU overclock
 *
 * See: Gaming Research/BiosOptimizationGuide/RAM_Safety_Rules.md
 */

import type { BiosDetectionResult, ProfileSetting } from '../types';

export interface RamSafetyWarning {
  id: string;
  severity: 'info' | 'warning' | 'danger';
  title: string;
  message: string;
  /** Optional step-by-step instructions shown below the message */
  steps?: string[];
}

export interface RamSafetyResult {
  warnings: RamSafetyWarning[];
  /** Profile setting names to exclude from auto-apply */
  skipSettings: string[];
}

// ─── CPU family detection ──────────────────────────────────

function isRyzen9000(cpu: string): boolean {
  // Matches 9600X, 9700X, 9800X3D, 9900X, 9900X3D, 9950X, 9950X3D
  return /ryzen.*(9[0-9]{3}X|9800X3D|9900X3D|9950X3D)/i.test(cpu)
    || /\b(9600X|9700X|9800X3D|9900X|9900X3D|9950X|9950X3D)\b/i.test(cpu);
}

function isRyzen7000(cpu: string): boolean {
  return /ryzen.*(7[0-9]{3}X|7800X3D)/i.test(cpu)
    || /\b(7600X?|7700X?|7800X3D|7900X|7950X)\b/i.test(cpu);
}

function isIntel13or14(cpu: string): boolean {
  // Matches i5-13600K, i9-14900KS, 13400F, 14700KF, etc.
  return /\b1[34][0-9]{3}K?F?S?\b/i.test(cpu);
}

function isIntel(cpu: string): boolean {
  return /intel|core/i.test(cpu);
}

// ─── Vendor-specific BIOS paths ────────────────────────────

type VendorKey = 'asus' | 'msi' | 'gigabyte' | 'asrock';

const XMP_NAV: Record<VendorKey, string> = {
  asus: 'AI Tweaker > XMP > Profile 1',
  msi: 'OC > XMP > Profile 1',
  gigabyte: 'Tweaker > Extreme Memory Profile (XMP) > Profile 1',
  asrock: 'OC Tweaker > DRAM Configuration > XMP > Profile 1',
};

const FREQ_NAV: Record<VendorKey, string> = {
  asus: 'AI Tweaker > DRAM Frequency > DDR5-6000',
  msi: 'OC > DRAM Frequency > 6000',
  gigabyte: 'Tweaker > System Memory Multiplier > 60.00 (DDR5-6000)',
  asrock: 'OC Tweaker > DRAM Frequency > DDR5-6000',
};

function detectVendor(vendor: string | null | undefined): VendorKey | null {
  if (!vendor) return null;
  const v = vendor.toLowerCase();
  if (v.includes('asus')) return 'asus';
  if (v.includes('msi') || v.includes('micro-star')) return 'msi';
  if (v.includes('gigabyte')) return 'gigabyte';
  if (v.includes('asrock')) return 'asrock';
  return null;
}

// ─── Safety check ──────────────────────────────────────────

export function checkRamSafety(detection: BiosDetectionResult | null): RamSafetyResult {
  const result: RamSafetyResult = {
    warnings: [],
    skipSettings: [],
  };

  if (!detection?.cpuName) return result;

  const cpu = detection.cpuName;
  const ramSpeed = detection.ramRatedSpeed;
  const sticks = detection.ramSticks;
  const vendor = detectVendor(detection.motherboardVendor);

  // ━━━ Rule 1: Ryzen 9000 + RAM > 6000 MHz ━━━
  // The Zen 5 memory controller tops out at ~6000 MHz stable.
  // Enabling XMP at higher speeds (e.g., DDR5-7200) WILL crash.
  // Also applies to Ryzen 7000 (Zen 4) — same 6000 MHz sweet spot.
  if ((isRyzen9000(cpu) || isRyzen7000(cpu)) && ramSpeed && ramSpeed > 6000) {
    result.skipSettings.push('RAM Speed Profile');

    const platform = isRyzen9000(cpu) ? 'Ryzen 9000' : 'Ryzen 7000';
    const xmpPath = vendor ? XMP_NAV[vendor] : 'your BIOS memory/overclocking section > XMP/EXPO > Profile 1';
    const freqPath = vendor ? FREQ_NAV[vendor] : 'your BIOS memory settings > DRAM Frequency > DDR5-6000';
    const vendorLabel = vendor ? vendor.charAt(0).toUpperCase() + vendor.slice(1) : null;

    result.warnings.push({
      id: 'amd-ram-too-fast',
      severity: 'danger',
      title: `RAM Too Fast for Auto-XMP (${ramSpeed} MHz)`,
      message: `Your RAM is rated at ${ramSpeed} MHz, but ${platform} series CPUs are only stable up to ~6000 MHz. We've disabled auto-XMP to prevent crashes. Follow these steps manually in BIOS to get the best safe performance:`,
      steps: [
        `Restart your PC and enter BIOS (press DEL or F2 on startup)`,
        `Enable XMP/EXPO Profile 1: ${vendorLabel ? `On your ${vendorLabel} board, go to` : 'Navigate to'} ${xmpPath}`,
        `Set memory frequency to 6000 MHz: ${vendorLabel ? `Go to` : 'Navigate to'} ${freqPath}`,
        `Save and exit BIOS (usually F10)`,
        `If your PC doesn't boot, clear CMOS (check your motherboard manual) and try DDR5-5600 instead`,
      ],
    });
  }

  // ━━━ Rule 2: Intel + RAM > 6800 MHz ━━━
  // Intel IMC handles higher speeds better than AMD, but >6800 is pushing it.
  // Don't block — just warn prominently.
  if (isIntel(cpu) && ramSpeed && ramSpeed > 6800) {
    const freqPath = vendor ? FREQ_NAV[vendor].replace('6000', '6800') : 'BIOS memory settings > DRAM Frequency > DDR5-6800';

    result.warnings.push({
      id: 'intel-high-ram',
      severity: 'warning',
      title: `Very High RAM Speed (${ramSpeed} MHz)`,
      message: `Your RAM is rated at ${ramSpeed} MHz, which is very high. XMP will be enabled at the full speed, but if your PC crashes or blue screens after optimization:`,
      steps: [
        `Enter BIOS (press DEL or F2 on startup)`,
        `Keep XMP enabled, but lower the memory frequency: ${freqPath}`,
        `Try DDR5-6800 first, then DDR5-6400 if still unstable`,
        `Save and exit (F10)`,
      ],
    });
  }

  // ━━━ Rule 3: >2 sticks on stress-sensitive platforms ━━━
  // 4 DIMMs put significantly more stress on the memory controller.
  // On Ryzen 9000 and Intel 13th/14th gen, this makes CPU overclocking
  // unreliable. Block the CPU OC settings, keep XMP and safe settings.
  if ((isRyzen9000(cpu) || isRyzen7000(cpu) || isIntel13or14(cpu)) && sticks != null && sticks > 2) {
    // Block CPU overclock settings by name (must match names in bios-profiles.ts)
    const ocSettings = [
      'CPU Auto-Boost',
      'CPU Speed Boost',
      'CPU Efficiency Tuning',
      'CPU Undervolt Direction',
      'CPU Undervolt Amount',
      'Max Frequency Enhancer',
      'CPU Voltage Offset',
      'CPU Voltage Safety Cap',
      'Voltage Control Mode',
      'Voltage Stability',
    ];
    result.skipSettings.push(...ocSettings);

    const platform = isIntel13or14(cpu) ? 'Intel 13th/14th Gen' : isRyzen9000(cpu) ? 'Ryzen 9000' : 'Ryzen 7000';
    result.warnings.push({
      id: 'too-many-sticks',
      severity: 'danger',
      title: `${sticks} RAM Sticks Detected — CPU Overclock Disabled`,
      message: `Your system has ${sticks} RAM sticks, which puts extra stress on the ${platform} memory controller. CPU overclocking with 4 sticks is unstable and can cause crashes. We've disabled CPU overclock settings for safety. For best performance, use 2 sticks of higher-capacity RAM instead of ${sticks} smaller ones — then you can safely enable overclocking.`,
    });
  }

  return result;
}

/**
 * Filter a profile's settings based on RAM safety rules.
 * Used both client-side (UI preview) and server-side (apply handler).
 */
export function filterProfileSettings(
  settings: ProfileSetting[],
  safetyResult: RamSafetyResult,
): ProfileSetting[] {
  if (safetyResult.skipSettings.length === 0) return settings;
  const skipSet = new Set(safetyResult.skipSettings);
  return settings.filter(s => !skipSet.has(s.name));
}
