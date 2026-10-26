/**
 * Stability Wizard - Default Values and Constants
 */

import type { ViewBounds, WikiPage, WikiCategory } from '@/types';

// ============================================
// COLORS
// ============================================

/** Colors for nullcline visualization */
export const NULLCLINE_COLORS = [
  '#e94560', // Rose
  '#4ade80', // Green
  '#60a5fa', // Blue
  '#fbbf24', // Amber
  '#a78bfa', // Purple
  '#f472b6', // Pink
  '#2dd4bf', // Teal
  '#fb923c', // Orange
];

/** Colors for fixed point markers */
export const FP_COLORS = {
  stable: '#4ade80',
  unstable: '#f87171',
  saddle: '#fbbf24',
  center: '#60a5fa',
  unknown: '#94a3b8',
};

/** Color scale for flow field magnitude */
export const FLOW_FIELD_COLORS = [
  '#3b82f6', // Low magnitude (blue)
  '#22c55e', // Medium (green)
  '#eab308', // Medium-high (yellow)
  '#f97316', // High (orange)
  '#ef4444', // Very high (red)
];

// ============================================
// VISUALIZATION DEFAULTS
// ============================================

export const DEFAULT_VIEW_BOUNDS: ViewBounds = {
  xMin: -1,
  xMax: 1,
  yMin: -1,
  yMax: 1,
  zMin: -1,
  zMax: 1,
};

export const DEFAULT_ARROW_DENSITY = 20;
export const MIN_ARROW_DENSITY = 5;
export const MAX_ARROW_DENSITY = 50;

// ============================================
// SLIDER DEFAULTS
// ============================================

export const DEFAULT_SLIDER_BOUNDS = {
  min: -10,
  max: 10,
  step: 0.01,
};

export const DEFAULT_STATE_VARIABLE_BOUNDS = {
  min: -1,
  max: 1,
  step: 0.01,
};

// ============================================
// TABS
// ============================================

export const TABS = [
  { id: 'nullcline', label: 'Nullclines', icon: 'GitBranch' },
  { id: 'flowfield', label: 'Flow Field', icon: 'Compass' },
  { id: 'suggestions', label: 'Suggestions', icon: 'Lightbulb' },
  { id: 'wiki', label: 'Wiki', icon: 'BookOpen' },
] as const;

// ============================================
// WIKI CONTENT
// ============================================

export const WIKI_CATEGORIES: { id: WikiCategory; label: string }[] = [
  { id: 'getting-started', label: 'Getting Started' },
  { id: 'theory', label: 'Theory' },
  { id: 'examples', label: 'Examples' },
  { id: 'reference', label: 'Reference' },
];

