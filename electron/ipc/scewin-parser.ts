/**
 * SCEWIN NVRAM Parser — TypeScript port of BiosTuner's Python parser.
 * Parses AMI Aptio UEFI NVRAM text exports, matches profiles, and patches settings.
 */
import type { NvramSetting, ProfileSetting, ProfileChange } from '../../src/types/index';
export type { NvramSetting, ProfileSetting, ProfileChange } from '../../src/types/index';

/**
 * Parse SCEWIN NVRAM export text into structured settings.
 * Port of BiosTuner's ScewinInterface.parse_nvram() — same regex, same logic.
 */
export function parseNvram(text: string): NvramSetting[] {
  // Strip BOM if present
  const clean = text.replace(/^\uFEFF/, '');
  const settings: NvramSetting[] = [];
  const blocks = clean.split(/\n(?=Setup Question\s+=)/);

  for (const block of blocks) {
    const trimmed = block.trim();
    if (!trimmed.startsWith('Setup Question')) continue;

    const s: NvramSetting = {
      name: '', token: '', offset: '', width: '',
      biosDefault: '', currentValue: '',
      options: {}, isNumeric: false, rawBlock: trimmed,
    };

    const nameMatch = trimmed.match(/Setup Question\s+=\s*(.+)/);
    if (nameMatch) s.name = nameMatch[1].trim();

    const tokenMatch = trimmed.match(/Token\s*=\s*(\S+)/);
    if (tokenMatch) s.token = tokenMatch[1];

    const offsetMatch = trimmed.match(/Offset\s*=\s*(\S+)/);
    if (offsetMatch) s.offset = offsetMatch[1];

    const widthMatch = trimmed.match(/Width\s*=\s*(\S+)/);
    if (widthMatch) s.width = widthMatch[1];

    const defaultMatch = trimmed.match(/BIOS Default\s*=\s*(.+)/);
    if (defaultMatch) s.biosDefault = defaultMatch[1].trim();

    const numericMatch = trimmed.match(/Options\s*=\s*Min:\s*(\S+)\s+Max:\s*(\S+)\s+Step:\s*(\S+)/);
    if (numericMatch) {
      s.isNumeric = true;
      s.numericMin = numericMatch[1];
      s.numericMax = numericMatch[2];
      s.numericStep = numericMatch[3];
    }

    const currentMatch = trimmed.match(/\*\[([^\]]+)\]/);
    if (currentMatch) s.currentValue = currentMatch[1];

    for (const om of trimmed.matchAll(/\[([^\]]+)\](\S.*?)(?=\n|$)/g)) {
      s.options[om[2].trim()] = om[1];
    }

    settings.push(s);
  }
  return settings;
}

/**
 * Match a profile's settings against parsed NVRAM and compute changes.
 * Port of BiosTuner's ProfileEngine.apply().
 */
export function matchProfile(
  nvram: NvramSetting[],
  profile: ProfileSetting[]
): ProfileChange[] {
  const changes: ProfileChange[] = [];

  for (const ps of profile) {
    let re: RegExp;
    try {
      re = new RegExp(ps.matchPattern, 'i');
    } catch {
      changes.push({
        name: ps.name, nvramName: '(invalid pattern)', currentValue: '',
        targetValue: ps.targetValue, resolvedValue: ps.targetValue,
        riskLevel: ps.riskLevel, description: ps.description,
        applied: false, found: false,
      });
      continue;
    }
    // Prefer the LAST (deepest) match in the NVRAM dump. AMD CBS tokens appear
    // after main Setup tokens, and the CBS copies are the authoritative values
    // that persist through boot. Using the first match can target a "shadow" copy
    // in the main section that the BIOS firmware overwrites on every POST.
    let match: NvramSetting | undefined;
    for (let i = nvram.length - 1; i >= 0; i--) {
      if (re.test(nvram[i].name)) { match = nvram[i]; break; }
    }

    if (match) {
      const resolved = resolveValue(ps, match);
      // Compare case-insensitively: NVRAM hex values may be lowercase (0x1e) or uppercase (0x1E)
      const alreadyAtTarget = resolved === null ||
        resolved.toLowerCase() === match.currentValue.toLowerCase();
      changes.push({
        name: ps.name,
        nvramName: match.name,
        currentValue: match.currentValue,
        targetValue: ps.targetValue,
        resolvedValue: resolved ?? ps.targetValue,
        riskLevel: ps.riskLevel,
        description: ps.description,
        applied: !alreadyAtTarget,
        found: true,
      });
    } else {
      changes.push({
        name: ps.name,
        nvramName: '(not found)',
        currentValue: '',
        targetValue: ps.targetValue,
        resolvedValue: ps.targetValue,
        riskLevel: ps.riskLevel,
        description: ps.description,
        applied: false,
        found: false,
      });
    }
  }
  return changes;
}

