'use client';

import { HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'success' | 'danger' | 'warning' | 'info' | 'outline';
  size?: 'sm' | 'md';
  dot?: boolean;
}

export function Badge({ 
  className, 
  variant = 'default', 
  size = 'md', 
  dot = false, 
  children, 
  ...props 
}: BadgeProps) {
  const variants = {
    default: 'bg-border text-text',
    success: 'bg-success/10 text-success border border-success/20',
    danger: 'bg-danger/10 text-danger border border-danger/20',
    warning: 'bg-warning/10 text-warning border border-warning/20',
    info: 'bg-primary/10 text-primary border border-primary/20',
    outline: 'bg-transparent text-text-secondary border border-border',
  };

  const sizes = {
    sm: 'px-2 py-0.5 text-xs gap-1',
    md: 'px-2.5 py-1 text-xs gap-1.5',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center font-medium rounded-full border',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    >
      {dot && (
        <span
          className={cn(
            'w-1.5 h-1.5 rounded-full',
            variant === 'success' && 'bg-success',
            variant === 'danger' && 'bg-danger',
            variant === 'warning' && 'bg-warning',
            variant === 'info' && 'bg-primary',
            variant === 'default' && 'bg-text-muted',
            variant === 'outline' && 'bg-text-muted'
          )}
        />
      )}
      {children}
    </span>
  );
}