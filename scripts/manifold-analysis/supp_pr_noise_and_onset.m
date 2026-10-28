%% supp_pr_noise_and_onset.m
%  Supplementary analysis for Fig. 2B: what the participation ratio (PR) of
%  DMFC reflects, and why its early values are high.
%
%  Supplementary Fig. 7 (Supplementary Section 7) is panel A of the
%  supplementary figure below, with the DMFC, dSPM, 1x matched-noise and gated
%  curves (figures/figures-september-2026/pr-with-noise.png).
%
%  One script, five sections. S1-S3 and S5 feed the two-panel supplementary
%  figure; S4 (bounce / no-bounce split) is a null control that is kept for
%  the record and reported in the text only. A second, diagnostic figure
%  shows all controls. Consolidates pr_noise_matched_test.m,
%  pr_bounce_split.m and dmfc_onset_transient_check.m.
%
%  Claims established:
%   1. PR of trial-averaging noise is HIGH, not low (PR is scale-free; the
%      noise floor for this population is ~24 in 35 PCs).                  [S1]
%   2. dSPM with DMFC-matched noise added throughout stays low-dimensional,
%      because it carries condition-specific signal from t = 0.            [S2]
%   3. dSPM with its signal switched on at 250 ms, same noise, reproduces
%      DMFC's early plateau and collapse. The collapse is signal arriving
%      out of a noise floor, not a change in representational dimension.   [S2]
%   4. DMFC's early PR (16) is below the floor (24): weak condition-specific
%      signal is present before 100 ms. Inverting PR gives the implied
%      signal-to-noise time course.                                        [S3]
%   5. The 300-600 ms rise in PR is a settling of condition-specific
%      variance after an onset overshoot, equal in bounce and no-bounce
%      conditions, matched by a ~10% population rate transient.            [S4, S5]
%
%  Inputs as for eigenspectrum.m:
%    ../../data/brain_and_rishi_data.mat        (brain, rishi_data)
%    data-pca/neural_states_manifold.mat        (brainStates [nU x 71 x 79])
%    data-pca/dspm_1000neurons_states_manifold.mat (dspmStates, cell of [nU x 71 x 79])

%% ====================== S0  parameters and data ======================
P.nPC        = 35;          % components, as in Fig. 2B
P.dt         = 50;
P.ntbins     = 71;
P.thresh_cov = 0.90;        % report PR where >= 90% of conditions are active
P.noise_bins = 1:2;         % 0-100 ms: before frontal visual responses; no signal
P.signal_win = [500 1500];  % window for the signal-to-noise match
P.t_on       = 250;         % ms, gate time for the signal-onset model
P.noise_mult = [1 2];       % noise levels relative to the DMFC match (1x, 2x)
P.n_draws    = 5;           % noise draws per dSPM instance
P.max_inst   = 10;          % dSPM instances used
P.n_sub      = 200;         % no-bounce subsamples (26 of 53) for the class split
rng(7);

if ~exist("rishi_data","var"), load("../../data/brain_and_rishi_data.mat"); end
if ~exist("brainStates","var"), load("data-pca/neural_states_manifold.mat","brainStates"); end
if ~exist("dspmStates","var"),  load("data-pca/dspm_1000neurons_states_manifold.mat","dspmStates"); end

[nU, ~, nC] = size(brainStates);
tvec = (0:P.ntbins-1) * P.dt;

mask_start = find(brain.all_mask(1,:), 1, "first");
mask_cols  = mask_start : (mask_start + P.ntbins - 1);
M.all      = logical(brain.all_mask(:, mask_cols))';     % [ntbins x nC]
M.valid    = mean(M.all, 2) >= P.thresh_cov;
M.min_act  = max(5, round(0.5 * nC));
tmax       = tvec(find(M.valid, 1, "last"));
sig_bins   = tvec >= P.signal_win(1) & tvec <= P.signal_win(2);
isB        = rishi_data.nbounces(:)' > 0;                % 26 bounce, 53 no-bounce

