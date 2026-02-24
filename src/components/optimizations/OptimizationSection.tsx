import { useState } from 'react';
import { useAppStore } from '../../store/appStore';
import OptimizationToggle from './OptimizationToggle';
import type { OptimizationItem } from '../../types';

interface OptimizationSectionProps {
  title: string;
  items: OptimizationItem[];
  icon: string;
}

export default function OptimizationSection({ title, items, icon }: OptimizationSectionProps) {
  const { toggles, setToggle, isRunning, detectedGames } = useAppStore();
  const [collapsed, setCollapsed] = useState(false);

  const enabledCount = items.filter(i => toggles[i.id]).length;
  const allEnabled = enabledCount === items.length;

  const toggleAll = () => {
    const newValue = !allEnabled;
    for (const item of items) {
      setToggle(item.id, newValue);
    }
  };

  // Filter game optimizations by detected games
  const visibleItems = items.filter(item => {
    if (item.gameId) {
      const game = detectedGames.find(g => g.id === item.gameId);
      return !game || game.installed; // Show if game found or if no detection data
    }
    return true;
  });

  return (
    <div className="bg-sq-surface border border-sq-border rounded-xl overflow-hidden">
      <div
        className="flex items-center justify-between px-5 py-3 border-b border-sq-border cursor-pointer hover:bg-sq-surface-hover transition-colors"
        onClick={() => setCollapsed(!collapsed)}
      >
        <div className="flex items-center gap-2">
          <span>{icon}</span>
          <h3 className="text-sm font-semibold text-sq-text">{title}</h3>
          <span className="text-xs text-sq-text-dim">
            {enabledCount}/{items.length} enabled
          </span>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={(e) => { e.stopPropagation(); toggleAll(); }}
            disabled={isRunning}
            className="text-[11px] text-sq-accent-hover hover:text-sq-accent transition-colors disabled:opacity-50"
          >
            {allEnabled ? 'Deselect All' : 'Select All'}
          </button>
          <svg
            className={`w-4 h-4 text-sq-text-muted transition-transform ${collapsed ? '-rotate-90' : ''}`}
            fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>

      {!collapsed && (
        <div className="px-4 py-1 divide-y divide-sq-border/50">
          {visibleItems.map((item) => (
            <OptimizationToggle
              key={item.id}
              item={item}
              checked={toggles[item.id] ?? true}
              onChange={(val) => setToggle(item.id, val)}
              disabled={isRunning}
            />
          ))}
        </div>
      )}
    </div>
  );
}
