function [basernn, res, gen] = program_rnn(runParams, board_params, symcache)
% PROGRAM_RNN  Build one programmed pong reservoir with dspm_reservoir.
%
%   basernn            = program_rnn(runParams, board_params)
%   [basernn, res, gen] = program_rnn(runParams, board_params, symcache)
%
% Replaces the getexpansion -> solve_readout pipeline:
%
%   old                                   new
%   ------------------------------------  --------------------------------------
%   define_symbolic_logic (13 eqns,       define_pong_dynamics (12 eqns,
%     symfuns, dx(13)=0)                    plain syms, x13 = ext port)
%   getexpansion: random B, rs, d;        dspm_reservoir(N, ports=12 rec + 1 ext)
%     decomp_poly1_ns + gen_basis           .decompile()  (jet 1, order 4)
%   solve_readout: sym2deriv + lsqminnorm pong_program_matrix + res.compile(P)
%   (closure done later in run_rnn_trials) res.close_loop()
%
% Outputs
%   basernn  ReservoirTanhB_dc, open-loop, W is 13 x N. Drop-in for
%            run_rnn_trials / prnnvars (unchanged).
%   res      the dspm_reservoir, closed, 12 rec ports bound, paddle port live
%   gen      struct: compile stats, program report, W_paddle, timings
%
% symcache (optional) from pong_symbolic_cache(runParams). Without it every
% call pays the full symbolic expansion.

if nargin < 3, symcache = []; end
rp = pong_run_defaults(runParams);

if rp.verbose, disp('Making RNN'), end
t0 = tic;

[dx, xv, info] = define_pong_dynamics(board_params);

% ---- substrate -----------------------------------------------------------
res = dspm_reservoir(rp.n, ...
    ports               = info.roles, ...
    port_names          = info.names, ...
    gamma               = rp.gamma, ...
    dt                  = rp.dt, ...
    integrator          = rp.integrator, ...
    B_scale             = rp.B_scale, ...
    jet_order           = rp.jet_order, ...
    decompilation_order = rp.decompilation_order, ...
    random_seed         = rp.random_seed, ...
    decompile           = "lazy", ...
    verbose             = rp.verbose);

if ~isempty(symcache)
    graft_symbolic_cache(res, symcache);
end

% ---- decompile -----------------------------------------------------------
res.decompile();

% ---- program: P, W, closure ---------------------------------------------
[P, gen.program_report] = pong_program_matrix(res, dx, xv);

if gen.program_report.max_basis_degree < info.max_degree
    error('program_rnn:basisDegree', ...
        'Basis reaches degree %d but the pong dynamics are degree %d.', ...
        gen.program_report.max_basis_degree, info.max_degree);
end

[~, ~, gen.compile_stats] = res.compile(P);
res.close_loop();

% ---- paddle passthrough readout (old W row 13: target e13, since dx13 = 0)
R  = res.decompiled_weight_matrix;
Pp = zeros(1, size(R, 2));
Pp(pure_position_column(res, info.n_rec + 1)) = 1;
gen.W_paddle = lsqminnorm(R', Pp')';
W_full = [res.W; gen.W_paddle];

% ---- base adjacency ------------------------------------------------------
A_base = [];
if rp.connectivity == "random"
    n = rp.n;
    if rp.random_seed > 0      % constructor re-shuffles the global stream
        rs_ = RandStream('twister', 'Seed', rp.random_seed + 7919);
    else
        rs_ = RandStream.getGlobalStream;
    end
    A_base = (rand(rs_, n) - .5) .* (rand(rs_, n) < .05);
    A_base = sparse(A_base / abs(eigs(A_base, 1, 'largestabs', 'MaxIterations', 1e6))) * .01;
    % Mirror on the new object: live A = B_rec*W + A_base, d unchanged
    % (as in the old code). NOTE: res.close_loop() recomputes A from
    % provenance and would drop A_base again.
    res.A = res.A + A_base;
end

basernn = dspm_to_legacy(res, W_full, A_base);

gen.seconds = toc(t0);
gen.info    = info;
gen.run     = rp;

end

% ========================================================================

function graft_symbolic_cache(res, c)
% Copy tier-1/2 symbolic results into a fresh reservoir. Keys must match.
if c.n_inputs ~= res.n_inputs || c.jet_order ~= res.jet_order ...
        || c.decompilation_order ~= res.decompilation_order
    error('program_rnn:cacheKey', ...
        'symcache was built for (inputs %d, jet %d, order %d); reservoir is (%d, %d, %d).', ...
        c.n_inputs, c.jet_order, c.decompilation_order, ...
        res.n_inputs, res.jet_order, res.decompilation_order);
end
res.symbolic_jet_equation_        = c.symbolic_jet_equation_;
res.jet_cache_valid_              = true;
res.symbolic_taylor_coefficients_ = c.symbolic_taylor_coefficients_;
res.symbolic_taylor_basis_        = c.symbolic_taylor_basis_;
res.taylor_cache_valid_           = true;
end

function col = pure_position_column(res, k)
% Column of R holding the bare monomial x_k.
E = table2array(removevars(res.symbolic_basis_mapping, 'Physical'));
e = zeros(1, size(E, 2)); e(k) = 1;
col = find(all(E == e, 2));
assert(isscalar(col), 'program_rnn: no unique column for x%d', k);
end
