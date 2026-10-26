import { create } from 'zustand';
import type { ReservoirConfig, DynamicsEquation, DynamicsConstant, Parameter, CompileResult } from '@/types';
import type { NetworkSaveFile, SavedEquation, SavedConstant, BuiltInPreset, UserPreset, PresetNode } from '@/types/saveSchema';
import { DEFAULT_CONFIG } from '@/constants';

type PresetItem = BuiltInPreset | UserPreset;

interface ReservoirState {
  // Configuration
  config: ReservoirConfig;
  
  // Dynamics equations (one per output)
  equations: DynamicsEquation[];
  
  // Dynamics constants (shared across equations)
  constants: DynamicsConstant[];
  
  // Named parameters
  parameters: Parameter[];
  
  // Compilation state
  isCompiled: boolean;
  isCompiling: boolean;
  compileResult: CompileResult | null;
  
  // Random seed for reproducibility
  randomSeed: number | null;
  
  // Network metadata
  networkName: string;
  networkDescription: string;
  
  // User presets loaded from disk (flat list for backwards compat)
  userPresets: UserPreset[];
  
  // Nested preset tree structure
  presetTree: PresetNode[];
  
  // Actions - Config
  setConfig: (config: Partial<ReservoirConfig>) => void;
  setNeuronCount: (n: number) => void;
  setGamma: (gamma: number) => void;
  setDt: (dt: number) => void;
  setBScale: (scale: number) => void;
  setBSparsity: (sparsity: number) => void;
  setVerbose: (verbose: boolean) => void;
  setExpansionPointValue: (type: 'x' | 'y', index: number, value: number) => void;
  
  // Actions - Ports
  setPortCount: (type: 'ext-in' | 'ext-out' | 'rec-in' | 'rec-out', count: number) => void;
  incrementPort: (type: 'ext-in' | 'ext-out' | 'rec-in' | 'rec-out') => void;
  decrementPort: (type: 'ext-in' | 'ext-out' | 'rec-in' | 'rec-out') => void;
  
  // Actions - Equations
  setEquation: (index: number, latex: string) => void;
  setCoefficient: (index: number, coefficient: string) => void;
  syncEquationsWithOutputs: () => void;
  
  // Actions - Constants
  addConstant: (raw: string) => DynamicsConstant | null;
  updateConstant: (id: string, raw: string) => void;
  removeConstant: (id: string) => void;
  
  // Actions - Parameters
  addParameter: (param: Parameter) => void;
  updateParameter: (name: string, value: number) => void;
  removeParameter: (name: string) => void;
  
  // Actions - Compilation
  setCompiling: (isCompiling: boolean) => void;
  setCompileResult: (result: CompileResult | null) => void;
  
  // Actions - Presets (legacy)
  loadPreset: (preset: {
    config: Partial<ReservoirConfig>;
    equations: Array<{ latex: string; coefficient?: string }>;
    constants?: Array<{ raw: string }>;
    parameters: Parameter[];
  }) => void;
  
  // Actions - Presets (new schema)
  loadPresetV2: (preset: PresetItem) => void;
  setUserPresets: (presets: UserPreset[]) => void;
  setPresetTree: (tree: PresetNode[]) => void;
  
  // Actions - Network metadata
  setNetworkName: (name: string) => void;
  setNetworkDescription: (description: string) => void;
  setRandomSeed: (seed: number | null) => void;
  
  // Actions - Serialization
  getNetworkSaveFile: (name: string, description: string, isPreset: boolean) => NetworkSaveFile;
  
  // Actions - Reset
  reset: () => void;
}

const createInitialEquations = (count: number): DynamicsEquation[] => {
  return Array.from({ length: count }, (_, i) => ({
    id: `eq-${i + 1}`,
    index: i + 1,
    latex: '',
    coefficient: '1',
    isValid: true,
  }));
};

