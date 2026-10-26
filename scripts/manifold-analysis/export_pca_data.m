%% =====================================================================
%  EXPORT PCA VIEWER DATA — THREE TEMPORAL EPOCHS
%
%  Exports pca_data.js containing PCA trajectories for all systems
%  across three epoch-defined bases:
%    epoch 1: onset        0–300 ms
%    epoch 2: transition   300–800 ms
%    epoch 3: manifold     600–1300 ms
%
%  Each epoch defines an independent PCA basis trained on that window.
%  The FULL trial trajectory is projected into each basis, so the viewer
%  shows the entire trial in each epoch's coordinate system.
%
%  Requires in workspace:
%    brainStates, dspmStates, rnn_ponly_states, rnn_ntp_states
%    ballStates_manifold.mat  (raw <x,y,xdot,ydot>, from preprocess_manifold)
%    all_mask_bs  [ntbins × ntrials]  logical
%    tvec_bs      [1 × ntbins]        ms
%    valid_bins                        1-indexed
%    ntbins, ntrials, dt
%    bounceIdx, bounce_wall
%    rishi_data.sim_coordinates.y
%    compute_pca_masked()             defined in main analysis script
% =====================================================================

fprintf('\n===== Exporting PCA Viewer Data (3 epochs) =====\n');

nPC_export = 15;

%% --- Epoch and system definitions ---

epoch_keys   = {'onset',   'transition', 'manifold'};
epoch_labels = {'0–300 ms','300–800 ms', '600–1300 ms'};
epoch_tmin   = [0,   300,  600];
epoch_tmax   = [300, 800, 1300];

sys_keys   = {'brain',       'dspm',  'ponly',          'ntp',        'ballState'};
sys_labels = {'Brain (DMFC)','dSPM',  'paddleOnly RNN', 'nextTP RNN', 'Ball State'};
sys_colors = {'#9B2335',     '#00ACC1','#8D7248',        '#2E7D32',    '#6A3D9A'};

nEpochs  = numel(epoch_keys);
nSystems = numel(sys_keys);

%% --- Condition metadata ---
endpoint_y = cellfun(@(y) y(end), rishi_data.sim_coordinates.y);

% Validated bounce indicator (26 trials) — see trajectory-split validation.
% nbounces is the simulation's own ground truth; do NOT recompute from the
% midline-crossing mask (that counts crossings, not reversals → 36, wrong).
bounceIdx  = logical(rishi_data.nbounces(:)');   % [1 × ntrials], 1 = bounced

% Bounce wall for the viewer + LDA cross-check: 0 none, 1 top, 2 bottom.
% The first bounce's wall is set by the initial y-velocity sign (up -> top
% wall first), so we derive it from bounceIdx + ydot0. NOTE: this makes the
% bounceIdx-vs-bounce_wall consistency check in lda_geometry_analysis.m
% tautological; if an independent wall label (e.g. from the trajectory) is
% available upstream, prefer it there to keep that cross-check meaningful.
yd0         = rishi_data.ydot0(:)';
bounce_wall = zeros(size(bounceIdx));
bounce_wall(bounceIdx & yd0 > 0) = 1;   % top
bounce_wall(bounceIdx & yd0 < 0) = 2;   % bottom

%% --- Ball-state covariate (raw task variables) ---
%  ballState = <x, y, xdot, ydot>, the raw task state variables. NOT the
%  M-augmented linear map: injecting M*r would hand the LDA the very
%  velocity/bounce structure it is meant to discover -> circular. Loaded from
%  the shared preprocess_manifold output so ballState is ONE object across the
%  manifold, decoding, and LDA pipelines. Stored [coord x trials x time];
%  permute to [coord x time x trials] to match the other systems.
bs = load("../network-data/ballStates_states_manifold_timezscore.mat", "ballStates");
ballState = permute(bs.ballStates, [1 3 2]);
assert(size(ballState,2) == ntbins && size(ballState,3) == ntrials, ...
    'ballState is [%d x %d x %d]; expected time=%d trials=%d -> bin/trial misalignment with the workspace systems.', ...
    size(ballState,1), size(ballState,2), size(ballState,3), ntbins, ntrials);

