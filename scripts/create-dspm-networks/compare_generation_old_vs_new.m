%% COMPARE_GENERATION_OLD_VS_NEW
% Parity gate for the refactor. Builds the pong reservoir twice on the SAME
% substrate (B, r_star):
%   OLD  getexpansion -> define_symbolic_logic -> sym2deriv -> lsqminnorm
%   NEW  dspm_reservoir.decompile -> define_pong_dynamics -> pong_program_matrix -> compile
% and compares R, P (row by row), W, and a closed-loop trial.
%
% Path (from create-dspm-networks/):
%   addpath(genpath('..'))                               % this project
%   addpath('/path/to/dspm-reservoir-matlab/core')       % package core ONLY
% Do not genpath the package: archive/ and verify/helpers/ contain
% gen_basis, sym2deriv, decomp_poly1_ns, tanh_deriv variants that would
% shadow the ones in ../dependencies.

clear; clc; close all
N   = 300;          % small for speed; parity does not depend on N
gam = 100;
dt  = 0.01;
m   = 13;
rng(1);

board_params = getGameBoardParamerters();   % paddle on: old logic has no fold

B  = (rand(N, m) - .5) * .1;     % old getexpansion distribution
rs =  rand(N, 1) - .5;

%% ===================== OLD =====================
fprintf('--- OLD generator ---\n'); t = tic;
old = ReservoirTanhB_dc(sparse(N, N), B, rs, zeros(m, 1), dt, gam);
old.r = rs;