// Parse a constant definition like "\sigma = 10" or "\beta_0 = 8/3"
const parseConstantDefinition = (raw: string): { latex: string; value: string } | null => {
  // Match patterns like: \symbol = value, \symbol_n = value
  const match = raw.match(/^\s*(\\?[a-zA-Z]+(?:_\{?[a-zA-Z0-9]+\}?)?)\s*=\s*(.+)\s*$/);
  if (!match) return null;
  
  const [, latex, value] = match;
  if (!latex || !value.trim()) return null;
  
  return { latex: latex.trim(), value: value.trim() };
};

let constantIdCounter = 0;

// Create initial expansion point based on port counts
const createInitialExpansionPoint = (numExtInputs: number, numRecInputs: number) => {
  const x: Record<number, number> = {};
  const y: Record<number, number> = {};
  
  for (let i = 1; i <= numExtInputs; i++) {
    x[i] = 0;
  }
  for (let i = 1; i <= numRecInputs; i++) {
    y[i] = 0;
  }
  
  return { x, y };
};

const initialConfig: ReservoirConfig = {
  nNeurons: DEFAULT_CONFIG.nNeurons,
  gamma: DEFAULT_CONFIG.gamma,
  dt: DEFAULT_CONFIG.dt,
  jetOrder: DEFAULT_CONFIG.jetOrder,
  decompilationOrder: DEFAULT_CONFIG.decompilationOrder,
  numExtInputs: DEFAULT_CONFIG.numExtInputs,
  numExtOutputs: DEFAULT_CONFIG.numExtOutputs,
  numRecInputs: DEFAULT_CONFIG.numRecInputs,
  numRecOutputs: DEFAULT_CONFIG.numRecOutputs,
  B_scale: DEFAULT_CONFIG.B_scale,
  B_sparsity: DEFAULT_CONFIG.B_sparsity,
  expansionPoint: createInitialExpansionPoint(DEFAULT_CONFIG.numExtInputs, DEFAULT_CONFIG.numRecInputs),
  verbose: DEFAULT_CONFIG.verbose,
};

