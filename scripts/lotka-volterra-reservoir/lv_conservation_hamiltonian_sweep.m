%% LV_HAMILTONIAN_CONSERVATION_SWEEP
% How well does a programmed reservoir conserve the Lotka-Volterra Hamiltonian,
% and what sets the limit? Supports the conservation tolerance quoted in the
% Lotka-Volterra supplementary section. No figure from this script is in the paper.
%
% Three things are measured on the supplementary figure's system and orbits:
%
%   (1) FLOOR.     The Lotka-Volterra equations integrated directly with RK4 at
%                  the same step: the best any RK4 run at this step can do.
%   (2) SWEEP.     The programmed reservoir over a range of input scales
%                  (B_scale), several random reservoirs each.
%   (3) STEP TEST. Every reservoir is rerun at half the step (same random
%                  matrices, same total time). A ~16x drop means the error is
%                  the integrator's (RK4 is 4th order); no change means it is not.
%
% What it shows: the deviation is a V in B_scale. On the right it is set by the
% truncation of the expansion and falls steeply as the input scale shrinks. On
% the left it rises again as the readout meets the limits of double precision.
% The integrator is never the limit (the step test changes nothing).
%
%   Section 1  settings
%   Section 2  floor: direct RK4 integration
%   Section 3  sweep: reservoirs over B_scale, seeds, and the two steps
%   Section 4  summary table
%   Section 5  figure
%
% Run in a clean workspace (clear).

%% 1. Settings

% Lotka-Volterra rate constants:  du/dt = ka*u - kb*u*v ,  dv/dt = -kc*v + kd*u*v
ka = 1.1;   kb = 0.4;
kc = 0.4;   kd = 0.1;

% orbits: prey fixed, predator varied (same as the supplementary figure)
u0      = 10;
v0_list = [15 12 10 7 5 2 1];

% reservoir (same as the supplementary figure, except B_scale is swept)
n      = 100;                % units
gam    = 100;                % reservoir rate constant
order  = 6;                  % expansion (decompilation) order
dt     = 0.01;               % integration step of the figure
Tsim   = 20000;              % steps per orbit at step dt  (total time = Tsim*dt)

s      = 10;                 % state scale: the reservoir is programmed in x/s, so populations are O(1).
                             % The reservoir's drive depends only on B_scale*s (figure: 0.001*1 = 0.01),
                             % but the monomial columns of R scale as B_scale^k, so a larger B_scale with
                             % a rescaled state keeps every order of the expansion above double precision.
