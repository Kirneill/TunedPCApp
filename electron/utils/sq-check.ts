/**
 * SQ_CHECK marker parsing utilities.
 *
 * Extracted from handlers.ts so these pure functions can be unit-tested
 * without importing Electron.
 */

export type CheckStatus = 'ok' | 'fail' | 'warn';

export interface ScriptCheck {
  key: string;
  status: CheckStatus;
  detail: string;
}

/**
 * Parses an SQ_CHECK marker line emitted by PowerShell scripts.
 *
 * Format: [SQ_CHECK_OK:KEY] or [SQ_CHECK_FAIL:KEY:detail text]
 * Returns null if the line doesn't match the marker format.
 */
export function parseScriptCheck(line: string): ScriptCheck | null {
  const match = line.match(/^\[SQ_CHECK_(OK|FAIL|WARN):([A-Z0-9_]+)(?::(.*))?\]$/);
  if (!match) return null;
  return {
    key: match[2],
    status: match[1] === 'OK' ? 'ok' : (match[1] === 'FAIL' ? 'fail' : 'warn'),
    detail: (match[3] || '').trim(),
  };
}

/**
 * Merges a new check into an existing checks record.
 * Higher-severity statuses (fail > warn > ok) take precedence.
 */
export function mergeScriptCheck(checks: Record<string, ScriptCheck>, next: ScriptCheck) {
  const current = checks[next.key];
  if (!current) {
    checks[next.key] = next;
    return;
  }

  const priority: Record<CheckStatus, number> = { fail: 3, warn: 2, ok: 1 };
  if (priority[next.status] >= priority[current.status]) {
    checks[next.key] = next;
  }
}
