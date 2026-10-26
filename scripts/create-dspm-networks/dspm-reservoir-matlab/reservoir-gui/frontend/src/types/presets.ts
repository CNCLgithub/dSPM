// Types for preset configurations
import type { BuiltInPreset } from './saveSchema';

// Legacy Preset type for backward compatibility during transition
export interface Preset {
  id: string;
  name: string;
  description: string;
  
  // Dimensions
  numRecInputs: number;
  numRecOutputs: number;
  numExtInputs: number;
  numExtOutputs: number;
  
  // Recommended settings
  recommendedN: number;
  recommendedGamma: number;
  recommendedJetOrder: number;
  recommendedDecompOrder: number;
  
  // Dynamics
  equations: Array<{
    latex: string;
    tau: number;
  }>;
  
  // Parameters
  parameters: Array<{
    name: string;
    value: number;
    description?: string;
  }>;
}

// Helper to create a built-in preset in the new schema format
const createBuiltInPreset = (
  name: string,
  description: string,
  topology: { extIn: number; extOut: number; recIn: number; recOut: number },
  settings: { neurons: number; gamma: number; jetOrder: number; decompOrder: number; dt?: number; B_scale?: number },
  equations: Array<{ latex: string; tau: string }>,
  constants: Array<{ name: string; value: number; display_value?: string; description?: string }>,
  extra?: { validated?: boolean; scaling?: object; expected_behavior?: object }
): BuiltInPreset => ({
  version: '1.0',
  name,
  description,
  created: '2025-01-01T00:00:00Z',
  modified: '2025-01-16T00:00:00Z',
  is_preset: true,
  isBuiltIn: true,
  ...(extra?.validated !== undefined && { validated: extra.validated }),
  ...(extra?.scaling && { scaling: extra.scaling }),
  ...(extra?.expected_behavior && { expected_behavior: extra.expected_behavior }),
  config: {
    n_neurons: settings.neurons,
    gamma: settings.gamma,
    dt: settings.dt ?? 0.01,
    B_scale: settings.B_scale ?? 0.4,  // Updated default from 0.5 to 0.4
    B_sparsity: 1.0,
    random_seed: 0, // Will be generated on first use
    expansion_point: {
      x: Object.fromEntries(Array.from({ length: topology.extIn }, (_, i) => [String(i + 1), 0])),
      y: Object.fromEntries(Array.from({ length: topology.recIn }, (_, i) => [String(i + 1), 0])),
    },
  },
  topology: {
    n_external_inputs: topology.extIn,
    n_external_outputs: topology.extOut,
    n_recurrent_inputs: topology.recIn,
    n_recurrent_outputs: topology.recOut,
  },
  inferred: {
    jet_order: settings.jetOrder,
    decompilation_order: settings.decompOrder,
  },
  equations: equations.map((eq, i) => ({
    index: i + 1,
    outputType: 'recurrent' as const,
    tau: eq.tau,
    latex: eq.latex,
  })),
  constants: constants.map(c => ({
    name: c.name,
    value: c.value,
    display_value: c.display_value,
    description: c.description,
  })),
});

// Category structure for built-in presets
export interface PresetCategory {
  name: string;
  presets: string[];  // Names of presets in this category
}

export const BUILT_IN_PRESET_CATEGORIES: PresetCategory[] = [
  {
    name: 'Chaotic Attractors (Scaled)',
    presets: ['Lorenz Attractor (Scaled)', 'Rössler Attractor (Scaled)', 'Chen Attractor (Scaled)'],
  },
  {
    name: 'Chaotic Attractors (Standard)',
    presets: ['Lorenz Attractor (Standard)', 'Rössler Attractor (Standard)'],
  },
  {
    name: 'Oscillators',
    presets: ['Harmonic Oscillator', 'Van der Pol Oscillator', 'Duffing Oscillator', 'Hopf Bifurcation'],
  },
  {
    name: 'Neuroscience',
    presets: ['FitzHugh-Nagumo', 'Hindmarsh-Rose'],
  },
  {
    name: 'Chemical & Biological',
    presets: ['Brusselator', 'Lotka-Volterra'],
  },
];