nI = min(numel(dspmStates), P.max_inst);
c  = pong_colors();  col.dmfc = c.brain.color;  col.dspm = c.dspm.color;
col.noise = [0 0 0];  col.nz = [0.55 0.35 0.15];  col.gate = [0.45 0.2 0.6];  col.cls = [0.2 0.45 0.8];

%% ====================== S1  DMFC noise floor and PR ======================
% per-unit noise SD from the cross-condition spread in the pre-signal bins
Xn   = reshape(brainStates(:, P.noise_bins, :), nU, []);
sd_u = std(Xn, 0, 2);
noise_var_dmfc = mean(sd_u.^2);
Xs   = reshape(brainStates(:, sig_bins, :), nU, []);
snr_dmfc = max(mean(var(Xs, 0, 2)) - noise_var_dmfc, 0) / noise_var_dmfc;
fprintf("S1  DMFC per-unit noise var %.3g, late-window SNR %.2f\n", noise_var_dmfc, snr_dmfc);

pr.dmfc = pr_curve(brainStates, M.all, P.nPC, M.min_act, true);  pr.dmfc(~M.valid) = NaN;

%% ====================== S2  noise-matched and gated dSPM ======================
ramp = 1 ./ (1 + exp(-(tvec - P.t_on) / 25));                % ~100 ms wide switch
nM = numel(P.noise_mult);
pr.clean = nan(nI, P.ntbins);
pr.noisy = nan(nM, nI*P.n_draws, P.ntbins);                   % one row per noise multiplier
pr.gated = nan(nI*P.n_draws, P.ntbins);
pr.pure  = nan(nI*P.n_draws, P.ntbins);
noise_for = cell(nI, 1);                                      % per-instance noise spec, reused in S3

for i = 1:nI
    S  = dspmStates{i};  nUd = size(S, 1);
    pr.clean(i, :) = pr_curve(S, M.all, P.nPC, M.min_act, false);

    Ss = reshape(S(:, sig_bins, :), nUd, []);  sig_var = mean(var(Ss, 0, 2));
    shape = sd_u(randi(nU, nUd, 1));  shape = shape / sqrt(mean(shape.^2));   % DMFC heterogeneity
    nsd   = sqrt(sig_var / snr_dmfc) * shape;                                 % matched SNR
    noise_for{i} = nsd;

    Sm = mean(S, 3);
    Sg = Sm + (S - Sm) .* reshape(ramp, 1, [], 1);           % condition-specific part gated on at t_on
    for d = 1:P.n_draws
        Z = randn(size(S)) .* nsd;  k = (i-1)*P.n_draws + d;
        for m = 1:nM
            pr.noisy(m, k, :) = pr_curve(S + sqrt(P.noise_mult(m)) * Z, M.all, P.nPC, M.min_act, false);
        end
        pr.gated(k, :) = pr_curve(Sg + Z, M.all, P.nPC, M.min_act, false);
        pr.pure (k, :) = pr_curve(Z,      M.all, P.nPC, M.min_act, false);
    end
    fprintf("S2  dSPM instance %d/%d\n", i, nI);
end
for f = ["clean","gated","pure"], pr.(f)(:, ~M.valid) = NaN; end
pr.noisy(:, :, ~M.valid) = NaN;

early = tvec <= 100;  late = tvec >= 500 & M.valid';
fprintf("\n%-28s  PR 0-100 ms   PR >= 500 ms\n", "S2 summary");
row = @(n, x) fprintf("%-28s  %6.1f        %6.1f\n", n, mean(x(:,early),"all","omitnan"), mean(x(:,late),"all","omitnan"));
row("DMFC", pr.dmfc); row("dSPM clean", pr.clean);
for m = 1:nM, row(sprintf("dSPM + %gx matched noise", P.noise_mult(m)), squeeze(pr.noisy(m,:,:))); end
row("dSPM gated + 1x noise", pr.gated); row("pure noise", pr.pure);

