% TEST_LORENZ_GUEST_EXACT  Exact replica of Jason's guest Lorenz code
%
% This extracts ONLY the guest portion of code_virtualize.m with
% detailed comments explaining each step.

clear; close all; clc;

%% Add path to Jason's code
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'reference', 'code_jasonKim_final'));

rng(0);  % MUST match Jason's seed!

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  GUEST LORENZ - Exact Replica of Jason''s Code\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%  STEP 1: CREATE GUEST RNN (lines 8-16)
%  ========================================================================
%  KEY: A is NOT zero! It's a small random matrix (spectral radius 0.01)

dt = 0.001;                 % Time step (smaller than our test!)
gamG = 100;                 % Time constant
NG = 15;                    % Number of neurons (small!)

% A is RANDOM, scaled to spectral radius 0.01
AG = (rand(NG) - 0.5);
AG = AG / abs(eigs(AG, 1, 'largestabs', 'MaxIterations', 1e6)) * 0.01;

BG = (rand(NG, 3) - 0.5) * 0.4;    % Input matrix (scale 0.4)
rsG = (rand(NG, 1) - 0.5);          % Operating point

RG = ReservoirTanhB(AG, BG, rsG, [0;0;0], dt, gamG);
dG = RG.d;

fprintf('Guest RNN:\n');
fprintf('  N = %d neurons\n', NG);
fprintf('  dt = %.4f (note: smaller than 0.01!)\n', dt);
fprintf('  γ = %.1f\n', gamG);
fprintf('  ||A|| = %.6f, spectral radius = %.6f\n', norm(AG,'fro'), max(abs(eig(AG))));
fprintf('  ||B|| = %.6f\n', norm(BG,'fro'));
fprintf('  ||d|| = %.6f\n', norm(dG));
fprintf('\n');

%% ========================================================================
%  STEP 2: DECOMPILE with 4th-order expansion (line 19)
%  ========================================================================
%  KEY: Uses decomp_poly4_ns, NOT decomp_poly1_ns!
%  This gives 8 coefficient matrices for different Taylor terms.

fprintf('Decompiling (4th order)...\n');

% Note: dv = A*rs + d (since xs = 0)
% BUT Jason writes it as: AG*rsG + dG
% Since d = atanh(rs) - A*rs - B*xs, and xs=0:
%   dv = A*rs + d = A*rs + atanh(rs) - A*rs = atanh(rs)
% So dv = atanh(rsG) when xs=0!

[PdG, GDNPG1, GDNPG2, GDNPG3a, GDNPG3b, GDNPG4a, GDNPG4b, GDNPG4c] = ...
    decomp_poly4_ns(AG, BG, rsG, AG*rsG + dG, gamG, 3);

fprintf('  Basis PdG: %d monomials × %d variables\n', size(PdG,1), size(PdG,2));
fprintf('  GDNPG1 (C1): %d × %d\n', size(GDNPG1,1), size(GDNPG1,2));
fprintf('  GDNPG2 (C2): %d × %d × %d\n', size(GDNPG2));
fprintf('\n');

% Show basis structure
fprintf('  Basis (PdG exponents):\n');
fprintf('       y1  y2  y3\n');
for i = 1:size(PdG, 1)
    fprintf('  %2d: [%d   %d   %d]\n', i, PdG(i,1), PdG(i,2), PdG(i,3));
end
fprintf('\n');

%% ========================================================================
%  STEP 3: COMPUTE SHIFT MATRIX (lines 21-26)
%  ========================================================================
%  Maps products of basis terms to their resulting basis term index.

fprintf('Computing shift matrix...\n');