// New format built-in presets
export const BUILT_IN_PRESETS_V2: BuiltInPreset[] = [
  // ═══════════════════════════════════════════════════════════════════════
  // CHAOTIC ATTRACTORS (SCALED VERSIONS)
  // ═══════════════════════════════════════════════════════════════════════
  
  // VALIDATED: Lorenz Attractor (Scaled)
  createBuiltInPreset(
    'Lorenz Attractor (Scaled)',
    'Validated 3D chaotic system. Coordinate-scaled to stay in tanh linear regime [-0.1, 0.1].',
    { extIn: 0, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 3, dt: 0.001, B_scale: 0.4 },
    [
      { latex: '\\sigma (y_2 - y_1)', tau: '10' },
      { latex: 'y_1 (\\rho - 27 - s \\cdot y_3) - y_2', tau: '10' },
      { latex: 's \\cdot y_1 y_2 - \\beta (y_3 + 27/s)', tau: '10' },
    ],
    [
      { name: '\\sigma', value: 10, description: 'Prandtl number' },
      { name: '\\rho', value: 28, description: 'Rayleigh number' },
      { name: '\\beta', value: 8/3, display_value: '\\frac{8}{3}', description: 'Geometric factor' },
      { name: 's', value: 200, description: 'Scale factor (keeps y₃ centered at 0)' },
    ],
    {
      validated: true,
      scaling: { scv: 200, time_divisor: 10, output_range: [-0.1, 0.1] },
      expected_behavior: { attractor_type: 'strange_attractor', visits_both_wings: true }
    }
  ),

  // Rössler Attractor (Scaled)
  createBuiltInPreset(
    'Rössler Attractor (Scaled)',
    'Scaled Rössler system. Output range [-0.1, 0.1] for stable tanh dynamics.',
    { extIn: 0, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 2, dt: 0.001, B_scale: 0.4 },
    [
      { latex: '-y_2 - y_3', tau: 's' },
      { latex: 'y_1 + a \\cdot y_2', tau: 's' },
      { latex: 'b/s + y_3 (s \\cdot y_1 - c)', tau: 's' },
    ],
    [
      { name: 'a', value: 0.2, description: 'System parameter' },
      { name: 'b', value: 0.2, description: 'System parameter' },
      { name: 'c', value: 5.7, description: 'Chaos parameter' },
      { name: 's', value: 100, description: 'Scale factor (divides all outputs)' },
    ],
    {
      validated: false,
      scaling: { scv: 100, time_divisor: 100, output_range: [-0.12, 0.12] },
      expected_behavior: { attractor_type: 'strange_attractor' }
    }
  ),

  // Chen Attractor (Scaled)
  createBuiltInPreset(
    'Chen Attractor (Scaled)',
    'Chen system (Lorenz dual) with coordinate scaling for tanh stability.',
    { extIn: 0, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 2, dt: 0.001, B_scale: 0.4 },
    [
      { latex: 'a(y_2 - y_1)', tau: 's' },
      { latex: '(c - a) y_1 - s \\cdot y_1 y_3 + c \\cdot y_2', tau: 's' },
      { latex: 's \\cdot y_1 y_2 - b \\cdot y_3', tau: 's' },
    ],
    [
      { name: 'a', value: 35, description: 'Parameter a' },
      { name: 'b', value: 3, description: 'Parameter b' },
      { name: 'c', value: 28, description: 'Parameter c' },
      { name: 's', value: 200, description: 'Scale factor' },
    ],
    {
      validated: false,
      scaling: { scv: 200, time_divisor: 200, output_range: [-0.15, 0.15] },
      expected_behavior: { attractor_type: 'strange_attractor' }
    }
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CHAOTIC ATTRACTORS (STANDARD - USE WITH CAUTION)
  // ═══════════════════════════════════════════════════════════════════════

  createBuiltInPreset(
    'Lorenz Attractor (Standard)',
    'Classic Lorenz equations. ⚠️ May saturate tanh - use Scaled version for reliable chaos.',
    { extIn: 0, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 2, B_scale: 0.4 },
    [
      { latex: '\\sigma (y_2 - y_1)', tau: '1' },
      { latex: 'y_1 (\\rho - y_3) - y_2', tau: '1' },
      { latex: 'y_1 y_2 - \\beta y_3', tau: '1' },
    ],
    [
      { name: '\\sigma', value: 10, description: 'Prandtl number' },
      { name: '\\rho', value: 28, description: 'Rayleigh number' },
      { name: '\\beta', value: 8/3, display_value: '\\frac{8}{3}', description: 'Geometric factor' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'strange_attractor', warning: 'May collapse without scaling' } }
  ),

  createBuiltInPreset(
    'Rössler Attractor (Standard)',
    'Classic Rössler equations. ⚠️ May saturate for large c values.',
    { extIn: 0, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 2, B_scale: 0.4 },
    [
      { latex: '-y_2 - y_3', tau: '1' },
      { latex: 'y_1 + a \\cdot y_2', tau: '1' },
      { latex: 'b + y_3 (y_1 - c)', tau: '1' },
    ],
    [
      { name: 'a', value: 0.2, description: 'System parameter' },
      { name: 'b', value: 0.2, description: 'System parameter' },
      { name: 'c', value: 5.7, description: 'Chaos parameter' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'strange_attractor', warning: 'May need scaling for c > 6' } }
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // OSCILLATORS (generally stable, smaller amplitude)
  // ═══════════════════════════════════════════════════════════════════════

  createBuiltInPreset(
    'Harmonic Oscillator',
    'Simple undamped spring-mass system. Linear dynamics, very stable.',
    { extIn: 0, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 50, gamma: 50, jetOrder: 1, decompOrder: 1, B_scale: 0.4 },
    [
      { latex: 'y_2', tau: '1' },
      { latex: '-\\omega^2 y_1', tau: '1' },
    ],
    [
      { name: '\\omega', value: 1, description: 'Natural frequency' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  createBuiltInPreset(
    'Van der Pol Oscillator',
    'Relaxation oscillator with limit cycle. Robust to parameter variations.',
    { extIn: 0, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: 'y_2', tau: '1' },
      { latex: '\\mu (1 - y_1^2) y_2 - y_1', tau: '1' },
    ],
    [
      { name: '\\mu', value: 1, description: 'Nonlinearity parameter (larger = more relaxation)' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  createBuiltInPreset(
    'Duffing Oscillator',
    'Nonlinear oscillator with cubic stiffness. Can exhibit chaos with forcing.',
    { extIn: 1, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: 'y_2', tau: '1' },
      { latex: '-\\delta y_2 - \\alpha y_1 - \\beta y_1^3 + x_1', tau: '1' },
    ],
    [
      { name: '\\alpha', value: -1, description: 'Linear stiffness (negative = double well)' },
      { name: '\\beta', value: 1, description: 'Cubic stiffness' },
      { name: '\\delta', value: 0.3, description: 'Damping coefficient' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  createBuiltInPreset(
    'Hopf Bifurcation',
    'Normal form with tunable limit cycle. Classic bifurcation example.',
    { extIn: 0, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: '\\mu y_1 - \\omega y_2 - y_1(y_1^2 + y_2^2)', tau: '1' },
      { latex: '\\omega y_1 + \\mu y_2 - y_2(y_1^2 + y_2^2)', tau: '1' },
    ],
    [
      { name: '\\mu', value: 0.5, description: 'Bifurcation parameter (μ>0 = limit cycle)' },
      { name: '\\omega', value: 1, description: 'Angular frequency' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // NEUROSCIENCE MODELS
  // ═══════════════════════════════════════════════════════════════════════

  createBuiltInPreset(
    'FitzHugh-Nagumo',
    'Simplified model of neuronal excitability. Captures spike generation.',
    { extIn: 1, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: 'y_1 - \\frac{y_1^3}{3} - y_2 + x_1', tau: '1' },
      { latex: '\\epsilon (y_1 + a - b y_2)', tau: '1' },
    ],
    [
      { name: '\\epsilon', value: 0.08, description: 'Time scale separation (small = slow recovery)' },
      { name: 'a', value: 0.7, description: 'Recovery parameter' },
      { name: 'b', value: 0.8, description: 'Recovery parameter' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  createBuiltInPreset(
    'Hindmarsh-Rose',
    'Three-variable neuron model with bursting behavior.',
    { extIn: 1, extOut: 0, recIn: 3, recOut: 3 },
    { neurons: 100, gamma: 100, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: 'y_2 - a y_1^3 + b y_1^2 - y_3 + x_1', tau: '1' },
      { latex: 'c - d y_1^2 - y_2', tau: '1' },
      { latex: 'r (s (y_1 - y_0) - y_3)', tau: '1' },
    ],
    [
      { name: 'a', value: 1, description: 'Cubic coefficient' },
      { name: 'b', value: 3, description: 'Quadratic coefficient' },
      { name: 'c', value: 1, description: 'Recovery constant' },
      { name: 'd', value: 5, description: 'Recovery coefficient' },
      { name: 'r', value: 0.006, description: 'Time scale (slow adaptation)' },
      { name: 's', value: 4, description: 'Adaptation strength' },
      { name: 'y_0', value: -1.6, description: 'Resting potential' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CHEMICAL & BIOLOGICAL MODELS
  // ═══════════════════════════════════════════════════════════════════════

  createBuiltInPreset(
    'Brusselator',
    'Autocatalytic chemical reaction. Exhibits limit cycles for B > 1 + A².',
    { extIn: 0, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 3, B_scale: 0.4 },
    [
      { latex: 'A - (B + 1) y_1 + y_1^2 y_2', tau: '1' },
      { latex: 'B y_1 - y_1^2 y_2', tau: '1' },
    ],
    [
      { name: 'A', value: 1, description: 'Reactant concentration' },
      { name: 'B', value: 3, description: 'Reactant concentration (B > 1+A² for oscillation)' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),

  createBuiltInPreset(
    'Lotka-Volterra',
    'Predator-prey population dynamics. Classic ecological model.',
    { extIn: 0, extOut: 0, recIn: 2, recOut: 2 },
    { neurons: 100, gamma: 50, jetOrder: 1, decompOrder: 2, B_scale: 0.4 },
    [
      { latex: '\\alpha y_1 - \\beta y_1 y_2', tau: '1' },
      { latex: '\\delta y_1 y_2 - \\gamma y_2', tau: '1' },
    ],
    [
      { name: '\\alpha', value: 1.1, description: 'Prey growth rate' },
      { name: '\\beta', value: 0.4, description: 'Predation rate' },
      { name: '\\delta', value: 0.1, description: 'Predator growth efficiency' },
      { name: '\\gamma', value: 0.4, description: 'Predator death rate' },
    ],
    { validated: false, expected_behavior: { attractor_type: 'limit_cycle' } }
  ),
];

// Legacy format for backward compatibility (will be removed)
export const BUILT_IN_PRESETS: Preset[] = [
  {
    id: 'lorenz',
    name: 'Lorenz Attractor',
    description: 'Classic chaotic system with butterfly attractor',
    numRecInputs: 3,
    numRecOutputs: 3,
    numExtInputs: 0,
    numExtOutputs: 0,
    recommendedN: 100,
    recommendedGamma: 100,
    recommendedJetOrder: 1,
    recommendedDecompOrder: 3,
    equations: [
      { latex: '\\sigma (y_2 - y_1)', tau: 1 },
      { latex: 'y_1 (\\rho - y_3) - y_2', tau: 1 },
      { latex: 'y_1 y_2 - \\beta y_3', tau: 1 },
    ],
    parameters: [
      { name: '\\sigma', value: 10, description: 'Prandtl number' },
      { name: '\\rho', value: 28, description: 'Rayleigh number' },
      { name: '\\beta', value: 8/3, description: 'Geometric factor' },
    ],
  },
  {
    id: 'vanderpol',
    name: 'Van der Pol Oscillator',
    description: 'Relaxation oscillator with limit cycle',
    numRecInputs: 2,
    numRecOutputs: 2,
    numExtInputs: 0,
    numExtOutputs: 0,
    recommendedN: 100,
    recommendedGamma: 50,
    recommendedJetOrder: 1,
    recommendedDecompOrder: 3,
    equations: [
      { latex: 'y_2', tau: 1 },
      { latex: '\\mu (1 - y_1^2) y_2 - y_1', tau: 1 },
    ],
    parameters: [
      { name: '\\mu', value: 1, description: 'Nonlinearity parameter' },
    ],
  },
  {
    id: 'fitzhugh-nagumo',
    name: 'FitzHugh-Nagumo',
    description: 'Simplified model of neuronal excitability',
    numRecInputs: 2,
    numRecOutputs: 2,
    numExtInputs: 1,
    numExtOutputs: 0,
    recommendedN: 100,
    recommendedGamma: 50,
    recommendedJetOrder: 1,
    recommendedDecompOrder: 3,
    equations: [
      { latex: 'y_1 - \\frac{y_1^3}{3} - y_2 + x_1', tau: 1 },
      { latex: '\\epsilon (y_1 + a - b y_2)', tau: 1 },
    ],
    parameters: [
      { name: '\\epsilon', value: 0.08, description: 'Time scale separation' },
      { name: 'a', value: 0.7, description: 'Recovery parameter' },
      { name: 'b', value: 0.8, description: 'Recovery parameter' },
    ],
  },
  {
    id: 'hopf',
    name: 'Hopf Bifurcation',
    description: 'Normal form with tunable limit cycle',
    numRecInputs: 2,
    numRecOutputs: 2,
    numExtInputs: 0,
    numExtOutputs: 0,
    recommendedN: 100,
    recommendedGamma: 50,
    recommendedJetOrder: 1,
    recommendedDecompOrder: 3,
    equations: [
      { latex: '\\mu y_1 - \\omega y_2 - y_1(y_1^2 + y_2^2)', tau: 1 },
      { latex: '\\omega y_1 + \\mu y_2 - y_2(y_1^2 + y_2^2)', tau: 1 },
    ],
    parameters: [
      { name: '\\mu', value: 0.5, description: 'Bifurcation parameter' },
      { name: '\\omega', value: 1, description: 'Angular frequency' },
    ],
  },
];

