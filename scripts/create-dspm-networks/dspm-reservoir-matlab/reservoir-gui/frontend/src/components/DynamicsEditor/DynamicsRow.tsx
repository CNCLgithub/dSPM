import React from 'react';
import katex from 'katex';
import { LatexInput } from './LatexInput';
import { CoefficientInput } from './CoefficientInput';
import { PORT_COLORS } from '@/constants/colors';
import type { DynamicsRowProps } from './DynamicsEditor.types';

export const DynamicsRow: React.FC<DynamicsRowProps> = ({
  index: _storeIndex,  // Store index (kept for future use in setEquation callbacks)
  displayIndex,
  latex,
  coefficient,
  isValid,
  errorMessage,
  onLatexChange,
  onCoefficientChange,
  isRecurrent,
}) => {
  const color = isRecurrent ? PORT_COLORS['rec-out'] : PORT_COLORS['ext-out'];
  
  // Variable name: ẋ for external, ẏ for recurrent
  const varName = isRecurrent ? 'y' : 'x';
  
  // Render LaTeX for · ẋ_n or ẏ_k =
  const renderedDot = React.useMemo(() => {
    try {
      return katex.renderToString(`\\cdot`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `·`;
    }
  }, []);

  const renderedVarDot = React.useMemo(() => {
    try {
      return katex.renderToString(`\\dot{${varName}}_{${displayIndex}}`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `${varName}̇${displayIndex}`;
    }
  }, [varName, displayIndex]);

  const renderedEquals = React.useMemo(() => {
    try {
      return katex.renderToString(`=`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `=`;
    }
  }, []);

  // Placeholder shows available variables - same for both since all outputs can depend on all inputs
  const placeholder = `f(\\vec{x}, \\vec{y})`;

  return (
    <div className="group flex items-center gap-3 px-5 py-3 
                    rounded-xl transition-colors
                    hover:bg-slate-50 dark:hover:bg-slate-800/30">
      {/* Subtle color indicator dot */}
      <div 
        className="w-2.5 h-2.5 rounded-full flex-shrink-0 opacity-70"
        style={{ backgroundColor: color.primary }}
      />
      
      {/* Coefficient input (τₙ(t) = [...] or τₖ(t) = [...]) */}
      <CoefficientInput
        value={coefficient}
        onChange={onCoefficientChange}
        displayIndex={displayIndex}
        isRecurrent={isRecurrent}
      />
      
      {/* Dot separator · */}
      <span 
        className="text-slate-400 dark:text-slate-500 flex-shrink-0"
        style={{ fontSize: '1.1rem' }}
        dangerouslySetInnerHTML={{ __html: renderedDot }}
      />
      
      {/* Variable label ẋₙ or ẏₖ */}
      <div 
        className="flex-shrink-0 text-slate-500 dark:text-slate-400"
        style={{ fontSize: '1.1rem' }}
        dangerouslySetInnerHTML={{ __html: renderedVarDot }}
      />
      
      {/* Equals sign */}
      <span 
        className="text-slate-400 dark:text-slate-500 flex-shrink-0"
        style={{ fontSize: '1.1rem' }}
        dangerouslySetInnerHTML={{ __html: renderedEquals }}
      />
      
      {/* Equation input [f(x)] - click to edit, renders LaTeX */}
      <LatexInput
        value={latex}
        onChange={onLatexChange}
        placeholder={placeholder}
        isValid={isValid}
        errorMessage={errorMessage}
      />
    </div>
  );
};