[PdMsx, PdMsy] = find((sum(PdG,2) + sum(PdG,2)') <= max(sum(PdG,2)));
PdSG = zeros(size(PdG, 1));
for i = 1:length(PdMsx)
    Pdv = PdG(PdMsx(i), :) + PdG(PdMsy(i), :);
    PdSG(PdMsx(i), PdMsy(i)) = find(sum(PdG == Pdv, 2) == 3);
end

fprintf('  PdSG: %d × %d\n', size(PdSG));
fprintf('\n');

%% ========================================================================
%  STEP 4: DEFINE LORENZ DYNAMICS (lines 29-34)
%  ========================================================================
%  KEY: This is SCALED Lorenz, not standard!
%  scv = 200 scales y3, and everything is divided by 10.

fprintf('Defining scaled Lorenz dynamics...\n');

syms t; assume(t, 'real');
syms y(t) [3,1]; syms ys [3,1]; y = y(t);
assume(y, 'real'); assume(ys, 'real');

scv = 200;  % SCALING FACTOR!

% Scaled Lorenz:
%   Standard: dy1 = σ(y2-y1), dy2 = ρy1 - y2 - y1*y3, dy3 = y1*y2 - βy3
%   Scaled:   shifts y3, scales by scv, divides by 10
dy = [-10*y(1) + 10*y(2); ...
      y(1)*(28 - (scv*y(3) + 27)) - y(2); ...
      scv*y(1)*y(2) - 8/3*(y(3) + 27/scv)] / 10;

fprintf('  scv = %d\n', scv);
fprintf('  dy1 = (-10*y1 + 10*y2) / 10\n');
fprintf('  dy2 = (y1*(28 - (scv*y3 + 27)) - y2) / 10\n');
fprintf('  dy3 = (scv*y1*y2 - (8/3)*(y3 + 27/scv)) / 10\n');
fprintf('\n');

%% ========================================================================
%  STEP 5: CONVERT SYMBOLIC TO COEFFICIENTS (lines 37-38)
%  ========================================================================

fprintf('Converting symbolic to polynomial coefficients...\n');

prs = primes(6)';  % First 3 primes: [2, 3, 5]

[GAMs, DXCs, DDXCs, DDDXCs, DXDXCs, DXDXDXCs, DDXDXCs] = ...
    sym2deriv(dy, y, prs, PdG, PdSG);

fprintf('  DXCs (1st deriv): %d × %d\n', size(DXCs));
fprintf('\n');

%% ========================================================================
%  STEP 6: COMPUTE DERIVATIVE SHIFT CORRECTIONS (lines 39-44)
%  ========================================================================
%  These corrections account for higher-order Taylor terms.

fprintf('Computing derivative shift corrections...\n');

C2Ss  = sum(deriv2shift(GDNPG2,  DXCs,      PdG, PdSG), 3);
C3aSs = sum(deriv2shift(GDNPG3a, DXDXCs,    PdG, PdSG), 3);
C3bSs = sum(deriv2shift(GDNPG3b, DDXCs,     PdG, PdSG), 3);
C4aSs = sum(deriv2shift(GDNPG4a, DXDXDXCs,  PdG, PdSG), 3);
C4bSs = sum(deriv2shift(GDNPG4b, DDXDXCs,   PdG, PdSG), 3);
C4cSs = sum(deriv2shift(GDNPG4c, DDDXCs,    PdG, PdSG), 3);

fprintf('  C2Ss:  %d × %d, ||C2Ss|| = %.6f\n', size(C2Ss,1), size(C2Ss,2), norm(C2Ss,'fro'));
fprintf('  C3aSs: ||C3aSs|| = %.6f\n', norm(C3aSs,'fro'));
fprintf('  C3bSs: ||C3bSs|| = %.6f\n', norm(C3bSs,'fro'));
fprintf('  C4aSs: ||C4aSs|| = %.6f\n', norm(C4aSs,'fro'));
fprintf('  C4bSs: ||C4bSs|| = %.6f\n', norm(C4bSs,'fro'));
fprintf('  C4cSs: ||C4cSs|| = %.6f\n', norm(C4cSs,'fro'));
fprintf('\n');

%% ========================================================================
%  STEP 7: BUILD R MATRIX (lines 47-49)
%  ========================================================================
%  KEY: R = gen_basis(A*(C1 + corrections) + B + d)
%  The A matrix multiplies the coefficient sum!

fprintf('Building R matrix...\n');

% Sum all coefficients with corrections
AAa = AG * (GDNPG1 + C2Ss + C3aSs + C3bSs + C4aSs + C4bSs + C4cSs);

% Add B to linear columns (columns 2,3,4)
AAa(:, (1:3)+1) = AAa(:, (1:3)+1) + BG;

% Add d to constant column (column 1)
AAa(:, 1) = AAa(:, 1) + dG;

% Apply gen_basis (Taylor expansion of tanh)
GDNPG1 = gen_basis(AAa, PdSG);

fprintf('  R matrix (GDNPG1): %d × %d\n', size(GDNPG1));
fprintf('  ||R|| = %.6f\n', norm(GDNPG1, 'fro'));
fprintf('\n');

%% ========================================================================
%  STEP 8: BUILD PROGRAM MATRIX P (lines 52-54)
%  ========================================================================
%  P = I (on state columns) + DX/gamma

fprintf('Building program matrix P...\n');

OdNPLG = zeros(3, size(GDNPG1, 2));
OdNPLG(:, (1:3)+1) = eye(3);       % Identity on columns 2,3,4
OdNPLG = OdNPLG + DXCs / gamG;     % Add dynamics/gamma

fprintf('  P matrix (OdNPLG): %d × %d\n', size(OdNPLG));
fprintf('  Non-zero entries per row:\n');
for i = 1:3
    nz = find(abs(OdNPLG(i,:)) > 1e-10);
    fprintf('    Row %d: ', i);
    for j = nz
        fprintf('P(%d,%d)=%.4f  ', i, j, OdNPLG(i,j));
    end
    fprintf('\n');
end
fprintf('\n');

%% ========================================================================
%  STEP 9: COMPILE W = P * pinv(R) (lines 57-59)
%  ========================================================================

fprintf('Compiling...\n');

WG = lsqminnorm(GDNPG1', OdNPLG')';
ABW = AG + BG * WG;  % Closed-loop adjacency

residual = norm(WG * GDNPG1 - OdNPLG, 'fro');
fprintf('  Compiler residual: %.6e\n', residual);
fprintf('  ||W|| = %.6f\n', norm(WG, 'fro'));
fprintf('  Spectral radius of A+B*W: %.6f\n', max(abs(eig(ABW))));
fprintf('\n');

%% ========================================================================
%  STEP 10: TEST (lines 62-66)
%  ========================================================================
%  Uses LorenzZs for ground truth, trains open-loop, then predicts.

fprintf('Testing...\n');

% Generate ground truth using Jason's LorenzZs class
% Parameters: [y0]/scv, dt, [sigma, rho, beta, scv]
L = LorenzZs([10; 4; 8]/scv, dt, [10, 28, 8/3, scv]);
LX = L.propagate(100/dt);  % 100 seconds

fprintf('  Ground truth: %d time steps\n', size(LX, 2));

% Train (open-loop) - drive reservoir with Lorenz trajectory
RG = ReservoirTanhB(AG, BG, rsG, [0;0;0], dt, gamG);
RG.r = rsG;  % Start at operating point
RTG = RG.train(LX);
RTG = RTG(:, 1001:end);  % Remove first 1000 steps (transient)
WRTG = WG * RTG;         % Readout during training

fprintf('  Open-loop readout: %d steps\n', size(WRTG, 2));

% Predict (closed-loop) - autonomous dynamics
RPG = RG.predict4(WG, 200/dt);  % 200 seconds of prediction
WWRPG = WG * RPG(:, :, 1);       % Readout

fprintf('  Closed-loop prediction: %d steps\n', size(WWRPG, 2));
fprintf('\n');

%% ========================================================================
%  VISUALIZE
%  ========================================================================

figure('Name', 'Guest Lorenz - Jason''s Exact Code', 'Position', [100 100 1400 500]);

% Ground truth
subplot(1,3,1);
plot3(LX(1, 1001:end), LX(2, 1001:end), LX(3, 1001:end), 'k-', 'LineWidth', 0.3);
xlabel('y_1'); ylabel('y_2'); zlabel('y_3');
title('Ground Truth (LorenzZs)');
grid on; view(45, 30);

% Open-loop reconstruction
subplot(1,3,2);
plot3(WRTG(1,:), WRTG(2,:), WRTG(3,:), 'b-', 'LineWidth', 0.3);
xlabel('y_1'); ylabel('y_2'); zlabel('y_3');
title('Open-Loop (train)');
grid on; view(45, 30);

% Closed-loop prediction
subplot(1,3,3);
plot3(WWRPG(1,:), WWRPG(2,:), WWRPG(3,:), 'r-', 'LineWidth', 0.3);
xlabel('y_1'); ylabel('y_2'); zlabel('y_3');
title('Closed-Loop (predict)');
grid on; view(45, 30);

sgtitle('Jason''s Guest Lorenz - Exact Replica');

%% ========================================================================
%  ERROR ANALYSIS
%  ========================================================================

% Compare first 10 seconds of prediction to ground truth
n_compare = min(size(WWRPG, 2), size(LX, 2) - 1000);
pred_segment = WWRPG(:, 1:n_compare);
truth_segment = LX(:, 1001:1000+n_compare);

err = pred_segment - truth_segment;
rel_err = norm(err, 'fro') / norm(truth_segment, 'fro') * 100;

fprintf('Error Analysis (first %.1f seconds of prediction):\n', n_compare*dt);
fprintf('  Relative error: %.2f%%\n', rel_err);
fprintf('\n');

%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  KEY DIFFERENCES FROM OUR IMPLEMENTATION:\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  1. A ≠ 0 (spectral radius 0.01, not zero)\n');
fprintf('  2. dt = 0.001 (not 0.01)\n');
fprintf('  3. decomp_poly4_ns (4th order time expansion)\n');
fprintf('  4. Derivative shift corrections (C2Ss, C3aSs, etc.)\n');
fprintf('  5. R includes A*(sum of coefficients)\n');
fprintf('  6. Scaled Lorenz (scv=200, /10)\n');
fprintf('  7. Train on ground truth THEN predict\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
