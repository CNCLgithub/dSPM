%% Set Parameters

load("../../data/brain_and_rishi_data.mat","brain","rishi_data")

% trimmed validity mask + dims + per-trial interception bin (t_k)
allmask = brain.all_mask;
idxKeep = logical(sum(allmask));

finalTbin = cellfun(@(r) find(r,1,"last"), num2cell(allmask,2));

fcirc = @(c) cell2mat(cellfun(@(v,n) ...
    circshift(v,n),c,num2cell(-finalTbin),uniformoutput=0));

ballY = rishi_data.ballYData';
ballY        = fcirc(num2cell(ballY,2));
ballY(:,end) = rishi_data.ball_pos_final;
ballY        = zscore(ballY);
ballY(:,any(isnan(ballY))) = [];

allmask(:,~idxKeep) = [];
finalTbin = cellfun(@(r) find(r,1,"last"), num2cell(allmask,2));
maxNback  = min(finalTbin) - (tbinTest+1);

ballY = ballY(:,(end-maxNback):end);

fitIntercept = true;

if 0
    load("./data/neural_states_normalized.mat","brainStates")
    load("./data/dspm_states_normalized_1000neurons.mat","dspmStates")
    load("./data/rnn_states_normalized_analysisSubset.mat","paddleStates")
    load("./data/rnn_states_normalized_analysisSubset.mat","nextTPstates")
    load("./data/ballState_states_normalized.mat","ballStates")
end

systemCell = {
    {brainStates} , "brain"     
    dspmStates    , "dSPM"  
    paddleStates  , "paddle"    
    nextTPstates  , "nextTP"   
    {ballStates}  , "ballStates"
    };

systemStates = systemCell(:,1);
syskey       = string(systemCell(:,2));

tbinTest = 250/50; % ms -> tbin conversion

% squeeze each system to [ntrials x nvars] at the readout bin
states = struct();
for s = 1:height(systemStates)
    states.(syskey(s)) = cellfun(@(m) m(:,:,tbinTest), ...
                                 systemStates{s}, 'UniformOutput', false);
end


%% Run Neural Data

brainState = states.brain{1};

% true performance, firmed up over repeats
[decoder_performance, decoder_std, beta_weights] = ...
    temporal_linear_decoder_bs(brainState,ballY,true,10,false);

brain_mtp_data = struct();
brain_mtp_data.decoder_performance = decoder_performance;
brain_mtp_data.decoder_std         = decoder_std;
brain_mtp_data.beta_weights        = beta_weights;

% null: many shuffles
[decoder_performance_null, decoder_std_null, beta_weights_null] =...
    temporal_linear_decoder_bs(brainState,ballY,true,100,true);

brain_mtp_data_shuffled = struct();
brain_mtp_data_shuffled.decoder_performance = decoder_performance_null;
brain_mtp_data_shuffled.decoder_std         = decoder_std_null;
brain_mtp_data_shuffled.beta_weights        = beta_weights_null;

save("./mtp_data_output/brain_mtp_decoding_data.mat",...
    "brain_mtp_data",...
    "brain_mtp_data_shuffled")


%% Run dSPM models

nmdls    = numel(dspmStates);
dataout  = cell(nmdls,3);
dataout_shuffled  = cell(nmdls,3);

for i = 1:nmdls

    statesIn = states.dSPM{i};

    % true performance, firmed up over repeats
    [decoder_performance, decoder_std, beta_weights] = ...
    temporal_linear_decoder_bs(statesIn,ballY,true,10,false);
    
    dataout{i,1} = decoder_performance;
    dataout{i,2} = decoder_std;
    dataout{i,3} = beta_weights;
    
    % null: many shuffles
    [decoder_performance_null, decoder_std_null, beta_weights_null] =...
        temporal_linear_decoder_bs(statesIn, ballY,true,100,true);
    
    dataout_shuffled{i,1} = decoder_performance_null;
    dataout_shuffled{i,2} = decoder_std_null;
    dataout_shuffled{i,3} = beta_weights_null;
    

end

dspm_mtp_data = struct();
dspm_mtp_data.decoder_performance = dataout(:,1);
dspm_mtp_data.decoder_std         = dataout(:,2);
dspm_mtp_data.beta_weights        = dataout(:,3);

dspm_mtp_data_shuffled = struct();
dspm_mtp_data_shuffled.decoder_performance = dataout_shuffled(:,1);
dspm_mtp_data_shuffled.decoder_std         = dataout_shuffled(:,2);
dspm_mtp_data_shuffled.beta_weights        = dataout_shuffled(:,3);

save("./mtp_data_output/dspm_mtp_decoding_data.mat",...
    "dspm_mtp_data",...
    "dspm_mtp_data_shuffled")

%% Run paddle only RNNs


nmdls    = numel(paddleStates);
dataout  = cell(nmdls,3);
dataout_shuffled  = cell(nmdls,3);

