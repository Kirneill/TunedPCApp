import { useState, useEffect } from 'react';
import { biosGuideSteps } from '../../data/bios-guide';
import Card from '../ui/Card';
import Badge from '../ui/Badge';

export default function BiosGuidePage() {
  const [checkedSteps, setCheckedSteps] = useState<Record<string, boolean>>({});

  // Load persisted state
  useEffect(() => {
    try {
      const stored = localStorage.getItem('sensequality-bios-checklist');
      if (stored) setCheckedSteps(JSON.parse(stored));
    } catch {}
  }, []);

  const toggleStep = (id: string) => {
    const updated = { ...checkedSteps, [id]: !checkedSteps[id] };
    setCheckedSteps(updated);
    try {
      localStorage.setItem('sensequality-bios-checklist', JSON.stringify(updated));
    } catch {}
  };

  const completedCount = Object.values(checkedSteps).filter(Boolean).length;

  return (
    <div className="space-y-5 max-w-4xl">
      <div>
        <h1 className="text-xl font-bold text-sq-text">BIOS Optimization Guide</h1>
        <p className="text-xs text-sq-text-muted mt-1">
          These settings must be changed manually in your BIOS. Reboot your PC and press DEL or F2 during POST to enter BIOS.
        </p>
        <div className="mt-2">
          <Badge variant="info">{completedCount}/{biosGuideSteps.length} completed</Badge>
        </div>
      </div>

      <div className="space-y-3">
        {biosGuideSteps.map((step, index) => (
          <Card key={step.id} className={checkedSteps[step.id] ? 'border-sq-success/30' : ''}>
            <div className="flex items-start gap-4">
              <button
                onClick={() => toggleStep(step.id)}
                className={`
                  mt-0.5 w-5 h-5 rounded border-2 shrink-0 flex items-center justify-center transition-colors
                  ${checkedSteps[step.id]
                    ? 'bg-sq-success border-sq-success'
                    : 'border-sq-border hover:border-sq-accent'
                  }
                `}
              >
                {checkedSteps[step.id] && (
                  <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                )}
              </button>

              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-xs text-sq-accent font-mono">Step {index + 1}</span>
                  <h3 className={`text-sm font-semibold ${checkedSteps[step.id] ? 'text-sq-text-muted line-through' : 'text-sq-text'}`}>
                    {step.title}
                  </h3>
                </div>

                <p className="text-xs text-sq-text-muted mb-2">{step.description}</p>

                <div className="bg-sq-bg rounded-lg p-3 text-xs text-sq-text-muted leading-relaxed">
                  {step.details}
                </div>

                <div className="flex items-center gap-3 mt-2">
                  <Badge variant="info">{step.impact}</Badge>
                  {step.warning && (
                    <span className="text-[10px] text-sq-warning flex items-center gap-1">
                      <span>⚠</span> {step.warning}
                    </span>
                  )}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
