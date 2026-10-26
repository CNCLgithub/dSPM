export interface ControlBarProps {
  className?: string;
}

export interface CompileButtonProps {
  onClick: () => void;
  isCompiling: boolean;
  disabled?: boolean;
}

export interface StatusIndicatorProps {
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
}