export const WIKI_PAGES: WikiPage[] = [
  {
    id: 'introduction',
    title: 'Introduction to dSPM',
    category: 'getting-started',
    content: `
# Introduction to dSPM

The **dynamical Structure-Preserving Manifolds (dSPM)** framework extends reservoir computing into quaternionic geometry on the 3-sphere (S³).

## Key Concepts

### The A=0 Reservoir

Unlike traditional reservoir computing, dSPM uses an **A=0 architecture** where the internal dynamics are purely contractive. This provides:

- **Trivial decompilation**: Setting A* = -I eliminates complex matrix exponentials
- **Guaranteed stability**: The -r term ensures all trajectories converge
- **Clean polynomial basis**: The Taylor expansion has a well-defined structure

### The Operating Point

The operating point r* becomes the symbolic origin of computation. Just as we might set the Sun at (0,0,0) to study planetary orbits, r* establishes the reference frame for all dynamics.

## Next Steps

- Learn about [Scaling & Centering](/wiki/scaling) to prepare your dynamics
- Understand [Fixed Points & Stability](/wiki/fixed-points) analysis
- Explore [Example Systems](/wiki/lorenz) like the Lorenz attractor
    `.trim(),
  },
  {
    id: 'scaling',
    title: 'Scaling & Centering',
    category: 'getting-started',
    content: `
# Scaling & Centering Dynamics

Physical systems expressed in SI units must be translated to the reservoir's number-theoretic scale.

## The Problem

The reservoir operates in a **number-theoretic coordinate system** where:
- The linear regime of tanh is approximately [-0.5, 0.5]
- The number **1** has special algebraic significance
- Values outside this range cause saturation and information loss

## The Solution

1. **Translate**: Shift coordinates so the attractor is centered at origin
2. **Scale**: Divide by a factor to fit within [-0.3, 0.3]
3. **Slow time**: Divide dynamics by τ to match reservoir timescale

## Example: Lorenz System

The standard Lorenz attractor must be scaled:
- z oscillates around 27, so translate: z_new = (z - 27) / scale
- With scale = 200, values fit in [-0.1, 0.1]
- Time scaling τ = 10 ensures smooth integration
    `.trim(),
  },
  {
    id: 'fixed-points',
    title: 'Fixed Points & Stability',
    category: 'theory',
    content: `
# Fixed Points & Stability Analysis

Understanding fixed points is crucial for designing stable reservoir programs.

## Finding Fixed Points

A **fixed point** x* satisfies: ẋ = f(x*) = 0

## Stability via Linearization

Near a fixed point, dynamics are approximated by the **Jacobian matrix**:

J_ij = ∂f_i/∂x_j

The eigenvalues λ of J determine local behavior:

| Eigenvalues | Type | Behavior |
|-------------|------|----------|
| All Re(λ) < 0 | Stable | Trajectories converge |
| All Re(λ) > 0 | Unstable | Trajectories diverge |
| Mixed signs | Saddle | Some converge, some diverge |
| Re(λ) = 0 | Center | Closed orbits (marginal) |

## Using the Wizard

The Stability Wizard automatically:
1. Finds fixed points symbolically or numerically
2. Computes the Jacobian at each point
3. Classifies stability via eigenvalue analysis
4. Warns if fixed points are outside the linear regime
    `.trim(),
  },
  {
    id: 'bifurcations',
    title: 'Bifurcations',
    category: 'theory',
    content: `
# Bifurcation Theory

Bifurcations occur when the qualitative behavior of a system changes as a parameter varies.

## Pitchfork Bifurcation

A single fixed point splits into three:

ẋ = μx - x³

- μ < 0: One stable FP at x=0
- μ = 0: Bifurcation point
- μ > 0: x=0 unstable, two stable FPs at ±√μ

### Application: Binary Logic

The pitchfork bifurcation is the foundation for implementing logic gates:
- The two stable branches represent logical 0 and 1
- Input signals modulate which branch is "selected"
- The cubic term ensures bounded dynamics

## Hopf Bifurcation

A fixed point loses stability and a limit cycle emerges.
This is the foundation for oscillator circuits in reservoirs.
    `.trim(),
  },
  {
    id: 'logic-gates',
    title: 'Logic Gates',
    category: 'examples',
    content: `
# Binary Logic via Dynamics

Logic gates can be implemented as dynamical systems using pitchfork bifurcations.

## The Dynamical Core

All logic gates share a common "core":

ẏ = c_x·y + a_x·y³ + h(x₁, x₂)

where:
- c_x = 3/13 sets the linear curvature
- a_x ensures fixed points at ±x_f
- h(x₁, x₂) implements the specific logic

## Logic Mapping

Binary values map to fixed points:
[-x_f, +x_f] ↔ [LOW, HIGH] ↔ [0, 1]

With x_f = 0.1, the logic operates well within the linear regime.

## Gate Examples

**AND**: Output is HIGH only when both inputs are HIGH
**XOR**: Output is HIGH when inputs have opposite signs
**NAND**: Inverted AND - foundation of digital logic

See the presets in the Programming GUI for ready-to-use implementations.
    `.trim(),
  },
  {
    id: 'lorenz',
    title: 'Lorenz Attractor',
    category: 'examples',
    content: `
# Programming the Lorenz Attractor

The Lorenz system is a classic example of deterministic chaos.

## Original Equations

ẋ = σ(y - x)
ẏ = x(ρ - z) - y
ż = xy - βz

Standard parameters: σ=10, ρ=28, β=8/3

## Scaled Version for Reservoir

The attractor must be scaled to fit the reservoir:

1. Translate z by -27 (center of attractor)
2. Scale by 1/200 to fit in [-0.1, 0.1]
3. Divide by τ=10 to slow dynamics

## Results

When properly scaled, the reservoir faithfully reproduces:
- The butterfly-shaped strange attractor
- Sensitive dependence on initial conditions
- The correct Lyapunov exponents

Load the "Lorenz (Scaled)" preset to try it yourself!
    `.trim(),
  },
  {
    id: 'api-reference',
    title: 'MATLAB API',
    category: 'reference',
    content: `
# MATLAB API Reference

## Creating a Reservoir

\`\`\`matlab
% Traditional constructor
res = dspm_reservoir(100, 'n_recurrent_inputs', 3);

% Load from JSON preset
res = dspm_reservoir('load', 'presets/lorenz_scaled.json');
\`\`\`

## Key Properties

| Property | Description |
|----------|-------------|
| n_neurons | Number of reservoir units |
| n_recurrent_inputs | Dimension of feedback channel |
| gamma | Time constant (τ = 1/γ) |
| B_scale | Scale for read-in matrices |
| P | Compiled program matrix |
| R | Decompiled weight matrix |

## Stability Wizard

\`\`\`matlab
wiz = StabilityWizard(res);
wiz.analyze(equations, constants);
wiz.report();
\`\`\`

## Running Simulations

\`\`\`matlab
res.condition([0.05; 0.05; -0.04]);
res.close_loop();
[r_traj, y_traj] = res.simulate(10000);
\`\`\`
    `.trim(),
  },
];

// ============================================
// KEYBOARD SHORTCUTS
// ============================================

export const KEYBOARD_SHORTCUTS = [
  { key: '1', description: 'Nullclines tab' },
  { key: '2', description: 'Flow Field tab' },
  { key: '3', description: 'Suggestions tab' },
  { key: '4', description: 'Wiki tab' },
  { key: '+', description: 'Zoom in' },
  { key: '-', description: 'Zoom out' },
  { key: 'r', description: 'Reset view' },
  { key: 'g', description: 'Toggle grid' },
  { key: 'n', description: 'Toggle nullclines' },
  { key: 'f', description: 'Toggle fixed points' },
  { key: 't', description: 'Toggle trajectories' },
  { key: '?', description: 'Show shortcuts' },
];
