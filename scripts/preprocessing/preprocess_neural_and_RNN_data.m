function preprocess_neural_and_RNN_data()

    load("../../data/brain_and_rishi_data.mat","brain");
    allmask    = brain.all_mask;
    idxInTrial = any(allmask);

    allmask(:,~idxInTrial) = [];
    idxPreTrial = find(idxInTrial,1,"first")-1;

    % ---- per-trial last valid bin; NaN everything strictly after it -----
    % include the final in-distribution bin (tail starts at +1)
    lastValid = cellfun(@(r) find(r,1,"last"),num2cell(allmask,2)); % [ntrials x 1]

    [ntrials, ntbins] = size(allmask);

    %% Normalize, trim, and save neural states
    
    brainStates = brain.data;
    
    % NaN each trial's out-of-distribution tail (index trial dim with j)
    for j = 1:ntrials
        brainStates(:, j, (lastValid(j)+1+idxPreTrial):end) = NaN;
    end
    % per-neuron stats from the pre-divergence window only (NaNs omitted)
    Xwin = brainStates(:, :, (1:ntbins)+idxPreTrial);
    
    mu = mean(Xwin, [2 3], 'omitnan');          % [nneurons x 1]
    sd = std( Xwin, 0, [2 3], 'omitnan');        % [nneurons x 1]
    sd(sd == 0) = 1;
    
    % apply to ALL bins; out-of-trial bins stay NaN by design
    brainStates = (Xwin - mu) ./ sd; 
    
    save("../../data/neural_states_normalized.mat","brainStates")

    %% Normalize, trim, and save rnn states
    load("../../data/bbrnns.mat","bbrnns")
    
    dataRNNs   = {bbrnns.data_neur_nxcxt};
    nmdls      = numel(dataRNNs);
    rnnStates  = cell(nmdls,1);
    
    for i = 1:nmdls
    
        states = dataRNNs{i};%systemStates.stateData{4}{i}; 
    
        % NaN each trial's out-of-distribution tail (index trial dim with j)
        for j = 1:ntrials
            states(:, j, (lastValid(j)+1):end) = NaN;
        end
    
        % per-neuron stats from the pre-divergence window only (NaNs omitted)
        Xwin = states(:, :, 1:ntbins);
    
        mu = mean(Xwin, [2 3], 'omitnan');          % [nneurons x 1]
        sd = std( Xwin, 0, [2 3], 'omitnan');        % [nneurons x 1]
        sd(sd == 0) = 1;
        
        % apply to ALL bins; out-of-trial bins stay NaN by design
        rnnStates{i} = (Xwin - mu) ./ sd; 
    
    end
    
    rnn_input    = string({bbrnns.input_representation})';
    rnn_nneurons = cellfun(@(c) size(c,1),dataRNNs');
    rnn_loss     = string({bbrnns.loss_type})';

%{
From Rishi et al.:

RNN Intercept ("mov") has one output to control paddle to intercept the 
ball at the endpoint. 

RNN Vis ("vis-mov") has two outputs additionally tracking the ball 
position during the visible epoch (solid line). 

RNN Vis&Occ ("sim-mov") tracks the ball across both epochs in one output
(two outputs in total).

RNN Vis+Occ ("vis-sim-mov") has three outputs with tracking of the 
occluded ball position

%}
    strChange = [
        "mov"         , "paddle"  
        "sim-mov"     , "nextTP-singleChannel"      
        "vis-mov"     , "nextTP-visibleOnly"      
        "vis-sim-mov" , "nextTP"          
        ];
    
    rnn_loss_new = replace(rnn_loss,strChange(:,1),strChange(:,2));
    
    rnn_model_key = table();
    rnn_model_key.input     = rnn_input   ;
    rnn_model_key.nneurons  = rnn_nneurons;
    rnn_model_key.loss      = rnn_loss_new;
    
    save("../../data/rnn_states_normalized_all.mat", ...
        "rnnStates","rnn_model_key")

    %% Save analysis subset of RNNs

    idxpaddle = contains(rnn_input,"gabor") & ...
                ismember(rnn_loss_new,"paddle") & ...
                rnn_nneurons == 40;

    idxnextTP = contains(rnn_input,"gabor") & ...
            ismember(rnn_loss_new,"nextTP") & ...
            rnn_nneurons == 40;

    paddleStates = rnnStates(idxpaddle);
    nextTPstates = rnnStates(idxnextTP);

    save("../../data/rnn_states_normalized_analysisSubset.mat", ...
        "paddleStates","nextTPstates")

end