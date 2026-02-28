import { useEffect, useRef } from 'react';
import type { LogEntry } from '../../types';

interface LogViewerProps {
  entries: LogEntry[];
  maxHeight?: string;
}

const typeStyles: Record<LogEntry['type'], string> = {
  info: 'text-sq-text-muted',
  success: 'text-sq-success',
  error: 'text-sq-danger',
  warning: 'text-sq-warning',
  start: 'text-sq-accent-hover',
  complete: 'text-sq-success font-semibold',
};

const typePrefix: Record<LogEntry['type'], string> = {
  info: '  ',
  success: '  [OK] ',
  error: '  [ERR] ',
  warning: '  [WARN] ',
  start: '> ',
  complete: '> ',
};

export default function LogViewer({ entries, maxHeight = '240px' }: LogViewerProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [entries.length]);

  if (entries.length === 0) {
    return (
      <div className="sq-panel-muted border border-sq-border rounded-lg p-4 font-mono text-xs text-sq-text-dim text-center" style={{ maxHeight }}>
        Ready to optimize. Select options and click "Run All Selected".
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className="sq-panel-muted border border-sq-border rounded-lg p-3 font-mono text-xs overflow-y-auto"
      style={{ maxHeight }}
    >
      {entries.map((entry, i) => (
        <div key={i} className={`${typeStyles[entry.type]} leading-relaxed`}>
          <span className="text-sq-text-dim mr-2">
            {new Date(entry.timestamp).toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' })}
          </span>
          {typePrefix[entry.type]}{entry.message}
        </div>
      ))}
    </div>
  );
}
