import React from 'react';
import { CheckCircle, AlertCircle, AlertTriangle, Info } from 'lucide-react';
import type { StatusIndicatorProps } from './ControlBar.types';

const statusConfig = {
  info: {
    icon: Info,
    bgColor: 'bg-blue-50',
    textColor: 'text-blue-700',
    borderColor: 'border-blue-200',
  },
  success: {
    icon: CheckCircle,
    bgColor: 'bg-green-50',
    textColor: 'text-green-700',
    borderColor: 'border-green-200',
  },
  warning: {
    icon: AlertTriangle,
    bgColor: 'bg-yellow-50',
    textColor: 'text-yellow-700',
    borderColor: 'border-yellow-200',
  },
  error: {
    icon: AlertCircle,
    bgColor: 'bg-red-50',
    textColor: 'text-red-700',
    borderColor: 'border-red-200',
  },
};

export const StatusIndicator: React.FC<StatusIndicatorProps> = ({
  message,
  type,
}) => {
  const config = statusConfig[type];
  const Icon = config.icon;

  return (
    <div
      className={`
        flex items-center gap-2 px-4 py-2 rounded-lg border
        ${config.bgColor} ${config.textColor} ${config.borderColor}
      `}
    >
      <Icon className="w-4 h-4" />
      <span className="text-sm font-medium">{message}</span>
    </div>
  );
};
