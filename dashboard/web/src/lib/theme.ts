export const theme = {
  colors: {
    background: '#0D1117',
    surface: '#161B22',
    border: '#2D333B',
    borderHover: '#3D444D',
    primary: '#3B82F6',
    primaryHover: '#2563EB',
    primaryLight: '#1E3A5F',
    success: '#10B981',
    successLight: '#064E3B',
    warning: '#F59E0B',
    warningLight: '#78350F',
    danger: '#EF4444',
    dangerLight: '#7F1D1D',
    text: '#E6EDF3',
    textMuted: '#8B949E',
    textSubtle: '#6E7681',
  },
  borderRadius: {
    sm: '6px',
    md: '10px',
    lg: '14px',
    xl: '18px',
  },
  shadows: {
    sm: '0 1px 2px rgba(0, 0, 0, 0.3)',
    md: '0 4px 12px rgba(0, 0, 0, 0.4)',
    lg: '0 8px 24px rgba(0, 0, 0, 0.5)',
  },
  transitions: {
    fast: '150ms ease',
    normal: '200ms ease',
    slow: '300ms ease',
  },
  spacing: {
    xs: '4px',
    sm: '8px',
    md: '16px',
    lg: '24px',
    xl: '32px',
  },
} as const;

export type Theme = typeof theme;