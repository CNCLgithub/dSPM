%% The Program Matrix: Encoding Dynamics as Linear Algebra
% In s01, we saw that the DNP formula $P = y + \frac{1}{\gamma}f(y)$ lets us
% compile dynamics into network weights. But that was 1D with a single
% coefficient.
%
% How does P generalize to multi-dimensional systems with *coupling* between
% variables? And what happens when the dynamics are *nonlinear*?
%
% This tutorial answers both questions using the *Lotka-Volterra* predator-prey
% model — a classic 2D nonlinear system.
%
% *Critical lesson*: The reservoir operates near $r^* \approx 0$ where tanh is
% approximately linear. We must *center and scale* our dynamics to work in
% this regime — just like we do for the Lorenz attractor.

%% Setup
clc; close all

%% The Lotka-Volterra Predator-Prey Model
% A classic model from ecology:
%
% * $x$ = prey population (e.g., rabbits)
% * $y$ = predator population (e.g., foxes)
%
% $$\dot{x} = \alpha x - \beta x y$$
%
% $$\dot{y} = \delta x y - \gamma y$$
%
% The system has an equilibrium at:
%
% $$x^* = \frac{\gamma}{\delta}, \quad y^* = \frac{\alpha}{\beta}$$
%
% Around this equilibrium, populations oscillate in limit cycles.

% Original parameters
alpha = 0.5;      % prey birth rate
beta_lv = 0.02;   % predation rate  
delta = 0.01;     % predator efficiency
gamma_lv = 0.5;   % predator death rate

% Equilibrium point
x_star = gamma_lv / delta;   % = 50
y_star = alpha / beta_lv;    % = 25

fprintf('Lotka-Volterra Predator-Prey Model\n');
fprintf('══════════════════════════════════\n');
fprintf('Original equations:\n');
fprintf('  dx/dt = α·x - β·x·y\n');
fprintf('  dy/dt = δ·x·y - γ·y\n\n');
fprintf('Equilibrium: (x*, y*) = (%.0f, %.0f)\n\n', x_star, y_star);

%% The Problem: Operating Point Mismatch
% The reservoir operates near $r^* \approx 0$ where tanh is linear.
% But Lotka-Volterra oscillates around $(50, 25)$ — way outside this regime!
%
% *Solution*: Transform to centered, scaled coordinates:
%
% $$u = \frac{x - x^*}{s}, \quad v = \frac{y - y^*}{s}$$
%
% where $s$ is a scale factor. Now $(u, v) \approx (0, 0)$ at equilibrium,
% and oscillations stay in a reasonable range.

%% Deriving the Scaled Dynamics
% Substituting $x = x^* + s \cdot u$ and $y = y^* + s \cdot v$ into the
% original equations and simplifying (the equilibrium terms cancel!):
%
% $$\dot{u} = -\frac{\beta \gamma}{\delta} v - \beta s \cdot u v$$
%
% $$\dot{v} = \frac{\delta \alpha}{\beta} u + \delta s \cdot u v$$
%
% Let's define the coefficients:

% Scale factor (maps ±s deviation from equilibrium to ±1)
s = 20;

% Linear coefficients (from equilibrium structure)
a_lin = -beta_lv * gamma_lv / delta;   % coefficient of v in u-equation
b_lin = delta * alpha / beta_lv;       % coefficient of u in v-equation

% Nonlinear coefficients  
a_nonlin = -beta_lv * s;               % coefficient of uv in u-equation
b_nonlin = delta * s;                  % coefficient of uv in v-equation

fprintf('Scaled coordinates: u = (x - %.0f)/%.0f, v = (y - %.0f)/%.0f\n', ...
    x_star, s, y_star, s);
fprintf('\nScaled dynamics:\n');
fprintf('  du/dt = %.2f·v + %.3f·u·v\n', a_lin, a_nonlin);
fprintf('  dv/dt = %.2f·u + %.3f·u·v\n\n', b_lin, b_nonlin);

%% Additional Time Scaling
% Like the Lorenz system, we may need to slow down the dynamics to match
% the network timescale. We divide by a factor $\tau$:
%
% $$\dot{u} = \frac{1}{\tau}\left( a_{lin} v + a_{nonlin} u v \right)$$

