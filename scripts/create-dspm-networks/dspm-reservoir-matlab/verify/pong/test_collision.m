% TEST_COLLISION  Validate collision detection using pitchfork bifurcation
%
% From Kim & Bassett (2023) Figure 6, code_pong.m
%
% Collision detection uses supercritical pitchfork bifurcation:
%   ċ = (x - x_wall) * c - c³
%
% When x < x_wall: c → 0 (no collision)
% When x > x_wall: c → ±√(x - x_wall) (collision detected)
%
% Key concept: The parameter (x - x_wall) controls whether c has one
% stable fixed point (0) or two (±√(x - x_wall)).
%
% See also: dspm_reservoir, test_velocity_latch, test_pong_full

clearvars; clc; close all

%% Add helpers to path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

%% Parameters (from code_pong.m)
N   = 100;
dt  = 0.001;
gam = 100;

xw = 0.05;   % Wall position (right wall at +xw)

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  COLLISION DETECTION TEST (Figure 6)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Wall position: x_wall = %.2f\n', xw);
fprintf('Reservoir: N=%d, γ=%d, dt=%.4f\n\n', N, gam, dt);

%% Define collision dynamics
% State: [x, c] where x is ball position, c is collision variable
% Dynamics:
%   ẋ = 0 (x is held constant as test input)
%   ċ = 1000 * ((x - x_wall) * c - c³)

syms x c real

% Pitchfork bifurcation dynamics
% The factor 1000 makes convergence fast
dc = 1000 * ((x - xw) * c - c^3);

fprintf('Collision dynamics: ċ = 1000 * ((x - %.2f) * c - c³)\n\n', xw);

%% Create and program reservoir
fprintf('Programming collision detector...\n');

rng(42);

res = dspm_reservoir( ...
    'n_neurons', N, ...
    'n_recurrent_inputs', 2, ...   % x = position, c = collision variable
    'n_external_inputs', 0, ...
    'gamma', gam, ...
    'dt', dt, ...
    'B_scale', 0.1, ...
    'decompilation_order', 4, ...
    'verbose', false);

% Program: dx = 0 (x held constant), dc = collision dynamics
dx_full = [0; dc];

res.program(dx_full);
res.close_loop();

fprintf('  ✓ Programmed collision detector\n\n');

%% Test at various x positions
test_positions = linspace(-0.1, 0.1, 11);  % Range around wall
T_converge = 5000;

fprintf('Testing collision detection at various x positions...\n\n');

results = zeros(length(test_positions), 2);  % [x, final_c]

for i = 1:length(test_positions)
    x_test = test_positions(i);
    
    % Start with c slightly perturbed from 0
    y0 = [x_test; 0.01];  % Small initial c to break symmetry
    res.condition(y0);
    
    [~, y_out] = res.simulate(T_converge);
    
    final_c = y_out(2, end);
    results(i, :) = [x_test, abs(final_c)];  % Take absolute value
    
    % Expected behavior:
    % x < x_wall: c → 0
    % x > x_wall: c → √(x - x_wall)
    if x_test < xw
        expected = 0;
    else
        expected = sqrt(x_test - xw);
    end
    
    error = abs(abs(final_c) - expected);
    
    if error < 0.02 || (expected == 0 && abs(final_c) < 0.02)
        status = '✓';
    else
        status = '✗';
    end
    
    fprintf('  x=%.3f: c→%.4f (expected %.4f) %s\n', x_test, abs(final_c), expected, status);
end

%% Theoretical curve
fprintf('\nGenerating theoretical bifurcation curve...\n');

x_theory = linspace(-0.1, 0.1, 100);
c_theory = zeros(size(x_theory));
for i = 1:length(x_theory)
    if x_theory(i) > xw
        c_theory(i) = sqrt(x_theory(i) - xw);
    end
end

%% Summary
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

% Check overall accuracy
errors = zeros(length(test_positions), 1);
for i = 1:length(test_positions)
    x_test = test_positions(i);
    if x_test < xw
        expected = 0;
    else
        expected = sqrt(x_test - xw);
    end
    errors(i) = abs(results(i,2) - expected);
end

max_error = max(errors);
mean_error = mean(errors);

fprintf('  Max error from theory: %.4f\n', max_error);
fprintf('  Mean error from theory: %.4f\n', mean_error);

if max_error < 0.05
    fprintf('\n  ★ COLLISION DETECTION PASSED ★\n');
else
    fprintf('\n  ✗ COLLISION DETECTION FAILED\n');
end
fprintf('═══════════════════════════════════════════════════════════════\n');

%% Plot
figure('Position', [100 100 600 400]);

% Plot theoretical curve
plot(x_theory, c_theory, 'b-', 'LineWidth', 2, 'DisplayName', 'Theory: c = √(x-x_w)');
hold on;

% Plot simulation results
plot(results(:,1), results(:,2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', ...
    'DisplayName', 'Simulation');

% Mark wall position
xline(xw, '--k', 'LineWidth', 1.5, 'DisplayName', sprintf('Wall (x=%.2f)', xw));

xlabel('Ball Position x');
ylabel('Collision Variable |c|');
title('Pitchfork Bifurcation for Collision Detection');
legend('Location', 'northwest');
grid on;

fprintf('\nBifurcation diagram plotted.\n');
