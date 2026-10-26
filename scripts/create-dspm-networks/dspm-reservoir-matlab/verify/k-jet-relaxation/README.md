# K-Jet Relaxation and Virtualization Tests

**Paper Reference**: Figure 4 - Software virtualization

## Overview

This folder validates the k-jet expansion and software virtualization:
- Guest RNN programmed with Lorenz dynamics
- Host RNN that virtualizes the Guest RNN
- Nested computation: Host → Guest → Lorenz

## Tests

### test_lorenz_scaled.m ✓
The canonical validation test demonstrating three programming methods:
1. **Symbolic**: `res.program(dx)` - uses MATLAB Symbolic Math Toolbox
2. **JSON**: `dspm_reservoir.load('lorenz_scaled.json')` - loads preset
3. **Hand-coded**: Direct P matrix construction matching paper equations

All three methods must produce identical P matrices.

### test_guest_rnn.m [TODO]
Programs a small "Guest" RNN to implement Lorenz dynamics:
1. Create Guest RNN (NG = 15 neurons)
2. Decompile Guest into dNPL representation  
3. Program scaled Lorenz dynamics
4. Compile and close loop
5. Validate Lorenz trajectory statistics

### test_host_virtualization.m [TODO]
Programs a large "Host" RNN to virtualize the Guest RNN:
1. Create Host RNN (N = 2000 neurons)
2. Condition Host on Guest's fixed point
3. Program tanh(Guest dynamics) as polynomial approximation
4. Validate nested computation

## Key Concepts

### K-Jet Expansion
Taylor series in time captures dynamics to order k:
```
r(t+dt) ≈ r(t) + dt·ṙ + (dt²/2!)·r̈ + (dt³/3!)·r⃛ + ...
```

The `decomp_poly4_ns` function computes coefficients for each time derivative order.

### Scaled Lorenz
To keep dynamics in bounded range suitable for tanh:
```matlab
scv = 200;  % Scaling factor
dy = [
    σ*(y2 - y1);
    y1*(ρ - 27 - scv*y3) - y2;
    scv*y1*y2 - β*(y3 + 27/scv)
] / 10;
```

## Validation Criteria

1. **P matrix match**: Frobenius norm difference < 1e-10
2. **Bounded trajectory**: max|y| < 1 for scaled Lorenz
3. **Attractor topology**: Correct strange attractor shape
