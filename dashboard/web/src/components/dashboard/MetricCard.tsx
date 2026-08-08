'use client';

import { ReactNode, forwardRef } from 'react';
import { cn } from '@/lib/utils';
import { Card } from '@/components/ui/Card';
import { Progress } from '@/components/ui/Progress';
import { Badge } from '@/components/ui/Badge';

interface MetricCardProps {
  label: string;
  value: string;
  icon: ReactNode;
  color?: 'primary' | 'success' | 'warning' | 'info' | 'danger';
  trend?: string;
  trendUp?: boolean;
  progress?: number;
  showProgress?: boolean;
  unit?: string;
}

const colorClasses = {
  primary: 'bg-primary/10 text-primary border-primary/20',
  success: 'bg-success/10 text-success border-success/20',
  warning: 'bg-warning/10 text-warning border-warning/20',
  info: 'bg-primary/10 text-primary border-primary/20',
  danger: 'bg-danger/10 text-danger border-danger/20',
};

export const MetricCard = forwardRef<HTMLDivElement, MetricCardProps>(
  ({ className, label, value, icon, color = 'primary', trend, trendUp, progress, showProgress, unit, ...props }, ref) => {
    return (
      <Card
        ref={ref}
        variant="hover"
        padding="md"
        className={cn('group', className)}
        {...props}
      >
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-text-secondary">{label}</p>
            <p className="mt-1 text-2xl font-bold text-text-primary truncate">{value}</p>
            {trend && (
              <div className="mt-2 flex items-center gap-1">
                <span className={cn(
                  'text-xs font-medium',
                  trendUp ? 'text-success' : 'text-danger'
                )}>
                  {trendUp ? '↑' : '↓'} {trend}
                </span>
                <span className="text-xs text-text-muted">vs mês anterior</span>
              </div>
            )}
          </div>
          <div className={cn('p-2 rounded-lg flex-shrink-0', colorClasses[color])}>
            {icon}
          </div>
        </div>
        {showProgress && progress !== undefined && (
          <div className="mt-4">
            <Progress value={progress} max={100} color={color} size="sm" showLabel />
            {unit && <p className="mt-1 text-xs text-text-muted">Capacidade: {unit}</p>}
          </div>
        )}
      </Card>
    );
  }
);

MetricCard.displayName = 'MetricCard';