export const useReservoirStore = create<ReservoirState>((set, get) => ({
  config: initialConfig,
  equations: createInitialEquations(initialConfig.numRecOutputs + initialConfig.numExtOutputs),
  constants: [],
  parameters: [],
  isCompiled: false,
  isCompiling: false,
  compileResult: null,
  randomSeed: null,
  networkName: '',
  networkDescription: '',
  userPresets: [],
  presetTree: [],

  setConfig: (newConfig) => set((state) => ({
    config: { ...state.config, ...newConfig },
    isCompiled: false,
    compileResult: null,
  })),

  setNeuronCount: (n) => set((state) => ({
    config: { ...state.config, nNeurons: n },
    isCompiled: false,
    compileResult: null,
  })),

  setGamma: (gamma) => set((state) => ({
    config: { ...state.config, gamma },
    isCompiled: false,
    compileResult: null,
  })),

  setDt: (dt) => set((state) => ({
    config: { ...state.config, dt },
    isCompiled: false,
    compileResult: null,
  })),

  setBScale: (B_scale) => set((state) => ({
    config: { ...state.config, B_scale },
    isCompiled: false,
    compileResult: null,
  })),

  setBSparsity: (B_sparsity) => set((state) => ({
    config: { ...state.config, B_sparsity },
    isCompiled: false,
    compileResult: null,
  })),

  setVerbose: (verbose) => set((state) => ({
    config: { ...state.config, verbose },
  })),

  setExpansionPointValue: (type, index, value) => set((state) => ({
    config: {
      ...state.config,
      expansionPoint: {
        ...state.config.expansionPoint,
        [type]: {
          ...state.config.expansionPoint[type],
          [index]: value,
        },
      },
    },
    isCompiled: false,
    compileResult: null,
  })),

  setPortCount: (type, count) => {
    const portKey = {
      'ext-in': 'numExtInputs',
      'ext-out': 'numExtOutputs',
      'rec-in': 'numRecInputs',
      'rec-out': 'numRecOutputs',
    }[type] as keyof ReservoirConfig;

    const newCount = Math.max(0, count);
    const state = get();
    const oldCount = state.config[portKey] as number;
    
    // Helper to update expansion point for a given input type
    const updateExpansionPoint = (
      current: Record<number, number>,
      oldN: number,
      newN: number
    ): Record<number, number> => {
      const updated = { ...current };
      
      if (newN > oldN) {
        // Adding inputs: add new entries with default 0
        for (let i = oldN + 1; i <= newN; i++) {
          updated[i] = 0;
        }
      } else if (newN < oldN) {
        // Removing inputs: delete the removed indices
        for (let i = newN + 1; i <= oldN; i++) {
          delete updated[i];
        }
      }
      
      return updated;
    };
    
    // If changing rec-out, also update rec-in (they are tethered)
    // NOTE: rec-in buttons are hidden in UI, but keeping this logic for programmatic changes
    if (type === 'rec-out') {
      const oldRecCount = state.config.numRecInputs;
      set((state) => ({
        config: { 
          ...state.config, 
          numRecOutputs: newCount,
          numRecInputs: newCount,  // Tether: rec-in always equals rec-out
          expansionPoint: {
            ...state.config.expansionPoint,
            y: updateExpansionPoint(state.config.expansionPoint.y, oldRecCount, newCount),
          },
        },
        isCompiled: false,
        compileResult: null,
      }));
    } else if (type === 'ext-in') {
      set((state) => ({
        config: { 
          ...state.config, 
          numExtInputs: newCount,
          expansionPoint: {
            ...state.config.expansionPoint,
            x: updateExpansionPoint(state.config.expansionPoint.x, oldCount, newCount),
          },
        },
        isCompiled: false,
        compileResult: null,
      }));
    } else if (type === 'rec-in') {
      // rec-in is tethered to rec-out, so this shouldn't be called directly
      // but handle it anyway for completeness
      set((state) => ({
        config: { 
          ...state.config, 
          numRecInputs: newCount,
          expansionPoint: {
            ...state.config.expansionPoint,
            y: updateExpansionPoint(state.config.expansionPoint.y, oldCount, newCount),
          },
        },
        isCompiled: false,
        compileResult: null,
      }));
    } else {
      // ext-out doesn't affect expansion point
      set((state) => ({
        config: { ...state.config, [portKey]: newCount },
        isCompiled: false,
        compileResult: null,
      }));
    }
    
    // Sync equations if outputs changed
    if (type === 'ext-out' || type === 'rec-out') {
      get().syncEquationsWithOutputs();
    }
  },

  incrementPort: (type) => {
    const state = get();
    const portKey = {
      'ext-in': 'numExtInputs',
      'ext-out': 'numExtOutputs',
      'rec-in': 'numRecInputs',
      'rec-out': 'numRecOutputs',
    }[type] as keyof ReservoirConfig;
    
    const current = state.config[portKey] as number;
    state.setPortCount(type, current + 1);
  },

  decrementPort: (type) => {
    const state = get();
    const portKey = {
      'ext-in': 'numExtInputs',
      'ext-out': 'numExtOutputs',
      'rec-in': 'numRecInputs',
      'rec-out': 'numRecOutputs',
    }[type] as keyof ReservoirConfig;
    
    const current = state.config[portKey] as number;
    if (current > 0) {
      state.setPortCount(type, current - 1);
    }
  },

  setEquation: (index, latex) => set((state) => ({
    equations: state.equations.map((eq) =>
      eq.index === index ? { ...eq, latex, isValid: true } : eq
    ),
    isCompiled: false,
    compileResult: null,
  })),

  setCoefficient: (index, coefficient) => set((state) => ({
    equations: state.equations.map((eq) =>
      eq.index === index ? { ...eq, coefficient } : eq
    ),
    isCompiled: false,
    compileResult: null,
  })),

  syncEquationsWithOutputs: () => set((state) => {
    const totalOutputs = state.config.numRecOutputs + state.config.numExtOutputs;
    const currentCount = state.equations.length;
    
    if (totalOutputs === currentCount) return state;
    
    if (totalOutputs > currentCount) {
      // Add new equations
      const newEquations = [...state.equations];
      for (let i = currentCount + 1; i <= totalOutputs; i++) {
        newEquations.push({
          id: `eq-${i}`,
          index: i,
          latex: '',
          coefficient: '1',
          isValid: true,
        });
      }
      return { equations: newEquations };
    } else {
      // Remove excess equations
      return { equations: state.equations.slice(0, totalOutputs) };
    }
  }),

  addConstant: (raw) => {
    const parsed = parseConstantDefinition(raw);
    if (!parsed) return null;
    
    const newConstant: DynamicsConstant = {
      id: `const-${++constantIdCounter}`,
      latex: parsed.latex,
      value: parsed.value,
      raw,
    };
    
    set((state) => ({
      constants: [...state.constants, newConstant],
      isCompiled: false,
      compileResult: null,
    }));
    
    return newConstant;
  },

  updateConstant: (id, raw) => {
    const parsed = parseConstantDefinition(raw);
    if (!parsed) return;
    
    set((state) => ({
      constants: state.constants.map((c) =>
        c.id === id ? { ...c, latex: parsed.latex, value: parsed.value, raw } : c
      ),
      isCompiled: false,
      compileResult: null,
    }));
  },

  removeConstant: (id) => set((state) => ({
    constants: state.constants.filter((c) => c.id !== id),
    isCompiled: false,
    compileResult: null,
  })),

  addParameter: (param) => set((state) => ({
    parameters: [...state.parameters, param],
  })),

  updateParameter: (name, value) => set((state) => ({
    parameters: state.parameters.map((p) =>
      p.name === name ? { ...p, value } : p
    ),
    isCompiled: false,
    compileResult: null,
  })),

  removeParameter: (name) => set((state) => ({
    parameters: state.parameters.filter((p) => p.name !== name),
  })),

  setCompiling: (isCompiling) => set({ isCompiling }),

  setCompileResult: (result) => set({
    compileResult: result,
    isCompiled: result?.success ?? false,
    isCompiling: false,
  }),

  loadPreset: (preset) => {
    set((state) => ({
      config: { ...state.config, ...preset.config },
      parameters: preset.parameters,
      isCompiled: false,
      compileResult: null,
    }));
    
    // Sync equations first
    get().syncEquationsWithOutputs();
    
    // Then populate with preset equations
    set((state) => ({
      equations: state.equations.map((eq, i) => ({
        ...eq,
        latex: preset.equations[i]?.latex ?? '',
        coefficient: preset.equations[i]?.coefficient ?? '1',
      })),
    }));
    
    // Load constants if provided
    if (preset.constants) {
      const newConstants: DynamicsConstant[] = [];
      for (const c of preset.constants) {
        const parsed = parseConstantDefinition(c.raw);
        if (parsed) {
          newConstants.push({
            id: `const-${++constantIdCounter}`,
            latex: parsed.latex,
            value: parsed.value,
            raw: c.raw,
          });
        }
      }
      set({ constants: newConstants });
    }
  },

  loadPresetV2: (preset: PresetItem) => {
    // Convert new schema to internal state
    const { config: savedConfig, topology, equations: savedEqs, constants: savedConsts } = preset;
    
    // Build expansion point from saved format
    // Handle both numeric keys ("1") and prefixed keys ("x1")
    const parseExpansionKey = (k: string): number => {
      // Strip 'x' prefix if present, then parse
      const numeric = k.replace(/^x/, '');
      return parseInt(numeric, 10);
    };

    const expansionPoint = {
      x: Object.fromEntries(
        Object.entries(savedConfig.expansion_point.x || {}).map(([k, v]) => [parseExpansionKey(k), v])
      ),
      y: Object.fromEntries(
        Object.entries(savedConfig.expansion_point.y || {}).map(([k, v]) => [parseExpansionKey(k), v])
      ),
    };
    
    // Update config
    set((state) => ({
      config: {
        ...state.config,
        nNeurons: savedConfig.n_neurons,
        gamma: savedConfig.gamma,
        dt: savedConfig.dt,
        B_scale: savedConfig.B_scale,
        B_sparsity: savedConfig.B_sparsity,
        numExtInputs: topology.n_external_inputs,
        numExtOutputs: topology.n_external_outputs,
        numRecInputs: topology.n_recurrent_inputs,
        numRecOutputs: topology.n_recurrent_outputs,
        expansionPoint,
      },
      randomSeed: savedConfig.random_seed || null,
      networkName: preset.name,
      networkDescription: preset.description,
      isCompiled: false,
      compileResult: null,
    }));
    
    // Sync equations first
    get().syncEquationsWithOutputs();
    
    // Then populate with preset equations
    set((state) => ({
      equations: state.equations.map((eq, i) => ({
        ...eq,
        latex: savedEqs[i]?.latex ?? '',
        coefficient: savedEqs[i]?.tau ?? '1',
      })),
    }));
    
    // Load constants - use display_value for nice LaTeX rendering if available
    const newConstants: DynamicsConstant[] = savedConsts.map((c) => {
      const displayVal = c.display_value ?? String(c.value);
      return {
        id: `const-${++constantIdCounter}`,
        latex: c.name,
        value: displayVal,
        raw: `${c.name} = ${displayVal}`,
      };
    });
    
    // Convert constants to parameters (always use numeric value for computation)
    const newParameters: Parameter[] = savedConsts.map(c => ({
      name: c.name,
      value: c.value,
      description: c.description,
    }));
    
    set({ 
      constants: newConstants,
      parameters: newParameters,
    });
  },

  setUserPresets: (presets) => set({ userPresets: presets }),
  
  setPresetTree: (tree) => set({ presetTree: tree }),

  setNetworkName: (name) => set({ networkName: name }),

  setNetworkDescription: (description) => set({ networkDescription: description }),

  setRandomSeed: (seed) => set({ randomSeed: seed }),

  getNetworkSaveFile: (name, description, isPreset) => {
    const state = get();
    const now = new Date().toISOString();
    
    // Convert expansion point to string keys for JSON
    const expansionPoint = {
      x: Object.fromEntries(
        Object.entries(state.config.expansionPoint.x).map(([k, v]) => [String(k), v])
      ),
      y: Object.fromEntries(
        Object.entries(state.config.expansionPoint.y).map(([k, v]) => [String(k), v])
      ),
    };
    
    // Convert equations to saved format
    const savedEquations: SavedEquation[] = state.equations.map((eq, i) => ({
      index: eq.index,
      outputType: i < state.config.numExtOutputs ? 'external' : 'recurrent',
      tau: eq.coefficient,
      latex: eq.latex,
    }));
    
    // Convert constants/parameters to saved format
    const savedConstants: SavedConstant[] = state.parameters.map(p => ({
      name: p.name,
      value: p.value,
      description: p.description,
    }));
    
    return {
      version: '1.0',
      name,
      description,
      created: now,
      modified: now,
      is_preset: isPreset,
      config: {
        n_neurons: state.config.nNeurons,
        gamma: state.config.gamma,
        dt: state.config.dt,
        B_scale: state.config.B_scale,
        B_sparsity: state.config.B_sparsity,
        random_seed: state.randomSeed ?? 0, // Will be set by MATLAB if 0
        expansion_point: expansionPoint,
      },
      topology: {
        n_external_inputs: state.config.numExtInputs,
        n_external_outputs: state.config.numExtOutputs,
        n_recurrent_inputs: state.config.numRecInputs,
        n_recurrent_outputs: state.config.numRecOutputs,
      },
      inferred: {
        jet_order: 1, // Will be computed by MATLAB
        decompilation_order: 2, // Will be computed by MATLAB
      },
      equations: savedEquations,
      constants: savedConstants,
    };
  },

  reset: () => set({
    config: initialConfig,
    equations: createInitialEquations(initialConfig.numRecOutputs + initialConfig.numExtOutputs),
    constants: [],
    parameters: [],
    isCompiled: false,
    isCompiling: false,
    compileResult: null,
    randomSeed: null,
    networkName: '',
    networkDescription: '',
  }),
}));
