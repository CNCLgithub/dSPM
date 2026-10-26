function rp = pong_run_defaults(runParams)
% PONG_RUN_DEFAULTS  Fill runParams with the values that reproduce the old
% getexpansion/program_rnn generator.
%
%   n                    (required) number of neurons
%   dt                   0.01    RK4 step (old ReservoirTanhB_dc)
%   connectivity         "programmed" | "random"
%   gamma                100     old getexpansion: gam = 100
%   B_scale              0.05    old B = (rand-.5)*.1  -> U(-0.05, 0.05)
%   integrator           "rk4"   gamma*dt = 1: Euler is at its stability edge
%   jet_order            1       positions only (old decomp_poly1_ns)
%   decompilation_order  4       Taylor 'Order' 4 -> total degree <= 3
%                                (old decomp_poly1_ns(...,4)); pong is cubic
%   random_seed          0       0 = use the global stream (old behavior)
%   verbose              false

rp = runParams;
def = struct( ...
    'dt',                  0.01, ...
    'connectivity',        "programmed", ...
    'gamma',               100, ...
    'B_scale',             0.05, ...
    'integrator',          "rk4", ...
    'jet_order',           1, ...
    'decompilation_order', 4, ...
    'random_seed',         0, ...
    'verbose',             false);

f = fieldnames(def);
for i = 1:numel(f)
    if ~isfield(rp, f{i}) || isempty(rp.(f{i}))
        rp.(f{i}) = def.(f{i});
    end
end
rp.connectivity = string(rp.connectivity);
rp.integrator   = string(rp.integrator);

end
