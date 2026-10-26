import React from 'react';
import { Play, Loader2 } from 'lucide-react';
import type { CompileButtonProps } from './ControlBar.types';

export const CompileButton: React.FC<CompileButtonProps> = ({
  onClick,
  isCompiling,
  disabled = false,
}) => {
  return (
    <button
      onClick={onClick}
      disabled={disabled || isCompiling}
      className={`
        flex items-center gap-2
        px-6 py-2.5
        rounded-lg font-semibold
        transition-all duration-200
        ${isCompiling || disabled
          ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
          : 'bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800 shadow-md hover:shadow-lg'
        }
      `}
    >
      {isCompiling ? (
        <>
          <Loader2 className="w-4 h-4 animate-spin" />
          Compiling...
        </>
      ) : (
        <>
          <Play className="w-4 h-4" />
          Compile
        </>
      )}
    </button>
  );
};
