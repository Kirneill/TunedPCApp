import { useAppStore } from '../../store/appStore';

export default function TitleBar() {
  const { isAdmin } = useAppStore();

  return (
    <div className="drag-region flex items-center justify-between h-10 bg-sq-surface border-b border-sq-border px-4 select-none shrink-0">
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 no-drag">
          <div className="w-5 h-5 rounded bg-sq-accent flex items-center justify-center text-[10px] font-bold text-white">
            SQ
          </div>
          <span className="text-sm font-semibold text-sq-text">SENSEQUALITY</span>
          <span className="text-xs text-sq-text-muted">Optimizer</span>
        </div>
        {isAdmin && (
          <span className="text-[10px] px-1.5 py-0.5 rounded bg-sq-success/20 text-sq-success font-medium">
            ADMIN
          </span>
        )}
      </div>

      <div className="flex items-center no-drag">
        <button
          onClick={() => window.sensequality.minimizeWindow()}
          className="w-10 h-10 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
        >
          <svg width="10" height="1" viewBox="0 0 10 1" fill="currentColor"><rect width="10" height="1"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.maximizeWindow()}
          className="w-10 h-10 flex items-center justify-center text-sq-text-muted hover:text-sq-text hover:bg-sq-surface-hover transition-colors"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1"><rect x="0.5" y="0.5" width="9" height="9"/></svg>
        </button>
        <button
          onClick={() => window.sensequality.closeWindow()}
          className="w-10 h-10 flex items-center justify-center text-sq-text-muted hover:text-white hover:bg-sq-danger transition-colors"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.2"><line x1="1" y1="1" x2="9" y2="9"/><line x1="9" y1="1" x2="1" y2="9"/></svg>
        </button>
      </div>
    </div>
  );
}
