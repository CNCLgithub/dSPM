% TEST_OSCILLATOR_DSPM  Program and run harmonic oscillator using dspm_reservoir
%
% This is the simplest possible test - a 2D linear harmonic oscillator:
%   ẏ₁ = y₂
%   ẏ₂ = -ω²y₁
%
% Solution: y₁(t) = A*cos(ωt + φ)
%
% Since this is LINEAR, errors should be minimal if the framework is correct.

clear; close all; clc;

%% Add path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));

%% Parameters
omega = 1.0;    % angular frequency

N = 200;        % neurons (small since linear)
gamma = 50;     % time constant
dt = 0.01;      % time step

rng(42);

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  HARMONIC OSCILLATOR TEST - dspm_reservoir\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Oscillator: ω = %.2f (period = %.2f s)\n', omega, 2*pi/omega);
fprintf('Reservoir: N=%d, γ=%.1f, dt=%.4f\n\n', N, gamma, dt);

%% Create reservoir
fprintf('Creating reservoir...\n');

res = dspm_reservoir(N, ...
    'n_recurrent_inputs', 2, ...   % y1, y2
    'n_external_inputs', 0, ...
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...
    'decompilation_order', 2, ...  % just need linear, but 2 is fine
    'verbose', false);

fprintf('  ✓ R matrix: %d × %d\n', size(res.R, 1), size(res.R, 2));
fprintf('  ✓ Monomials: %d\n\n', res.n_monomials);

%% Build program matrix
fprintf('Building P matrix...\n');

idx_y1 = res.getColumnIndex('x1');
idx_y2 = res.getColumnIndex('x2');

fprintf('  y₁ → col %d\n', idx_y1);
fprintf('  y₂ → col %d\n', idx_y2);

P = zeros(2, res.n_monomials);

% Row 1: y₁ + (1/γ)*y₂ = y₁ + (1/γ)*y₂
P(1, idx_y1) = 1;
P(1, idx_y2) = 1/gamma;

% Row 2: y₂ + (1/γ)*(-ω²*y₁) = -ω²/γ*y₁ + y₂
P(2, idx_y1) = -omega^2/gamma;
P(2, idx_y2) = 1;

fprintf('\n  P matrix:\n');
fprintf('    P(1, y₁) = %.4f, P(1, y₂) = %.4f\n', P(1,idx_y1), P(1,idx_y2));
fprintf('    P(2, y₁) = %.4f, P(2, y₂) = %.4f\n', P(2,idx_y1), P(2,idx_y2));
fprintf('\n');

%% Compile
fprintf('Compiling...\n');
[residual, rank_R, stats] = res.compile(P);
fprintf('  Residual: %.2e\n', residual);
fprintf('  Relative error: %.2f%%\n\n', stats.rel_error * 100);

%% Close loop
fprintf('Closing loop...\n');
A_tilde = res.close_loop();
fprintf('  Spectral radius of Ã: %.4f\n\n', max(abs(eig(A_tilde))));

%% Condition
y0 = [1; 0];  % start at max displacement, zero velocity
r0 = res.condition(y0);
% res.is_conditioned removed: status is now derived (see MIGRATION.md)
fprintf('Conditioned to y₀ = [%.1f, %.1f]\n', y0(1), y0(2));
fprintf('  Initial readout: [%.4f, %.4f]\n\n', res.readout(res.r0)');

%% Simulate
T_sim = 20;  % seconds (about 3 periods)
T_steps = round(T_sim / dt);

fprintf('Simulating %.1f seconds...\n', T_sim);
[~, y_traj] = res.simulate(T_steps);   % r0 stored by condition()

%% Ground truth
t = (0:T_steps-1) * dt;
y_truth = [cos(omega*t); -omega*sin(omega*t)];  % exact solution

%% Error
err = y_traj - y_truth;
rel_err = norm(err, 'fro') / norm(y_truth, 'fro') * 100;

fprintf('\n  Relative error: %.4f%%\n\n', rel_err);

%% Plot
figure('Name', 'Harmonic Oscillator', 'Position', [100 100 1200 400]);

subplot(1,3,1);
plot(t, y_traj(1,:), 'b-', 'LineWidth', 1.5);
hold on;
plot(t, y_truth(1,:), 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('y_1 (position)');
title('Position vs Time');
legend('Reservoir', 'Truth');

subplot(1,3,2);
plot(t, y_traj(2,:), 'b-', 'LineWidth', 1.5);
hold on;
plot(t, y_truth(2,:), 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('y_2 (velocity)');
title('Velocity vs Time');

subplot(1,3,3);
plot(y_traj(1,:), y_traj(2,:), 'b-', 'LineWidth', 1);
hold on;
plot(y_truth(1,:), y_truth(2,:), 'r--', 'LineWidth', 1);
xlabel('y_1'); ylabel('y_2');
title('Phase Portrait');
legend('Reservoir', 'Truth');
axis equal;

sgtitle(sprintf('Harmonic Oscillator: ω=%.1f, Error=%.2f%%', omega, rel_err));

%% Summary
fprintf('═══════════════════════════════════════════════════════════════\n');
if rel_err < 1
    fprintf('  ✓ SUCCESS: Error %.4f%% < 1%%\n', rel_err);
elseif rel_err < 5
    fprintf('  ~ ACCEPTABLE: Error %.2f%% < 5%%\n', rel_err);
else
    fprintf('  ✗ PROBLEM: Error %.2f%% >= 5%%\n', rel_err);
end
fprintf('═══════════════════════════════════════════════════════════════\n');
