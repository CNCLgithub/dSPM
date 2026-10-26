function dspm_run_state_normalization(runDir, svFileName, hpcDir)
%DSPM_RUN_STATE_NORMALIZATION  Normalize raw dSPM network states for one run.
%
%   DSPM_RUN_STATE_NORMALIZATION(RUNDIR, SVFILENAME, ALLMASK) loads every
%   per-network state file under the run directory RUNDIR, masks each trial's
%   out-of-distribution time bins to NaN, z-scores each neuron using statistics
%   drawn from the universally-covered (pre-divergence) time window, and saves
%   the normalized states to SVFILENAME.
%
%   Statistics (mu, sigma) are computed per neuron over [trials x statWin] with
%   NaNs omitted, then applied to ALL time bins. Out-of-trial bins remain NaN by
%   design, so any naive downstream use will surface them rather than silently
%   corrupt results.
%
%   Inputs:
%     runDir     (1,1) string  - run subfolder under the programmed-networks dir
%     svFileName (1,1) string  - output .mat filename (saved inside runDir)
%     hpcDir     (1,1) string  - base programmed-networks directory
%
%   Output (saved, not returned):
%     dspmStates {nfiles x 1} - each [nneurons x ntrials x ntbins] normalized
%
%   Example:
%     dspm_run_state_normalization("25-Sep-2024_...", "dspm_states_norm.mat")
%
%
    arguments
        runDir       (1,1) string
        svFileName   (1,1) string  = "dspm_states_normalized.mat";
        hpcDir       (1,1) string  = "../../hpc-outputs/programmed-networks/"
    end
%%
    load("../../data/brain_and_rishi_data.mat","brain");
    allmask = brain.all_mask;
    allmask(:,all(~allmask)) = [];

    [ntrials, ntbins] = size(allmask);

    % ---- locate per-network state files for this run --------------------
    files  = dir(fullfile(hpcDir, runDir, "rnn-states", "*.mat"));
    nfiles = numel(files);

    % ---- per-trial last valid bin; NaN everything strictly after it -----
    % include the final in-distribution bin (tail starts at +1)
    lastValid = cellfun(@(r) find(r,1,"last"),num2cell(allmask,2)); % [ntrials x 1]

    dspmStates = cell(nfiles,1);
    parfor i = 1:nfiles

        fprintf("\t network %d/%d\n",i, nfiles)

        % load raw states and orient to [nneurons x ntrials x ntbins]
        net    = load(fullfile(hpcDir, runDir, "rnn-states", files(i).name));
        states = net.prnn_validation.binned_states.modelStates;
        states = cat(3, states{:});
        states(:,1:4,:) = [];

        X      = permute(states, [1 3 2]);          % [nneurons x ntrials x ntbins]

        % NaN each trial's out-of-distribution tail (index trial dim with j)
        for j = 1:ntrials
            X(:, j, (lastValid(j)+1):end) = NaN;
        end

        % per-neuron stats from the pre-divergence window only (NaNs omitted)
        Xwin = X(:, :, 1:ntbins);

        mu = mean(Xwin, [2 3], 'omitnan');          % [nneurons x 1]
        sd = std( Xwin, 0, [2 3], 'omitnan');        % [nneurons x 1]
        sd(sd == 0) = 1;

        % apply to ALL bins; out-of-trial bins stay NaN by design
        dspmStates{i} = (Xwin - mu) ./ sd; %#ok<PFOUS>
    end

    save(fullfile(hpcDir, runDir, svFileName), "dspmStates",'-v7.3')

end

function runLocal()
%%

%{

runDir = "28-Feb-2025_2000neurons_67b7c1a2-7732-467f-99c6-ba2a10fe89c4";
svFileName = "dspm_states_normalized_2000neurons.mat";

%}
runDir = "28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b";
svFileName = "dspm_states_normalized_1000neurons.mat";

dspm_run_state_normalization(runDir,svFileName)

end