for i = 1:nmdls

    statesIn = states.paddle{i};

    % true performance, firmed up over repeats
    [decoder_performance, decoder_std, beta_weights] = ...
    temporal_linear_decoder_bs(statesIn,ballY,true,10,false);
    
    dataout{i,1} = decoder_performance;
    dataout{i,2} = decoder_std;
    dataout{i,3} = beta_weights;
    
    % null: many shuffles
    [decoder_performance_null, decoder_std_null, beta_weights_null] =...
        temporal_linear_decoder_bs(statesIn,ballY,true,100,true);
    
    dataout_shuffled{i,1} = decoder_performance_null;
    dataout_shuffled{i,2} = decoder_std_null;
    dataout_shuffled{i,3} = beta_weights_null;
    

end

paddle_mtp_data = struct();
paddle_mtp_data.decoder_performance = dataout(:,1);
paddle_mtp_data.decoder_std         = dataout(:,2);
paddle_mtp_data.beta_weights        = dataout(:,3);

paddle_mtp_data_shuffled = struct();
paddle_mtp_data_shuffled.decoder_performance = dataout_shuffled(:,1);
paddle_mtp_data_shuffled.decoder_std         = dataout_shuffled(:,2);
paddle_mtp_data_shuffled.beta_weights        = dataout_shuffled(:,3);


save("./mtp_data_output/paddle_mtp_decoding_data.mat",...
    "paddle_mtp_data",...
    "paddle_mtp_data_shuffled")

%% Run next time point (nextTP) RNNs


nmdls    = numel(nextTPstates);
dataout  = cell(nmdls,3);
dataout_shuffled  = cell(nmdls,3);

for i = 1:nmdls

    statesIn = states.nextTP{i};

    % true performance, firmed up over repeats
    [decoder_performance, decoder_std, beta_weights] = ...
    temporal_linear_decoder_bs(statesIn,ballY,true,10,false);
    
    dataout{i,1} = decoder_performance;
    dataout{i,2} = decoder_std;
    dataout{i,3} = beta_weights;
    
    % null: many shuffles
    [decoder_performance_null, decoder_std_null, beta_weights_null] =...
        temporal_linear_decoder_bs(statesIn,ballY,true,100,true);
    
    dataout_shuffled{i,1} = decoder_performance_null;
    dataout_shuffled{i,2} = decoder_std_null;
    dataout_shuffled{i,3} = beta_weights_null;
    

end

nextTP_mtp_data = struct();
nextTP_mtp_data.decoder_performance = dataout(:,1);
nextTP_mtp_data.decoder_std         = dataout(:,2);
nextTP_mtp_data.beta_weights        = dataout(:,3);

nextTP_mtp_data_shuffled = struct();
nextTP_mtp_data_shuffled.decoder_performance = dataout_shuffled(:,1);
nextTP_mtp_data_shuffled.decoder_std         = dataout_shuffled(:,2);
nextTP_mtp_data_shuffled.beta_weights        = dataout_shuffled(:,3);

save("./mtp_data_output/nextTP_mtp_decoding_data.mat",...
    "nextTP_mtp_data",...
    "nextTP_mtp_data_shuffled")

%% Run ballState model
ballState250 = states.ballStates{1};

% true performance, firmed up over repeats
[decoder_performance, decoder_std, beta_weights] = ...
temporal_linear_decoder_bs(ballState250,ballY,true,10,false);


dataout = {decoder_performance,...
           decoder_std,...
           beta_weights};

% null: many shuffles
[decoder_performance_null, decoder_std_null, beta_weights_null] =...
    temporal_linear_decoder_bs(ballState250,ballY,true,100,true);

dataout_shuffled = {decoder_performance_null,...
                    decoder_std_null,...
                    beta_weights_null};

ballState_mtp_data = struct();
ballState_mtp_data.decoder_performance = dataout(:,1);
ballState_mtp_data.decoder_std         = dataout(:,2);
ballState_mtp_data.beta_weights        = dataout(:,3);

ballState_mtp_data_shuffled = struct();
ballState_mtp_data_shuffled.decoder_performance = dataout_shuffled(:,1);
ballState_mtp_data_shuffled.decoder_std         = dataout_shuffled(:,2);
ballState_mtp_data_shuffled.beta_weights        = dataout_shuffled(:,3);

save("./mtp_data_output/ballState_mtp_decoding_data.mat",...
    "ballState_mtp_data",...
    "ballState_mtp_data_shuffled")


%%

function [decoder_performance, decoder_std, beta_weights, perf_reps] = ...
    temporal_linear_decoder_bs(state_data, predvecs, fitIntercept, nrep, shuffleBaseline)
