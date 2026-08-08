'use client';

import { forwardRef, HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface ProgressProps extends HTMLAttributes<HTMLDivElement> {
  value: number;
  max?: number;
  color?: 'primary' | 'success' | 'warning' | 'danger' | 'info';
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
  label?: string;
  animated?: boolean;
  striped?: boolean;
}

const colorClasses = {
  primary: 'bg-primary',
  success: 'bg-success',
  warning: 'bg-warning',
  danger: 'bg-danger',
  info: 'bg-primary',
};

const sizeClasses = {
  sm: 'h-1.5',
  md: 'h-2',
  lg: 'h-3',
};

export const Progress = forwardRef<HTMLDivElement, ProgressProps>(
  ({ className, value, max = 100, color = 'primary', size = 'md', showLabel = false, label, animated = false, striped = false, ...props }, ref) => {
    const percentage = Math.min(Math.max((value / max) * 100, 0), 100);

    return (
      <div ref={ref} className={cn('w-full', className)} {...props}>
        {(showLabel || label) && (
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-sm font-medium text-text-secondary">{label || `${Math.round(percentage)}%`}</span>
            {showLabel && <span className="text-sm font-mono text-text-primary">{Math.round(percentage)}%</span>}
          </div>
        )}
        <div className={cn('w-full bg-bg-border rounded-full overflow-hidden', sizeClasses[size])}>
          <div
            className={cn(
              'h-full rounded-full transition-all duration-500 ease-out',
              colorClasses[color],
              animated && 'animate-pulse-soft',
              striped && 'bg-gradient-to-r from-transparent via-white/20 to-transparent bg-[length:20px_100%] animate-[stripe_1s_linear_infinite]'
            )}
            style={{ width: `${percentage}%` }}
            role="progressbar"
            aria-valuenow={Math.round(percentage)}
            aria-valuemin={0}
            aria-valuemax={100}
          />
        </div>
      </div>
    );
  }
);

Progress.displayName = 'Progress';