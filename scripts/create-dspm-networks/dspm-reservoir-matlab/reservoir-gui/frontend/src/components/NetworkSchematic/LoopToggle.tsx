import React from 'react';

interface LoopToggleProps {
  isClosedLoop: boolean;
  onToggle: () => void;
  className?: string;
}

export const LoopToggle: React.FC<LoopToggleProps> = ({
  isClosedLoop,
  onToggle,
  className = '',
}) => {
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <span 
        className={`text-sm font-medium transition-colors cursor-pointer select-none ${
          !isClosedLoop 
            ? 'text-slate-700 dark:text-slate-200' 
            : 'text-slate-400 dark:text-slate-600'
        }`}
        onClick={() => !isClosedLoop || onToggle()}
      >
        Open
      </span>
      
      <button
        onClick={onToggle}
        className={`
          relative w-11 h-6 rounded-full
          transition-colors duration-200 ease-in-out
          focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-400
          ${isClosedLoop 
            ? 'bg-slate-700 dark:bg-slate-500' 
            : 'bg-slate-300 dark:bg-slate-600'}
        `}
        role="switch"
        aria-checked={isClosedLoop}
      >
        <span
          className={`
            absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full
            transition-transform duration-200 ease-in-out shadow-md
            ${isClosedLoop ? 'translate-x-5' : 'translate-x-0'}
          `}
        />
      </button>
      
      <span 
        className={`text-sm font-medium transition-colors cursor-pointer select-none ${
          isClosedLoop 
            ? 'text-slate-700 dark:text-slate-200' 
            : 'text-slate-400 dark:text-slate-600'
        }`}
        onClick={() => isClosedLoop || onToggle()}
      >
        Closed
      </span>
    </div>
  );
};
