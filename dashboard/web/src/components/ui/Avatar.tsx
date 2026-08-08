'use client';

import { forwardRef, ImgHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface AvatarProps extends ImgHTMLAttributes<HTMLImageElement> {
  src?: string | null;
  fallback?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  shape?: 'circle' | 'square';
}

const sizeClasses = {
  xs: 'w-6 h-6 text-xs',
  sm: 'w-8 h-8 text-sm',
  md: 'w-10 h-10 text-base',
  lg: 'w-12 h-12 text-lg',
  xl: 'w-16 h-16 text-xl',
};

export const Avatar = forwardRef<HTMLDivElement, AvatarProps>(
  ({ className, src, fallback, size = 'md', shape = 'circle', ...props }, ref) => {
    const [imgError, setImgError] = useState(false);
    
    const getInitials = (name: string) => {
      return name
        .split(' ')
        .map((n) => n[0])
        .join('')
        .toUpperCase()
        .slice(0, 2);
    };

    return (
      <div
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center font-medium bg-primary/10 text-primary overflow-hidden',
          sizeClasses[size],
          shape === 'circle' ? 'rounded-full' : 'rounded-lg',
          className
        )}
        {...props}
      >
        {src && !imgError ? (
          <img
            src={src}
            alt=""
            className="w-full h-full object-cover"
            onError={() => setImgError(true)}
          />
        ) : (
          <span>{fallback ? getInitials(fallback) : '?'}</span>
        )}
      </div>
    );
  }
);

Avatar.displayName = 'Avatar';

import { useState } from 'react';