tau = 2;  % time scale factor (tune this!)

fprintf('With time scaling τ = %.1f:\n', tau);
fprintf('  du/dt = (%.2f·v + %.3f·u·v) / %.1f\n', a_lin, a_nonlin, tau);
fprintf('  dv/dt = (%.2f·u + %.3f·u·v) / %.1f\n\n', b_lin, b_nonlin, tau);

%% Create the Reservoir

gamma_net = 100;  % network timescale

res = dspm_reservoir( ...
    'n_neurons', 500, ...
    'n_recurrent_inputs', 2, ...   % u (scaled prey), v (scaled predator)
    'n_external_inputs', 0, ...
    'gamma', gamma_net, ...
    'dt', 0.01, ...
    'B_scale', 0.2, ...
    'B_sparsity', 1, ...
    'jet_order', 1, ...
    'decompilation_order', 3, ...  % need order 3 for u*v term!
    'decompile', 'eager', ...      % this tutorial builds P by hand, so decompile now
    'verbose', false);

fprintf('Reservoir: %d neurons, γ_net = %.0f\n', res.n_neurons, gamma_net);
fprintf('Basis size: %d monomials\n\n', res.n_monomials);

%% Inspect the Basis

res.printBasis();

idx_u = res.getColumnIndex('x1');       % scaled prey
idx_v = res.getColumnIndex('x2');       % scaled predator
idx_uv = res.getColumnIndex('x1*x2');   % interaction term

fprintf('\nColumn indices:\n');
fprintf('  u (x1)    -> column %d\n', idx_u);
fprintf('  v (x2)    -> column %d\n', idx_v);
fprintf('  u·v (x1*x2) -> column %d\n\n', idx_uv);

%% Build P Matrix by Hand
% Applying the DNP formula $P = y + \frac{1}{\gamma}f(y)$:
%
% *Row 1 (scaled prey):*
% $$P_1 = u + \frac{1}{\gamma \tau}(a_{lin} v + a_{nonlin} u v)$$
%
% *Row 2 (scaled predator):*
% $$P_2 = v + \frac{1}{\gamma \tau}(b_{lin} u + b_{nonlin} u v)$$

P = zeros(2, res.n_monomials);

% Row 1: scaled prey equation
P(1, idx_u) = 1;                                   % identity
P(1, idx_v) = a_lin / (gamma_net * tau);           % linear coupling
P(1, idx_uv) = a_nonlin / (gamma_net * tau);       % nonlinear term

% Row 2: scaled predator equation
P(2, idx_v) = 1;                                   % identity
P(2, idx_u) = b_lin / (gamma_net * tau);           % linear coupling
P(2, idx_uv) = b_nonlin / (gamma_net * tau);       % nonlinear term

fprintf('Program matrix P (non-zero entries):\n');
fprintf('  Row 1 (prey):\n');
fprintf('    P(1, u)   = %.6f  (identity)\n', P(1, idx_u));
fprintf('    P(1, v)   = %.6f  (linear coupling)\n', P(1, idx_v));
fprintf('    P(1, u·v) = %.6f  (predation)\n', P(1, idx_uv));
fprintf('  Row 2 (predator):\n');
fprintf('    P(2, v)   = %.6f  (identity)\n', P(2, idx_v));
fprintf('    P(2, u)   = %.6f  (linear coupling)\n', P(2, idx_u));
fprintf('    P(2, u·v) = %.6f  (eating helps predators)\n\n', P(2, idx_uv));

%% Reading the Dynamics from P
% 
% * $P_{1,v} < 0$: When predators are above equilibrium, prey decreases
% * $P_{2,u} > 0$: When prey are above equilibrium, predators increase
% * $P_{1,uv} < 0$: Predation hurts prey
% * $P_{2,uv} > 0$: Predation helps predators
%
% The signs encode the biology!

%% Compile and Simulate

[residual, rank_R, stats] = res.compile(P);
fprintf('Compilation: residual = %.2e, relative error = %.4f%%\n', ...
    residual, stats.rel_error * 100);

A_tilde = res.close_loop();
fprintf('Loop closed: ||A||_F = %.4f\n\n', norm(A_tilde, 'fro'));

