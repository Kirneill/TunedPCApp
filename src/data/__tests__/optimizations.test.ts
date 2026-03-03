import { describe, it, expect } from 'vitest';
import { GAMES } from '../game-registry';
import { gameOptimizations, windowsOptimizations, allOptimizations } from '../optimizations';

describe('Game Optimizations (derived from registry)', () => {
  it('creates one optimization per game', () => {
    expect(gameOptimizations.length).toBe(GAMES.length);
  });

  it('prefixes all game optimization IDs with "game-"', () => {
    for (const opt of gameOptimizations) {
      expect(opt.id).toMatch(/^game-/);
    }
  });

  it('maps game IDs correctly', () => {
    for (const game of GAMES) {
      const opt = gameOptimizations.find(o => o.id === `game-${game.id}`);
      expect(opt).toBeDefined();
      expect(opt!.label).toBe(game.name);
      expect(opt!.description).toBe(game.description);
      expect(opt!.risk).toBe(game.risk);
      expect(opt!.requiresReboot).toBe(game.requiresReboot);
      expect(opt!.gameId).toBe(game.id);
    }
  });

  it('all game optimizations have category "game"', () => {
    for (const opt of gameOptimizations) {
      expect(opt.category).toBe('game');
    }
  });
});

describe('Windows Optimizations', () => {
  it('all have category "windows"', () => {
    for (const opt of windowsOptimizations) {
      expect(opt.category).toBe('windows');
    }
  });

  it('all IDs start with "win-" or "updates-"', () => {
    for (const opt of windowsOptimizations) {
      expect(opt.id).toMatch(/^(win-|updates-)/);
    }
  });

  it('has no duplicate IDs', () => {
    const ids = windowsOptimizations.map(o => o.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});

describe('allOptimizations', () => {
  it('combines windows and game optimizations', () => {
    expect(allOptimizations.length).toBe(
      windowsOptimizations.length + gameOptimizations.length
    );
  });

  it('has globally unique IDs across windows and games', () => {
    const ids = allOptimizations.map(o => o.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
