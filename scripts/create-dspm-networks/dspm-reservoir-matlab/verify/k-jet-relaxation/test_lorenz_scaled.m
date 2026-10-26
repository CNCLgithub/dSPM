% TEST_LORENZ_SCALED  Validate Lorenz attractor using all three programming methods
%
% Validates the fundamental programming capability using scaled Lorenz dynamics
% from Kim & Bassett (2023) code_virtualize.m
%
% Three validation methods:
%   1. Symbolic: res.program(dx)
%   2. JSON: dspm_reservoir.load('lorenz_scaled.json')  
%   3. Hand-coded: Direct P matrix construction
%
% All three must produce identical P matrices and bounded trajectories.
%
% See also: dspm_reservoir, test_guest_rnn

clearvars; clc; close all

%% Add helpers to path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

%% Parameters (from code_virtualize.m)
scv   = 200;       % Scaling factor (keeps dynamics in [-0.4, 0.4])
sigma = 10;
rho   = 28;
beta  = 8/3;

N     = 50;        % Neurons
gamma = 100;       % Time constant
dt    = 0.01;      % Integration step
seed  = 42;        % Random seed

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  SCALED LORENZ ATTRACTOR TEST\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Parameters: scv=%d, σ=%.1f, ρ=%.1f, β=%.4f\n', scv, sigma, rho, beta);
fprintf('Reservoir:  N=%d, γ=%d, dt=%.4f, seed=%d\n\n', N, gamma, dt, seed);

%% Create reservoirs with same random seed
fprintf('Creating three reservoirs with identical random seed...\n');

common_opts = { ...
    'n_neurons', N, ...
    'B_scale', 0.2, ...
    'B_sparsity', 0.7, ...
    'n_recurrent_inputs', 3, ...
    'n_external_inputs', 0, ...
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...
    'decompilation_order', 3, ...
    'random_seed', seed, ...
    'verbose', false};

% Method 1: Symbolic programming
res_prog = dspm_reservoir(common_opts{:});

% Method 2: JSON loading (if file exists)
json_path = 'saved-networks/presets/attractors/lorenz_scaled.json';
if exist(json_path, 'file')
    res_load = dspm_reservoir.load(json_path, common_opts{:});
    has_json = true;
else
    warning('JSON file not found: %s - skipping JSON test', json_path);
    res_load = dspm_reservoir(common_opts{:});
    has_json = false;
end

% Method 3: Hand-coded
res_hand = dspm_reservoir(common_opts{:});

fprintf('  ✓ Created reservoirs with %d monomials\n\n', res_prog.n_monomials);

%% Method 1: Symbolic programming
fprintf('Method 1: Symbolic programming via res.program(dx)...\n');

syms x1 x2 x3 real

% Scaled Lorenz from code_virtualize.m:
%   dy = [-10*y(1) + 10*y(2);
%         y(1)*(28-(scv*y(3)+27)) - y(2);
%         scv*y(1)*y(2) - 8/3*(y(3)+27/scv)] / 10;
dx = [
    sigma * (x2 - x1)
    x1 * (rho - 27 - scv*x3) - x2
    scv * x1 * x2 - beta * (x3 + 27/scv)
] / 10;

res_prog.program(dx);
fprintf('  ✓ Symbolic programming complete\n');

%% Method 2: JSON loading (already done in constructor if file exists)
if has_json
    fprintf('\nMethod 2: Loaded from JSON preset\n');
    fprintf('  ✓ JSON loading complete\n');
else
    fprintf('\nMethod 2: Skipped (no JSON file)\n');
    % Program the second reservoir symbolically so comparison works
    res_load.program(dx);
end

%% Method 3: Hand-coded P matrix
fprintf('\nMethod 3: Hand-coded P matrix construction...\n');

P = buildProgramMatrixByHand(res_hand, sigma, rho, beta, scv);
[residual, rank_R, stats] = res_hand.compile(P);

fprintf('  ✓ Hand-coded programming complete\n');
fprintf('    Compilation residual: %.2e, Rank: %d/%d\n', residual, rank_R, res_hand.n_monomials);

%% Verify P matrices match
fprintf('\nVerifying P matrices match...\n');

fnorm = @(r1, r2) norm(r1.compiled_program_matrix - r2.compiled_program_matrix, 'fro');

err_prog_load = fnorm(res_prog, res_load);
err_prog_hand = fnorm(res_prog, res_hand);
err_load_hand = fnorm(res_load, res_hand);

fprintf('  ||P_prog - P_load||_F = %.2e\n', err_prog_load);
fprintf('  ||P_prog - P_hand||_F = %.2e\n', err_prog_hand);
fprintf('  ||P_load - P_hand||_F = %.2e\n', err_load_hand);

tol = 1e-10;
p_match = max([err_prog_load, err_prog_hand, err_load_hand]) < tol;

if p_match
    fprintf('  ✓ All P matrices match!\n');
else
    fprintf('  ✗ P matrix mismatch detected!\n');
end

%% Simulate all three
fprintf('\nSimulating trajectories...\n');

res_prog.close_loop();
res_load.close_loop();
res_hand.close_loop();

y0 = randn(3, 1) * 0.1;  % Small initial condition
tsim = 10000;

res_prog.condition(y0);
res_load.condition(y0);
res_hand.condition(y0);