% Nested-CV ridge, SVD path form. One thin SVD per training set serves the
% whole lambda grid in closed form.
%
% fitIntercept    (optional, default true) : center X,y on the TRAIN fold
%                   (unpenalized bias); false forces the fit through origin.
% nrep            (optional, default 1)    : repeats of the whole outer CV,
%                   each with a fresh partition. Scores pooled over all
%                   outer_k*nrep folds. Use ~10 to firm up the estimate.
% shuffleBaseline (optional, default false): permute predvec across
%                   conditions once per repeat -> per-timepoint null. Use a
%                   large nrep (e.g. 200-1000) to build the null distribution.
%
% perf_reps [ntpts x nrep x 3] : each repeat's fold-mean [R, R^2, MSE].
%                   With shuffleBaseline=true this IS the null distribution.

    arguments
        state_data       double
        predvecs         double  
        fitIntercept     (1,1) logical  = true
        nrep             (1,1) double   = 10
        shuffleBaseline  (1,1) logical  = false
    end


    [nneurons, ntrials, ~] = size(state_data);

    ntpts_decode = size(predvecs,2);
    decoder_performance = zeros(ntpts_decode, 3);
    decoder_std  = zeros(ntpts_decode, 3);
    beta_weights = zeros(nneurons, ntpts_decode);
    perf_reps    = zeros(ntpts_decode, nrep, 3);

    lambda_values = logspace(-2, 2, 10);

    outer_k = 5;
    inner_k = 4;

    X  = state_data'; % [ntrials x nneurons]
    parfor t = 1:ntpts_decode

        fprintf('\t%d/%d\n', t, ntpts_decode)
        y0 = predvecs(:,t);    % base target (shuffled per rep below)

        pooled    = zeros(outer_k * nrep, 3);
        rep_means = zeros(nrep, 3);
        beta      = zeros(nneurons, 1);

        for rep = 1:nrep

            % break X-y correspondence -> null
            if shuffleBaseline, y = y0(randperm(ntrials));  
            else,y = y0;end

            outer_cv = cvpartition(ntrials, 'KFold', outer_k);   % fresh each rep
            fold_performance = zeros(outer_k, 3);

            for outer_fold = 1:outer_k

                train_idx = training(outer_cv, outer_fold);
                test_idx  = test(outer_cv, outer_fold);
                X_train = X(train_idx, :);
                y_train = y(train_idx);
                X_test  = X(test_idx, :);
                y_test  = y(test_idx);

                % Inner loop: score every lambda from ONE svd of the inner-train set
                inner_cv = cvpartition(numel(y_train), 'KFold', inner_k);
                lambda_scores = zeros(numel(lambda_values), 1);

                for inner_fold = 1:inner_k
                    itr = training(inner_cv, inner_fold);
                    ivl = test(inner_cv, inner_fold);

                    [U,s,V,mux,muy] = ridge_fit_svd(X_train(itr,:), y_train(itr), fitIntercept);
                    Xv_c = X_train(ivl,:) - mux;
                    P    = Xv_c * V;                       % [nval x r]
                    Uty  = U' * (y_train(itr) - muy);      % [r x 1]

                    yv   = y_train(ivl);
                    for li = 1:numel(lambda_values)
                        coef = s ./ (s.^2 + lambda_values(li));
                        yhat = P * (coef .* Uty) + muy;
                        lambda_scores(li) = lambda_scores(li) + corr(yhat, yv);
                    end
                end
                lambda_scores = lambda_scores / inner_k;

                % Best lambda, refit on full outer-train via the same path
                [~, bi] = max(lambda_scores);
                optimal_lambda = lambda_values(bi);

                [U,s,V,mux,muy] = ridge_fit_svd(X_train, y_train, fitIntercept);
                coef = s ./ (s.^2 + optimal_lambda);
                w    = V * (coef .* (U' * (y_train - muy)));

                y_pred = (X_test - mux) * w + muy;

                fold_performance(outer_fold, 1) = corr(y_pred, y_test);          % R
                fold_performance(outer_fold, 2) = corr(y_pred, y_test)^2;        % R^2
                fold_performance(outer_fold, 3) = mean((y_pred - y_test).^2);    % MSE

                beta = w;
            end

            pooled((rep-1)*outer_k + (1:outer_k), :) = fold_performance;
            rep_means(rep, :) = mean(fold_performance, 1);
        end

        decoder_performance(t,:) = mean(pooled, 1);
        decoder_std(t,:)  = std(pooled, [], 1) / sqrt(outer_k * nrep);
        perf_reps(t,:,:)  = reshape(rep_means, 1, nrep, 3);
        beta_weights(:,t) = beta;
    end

end


function [U,s,V,mux,muy] = ridge_fit_svd(Xtr, ytr, fitIntercept)
    % Center on train (if fitIntercept), thin SVD. Returns factors for the path:
    %   w(lam) = V * diag( s/(s^2+lam) ) * (U' * (ytr - muy)),  intercept = muy

    if fitIntercept
        mux = mean(Xtr, 1);
        muy = mean(ytr);
    else
        mux = zeros(1, size(Xtr,2));
        muy = 0;
    end

    Xc = Xtr - mux;
    [U,S,V] = svd(Xc, 'econ');
    s = diag(S);
    tol = max(size(Xc)) * eps(max(s));
    keep = s > tol;                         % drop null directions (n << p here)
    U = U(:,keep);
    s = s(keep);
    V = V(:,keep);
end


