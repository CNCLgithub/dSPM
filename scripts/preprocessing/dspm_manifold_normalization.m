function dspm_manifold_normalization(runDir, svFileName, hpcDir, scaleMode, softFrac)
%DSPM_MANIFOLD_NORMALIZATION  dSPM states for the manifold analysis.
% Mirrors dspm_run_state_normalization.m (same NaN-tail masking, window,
% orientation) but SOFT-NORMALIZES instead of z-scoring. 
% Run where the raw HPC states live. 
% Decoding dSPM files are untouched.
%
%   scaleMode : "soft" (default) | "center" | "zscore"
%   softFrac  : soft-norm strength in units of median(sd). 0=zscore, large->center.
    arguments
        runDir     (1,1) string
        svFileName (1,1) string = "dspm_states_manifold_1000neurons.mat";
        hpcDir     (1,1) string = "../../hpc-outputs/programmed-networks/";
        scaleMode  (1,1) string = "soft";
        softFrac   (1,1) double = 1.0;
    end

    %%
    
    load("../../data/brain_and_rishi_data.mat", "brain");
    allmask = brain.all_mask;
    allmask(:, all(~allmask)) = [];
    [ntrials, ntbins] = size(allmask);
    lastValid = cellfun(@(r) find(r,1,"last"), num2cell(allmask,2));

    files  = dir(fullfile(hpcDir, runDir, "rnn-states", "*.mat"));
    nfiles = numel(files);
    dspmStates = cell(nfiles,1);
    parfor i = 1:nfiles
        fprintf("\t network %d/%d\n", i, nfiles);
        net    = load(fullfile(hpcDir, runDir, "rnn-states", files(i).name));
        states = net.prnn_validation.binned_states.modelStates;
        states = cat(3, states{:});
        states(:,1:4,:) = [];
        X = permute(states, [1 3 2]);               % [nneurons x ntrials x ntbins]
        for j = 1:ntrials
            X(:, j, (lastValid(j)+1):end) = NaN;
        end
        Xwin = X(:, :, 1:ntbins);
        mu = mean(Xwin, [2 3], "omitnan");
        sd = std( Xwin, 0, [2 3], "omitnan");  sd(sd==0) = 1;
        switch scaleMode
            case "zscore", dspmStates{i} = (Xwin - mu) ./ sd;
            case "center", dspmStates{i} = (Xwin - mu);
            case "soft"
                s0 = softFrac * median(sd(sd>0), "omitnan");
                dspmStates{i} = (Xwin - mu) ./ (sd + s0);
        end
    end
    save(fullfile(hpcDir, runDir, svFileName), "dspmStates", "-v7.3");
    fprintf("saved %s (%s, softFrac=%g)\n", svFileName, scaleMode, softFrac);
end