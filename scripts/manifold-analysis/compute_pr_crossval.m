function pr_cv = compute_pr_crossval(states_3d, mask_2d, nPC, min_n_active)
%COMPUTE_PR_CROSSVAL  Cross-validated participation ratio on PCA trajectories.
%
%  MATCHES the original pr_masked_cov approach: PR is computed on
%  PCA-PROJECTED trajectories [nPC x ntbins x nTrials], not raw states.
%  This is critical — PR on raw states is dominated by nTrials rank cap.
%
%  Cross-validation (Fusi noise concern):
%    Fold A: fit PCA on odd trials, project even trials, compute PR
%    Fold B: fit PCA on even trials, project odd trials, compute PR
%    Output: average of both folds
%
%  Noise in test data won't correlate with noise in training eigenvectors,
%  so noise-inflated dimensions collapse in the held-out projection.
%  Genuine manifold structure generalizes → lower, sharper CV-PR for DMFC.
%
%  Inputs:
%    states_3d    [nU x ntbins x nTrials]  raw neural/model states
%    mask_2d      [ntbins x nTrials]       logical, active time-trial pairs
%    nPC          number of PCs to use
%    min_n_active minimum active conditions to compute PR at a time bin
%
%  Output:
%    pr_cv        [1 x ntbins]  cross-validated PR (matches pr_masked_cov format)

[nU, ntbins, nTrials] = size(states_3d);

odd_trials  = 1:2:nTrials;
even_trials = 2:2:nTrials;

% Fit PCA on each fold's masked active samples
[coeff_odd,  mu_odd]  = fit_pca_on_trials(states_3d, odd_trials,  mask_2d, nPC);
[coeff_even, mu_even] = fit_pca_on_trials(states_3d, even_trials, mask_2d, nPC);

% Project test trials through training PCs → trajectories
traj_even = project_trials(states_3d, even_trials, coeff_odd,  mu_odd,  ntbins, size(coeff_odd,2));
traj_odd  = project_trials(states_3d, odd_trials,  coeff_even, mu_even, ntbins, size(coeff_even,2));

% Compute PR on held-out trajectory at each time bin
pr_a = pr_from_traj(traj_even, mask_2d(:, even_trials), min_n_active, ntbins);
pr_b = pr_from_traj(traj_odd,  mask_2d(:, odd_trials),  min_n_active, ntbins);

% Average the two folds
pr_cv = nanmean([pr_a; pr_b], 1);

end


%% ── Helper: fit PCA on a subset of trials ────────────────────────────
function [coeff, mu] = fit_pca_on_trials(states_3d, trial_idx, mask_2d, nPC)
%  Exactly matches compute_pca_masked: pool all masked (time,trial) pairs
%  for the given trials, center, run PCA.

    states_sub = states_3d(:, :, trial_idx);       % [nU x ntbins x nSub]
    mask_sub   = mask_2d(:, trial_idx);            % [ntbins x nSub]

    % Flatten to [nU x (ntbins*nSub)], select active columns
    flat   = reshape(states_sub, size(states_sub,1), []);
    active = find(mask_sub(:));
    masked = flat(:, active)';                      % [n_active x nU]

    nU       = size(masked, 2);
    n_active = size(masked, 1);
    nPC_use  = min(nPC, min(nU, n_active) - 1);

    mu  = mean(masked, 1);                         % [1 x nU]
    X_c = masked - mu;

    [coeff, ~, ~, ~, ~] = pca(X_c, 'NumComponents', nPC_use, 'Centered', false);
    % coeff: [nU x nPC_use]
end


%% ── Helper: project trials through given PCA basis ───────────────────
function traj = project_trials(states_3d, trial_idx, coeff, mu, ntbins, nPC)
%  Project each trial's time course through coeff (fitted on OTHER trials).
%  Returns [nPC x ntbins x nSub].

    nSub = numel(trial_idx);
    traj = zeros(nPC, ntbins, nSub);
    for ti = 1:nSub
        tr = trial_idx(ti);
        % Centre by TRAINING mean, project
        traj(:, :, ti) = coeff' * (states_3d(:, :, tr) - mu');
    end
end


%% ── Helper: PR at each time bin from a trajectory tensor ─────────────
function pr_vec = pr_from_traj(traj, mask_sub, min_n_active, ntbins)
%  traj:     [nPC x ntbins x nSub]
%  mask_sub: [ntbins x nSub]
%  Matches the logic of pr_masked_cov — uses only active conditions,
%  requires min_n_active, computes PR from variance across conditions.

    [nPC, ~, ~] = size(traj);
    pr_vec = nan(1, ntbins);

    for tb = 1:ntbins
        active = find(mask_sub(tb, :));
        if numel(active) < min_n_active, continue; end

        % Condition snapshots: [nPC x n_active]
        X = squeeze(traj(:, tb, active));   % [nPC x n_active]
        if size(X,2) < 2, continue; end

        % Variance of each PC across active conditions
        v = var(X, 0, 2);   % [nPC x 1]
        sv = sum(v);
        if sv < eps, continue; end
        pr_vec(tb) = sv^2 / sum(v.^2);
    end
end