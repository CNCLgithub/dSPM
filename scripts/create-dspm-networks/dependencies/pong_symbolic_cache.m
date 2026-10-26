function cache = pong_symbolic_cache(runParams)
% PONG_SYMBOLIC_CACHE  Run the expensive symbolic tiers once and return them
% as a plain struct that can be broadcast to parfor workers.
%
%   cache = pong_symbolic_cache(runParams)
%
% The jet (tier 1) and Taylor (tier 2) expansions depend only on
% (n_inputs, jet_order, decompilation_order), never on N, B, r_star or
% gamma, so they are computed here on a 2-neuron reservoir and grafted into
% each real network by program_rnn. Only the cheap eval tier runs per
% network.

rp   = pong_run_defaults(runParams);
tmpl = dspm_reservoir(2, ...
    ports               = [repmat("rec", 1, 12) "ext"], ...
    gamma               = rp.gamma, ...
    dt                  = rp.dt, ...
    jet_order           = rp.jet_order, ...
    decompilation_order = rp.decompilation_order, ...
    verbose             = rp.verbose);

t0 = tic;
tmpl.decompile();

cache.n_inputs            = tmpl.n_inputs;
cache.jet_order           = tmpl.jet_order;
cache.decompilation_order = tmpl.decompilation_order;
cache.symbolic_jet_equation_        = tmpl.symbolic_jet_equation_;
cache.symbolic_taylor_coefficients_ = tmpl.symbolic_taylor_coefficients_;
cache.symbolic_taylor_basis_        = tmpl.symbolic_taylor_basis_;
cache.build_seconds = toc(t0);

fprintf('pong_symbolic_cache: %d inputs, jet %d, order %d -> %d monomials (%.1f s)\n', ...
    cache.n_inputs, cache.jet_order, cache.decompilation_order, ...
    tmpl.n_monomials, cache.build_seconds);

end
