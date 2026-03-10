import { describe, it, expect } from 'vitest';
import { GAMES, type GameDefinition } from '../game-registry';
import fs from 'fs';
import path from 'path';

const SCRIPTS_DIR = path.resolve(__dirname, '../../../scripts');

describe('Game Registry', () => {
  it('has at least one game', () => {
    expect(GAMES.length).toBeGreaterThan(0);
  });

  it('has no duplicate IDs', () => {
    const ids = GAMES.map(g => g.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('has no duplicate script filenames', () => {
    const scripts = GAMES.map(g => g.script);
    expect(new Set(scripts).size).toBe(scripts.length);
  });

  describe.each(GAMES.map(g => [g.id, g] as const))('game: %s', (_id, game) => {
    it('has all required string fields', () => {
      expect(game.id).toBeTruthy();
      expect(game.name).toBeTruthy();
      expect(game.subtitle).toBeTruthy();
      expect(game.description).toBeTruthy();
      expect(game.gradient).toBeTruthy();
      expect(game.letter).toBeTruthy();
      expect(game.script).toBeTruthy();
    });

    it('has valid risk level', () => {
      expect(['safe', 'moderate']).toContain(game.risk);
    });

    it('has a boolean requiresReboot', () => {
      expect(typeof game.requiresReboot).toBe('boolean');
    });

    it('has a boolean defaultEnabled', () => {
      expect(typeof game.defaultEnabled).toBe('boolean');
    });

    it('has steamFolders as an array', () => {
      expect(Array.isArray(game.steamFolders)).toBe(true);
    });

    it('has checkLabels as an object', () => {
      expect(typeof game.checkLabels).toBe('object');
      expect(game.checkLabels).not.toBeNull();
    });

    it('script file exists on disk', () => {
      const scriptPath = path.join(SCRIPTS_DIR, game.script);
      expect(fs.existsSync(scriptPath)).toBe(true);
    });

    it('script filename matches expected pattern (XX_GameName_Settings.ps1)', () => {
      expect(game.script).toMatch(/^\d{2}_\w+_Settings\.ps1$/);
    });

    it('checkLabel keys use SCREAMING_SNAKE_CASE', () => {
      for (const key of Object.keys(game.checkLabels)) {
        expect(key).toMatch(/^[A-Z][A-Z0-9_]+$/);
      }
    });

    it('checkLabel values are non-empty strings', () => {
      for (const [key, label] of Object.entries(game.checkLabels)) {
        expect(label).toBeTruthy();
        expect(typeof label).toBe('string');
      }
    });

    it('pathEnvVar uses SCREAMING_SNAKE format when defined', () => {
      if (game.pathEnvVar) {
        expect(game.pathEnvVar).toMatch(/^[A-Z][A-Z0-9_]+$/);
      }
    });

    it('letter is short (1-4 chars)', () => {
      expect(game.letter.length).toBeGreaterThanOrEqual(1);
      expect(game.letter.length).toBeLessThanOrEqual(4);
    });

    it('script dot-sources SQEngine.ps1', () => {
      const scriptPath = path.join(SCRIPTS_DIR, game.script);
      const content = fs.readFileSync(scriptPath, 'utf-8');
      expect(content).toContain('SQEngine.ps1');
      expect(content).toContain('Initialize-SQEngine');
    });
  });
});

describe('Game Registry - cross-field consistency', () => {
  it('games with pathEnvVar have non-empty steamFolders or detection logic', () => {
    // Non-Steam games use their own launcher and custom detection (not Steam folder scanning)
    const nonSteamGames = new Set(['tarkov', 'lol']);
    const gamesWithPath = GAMES.filter(g => g.pathEnvVar);
    for (const game of gamesWithPath) {
      expect(
        game.steamFolders.length > 0 || nonSteamGames.has(game.id)
      ).toBe(true);
    }
  });

  it('all check label keys are globally unique across games', () => {
    const allKeys: string[] = [];
    for (const game of GAMES) {
      allKeys.push(...Object.keys(game.checkLabels));
    }
    const uniqueKeys = new Set(allKeys);
    expect(uniqueKeys.size).toBe(allKeys.length);
  });
});
