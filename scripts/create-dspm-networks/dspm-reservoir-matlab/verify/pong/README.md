# Pong Game Tests

**Paper Reference**: Figure 6 - Programming pong using neural circuits and bifurcations

## Overview

This folder validates the programming of a playable Pong game inside a 
reservoir computer, demonstrating the combination of:
- Continuous dynamics for ball physics
- Bistable dynamics for collision detection  
- SR latches for velocity state
- Circuit composition for the complete game

## Tests

### test_collision.m ✓
Validates collision detection using supercritical pitchfork bifurcation:
```matlab
ċ = 1000 * ((x - x_wall) * c - c³)
```
- When x < x_wall: c → 0 (no collision)
- When x > x_wall: c → ±√(x - x_wall) (collision detected)

The test verifies the bifurcation behavior at various x positions.

### test_velocity_latch.m [TODO]
Validates SR latch for velocity direction control:
- Left wall collision sets velocity right
- Right wall collision sets velocity left
- No collision maintains current velocity

### test_pong_full.m [TODO]
Full Pong game integration test:
1. Ball position (x, y) with velocity (ẋ, ẏ)
2. Wall collision detection (cl, cr, cu)
3. Paddle collision detection (cp)
4. Velocity latches for direction changes
5. Paddle position (xp) controlled externally

## Key Concepts

### Pong State Variables
From code_pong.m:
```
x, y    - Ball position
ẋ, ẏ    - Ball velocity (implicit in dynamics)
xp      - Paddle position (external control)
cl      - Left wall contact
cr      - Right wall contact  
cu      - Upper wall contact
cp      - Paddle contact
```

### Collision Detection via Bifurcation
```matlab
% Right wall collision (at x = xw)
dcr = 1000 * ((x - xw)*cr - cr^3);

% Pitchfork bifurcation:
% When x < xw: stable at cr = 0
% When x > xw: bifurcates to cr ≠ 0
```

### Velocity SR Latch
```matlab
% x-velocity latch using cross-coupled NORs
dv_x  = NOR(cr, v_x');  % Set by right wall
dv_x' = NOR(cl, v_x);   % Reset by left wall
```

### Complete Dynamics
From code_pong.m:
```matlab
dx = [
    vx * 0.1;                                    % ẋ = vx
    latch_dynamics_1;                            % v_x state
    latch_dynamics_2;                            % v_x' state
    vy * 0.1;                                    % ẏ = vy
    latch_dynamics_3;                            % v_y state
    latch_dynamics_4;                            % v_y' state
    1000 * ((x - xr)*cr - cr^3);                 % cr (right wall)
    1000 * ((-xl - x)*cl - cl^3);                % cl (left wall)
    1000 * ((y - yu)*cu - cu^3);                 % cu (upper wall)
    2000 * ((r² - d²)*cp - cp^3);                % cp (paddle)
    0                                             % xp (external)
];
```

## Validation Criteria

1. **Collision detection**: Correct bifurcation timing relative to wall
2. **Velocity latch**: Correct direction changes on collision
3. **Full game**: Ball bounces correctly, paddle interaction works
4. **Playability**: Responds to paddle input and maintains physics