[~, y_prog] = res_prog.simulate(tsim);
[~, y_load] = res_load.simulate(tsim);
[~, y_hand] = res_hand.simulate(tsim);

fprintf('  ✓ All simulations complete\n');

%% Generate ground truth for comparison
fprintf('\nGenerating ground truth...\n');

scaled_lorenz = @(t, y) [
    sigma * (y(2) - y(1));
    y(1) * (rho - (scv*y(3) + 27)) - y(2);
    scv * y(1) * y(2) - beta * (y(3) + 27/scv)
] / 10;

T_total = tsim * dt;
[t_ode, y_ode] = ode45(scaled_lorenz, [0, T_total], y0, odeset('MaxStep', dt));
t_grid = (0:dt:T_total)';
y_truth = interp1(t_ode, y_ode, t_grid)';
y_truth = y_truth(:, 1:tsim);

fprintf('  ✓ Ground truth generated\n');

%% Summary
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('  Method       |  y1 range      |  y2 range      |  y3 range\n');
fprintf('  -------------|----------------|----------------|----------------\n');
fprintf('  Ground truth | [%+.3f, %+.3f] | [%+.3f, %+.3f] | [%+.3f, %+.3f]\n', ...
    min(y_truth(1,:)), max(y_truth(1,:)), ...
    min(y_truth(2,:)), max(y_truth(2,:)), ...
    min(y_truth(3,:)), max(y_truth(3,:)));
fprintf('  program()    | [%+.3f, %+.3f] | [%+.3f, %+.3f] | [%+.3f, %+.3f]\n', ...
    min(y_prog(1,:)), max(y_prog(1,:)), ...
    min(y_prog(2,:)), max(y_prog(2,:)), ...
    min(y_prog(3,:)), max(y_prog(3,:)));
fprintf('  load()       | [%+.3f, %+.3f] | [%+.3f, %+.3f] | [%+.3f, %+.3f]\n', ...
    min(y_load(1,:)), max(y_load(1,:)), ...
    min(y_load(2,:)), max(y_load(2,:)), ...
    min(y_load(3,:)), max(y_load(3,:)));
fprintf('  hand-coded   | [%+.3f, %+.3f] | [%+.3f, %+.3f] | [%+.3f, %+.3f]\n', ...
    min(y_hand(1,:)), max(y_hand(1,:)), ...
    min(y_hand(2,:)), max(y_hand(2,:)), ...
    min(y_hand(3,:)), max(y_hand(3,:)));

% Check if trajectories are bounded (chaotic but not blowing up)
bounded = all([max(abs(y_prog(:))) < 1, ...
               max(abs(y_load(:))) < 1, ...
               max(abs(y_hand(:))) < 1]);

fprintf('\n');
if p_match && bounded
    fprintf('  ★ TEST PASSED ★\n');
else
    fprintf('  ✗ TEST FAILED\n');
    if ~p_match, fprintf('    - P matrices do not match\n'); end
    if ~bounded, fprintf('    - Trajectories not bounded\n'); end
end
fprintf('═══════════════════════════════════════════════════════════════\n');

%% =========================================================================
%  HELPER FUNCTION
%  =========================================================================

function P = buildProgramMatrixByHand(res, sigma, rho, beta, scv)
% Build P matrix directly from DNP formula
%
% From Kim & Bassett (2023):
%   P(i,:) = y_i + (1/γ) * ẏ_i
%
% For scaled Lorenz:
%   f1 = (σ*(y2-y1)) / 10
%   f2 = (y1*(ρ-27-scv*y3) - y2) / 10  
%   f3 = (scv*y1*y2 - β*(y3+27/scv)) / 10

    gamma = res.gamma;
    
    % Get column indices
    idx_const = res.getColumnIndex('1');
    idx_y1    = res.getColumnIndex('x1');
    idx_y2    = res.getColumnIndex('x2');
    idx_y3    = res.getColumnIndex('x3');
    idx_y1y2  = res.getColumnIndex('x1*x2');
    idx_y1y3  = res.getColumnIndex('x1*x3');
    
    P = zeros(3, res.n_monomials);
    
    % Row 1: y1 + (1/γ)*(σ/10)*(y2 - y1)
    P(1, idx_y1) = 1 - sigma / (10 * gamma);
    P(1, idx_y2) = sigma / (10 * gamma);
    
    % Row 2: y2 + (1/γ)*(1/10)*(y1*(ρ-27-scv*y3) - y2)
    % = y2 + (1/γ)*(1/10)*((ρ-27)*y1 - scv*y1*y3 - y2)
    P(2, idx_y1)   = (rho - 27) / (10 * gamma);
    P(2, idx_y2)   = 1 - 1 / (10 * gamma);
    P(2, idx_y1y3) = -scv / (10 * gamma);
    
    % Row 3: y3 + (1/γ)*(1/10)*(scv*y1*y2 - β*(y3 + 27/scv))
    % = y3 + (1/γ)*(1/10)*(scv*y1*y2 - β*y3 - 27β/scv)
    P(3, idx_const) = -27 * beta / (scv * 10 * gamma);
    P(3, idx_y3)    = 1 - beta / (10 * gamma);
    P(3, idx_y1y2)  = scv / (10 * gamma);
end
