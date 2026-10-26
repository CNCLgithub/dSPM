%% ANALYZE_SPECTRAL_DISTRIBUTION
% Distribution of the three spectral measures across the 50 legacy Pong
% reservoirs used in the paper's Results.
%
% For each network (one .mat file each) this computes:
%   1. Raw spectral radius of the programmed adjacency      rho(Ap)
%   2. Spectrum at the analytic operating point r*          diag(1 - r*.^2) * Ap
%   3. Spectrum at each trial's conditional operating point diag(1 - r_i.^2) * Ap
%      for all 79 conditions
% For 2 and 3 it records both the spectral radius (largest modulus) and the
% largest real part. They coincide when the leading eigenvalue is real.
%
% Speed: with A0 = 0 the programmed adjacency has rank ~13, so Ap is
% factorized once per network (Ap = U*S*V') and every spectrum is taken from
% a small k x k matrix with the same nonzero eigenvalues. If Ap is not low
% rank the script falls back to full 1000 x 1000 eigendecompositions.
%
% Requires the legacy classes (prnnvars, ReservoirTanhB_dc) on the path so
% the objects load correctly.

%% 0. Settings

run_dir = fullfile('../../hpc-outputs/programmed-networks', ...
                   '28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b', 'rnn-states');
files   = dir(fullfile(run_dir, 'prnn-states-id*.mat'));
nNet    = numel(files);
fprintf('Found %d network files\n', nNet);

rank_tol   = 1e-8;      % relative singular-value cutoff for the numerical rank
max_lowrnk = 100;       % above this rank, use full eigendecompositions instead

%% 1. Loop over networks

res = struct('netnum', [], 'netid', "", 'rank', [], ...
             'rho_raw', [], ...
             'rho_star', [], 'maxre_star', [], ...
             'rho_cond', [], 'maxre_cond', []);        % last two: 79 x 1 per network
res = repmat(res, nNet, 1);

parfor n = 1:nNet
    a    = load(fullfile(files(n).folder, files(n).name));
    pv   = a.prnn_validation;
    prnn = pv.progrnn.prnn;          % closed-loop (programmed) reservoir
    base = pv.progrnn.basernn;       % open-loop reservoir, used only if states must be rebuilt

    Ap = prnn.A;                     % programmed adjacency (N x N)
    rs = prnn.rs(:);                 % analytic operating point r*
    N  = size(Ap, 1);

    % ---- factorize Ap once -------------------------------------------------
    [U, S, V] = svd(Ap, 'econ');
    s  = diag(S);
    k  = nnz(s > rank_tol * s(1));   % numerical rank
    lowrank = k <= max_lowrnk;
    if lowrank
        Uk = U(:, 1:k);   SVk = S(1:k, 1:k) * V(:, 1:k)';     % Ap = Uk * SVk
        spec = @(g) eig(SVk * (g .* Uk));                      % nonzero eig of diag(g)*Ap
    else
        spec = @(g) eig(g .* Ap);                              % full spectrum
    end

    % ---- 1. raw spectral radius -------------------------------------------
    mu_raw = spec(ones(N, 1));

    % ---- 2. at the analytic operating point r* ----------------------------
    mu_star = spec(1 - rs.^2);

    % ---- 3. at each trial's conditional operating point r_i ---------------
    nCond    = numel(pv.start_states);
    rho_c    = nan(nCond, 1);
    maxre_c  = nan(nCond, 1);
    for c = 1:nCond
        [ri, how] = conditioned_state(pv.start_states{c}, base, rs, N);
        if n == 1 && c == 1
            fprintf('start_states format: %s\n', how);
        end
        mu_c       = spec(1 - ri.^2);
        rho_c(c)   = max(abs(mu_c));
        maxre_c(c) = max(real(mu_c));
    end

    % ---- store -------------------------------------------------------------
    res(n).netnum     = a.netnum;
    res(n).netid      = string(a.netid);
    res(n).rank       = k;
    res(n).rho_raw    = max(abs(mu_raw));
    res(n).rho_star   = max(abs(mu_star));
    res(n).maxre_star = max(real(mu_star));
    res(n).rho_cond   = rho_c;
    res(n).maxre_cond = maxre_c;

    fprintf('net %2d/%d  rank %3d  rho(Ap) %.4g  at r*: %.4f  at r_i (median over %d conds): %.4f\n', ...
            n, nNet, k, res(n).rho_raw, res(n).rho_star, nCond, median(rho_c));
end

%% 2. Summary across networks

rho_raw    = [res.rho_raw]';
rho_star   = [res.rho_star]';
maxre_star = [res.maxre_star]';
rho_cond   = [res.rho_cond];            % nCond x nNet
maxre_cond = [res.maxre_cond];

cond_med = median(rho_cond, 1)';        % per network: median over conditions
cond_max = max(rho_cond, [], 1)';       % per network: worst condition

stat = @(v) [mean(v), std(v), min(v), max(v)];
T = array2table([stat(rho_raw); stat(rho_star); stat(maxre_star); ...
                 stat(cond_med); stat(cond_max); stat(median(maxre_cond, 1)')], ...
    'VariableNames', {'mean', 'sd', 'min', 'max'}, ...
    'RowNames', {'rho(Ap) raw', 'rho at r*', 'max Re at r*', ...
                 'rho at r_i (median over conds)', 'rho at r_i (max over conds)', ...
                 'max Re at r_i (median over conds)'});
disp(T)
fprintf('ranks across networks: min %d, max %d\n', min([res.rank]), max([res.rank]));

%% 3. Figure

figure; tiledlayout(1, 3);
nexttile; histogram(rho_raw);      xlabel('\rho(A_p)');                  ylabel('networks'); title('Raw');
nexttile; histogram(rho_star);     xlabel('\rho at r^*');                title('Analytic operating point');
nexttile; histogram(rho_cond(:));  xlabel('\rho at r_i^*');              title('Conditional operating points (all conds)');

%% 4. Save

out_file = fullfile(run_dir, '..', 'spectral_distribution.mat');
save(out_file, 'res', 'T');
writetable(T, fullfile(run_dir, '..', 'spectral_distribution_summary.csv'), 'WriteRowNames', true);
fprintf('Saved %s\n', out_file);


%% Local function
function [ri, how] = conditioned_state(s, base, rs, N)
% Return the conditional operating point r_i for one condition.
% Handles three possible formats of pv.start_states{c}:
%   (a) the reservoir state itself, N x 1
%   (b) a reservoir trajectory, N x T (the last column is taken as settled)
%   (c) the symbolic starting state x0; r_i is then rebuilt by relaxing the
%       open-loop reservoir from r* with x0 held fixed
    if numel(s) == N
        ri  = s(:);
        how = 'reservoir state (N x 1), used directly';
    elseif size(s, 1) == N
        ri  = s(:, end);
        how = 'reservoir trajectory (N x T), last column used';
    else
        x0 = s(:);
        B  = base.B;
        if size(B, 2) < numel(x0)
            error('start state has %d entries but base.B has %d columns', numel(x0), size(B, 2));
        end
        ri = rs;
        for it = 1:200                              % relax the open-loop reservoir
            ri = tanh(base.A * ri + B(:, 1:numel(x0)) * x0 + base.d);
        end
        how = sprintf('symbolic x0 (%d entries), r_i rebuilt from the open-loop reservoir', numel(x0));
    end
end