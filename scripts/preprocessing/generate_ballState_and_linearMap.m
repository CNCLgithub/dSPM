
if ~exist("rishi_data","var")
    load("../../data/brain_and_rishi_data.mat","brain","rishi_data")
end

allmask    = brain.all_mask;
idxInTrial = any(allmask);

allmask(:,~idxInTrial) = [];
idxPreTrial = find(idxInTrial,1,"first")-1;

% ---- per-trial last valid bin; NaN everything strictly after it -----
% include the final in-distribution bin (tail starts at +1)
lastValid = cellfun(@(r) find(r,1,"last"),num2cell(allmask,2)); % [ntrials x 1]
[ntrials, ntbins] = size(allmask);

xdata = rishi_data.ballXData;
ydata = rishi_data.ballYData;

xdot  = repmat(rishi_data.xdot0',size(xdata,1),1);
ydot  = repmat(rishi_data.ydot0',size(xdata,1),1);

ballStates = cat(3,xdata,ydata,xdot,ydot);
ballStates = permute(ballStates,[3 2 1]);

tbinKeep = any(brain.all_mask,1);

% NaN each trial's out-of-distribution tail (index trial dim with j)

for j = 1:ntrials
    ballStates(:, j, (lastValid(j)+1+idxPreTrial):end) = NaN;
end
% per-neuron stats from the pre-divergence window only (NaNs omitted)
Xwin = ballStates(:, :, (1:ntbins)+idxPreTrial);

mu = mean(Xwin, [2 3], 'omitnan');    % [nneurons x 1]
sd = std( Xwin, 0, [2 3], 'omitnan'); % [nneurons x 1]
sd(sd == 0) = 1;

% apply to ALL bins; out-of-trial bins stay NaN by design
ballStates = (Xwin - mu) ./ sd; 

save("./data/ballStates_states_normalized.mat","ballStates")


%%


% a = allmask;
% 
% b = cellfun(@(v,n) circshift(v, ntbins-n), ...
%     num2cell(a,2),num2cell(finalTbin),UniformOutput=0);
% b = cat(1,b{:});
% 
% cy = cellfun(@(v,n) circshift(v, ntbins-n), ...
%     num2cell(ballY',2),num2cell(finalTbin),UniformOutput=0);
% cy = cat(1,cy{:});
% 
% cx = cellfun(@(v,n) circshift(v, ntbins-n), ...
%     num2cell(ballX',2),num2cell(finalTbin),UniformOutput=0);
% cx = cat(1,cx{:});
% 
% plot(cx(:,end-maxNback:end)',cy(:,end-maxNback:end)')