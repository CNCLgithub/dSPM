%% LV_SUPPLEMENT_FIGURE
% Lotka-Volterra system programmed into a dSPM reservoir: reproduces the
% supplementary figure (prey fixed at x0 = 10, predator initial condition
% varied) and prints the numbers quoted in the supplement.
%
%   Section 1  settings (everything you might change is here)
%   Section 2  build and program the reservoir
%   Section 3  simulate the orbits and evaluate the Hamiltonian
%   Section 4  figure: phase portrait, Hamiltonian, example time series
%   Section 5  spectral properties and conservation, printed
%
% Run this in a clean workspace. It uses a, b, c, d for the rate constants,
% and the Pong analysis scripts use d for the reservoir's bias vector.

%% 1. Settings

% Lotka-Volterra rate constants:  dx1/dt = a*x1 - b*x1*x2 ,  dx2/dt = -c*x2 + d*x1*x2
a = 1.1;   b = 0.4;          % prey: growth rate, predation rate
c = 0.4;   d = 0.1;          % predator: death rate, growth per prey

% initial conditions: prey fixed, predator varied (one orbit each)
x0      = 10;
y0_list = [15 12 10 7 5 2 1];
y0_show = 5;                 % orbit shown in the time-series panel

% reservoir
n       = 100;               % units
m       = 2;                 % programmed variables
gam     = 100;               % reservoir rate constant
dt      = 0.01;              % integration step
B_scale = 0.002;             % scale of the input matrix
order   = 6;                 % expansion (decompilation) order
Tsim    = 20000;             % time steps per orbit
flip_sign = false;            % true: program(-dx), as in the runs so far; false: program(dx)

save_pdf = "";               % e.g. "supplement-s2-LVres.pdf" to export; "" to skip

clc

%% 2. Build and program the reservoir

syms x [m, 1] real
dx = [ a*x(1) - b*x(1)*x(2); ...
      -c*x(2) + d*x(1)*x(2) ];

resLV = dspm_reservoir( ...
    "n_neurons",           n, ...
    "n_recurrent_inputs",  m, ...
    "n_external_inputs",   0, ...
    "decompilation_order", order, ...
    "B_scale",             B_scale, ...
    "jet_order",           1, ...
    "dt",                  dt, ...
    "gamma",               gam, ...
    "integrator",          "rk4");

resLV.decompile();
if flip_sign, resLV.program(-dx); 
else, resLV.program(dx); end

resLV.close_loop();

%% 3. Simulate the orbits and evaluate the Hamiltonian

H    = @(u, v) d*u - c*log(u) + b*v - a*log(v);      % conserved quantity of the target system
nOrb = numel(y0_list);
yt   = cell(nOrb, 1);   Ht = cell(nOrb, 1);

for k = 1:nOrb
    resLV.condition([x0; y0_list(k)], [], 100);      % load the initial condition
    [~, yt{k}] = resLV.simulate(Tsim);               % closed-loop run, read out through W
    Ht{k} = H(yt{k}(1, :), yt{k}(2, :));
end

H0   = arrayfun(@(v) H(x0, v), y0_list);             % exact Hamiltonian of each initial condition
devH = cellfun(@(h) max(abs(h(1:end-1) - h(1))), Ht);   % largest deviation along each orbit

%% 4. Figure

[~, bySize] = sort(H0, 'descend');                   % largest orbit first
cols = parula(nOrb + 1);   cols = cols(1:nOrb, :);   % dark blue (largest) to yellow (smallest)
colOf = zeros(nOrb, 3);    colOf(bySize, :) = cols;  % colour of each orbit, indexed like y0_list

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 32 9]);
tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% A. phase portrait
nexttile; hold on
for k = 1:nOrb
    plot(yt{k}(1, :), yt{k}(2, :), 'Color', colOf(k, :), 'LineWidth', 2, ...
         'DisplayName', sprintf('y_0 = %g', y0_list(k)));
end
xlabel('Prey population');   ylabel('Predator population');
title('A.  Phase portrait');   legend('Location', 'northeast');   grid on

% B. Hamiltonian along each trajectory
nexttile; hold on
for k = 1:nOrb
    plot(Ht{k}(1:end-1), 'Color', colOf(k, :), 'LineWidth', 1.5);
end
ylim([0, max(H0) * 1.08]);                           % tall enough to show every orbit
xlabel('Simulation time step');   ylabel('Hamiltonian (H)');
title({'B.  Hamiltonian conservation', '$H(x,y) = d\,x - c\ln x + b\,y - a\ln y$'}, 'Interpreter', 'latex');

% C. one orbit in the time domain
ks = find(y0_list == y0_show, 1);
nexttile; hold on
plot(yt{ks}(1, :), 'Color', [0.25 0.50 0.70], 'LineWidth', 1, 'DisplayName', 'Prey population');
plot(yt{ks}(2, :), 'Color', [0.55 0.20 0.15], 'LineWidth', 1, 'DisplayName', 'Predator population');
xlabel('Simulation time step');   ylabel('Population');
title(sprintf('C.  Time-domain trajectory, y_0 = %g', y0_show));
legend('Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

sgtitle(sprintf(['Reservoir computer programmed with the Lotka-Volterra system: ' ...
                 'prey initial condition fixed (x_0 = %g), predator initial condition varied'], x0), ...
        'FontSize', 11, 'FontWeight', 'bold');

if strlength(save_pdf) > 0
    exportgraphics(fig, save_pdf, 'ContentType', 'vector');
end

%% 5. Spectral properties and conservation (numbers for the supplement)

Wr = resLV.W;   Br = resLV.B;   rs = resLV.r_star;   Ap = resLV.programmed_adjacency;
sg = 1 - 2 * flip_sign;                              % -1 if -dx was programmed, +1 otherwise

fprintf('\nreservoir: N = %d, B_scale = %g, order = %d, gamma = %g, program(%sdx)\n', ...
        n, B_scale, order, gam, char('-' * flip_sign));

% spectral radius of the programmed adjacency (NOT the Frobenius norm) and its rank
fprintf('rho(Ap) = %.4f    Frobenius norm = %.4f    rank = %d\n', ...
        max(abs(eig(Ap))), norm(Ap, 'fro'), rank(Ap));

% at the analytic operating point r* (the origin of the Lotka-Volterra system)
mu_star = sort(eig(Wr * ((1 - rs.^2) .* Br)));
pred    = sort([1 + sg*a/gam, 1 - sg*c/gam]);
fprintf('at r*:            %s    predicted: %.5f, %.5f\n', mat2str(mu_star.', 6), pred(1), pred(2));

% at the coexistence fixed point (c/d, a/b), which the orbits circle
resLV.condition([c/d; a/b], [], 100);
G     = 1 - tanh(Br * (Wr * resLV.r) + resLV.d_star).^2;
mu_fp = eig(Wr * (G .* Br));
fprintf('at (%.3g, %.3g):  %s    predicted: 1 +/- %.5fi\n', c/d, a/b, mat2str(mu_fp.', 6), sqrt(a*c)/gam);

% Hamiltonian conservation, per orbit
disp(table(y0_list(:), H0(:), devH(:), devH(:) ./ H0(:), ...
     'VariableNames', {'y0', 'H_initial', 'max_abs_deviation', 'relative_deviation'}))
fprintf('largest deviation over all orbits: %.2e (relative %.2e)\n', max(devH), max(devH ./ H0));