% Initial condition in SCALED coordinates
% Original IC: (40, 10) -> scaled: ((40-50)/20, (10-25)/20) = (-0.5, -0.75)
x0_orig = [40; 10];
u0 = (x0_orig - [x_star; y_star]) / s;

fprintf('Initial condition:\n');
fprintf('  Original: (x, y) = (%.0f, %.0f)\n', x0_orig(1), x0_orig(2));
fprintf('  Scaled:   (u, v) = (%.2f, %.2f)\n\n', u0(1), u0(2));

% Condition the network
res.condition(u0);

% Simulate
T_sim = 100;  % time units (scaled time)
T_steps = round(T_sim / res.dt);
[~, y_sim] = res.simulate(T_steps);
t = (0:T_steps-1) * res.dt;

%% Ground Truth: Scaled System via ode45

% Scaled dynamics ODE
scaled_odefun = @(t, y) [
    (a_lin * y(2) + a_nonlin * y(1) * y(2)) / tau;
    (b_lin * y(1) + b_nonlin * y(1) * y(2)) / tau
];

[t_ode, y_ode] = ode45(scaled_odefun, [0, T_sim], u0, odeset('MaxStep', 0.01));
y_truth = interp1(t_ode, y_ode, t)';

% Compute error
mse = mean(sum((y_sim - y_truth).^2, 1));
fprintf('Simulation: %d steps over %.0f time units\n', T_steps, T_sim);
fprintf('MSE vs ground truth: %.2e\n', mse);

%% Visualization: Scaled Coordinates

figure('Position', [100, 100, 1200, 400]);

