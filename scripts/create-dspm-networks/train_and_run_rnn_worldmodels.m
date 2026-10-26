function train_and_run_rnn_worldmodels(netnum, runid, varargin )
% New as of Jan 2025, check archive for old function with same name that
% contains the old method(s) with game-play, paddle-control, game-analysis
% etc
%% Load Dependencies

% Next 4 lines is for local debugging/running
live_trig = contains(mfilename,'LiveEditorEvaluationHelper');
nnetworks = 1;
create_new_rnn = true;
if live_trig, varargin = {}; end   % local runs only; cluster jobs pass nneurons/ntrials/connectivity

p = inputParser;
addParameter(p, 'rootpath', '../../');
addParameter(p, 'nneurons', 1000, @isnumeric); % # neurons 
addParameter(p, 'ntrials', 40, @isnumeric); % # training trials
addParameter(p, 'connectivity', 'programmed'); % {'programmed' , 'random'
addParameter(p, 'runPaddleFeedBack', false, @islocal);

try parse(p, varargin{:});
catch, parse(p);end

rootpath      = p.Results.rootpath;
nneurons      = p.Results.nneurons;
ntrials       = p.Results.ntrials;
connectivity  = p.Results.connectivity;

warning off
addpath(rootpath); setup_paths()   % not genpath(rootpath): see setup_paths.m

%% Add everything to path and start parallel pool

rng('shuffle')
pause(rand(1)*2)

parpool(feature('NumCores'))

%% Load Monkey Data and Control/Validation Trial Data
% This section set ups training trials, gets rishi's validation trials, and
% creates a prnn with specific gameboard setup

if live_trig
    
    if create_new_rnn 
        nnetworks = 1;
        nneurons  = 1000;
        connectivity = "programmed";
        prnn_info = create_and_program_pong_rnns( ...
            nnetworks,nneurons,connectivity, ...
            "paddle_exist",false);
    else
        rnn_path = fullfile(rootpath, "data", "untrained-prnns");
        rnn_fids = dir(fullfile(rnn_path,"*.mat"));

        netnum    = 1;
        rnnpath   = fullfile(rnn_path,rnn_fids(netnum).name);
        mfile     = matfile(rnnpath);
        prnn_info = mfile.prnns(netnum,1);  
    end

    netnum = 1;
    runid = dicomuid;
    
else

    if create_new_rnn 
        prnn_info = create_and_program_pong_rnns(...
            nnetworks,nneurons,connectivity,...
            "paddle_exist",false);     
    else
        rnn_fids  = dir(fullfile(rnnpath,"*.mat"));
        rnnpath   = fullfile(rnnpath,rnn_fids(netnum).name);
        mfile     = matfile(rnnpath);
        prnn_info = mfile.prnns(netnum,1);
    end
    
end

board_params = prnn_info.board_params;
basernn      = prnn_info.prnn;

[train_data,rishi_data,~] = ...
    load_game_data(fullfile(rootpath,"data/"),board_params,ntrials);

valid_data                 = rishi_data;
valid_data.board_params    = board_params;
valid_data.ntrials         = numel(valid_data.nbounces);


runEqualTrialLength = true;
if runEqualTrialLength
    % Rishi ran for 5s per trial and binned by 50 ms
    valid_data.simulation_time = 5000*ones(valid_data.ntrials,1);
else
    % Still increase trial time by a bit 
    valid_data.simulation_time = round(valid_data.simulation_time*1.2);
end

prnn_out  = prnn_output();
prnn_out.board_params = board_params;

save_path = fullfile(rootpath, 'hpc-outputs' ,...
    [char(connectivity) '-networks'], runid);

netid  = string(java.util.UUID.randomUUID.toString);

%% Play Validation Set with random paddle placement
% Creates a prnnvars structure for the validation data

pool = gcp("nocreate");
if isempty(pool)
    try parpool(feature('NumCores')), catch, end
end

rnnvars_validation = run_rnn_trials(basernn,valid_data);

rnnvars_validation.savedir    = save_path;
rnnvars_validation.runid      = runid;
rnnvars_validation.netid      = netid;
rnnvars_validation.runOrdinal = netnum;

prnn_out.rnnvars_validation = rnnvars_validation;

prnn_out.spectral_radius = max(abs(eig(rnnvars_validation.progrnn.prnn.A)));


%% Final/Multi Time Point Decoding 
% Runs through final timepoint prediction yielding information about
% decoding accuracy over time (performance x time)
% decoding error over time (mse x time)
% linear transformation betas (nneurons x time)

prnn_validation = rnnvars_validation;

prnn_validation.data = valid_data;

% All possible prediction targets can be found at EOF
prediction_targets = [
    "ballx_absT_all"
    "bally_absT_all"
    "ballx_absT_bounce0"
    "bally_absT_bounce0"
    "ballx_absT_bounce1"
    "bally_absT_bounce1"
    "bally_shuffled_all"
];

% Number of time points to sample from trajectory
ntpts = 50;

if live_trig
    prediction_targets=["ballx_absT_all";"bally_absT_all"];
    ntpts = 10;
end

validation_states = prnn_validation.binned_states.modelStates;

ftp_valid = run_multiTimePoint_decoding_neural_hpc(...
    validation_states, ...
    'nTimePredictors',ntpts,'predvars',prediction_targets);

prnn_validation.final_timepoint_prediction = ftp_valid;

%% Representational Similarity Analysis
% Runs through RSA with Neural Data and Black-Box Models
% Yields:
% - RDM vectors over binned-time (RDMstates x ntbins)
% Both Static and Time-resolved versions of:
% - Raw Brain RSA
% - Raw Model RSA
% - Residualized Brain and prnn RSA (Strict, prnn-(all bbrnns))
% - Residualized Brain and prnn RSA (Loose, bootstrap prnn-(1 random bbrnn ))
% - Residualized Model to Model RSA 

save_path_RSA = fullfile(save_path,'rnn-RSA-files');
if ~exist(save_path_RSA,"dir") && ~live_trig
    mkdir(save_path_RSA)
    mkdir(fullfile(save_path_RSA,'static-rdms'))
    mkdir(fullfile(save_path_RSA,'temporal-rdms'))
end

runparams.corrtype  = 'Pearson';
runparams.disttype  = 'seuclidean';% correlation
runparams.nruns     = 1;
runparams.rootdir   = rootpath;
runparams.savepath  = save_path_RSA;
runparams.live_trig = live_trig;

[rsaStruct, RDMs]   = rsa_residual_pipeline(rnnvars_validation,runparams);

prnn_validation.rdm_vectors_rsa = RDMs;


%% Save Structures

% Create save file names and directories
save_path_rnnvars = fullfile(save_path,'rnn-states');
fileid            = strjoin(['prnn-states-id', netnum, netid],'_');
fid_rnnvars       = strcat(save_path_rnnvars,'/',fileid, '.mat');

prnn_validation.network_states = [];
prnn_validation.network_inputs = valid_data;

% save(fid_stats , "runid", "netnum", "netid", "network_outputs" , "stats_out" )

save(fid_rnnvars , "runid", "netnum", "netid", "prnn_validation","rsaStruct","ftp_valid" )


%% Log Parameters for this family of runs to parent dir

if netnum == 1, log_parameters(nneurons, connectivity, ntrials, board_params,save_path); end

end 


%% Support Functions

function [network_structures,map_data] = reduce_memory_size(prnn_out)
%%


% maps = prnn_out.decoding_maps;

rm_fields = { 'train_prediction','valid_prediction','valid_error','train_error','compilation_error','plot'};
map_data  = structfun(@single,rmfield(maps,rm_fields),uniformoutput=false);

train1 = prnn_out.trainned_rnn;
valid1 = prnn_out.validation_rnn1;
valid2 = prnn_out.validation_rnn2;


basernn = train1.progrnn.basernn;
prnn    = train1.progrnn.prnn;
prnn.W  = train1.progrnn.basernn.W;

network_structures = prnnvars_out;

network_structures.prnn               = prnn;
network_structures.basernn            = basernn;
network_structures.board_params       = prnn_out.board_params;
network_structures.decoding_maps      = map_data;
network_structures.training_data      = train1.data;
network_structures.validation_data    = valid1.data;
network_structures.input_data.train   = train1.input_data;
network_structures.input_data.valid_predecoding  = valid1.input_data;
network_structures.input_data.valid_postdecoding = cellfun(@(s) s.input_data,valid2,uniformoutput=false);


end

function [network_outputs, stats_out]  = gather_stats(prnn_out,analysis)
%%
    
    rnn_valid1 = prnn_out.validation_rnn1;
    rnn_valid2 = prnn_out.validation_rnn2;

    network_outputs = network_outputs_pong();
    network_outputs.rnn_trained.data   = cellfun(@(r) r.network_outputs(),rnn_valid2,uniformoutput=false); 
    network_outputs.rnn_untrained.data = rnn_valid1.network_outputs();
    network_outputs.board_params  = prnn_out.board_params;

       
    %%

    % maps = prnn_out.decoding_maps;
    % 
    % decoding_outputs = decoding_outputs_pong;
    % 
    % decoding_outputs.avg_train_error       = mean(maps.train_error,3);
    % decoding_outputs.avg_valid_error       = mean(maps.valid_error,3);
    % decoding_outputs.avg_valid_correlation = maps.valid_correlation;
    % decoding_outputs.avg_valid_cor_mse_sum = maps.valid_cor_mse_sum;
    % decoding_outputs.t_decode              = maps.t_decode    ;
    % decoding_outputs.t_validation          = maps.t_validation;
    % decoding_outputs.best_map              = maps.best_mapping;
    % decoding_outputs.best_map_index        = maps.best_map_index;


    %%

    stats_out = statistic_outputs_pong();

    stats_out.brain_rsa                = analysis.brain_rsa;
    stats_out.correlation_stats        = analysis.correlation_stats;
    stats_out.game_stats_rand_training = analysis.game_stats_rand_training;
    stats_out.game_stats_rand_valid    = analysis.game_stats_rand_valid;
    stats_out.game_stats_pred_valid    = analysis.game_stats_pred_valid;


end

function log_parameters(nneurons, connectivity, ntrials, board_params,save_path)
%%   
% Open a file to write
    logfid = fullfile(save_path,'parameter_log.txt');
    fileID = fopen(logfid, 'w');

    % Check if the file was opened successfully
    if fileID == -1
        error('Failed to open file.');
    end

    % Write the simple variables
    fprintf(fileID, ['Date: ' char(datetime('now')) '\n\n']);
    fprintf(fileID, 'Number of neurons: %d\n', nneurons);
    fprintf(fileID, 'Connectivity: %s\n', connectivity);
    fprintf(fileID, 'Number of training trials: %d\n\n', ntrials);

    % Write the board_params structure
    fprintf(fileID, 'Board Parameters:\n\n');
    fieldNames = fieldnames(board_params);
    for i = 1:length(fieldNames)
        fieldName = fieldNames{i};
        fieldValue = board_params.(fieldName);

        % Handle different types of field values
        if isnumeric(fieldValue)
            if numel(fieldValue) == 1
                % Scalar numeric values
                fprintf(fileID, '   %s: %.4f\n', fieldName, fieldValue);
            else
                % Array values, write as a comma-separated list
                fprintf(fileID, '   %s: [', fieldName);
                fprintf(fileID, '%.4f, ', fieldValue(1:end-1));
                fprintf(fileID, '%.4f]\n', fieldValue(end));
            end
        elseif ischar(fieldValue)
            % String values
            fprintf(fileID, '   %s: %s\n', fieldName, fieldValue);
        else
            % For other types, just use a generic output
            fprintf(fileID, '   %s: %s\n', fieldName, mat2str(fieldValue));
        end
    end

    % Close the file
    fclose(fileID);
end



%{
All possible prediction targets for the multi-time-point 
decoding analysis

ballx    is the x positions of the ball to predict
bally    is the y positions of the ball to predict

absT     is absolute time from ball interception point
propT    is evenly spaced proportional time points across an individual trial
spaceT   is evenly spaced *spatial* times shared across all trials
shuffled is shuffled accross trials to make a "null" distribution

all      is all trials together
bounce0  is just the trials with no bounces
bounce1  is just the trials with one bounce


prediction_targets = [

    "ballx_absT_all"
    "ballx_absT_bounce0"
    "ballx_absT_bounce1"
    "ballx_propT_all"
    "ballx_propT_bounce0"
    "ballx_propT_bounce1"
    "ballx_spaceT_all"
    "ballx_spaceT_bounce0"
    "ballx_spaceT_bounce1"
    "ballx_shuffled_all"

    "bally_absT_all"
    "bally_absT_bounce0"
    "bally_absT_bounce1"
    "bally_propT_all"
    "bally_propT_bounce0"
    "bally_propT_bounce1"
    "bally_spaceT_all"
    "bally_spaceT_bounce0"
    "bally_spaceT_bounce1"
    "bally_shuffled_all"



];

%}




