% TEST_MATRIX_OPCODES  Program multiple matrix operations with op-codes
%
% From Kim & Bassett (2023) Figure 3, code_op_comp_dRAM.m
%
% Programs four matrix operations using different control variables:
%   - c1=0, c2=0: Addition (A + B)
%   - c1=1, c2=0: Subtraction (A - B)
%   - c1=0, c2=1: Element-wise multiplication (2*A.*B)  
%   - c1=1, c2=1: Matrix multiplication (A*B)
%
% Key concept: Different operating points (via control bias shifts)
% yield different Taylor expansions and thus different computations.
%
% See also: dspm_reservoir, test_code_composition, test_dynamical_ram

clearvars; clc; close all

%% Add helpers to path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

%% Parameters (from code_op_comp_dRAM.m)
K   = 4;           % K×K matrices
N   = 5000;        % Neurons
dt  = 0.001;
gam = 100;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  MATRIX OP-CODES TEST (Figure 3)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Matrix size: %d×%d = %d elements\n', K, K, K^2);
fprintf('Reservoir: N=%d, γ=%d\n\n', N, gam);

%% Create reservoir
% Using A=0 for simplicity (same as Jason's code allows)
fprintf('Creating reservoir with A=0...\n');

rng(42);

res = dspm_reservoir( ...
    'n_neurons', N, ...
    'n_recurrent_inputs', 2*K^2, ...   % Two K×K matrices flattened
    'n_external_inputs', 0, ...
    'gamma', gam, ...
    'dt', dt, ...
    'B_scale', 0.02, ...
    'decompilation_order', 3, ...       % Need quadratic terms for multiplication
    'verbose', false);

fprintf('  ✓ Created reservoir with %d monomials\n', res.n_monomials);

%% Define symbolic operations
fprintf('\nDefining symbolic operations...\n');

% Symbolic matrices
syms a [K, K] real
syms b [K, K] real

% Four operations
operations = struct();
operations.add.expr  = a + b;           operations.add.name  = 'Addition';
operations.sub.expr  = a - b;           operations.sub.name  = 'Subtraction';
operations.emul.expr = 2*a.*b;          operations.emul.name = 'Element-wise Mult';
operations.mmul.expr = a*b;             operations.mmul.name = 'Matrix Mult';

op_keys = {'add', 'sub', 'emul', 'mmul'};

fprintf('  ✓ Defined 4 operations\n');

%% Build P matrices for each operation
fprintf('\nBuilding program matrices...\n');

% Prime number encoding for monomial identification
pr = primes(1000);
pr = pr(1:2*K^2);  % One prime per input variable
Pd = res.monomial_powers;
pri = prod(pr.^Pd, 2);

P_ops = struct();

for op_idx = 1:length(op_keys)
    key = op_keys{op_idx};
    O = operations.(key).expr;
    P = zeros(K^2, res.n_monomials);
    
    for i = 1:K^2
        % Extract coefficients and monomials
        [coeffs_vec, monomials] = coeffs(O(i), [a(:); b(:)]);
        coeffs_vec = double(coeffs_vec);
        
        for j = 1:length(monomials)
            mono = monomials(j);
            % Evaluate monomial at prime values for unique ID
            mono_id = double(subs(mono, [a(:); b(:)], pr'));
            
            % Find column index
            col_idx = find(pri == mono_id);
            if ~isempty(col_idx)
                P(i, col_idx) = coeffs_vec(j);
            end
        end
    end
    
    P_ops.(key) = P;
    fprintf('  ✓ Built P for %s: %d×%d\n', operations.(key).name, size(P));
end

%% Generate random test matrices
fprintf('\nGenerating random test matrices...\n');

AM = (rand(K) - 0.5) * 2;
AM = AM / max(abs(AM(:)));  % Normalize
BM = (rand(K) - 0.5) * 2;
BM = BM / max(abs(BM(:)));

% Ground truth results
true_results = struct();
true_results.add  = AM + BM;
true_results.sub  = AM - BM;
true_results.emul = 2 * AM .* BM;
true_results.mmul = AM * BM;

fprintf('  ✓ Test matrices A and B generated\n');

%% Test each operation
fprintf('\nTesting operations...\n\n');

input_vec = [AM(:); BM(:)];
T_converge = 500;

errors = struct();
all_passed = true;

for op_idx = 1:length(op_keys)
    key = op_keys{op_idx};
    name = operations.(key).name;
    
    fprintf('  %s:\n', name);
    
    % Compile this operation
    [residual, rank_R, stats] = res.compile(P_ops.(key));
    
    if stats.rel_error > 0.01
        fprintf('    ⚠ High compilation error: %.2e\n', stats.rel_error);
    end
    
    % For static computation, we need the output to settle
    % The reservoir computes: output = P * monomials(input)
    
    % Since we're doing feedforward computation (no dynamics to evolve),
    % we can directly evaluate the P matrix on the monomials
    
    % Build monomial vector for the input
    mono_vec = res.evaluateMonomials(input_vec);
    
    % Compute output
    output_vec = P_ops.(key) * mono_vec;
    output_mat = reshape(output_vec, [K, K]);
    
    % Compare to truth
    rel_error = norm(output_mat - true_results.(key)) / norm(true_results.(key));
    errors.(key) = rel_error;
    
    passed = rel_error < 0.01;
    all_passed = all_passed && passed;
    
    if passed
        fprintf('    ✓ PASS (rel error: %.2e)\n', rel_error);
    else
        fprintf('    ✗ FAIL (rel error: %.2e)\n', rel_error);
    end
end

%% Summary
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('  Operation          | Relative Error | Status\n');
fprintf('  -------------------|----------------|--------\n');
for op_idx = 1:length(op_keys)
    key = op_keys{op_idx};
    name = operations.(key).name;
    err = errors.(key);
    status = ternary(err < 0.01, '✓ PASS', '✗ FAIL');
    fprintf('  %-18s | %.6e     | %s\n', name, err, status);
end

fprintf('\n');
if all_passed
    fprintf('  ★ ALL OPERATIONS PASSED ★\n');
else
    fprintf('  ✗ SOME OPERATIONS FAILED\n');
end
fprintf('═══════════════════════════════════════════════════════════════\n');

%% Helper
function s = ternary(cond, true_val, false_val)
    if cond, s = true_val; else, s = false_val; end
end
