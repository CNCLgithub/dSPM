%% Construction & Validation Suite — new dspm_reservoir API
% Comprehensive checks of construction paths, the port model, derived status,
% the §1.9 invalidation matrix, legacy aliases, and the declarative factory.
% Sections needing the Symbolic Toolbox are skipped gracefully without it.
clear; clc;
n_pass = 0;
have_sym = ~isempty(ver('symbolic'));

%% 1. Construction paths
fprintf('=== 1: Construction paths ===\n');
r1 = dspm_reservoir(50, n_recurrent_inputs=2, verbose=false);        % positional N
assert(r1.n_neurons == 50 && r1.n_recurrent_inputs == 2);
r2 = dspm_reservoir(n_neurons=50, n_recurrent_inputs=2, verbose=false);  % pure NV
assert(r2.n_neurons == 50);
r3 = dspm_reservoir(50, ports=["rec","exo","ext"], verbose=false);   % role spec
assert(r3.n_recurrent_inputs == 1 && r3.n_exogenous_inputs == 1 && r3.n_inputs == 3);
r4 = dspm_reservoir(50, ports="infer", verbose=false);               % deferred m̃
assert(~r4.is_initialized && isempty(r4.ports));
r5 = dspm_reservoir(50, 'n_recurrent_inputs', 2, 'verbose', false);  % char pairs
assert(r5.n_recurrent_inputs == 2);
n_pass = n_pass + 1; fprintf('✓ construction paths\n\n');

%% 2. Port ontology: ids, labels, roles, aliases, table
fprintf('=== 2: Port ontology ===\n');
p = dspm_reservoir(40, ports=["rec","exo","exo","ext"], ...
                   port_names=["fb","in1","in2","drive"], verbose=false);
assert(strcmp(p.ports(1).id,'rec1') && strcmp(p.ports(2).id,'exo1') && ...
       strcmp(p.ports(3).id,'exo2') && strcmp(p.ports(4).id,'ext1'));
assert(p.ports(2).aliases == "in1" && p.ports(4).aliases == "drive");
assert(p.live_input_width == 4 && ~any([p.ports.bound]));
% legacy index aliases derive from roles
assert(isequal(p.recurrent_input_indices, 1));
assert(isequal(p.external_input_indices, 2:4));   % legacy external = non-recurrent
n_pass = n_pass + 1; fprintf('✓ port ontology\n\n');

%% 3. Derived status: flags readable, not writable
fprintf('=== 3: Derived status ===\n');
s = r1.status();
assert(islogical(s.is_initialized) && s.is_initialized);
assert(~s.is_decompiled && ~s.is_compiled && ~s.is_closed && ~s.is_conditioned);
threw = false;
try, r1.is_conditioned = true; catch, threw = true; end
assert(threw, 'derived flags must be read-only');
c = r1.capabilities();
assert(c.programmable && ~c.runnable && ~c.composable_source && c.reopenable);
n_pass = n_pass + 1; fprintf('✓ derived status & read-only flags\n\n');

%% 4. Identity & alias coherence
fprintf('=== 4: Identity & aliases ===\n');
q = dspm_reservoir(40, n_recurrent_inputs=2, verbose=false, random_seed=2);
assert(norm(q.d_star - (atanh(q.r_star) - q.B * q.x_star), inf) < 1e-12);
assert(isequal(q.bias, q.d_star));
assert(isequal(q.read_in_matrix_B, q.B));
assert(isequal(q.read_in_matrix_recurrent, q.B(:, 1:2)));
q.x_recurrent_star = [0.1; -0.1];             % legacy sliced expansion-point set
assert(isequal(q.x_star, [0.1; -0.1]));
assert(norm(q.d_star - (atanh(q.r_star) - q.B * q.x_star), inf) < 1e-12, ...
    'identity must refresh after x0 change');
n_pass = n_pass + 1; fprintf('✓ identity & aliases\n\n');

%% 5. Invalidation matrix (§1.9): setters clear downstream DATA
if have_sym
    fprintf('=== 5: Invalidation matrix ===\n');
    v = dspm_reservoir(40, n_recurrent_inputs=2, decompile="eager", ...
                       jet_order=1, decompilation_order=2, verbose=false, random_seed=3);
    assert(v.is_decompiled);
    K1 = v.n_monomials;

    v.decompilation_order = v.decompilation_order;        % no-op guard
    assert(v.is_decompiled, 'no-op order set must not clear');

    v.r_star = v.r_star * 0.9;                            % numeric change
    assert(~v.is_decompiled, 'r_star change clears R (eval tier stale)');
    v.decompile(); assert(v.n_monomials == K1, 'basis size unchanged by numerics');

    v.B = v.B * 1.1;                                      % B values
    assert(~v.is_decompiled, 'B change clears R');
    v.decompile();

    v.gamma = v.gamma * 2;                                % γ ⟹ eval tier
    assert(~v.is_decompiled, 'gamma change clears R');
    v.decompile();

    v.decompilation_order = 3;                            % Taylor tier
    assert(~v.is_decompiled && ~v.taylor_cache_valid_, 'order change clears + invalidates cache');
    v.decompile();
    assert(v.n_monomials > K1, 'higher order ⟹ more monomials');
    n_pass = n_pass + 1; fprintf('✓ invalidation matrix\n\n');
