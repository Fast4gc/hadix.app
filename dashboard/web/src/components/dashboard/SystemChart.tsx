'use client';

import { useEffect, useRef, useState } from 'react';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';
import { cn } from '@/lib/utils';
import { Card } from '@/components/ui/Card';

interface SystemChartProps {
  type: 'cpu' | 'memory' | 'network' | 'disk';
  height?: number;
  className?: string;
  realtime?: boolean;
}

const COLORS = {
  cpu: { primary: '#3B82F6', secondary: '#1E3A5F' },
  memory: { primary: '#10B981', secondary: '#064E3B' },
  network: { primary: '#F59E0B', secondary: '#78350F' },
  disk: { primary: '#EF4444', secondary: '#7F1D1D' },
};

const generateMockData = (type: string, points = 30) => {
  const data = [];
  const now = Date.now();
  let baseValue = type === 'cpu' ? 40 : type === 'memory' ? 35 : type === 'network' ? 20 : 25;
  
  for (let i = points - 1; i >= 0; i--) {
    const variation = (Math.random() - 0.5) * 15;
    baseValue = Math.max(0, Math.min(100, baseValue + variation));
    
    data.push({
      time: new Date(now - i * 5000).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }),
      value: Math.round(baseValue * 10) / 10,
    });
  }
  return data;
};

export function SystemChart({ type, height = 280, className, realtime = true }: SystemChartProps) {
  const [data, setData] = useState(() => generateMockData(type));
  const [isAnimating, setIsAnimating] = useState(true);
  const colors = COLORS[type];
  const intervalRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    if (!realtime) return;
    
    intervalRef.current = setInterval(() => {
      setData(prev => {
        const lastValue = prev[prev.length - 1]?.value || 50;
        const variation = (Math.random() - 0.5) * 10;
        const newValue = Math.max(0, Math.min(100, lastValue + variation));
        
        return [
          ...prev.slice(1),
          {
            time: new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }),
            value: Math.round(newValue * 10) / 10,
          },
        ];
      });
    }, 3000);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [type, realtime]);

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (!active || !payload || !payload.length) return null;
    const value = payload[0].value;
    return (
      <div className="bg-bg-card border border-bg-border rounded-lg p-3 shadow-lg">
        <p className="text-xs text-text-muted">{label}</p>
        <p className="text-lg font-bold text-text-primary">{value}%</p>
      </div>
    );
  };

  return (
    <div className={cn('w-full h-full', className)} style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
          <defs>
            <linearGradient id={`gradient-${type}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={colors.primary} stopOpacity={0.3} />
              <stop offset="100%" stopColor={colors.primary} stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#2D333B" vertical={false} />
          <XAxis
            dataKey="time"
            stroke="#6E7681"
            fontSize={11}
            tickLine={false}
            axisLine={false}
            tick={{ fill: '#6E7681' }}
            interval="preserveStartEnd"
          />
          <YAxis
            stroke="#6E7681"
            fontSize={11}
            tickLine={false}
            axisLine={false}
            tick={{ fill: '#6E7681' }}
            domain={[0, 100]}
            tickCount={4}
          />
          <Tooltip content={<CustomTooltip />} />
          <Area
            type="monotone"
            dataKey="value"
            stroke={colors.primary}
            strokeWidth={2}
            fillOpacity={1}
            fill={`url(#gradient-${type})`}
            isAnimationActive={isAnimating}
            animationDuration={500}
            animationEasing="easeOut"
          />
          <Line
            type="monotone"
            dataKey="value"
            stroke={colors.primary}
            strokeWidth={2}
            dot={false}
            isAnimationActive={isAnimating}
            animationDuration={500}
            animationEasing="easeOut"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}