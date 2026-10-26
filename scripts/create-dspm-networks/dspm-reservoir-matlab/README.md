# Reservoir_v2: Unified Symbolic Decompilation Framework

A MATLAB implementation of the Kim & Bassett (2023) neural programming framework with **unified symbolic decompilation** supporting arbitrary jet order and polynomial expansion.

## Key Innovation: Symbolic Jet Decompilation

Instead of Jason's approach with separate `decomp_poly1_ns` and `decomp_poly4_ns` functions returning 7+ coefficient tensors (C1, C2, C3a, C3b, C4a, C4b, C4c), we use a single symbolic Taylor expansion:

```matlab
h = tanh(B*x + d);
tay = taylor(h, tau, t, 'Order', jet_order);  % Expand in time
tayy = taylor(tay, y, 0, 'Order', poly_order); % Expand in extended state
```

This produces a unified R matrix where:
- Columns for y₁...yₖ correspond to position (x)
- Columns for yₖ₊₁...y₂ₖ correspond to velocity (ẋ)  
- Columns for y₂ₖ₊₁...y₃ₖ correspond to acceleration (ẍ)
- And so on for higher jet orders

## Advantages Over Original Implementation

| Aspect | Jason's Approach | Our Approach |
|--------|------------------|--------------|
| Jet order | Hardcoded (1 or 4) | Arbitrary (parameter) |
| Polynomial order | Fixed per function | Arbitrary (parameter) |
| Output structure | 7+ separate tensors | Single R matrix |
| Chain rule | Manual `deriv2shift` | Automatic via symbolic |
| Readability | Opaque tensor ops | Clear polynomial basis |
| Speed | ~0.1s | ~0.8s |

The 8× slowdown is negligible for research iteration where understanding and flexibility matter more than raw speed.

## Verified Equivalence

For the A=0 case (which is optimal per Kim & Bassett), our x-only columns match Jason's R matrix to machine precision:

```
||R_jason - R_ours||_F = 3.5262e-16
Relative difference: 1.1936e-16
```

## Quick Start

```matlab
% Add paths
addpath('core', 'compile', 'program', 'utils');

% 1. CREATE RESERVOIR
res = Reservoir_v2(500, 3, 0, 100, 0.001);  % N=500, k_rec=3, k_ext=0, γ=100
res.init_random(0.6);
res.set_operating_point(zeros(3,1));

% 2. DECOMPILE with jet structure
[R, basis] = res.decompile(3, 2);  % poly_order=3, jet_order=2 (x and ẋ)

% 3. VIEW physical interpretation
disp(basis.degreeTable(1:15, :));
%    Physical    y1^n    y2^n    y3^n    y4^n    y5^n    y6^n
%    ________    ____    ____    ____    ____    ____    ____
%    "1"          0       0       0       0       0       0
%    "x1"         1       0       0       0       0       0
%    "x2"         0       1       0       0       0       0
%    "x3"         0       0       1       0       0       0
%    "ẋ1"         0       0       0       1       0       0
%    "ẋ2"         0       0       0       0       1       0
%    "x1·x2"      1       1       0       0       0       0
%    ...

% 4. PROGRAM dynamics (e.g., Lorenz)
% P = dynamics_to_program(f_sym, x_sym, basis, gamma);

% 5. COMPILE
[residual, rank_R, stats] = res.compile(P, R);

% 6. CONDITION to initial state
r_cond = res.condition(x0);

% 7. CLOSE LOOP and simulate
res.close_loop();
[~, y_traj] = res.simulate(zeros(0, T), r_cond);
```

## Physical Interpretation of Basis

The `degreeTable` provides human-readable mapping:

| y-variable | Physical Meaning |
|------------|------------------|
| y₁, y₂, y₃ | x₁, x₂, x₃ (position) |
| y₄, y₅, y₆ | ẋ₁, ẋ₂, ẋ₃ (velocity) |
| y₇, y₈, y₉ | ẍ₁, ẍ₂, ẍ₃ (acceleration) |
| y₁·y₄ | x₁·ẋ₁ (position-velocity coupling) |

This makes programming dynamics intuitive - you know exactly which column encodes which physical term.

## Directory Structure

```
reservoir_dc_v2/
├── core/
│   ├── Reservoir_v2.m        # Main class with symbolic decompilation
│   ├── build_degree_matrix.m # Polynomial basis generation
│   └── tanh_derivs.m         # Analytic tanh derivatives
│
├── compile/
│   └── compile_program.m     # W = P * pinv(R) with diagnostics
│
├── program/
│   ├── dynamics_to_program.m # Symbolic dynamics → P matrix
│   └── quaternion_kinematics_program.m
│
├── utils/
│   ├── quat_exp.m            # Exponential map: su(2) → SU(2)
│   ├── quat_mult.m           # Quaternion multiplication
│   └── get_24cell_vertices.m # The 24 vertices of the 24-cell
│
├── verify/
│   ├── verify_logic_gates.m  # Reproduces code_neural_circuits.m
│   └── verify_dram_attractors.m # Reproduces code_op_comp_dRAM.m
│
├── demo_user_interface.m     # Shows the clean API
└── test_reservoir_v2.m       # Integration tests
```

## Verification Against Jason's Code

The `verify/` folder contains scripts that reproduce Jason's original examples:

### Logic Gates (`verify_logic_gates.m`)
Implements AND, NAND, OR, NOR, XOR, XNOR gates using our framework and compares:
- R matrices (decompilation)
- W matrices (compilation)  
- Simulation outputs (all 4 input combinations)

```matlab
% Our clean API for XOR:
res.decompile(4, 1);
P = zeros(1, res.n_mono);
P(res.getColumnIndex('x3')) = 1 + cx/gam;
P(res.getColumnIndex('x3^3')) = ax/gam;
P(res.getColumnIndex('x1·x2')) = -1/(xf*gam);
res.compile(P);
```

### dRAM with Multiple Attractors (`verify_dram_attractors.m`)
Programs 4 chaotic attractors (Lorenz, Rössler, Halvorsen, Sprott) into one reservoir, selected by control inputs:
- Finds operating points for each control setting
- Decompiles at each operating point
- Compiles combined program
- Simulates all 4 attractors

## Why This Matters

For extending to SU(2) quaternion dynamics and probabilistic inference:

1. **Arbitrary jet order** - Natural gradients and Fisher information require velocity/acceleration structure
2. **Clear physical basis** - Know exactly where x₁·ẋ₂ terms live
3. **No rewiring** - Change parameters, not code structure
4. **Verified foundation** - Matches Jason's implementation where they overlap

## References

- Kim & Bassett (2023). "A neural machine code and programming framework for the reservoir computer." Nature Machine Intelligence.
- Kim & Bassett (2023). Supplementary Information, Sections I-III.
