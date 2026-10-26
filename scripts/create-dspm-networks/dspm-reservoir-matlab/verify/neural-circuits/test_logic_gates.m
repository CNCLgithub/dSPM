% TEST_LOGIC_GATES  Validate all six logic gates using bistable dynamics
%
% From Kim & Bassett (2023) Figure 5, code_neural_circuits.m
%
% Programs six logic gates: AND, NAND, OR, NOR, XOR, XNOR
% Each gate uses cubic dynamics for bistability.
%
% Key concept: Bistable dynamics create two stable fixed points,
% and input-dependent terms shift between them based on logic.
%
% See also: dspm_reservoir, test_adder, test_sr_latch

clearvars; clc; close all

%% Add helpers to path  
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

%% Parameters (from code_neural_circuits.m)
m   = 3;           % Inputs: x1=feedback, x2=input1, x3=input2
N   = 30;          % Neurons per gate
dt  = 0.001;
gam = 100;

% Bistable dynamics parameters
xw = 0.025;        % Well width (controls transition sharpness)
xf = 0.1;          % Fixed point location (HIGH/LOW levels)
cx = 3/13;         % Linear coefficient  
ax = -cx / (3*xw^2);  % Cubic coefficient (ensures wells at ±xf)

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  LOGIC GATES TEST (Figure 5)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Gate parameters: xw=%.3f, xf=%.1f, cx=%.4f, ax=%.2f\n', xw, xf, cx, ax);
fprintf('Reservoir: N=%d, γ=%d, dt=%.4f\n\n', N, gam, dt);

%% Define gate dynamics symbolically
% Base cubic for bistability: dxb = cx*x + ax*x³
% This creates stable points at x = ±xf (approximately)

syms x1 x2 x3 real  % x1=output(feedback), x2=input1, x3=input2

% Base cubic dynamics (for the output variable x1)
dxb = cx*x1 + ax*x1^3;

% Gate definitions (from code_neural_circuits.m)
% Convention: x2, x3 are inputs; x1 is the gate output (fed back)
gates = struct();

% AND: output HIGH only when both inputs HIGH
gates.AND.dx = dxb - 0.1 + (x2 + xf)*(x3 + xf)/(2*xf);
gates.AND.truth = [-1, -1, -1, +1];  % [00, 01, 10, 11]

% NAND: NOT AND  
gates.NAND.dx = dxb + 0.1 + (x2 + xf)*(-x3 - xf)/(2*xf);
gates.NAND.truth = [+1, +1, +1, -1];

% OR: output HIGH when either input HIGH
gates.OR.dx = dxb + 0.1 + (x2 - xf)*(-x3 + xf)/(2*xf);
gates.OR.truth = [-1, +1, +1, +1];

% NOR: NOT OR
gates.NOR.dx = dxb - 0.1 + (x2 - xf)*(x3 - xf)/(2*xf);
gates.NOR.truth = [+1, -1, -1, -1];

% XOR: exclusive OR (different inputs = HIGH)
gates.XOR.dx = dxb + 0.0 + (-x2)*(x3)/xf;
gates.XOR.truth = [-1, +1, +1, -1];

% XNOR: NOT XOR (same inputs = HIGH)
gates.XNOR.dx = dxb + 0.0 + (x2)*(x3)/xf;
gates.XNOR.truth = [+1, -1, -1, +1];

gate_names = {'AND', 'NAND', 'OR', 'NOR', 'XOR', 'XNOR'};

%% Test inputs (LOW = -xf, HIGH = +xf)
test_inputs = [-xf, -xf;   % 0, 0
               -xf, +xf;   % 0, 1
               +xf, -xf;   % 1, 0
               +xf, +xf];  % 1, 1

T_converge = 10000;  % Time steps for convergence

%% Test each gate
fprintf('Testing gates...\n\n');

results = struct();
all_passed = true;

for g = 1:length(gate_names)
    name = gate_names{g};
    fprintf('  %s gate:\n', name);
    
    % Create reservoir for this gate
    rng(42);  % Same seed for each gate
    res = dspm_reservoir( ...
        'n_neurons', N, ...
        'n_recurrent_inputs', 3, ...
        'n_external_inputs', 0, ...
        'gamma', gam, ...
        'dt', dt, ...
        'B_scale', 0.05, ...
        'decompilation_order', 4, ...
        'verbose', false);
    
    % Program: dynamics are for x1 (output), with x2,x3 as inputs held constant
    % We program: dx1 = gate_dynamics(x1, x2, x3)
    %             dx2 = 0 (input, not dynamic)
    %             dx3 = 0 (input, not dynamic)
    dx_full = [gates.(name).dx; 0; 0];
    
    try
        res.program(dx_full);
        res.close_loop();
        
        outputs = zeros(1, 4);
        
        for i = 1:4
            % Set initial condition: output near zero, inputs at test values
            y0 = [0; test_inputs(i,1); test_inputs(i,2)];
            res.condition(y0);
            
            % Simulate until convergence
            [~, y_out] = res.simulate(T_converge);
            
            % Output is x1 (first component)
            outputs(i) = y_out(1, end);
        end
        
        % Check against truth table
        expected = gates.(name).truth * xf;
        actual_binary = sign(outputs);
        expected_binary = gates.(name).truth;
        
        passed = all(actual_binary == expected_binary);
        all_passed = all_passed && passed;
        
        results.(name).outputs = outputs;
        results.(name).expected = expected;
        results.(name).passed = passed;
        
        if passed
            fprintf('    ✓ PASS\n');
        else
            fprintf('    ✗ FAIL\n');
            fprintf('      Expected: [%+.2f, %+.2f, %+.2f, %+.2f]\n', expected);
            fprintf('      Got:      [%+.2f, %+.2f, %+.2f, %+.2f]\n', outputs);
        end
        
    catch ME
        fprintf('    ✗ ERROR: %s\n', ME.message);
        results.(name).passed = false;
        all_passed = false;
    end
end

%% Summary
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  TRUTH TABLE SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('  Gate   | 0,0 | 0,1 | 1,0 | 1,1 | Status\n');
fprintf('  -------|-----|-----|-----|-----|--------\n');

for g = 1:length(gate_names)
    name = gate_names{g};
    if isfield(results, name) && results.(name).passed
        status = '✓';
        out = results.(name).outputs;
        out_str = sprintf('%s   %s   %s   %s', ...
            ternary(out(1) > 0, 'H', 'L'), ...
            ternary(out(2) > 0, 'H', 'L'), ...
            ternary(out(3) > 0, 'H', 'L'), ...
            ternary(out(4) > 0, 'H', 'L'));
    elseif isfield(results, name)
        status = '✗';
        out = results.(name).outputs;
        out_str = sprintf('%s   %s   %s   %s', ...
            ternary(out(1) > 0, 'H', 'L'), ...
            ternary(out(2) > 0, 'H', 'L'), ...
            ternary(out(3) > 0, 'H', 'L'), ...
            ternary(out(4) > 0, 'H', 'L'));
    else
        status = '?';
        out_str = '?   ?   ?   ?';
    end
    fprintf('  %-6s | %s | %s\n', name, out_str, status);
end

fprintf('\n');
if all_passed
    fprintf('  ★ ALL GATES PASSED ★\n');
else
    fprintf('  ✗ SOME GATES FAILED\n');
end
fprintf('═══════════════════════════════════════════════════════════════\n');

%% Helper function
function s = ternary(cond, true_val, false_val)
    if cond
        s = true_val;
    else
        s = false_val;
    end
end
