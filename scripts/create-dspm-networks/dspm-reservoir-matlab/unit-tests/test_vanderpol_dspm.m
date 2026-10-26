% TEST_VANDERPOL_DSPM  Program Van der Pol oscillator using dspm_reservoir
%
% Van der Pol oscillator:
%   ẏ₁ = y₂
%   ẏ₂ = μ(1 - y₁²)y₂ - y₁
%
% This is a good test case because:
%   - Nonlinear (cubic term y₁²y₂)
%   - Stable limit cycle (errors don't explode)
%   - Classic dynamical system

clear; close all; clc;

%% Add path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));

%% Parameters
mu = 1.0;       % nonlinearity parameter

N = 300;        % neurons
gamma = 50;     % time constant
dt = 0.01;      % time step

rng(42);

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  VAN DER POL OSCILLATOR TEST - dspm_reservoir\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Parameters: μ = %.2f\n', mu);
fprintf('Reservoir: N=%d, γ=%.1f, dt=%.4f\n\n', N, gamma, dt);

%% Create reservoir
fprintf('Creating reservoir...\n');

res = dspm_reservoir(N, ...
    'n_recurrent_inputs', 2, ...
    'n_external_inputs', 0, ...
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...
    'decompilation_order', 3, ...  % NEED order 3 for y₁²y₂
    'verbose', false);

fprintf('  ✓ R matrix: %d × %d\n', size(res.R, 1), size(res.R, 2));
fprintf('  ✓ Monomials: %d\n\n', res.n_monomials);

%% Inspect basis
fprintf('Basis structure:\n');
res.printBasis(20);
fprintf('\n');

%% Build program matrix
fprintf('Building P matrix...\n');

idx_y1 = res.getColumnIndex('x1');
idx_y2 = res.getColumnIndex('x2');
idx_y1sq = res.getColumnIndex('x1^2');      % or 'x1*x1'
idx_y1sq_y2 = res.getColumnIndex('x1^2*x2'); % cubic term

% Try alternative if first attempt fails
if isempty(idx_y1sq)
    idx_y1sq = res.getColumnIndex('x1*x1');
end

fprintf('  y₁    → col %d\n', idx_y1);
fprintf('  y₂    → col %d\n', idx_y2);
fprintf('  y₁²   → col %d\n', idx_y1sq);
fprintf('  y₁²y₂ → col %d\n', idx_y1sq_y2);

P = zeros(2, res.n_monomials);

% Row 1: y₁ + (1/γ)*y₂
%   ẏ₁ = y₂
%   → P₁ = y₁ + y₂/γ
P(1, idx_y1) = 1;
P(1, idx_y2) = 1/gamma;

% Row 2: y₂ + (1/γ)*(μ(1-y₁²)y₂ - y₁)
%   ẏ₂ = μy₂ - μy₁²y₂ - y₁
%   → P₂ = y₂ + (1/γ)*(μy₂ - μy₁²y₂ - y₁)
%        = -1/γ * y₁ + (1 + μ/γ)*y₂ - μ/γ * y₁²y₂
P(2, idx_y1) = -1/gamma;
P(2, idx_y2) = 1 + mu/gamma;
if ~isempty(idx_y1sq_y2)
    P(2, idx_y1sq_y2) = -mu/gamma;
else
    warning('Could not find y₁²y₂ term in basis!');
end

fprintf('\n  P matrix (non-zero entries):\n');
for row = 1:2
    nz = find(P(row,:) ~= 0);
    fprintf('    Row %d: ', row);
    for j = nz
        fprintf('P(%d,%d)=%.4f  ', row, j, P(row,j));
    end
    fprintf('\n');
end
fprintf('\n');

%% Compile
fprintf('Compiling...\n');
[residual, rank_R, stats] = res.compile(P);
fprintf('  Residual: %.2e\n', residual);
fprintf('  Relative error: %.2f%%\n\n', stats.rel_error * 100);

%% Close loop
fprintf('Closing loop...\n');
A_tilde = res.close_loop();
fprintf('  ||Ã||_F: %.4f\n', norm(A_tilde, 'fro'));
fprintf('  Spectral radius: %.4f\n\n', max(abs(eig(A_tilde))));

%% Condition
y0 = [0.1; 0];  % small initial displacement
r0 = res.condition(y0);
% res.is_conditioned removed: status is now derived (see MIGRATION.md)
fprintf('Conditioned to y₀ = [%.2f, %.2f]\n', y0(1), y0(2));
fprintf('  Initial readout: [%.4f, %.4f]\n\n', res.readout(res.r0)');

%% Simulate
T_sim = 30;  % seconds (enough for limit cycle)
T_steps = round(T_sim / dt);

fprintf('Simulating %.1f seconds...\n', T_sim);
[~, y_traj] = res.simulate(T_steps);   % r0 stored by condition()

%% Ground truth
fprintf('Computing ground truth...\n');
vdp = @(t, y) [y(2); mu*(1 - y(1)^2)*y(2) - y(1)];
[t_ode, y_ode] = ode45(vdp, [0, T_sim], y0);
t_res = (0:T_steps-1) * dt;
y_truth = interp1(t_ode, y_ode, t_res)';

%% Error (only compute for first 10 seconds before chaos diverges)
n_compare = min(T_steps, round(10/dt));
err = y_traj(:, 1:n_compare) - y_truth(:, 1:n_compare);
rel_err = norm(err, 'fro') / norm(y_truth(:, 1:n_compare), 'fro') * 100;

fprintf('\n  Relative error (first 10s): %.2f%%\n\n', rel_err);

%% Plot
figure('Name', 'Van der Pol Oscillator', 'Position', [100 100 1400 500]);

% Time series
subplot(1,3,1);
plot(t_res, y_traj(1,:), 'b-', 'LineWidth', 1);
hold on;
plot(t_res, y_truth(1,:), 'r--', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('y_1');
title('Position vs Time');
legend('Reservoir', 'Truth');

subplot(1,3,2);
plot(t_res, y_traj(2,:), 'b-', 'LineWidth', 1);
hold on;
plot(t_res, y_truth(2,:), 'r--', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('y_2');
title('Velocity vs Time');

% Phase portrait
subplot(1,3,3);
plot(y_traj(1,:), y_traj(2,:), 'b-', 'LineWidth', 0.5);
hold on;
plot(y_truth(1,:), y_truth(2,:), 'r--', 'LineWidth', 0.5);
xlabel('y_1'); ylabel('y_2');
title('Phase Portrait (Limit Cycle)');
legend('Reservoir', 'Truth');

sgtitle(sprintf('Van der Pol: μ=%.1f, N=%d, Error=%.2f%%', mu, N, rel_err));

%% Summary
fprintf('═══════════════════════════════════════════════════════════════\n');
if rel_err < 5
    fprintf('  ✓ SUCCESS: Error %.2f%% < 5%%\n', rel_err);
elseif rel_err < 20
    fprintf('  ~ ACCEPTABLE: Error %.2f%% < 20%%\n', rel_err);
else
    fprintf('  ✗ PROBLEM: Error %.2f%% >= 20%%\n', rel_err);
end
fprintf('═══════════════════════════════════════════════════════════════\n');
