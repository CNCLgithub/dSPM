%% =====================================================================
%  §00  LOAD IN DATA AND SET COLORS
%  =====================================================================


if ~exist("rishi_data","var") 
    load("../../data/brain_and_rishi_data.mat")
end

loadinTrig = false;

if ~exist("brainStates","var") || loadinTrig
    load("data-pca/neural_states_manifold.mat","brainStates")
end

if ~exist("dspmStates","var") || loadinTrig
    load("data-pca/dspm_1000neurons_states_manifold.mat","dspmStates")
end

if ~exist("paddleStates","var") || loadinTrig
    load("data-pca/paddle_states_manifold.mat","paddleStates")
end

if ~exist("nextTPStates","var") || loadinTrig
    load("data-pca/nextTP_states_manifold.mat","nextTPStates")
end

% --- Color scheme ---
c = pong_colors();

col_brain = c.brain.color;
col_dspm  = c.dspm.color ;
col_ponly = c.paddle.color;
col_ntp   = c.nextTP.color;
col_shuf  = [0 0 0];
alpha_band = 0.15; % transparency for STD/SEM bands


%% =====================================================================
%  §0  MASK ALIGNMENT & EPOCH BOUNDARY EXTRACTION
%
%  brainStates uses bins 5:(5+ntbins-1) of brain.data (100 bins, 5000ms).
%  The first 4 bins are pre-stimulus; we remove them and truncate to the
%  longest active trial (ntbins = 71 bins = 3550ms post-stimulus).
%
%  All masks are [79×100] (conditions × bins) in brain.data indexing.
%  Here we realign them to [ntbins × nTrials] in brainStates indexing.
%  =====================================================================

nPC        = 35;
dt         = 50; % ms per bin
ntbins     = 71; % game-active time bins
varThresh  = 90; % percent variance for dimensionality
ntrials    = size(brainStates,3);

fprintf('\n===== §0: Mask Alignment & Epoch Boundaries =====\n');

mask_start = find(brain.all_mask(1,:),1,"first");                                          % first brainStates bin in brain.data
mask_cols  = mask_start : (mask_start + ntbins - 1);    % [1×71] index into brain.data bins

% brain.*_mask is [79×100] (conditions × bins)
% Slice to brainStates bins → [79×71] → transpose → [71×79]
all_mask_bs = logical(brain.all_mask(:, mask_cols))';   % [71×79]
vis_mask_bs = logical(brain.vis_mask(:, mask_cols))';   % [71×79]
occ_mask_bs = logical(brain.occ_mask(:, mask_cols))';   % [71×79]

% Sanity check: vis + occ should equal all (up to rounding at boundaries)
assert(all(all_mask_bs(:) >= vis_mask_bs(:) | all_mask_bs(:) >= occ_mask_bs(:)), ...
    'Mask inconsistency: vis+occ not subset of all');

% Coverage curve: fraction of conditions active at each brainStates bin
coverage   = mean(all_mask_bs, 2);    % [71×1] — 0 to 1
thresh_cov = 0.90;                    % only trust bins where ≥90% of conditions are active
valid_bins = find(coverage >= thresh_cov);

% Time vector: ms relative to trial start (post-prestim), bin 1 = t=0
tvec_bs = (0 : ntbins-1) * dt;        % [1×71] ms

% Per-condition epoch boundaries (brainStates bin indices, 1-indexed)
occ_start_bs = nan(1, ntrials);    % bin where occluded epoch first appears
vis_end_bs   = nan(1, ntrials);    % last visible epoch bin
trial_end_bs = nan(1, ntrials);    % last active bin for this condition

for c = 1:ntrials
    vb = find(vis_mask_bs(:, c), 1, 'last');
    ob = find(occ_mask_bs(:, c), 1, 'first');
    ab = find(all_mask_bs(:, c), 1, 'last');
    if ~isempty(vb), vis_end_bs(c)   = vb; end
    if ~isempty(ob), occ_start_bs(c) = ob; end
    if ~isempty(ab), trial_end_bs(c) = ab; end
end

med_occ_start_bin = round(nanmedian(occ_start_bs));
med_occ_start_ms  = (med_occ_start_bin - 1) * dt;

fprintf('  Visible epoch:  median end bin %d  (%.0f ms)\n', ...
    round(nanmedian(vis_end_bs)), nanmedian(vis_end_bs) * dt);
