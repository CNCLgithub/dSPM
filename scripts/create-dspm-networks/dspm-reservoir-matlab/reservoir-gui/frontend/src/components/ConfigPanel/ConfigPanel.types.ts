import type { Parameter } from '@/types/reservoir';
import type { Preset } from '@/types/presets';

export interface ConfigPanelProps {
  className?: string;
}

export interface NetworkConfigProps {
  nNeurons: number;
  gamma: number;
  jetOrder: number;
  decompilationOrder: number;
  onNeuronsChange: (n: number) => void;
  onGammaChange: (gamma: number) => void;
  onJetOrderChange: (order: number) => void;
  onDecompOrderChange: (order: number) => void;
}

export interface ParameterListProps {
  parameters: Parameter[];
  onAdd: (param: Parameter) => void;
  onUpdate: (name: string, value: number) => void;
  onRemove: (name: string) => void;
}

export interface PresetDropdownProps {
  presets: Preset[];
  onSelect: (preset: Preset) => void;
}