% getexpansion body with fixed B, rs
dv        = old.A*rs + old.B*zeros(m,1) + old.d;
[Pd1, C1] = decomp_poly1_ns(old.A, old.B, rs, dv, 4);
[Pdx,Pdy] = find((sum(Pd1,2) + sum(Pd1,2)') <= max(sum(Pd1,2)));
PdS       = zeros(size(Pd1,1));
for i = 1:length(Pdx)
    PdS(Pdx(i),Pdy(i)) = find(sum(Pd1 == (Pd1(Pdx(i),:) + Pd1(Pdy(i),:)), 2) == m);
end
Aa = zeros(size(C1));
Aa(:, (1:m)+1) = Aa(:, (1:m)+1) + old.B;  Aa(:,1) = Aa(:,1) + old.d;
R_old = gen_basis(Aa, PdS);
t_old_decomp = toc(t);

% solve_readout body (so O is visible)
old_ok = true;
try
    [xs_old, dx_old] = define_symbolic_logic(board_params);
    nvars  = numel(unique(regexp(char(dx_old), 'x\d+\(t\)', 'match')));
    pr     = primes(2000)'; pr = pr(1:m);
    [~, DXC] = sym2deriv(dx_old, xs_old(1:nvars), pr, Pd1, PdS);
    O_old  = zeros(m, size(Pd1,1)); O_old(:, (1:m)+1) = eye(m);
    O_old  = O_old + DXC/gam;
    W_old  = lsqminnorm(R_old', O_old')';
catch ME
    old_ok = false;
    fprintf(2, 'OLD compile failed: %s\n', ME.message);
end
fprintf('old: decompile %.2f s, total %.2f s, %d monomials\n', t_old_decomp, toc(t), size(Pd1,1));

%% ===================== NEW =====================
fprintf('\n--- NEW generator ---\n'); t = tic;
res = dspm_reservoir(N, ...
    ports = [repmat("rec",1,12) "ext"], gamma = gam, dt = dt, integrator = "rk4", ...
    jet_order = 1, decompilation_order = 4, ...
    read_in_matrix = B, r_star = rs, verbose = false);
res.decompile();
t_new_decomp = toc(t);

[dx_new, xs_new, info] = define_pong_dynamics(board_params);
P_new = pong_program_matrix(res, dx_new, xs_new);
[~, ~, st] = res.compile(P_new);
res.close_loop();

R_new = res.decompiled_weight_matrix;
E_new = table2array(removevars(res.symbolic_basis_mapping, 'Physical'));
Pp    = double(all(E_new == [zeros(1,12) 1], 2))';
W_new = [res.W; lsqminnorm(R_new', Pp')'];
fprintf('new: decompile %.2f s, total %.2f s, %d monomials, compile rel err %.2e\n', ...
    t_new_decomp, toc(t), size(E_new,1), st.rel_error);

%% ===================== COMPARE =====================
fprintf('\n--- Parity ---\n');
rel = @(a, b) norm(a - b, 'fro') / max(norm(b, 'fro'), eps);

assert(isequal(size(E_new,1), size(Pd1,1)), 'basis sizes differ: %d vs %d', size(E_new,1), size(Pd1,1));
[tf, loc] = ismember(E_new, Pd1, 'rows');
assert(all(tf), 'new basis contains monomials the old one lacks');

fprintf('identity d       : %.2e\n', norm(res.d_star - old.d, inf));
fprintf('R  (aligned)     : %.2e\n', rel(R_new, R_old(:, loc)));

if old_ok
    O_al = O_old(:, loc);
    fprintf('P rows (new vs old, relative):\n');
    for i = 1:12
        d = rel(P_new(i,:), O_al(i,:));
        flag = ""; if d > 1e-8, flag = "   <-- differs"; end
        fprintf('  %2d %-7s %.2e%s\n', i, info.names(i), d, flag);
    end
    fprintf('  13 paddle  %.2e  (old row 13 vs e13)\n', rel(Pp, O_al(13,:)));
    fprintf('W (13 rows)      : %.2e\n', rel(W_new, W_old));
end

%% ===================== CLOSED-LOOP TRIAL =====================
% One trial, run_rnn_trials conventions, full-rank integration.
T  = 3000;
x0 = 0; y0 = 0.02; vx = 0.2; vy = -0.15;
c  = [abs(vx); abs(vy); x0; y0; ...
      sign(vx)*0.1; -sign(vx)*0.1; sign(vy)*0.1; -sign(vy)*0.1; ...
      0; 0; 0; 0; 0];

% new: condition (open loop, 199 steps like basernn.train(...,200,...)) + simulate
res.condition(c(1:12), c(13), 199);
[r_new, ~] = res.simulate(T, zeros(1, T));
ball_new   = W_new(3:4, :) * r_new;

figure('Name', 'pong generation parity'); hold on; axis equal
plot(board_params.plot_wall_x, board_params.plot_wall_y, 'k-', 'LineWidth', 3)
plot(ball_new(1,:), ball_new(2,:), '-', 'LineWidth', 1.5, 'DisplayName', 'new')

if old_ok
    base = ReservoirTanhB_dc(sparse(N,N), B, rs, zeros(m,1), dt, gam); base.r = rs;
    st_init = base.train(repmat(c, [1, 200, 4]));
    prnn = ReservoirTanhB_dc(B(:,1:12)*W_old(1:12,:), B(:,13), rs, 0, dt, gam);
    prnn.d = base.d;
    prnn.r = st_init(:, end);
    r_old  = prnn.train(repmat(zeros(1, T+1), [1, 1, 4]));
    r_old  = r_old(:, 2:end);                     % align: simulate records post-step
    ball_old = W_old(3:4, :) * r_old;
    plot(ball_old(1,:), ball_old(2,:), '--', 'LineWidth', 1.5, 'DisplayName', 'old')

    fprintf('\nconditioned r0   : %.2e\n', norm(res.r0 - st_init(:,end), inf));
    fprintf('trajectory |dr|  : max %.2e\n', max(abs(r_new - r_old), [], 'all'));
    fprintf('ball |d(x,y)|    : max %.2e\n', max(abs(ball_new - ball_old), [], 'all'));
end
legend show; title('ball trajectory, W(3:4,:) r')
