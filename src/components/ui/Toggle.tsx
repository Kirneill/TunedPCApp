interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}

export default function Toggle({ checked, onChange, disabled }: ToggleProps) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`
        toggle-track relative inline-flex h-5 w-9 items-center rounded-full shrink-0
        ${checked ? 'bg-sq-accent' : 'bg-sq-border'}
        ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
      `}
    >
      <span
        className={`
          toggle-thumb inline-block h-3.5 w-3.5 rounded-full bg-white shadow-sm
          ${checked ? 'translate-x-[18px]' : 'translate-x-[3px]'}
        `}
      />
    </button>
  );
}
