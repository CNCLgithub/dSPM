# DSPM Reservoir Unit Tests

Validation suite that recapitulates the figures from Kim & Bassett (2023):
"A Neural Machine Code and Programming Framework for the Reservoir Computer"

Nature Machine Intelligence: https://doi.org/10.1038/s42256-023-00668-8

## Folder Structure

```
unit-tests/
├── README.md                    # This file
├── run_all_tests.m              # Master test runner
├── helpers/                     # Shared helper functions
│   ├── tanh_deriv.m             # Tanh derivatives
│   ├── sym2deriv.m              # Symbolic to derivative conversion
│   ├── deriv2shift.m            # Derivative shift operation
│   ├── gen_basis.m              # Generate polynomial basis
│   ├── decomp_poly1_ns.m        # 1st order decompilation
│   └── decomp_poly4_ns.m        # 4th order jet decompilation
├── k-jet-relaxation/            # Figure 4: Virtualization
│   ├── test_lorenz_scaled.m     # Lorenz attractor (3 methods)
│   ├── test_guest_rnn.m         # Guest RNN running Lorenz
│   └── test_host_virtualization.m  # Host virtualizing Guest
├── opcodes-DRAM/                # Figure 3: Op-codes and dRAM
│   ├── test_matrix_opcodes.m    # Matrix operations via control
│   ├── test_code_composition.m  # Linear regression via NPU chain
│   └── test_dynamical_ram.m     # Chaotic attractors as memory
├── neural-circuits/             # Figure 5: Logic and circuits
│   ├── test_logic_gates.m       # AND, NAND, OR, NOR, XOR, XNOR
│   ├── test_adder.m             # Full adder circuit
│   ├── test_sr_latch.m          # SR latch memory element
│   └── test_oscillator.m        # Ring oscillator
└── pong/                        # Figure 6: Pong game
    ├── test_collision.m         # Pitchfork bifurcation collision
    ├── test_velocity_latch.m    # SR latch for velocity
    └── test_pong_full.m         # Complete game integration
```

## Running Tests

### Setup Path
```matlab
% Add helpers to path
addpath('helpers');

% If using dspm_reservoir, ensure it's on the path
addpath('/path/to/your/dspm_reservoir');
```

### Individual Test
```matlab
run('k-jet-relaxation/test_lorenz_scaled.m')
```

### All Tests in a Folder
```matlab
run_folder_tests('neural-circuits')
```

### Full Suite
```matlab
results = run_all_tests()
```

## Test Methodology

Each test follows the **three-method validation pattern**:

1. **Symbolic** (`res.program(dx)`) 
   - Uses MATLAB Symbolic Math Toolbox
   - Most user-friendly, automatic coefficient extraction

2. **JSON** (`dspm_reservoir.load('preset.json')`)
   - Loads from saved configuration
   - Validates serialization/deserialization

3. **Hand-coded** (`res.compile(P)`)
   - Direct P matrix construction
   - Most transparent, matches paper equations

All three methods must produce **identical** P matrices.

## Comparison to Jason's Original Code

| Jason's Code | dspm_reservoir Equivalent |
|--------------|---------------------------|
| `decomp_poly4_ns(A,B,rs,dv,gam,o)` | `res.decompile()` |
| `gen_basis(Aa, PdS)` | Internal to decompilation |
| `lsqminnorm(R', O')'` | `res.compile(P)` |
| `ReservoirTanhB.train(x)` | `res.simulate(T)` |
| `ReservoirTanhB.predict(W,nc)` | `res.simulate(T)` after `close_loop()` |

## Key Simplifications

### A=0 Architecture
Many tests use `A=0` (unconnected reservoir), which dramatically simplifies:
- Decompilation becomes trivial: A* = -I
- No recurrent dynamics to worry about
- Same computational capacity for feedforward computations
- Faster simulation

### Prime Number Encoding
Jason's code uses prime numbers to uniquely identify monomials:
```matlab
pr = primes(100)';  % [2, 3, 5, 7, ...]
% Monomial x1^a * x2^b has ID = 2^a * 3^b
pri = prod(pr.^Pd1, 2);
```

The `dspm_reservoir.getColumnIndex()` method handles this transparently.

## Implementation Notes

### Continuous vs Discrete Time
- Current tests focus on **continuous time** dynamics
- Discrete time (STFT, etc.) requires `decomp_poly_ns_discrete`
- Tests marked `[DISCRETE]` await discrete time support

### Bistable Dynamics for Logic Gates
Logic gates use cubic dynamics:
```matlab
xw = 0.025;  % Well width
xf = 0.1;    % Fixed point location
cx = 3/13;   % Linear coefficient
ax = -cx/(3*xw^2);  % Cubic coefficient

% Creates two stable points at ±xf
dx = cx*x + ax*x^3 + (input_dependent_terms);
```

### Bifurcation for Collision Detection
Collision detection uses supercritical pitchfork:
```matlab
dcr = 1000 * ((x - x_wall) * cr - cr^3);
% When x < x_wall: cr → 0
% When x > x_wall: cr → ±√(x - x_wall)
```

## Validation Criteria

| Test Type | Success Criterion |
|-----------|-------------------|
| P matrix match | Frobenius norm < 1e-10 |
| Logic gates | Correct binary output for all input combos |
| Attractor stats | Bounded trajectory with correct topology |
| Compilation | Residual < 1e-6 |

## Contributing

When adding new tests:
1. Use the three-method validation pattern
2. Include clear `fprintf` output showing pass/fail
3. Add to appropriate figure folder
4. Update this README