% Time series
subplot(1,3,1);
plot(t, y_truth(1,:), 'b-', 'LineWidth', 2, 'DisplayName', 'True u (prey)');
hold on;
plot(t, y_sim(1,:), 'b--', 'LineWidth', 1.5, 'DisplayName', 'Reservoir u');
plot(t, y_truth(2,:), 'r-', 'LineWidth', 2, 'DisplayName', 'True v (pred)');
plot(t, y_sim(2,:), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Reservoir v');
hold off;
xlabel('Time (scaled)'); ylabel('Scaled population');
title('Time Series (Scaled Coordinates)');
legend('Location', 'northeast');
grid on; xlim([0, T_sim]);

% Phase portrait (scaled)
subplot(1,3,2);
plot(y_truth(1,:), y_truth(2,:), 'k-', 'LineWidth', 2, 'DisplayName', 'True');
hold on;
plot(y_sim(1,:), y_sim(2,:), 'm--', 'LineWidth', 1.5, 'DisplayName', 'Reservoir');
plot(u0(1), u0(2), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g', ...
    'DisplayName', 'Start');
plot(0, 0, 'kx', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'Equilibrium');
hold off;
xlabel('u (scaled prey)'); ylabel('v (scaled predator)');
title('Phase Portrait (Scaled)');
legend('Location', 'northeast');
grid on; axis equal;

% Convert back to original coordinates for intuition
x_truth_orig = x_star + s * y_truth(1,:);
y_truth_orig = y_star + s * y_truth(2,:);
x_sim_orig = x_star + s * y_sim(1,:);
y_sim_orig = y_star + s * y_sim(2,:);

subplot(1,3,3);
plot(x_truth_orig, y_truth_orig, 'k-', 'LineWidth', 2, 'DisplayName', 'True');
hold on;
plot(x_sim_orig, y_sim_orig, 'm--', 'LineWidth', 1.5, 'DisplayName', 'Reservoir');
plot(x0_orig(1), x0_orig(2), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g', ...
    'DisplayName', 'Start');
plot(x_star, y_star, 'kx', 'MarkerSize', 12, 'LineWidth', 2, ...
    'DisplayName', 'Equilibrium');
hold off;
xlabel('Prey population'); ylabel('Predator population');
title('Phase Portrait (Original Coordinates)');
legend('Location', 'northeast');
grid on;

sgtitle('s02: Lotka-Volterra with Centered & Scaled Coordinates');

%% The Symbolic Interface
% The |program()| method handles the DNP formula automatically,
% but you must provide the *scaled* dynamics:

res2 = dspm_reservoir( ...
    'n_neurons', 100, ...
    'n_recurrent_inputs', 2, ...
    'n_external_inputs', 0, ...
    'gamma', gamma_net, 'dt', 0.01, ...
    'B_scale', 0.5, 'B_sparsity', 1, ...
    'jet_order', 1, 'decompilation_order', 3, ...
    'verbose', false);

% Symbolic scaled dynamics
syms x1 x2 real  % x1 = u, x2 = v in our notation
dx_scaled = [
    (a_lin * x2 + a_nonlin * x1 * x2) / tau;
    (b_lin * x1 + b_nonlin * x1 * x2) / tau
];

res2.program(dx_scaled);

% Compare
fprintf('\nSymbolic vs hand-coded P:\n');
fprintf('  Norm difference: %.2e\n', norm(P - res2.compiled_program_matrix));

%% Visualize P Matrix Structure

figure('Position', [100, 550, 700, 300]);

% Full P matrix
subplot(1,2,1);
imagesc(P);
colorbar;
colormap(bluewhitered(256));
caxis([-1 1] * max(abs(P(:))) * 1.1);
xlabel('Monomial'); ylabel('Equation');
title('P Matrix (Full)');
xticks(1:res.n_monomials);
xticklabels(res.symbolic_basis_strings);
xtickangle(45);
yticks([1 2]);
yticklabels({'u (prey)', 'v (pred)'});

for i = 1:2
    for j = 1:res.n_monomials
        if abs(P(i,j)) > 1e-8
            text(j, i, sprintf('%.4f', P(i,j)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9);
        end
    end
end

% Relevant columns only
subplot(1,2,2);
P_rel = P(:, [idx_u, idx_v, idx_uv]);
imagesc(P_rel);
colorbar;
colormap(bluewhitered(256));
caxis([-1 1] * max(abs(P(:))) * 1.1);
xlabel('Term'); ylabel('Equation');
title('P Matrix (Key Terms)');
xticks(1:3);
xticklabels({'u', 'v', 'u·v'});
yticks([1 2]);
yticklabels({'prey eq.', 'pred eq.'});

for i = 1:2
    for j = 1:3
        text(j, i, sprintf('%.4f', P_rel(i,j)), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end

sgtitle('s02: Program Matrix Structure');

%% Key Takeaways
%
% *Centering and scaling are essential:*
%
% The reservoir operates near $r^* \approx 0$. If your system has an equilibrium
% far from zero, you must transform coordinates:
%
% $$u = \frac{x - x^*}{s}$$
%
% This is exactly what we do for the Lorenz attractor (the |scv| and |/10| terms).
%
% *Multi-dimensional P structure:*
%
% * Each row encodes one equation
% * Diagonal entries $\approx 1$: identity (state persistence)  
% * Off-diagonal linear: how variables directly affect each other
% * Nonlinear terms: higher-order coupling (requires |decompilation_order >= 3|)
%
% *Signs encode the physics/biology:*
%
% * $P_{1,uv} < 0$: predation hurts prey
% * $P_{2,uv} > 0$: predation helps predators
%
% *Time scaling may be needed:*
%
% The $\tau$ factor aligns program dynamics with network timescale $\gamma$.

%% Experiments to Try
%
% # *Vary $\tau$*: What happens with $\tau = 1$? $\tau = 10$? 
%   How does this affect trajectory tracking?
%
% # *Vary $s$*: Larger $s$ = larger coordinate range. What breaks?
%
% # *Remove |decompilation_order = 3|*: Try order 2. Can you still program
%   the $uv$ term? (Hint: no!)
%
% # *Different initial conditions*: Try starting at equilibrium $(u_0, v_0) = (0, 0)$.

%% Next Tutorial  
% *s03_decompilation_demystified.m* — We've been using the R matrix and
% talking about "monomials in the basis." But where does R come from?
% How does |decompilation_order| determine what terms are available?

%% Helper: Blue-White-Red Colormap
function cmap = bluewhitered(n)
    if nargin < 1, n = 256; end
    half = floor(n/2);
    r1 = linspace(0.2, 1, half)';
    g1 = linspace(0.2, 1, half)';
    b1 = ones(half, 1);
    r2 = ones(n-half, 1);
    g2 = linspace(1, 0.2, n-half)';
    b2 = linspace(1, 0.2, n-half)';
    cmap = [r1, g1, b1; r2, g2, b2];
end
