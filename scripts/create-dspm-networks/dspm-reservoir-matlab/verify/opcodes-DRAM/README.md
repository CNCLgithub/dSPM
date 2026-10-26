# Op-codes and Dynamical RAM Tests

**Paper Reference**: Figure 3 - Programming multiple operations with op-codes

## Overview

This folder validates programming of multiple mathematical operations 
using different "op-codes" (operating points). By shifting the reservoir's 
fixed point, the same network can perform different computations.

## Tests

### test_matrix_opcodes.m ✓
Programs four matrix operations:
- **c1=0, c2=0**: Matrix Addition (A + B)
- **c1=1, c2=0**: Matrix Subtraction (A - B)  
- **c1=0, c2=1**: Element-wise Multiplication (2*A.*B)
- **c1=1, c2=1**: Matrix Multiplication (A*B)

Uses symbolic coefficient extraction and prime number encoding for monomial identification.

### test_code_composition.m [TODO]
Demonstrates code composition by chaining two NPUs to solve linear regression:
- NPU 1: Computes A*b + c
- NPU 2: Iteratively refines to compute A\z (matrix left-division)

### test_dynamical_ram.m ✓
Programs four different chaotic attractors as "memory addresses":
- Address 00: Lorenz attractor
- Address 01: Rössler attractor  
- Address 10: Halvorsen attractor
- Address 11: Thomas attractor

Control variables (c1, c2) select which attractor the network evolves.

## Key Concepts

### Op-code Mechanism
Different fixed points yield different Taylor expansions → different computations

```matlab
% Find equilibrium for each control configuration
rs_00 = findFixedPoint(res, [0; 0]);  % c1=0, c2=0
rs_01 = findFixedPoint(res, [0; 1]);  % c1=0, c2=1
% etc...
```

### Prime Number Encoding
Uniquely identifies monomials for coefficient extraction:
```matlab
pr = primes(100)';  % [2, 3, 5, 7, ...]
% Monomial x1^a * x2^b * x3^c has ID = 2^a * 3^b * 5^c
pri = prod(pr.^Pd, 2);
```

### Dynamical RAM
Store different attractors at different "addresses" by bias shifts:
```matlab
d_00 = d0;                    % Base bias
d_01 = d0 + B_shift*[0; 1];   % Shifted for address 01
d_10 = d0 + B_shift*[1; 0];   % Shifted for address 10
d_11 = d0 + B_shift*[1; 1];   % Shifted for address 11
```

## Validation Criteria

1. **Op-codes**: Relative error < 1% for each operation
2. **dRAM**: Each attractor bounded with correct topology