else
    fprintf('--- 5 skipped (no Symbolic Toolbox) ---\n\n');
end

%% 6. Declarative factory: all three {r⋆,d⋆} paths + capabilities
fprintf('=== 6: from_matrices ===\n');
N = 30; rng(4);
A  = 0.1 * randn(N);  Bx = 0.05 * randn(N,2);  rs = rand(N,1) - 0.5;

f1 = dspm_reservoir.from_matrices(A=A, B=Bx, r_star=rs, gamma=50);   % derive d
d_ref = atanh(rs) - A*rs - Bx*f1.x_star;
assert(norm(f1.d_star - d_ref, inf) < 1e-10);
assert(all(strcmp({f1.ports.role}, 'external')), 'default port role is external');
assert(f1.capabilities().runnable && ~f1.capabilities().reopenable);

f2 = dspm_reservoir.from_matrices(A=A, B=Bx, d_star=d_ref, gamma=50); % derive r
assert(norm(f2.r_star - rs, inf) < 1e-6, 'fixed-point solve must recover r_star');

f3 = dspm_reservoir.from_matrices(A=A, B=Bx, r_star=rs, d_star=d_ref, gamma=50); % assert-both
assert(norm(f3.d_star - d_ref, inf) == 0);

threw = false;
try
    dspm_reservoir.from_matrices(A=A, B=Bx, r_star=rs, d_star=d_ref + 0.5, gamma=50);
catch ME
    threw = contains(ME.identifier, 'identityViolated');
end
assert(threw, 'violated pair must error');

f4 = dspm_reservoir.from_matrices(A=A, B=Bx, r_star=rs, A0=zeros(N), gamma=50); % provenance
assert(f4.provenance.tier == "full" && f4.capabilities().reopenable);
n_pass = n_pass + 1; fprintf('✓ from_matrices paths\n\n');

%% 7. Bare A_prog runs; simulate guards drive width
fprintf('=== 7: Runnable minimal tuple + drive checks ===\n');
f1.r0 = rs;
[rt, ~] = f1.simulate(50, zeros(2, 50));
assert(all(isfinite(rt(:))));
threw = false;
try, f1.simulate(10, zeros(5, 10)); catch, threw = true; end
assert(threw, 'wrong drive width must error');
[rt2, ~] = f1.simulate(20, [0.1; -0.1]);      % single column = constant drive
assert(all(isfinite(rt2(:))));
n_pass = n_pass + 1; fprintf('✓ minimal runnable + drive-width guard\n\n');

%% 8. Custom matrices & operating points at construction
fprintf('=== 8: Custom construction inputs ===\n');
Bc = 0.3 * (2*rand(35, 2) - 1);  rc = 0.4 * (rand(35,1) - 0.5);
w = dspm_reservoir(35, n_recurrent_inputs=2, read_in_matrix=Bc, r_star=rc, ...
                   verbose=false);
assert(isequal(w.B, Bc) && isequal(w.r_star, rc));
assert(abs(w.B_scale - max(abs(Bc(:)))) < 1e-12, 'B_scale inferred from provided B');
n_pass = n_pass + 1; fprintf('✓ custom matrices honored\n\n');

%% 9. Program-path integration checks (signature + infer)  [symbolic]
if have_sym
    fprintf('=== 9: Signature validation ===\n');
    g = dspm_reservoir(40, n_recurrent_inputs=2, verbose=false, random_seed=5);
    syms x1 x2 x3 real
    threw = false;
    try, g.program([x2; -x1; x3]); catch ME, threw = contains(ME.identifier, 'dimensionMismatch'); end
    assert(threw, 'm̃ mismatch must error with the signature message');
    g.program([x2; -x1]);
    assert(g.is_closed && all([g.ports.bound]));
    n_pass = n_pass + 1; fprintf('✓ signature validation\n\n');
else
    fprintf('--- 9 skipped (no Symbolic Toolbox) ---\n\n');
end

fprintf('=== CONSTRUCTION & VALIDATION: %d sections passed ===\n', n_pass);
