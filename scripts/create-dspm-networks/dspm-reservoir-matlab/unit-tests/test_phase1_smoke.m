%% PHASE 1 SMOKE TEST — new dspm_reservoir core
%  Fast end-to-end exercise of the refactored object. Run after addpath('core').
clear; clc;
fprintf('=== Phase 1 smoke test ===\n');

%% 1. Lazy generative construction (ms — no symbolic work)
t0 = tic;
res = dspm_reservoir(60, ports=["rec","rec"], gamma=100, dt=0.01, ...
                     random_seed=7, verbose=false);
t_construct = toc(t0);
assert(t_construct < 1.0, 'constructor should be fast (lazy decompile)');
assert(res.n_recurrent_inputs == 2 && res.n_inputs == 2);
assert(~res.is_decompiled, 'should NOT be decompiled yet (lazy)');
assert(res.is_initialized,  'should be initialized (B, r_star, ports)');
c = res.capabilities();
assert(c.programmable && ~c.runnable && ~c.composable_source);
fprintf('✓ lazy construction (%.3f s), status derived correctly\n', t_construct);

%% 2. Identity invariant at birth
d_ref = atanh(res.r_star) - res.B * res.x_star;
assert(norm(res.d_star - d_ref, inf) < 1e-12, 'identity violated at construction');
assert(norm(res.bias - res.d_star, inf) == 0, 'bias alias must equal d_star');
fprintf('✓ fixed-point identity holds; bias≡d_star alias intact\n');

%% 3. One-verb program (decompile + compile + close)
syms x1 x2 real
res.program([x2; -x1]);                       % simple harmonic oscillator
assert(res.is_decompiled && res.is_compiled && res.is_closed);
assert(all([res.ports.bound]), 'recurrent ports should be bound after closure');
assert(res.live_input_width == 0);
fprintf('✓ program() ran decompile→P→W→close; ports retired\n');

%% 4. Explicit close_loop() is idempotent after program()
A1 = res.A;
res.close_loop();
assert(norm(res.A - A1, 'fro') < 1e-12, 'close_loop must be idempotent');
fprintf('✓ close_loop idempotent\n');

%% 5. Condition via provenance (no flag toggling), then simulate
res.condition([1; 0]);
assert(res.is_conditioned && res.ready_to_run);
[r_traj, y_traj] = res.simulate(500);
assert(all(isfinite(r_traj(:))) && all(isfinite(y_traj(:))));
assert(size(y_traj, 1) == 2);
fprintf('✓ condition + simulate produce finite trajectories\n');

%% 6. Reopen from provenance
res.reopen();
assert(~res.is_closed && ~any([res.ports.bound]));
res.close_loop();                              % re-close from retained W
assert(res.is_closed);
fprintf('✓ reopen()/re-close round-trip via provenance\n');

%% 7. Invalidation clears data (no flags to lie)
res.gamma = res.gamma;                         %#ok<*NASGU> % no-op keeps artifacts
res.jet_order = res.jet_order;                 % no-op guard
assert(res.is_decompiled, 'no-op sets must not invalidate');
res.decompilation_order = res.decompilation_order + 1;
assert(~res.is_decompiled && ~res.is_compiled && ~res.is_closed, ...
    'order change must clear R, W, A');
fprintf('✓ setters clear downstream data; no-op sets preserved\n');

%% 8. Declarative factory: give r⋆, derive d⋆
N = 40; rng(1);
A_prog = 0.1 * randn(N);  Bx = 0.05 * randn(N, 2);  rs = rand(N,1) - 0.5;
dec = dspm_reservoir.from_matrices(A=A_prog, B=Bx, ports=["ext","ext"], ...
                                   r_star=rs, gamma=50, dt=0.01);
d_ref = atanh(rs) - A_prog * rs - Bx * dec.x_star;
assert(norm(dec.d_star - d_ref, inf) < 1e-10, 'declarative identity (derive d)');
assert(dec.capabilities().runnable && ~dec.capabilities().reopenable);
dec.r0 = rs;  [rt, ~] = dec.simulate(100);
assert(all(isfinite(rt(:))));
fprintf('✓ from_matrices: r⋆ given → d⋆ derived; runnable, not reopenable\n');

%% 9. Declarative factory: give both — violated pair must error
try
    dspm_reservoir.from_matrices(A=A_prog, B=Bx, ports=["ext","ext"], ...
        r_star=rs, d_star=d_ref + 1, gamma=50);
    error('should have thrown identityViolated');
catch ME
    assert(contains(ME.identifier, 'identityViolated'), ME.message);
end
fprintf('✓ from_matrices: inconsistent {r⋆,d⋆} pair rejected\n');

%% 10. ports="infer": m̃ provisioned by the program signature
res2 = dspm_reservoir(50, ports="infer", gamma=100, verbose=false, random_seed=3);
syms x1 x2 x3 real
res2.program([x2; x3; -x1 - x2 - x3]);
assert(res2.n_recurrent_inputs == 3, 'infer mode must provision m̃ = 3');
fprintf('✓ ports="infer" provisions m̃ from program(dx)\n');

%% 11. Arbitrary symbolic variable names in dx (name-agnostic decode)
res3 = dspm_reservoir(50, ports=["rec","rec"], gamma=100, verbose=false, random_seed=5);
syms u v real
res3.program([v; -u]);                         % u→x1, v→x2 (symvar order), SHO
res3.condition([1; 0]);
[~, y3] = res3.simulate(300);
assert(all(isfinite(y3(:))), 'named-variable program must simulate finitely');
res3b = dspm_reservoir(50, ports=["rec","rec"], gamma=100, verbose=false, random_seed=5);
syms omega theta real
res3b.program([omega; -theta], vars=[theta; omega]);  % explicit slot order
fprintf('✓ arbitrary variable names (auto + explicit vars=) accepted\n');

%% 12. Symbolic constants substituted from constants=struct(...)
res4 = dspm_reservoir(50, ports=["rec","rec"], gamma=100, verbose=false, random_seed=6);
syms p1 p2 alpha real
res4.program([p2; -alpha*p1], constants=struct('alpha', 2.5), vars=[p1; p2]);
fprintf('✓ symbolic constants substituted before compilation\n');

fprintf('\n=== ALL PHASE 1 SMOKE TESTS PASSED ===\n');