fprintf('  Occlusion onset: median bin %d  (%.0f ms)\n', ...
    med_occ_start_bin, med_occ_start_ms);
fprintf('  90%% coverage through: bin %d  (%.0f ms)\n', ...
    max(valid_bins), tvec_bs(max(valid_bins)));
fprintf('  Trial duration range: %d–%d bins  (%.0f–%.0f ms)\n', ...
    min(trial_end_bs, [], 'omitnan'), max(trial_end_bs, [], 'omitnan'), ...
    min(trial_end_bs, [], 'omitnan') * dt, max(trial_end_bs, [], 'omitnan') * dt);
fprintf('  Occ onset range: bin %d–%d  (%.0f–%.0f ms)\n', ...
    min(occ_start_bs, [], 'omitnan'), max(occ_start_bs, [], 'omitnan'), ...
    min(occ_start_bs, [], 'omitnan') * dt, max(occ_start_bs, [], 'omitnan') * dt);


%% =====================================================================
%  §1  EIGENSPECTRUM WITH SHUFFLED BASELINE
%
%  Shuffled baseline (Rajalingham Fig 3B):
%    For each neuron ui, permute the condition index independently.
%    This preserves each neuron's marginal firing rate distribution and
%    temporal structure, but destroys the shared covariance across neurons
%    that drives low-dimensional population structure.
%    The gap between true and shuffled eigenspectra = evidence for genuine
%    low-dimensional organisation.
%  =====================================================================

fprintf('\n===== §1: Eigenspectrum + Shuffled Baseline =====\n');

warning('off', 'all');

% -----------------------------------------------------------------------
%  Build brain_masked: [n_active × nU]
%
%  Rajalingham et al. run PCA on only the ACTIVE (unmasked) time-condition
%  points — not the full padded [71×79] tensor which includes imputed zeros
%  from short-trial conditions. We reproduce this exactly.
%
%  all_mask_bs is [ntbins × nTrials] (from §0).
%  Reshape brainStates to [nU × ntbins*nTrials], select active columns,
%  transpose to [n_active × nU] — matching their x_ctxn orientation.
% -----------------------------------------------------------------------
nU_brain     = size(brainStates, 1);                          % 1889
brain_2d     = reshape(brainStates, nU_brain, ntbins*ntrials);% [nU × ntbins*nTrials]
active_idx   = find(all_mask_bs(:));                          % linear indices of active bins
brain_masked = brain_2d(:, active_idx)';                      % [n_active × nU]
n_active     = size(brain_masked, 1);

fprintf('  Active (masked) states: %d of %d total\n', n_active, ntbins*ntrials);

% --- True eigenspectrum: brain (masked flat matrix, matches Rajalingham) ---
% traj_brain [nPC × ntbins × nTrials] is computed from the same PCA basis
% and used downstream for RSS. expl_brain is [nPC × 1] % variance explained.
[expl_brain, traj_brain] = compute_pca_masked(brain_masked, nPC, ...
    brainStates, all_mask_bs);

% --- True eigenspectra: dSPM, paddleOnly, nextTP (full tensor, no mask) ---
%  dSPM and RNNs run for complete trials (no variable-length issue), so
%  compute_pca_traj on the full tensor is appropriate.
expl_dspm_all  = nan(numel(dspmStates),        nPC);
traj_dspm      = cell(numel(dspmStates), 1);
for di = 1:numel(dspmStates)
    [traj_dspm{di}, ev] = compute_pca_traj(dspmStates{di}, nPC);
    nev = min(nPC, numel(ev));
    expl_dspm_all(di, 1:nev) = ev(1:nev)';
end

expl_ponly_all = nan(numel(paddleStates), nPC);
traj_ponly     = cell(numel(paddleStates), 1);
for ki = 1:numel(paddleStates)
    [traj_ponly{ki}, ev] = compute_pca_traj(paddleStates{ki}, nPC);
    nev = min(nPC, numel(ev));
    expl_ponly_all(ki, 1:nev) = ev(1:nev)';
end

expl_ntp_all = nan(numel(nextTPStates), nPC);
traj_ntp     = cell(numel(nextTPStates), 1);
for ki = 1:numel(nextTPStates)
    [traj_ntp{ki}, ev] = compute_pca_traj(nextTPStates{ki}, nPC);
    nev = min(nPC, numel(ev));
    expl_ntp_all(ki, 1:nev) = ev(1:nev)';
