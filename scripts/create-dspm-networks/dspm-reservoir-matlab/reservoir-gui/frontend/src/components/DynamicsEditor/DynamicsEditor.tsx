import React from 'react';
import { DynamicsRow } from './DynamicsRow';
import { ConstantsBar } from './ConstantsBar';
import { useReservoirStore } from '@/stores/reservoirStore';

interface DynamicsEditorProps {
  className?: string;
}

export const DynamicsEditor: React.FC<DynamicsEditorProps> = ({ className = '' }) => {
  const { config, equations, setEquation, setCoefficient } = useReservoirStore();
  const { numRecOutputs } = config;

  if (equations.length === 0) {
    return (
      <div className={`flex flex-col h-full ${className}`}>
        {/* Header with constants */}
        <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-100 dark:border-slate-800">
          <span className="text-base font-medium text-slate-400 dark:text-slate-500">
            Dynamics
          </span>
          <div className="h-4 w-px bg-slate-200 dark:bg-slate-700" />
          <ConstantsBar />
        </div>
        
        <div className="flex-1 flex items-center justify-center
                        text-slate-400 dark:text-slate-600 text-base">
          Add outputs to define dynamics
        </div>
      </div>
    );
  }

  // Split equations into external and recurrent
  // In the store: first numRecOutputs are recurrent (ẏ), rest are external (ẋ)
  const recurrentEquations = equations.slice(0, numRecOutputs);
  const externalEquations = equations.slice(numRecOutputs);

  return (
    <div className={`flex flex-col h-full ${className}`}>
      {/* Header with constants */}
      <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-100 dark:border-slate-800">
        <span className="text-base font-medium text-slate-400 dark:text-slate-500 flex-shrink-0">
          Dynamics
        </span>
        <div className="h-4 w-px bg-slate-200 dark:bg-slate-700 flex-shrink-0" />
        <ConstantsBar />
      </div>
      
      {/* Equation rows - scrollable */}
      <div className="flex-1 overflow-y-auto py-2">
        <div className="flex flex-col">
          {/* External outputs first (ẋₙ) */}
          {externalEquations.map((eq, idx) => (
            <DynamicsRow
              key={eq.id}
              index={eq.index}
              displayIndex={idx + 1}
              latex={eq.latex}
              coefficient={eq.coefficient}
              isValid={eq.isValid}
              errorMessage={eq.errorMessage}
              onLatexChange={(latex) => setEquation(eq.index, latex)}
              onCoefficientChange={(coefficient) => setCoefficient(eq.index, coefficient)}
              isRecurrent={false}
            />
          ))}
          
          {/* Recurrent outputs (ẏₖ) */}
          {recurrentEquations.map((eq, idx) => (
            <DynamicsRow
              key={eq.id}
              index={eq.index}
              displayIndex={idx + 1}
              latex={eq.latex}
              coefficient={eq.coefficient}
              isValid={eq.isValid}
              errorMessage={eq.errorMessage}
              onLatexChange={(latex) => setEquation(eq.index, latex)}
              onCoefficientChange={(coefficient) => setCoefficient(eq.index, coefficient)}
              isRecurrent={true}
            />
          ))}
        </div>
      </div>
    </div>
  );
};
