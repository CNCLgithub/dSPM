%% supp_noise_floor_dimensionality.m
%  Not in the manuscript: an extension of Supplementary Fig. 7 prepared for the
%  review of Fig. 2A. Supplementary Fig. 7 itself is drawn by
%  supp_pr_noise_and_onset.m; its curves are reproduced here in panel A.
%
%  Accounting for DMFC's noise floor in the dimensionality analyses (Fig. 2A-B).
%  DMFC is condition-averaged
%  and carries a noise floor the deterministic models do not. The gap between
%  DMFC and dSPM is examined from both sides:
%    adding noise to dSPM       DMFC-matched noise raises dSPM's PR to DMFC's  [S1]
%    removing noise from DMFC   subtracting a shuffle floor moves DMFC to dSPM [S2-S4]
%
%  Panels
%    A  time-resolved PR (Fig. 2B pipeline): DMFC, DMFC noise-corrected, dSPM,
%       dSPM + DMFC-matched noise, dSPM with signal switched on at 250 ms   [S1, S2]
%    B  noise-corrected cumulative variance of the pooled eigenspectra
%       (Fig. 2A inputs), global shuffle                                    [S3, S4]
%    C  PCs to 80% of above-noise variance under each choice of shuffle and
%       model normalization                                                 [S4]
%
%  Fig. 2B pipeline: PCA on all (condition, time) states (DMFC: active points
%  only), then in each 50 ms bin the PR of the cross-condition covariance of
%  the projected states, using the active conditions, in bins where >= 90% of
%  conditions are active.
%
%  Noise floors
%    S1  per-unit noise SD of DMFC from the cross-condition spread in 0-100 ms
%        (before frontal visual responses), scaled to DMFC's signal-to-noise
%        in 500-1500 ms when added to dSPM.
%    S2  per bin: conditions permuted independently for each neuron (keeps
%        each neuron's variance, removes covariance across neurons), projected
%        on the same PCs; the mean floor spectrum is subtracted and PR is taken
%        over the components above it. The top PCs of the pooled data also
%        favour noise, so this floor removes only part of the noise.
%    S3  pooled spectra: DMFC's eigenspectrum minus the mean shuffled
%        eigenspectrum, over the components before it first falls below the
%        shuffle (K). Two shuffles: global (one permutation of every element;
%        Methods) and within-condition (neurons and time bins permuted
%        separately within each condition; as in eigenspectrum.m). Dropping
%        the components below the floor discards some signal, so this
%        correction errs low for DMFC. Models are deterministic and are
%        normalized over their first nPC components (or over K, as a check).
%
%  Inputs : ../../data/brain_and_rishi_data.mat (brain)
%           data-pca/neural_states_manifold.mat, dspm_1000neurons_states_manifold.mat,
%           nextTP_states_manifold.mat, paddle_states_manifold.mat
%  Outputs: ../../figures/supp_noise_floor_dimensionality.{pdf,png}, printed
%           tables. Run from this folder after setup_paths.

%% ====================== S0  parameters and data ======================
P.nPC         = 35;          % components, as in Fig. 2A-B
P.dt          = 50;
P.ntbins      = 71;
P.thresh_cov  = 0.90;        % report PR where >= 90% of conditions are active
P.noise_bins  = 1:2;         % 0-100 ms: before frontal visual responses; no signal
P.signal_win  = [500 1500];  % window for the signal-to-noise match
P.t_on        = 250;         % ms, gate time for the signal-onset model
P.n_draws     = 5;           % noise draws per dSPM instance
P.max_inst    = 10;          % dSPM instances used for the noise-matched curves
P.nShufBin    = 50;          % per-bin floor permutations
P.nMax        = 200;         % pooled components stored, to find the floor crossing
P.nShufGlobal = 20;          % Methods
P.nShufCond   = 50;          % eigenspectrum.m
rng(7);

if ~exist("brain","var"),        load("../../data/brain_and_rishi_data.mat","brain");               end
if ~exist("brainStates","var"),  load("data-pca/neural_states_manifold.mat","brainStates");          end
if ~exist("dspmStates","var"),   load("data-pca/dspm_1000neurons_states_manifold.mat","dspmStates"); end
if ~exist("nextTPStates","var"), load("data-pca/nextTP_states_manifold.mat","nextTPStates");         end
if ~exist("paddleStates","var"), load("data-pca/paddle_states_manifold.mat","paddleStates");         end

[nU, ~, nC] = size(brainStates);
tvec = (0:P.ntbins-1) * P.dt;

mask_start = find(brain.all_mask(1,:), 1, "first");
mask_cols  = mask_start : (mask_start + P.ntbins - 1);
M.all      = logical(brain.all_mask(:, mask_cols))';     % [ntbins x nC]
M.valid    = mean(M.all, 2) >= P.thresh_cov;
M.min_act  = max(5, round(0.5 * nC));
tmax       = tvec(find(M.valid, 1, "last"));
sig_bins   = tvec >= P.signal_win(1) & tvec <= P.signal_win(2);
early      = tvec <= 100;
late       = tvec >= 500 & M.valid';

nI = min(numel(dspmStates), P.max_inst);
c  = pong_colors();
col.dmfc = c.brain.color;  col.dspm = c.dspm.color;  col.ntp = c.nextTP.color;  col.ponly = c.paddle.color;
col.nz   = [0.75 0.72 0.30];  col.gate = [0.45 0.20 0.60];

%% ====================== S1  DMFC PR and noise-matched dSPM ======================
% per-unit noise SD from the cross-condition spread in the pre-signal bins
Xn   = reshape(brainStates(:, P.noise_bins, :), nU, []);
sd_u = std(Xn, 0, 2);
noise_var_dmfc = mean(sd_u.^2);
Xs   = reshape(brainStates(:, sig_bins, :), nU, []);
snr_dmfc = max(mean(var(Xs, 0, 2)) - noise_var_dmfc, 0) / noise_var_dmfc;
fprintf("S1  DMFC per-unit noise var %.3g, late-window SNR %.2f\n", noise_var_dmfc, snr_dmfc);

[trajB, VB, muB] = pca_traj(brainStates, M.all, P.nPC, true);
pr.dmfc = pr_subset(trajB, M.all, 1:nC, M.min_act);

ramp = 1 ./ (1 + exp(-(tvec - P.t_on) / 25));                % ~100 ms wide switch
pr.clean = nan(nI, P.ntbins);
pr.noisy = nan(nI*P.n_draws, P.ntbins);
pr.gated = nan(nI*P.n_draws, P.ntbins);
for i = 1:nI
    S  = dspmStates{i};  nUd = size(S, 1);
    pr.clean(i, :) = pr_curve(S, M.all, P.nPC, M.min_act, false);

    Ss = reshape(S(:, sig_bins, :), nUd, []);  sig_var = mean(var(Ss, 0, 2));
    shape = sd_u(randi(nU, nUd, 1));  shape = shape / sqrt(mean(shape.^2));   % DMFC heterogeneity
    nsd   = sqrt(sig_var / snr_dmfc) * shape;                                 % matched SNR

    Sm = mean(S, 3);
    Sg = Sm + (S - Sm) .* reshape(ramp, 1, [], 1);           % condition-specific part gated on at t_on
    for d = 1:P.n_draws
        Z = randn(size(S)) .* nsd;  k = (i-1)*P.n_draws + d;
        pr.noisy(k, :) = pr_curve(S + Z,  M.all, P.nPC, M.min_act, false);
        pr.gated(k, :) = pr_curve(Sg + Z, M.all, P.nPC, M.min_act, false);
    end
    fprintf("S1  dSPM instance %d/%d\n", i, nI);
end

%% ====================== S2  DMFC PR with a per-bin noise floor ======================
pr.cor = nan(1, P.ntbins);  nAbove = nan(1, P.ntbins);
rng(43);
for t = find(M.valid)'
    act = find(M.all(t, :));
    if numel(act) < M.min_act, continue; end
    Xt   = squeeze(brainStates(:, t, act));                       % [nU x nAct]
    lam  = bin_eigs(VB' * (Xt - muB));
    lamS = zeros(P.nShufBin, numel(lam));
    for si = 1:P.nShufBin
        [~, ord] = sort(rand(size(Xt)), 2);                       % condition order, per neuron
        Xp = Xt(sub2ind(size(Xt), repmat((1:nU)', 1, numel(act)), ord));
        lamS(si, :) = bin_eigs(VB' * (Xp - muB));
    end
    fl = mean(lamS, 1)';
    k  = find(lam < fl, 1, 'first') - 1;
    if isempty(k), k = numel(lam); end
    nAbove(t) = k;
    if k > 0, pr.cor(t) = prf(lam(1:k) - fl(1:k)); end
end

for f = ["dmfc","cor","clean","noisy","gated"], pr.(f)(:, ~M.valid) = NaN; end

fprintf("\n%-30s  PR 0-100 ms   PR >= 500 ms\n", "Time-resolved PR");
row = @(n, x) fprintf("%-30s  %6.2f        %6.2f\n", n, mean(x(:,early),"all","omitnan"), mean(x(:,late),"all","omitnan"));
row("DMFC (Fig. 2B)", pr.dmfc); row("DMFC, noise-corrected", pr.cor);
row("dSPM", pr.clean); row("dSPM + DMFC-matched noise", pr.noisy); row("dSPM gated + noise", pr.gated);
fprintf("DMFC components above the per-bin floor: %d-%d of %d\n", min(nAbove), max(nAbove), P.nPC);

%% ====================== S3  pooled eigenspectra and shuffles (Fig. 2A inputs) ======================
Xb = reshape(brainStates, nU, [])';
Xb = Xb(M.all(:), :);                                           % [n_active x nU]
pB = pct_spectrum(Xb);

spec = @(SS) cell2mat(cellfun(@(S) top(pct_spectrum(reshape(S, size(S,1), [])'), P.nMax), SS(:), UniformOutput=false));
models = struct('name', {'dSPM','Next TP','Paddle-only'}, ...
                'P',    {spec(dspmStates), spec(nextTPStates), spec(paddleStates)}, ...
                'col',  {col.dspm, col.ntp, col.ponly});       % [instances x nMax], % of total variance

rng(42);
shufG = nan(P.nShufGlobal, P.nMax);
for si = 1:P.nShufGlobal
    shufG(si,:) = top(pct_spectrum(reshape(Xb(randperm(numel(Xb))), size(Xb))), P.nMax);
end
blocks = arrayfun(@(k) brainStates(:, M.all(:,k), k), 1:nC, UniformOutput=false);
shufC  = nan(P.nShufCond, P.nMax);
for si = 1:P.nShufCond
    bs = cellfun(@(b) b(randperm(size(b,1)), randperm(size(b,2))), blocks, UniformOutput=false);
    shufC(si,:) = top(pct_spectrum(cat(2, bs{:})'), P.nMax);
end

%% ====================== S4  noise-corrected cumulative variance ======================
shufs = struct('name', {'global','within-condition'}, 'S', {shufG, shufC});
kto   = @(cv, t) find(cv >= t, 1, 'first');
thr   = [0.5 0.8 0.9];

for s = 1:numel(shufs)
    mu  = mean(shufs(s).S, 1)';
    K   = find(pB(1:P.nMax) < mu, 1, 'first') - 1;
    sig = pB(1:K) - mu(1:K);
    shufs(s).K       = K;
    shufs(s).fracSig = sum(sig);                       % % of DMFC total variance above noise
    shufs(s).cumB    = cumsum(sig)' / sum(sig);
    shufs(s).prB     = prf(sig);
end

res = struct([]);
for s = 1:numel(shufs)
    for norm_to = ["nPC" "K"]
        if norm_to == "nPC", L = P.nPC; else, L = shufs(s).K; end
        r = struct('shuffle', shufs(s).name, 'L', L, 'kto', nan(4, numel(thr), 2), 'pr', nan(4, 2), 'cum', {cell(1, 4)});
        r.kto(1,:,1) = arrayfun(@(t) kto(shufs(s).cumB, t), thr);
        r.pr(1,:)    = [shufs(s).prB 0];
        r.cum{1}     = shufs(s).cumB;
        for m = 1:numel(models)
            Pm  = models(m).P(:, 1:L);  Pm(isnan(Pm)) = 0;      % RNNs have fewer units than nMax
            cum = cumsum(Pm ./ sum(Pm, 2), 2);
            k   = cell2mat(arrayfun(@(t) arrayfun(@(i) kto(cum(i,:), t), (1:size(Pm,1))'), thr, UniformOutput=false));
            p   = arrayfun(@(i) prf(Pm(i,:)), 1:size(Pm,1));
            r.kto(m+1,:,:) = cat(3, mean(k,1), std(k,0,1));
            r.pr(m+1,:)    = [mean(p) std(p)];
            r.cum{m+1}     = cum;
        end
        res = [res r]; %#ok<AGROW>
    end
end

fprintf("\nDMFC: top-%d PCs explain %.1f%% of total variance; models %.1f%% (dSPM), %.1f%% (Next TP), %.1f%% (Paddle-only)\n", ...
    P.nPC, sum(pB(1:P.nPC)), mean(sum(models(1).P(:,1:P.nPC),2)), mean(sum(models(2).P(:,1:P.nPC),2)), mean(sum(models(3).P(:,1:P.nPC),2)));
for s = 1:numel(shufs)
    fprintf("%s shuffle (%d reps): DMFC falls below the shuffle at PC %d; above-noise variance = %.1f%% of total\n", ...
        shufs(s).name, size(shufs(s).S,1), shufs(s).K + 1, shufs(s).fracSig);
end
sysn = ["DMFC" string({models.name})];
for r = res
    fprintf("\n[%s shuffle, models normalized over %d PCs]\n", r.shuffle, r.L);
    fprintf("  %-12s %8s %8s %8s %16s\n", "", "PCs-50%", "PCs-80%", "PCs-90%", "whole-trial PR");
    for i = 1:4
        fprintf("  %-12s %8.1f %8.1f %8.1f %8.2f +/- %.2f\n", sysn(i), r.kto(i,:,1), r.pr(i,1), r.pr(i,2));
    end
end

%% ====================== S5  figure ======================
fig = figure('Color','w','Units','centimeters','Position',[2 2 18 16],'Visible','off');
tl  = tiledlayout(fig, 2, 2, 'TileSpacing','loose', 'Padding','compact');
lab = {'DMFC', col.dmfc; 'dSPM', col.dspm; 'Next TP', col.ntp; 'Paddle-only', col.ponly};

% A  time-resolved PR
ax = nexttile(tl, [1 2]); hold(ax, 'on');
band(ax, tvec, pr.gated, col.gate, '-',  sprintf('dSPM, signal on at %d ms + DMFC-matched noise', P.t_on));
band(ax, tvec, pr.noisy, col.nz,   '--', 'dSPM + DMFC-matched noise');
band(ax, tvec, pr.clean, col.dspm, '-',  'dSPM');
plot(ax, tvec, pr.dmfc, 'o-', 'Color', col.dmfc, 'LineWidth', 2, 'MarkerFaceColor', col.dmfc, 'MarkerSize', 3.5, 'DisplayName', 'DMFC');
plot(ax, tvec, pr.cor,  'o-', 'Color', col.dmfc, 'LineWidth', 1.2, 'MarkerFaceColor', 'w', 'MarkerSize', 3.5, 'DisplayName', 'DMFC, noise floor removed');
xline(ax, P.t_on, '--', 'Color', [.5 .5 .5], 'HandleVisibility', 'off');
xlim(ax, [0 tmax]); ylim(ax, [0 26]);
xlabel(ax, 'Time from trial onset (ms)'); ylabel(ax, 'Participation ratio');
legend(ax, 'Box', 'off', 'FontSize', 7, 'Location', 'northeast');
style(ax, 'A  Time-resolved effective dimensionality');

% B  noise-corrected cumulative variance (global shuffle, models over nPC)
main = res(1);
ax = nexttile(tl); hold(ax, 'on'); X = 20; x = 1:X;
for m = numel(models):-1:1
    Mx = main.cum{m+1}(:, x);
    fill(ax, [x fliplr(x)], [mean(Mx)+std(Mx) fliplr(mean(Mx)-std(Mx))], models(m).col, 'FaceAlpha', .18, 'EdgeColor', 'none');
    plot(ax, x, mean(Mx), '-', 'Color', models(m).col, 'LineWidth', 2);
end
cb = [main.cum{1} ones(1, max(0, X - numel(main.cum{1})))];
plot(ax, x, cb(x), '-o', 'Color', col.dmfc, 'LineWidth', 2, 'MarkerSize', 3, 'MarkerFaceColor', col.dmfc);
yline(ax, 0.8, ':', 'Color', [.6 .6 .6]);
for i = 1:4
    y = 0.42 - 0.08*(i-1);
    plot(ax, [12.6 13.8], [y y], '-', 'Color', lab{i,2}, 'LineWidth', 2);
    text(ax, 14.1, y, lab{i,1}, 'FontSize', 7, 'Color', [.2 .2 .2]);
end
xlim(ax, [1 X]); ylim(ax, [0 1.02]); xticks(ax, [1 5 10 15 20]);
xlabel(ax, 'Principal component'); ylabel(ax, 'Cumulative fraction of above-noise variance');
style(ax, 'B  Noise-corrected cumulative variance');

% C  PCs to 80% under each shuffle and normalization
ax = nexttile(tl); hold(ax, 'on');
mk = {'o','s','^','d'}; off = [-.24 -.08 .08 .24];
vn = strings(1, numel(res));
for v = 1:numel(res)
    r = res(v);
    vn(v) = sprintf('%s shuffle, models over %d PCs', r.shuffle, r.L);
    for g = 1:4
        if g > 1
            errorbar(ax, g + off(v), r.kto(g,2,1), r.kto(g,2,2), 'Color', [.4 .4 .4], 'LineWidth', .8, 'CapSize', 0, 'HandleVisibility', 'off');
        end
        scatter(ax, g + off(v), r.kto(g,2,1), 26, lab{g,2}, mk{v}, 'filled', 'MarkerEdgeColor', [.2 .2 .2], 'LineWidth', .5, 'HandleVisibility', 'off');
    end
    scatter(ax, nan, nan, 26, [.6 .6 .6], mk{v}, 'filled', 'MarkerEdgeColor', [.2 .2 .2]);   % legend proxy
end
xlim(ax, [.4 4.6]); xticks(ax, 1:4); xticklabels(ax, lab(:,1)); ylim(ax, [0 22]);
ylabel(ax, 'PCs to 80% of above-noise variance');
legend(ax, vn, 'Box', 'off', 'FontSize', 6, 'Location', 'northwest');
style(ax, 'C  Robustness to the noise estimate');

outdir = fullfile('..', '..', 'figures');
exportgraphics(fig, fullfile(outdir, 'supp_noise_floor_dimensionality.png'), 'Resolution', 300);
exportgraphics(fig, fullfile(outdir, 'supp_noise_floor_dimensionality.pdf'), 'ContentType', 'vector');

%% ====================== functions ======================
function pr = pr_curve(states, mask, nPC, min_active, use_mask_for_pca)
% Fig. 2B pipeline: global PCA, then PR of the cross-condition covariance of
% the projected states at each bin, active conditions only.
    traj = pca_traj(states, mask, nPC, use_mask_for_pca);
    pr   = pr_subset(traj, mask, 1:size(states,3), min_active);
end

function [traj, coeff, mu] = pca_traj(states, mask, nPC, use_mask)
    [nU, nT, nC] = size(states);
    flat = reshape(states, nU, []);
    if use_mask, flat = flat(:, mask(:)); end
    mu    = mean(flat, 2);
    nPC   = min(nPC, min(nU, size(flat,2)) - 1);
    coeff = pca((flat - mu)', NumComponents=nPC, Centered=false);
    traj  = zeros(nPC, nT, nC);
    for c = 1:nC, traj(:,:,c) = coeff' * (states(:,:,c) - mu); end
end

function pr = pr_subset(traj, mask, idx, min_active)
    nT = size(traj, 2);  pr = nan(1, nT);
    for t = 1:nT
        a = idx(mask(t, idx));
        if numel(a) < min_active, continue; end
        pr(t) = prf(bin_eigs(squeeze(traj(:, t, a))));
    end
end

function lam = bin_eigs(Y)
%BIN_EIGS  Descending covariance eigenvalues of [components x conditions] Y.
    Y   = Y - mean(Y, 2);
    lam = sort(max(eig(Y * Y' / (size(Y, 2) - 1)), 0), 'descend');
end

function p = prf(lam)
    p = sum(lam)^2 / sum(lam.^2);
end

function p = pct_spectrum(X)
%PCT_SPECTRUM  Covariance eigenvalues of [samples x units] X as % of total.
    X   = X(all(isfinite(X), 2), :);
    X   = X - mean(X, 1);
    lam = svd(X, 'econ').^2 / (size(X,1) - 1);
    p   = 100 * lam / sum(lam);
end

function v = top(p, n)
    v = nan(1, n);
    k = min(n, numel(p));
    v(1:k) = p(1:k);
end

function band(ax, t, Mx, col, ls, name)
    mu = mean(Mx, 1, "omitnan"); sd = std(Mx, 0, 1, "omitnan");  ok = ~isnan(mu);
    fill(ax, [t(ok) fliplr(t(ok))], [mu(ok)+sd(ok) fliplr(mu(ok)-sd(ok))], col, FaceAlpha=0.15, EdgeColor="none", HandleVisibility="off");
    plot(ax, t(ok), mu(ok), ls, Color=col, LineWidth=2, DisplayName=name);
end

function style(ax, ttl)
    title(ax, ttl, 'FontWeight','normal', 'HorizontalAlignment','left', 'Units','normalized', 'Position',[0 1.02]);
    ax.Box = 'off'; ax.TickDir = 'out'; ax.YGrid = 'on';
    ax.GridColor = [.85 .85 .85]; ax.GridAlpha = 1; ax.FontSize = 8;
    ax.YMinorGrid = 'off'; ax.XTickLabelRotation = 0;
end
