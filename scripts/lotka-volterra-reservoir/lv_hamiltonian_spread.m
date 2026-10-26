%% LV_HAMILTONIAN_SPREAD
% Hamiltonian conservation across independent Lotka-Volterra reservoirs.
% Supports the numbers in Supplementary Section 1.10: "H remains within 0.12%
% of its initial value on every orbit in each of 20 reservoirs, with a median
% deviation of 0.03% on the largest orbit".
%
% Same system, orbits and reservoir settings as create_LV_reservoirs.m; only
% the random reservoir (B, r*) changes, one seed per reservoir.
%
%   Section 1  settings
%   Section 2  build, program and simulate each reservoir
%   Section 3  summary
%
% Run from scripts/lotka-volterra-reservoir after setup_paths. Uses a, b, c, d
% for the rate constants, as in create_LV_reservoirs.m.

%% 1. Settings

a = 1.1;   b = 0.4;          % prey: growth rate, predation rate
c = 0.4;   d = 0.1;          % predator: death rate, growth per prey

x0      = 10;
y0_list = [15 12 10 7 5 2 1];

n       = 100;               % units
m       = 2;                 % programmed variables
gam     = 100;               % reservoir rate constant
dt      = 0.01;              % integration step
B_scale = 0.002;             % scale of the input matrix
order   = 6;                 % expansion (decompilation) order
Tsim    = 20000;             % time steps per orbit

equilibrate = false;         % true: unit-norm columns of R before solving for W. At this B_scale,
                             % false leaves rank(R) at 15 of 21 (see lv_conservation_hamiltonian_sweep.m)

nRes    = 20;                % independent reservoirs
seeds   = 1:nRes;            % one random_seed per reservoir

save_file = "lv_hamiltonian_spread.mat";   % "" to skip

%% 2. Build, program and simulate each reservoir

syms x [m, 1] real
dx = [ a*x(1) - b*x(1)*x(2); ...
      -c*x(2) + d*x(1)*x(2) ];

H    = @(u, v) d*u - c*log(u) + b*v - a*log(v);
H0   = arrayfun(@(v) H(x0, v), y0_list);
nOrb = numel(y0_list);

relDev = nan(nRes, nOrb);    % largest |H(t) - H(0)| along each orbit, relative to H0

for s = 1:nRes
    resLV = dspm_reservoir( ...
        "n_neurons",           n, ...
        "n_recurrent_inputs",  m, ...
        "n_external_inputs",   0, ...
        "decompilation_order", order, ...
        "B_scale",             B_scale, ...
        "jet_order",           1, ...
        "dt",                  dt, ...
        "gamma",               gam, ...
        "integrator",          "rk4", ...
        "random_seed",         seeds(s), ...
        "equilibrate",         equilibrate);
    resLV.decompile();
    resLV.program(dx);
    resLV.close_loop();

    for k = 1:nOrb
        resLV.condition([x0; y0_list(k)], [], 100);
        [~, yt] = resLV.simulate(Tsim);
        Ht = H(yt(1, :), yt(2, :));
        relDev(s, k) = max(abs(Ht(1:end-1) - Ht(1))) / H0(k);
    end
    fprintf('reservoir %2d/%d: worst orbit %.3f%%\n', s, nRes, 100*max(relDev(s, :)));
end

%% 3. Summary

[~, kLargest] = max(H0);
disp(table(y0_list(:), H0(:), 100*median(relDev, 1)', 100*max(relDev, [], 1)', ...
     'VariableNames', {'y0', 'H_initial', 'median_pct', 'max_pct'}))
fprintf('largest deviation, all orbits and reservoirs: %.3f%%\n', 100*max(relDev(:)));
fprintf('median deviation on the largest orbit (y0 = %g): %.3f%%\n', ...
        y0_list(kLargest), 100*median(relDev(:, kLargest)));

if strlength(save_file) > 0
    save(save_file, "relDev", "y0_list", "seeds");
end
