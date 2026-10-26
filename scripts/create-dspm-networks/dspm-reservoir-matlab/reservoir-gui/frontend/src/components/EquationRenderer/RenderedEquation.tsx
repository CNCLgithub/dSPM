import React, { useMemo } from 'react';
import katex from 'katex';
import { prepareForKatex } from '@/utils/latexParser';
import { PORT_COLORS } from '@/constants/colors';
import type { RenderedEquationProps } from './EquationRenderer.types';

export const RenderedEquation: React.FC<RenderedEquationProps> = ({
  index,
  latex,
  coefficient,
  isRecurrent,
}) => {
  const color = isRecurrent ? PORT_COLORS['rec-out'] : PORT_COLORS['ext-out'];

  const renderedHtml = useMemo(() => {
    if (!latex.trim()) {
      return { __html: '<span class="text-slate-300 dark:text-slate-600 italic">Empty</span>' };
    }

    try {
      // Build the full equation with coefficient on LHS
      const preparedLatex = prepareForKatex(latex);
      const preparedCoeff = prepareForKatex(coefficient);
      
      let fullEquation: string;
      if (coefficient === '1') {
        // Simple case: just ẋ = f(x)
        fullEquation = `\\dot{x}_{${index}} = ${preparedLatex}`;
      } else {
        // General case: g(t) · ẋ = f(x)
        fullEquation = `\\left(${preparedCoeff}\\right) \\cdot \\dot{x}_{${index}} = ${preparedLatex}`;
      }

      const html = katex.renderToString(fullEquation, {
        throwOnError: false,
        displayMode: false,
        output: 'html',
      });
      return { __html: html };
    } catch (error) {
      return { __html: `<span class="text-red-400">Parse error</span>` };
    }
  }, [latex, coefficient, index]);

  return (
    <div className="flex items-start gap-4 py-4 group">
      {/* Subtle color dot */}
      <div 
        className="w-2 h-2 rounded-full mt-2 flex-shrink-0 opacity-60 
                   group-hover:opacity-100 transition-opacity"
        style={{ backgroundColor: color.primary }}
      />
      
      {/* Rendered equation */}
      <div 
        className="text-slate-700 dark:text-slate-200 text-lg"
        style={{ fontSize: '1.1rem' }}
        dangerouslySetInnerHTML={renderedHtml}
      />
    </div>
  );
};
