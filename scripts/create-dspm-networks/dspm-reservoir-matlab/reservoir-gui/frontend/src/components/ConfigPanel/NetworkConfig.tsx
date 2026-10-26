import React from 'react';
import { LIMITS } from '@/constants/defaults';
import type { NetworkConfigProps } from './ConfigPanel.types';

export const NetworkConfig: React.FC<NetworkConfigProps> = ({
  nNeurons,
  gamma,
  jetOrder,
  decompilationOrder,
  onNeuronsChange,
  onGammaChange,
  onJetOrderChange,
  onDecompOrderChange,
}) => {
  return (
    <div className="grid grid-cols-2 gap-4">
      <ConfigInput
        label="N"
        value={nNeurons}
        onChange={onNeuronsChange}
        min={LIMITS.minNeurons}
        max={LIMITS.maxNeurons}
      />
      
      <ConfigInput
        label="γ"
        value={gamma}
        onChange={onGammaChange}
        min={LIMITS.minGamma}
        max={LIMITS.maxGamma}
      />
      
      <ConfigInput
        label="Jet"
        value={jetOrder}
        onChange={onJetOrderChange}
        min={1}
        max={LIMITS.maxJetOrder}
      />
      
      <ConfigInput
        label="Order"
        value={decompilationOrder}
        onChange={onDecompOrderChange}
        min={1}
        max={LIMITS.maxDecompOrder}
      />
    </div>
  );
};

// Internal component for config inputs
const ConfigInput: React.FC<{
  label: string;
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
}> = ({ label, value, onChange, min, max }) => {
  return (
    <div className="flex items-center gap-2">
      <span className="text-xs text-slate-400 dark:text-slate-500 w-10">
        {label}
      </span>
      <input
        type="number"
        value={value}
        onChange={(e) => {
          const v = parseInt(e.target.value);
          if (!isNaN(v)) onChange(Math.max(min ?? 0, Math.min(max ?? Infinity, v)));
        }}
        className="flex-1 px-2 py-1.5 text-sm text-center
                   bg-slate-50 dark:bg-slate-800
                   border-0 rounded-lg
                   text-slate-700 dark:text-slate-200
                   focus:ring-1 focus:ring-slate-300 dark:focus:ring-slate-600"
      />
    </div>
  );
};