%% ====================== S3  implied signal-to-noise of DMFC ======================
% lookup PR(g) with dSPM signal scaled by g at fixed matched noise, then invert DMFC's PR(t)
g_grid = [0 logspace(-2, 1, 40)];
pr_g   = nan(numel(g_grid), nI);
for i = 1:nI
    S = dspmStates{i};  Sm = mean(S, 3);  D = S - Sm;
    Z = randn(size(S)) .* noise_for{i};
    for k = 1:numel(g_grid)
        p = pr_curve(Sm + g_grid(k)*D + Z, M.all, P.nPC, M.min_act, false);
        pr_g(k, i) = mean(p(sig_bins & M.valid'), "omitnan");
    end
end
lookup   = mean(pr_g, 2);                                     % decreasing in g
g_dmfc   = max(interp1(flipud(lookup), flipud(g_grid(:)), pr.dmfc, "linear", "extrap"), 0);
snr_t    = g_dmfc.^2 * snr_dmfc;  snr_t(~M.valid) = NaN;
fprintf("S3  implied SNR: 0-100 ms %.3f, 250 ms %.3f, 450-650 ms %.3f, 700-1000 ms %.3f (late-window %.3f)\n", ...
    mean(snr_t(early)), snr_t(tvec == 250), mean(snr_t(tvec>=450 & tvec<=650)), mean(snr_t(tvec>=700 & tvec<=1000)), snr_dmfc);

%% ====================== S4  bounce vs no-bounce, matched n ======================
traj_b = pca_traj(brainStates, M.all, P.nPC, true);            % common basis, all 79
iB = find(isB);  iN = find(~isB);  nB = numel(iB);
min_act26 = max(5, round(0.5 * nB));
[pr.B, cv.B] = pr_subset(traj_b, M.all, iB, min_act26);
pr.N = nan(P.n_sub, P.ntbins);  cv.N = nan(P.n_sub, P.ntbins);
for s = 1:P.n_sub
    sub = iN(randperm(numel(iN), nB));
    [pr.N(s,:), cv.N(s,:)] = pr_subset(traj_b, M.all, sub, min_act26);
end
[pr.all79, cv.all79] = pr_subset(traj_b, M.all, 1:nC, M.min_act);
% within-class PR on all 79: remove each class's mean per bin
traj_w = traj_b;
for t = 1:P.ntbins
    for g = {iB, iN}
        a = g{1}(M.all(t, g{1}));
        if numel(a) >= 2, traj_w(:, t, a) = traj_b(:, t, a) - mean(traj_b(:, t, a), 3); end
    end
end
[pr.within, ~] = pr_subset(traj_w, M.all, 1:nC, M.min_act);
for f = ["B","N","all79","within"], pr.(f)(:, ~M.valid) = NaN; end
for f = ["B","N","all79"], cv.(f)(:, ~M.valid) = NaN; end
bump = tvec >= 300 & tvec <= 600;
fprintf("S4  PR in 300-600 ms: bounce %.1f, no-bounce(26) %.1f (pctile of bounce %.0f%%), all 79 %.1f, all 79 class means removed %.1f\n", ...
    mean(pr.B(bump)), mean(pr.N(:,bump),"all"), 100*mean(mean(pr.N(:,bump),2) <= mean(pr.B(bump))), mean(pr.all79(bump)), mean(pr.within(bump)));
fprintf("    noise PR ceiling: n=26 -> %.1f, n=79 -> %.1f (so subgroup and pooled levels are not comparable; shapes are)\n", ...
    P.nPC/(1+P.nPC/25), P.nPC/(1+P.nPC/78));

%% ====================== S5  population rate transient ======================
raw = permute(brain.data,[1 3 2]);  sz = size(raw);
if ndims(raw) == 3 && sz(1) == nU && sz(3) == nC
elseif ndims(raw) == 3 && sz(1) == nC && sz(3) == nU, raw = permute(raw, [3 2 1]);
elseif ndims(raw) == 3 && sz(2) == nU,                 raw = permute(raw, [2 1 3]);
else, error("Unrecognized layout of brain.data: %s", mat2str(sz));
end
rates = reshape(raw(:, mask_cols, :), nU, []);
rates(:, ~M.all(:)) = NaN;
rates = reshape(rates, nU, P.ntbins, nC);
rate_t = squeeze(mean(rates, [1 3], "omitnan"))';  rate_t(~M.valid) = NaN;
% total condition-specific variance (all 79, above the 0-100 ms floor), for the same panel
var_t  = cv.all79 - mean(cv.all79(P.noise_bins));
fprintf("S5  rate: 0-100 ms %.4g, peak %.4g at %d ms, 650-700 ms %.4g (%.0f%% change)\n", ...
    mean(rate_t(early)), max(rate_t), tvec(find(rate_t == max(rate_t),1)), mean(rate_t(tvec>=650 & tvec<=700)), ...
    100*(max(rate_t)-mean(rate_t(tvec>=650 & tvec<=700)))/mean(rate_t(early)));

%% ====================== supplementary figure (two panels) ======================
figure(Color="w", Position=[80 80 1150 440], Name="Supp: PR noise and onset");
tl = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");

% A  noise floor, matched noise, and signal onset
ax = nexttile; hold(ax, "on");
band(tvec, pr.pure, col.noise, "pure noise (no signal)");
shades = [col.nz; 0.8 0.65 0.3];
for m = 1:nM
    band(tvec, squeeze(pr.noisy(m,:,:)), shades(min(m,2),:), sprintf("dSPM + %gx DMFC-matched noise", P.noise_mult(m)));
end
band(tvec, pr.gated, col.gate, sprintf("dSPM, signal on at %d ms + 1x noise", P.t_on));
band(tvec, pr.clean, col.dspm, "dSPM");
plot(tvec, pr.dmfc, "o-", Color=col.dmfc, LineWidth=2, MarkerFaceColor=col.dmfc, MarkerSize=4, DisplayName="DMFC");
xline(250, "--", Color=[.4 .4 .4], HandleVisibility="off");
xlim([0 tmax]); ylim([0 26]); xlabel("Time from trial start (ms)"); ylabel("Participation ratio");
title("A   PR of dSPM with DMFC-matched noise", FontWeight="normal", HorizontalAlignment="left");
legend(Location="east", Box="off", FontSize=9); style(ax);

% B  implied SNR and population rate
ax = nexttile; hold(ax, "on");
yyaxis(ax, "left");
plot(tvec, snr_t, "o-", Color=col.dmfc, LineWidth=2, MarkerFaceColor=col.dmfc, MarkerSize=4, DisplayName="implied signal-to-noise");
yline(snr_dmfc, ":", Color=col.dmfc, HandleVisibility="off");
ylabel("Implied signal-to-noise"); ax.YColor = col.dmfc;
yyaxis(ax, "right");
plot(tvec, rate_t, "-", Color=[.3 .3 .3], LineWidth=1.5, DisplayName="population mean rate");
ylabel("Population mean rate"); ax.YColor = [.3 .3 .3];
xline(250, "--", Color=[.4 .4 .4], HandleVisibility="off");
xlim([0 tmax]); xlabel("Time from trial start (ms)");
title("B   Signal implied by PR, and firing rate", FontWeight="normal", HorizontalAlignment="left");
legend(Location="southeast", Box="off", FontSize=9); style(ax);

% exportgraphics(tl, "supp_pr_noise_and_onset.pdf", ContentType="vector");

%% ====================== diagnostic figure: all controls (not for the supplement) ======================
figure(Color="w", Position=[80 80 1150 440], Name="Diag: class split and variance overshoot");
tl = tiledlayout(1, 2, TileSpacing="compact", Padding="compact");

ax = nexttile; hold(ax, "on");
plot(tvec, pr.all79,  "-", Color=[.3 .3 .3], LineWidth=2, DisplayName="all 79 conditions (Fig. 2B)");
plot(tvec, pr.within, "-", Color=col.cls,    LineWidth=2, DisplayName="all 79, bounce-class means removed");
band(tvec, pr.N, [0.5 0.5 0.5], "no-bounce, 26 of 53");
plot(tvec, pr.B, "o-", Color=col.dmfc, LineWidth=1.5, MarkerFaceColor=col.dmfc, MarkerSize=3, DisplayName="bounce, n = 26");
xline(250, "--", Color=[.4 .4 .4], HandleVisibility="off"); xline(550, ":", Color=[.4 .4 .4], Label="earliest bounce", HandleVisibility="off");
xlim([0 tmax]); ylim([0 12]); xlabel("Time from trial start (ms)"); ylabel("Participation ratio");
title("The 300-600 ms rise by trial class (null)", FontWeight="normal"); legend(Location="northeast", Box="off", FontSize=9); style(ax);

ax = nexttile; hold(ax, "on");
band(tvec, cv.N - mean(cv.N(:, P.noise_bins), 2), [0.5 0.5 0.5], "no-bounce, 26 of 53");
plot(tvec, cv.B - mean(cv.B(P.noise_bins)), "o-", Color=col.dmfc, LineWidth=1.5, MarkerFaceColor=col.dmfc, MarkerSize=3, DisplayName="bounce, n = 26");
xline(250, "--", Color=[.4 .4 .4], HandleVisibility="off"); xline(550, ":", Color=[.4 .4 .4], HandleVisibility="off");
xlim([0 tmax]); xlabel("Time from trial start (ms)"); ylabel("Condition-specific variance above floor");
title("Variance overshoot and settling, by class", FontWeight="normal"); legend(Box="off", FontSize=9); style(ax);

%% ====================== functions ======================
function pr = pr_curve(states, mask, nPC, min_active, use_mask_for_pca)
% Fig. 2B pipeline: global PCA, then PR of the cross-condition covariance of
% the projected states at each bin, active conditions only.
    traj = pca_traj(states, mask, nPC, use_mask_for_pca);
    [pr, ~] = pr_subset(traj, mask, 1:size(states,3), min_active);
end

function traj = pca_traj(states, mask, nPC, use_mask)
    [nU, nT, nC] = size(states);
    flat = reshape(states, nU, []);
    if use_mask, flat = flat(:, mask(:)); end
    mu    = mean(flat, 2);
    nPC   = min(nPC, min(nU, size(flat,2)) - 1);
    coeff = pca((flat - mu)', NumComponents=nPC, Centered=false);
    traj  = zeros(nPC, nT, nC);
    for c = 1:nC, traj(:,:,c) = coeff' * (states(:,:,c) - mu); end
end

function [pr, tr] = pr_subset(traj, mask, idx, min_active)
    nT = size(traj, 2);  pr = nan(1, nT);  tr = nan(1, nT);
    for t = 1:nT
        a = idx(mask(t, idx));
        if numel(a) < min_active, continue; end
        X = squeeze(traj(:, t, a));  X = X - mean(X, 2);
        lam = max(eig(X*X'/(numel(a)-1)), 0);
        pr(t) = sum(lam)^2 / sum(lam.^2);  tr(t) = sum(lam);
    end
end

function band(t, Mx, col, name)
    mu = mean(Mx, 1, "omitnan"); sd = std(Mx, 0, 1, "omitnan");  ok = ~isnan(mu);
    fill([t(ok) fliplr(t(ok))], [mu(ok)+sd(ok) fliplr(mu(ok)-sd(ok))], col, FaceAlpha=0.15, EdgeColor="none", HandleVisibility="off");
    plot(t(ok), mu(ok), "-", Color=col, LineWidth=2, DisplayName=name);
end

function style(ax)
    set(ax, FontSize=11, Box="off", TickDir="out", LineWidth=1.2);
end