sys_data   = {brainStates, dspmStates, rnn_ponly_states, rnn_ntp_states, ballState};

%% --- Compute all PCAs ---
fprintf('Running %d epochs × %d systems = %d PCAs...\n', ...
    nEpochs, nSystems, nEpochs*nSystems);

all_traj = cell(nEpochs, nSystems);
all_expl = cell(nEpochs, nSystems);

for ei = 1:nEpochs
    tbin_start = find(tvec_bs >= epoch_tmin(ei), 1, 'first');
    tbin_final = find(tvec_bs <= epoch_tmax(ei), 1, 'last');
    if isempty(tbin_start), tbin_start = 1; end
    if isempty(tbin_final), tbin_final = ntbins; end
    tidx = tbin_start:tbin_final;

    fprintf('\n  Epoch "%s" — bins %d:%d (%.0f–%.0f ms)\n', ...
        epoch_labels{ei}, tbin_start, tbin_final, ...
        tvec_bs(tbin_start), tvec_bs(tbin_final));

    post_mask = all_mask_bs(tidx, :);

    for si = 1:nSystems
        fprintf('    %-18s ... ', sys_labels{si});

        % Concatenate ensemble along neuron dim (handles both cell and array)
        d = sys_data{si};
        if iscell(d)
            data_3d = cat(1, d{:});
        else
            data_3d = d;
        end
        nU_sys = size(data_3d, 1);

        % Masked flat matrix for epoch window
        data_2d = reshape(data_3d(:, tidx, :), nU_sys, []);
        active  = find(post_mask(:));
        masked  = data_2d(:, active)';    % [n_active × nU]
        masked  = masked(all(isfinite(masked), 2), :);   % drop NaN samples (ballState / out-of-trial tails)

        % PCA on epoch window, project full trial — EXCEPT ballState, which
        % IS the low-dimensional manifold already. PCA on its 4 raw coords is
        % not reduction but a variance-ranked rotation of a 4D space with
        % nothing to discard: it launders the low-variance, label-aligned ẏ
        % channel into the high-variance position axes and manufactures a
        % spurious ~90° four-condition split (raw <x,y> alone gives ~8°, the
        % rotated PC1/PC2 gave ~68°). So ballState uses the IDENTITY basis —
        % its raw coordinates <x,y,ẋ,ẏ> ARE its "PCs" — fed straight to the
        % same downstream factorial LDA. The C(4,2)=6 column-pairs are the
        % analogue of the models' PC-pair search.
        if strcmp(sys_keys{si}, 'ballState')
            mu_bs = mean(masked, 1);              % [1 × 4] onset-window mean/coord
            traj  = data_3d - mu_bs';             % centre like the PCA path (mean
                                                  %   removal is invariant to the
                                                  %   centroid-difference LDA anyway)
            cvar  = var(masked, 0, 1);            % per-coordinate variance
            expl  = 100 * cvar(:) / sum(cvar);    % [4 × 1] pseudo-"explained"
            fprintf('IDENTITY basis (x,y,ẋ,ẏ), var%%=[%.0f %.0f %.0f %.0f] ... ', expl);
        else
            [expl, traj] = compute_pca_masked(masked, nPC_export, data_3d, all_mask_bs);
        end

        all_traj{ei, si} = traj;
        all_expl{ei, si} = expl;

        fprintf('PC1=%.1f%% PC2=%.1f%% PC3=%.1f%%\n', expl(1), expl(2), expl(min(3,numel(expl))));
    end
end

%% --- Write pca_data.js ---
fprintf('\nWriting pca_data.js ...\n');

fid = fopen('pca_data.js', 'w');

fprintf(fid, '// pca_data.js — PCA Viewer Data\n');
fprintf(fid, '// Generated: %s\n\n', char(datetime('now','Format','yyyy-MM-dd HH:mm')));

fprintf(fid, 'const PCA_DATA = {\n\n');

