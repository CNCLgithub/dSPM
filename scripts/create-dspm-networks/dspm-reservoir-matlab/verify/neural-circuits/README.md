# Neural Circuits Tests

**Paper Reference**: Figure 5 - Distributed implementation of logic and memory

## Overview

This folder validates the programming of neural circuits that implement:
- Boolean logic gates (AND, NAND, OR, NOR, XOR, XNOR)
- Arithmetic circuits (binary adder)
- Memory elements (SR-latch)
- Oscillators (ring oscillator)

## Tests

### test_logic_gates.m ✓
Programs six fundamental logic gates using bistable dynamics:
```matlab
% Base bistable dynamics
dxb = cx*x + ax*x³   % Creates wells at x = ±xf

% Gates add input-dependent terms
AND:  dxb - 0.1 + (x1+xf)*(x2+xf)/(2*xf)
NAND: dxb + 0.1 + (x1+xf)*(-x2-xf)/(2*xf)
OR:   dxb + 0.1 + (x1-xf)*(-x2+xf)/(2*xf)
NOR:  dxb - 0.1 + (x1-xf)*(x2-xf)/(2*xf)
XOR:  dxb + 0.0 + (-x1)*(x2)/xf
XNOR: dxb + 0.0 + (x1)*(x2)/xf
```

### test_adder.m [TODO]
Combines logic gates to form a binary full adder:
- Uses XOR gates for sum computation
- Uses AND and OR gates for carry propagation

### test_sr_latch.m [TODO]
Implements an SR (Set-Reset) latch using cross-coupled NOR gates:
- Set input: S=1, R=0 → Q=1
- Reset input: S=0, R=1 → Q=0
- Hold: S=0, R=0 → Q maintains previous state

### test_oscillator.m [TODO]
Creates a ring oscillator using three NAND gates in feedback:
- Autonomous oscillation emerges from circuit topology
- Period determined by gate delays and γ

## Key Concepts

### Bistable Dynamics
Logic gates use cubic dynamics to create two stable states:
```matlab
xw = 0.025;           % Well width
xf = 0.1;             % Fixed point location (±xf)
cx = 3/13;            % Linear coefficient
ax = -cx/(3*xw^2);    % Cubic coefficient

% Base dynamics: ẋ = cx·x + ax·x³
% Has stable fixed points near x = ±xf
```

### Truth Table Encoding
Input HIGH/LOW mapped to ±xf:
```
LOW  = -xf = -0.1
HIGH = +xf = +0.1
```

### Circuit Composition
Gates combined by connecting outputs to inputs:
```matlab
% Adder circuit matrix
AC = [B3*W_xor    O           O       ;   % XOR for partial sum
      B1*W_xor    B3*W_xor    O       ;   % XOR for full sum  
      B1*W_and    B2*W_and    B3*W_or ];  % AND+OR for carry
```

## Validation Criteria

1. **Logic gates**: Correct binary output for all input combinations
2. **Adder**: Correct sum and carry for all 8 input combinations
3. **SR latch**: Correct set, reset, and hold behavior
4. **Oscillator**: Sustained oscillation with consistent frequency