B_list = [0.02 0.01 0.005 0.002 0.001 0.0005]; % input scales to sweep (B_scale*s = 0.01 matches the figure's drive)

% WHY EQUILIBRATE.  compile() solves W*R = P, one equation per monomial. The
% column of R for a degree-k monomial has norm ~ B_scale^k, so at small input
% scales the high-order columns are 10 or more orders of magnitude shorter than
% the linear ones. lsqminnorm judges which columns exist by comparing them with
% the largest, treats the short ones as zero, and drops their equations. W is
% then unconstrained along those directions and high-order terms leak into the
% readout (rank(R) reads 15 or 10 of 21 and the deviation jumps tenfold).
% Equilibrating divides each column of R, and the matching column of P, by the
% column's norm. The equations, and so the exact solution, are unchanged; the
% solver now keeps every order of the expansion at every input scale.
equilibrate = true;

seeds  = 1:5;                                  % random reservoirs per input scale
dt_div = [1 2];                                % step = dt ./ dt_div  (1: figure's step, 2: half)

%% 2. Floor: direct RK4 integration of the Lotka-Volterra equations

f = @(z) [ ka*z(1) - kb*z(1)*z(2); ...
          -kc*z(2) + kd*z(1)*z(2) ];
H = @(u, v) kd*u - kc*log(u) + kb*v - ka*log(v);     % conserved quantity

nOrb = numel(v0_list);
nDt  = numel(dt_div);
H0   = arrayfun(@(v) H(u0, v), v0_list);             % exact value on each orbit

floor_dev  = zeros(nDt, nOrb);                       % max |H - H0| / |H0|, direct integration
period_ref = zeros(1, nOrb);                         % orbital period, for the time-base check

for j = 1:nDt
    h  = dt / dt_div(j);
    nT = Tsim * dt_div(j);
    for k = 1:nOrb
        z  = zeros(2, nT + 1);   z(:, 1) = [u0; v0_list(k)];
        for t = 1:nT
            k1 = f(z(:, t));
            k2 = f(z(:, t) + h/2 * k1);
            k3 = f(z(:, t) + h/2 * k2);
            k4 = f(z(:, t) + h   * k3);
            z(:, t+1) = z(:, t) + h/6 * (k1 + 2*k2 + 2*k3 + k4);
        end
        Hz = H(z(1, :), z(2, :));
        floor_dev(j, k) = max(abs(Hz - Hz(1))) / abs(H0(k));
        if j == 1, period_ref(k) = orbit_period(z(1, :), h); end
    end
end

fprintf('\nDIRECT RK4 (floor), worst orbit:  step %.4g -> %.2e    step %.4g -> %.2e\n', ...
        dt, max(floor_dev(1, :)), dt/dt_div(end), max(floor_dev(end, :)));

%% 3. Sweep: programmed reservoirs

syms x [2, 1] real
dx = [ ka*x(1) - kb*s*x(1)*x(2); ...          % the same system written in x/s
      -kc*x(2) + kd*s*x(1)*x(2) ];

nB = numel(B_list);   nS = numel(seeds);

% one job = one reservoir build (input scale, seed, step); 
% jobs are independent, so parfor
[jB, jS, jD] = ndgrid(1:nB, 1:nS, 1:nDt);
nJob = numel(jB);

dev_q    = nan(nJob, nOrb);   grow_q = nan(nJob, nOrb);   start_q = nan(nJob, nOrb);
period_q = nan(nJob, nOrb);   rank_q = nan(nJob, 1);

parfor q = 1:nJob
    h  = dt / dt_div(jD(q));
    nT = Tsim * dt_div(jD(q));

    resLV = dspm_reservoir( ...
        "n_neurons",           n, ...
        "n_recurrent_inputs",  2, ...
        "n_external_inputs",   0, ...
        "decompilation_order", order, ...
        "B_scale",             B_list(jB(q)), ...
        "jet_order",           1, ...
        "dt",                  h, ...
        "gamma",               gam, ...
        "integrator",          "rk4", ...
        "random_seed",         seeds(jS(q)), ...
        "verbose",             false);
    resLV.equilibrate = equilibrate;  % must be set before program()
    stats     = resLV.program(dx);    % decompile, solve for W, close the loop
    rank_q(q) = stats.rank_R;         % rank of the matrix actually solved

    dev_k = nan(1, nOrb);   grow_k = nan(1, nOrb);   start_k = nan(1, nOrb);   per_k = nan(1, nOrb);
    for k = 1:nOrb
        resLV.condition([u0; v0_list(k)] / s, [], 100);
        [~, y] = resLV.simulate(nT);   y = s * y;        % back to populations
        Hy   = H(y(1, 1:end-1), y(2, 1:end-1));
        dH   = abs(Hy - Hy(1)) / abs(H0(k));
        half = floor(numel(dH) / 2);

        dev_k(k)   = max(dH);
        grow_k(k)  = max(dH(half+1:end)) / max(dH(1:half));
        start_k(k) = abs(Hy(1) - H0(k)) / abs(H0(k));
        per_k(k)   = orbit_period(y(1, 1:end-1), h);
    end
    dev_q(q, :) = dev_k;   grow_q(q, :) = grow_k;   start_q(q, :) = start_k;   period_q(q, :) = per_k;

    fprintf('B_scale %-7g seed %d step %-6.4g  worst orbit: %.2e\n', ...
            B_list(jB(q)), seeds(jS(q)), h, max(dev_k));
end

% back to (input scale, seed, step, orbit); 
% ndgrid order makes this a plain reshape
dev       = reshape(dev_q,    nB, nS, nDt, nOrb);
growth    = reshape(grow_q,   nB, nS, nDt, nOrb);
start_err = reshape(start_q,  nB, nS, nDt, nOrb);
period    = reshape(period_q, nB, nS, nDt, nOrb);   period = reshape(period(:, :, 1, :), nB, nS, nOrb);
rankR     = reshape(rank_q,   nB, nS, nDt);         rankR  = rankR(:, :, 1);

save('lv_hamiltonian_conservation_sweep.mat', 's', 'equilibrate', 'B_list', 'seeds', 'dt', 'dt_div', 'v0_list', 'H0', ...
     'floor_dev', 'dev', 'growth', 'start_err', 'period', 'period_ref', 'rankR');

%% 4. Summary

worst      = max(dev, [], 4);                        % worst orbit: nB x nS x nDt
worst_med  = squeeze(median(worst, 2));              % median over reservoirs: nB x nDt
worst_min  = squeeze(min(worst, [], 2));
worst_max  = squeeze(max(worst, [], 2));
step_gain  = worst_med(:, 1) ./ worst_med(:, end);   % ~16 integrator-limited, ~1 expansion-limited
over_floor = worst_med(:, 1) ./ max(floor_dev(1, :));
growth_med = median(reshape(growth(:, :, 1, :), nB, []), 2);
period_err = max(reshape(abs(period ./ reshape(period_ref, 1, 1, []) - 1), nB, []), [], 2);

fprintf('\nWorst-orbit relative deviation of H over %g time units (%d reservoirs per row)\n', Tsim*dt, nS);
disp(table(B_list(:), median(rankR, 2), worst_med(:, 1), worst_min(:, 1), worst_max(:, 1), ...
           worst_med(:, end), step_gain, over_floor, growth_med, period_err, ...
     'VariableNames', {'B_scale', 'rank_R', 'median', 'min', 'max', ...
                       'median_half_step', 'gain_from_half_step', 'ratio_to_floor', ...
                       'growth_2nd_vs_1st_half', 'period_error'}))

fprintf(['Reading the table:\n' ...
         '  gain_from_half_step ~16 : error set by the integrator (4th-order RK4)\n' ...
         '  gain_from_half_step ~1  : error not set by the integrator (expansion or precision)\n' ...
         '  ratio_to_floor ~1       : reservoir matches direct RK4 integration of the equations\n' ...
         '  growth ~1 bounded, ~2 linear drift;  period_error = time-base check against direct integration\n\n']);

[best, iBest] = min(worst_med(:, 1));
fprintf('Smallest deviation: %.1e at B_scale = %g  (%.1fx the direct-RK4 floor of %.1e; half-step gain %.1fx)\n', ...
        best, B_list(iBest), over_floor(iBest), max(floor_dev(1, :)), step_gain(iBest));
if over_floor(iBest) < 3
    fprintf('  -> supports: "conserved to the accuracy of the integrator itself"\n');
elseif step_gain(iBest) > 8
    fprintf('  -> integrator-limited, but above direct RK4 (reservoir is stiffer: gamma*dt = %g). Say "limited by the integration step".\n', gam*dt);
else
    fprintf('  -> not integrator-limited: the minimum is where expansion error meets double precision.\n');
end

%% 5. Figure

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 14 11]);
hold on
col = [0.20 0.40 0.65;  0.80 0.45 0.10];
for j = [1 nDt]
    c = col(1 + (j > 1), :);
    for iS = 1:nS
        plot(B_list, worst(:, iS, j), '-', 'Color', [c 0.3], 'LineWidth', 0.75, 'HandleVisibility', 'off');
    end
    plot(B_list, worst_med(:, j), '-o', 'Color', c, 'MarkerFaceColor', c, 'LineWidth', 2, ...
         'DisplayName', sprintf('reservoir, step %.4g', dt/dt_div(j)));
    yline(max(floor_dev(j, :)), '--', 'Color', c, 'LineWidth', 1.25, ...
          'DisplayName', sprintf('direct RK4, step %.4g', dt/dt_div(j)));
end
set(gca, 'XScale', 'log', 'YScale', 'log');   grid on
xlabel('Input scale (B\_scale)');
ylabel('max |H - H_0| / |H_0|, largest orbit');
title('Hamiltonian conservation against input scale');
legend('Location', 'northwest', 'Box', 'off');

%% Local function

function T = orbit_period(u, h)
% Mean time between upward crossings of the trace through its own mean.
    s  = u - mean(u);
    i  = find(s(1:end-1) < 0 & s(2:end) >= 0);
    tc = (i - s(i) ./ (s(i+1) - s(i))) * h;          % linear interpolation of each crossing
    if numel(tc) > 1, T = mean(diff(tc)); else, T = NaN; end
end