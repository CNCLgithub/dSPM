% TEST_DYNAMICAL_RAM  Program chaotic attractors as addressable memory
%
% From Kim & Bassett (2023) Figure 3, code_op_comp_dRAM.m
%
% Programs four different chaotic attractors as "memory addresses":
%   - Address 00 (c1=0, c2=0): Lorenz attractor
%   - Address 01 (c1=0, c2=1): Rössler attractor
%   - Address 10 (c1=1, c2=0): Halvorsen attractor
%   - Address 11 (c1=1, c2=1): Thomas attractor
%
% Control variables (c1, c2) select which attractor the network evolves.
%
% Key concept: Bias shifts change the reservoir's fixed point, yielding
% different Taylor expansions that encode different dynamical systems.
%
% See also: dspm_reservoir, test_matrix_opcodes

clearvars; clc; close all

%% Add helpers to path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

%% Parameters (from code_op_comp_dRAM.m)
N   = 1000;
dt  = 0.01;
gam = 100;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  DYNAMICAL RAM TEST (Figure 3)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Reservoir: N=%d, γ=%d, dt=%.3f\n\n', N, gam, dt);

%% Define the four chaotic attractors
% From code_op_comp_dRAM.m

syms x1 x2 x3 real

% Address 00: Lorenz (scaled)
lorenz = [
    10*(x2 - x1);
    x1 - 20*x1*x3 - x2;
    20*x1*x2 - 8/3*(x3 + 27/20)
];

% Address 01: Rössler (scaled)
rossler = [
    -5*x2 - 5*x3 - 5*3/5;
    5*x1 + x2;
    50*5/3*x1*x3 + 50*x1 - 28.5*x3 - 28.4*3/5
];

% Address 10: Halvorsen (scaled)
halvorsen = 1.5 * [
    -1.4*x1 - 4*x2 - 4*x3 - 10*x2^2;
    -1.4*x2 - 4*x3 - 4*x1 - 10*x3^2;
    -1.4*x3 - 4*x1 - 4*x2 - 10*x1^2
];

% Address 11: Thomas (scaled)
thomas = [
    -8*x2;
    25/4*x1 + 8*x3^2;
    25/32 + 20*x2 - 10*x3
];

attractors = {lorenz, rossler, halvorsen, thomas};
attractor_names = {'Lorenz', 'Rössler', 'Halvorsen', 'Thomas'};
addresses = [0 0; 0 1; 1 0; 1 1];

fprintf('Attractors to program:\n');
for i = 1:4
    fprintf('  Address %d%d: %s\n', addresses(i,1), addresses(i,2), attractor_names{i});
end
fprintf('\n');

%% Create base reservoir
fprintf('Creating reservoir...\n');

rng(42);

res = dspm_reservoir( ...
    'n_neurons', N, ...
    'n_recurrent_inputs', 3, ...
    'n_external_inputs', 0, ...
    'gamma', gam, ...
    'dt', dt, ...
    'B_scale', 0.6, ...
    'decompilation_order', 6, ...
    'verbose', false);

fprintf('  ✓ Created reservoir with %d monomials\n\n', res.n_monomials);

%% Program and test each attractor individually
% For now, we test each attractor as a separate program
% (Full dRAM with control variables requires more complex decompilation)

fprintf('Testing attractors individually...\n\n');

T_evolve = 5000;
results = struct();
all_bounded = true;

for i = 1:4
    name = attractor_names{i};
    fprintf('  %s (address %d%d):\n', name, addresses(i,1), addresses(i,2));
    
    % Create fresh reservoir
    rng(42);
    res_i = dspm_reservoir( ...
        'n_neurons', N, ...
        'n_recurrent_inputs', 3, ...
        'n_external_inputs', 0, ...
        'gamma', gam, ...
        'dt', dt, ...
        'B_scale', 0.6, ...
        'decompilation_order', 6, ...
        'verbose', false);
    
    % Program this attractor
    try
        res_i.program(attractors{i});
        res_i.close_loop();
        
        % Random initial condition near origin
        y0 = (rand(3,1) - 0.5) * 0.1;
        res_i.condition(y0);
        
        % Simulate
        [~, y_out] = res_i.simulate(T_evolve);
        
        % Check if bounded (chaotic but not exploding)
        max_val = max(abs(y_out(:)));
        bounded = max_val < 10;  % Reasonable bound for these attractors
        
        results.(name).trajectory = y_out;
        results.(name).bounded = bounded;
        results.(name).max_val = max_val;
        
        if bounded
            fprintf('    ✓ Bounded trajectory (max |y| = %.2f)\n', max_val);
            fprintf('    Range: y1∈[%.2f,%.2f], y2∈[%.2f,%.2f], y3∈[%.2f,%.2f]\n', ...
                min(y_out(1,:)), max(y_out(1,:)), ...
                min(y_out(2,:)), max(y_out(2,:)), ...
                min(y_out(3,:)), max(y_out(3,:)));
        else
            fprintf('    ✗ Unbounded (max |y| = %.2f)\n', max_val);
            all_bounded = false;
        end
        
    catch ME
        fprintf('    ✗ ERROR: %s\n', ME.message);
        results.(name).bounded = false;
        all_bounded = false;
    end
    fprintf('\n');
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('  Attractor   | Address | Bounded | Max |y|\n');
fprintf('  ------------|---------|---------|----------\n');
for i = 1:4
    name = attractor_names{i};
    if results.(name).bounded
        status = '✓';
        max_val = sprintf('%.2f', results.(name).max_val);
    else
        status = '✗';
        max_val = 'N/A';
    end
    fprintf('  %-11s | %d%d      | %s       | %s\n', name, ...
        addresses(i,1), addresses(i,2), status, max_val);
end

fprintf('\n');
if all_bounded
    fprintf('  ★ ALL ATTRACTORS BOUNDED ★\n');
else
    fprintf('  ✗ SOME ATTRACTORS UNBOUNDED\n');
end
fprintf('═══════════════════════════════════════════════════════════════\n');

%% Plot trajectories (optional visualization)
if exist('results', 'var') && all(structfun(@(x) x.bounded, results))
    figure('Position', [100 100 1200 400]);
    
    for i = 1:4
        name = attractor_names{i};
        y = results.(name).trajectory;
        
        subplot(1, 4, i);
        plot3(y(1,:), y(2,:), y(3,:), 'LineWidth', 0.5);
        title(sprintf('%s [%d%d]', name, addresses(i,1), addresses(i,2)));
        xlabel('y_1'); ylabel('y_2'); zlabel('y_3');
        grid on;
        view(30, 20);
    end
    
    sgtitle('Dynamical RAM: Four Attractors as Memory Addresses');
end
