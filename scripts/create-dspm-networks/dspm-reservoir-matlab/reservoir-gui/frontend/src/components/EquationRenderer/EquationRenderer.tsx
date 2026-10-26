import React from 'react';
import { RenderedEquation } from './RenderedEquation';
import { useReservoirStore } from '@/stores/reservoirStore';
import type { EquationRendererProps } from './EquationRenderer.types';

export const EquationRenderer: React.FC<EquationRendererProps> = ({
  className = '',
}) => {
  const { config, equations } = useReservoirStore();
  const { numRecOutputs } = config;

  if (equations.length === 0) {
    return (
      <div className={`flex items-center justify-center h-full 
                       text-slate-400 dark:text-slate-600 text-base ${className}`}>
        No equations defined
      </div>
    );
  }

  return (
    <div className={`flex flex-col p-6 h-full overflow-y-auto ${className}`}>
      {/* Subtle header */}
      <p className="text-sm font-medium text-slate-400 dark:text-slate-500 mb-4">
        Preview
      </p>
      
      {/* Rendered equations */}
      <div className="flex flex-col divide-y divide-slate-100 dark:divide-slate-800">
        {equations.map((eq, idx) => (
          <RenderedEquation
            key={eq.id}
            index={eq.index}
            latex={eq.latex}
            coefficient={eq.coefficient}
            isRecurrent={idx < numRecOutputs}
          />
        ))}
      </div>
    </div>
  );
};
