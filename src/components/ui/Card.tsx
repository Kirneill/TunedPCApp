import type { ReactNode } from 'react';

interface CardProps {
  title?: string;
  children: ReactNode;
  className?: string;
  badge?: ReactNode;
}

export default function Card({ title, children, className = '', badge }: CardProps) {
  return (
    <div className={`bg-sq-surface border border-sq-border rounded-xl ${className}`}>
      {title && (
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-sq-border">
          <h3 className="text-sm font-semibold text-sq-text">{title}</h3>
          {badge}
        </div>
      )}
      <div className="px-5 py-4">
        {children}
      </div>
    </div>
  );
}
