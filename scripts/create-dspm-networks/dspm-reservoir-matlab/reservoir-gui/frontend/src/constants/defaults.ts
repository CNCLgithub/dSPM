// Default values for reservoir configuration

export const DEFAULT_CONFIG = {
  nNeurons: 500,
  gamma: 100,
  dt: 0.01,
  jetOrder: 2,
  decompilationOrder: 3,
  
  // Default port counts
  numExtInputs: 2,
  numExtOutputs: 0,
  numRecInputs: 1,
  numRecOutputs: 1,
  
  // Initialization hyperparameters
  B_scale: 0.4,
  B_sparsity: 0.3,
  
  // Debug
  verbose: true,
} as const;

export const LIMITS = {
  minNeurons: 10,
  maxNeurons: 10000,
  minGamma: 1,
  maxGamma: 10000,
  minTau: 0.001,
  maxTau: 10000,
  minPorts: 0,
  maxPorts: 20,
  maxJetOrder: 5,
  maxDecompOrder: 6,
  minBScale: 0.01,
  maxBScale: 10,
  minBSparsity: 0.01,
  maxBSparsity: 1.0,
  minDt: 0.0001,
  maxDt: 1.0,
} as const;