end

warning('on', 'all');

% -----------------------------------------------------------------------
%  Shuffled baseline — EXACT Rajalingham method (DMFC_dimensionality.ipynb)
%
%  def shuffle_data_matrix(x):
%      x_shuf = x.flatten()          # flatten entire [CT_active × N] matrix
%      np.random.shuffle(x_shuf)     # single global element permutation
%      return np.reshape(x_shuf, x.shape)
%
%  Key properties:
%   - Operates on the MASKED flat matrix [n_active × nU], not the padded tensor
%   - One randperm of ALL n_active*nU elements — global, not per-neuron
%   - Destroys neuron identity, time, and condition simultaneously
%   - Expected covariance → σ²I → flat eigenspectrum
% -----------------------------------------------------------------------
n_shuf     = 50;
expl_shuf  = nan(n_shuf, nPC);

bS = num2cell(brainStates,[1,2]);
bS = squeeze(cellfun(@squeeze, bS,UniformOutput=0));
bShuff = cellfun(@(c,m) c(:,m), bS, num2cell(all_mask_bs,1)',uniformoutput=0);

n_elements = numel(brain_masked);   % n_active × nU

fprintf('  Computing %d shuffled eigenspectra (global element shuffle)...\n', n_shuf);
rng(42);
for si = 1:n_shuf
    % Flatten everything, one global permutation, reshape back
    % x_flat       = brain_masked(:);
    % x_flat       = x_flat(randperm(n_elements));
    % brain_shuf   = reshape(x_flat, n_active, nU_brain);   % [n_active × nU]

    % brain_shuf   = reshape(x_flat, n_active, nU_brain);   % [n_active × nU]

    bS = cellfun(@(c) c( randperm(size(c,1)),randperm(size(c,2))), bShuff,UniformOutput=0);
    brain_shuf = cat(2,bS{:})';

    [ev_s, ~] = compute_pca_masked(brain_shuf, nPC, [], []);
    nev = min(nPC, numel(ev_s));
    expl_shuf(si, 1:nev) = ev_s(1:nev)';
    if mod(si, 5) == 0
        fprintf('    %d/%d shuffles done\n', si, n_shuf);
    end

end

% Cumulative variance
pcs          = 1:nPC;
cumvar_brain = cumsum(expl_brain);
cumvar_shuf  = cumsum(nanmean(expl_shuf,       1));
cumvar_dspm  = cumsum(nanmean(expl_dspm_all,   1));
cumvar_ponly = cumsum(nanmean(expl_ponly_all,  1));
cumvar_ntp   = cumsum(nanmean(expl_ntp_all,    1));

% PC at which brain crosses shuffled mean (geometric threshold for low-dim signal)
shuf_mean = nanmean(expl_shuf, 1);
cross_pc  = find(expl_brain < shuf_mean', 1, 'first');

fprintf('  Brain crosses shuffled at PC %d\n', cross_pc);
fprintf('  Cumulative variance at %d PCs:\n', nPC);
fprintf('    Brain:      %.1f%% | Shuffled: %.1f%%\n', cumvar_brain(end), cumvar_shuf(end));
fprintf('    dSPM:       %.1f%%\n', cumvar_dspm(end));
fprintf('    paddleOnly: %.1f%%\n', cumvar_ponly(end));
fprintf('    nextTP:     %.1f%%\n', cumvar_ntp(end));


%% =====================================================================
%  §2  PARTICIPATION RATIO — COVERAGE-MASKED (single time axis)
%
%  PR is computed on PCA-PROJECTED TRAJECTORIES (traj_*), not raw states.
%
%  Rationale: PR on raw [1889 × 79] states at each bin has maximum possible
%  value of 78 (rank = nConditions-1) regardless of structure, and getting
%  PR≈75 just means the 79 conditions span the space nearly uniformly —
%  uninformative. PR on PCA trajectories [nPC × ntbins × nTrials] measures
%  effective dimensionality of the TASK-RELEVANT subspace identified by the
%  global PCA, matching the old analysis and the paper narrative.
%
%  traj_brain  [nPC × ntbins × nTrials] — from compute_pca_masked §1
%  traj_dspm   cell of [nPC × ntbins × nTrials] — from compute_pca_traj §1
%  traj_ponly  cell of [nPC × ntbins × nTrials] — from compute_pca_traj §1
%  traj_ntp    cell of [nPC × ntbins × nTrials] — from compute_pca_traj §1
%  =====================================================================
%

fprintf('\n===== §2: PR Over Time (Coverage-Masked, on PCA trajectories) =====\n');

% Minimum number of active conditions required to compute PR
min_n_active = max(5, round(0.50 * ntrials));   % ≥50% of conditions
cov_mask_vec = ismember(1:ntbins, valid_bins);

% Brain PR — on PCA-projected traj_brain [nPC × ntbins × nTrials]
pr_cm_brain_all = pr_masked_cov(traj_brain, all_mask_bs, min_n_active);
pr_cm_brain_all(~cov_mask_vec) = NaN;

% dSPM PR — on PCA-projected traj_dspm{di}
pr_cm_dspm_all = nan(numel(dspmStates), ntbins);
for di = 1:numel(dspmStates)
    tmp = pr_masked_cov(traj_dspm{di}, all_mask_bs, min_n_active);
    tmp(~cov_mask_vec)   = NaN;
    pr_cm_dspm_all(di,:) = tmp;
end

% paddleOnly RNN PR — on PCA-projected traj_ponly{ki}
pr_cm_ponly_all = nan(numel(paddleStates), ntbins);
for ki = 1:numel(paddleStates)
    tmp = pr_masked_cov(traj_ponly{ki}, all_mask_bs, min_n_active);
    tmp(~cov_mask_vec) = NaN;
    pr_cm_ponly_all(ki,:) = tmp;
end

% nextTP RNN PR — on PCA-projected traj_ntp{ki}
pr_cm_ntp_all = nan(numel(nextTPStates), ntbins);
for ki = 1:numel(nextTPStates)
    tmp = pr_masked_cov(traj_ntp{ki}, all_mask_bs, min_n_active);
    tmp(~cov_mask_vec) = NaN;
    pr_cm_ntp_all(ki,:) = tmp;
end

fprintf('  Coverage-masked PR done.\n');
fprintf('  Valid window: %.0f – %.0f ms\n', ...
    tvec_bs(min(valid_bins)), tvec_bs(max(valid_bins)));


%% ----------------------------------------------------------------
%  FIGURE 1: Eigenspectrum + Shuffled Baseline
% ----------------------------------------------------------------
figure('Name', 'Fig: Eigenspectrum', 'Position', ...
    [50 500 1200 450], 'Color', 'w');

% --- Panel (A): log-scale eigenspectrum ---
ax = gca; hold(ax,"on")
p  = gobjects(5,1);

% Plot bands and means for each system (back-to-front order)
p(1) = plot_mean_sem(pcs, expl_ponly_all, col_ponly, '^-', 'paddleOnly', alpha_band);
p(2) = plot_mean_sem(pcs, expl_ntp_all,   col_ntp,   'v-', 'nextTP',     alpha_band);
p(3) = plot_mean_sem(pcs, expl_dspm_all,  col_dspm,  's-', 'dSPM',       alpha_band);

% Shuffled brain band (mean ± SEM)
mu_shuf  = nanmean(expl_shuf, 1);
std_shuf = nanstd(expl_shuf, 0, 1);
fill([pcs, fliplr(pcs)], [mu_shuf+std_shuf, fliplr(mu_shuf-std_shuf)], ...
    col_shuf, 'FaceAlpha', alpha_band, 'EdgeColor', 'none', 'HandleVisibility', 'off');

p(4) = plot(pcs, mu_shuf, '--', 'Color', col_shuf, 'LineWidth', 1.5, 'DisplayName', 'Brain (shuffled)');

% True brain on top
p(5) = plot(pcs, expl_brain, 'o-', 'Color', col_brain, 'LineWidth', 2.5, ...
    'MarkerFaceColor', col_brain, 'MarkerSize', 5, 'DisplayName', 'Brain');

% Mark where brain crosses shuffled (effective dimensionality boundary)
if ~isempty(cross_pc)
    xline(cross_pc, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, ...
          'Label', sprintf('PC %d', cross_pc), ...
          'LabelHorizontalAlignment', 'right', 'FontSize', 9);
end

set(gca, 'YScale', 'linear', 'FontSize', 11, 'XLim', [1 nPC]);
xlabel('Principal Component');
ylabel('% Variance Explained');
title('Eigenspectrum', 'FontWeight', 'bold');
legend(p, 'FontSize', 9);


%% ----------------------------------------------------------------
%  FIGURE 2: PR Coverage-Masked (single axis, inspection figure)
%  Single PR panel (all conditions) + coverage curve below.
% ----------------------------------------------------------------
figure('Name', 'Fig: PR Coverage-Masked', ...
    'Position', [50 50 800 600], 'Color', 'w');

etype = "std"; %{ std , sem }
fplot = @(data,color,tag)...
    plot_mean_with_error_ts(tvec_bs, data,...
        color, '-', tag, alpha_band,etype);

ax = gobjects(2,1);
p  = gobjects(4,1);

ax(1) = subplot(2,1,1); hold on;
p(1) = fplot( pr_cm_ponly_all, col_ponly, 'paddleOnly');
p(2) = fplot(   pr_cm_ntp_all,   col_ntp,   'nextTP'  );
p(3) = fplot(  pr_cm_dspm_all,  col_dspm,    'dSPM'   );

p(4) = plot(tvec_bs, pr_cm_brain_all, 'o-', 'Color', col_brain, 'LineWidth', 2.5, ...
    'MarkerFaceColor', col_brain, 'MarkerSize', 4, 'DisplayName', 'Brain');

xline(med_occ_start_ms, '--', 'Color', [0.5 0.5 0.5], ...
    'Label', sprintf('Occ. onset\n(%.0f ms)', med_occ_start_ms), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left', ...
    'FontSize', 9, 'LineWidth', 1);
xline(250, ':', 'Color', [0.8 0 0], 'Label', '250ms', ...
    'LabelVerticalAlignment', 'bottom', 'FontSize', 9, 'LineWidth', 1);

set(ax(1), 'FontSize', 11, 'XLim', [0 tvec_bs(end)]);

xlabel('Time from trial start (ms)');
ylabel('Participation Ratio');
title('PR: All conditions (coverage-masked)', 'FontWeight', 'bold');
legend(p,'Location', 'northeast', 'FontSize', 12);

ax(2) = subplot(2,1,2); hold on;
plot(tvec_bs, coverage * 100, 'k-', 'LineWidth', 2);
yline(thresh_cov * 100, 'r--', sprintf('%.0f%% threshold', thresh_cov*100), ...
    'LineWidth', 1, 'FontSize', 10);
xline(med_occ_start_ms, '--', 'Color', [0.5 0.5 0.5], ...
    'Label', sprintf('Median occ. onset\n(%.0f ms)', med_occ_start_ms), ...
    'LabelVerticalAlignment', 'bottom', 'FontSize', 9);

set(ax(2), 'FontSize', 11, 'XLim', [0 tvec_bs(end)], 'YLim', [0 105]);
xlabel('Time from trial start (ms)');
ylabel('% Conditions active');
title('Trial coverage across time', 'FontWeight', 'bold');

sgtitle('PR: Coverage-Masked', 'FontSize', 13, 'FontWeight', 'bold');



%% Plot Functions


function p = plot_mean_sem(x, data_matrix, col, marker, name, alpha_val)
%PLOT_MEAN_SEM  Mean + SEM band for indexed data (e.g., PC number).

    mu  = nanmean(data_matrix, 1);
    sem = nanstd(data_matrix, 0, 1) ./ sqrt(sum(~isnan(data_matrix), 1));
    fill([x(:); flipud(x(:))], [mu(:)+sem(:); flipud(mu(:)-sem(:))], ...
        col, 'FaceAlpha', alpha_val, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    p = plot(x, mu, marker, 'Color', col, 'LineWidth', 2, ...
        'MarkerFaceColor', col, 'MarkerSize', 6, 'DisplayName', name);

end


function p = plot_mean_with_error_ts(tvec, data_matrix, col, linestyle, name, alpha_val,errorType)
%PLOT_MEAN_SEM_TS  Mean + SEM/STD band for time-series data.

    data_matrix(:,isnan(data_matrix(1,:))) = [];
    T    = min(numel(tvec), size(data_matrix, 2));
    tvec = tvec(1:T);

    data_matrix = data_matrix(:, 1:T);

    mu      = nanmean(data_matrix, 1);
    n_valid = sum(~isnan(data_matrix), 1);
    sigma   = nanstd(data_matrix, 0, 1);

    if errorType == "sem", sigma = sigma ./ sqrt(max(n_valid, 1));end

    patch([tvec(:); flipud(tvec(:))], [mu(:)+sigma(:); flipud(mu(:)-sigma(:))], ...
        col, 'FaceAlpha', alpha_val, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    
    p = plot(tvec, mu, linestyle, 'Color', col, 'LineWidth', 2, 'DisplayName', name);
end



%% Computation Functions

function [traj, expl,score] = compute_pca_traj(states, nPC)
%COMPUTE_PCA_TRAJ  PCA on unrolled data, project per trial.
    [nUnits, ntbins, ntrials] = size(states);
    flat = reshape(states, nUnits, []);
    flat = flat - mean(flat, 2);
    nPC_use = min(nPC, min(nUnits, ntbins * ntrials) - 1);
    [coeff, score, ~, ~, expl_raw] = pca(flat', 'NumComponents', nPC_use);
    mu = mean(flat, 2);
    traj = zeros(nPC_use, ntbins, ntrials);
    for tr = 1:ntrials
        traj(:, :, tr) = coeff' * (states(:, :, tr) - mu);
    end
    expl = expl_raw(1:nPC_use);
end



function [expl, traj] = compute_pca_masked(brain_masked_2d, nPC, states_3d, mask_2d)
%COMPUTE_PCA_MASKED  PCA on masked flat matrix — exact Rajalingham method.
%
%  PRIMARY USE: eigenspectrum and shuffled baseline for brain data.
%
%  brain_masked_2d: [n_active × nU] — active time-condition states only.
%                   Pass [] to skip traj computation (shuffle case).
%  nPC:             number of PCs to retain.
%  states_3d:       [nU × ntbins × nTrials] — original tensor, used only
%                   to compute traj for downstream PR/RSS. Pass [] to skip.
%  mask_2d:         [ntbins × nTrials] logical — same mask used to build
%                   brain_masked_2d. Pass [] to skip traj.
%
%  Returns:
%  expl:  [nPC × 1]  % variance explained per PC
%  traj:  [nPC × ntbins × nTrials] projected trajectories ([] if skipped)

    [n_active, nU] = size(brain_masked_2d);
    nPC_use = min(nPC, min(nU, n_active) - 1);

    % Centre columns (neurons), matching sklearn PCA default
    mu   = mean(brain_masked_2d, 1);                   % [1 × nU]
    X_c  = brain_masked_2d - mu;                       % [n_active × nU]

    % PCA: columns are neurons (features), rows are states (samples)
    [coeff, ~, ~, ~, expl_raw] = pca(X_c, 'NumComponents', nPC_use, ...
                                      'Centered', false);
    expl = expl_raw(1:nPC_use);

    % Project original 3D tensor for traj (only when states_3d provided)
    traj = [];
    if ~isempty(states_3d) && ~isempty(mask_2d)
        [nU_s, ntbins, nTrials] = size(states_3d);
        traj = zeros(nPC_use, ntbins, nTrials);
        for tr = 1:nTrials
            % Centre each trial's matrix by the training mean
            traj(:, :, tr) = coeff' * (states_3d(:, :, tr) - mu');
        end
    end

end

function pr = pr_masked_cov(states, mask_2d, min_active)
%PR_MASKED_COV  PR at each timebin using only mask-active conditions.
%
%   states:     [nU × nT × nC] — neural/model state matrix
%   mask_2d:    [nT × nC]      — logical, 1 = condition c active at bin t
%   min_active: scalar         — minimum conditions to compute PR
%
%   The key fix over participation_ratio_over_time: each bin uses only
%   the conditions that are actually active (on-manifold), not all 79.
%   This prevents late-bin PR estimates from being deflated by imputed
%   values in conditions whose trials have already ended.

    [~, nT, ~] = size(states);
    pr = nan(1, nT);

    for t = 1:nT
        active = find(mask_2d(t, :));           % conditions active at this bin
        if numel(active) < min_active, continue; end

        X = squeeze(states(:, t, active));       % [nU × n_active]
        if size(X, 2) == 1, X = X(:); end        % edge case: single condition
        if any(isnan(X(:))), continue; end

        X = X - mean(X, 2);                      % centre per neuron
        C = (X * X') / (numel(active) - 1);      % covariance matrix [nU × nU]
        lam = max(eig(C), 0);                    % non-negative eigenvalues
        s1  = sum(lam);
        s2  = sum(lam .^ 2);
        if s2 > 0
            pr(t) = s1^2 / s2;
        end
    end
end