/** Resolve a profile target value to an NVRAM option value. */
function resolveValue(ps: ProfileSetting, ns: NvramSetting): string | null {
  if (ns.isNumeric) {
    // Profile targets are decimal (e.g., "30", "200").
    // SCEWIN export format uses hex (e.g., "0x1E", "0xC8").
    // We must convert to hex so SCEWIN writes the correct value.
    const num = parseInt(ps.targetValue, 10);
    if (isNaN(num)) return ps.targetValue;
    // Pad hex digits to match NVRAM field width: Width=0x01→2 digits, 0x02→4, 0x04→8
    const width = parseInt(ns.width.replace(/^0x/i, ''), 16);
    const hexDigits = isNaN(width) || width < 1 ? 2 : width * 2;
    return `0x${num.toString(16).toUpperCase().padStart(hexDigits, '0')}`;
  }
  const target = ps.targetValue.toLowerCase();
  // Exact match first
  for (const [label, val] of Object.entries(ns.options)) {
    if (label.toLowerCase() === target) return val;
  }
  // Substring fallback only if no exact match
  for (const [label, val] of Object.entries(ns.options)) {
    if (label.toLowerCase().includes(target)) return val;
  }
  return ps.targetValue;
}

/**
 * Patch an NVRAM export text file with the computed changes.
 * Port of BiosTuner's ProfileEngine._patch() + write_modified().
 */
export function patchNvramText(
  originalText: string,
  nvram: NvramSetting[],
  changes: ProfileChange[]
): string {
  let text = originalText;

  for (const change of changes) {
    if (!change.applied || !change.found) continue;

    // Use reverse lookup to match the same deep token that matchProfile selected
    let setting: NvramSetting | undefined;
    for (let i = nvram.length - 1; i >= 0; i--) {
      if (nvram[i].name === change.nvramName) { setting = nvram[i]; break; }
    }
    if (!setting) continue;

    // Use token for unique identification — setting names can be duplicated across subsections
    const tokenMarker = `Token = ${setting.token}`;
    const tokenIdx = text.indexOf(tokenMarker);
    if (tokenIdx < 0) continue;

    // Walk backwards from token to find the Setup Question header for this block
    const blockStart = text.lastIndexOf('Setup Question  =', tokenIdx);
    if (blockStart < 0) continue;

    let blockEnd = text.indexOf('\nSetup Question  =', blockStart + 1);
    if (blockEnd < 0) blockEnd = text.length;

    let block = text.substring(blockStart, blockEnd);

    // Remove all current selection markers
    block = block.replace(/\*\[/g, '[');

    // Set new selection
    if (setting.isNumeric) {
      // For numeric: replace the last [value] with *[newValue]
      const patched = block.replace(/\[([^\]]*)\]\s*$/m, `*[${change.resolvedValue}]`);
      if (patched === block) {
        console.warn(`SCEWIN patcher: failed to patch numeric setting "${setting.name}" (token ${setting.token})`);
        continue;
      }
      block = patched;
    } else {
      // For option: mark the target value with *
      block = block.replace(
        new RegExp(`\\[${escapeRegex(change.resolvedValue)}\\]`),
        `*[${change.resolvedValue}]`
      );
    }

    text = text.substring(0, blockStart) + block + text.substring(blockEnd);
  }

  return text;
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
