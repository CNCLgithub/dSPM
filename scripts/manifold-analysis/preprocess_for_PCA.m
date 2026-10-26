function preprocess_for_PCA

    load("../../data/brainAndBB-state-matrices-time_refactored.mat", ...
        "brainStates","rnnStates")
    brainStates = cat(3,brainStates{:});
    brainStates = permute(brainStates,[1 3 2]);

    [paddleStates,nextTPStates] = filter_tradRNNs(rnnStates);

    proj = "../../";
    resClass = "28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b";
    fldr = "hpc-outputs/programmed-networks/"+resClass+ "/post-hoc/";
    dataFile = "time-organized-states/all-network-states.mat";

    file = fullfile(proj,fldr,dataFile);

    a = load(file);
    dspmStates = a.allStates;

    if ~exist("data-pca","dir"),mkdir("data-pca"),end

    save(fullfile("data-pca","neural_states_manifold"),"brainStates")
    save(fullfile("data-pca","dspm_1000neurons_states_manifold"),"dspmStates",'-v7.3')
    save(fullfile("data-pca","paddle_states_manifold"),"paddleStates")
    save(fullfile("data-pca","nextTP_states_manifold"),"nextTPStates")

end


%% Data Parsing Functions

function [paddleStates,nextTPstates] = filter_tradRNNs(rnnStates)
% =====================================================================
% FILTER RNNs by Gabor Input, 40 neurons, Loss Function
% =====================================================================

    load("../../data/bbrnns.mat","bbrnns")

    rnn_input = string({bbrnns.input_representation})';
    rnn_nn    = cellfun(@(c) size(c,1), {bbrnns.data_neur_nxcxt}' );
    rnn_loss  = replace(string({bbrnns.loss_type})', ...
        ["mov";"sim-mov";"vis-mov";"vis-sim-mov"], ...
        ["paddle";"nextTP-singleChannel";"nextTP-visibleOnly";"nextTP"]);
    idxPaddle = contains(rnn_input,"gabor") & rnn_loss=="paddle" & rnn_nn==40;
    idxNextTP = contains(rnn_input,"gabor") & rnn_loss=="nextTP" & rnn_nn==40;
    paddleStates = rnnStates(idxPaddle);
    nextTPstates = rnnStates(idxNextTP);

    fprintf('Primary analysis:\n');
    fprintf('  paddleOnly: %d networks\n', sum(idxPaddle));
    fprintf('  nextTP:     %d networks\n', sum(idxNextTP));


end