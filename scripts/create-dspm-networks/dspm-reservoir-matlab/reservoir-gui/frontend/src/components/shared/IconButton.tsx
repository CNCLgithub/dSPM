import React from 'react';

interface IconButtonProps {
  onClick: () => void;
  disabled?: boolean;
  variant?: 'add' | 'remove';
  color: string;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
  title?: string;
}

export const IconButton: React.FC<IconButtonProps> = ({
  onClick,
  disabled = false,
  variant = 'add',
  color,
  size = 'md',
  className = '',
  title,
}) => {
  const sizeClasses = {
    sm: 'w-5 h-5 text-xs',
    md: 'w-6 h-6 text-sm',
    lg: 'w-8 h-8 text-base',
  };

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`
        ${sizeClasses[size]}
        rounded-full
        flex items-center justify-center
        font-bold
        transition-all duration-150
        ${disabled 
          ? 'opacity-40 cursor-not-allowed' 
          : 'hover:scale-110 active:scale-95 cursor-pointer'
        }
        ${className}
      `}
      style={{
        backgroundColor: disabled ? '#e5e7eb' : color,
        color: 'white',
      }}
    >
      {variant === 'add' ? '+' : '−'}
    </button>
  );
};
