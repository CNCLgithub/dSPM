// Core reservoir configuration types

export type PortType = 'ext-in' | 'ext-out' | 'rec-in' | 'rec-out';

// Expansion point stored per-input for resilience to port changes
export interface ExpansionPoint {
  x: Record<number, number>;  // External inputs: { 1: 0, 2: 1.5 }
  y: Record<number, number>;  // Recurrent inputs: { 1: 0, 2: 0, 3: 2.0 }
}

export interface ReservoirConfig {
  nNeurons: number;
  gamma: number;
  dt: number;
  jetOrder: number;           // Will be inferred at compile time
  decompilationOrder: number; // Will be inferred at compile time
  
  // Port counts
  numExtInputs: number;
  numExtOutputs: number;
  numRecInputs: number;
  numRecOutputs: number;
  
  // Initialization hyperparameters
  B_scale: number;            // Scale factor for random B matrix
  B_sparsity: number;         // Sparsity fraction (1.0 = fully connected)
  
  // Expansion point for polynomial Taylor series
  expansionPoint: ExpansionPoint;
  
  // Debug
  verbose: boolean;
}

export interface DynamicsEquation {
  id: string;
  index: number;              // 1-indexed for display
  latex: string;              // RHS: User input for f(x) in g·ẋ = f(x)
  coefficient: string;        // LHS: Coefficient g(t) in g·ẋ = f(x), default "1"
  isValid: boolean;           // Parsing succeeded
  errorMessage?: string;      // Parsing error if any
}

export interface DynamicsConstant {
  id: string;
  latex: string;              // The symbol: '\sigma', '\beta_0'
  value: string;              // The value: '10', '8/3', 'x_1^2'
  raw: string;                // Original input: '\sigma = 10'
}

export interface Parameter {
  name: string;               // "beta_0", "sigma", etc.
  value: number;
  description?: string;
}

export interface SymbolicProgram {
  equations: DynamicsEquation[];
  parameters: Parameter[];
  compiledAt?: Date;
  residual?: number;
  relativeError?: number;
  rankR?: number;
}

export interface CompileResult {
  success: boolean;
  residual: number;
  relativeError: number;
  rankR: number;
  nMonomials: number;
  errorMessage?: string;
}
