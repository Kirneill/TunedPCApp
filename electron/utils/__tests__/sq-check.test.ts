import { describe, it, expect } from 'vitest';
import { parseScriptCheck, mergeScriptCheck, type ScriptCheck } from '../sq-check';

describe('parseScriptCheck', () => {
  it('parses OK marker without detail', () => {
    const result = parseScriptCheck('[SQ_CHECK_OK:COD_EXE_FLAGS]');
    expect(result).toEqual({ key: 'COD_EXE_FLAGS', status: 'ok', detail: '' });
  });

  it('parses OK marker with detail', () => {
    const result = parseScriptCheck('[SQ_CHECK_OK:APEX_VIDEOCONFIG_WRITTEN:1920 x 1080]');
    expect(result).toEqual({
      key: 'APEX_VIDEOCONFIG_WRITTEN',
      status: 'ok',
      detail: '1920 x 1080',
    });
  });

  it('parses FAIL marker with detail', () => {
    const result = parseScriptCheck('[SQ_CHECK_FAIL:TARKOV_CONFIG_WRITTEN:WRITE_ERROR]');
    expect(result).toEqual({
      key: 'TARKOV_CONFIG_WRITTEN',
      status: 'fail',
      detail: 'WRITE_ERROR',
    });
  });

  it('parses WARN marker with detail', () => {
    const result = parseScriptCheck('[SQ_CHECK_WARN:BF6_EXE_FLAGS:EXE_NOT_FOUND]');
    expect(result).toEqual({
      key: 'BF6_EXE_FLAGS',
      status: 'warn',
      detail: 'EXE_NOT_FOUND',
    });
  });

  it('trims whitespace from detail', () => {
    const result = parseScriptCheck('[SQ_CHECK_OK:KEY:  some detail  ]');
    expect(result?.detail).toBe('some detail');
  });

  it('handles detail with colons', () => {
    const result = parseScriptCheck('[SQ_CHECK_FAIL:KEY:error: file not found]');
    expect(result?.detail).toBe('error: file not found');
  });

  it('returns null for non-marker lines', () => {
    expect(parseScriptCheck('[DONE] Script completed')).toBeNull();
    expect(parseScriptCheck('Write-Host "hello"')).toBeNull();
    expect(parseScriptCheck('')).toBeNull();
  });

  it('returns null for partial markers', () => {
    expect(parseScriptCheck('[SQ_CHECK_OK]')).toBeNull();
    expect(parseScriptCheck('[SQ_CHECK_:KEY]')).toBeNull();
    expect(parseScriptCheck('SQ_CHECK_OK:KEY')).toBeNull();
  });

  it('returns null for markers with invalid status', () => {
    expect(parseScriptCheck('[SQ_CHECK_ERROR:KEY]')).toBeNull();
    expect(parseScriptCheck('[SQ_CHECK_ok:KEY]')).toBeNull();
  });

  it('returns null for markers with lowercase keys', () => {
    expect(parseScriptCheck('[SQ_CHECK_OK:some_key]')).toBeNull();
  });

  it('handles keys with numbers', () => {
    const result = parseScriptCheck('[SQ_CHECK_OK:CS2_EXE_FLAGS]');
    expect(result?.key).toBe('CS2_EXE_FLAGS');
  });

  it('returns null when marker has leading/trailing text', () => {
    expect(parseScriptCheck('  [SQ_CHECK_OK:KEY]')).toBeNull();
    expect(parseScriptCheck('[SQ_CHECK_OK:KEY]  ')).toBeNull();
    expect(parseScriptCheck('prefix[SQ_CHECK_OK:KEY]')).toBeNull();
  });
});

describe('mergeScriptCheck', () => {
  it('adds new check to empty record', () => {
    const checks: Record<string, ScriptCheck> = {};
    mergeScriptCheck(checks, { key: 'A', status: 'ok', detail: '' });
    expect(checks['A']).toEqual({ key: 'A', status: 'ok', detail: '' });
  });

  it('does not overwrite fail with ok', () => {
    const checks: Record<string, ScriptCheck> = {
      A: { key: 'A', status: 'fail', detail: 'broken' },
    };
    mergeScriptCheck(checks, { key: 'A', status: 'ok', detail: 'fixed' });
    expect(checks['A'].status).toBe('fail');
  });

  it('overwrites ok with fail', () => {
    const checks: Record<string, ScriptCheck> = {
      A: { key: 'A', status: 'ok', detail: '' },
    };
    mergeScriptCheck(checks, { key: 'A', status: 'fail', detail: 'broke' });
    expect(checks['A'].status).toBe('fail');
    expect(checks['A'].detail).toBe('broke');
  });

  it('overwrites ok with warn', () => {
    const checks: Record<string, ScriptCheck> = {
      A: { key: 'A', status: 'ok', detail: '' },
    };
    mergeScriptCheck(checks, { key: 'A', status: 'warn', detail: 'degraded' });
    expect(checks['A'].status).toBe('warn');
  });

  it('overwrites warn with fail', () => {
    const checks: Record<string, ScriptCheck> = {
      A: { key: 'A', status: 'warn', detail: '' },
    };
    mergeScriptCheck(checks, { key: 'A', status: 'fail', detail: 'dead' });
    expect(checks['A'].status).toBe('fail');
  });

  it('keeps independent keys separate', () => {
    const checks: Record<string, ScriptCheck> = {};
    mergeScriptCheck(checks, { key: 'A', status: 'ok', detail: '' });
    mergeScriptCheck(checks, { key: 'B', status: 'fail', detail: '' });
    expect(checks['A'].status).toBe('ok');
    expect(checks['B'].status).toBe('fail');
  });

  it('replaces same-severity check (last write wins)', () => {
    const checks: Record<string, ScriptCheck> = {
      A: { key: 'A', status: 'warn', detail: 'first' },
    };
    mergeScriptCheck(checks, { key: 'A', status: 'warn', detail: 'second' });
    expect(checks['A'].detail).toBe('second');
  });
});
