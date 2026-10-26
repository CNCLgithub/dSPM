import React, { useState, useEffect } from 'react';

interface NumericInputProps {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  disabled?: boolean;
  className?: string;
  label?: string;
  size?: 'sm' | 'md' | 'lg';
}

export const NumericInput: React.FC<NumericInputProps> = ({
  value,
  onChange,
  min,
  max,
  step = 1,
  disabled = false,
  className = '',
  label,
  size = 'md',
}) => {
  const [localValue, setLocalValue] = useState(String(value));

  useEffect(() => {
    setLocalValue(String(value));
  }, [value]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setLocalValue(e.target.value);
  };

  const handleBlur = () => {
    let numValue = parseFloat(localValue);
    
    if (isNaN(numValue)) {
      numValue = value;
    }
    
    if (min !== undefined && numValue < min) {
      numValue = min;
    }
    if (max !== undefined && numValue > max) {
      numValue = max;
    }
    
    // Round to step if specified
    if (step && step !== 1) {
      numValue = Math.round(numValue / step) * step;
    }
    
    setLocalValue(String(numValue));
    onChange(numValue);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleBlur();
    }
  };

  const sizeClasses = {
    sm: 'px-2 py-1 text-xs w-16',
    md: 'px-3 py-1.5 text-sm w-20',
    lg: 'px-4 py-2 text-base w-24',
  };

  return (
    <div className={`flex items-center gap-2 ${className}`}>
      {label && (
        <label className="text-sm text-gray-600 whitespace-nowrap">
          {label}
        </label>
      )}
      <input
        type="text"
        value={localValue}
        onChange={handleChange}
        onBlur={handleBlur}
        onKeyDown={handleKeyDown}
        disabled={disabled}
        className={`
          ${sizeClasses[size]}
          border border-gray-300 rounded
          focus:border-blue-500 focus:ring-1 focus:ring-blue-500
          disabled:bg-gray-100 disabled:text-gray-500
          text-center
        `}
      />
    </div>
  );
};
