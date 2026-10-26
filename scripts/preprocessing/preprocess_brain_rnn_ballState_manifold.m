function preprocess_brain_rnn_ballState_manifold(scaleMode, softFrac)
% Manifold-analysis preprocessing: mirrors preprocess_neural_and_RNN_data.m and
% generate_ballState_and_linearMap.m EXACTLY (same NaN-tail masking, same
% pre-divergence window, same [units x trials x time] orientation) but replaces
% the per-neuron z-score with SOFT-NORMALIZATION so the natural across-neuron
% variance PR/PCA depend on is preserved. Decoding files are untouched.
%
%   scaleMode : "soft" (default) -> (X-mu)/(sd + softFrac*median(sd))
%               "center"         -> (X-mu)            [no scaling; PR-purest]
%               "zscore"         -> (X-mu)/sd         [reproduces decoding files]
%   softFrac  : soft-norm strength in units of median(sd). 0=zscore, large->center.
%
% Writes *_manifold.mat next to the decoding files (dSPM handled separately by
% dspm_manifold_normalization.m, which runs where the raw HPC states live).

arguments
    scaleMode (1,1) string {mustBeMember(scaleMode,["soft","center","zscore"])} = "soft"
    softFrac  (1,1) double {mustBeNonnegative} = 1.0
end

%%

snorm = @(Xw, mu, sd) scale_apply(Xw, mu, sd, scaleMode, softFrac);

load("../../data/brain_and_rishi_data.mat", "brain", "rishi_data");
allmask    = brain.all_mask;
idxInTrial = any(allmask);
allmask(:, ~idxInTrial) = [];
idxPreTrial = find(idxInTrial, 1, "first") - 1;
lastValid   = cellfun(@(r) find(r,1,"last"), num2cell(allmask,2));
[ntrials, ntbins] = size(allmask);

%% ---- neural ----
brainStates = brain.data;
for j = 1:ntrials
    brainStates(:, j, (lastValid(j)+1+idxPreTrial):end) = NaN;
end
Xwin = brainStates(:, :, (1:ntbins)+idxPreTrial);
[mu, sd] = neuron_stats(Xwin);
brainStates = snorm(Xwin, mu, sd);
save("../network-data/neural_states_manifold.mat", "brainStates");
fprintf("neural: %s (softFrac=%g)\n", scaleMode, softFrac);

%% ---- RNNs (paddle + nextTP analysis subset) ----
load("../../data/bbrnns.mat", "bbrnns");
dataRNNs  = {bbrnns.data_neur_nxcxt};
rnnStates = cell(numel(dataRNNs),1);
for i = 1:numel(dataRNNs)
    states = dataRNNs{i};
    for j = 1:ntrials
        states(:, j, (lastValid(j)+1):end) = NaN;
    end
    Xwin = states(:, :, 1:ntbins);
    [mu, sd] = neuron_stats(Xwin);
    rnnStates{i} = snorm(Xwin, mu, sd);
end

rnn_input = string({bbrnns.input_representation})';
rnn_nn    = cellfun(@(c) size(c,1), dataRNNs');
rnn_loss  = replace(string({bbrnns.loss_type})', ...
    ["mov";"sim-mov";"vis-mov";"vis-sim-mov"], ...
    ["paddle";"nextTP-singleChannel";"nextTP-visibleOnly";"nextTP"]);
idxPaddle = contains(rnn_input,"gabor") & rnn_loss=="paddle" & rnn_nn==40;
idxNextTP = contains(rnn_input,"gabor") & rnn_loss=="nextTP" & rnn_nn==40;
paddleStates = rnnStates(idxPaddle);
nextTPstates = rnnStates(idxNextTP);
save("../network-data/rnn_states_manifold_analysisSubset.mat", "paddleStates", "nextTPstates");
fprintf("RNN: paddle=%d nextTP=%d instances\n", sum(idxPaddle), sum(idxNextTP));

%% ---- ballState (kept z-scored; only feeds the LDA, not PCA/PR) ----

xdata = rishi_data.ballXData;  ydata = rishi_data.ballYData;
xdot  = repmat(rishi_data.xdot0', size(xdata,1), 1);
ydot  = repmat(rishi_data.ydot0', size(xdata,1), 1);
ballStates = permute(cat(3, xdata, ydata, xdot, ydot), [3 2 1]);
for j = 1:ntrials
    ballStates(:, j, (lastValid(j)+1+idxPreTrial):end) = NaN;
end

Xwin     = ballStates(:, :, (1:ntbins)+idxPreTrial);
[mu, sd] = neuron_stats(Xwin);
ballStates = (Xwin - mu) ./ sd;   % z-score (LDA is scale-normalized anyway)
save("../network-data/ballStates_manifold.mat", "ballStates");
fprintf("ballState: zscore (LDA input)\n");

end


% ====================================================================
function [mu, sd] = neuron_stats(Xwin)
mu = mean(Xwin, [2 3], "omitnan");
sd = std( Xwin, 0, [2 3], "omitnan");
sd(sd == 0) = 1;
end

function Xn = scale_apply(Xwin, mu, sd, mode, softFrac)
switch mode
    case "zscore", Xn = (Xwin - mu) ./ sd;
    case "center", Xn = (Xwin - mu);
    case "soft"
        s0 = softFrac * median(sd(sd > 0), "omitnan");
        Xn = (Xwin - mu) ./ (sd + s0);
    otherwise, error("scaleMode must be soft | center | zscore");
end
end