%% meta
fprintf(fid, '  meta: {\n');
fprintf(fid, '    ntrials: %d,\n', ntrials);
fprintf(fid, '    nPC: %d,\n', nPC_export);
fprintf(fid, '    dt: %d,\n', dt);
fprintf(fid, '    tvec: %s,\n', vec2js(tvec_bs));
fprintf(fid, '    valid_bins: %s,\n', intvec2js(valid_bins - 1));

% epochs array
fprintf(fid, '    epochs: [\n');
for ei = 1:nEpochs
    comma = ''; if ei < nEpochs, comma = ','; end
    fprintf(fid, '      {key:"%s", label:"%s", window_ms:[%d,%d]}%s\n', ...
        epoch_keys{ei}, epoch_labels{ei}, epoch_tmin(ei), epoch_tmax(ei), comma);
end
fprintf(fid, '    ],\n');

% system arrays
fprintf(fid, '    system_keys:   [%s],\n', ...
    strjoin(cellfun(@(s) ['"' s '"'], sys_keys,   'UniformOutput',false), ','));
fprintf(fid, '    system_labels: [%s],\n', ...
    strjoin(cellfun(@(s) ['"' s '"'], sys_labels, 'UniformOutput',false), ','));
fprintf(fid, '    system_colors: [%s]\n', ...
    strjoin(cellfun(@(s) ['"' s '"'], sys_colors, 'UniformOutput',false), ','));
fprintf(fid, '  },\n\n');

%% conditions
fprintf(fid, '  conditions: {\n');
fprintf(fid, '    bounce_wall: %s,\n', intvec2js(bounce_wall));
fprintf(fid, '    bounceIdx:   %s,\n', intvec2js(double(bounceIdx)));
fprintf(fid, '    endpoint_y:  %s,\n', vec2js(endpoint_y));
fprintf(fid, '    ydot0:       %s\n',  vec2js(rishi_data.ydot0(:)'));
fprintf(fid, '  },\n\n');

%% data: data[epoch_key][system_key]

fprintf(fid, '  data: {\n');
for ei = 1:nEpochs
    ep_comma = ''; if ei < nEpochs, ep_comma = ','; end
    fprintf(fid, '    %s: {\n', epoch_keys{ei});
    for si = 1:nSystems
        sys_comma = ''; if si < nSystems, sys_comma = ','; end
        fprintf(fid, '      %s: {\n', sys_keys{si});
        fprintf(fid, '        expl: %s,\n', vec2js(all_expl{ei,si}'));
        fprintf(fid, '        traj: %s\n',  traj2js(all_traj{ei,si}));
        fprintf(fid, '      }%s\n', sys_comma);
    end
    fprintf(fid, '    }%s\n', ep_comma);
end
fprintf(fid, '  }\n\n');

fprintf(fid, '};\n');
fclose(fid);

d = dir('pca_data.js');
fprintf('Written: pca_data.js  (%.1f MB)\n', d.bytes/1e6);
fprintf('Zip with pca_viewer.html and send.\n');
fprintf('===== Done =====\n');


%% =====================================================================
%  LOCAL FUNCTIONS  (MATLAB R2016b+: must be at end of script)
% =====================================================================

function s = traj2js(traj)
% [nPC × ntbins × ntrials] → JS nested array [ntrials][nPC][ntbins]
    [nPC, ntbins, ntrials] = size(traj);
    cparts = cell(ntrials, 1);
    for c = 1:ntrials
        rows = cell(nPC, 1);
        for p = 1:nPC
            vals   = squeeze(traj(p, :, c));
            strs   = arrayfun(@(v) sprintf('%.4f',v), vals, 'UniformOutput',false);
            rows{p} = ['[' strjoin(strs,',') ']'];
        end
        cparts{c} = ['[' strjoin(rows,',') ']'];
    end
    s = ['[' strjoin(cparts,',') ']'];
end

function s = vec2js(v)
    strs = arrayfun(@(x) sprintf('%.4f',x), v(:)', 'UniformOutput',false);
    s = ['[' strjoin(strs,',') ']'];
end

function s = intvec2js(v)
    strs = arrayfun(@(x) sprintf('%d',x), v(:)', 'UniformOutput',false);
    s = ['[' strjoin(strs,',') ']'];
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