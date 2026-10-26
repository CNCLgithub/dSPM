%% Test basic construction — new dspm_reservoir API
% Quick daily-driver checks. For the exhaustive suite see
% test_construction_and_validation.m; for the pipeline see test_phase1_smoke.m.
clear; clc;

%% Test 1: Name-value construction (eager, so the basis exists immediately)
fprintf('=== Test 1: Basic Construction ===\n');
res = dspm_reservoir(100, n_recurrent_inputs=3, decompile="eager", ...
                     verbose=false, random_seed=11);
assert(res.n_neurons == 100, 'n_neurons mismatch');
assert(res.n_recurrent_inputs == 3, 'n_recurrent_inputs mismatch');
assert(res.is_initialized, 'Should be initialized');
assert(res.is_decompiled, 'Should be decompiled (eager)');
fprintf('✓ Basic construction passed\n\n');

%% Test 2: Dimensions
fprintf('=== Test 2: Dimension Checks ===\n');
assert(size(res.B, 1) == res.n_neurons, 'B row mismatch');
assert(size(res.B, 2) == res.n_inputs, 'B col mismatch');
assert(numel(res.r_star) == res.n_neurons, 'r_star size mismatch');
assert(numel(res.x_star) == res.n_inputs, 'x_star size mismatch');
assert(numel(res.d_star) == res.n_neurons, 'd_star size mismatch');
% legacy aliases agree with canonical names
assert(isequal(res.read_in_matrix_B, res.B), 'alias B mismatch');
assert(isequal(res.bias, res.d_star), 'bias must alias d_star');
fprintf('✓ Dimension checks passed\n\n');

%% Test 3: Decompilation artifacts
fprintf('=== Test 3: Decompilation Outputs ===\n');
assert(~isempty(res.decompiled_weight_matrix), 'R should not be empty');
assert(~isempty(res.symbolic_basis_strings), 'symbolic_basis_strings empty');
assert(~isempty(res.physical_basis_strings), 'physical_basis_strings empty');
assert(res.n_monomials == size(res.decompiled_weight_matrix, 2), 'K mismatch');
fprintf('✓ Decompilation outputs passed\n\n');

%% Test 4: Port table
fprintf('=== Test 4: Port Table ===\n');
assert(numel(res.ports) == 3, 'port count');
assert(all(strcmp({res.ports.role}, 'recurrent')), 'roles');
assert(strcmp(res.ports(1).id, 'rec1') && strcmp(res.ports(3).id, 'rec3'), 'ids');
assert(~any([res.ports.bound]), 'nothing bound before closure');
fprintf('✓ Port table passed\n\n');

%% Test 5: Fixed-point identity at birth
fprintf('=== Test 5: Identity ===\n');
d_ref = atanh(res.r_star) - res.B * res.x_star;
assert(norm(res.d_star - d_ref, inf) < 1e-12, 'identity violated');
fprintf('✓ Identity holds\n\n');

%% Test 6: Lazy default is actually lazy
fprintf('=== Test 6: Lazy Default ===\n');
res2 = dspm_reservoir(60, ports=["rec","exo"], verbose=false);
assert(~res2.is_decompiled, 'default construction must be lazy');
assert(res2.capabilities().programmable, 'should be programmable');
assert(res2.n_exogenous_inputs == 1, 'exo count');
fprintf('✓ Lazy default passed\n\n');

fprintf('=== ALL BASIC CONSTRUCTION TESTS PASSED ===\n');
