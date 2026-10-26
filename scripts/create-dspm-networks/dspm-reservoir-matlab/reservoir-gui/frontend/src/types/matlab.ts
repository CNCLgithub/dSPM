// Types for MATLAB <-> JavaScript communication

export type MatlabAction = 
  | 'init'
  | 'compile'
  | 'compile_result'
  | 'simulate'
  | 'simulate_result'
  | 'save'
  | 'save_result'
  | 'load'
  | 'export'
  | 'list_presets'
  | 'presets_list'
  | 'remove_preset'
  | 'remove_preset_result'
  | 'browse_saved_networks'
  | 'saved_networks_list'
  | 'add_to_presets'
  | 'add_to_presets_result'
  | 'load_network'
  | 'load_network_result';

export interface MatlabMessage {
  action: MatlabAction;
  payload?: unknown;
}

export interface InitPayload {
  reservoir?: {
    nNeurons: number;
    nRecurrentInputs: number;
    nExternalInputs: number;
    nRecurrentOutputs: number;
    nExternalOutputs: number;
    gamma: number;
    dt: number;
    basisStrings?: string[];
  };
  standaloneMode: boolean;
}

export interface CompilePayload {
  equations: Array<{
    latex: string;
    coefficient: string;
  }>;
  parameters: Array<{
    name: string;
    value: number;
  }>;
  config: {
    nNeurons: number;
    gamma: number;
    jetOrder: number;
    decompilationOrder: number;
  };
}

export interface CompileResultPayload {
  success: boolean;
  residual: number;
  relativeError: number;
  rankR: number;
  nMonomials: number;
  errorMessage?: string;
}

export interface SimulatePayload {
  tSteps: number;
  initialCondition?: number[];
}

export interface SimulateResultPayload {
  trajectory: number[][];
  time: number[];
}
