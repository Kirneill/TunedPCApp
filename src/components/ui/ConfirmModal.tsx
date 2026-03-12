interface ConfirmModalProps {
  title: string;
  description: string;
  bullets: string[];
  confirmLabel: string;
  confirmClassName: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function ConfirmModal({
  title,
  description,
  bullets,
  confirmLabel,
  confirmClassName,
  onConfirm,
  onCancel,
}: ConfirmModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="bg-sq-surface border border-sq-border rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl space-y-4">
        <h2 className="text-lg font-bold text-sq-text">{title}</h2>
        <p className="text-sm text-sq-text-muted leading-relaxed">{description}</p>
        <ul className="text-xs text-sq-text-muted space-y-1 list-disc list-inside">
          {bullets.map((bullet, i) => (
            <li key={i}>{bullet}</li>
          ))}
        </ul>
        <div className="flex gap-3 justify-end pt-2">
          <button
            onClick={onCancel}
            className="px-4 py-2.5 rounded-xl text-sm font-medium text-sq-text-muted border border-sq-border hover:bg-sq-surface-hover transition-colors cursor-pointer"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className={`px-4 py-2.5 rounded-xl text-sm font-bold text-white transition-colors cursor-pointer ${confirmClassName}`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
