import type { ReactNode } from 'react';

interface CardProps {
  title?: string;
  children: ReactNode;
  className?: string;
  badge?: ReactNode;
}

export default function Card({ title, children, className = '', badge }: CardProps) {
  return (
    <div className={`sq-panel border sq-subtle-divider rounded-xl ${className}`}>
      {title && (
        <div className="flex items-center justify-between px-5 py-3.5 border-b sq-subtle-divider">
          <h3 className="text-sm font-semibold tracking-wide text-sq-text">{title}</h3>
          {badge}
        </div>
      )}
      <div className="px-5 py-4">
        {children}
      </div>
    </div>
  );
}
