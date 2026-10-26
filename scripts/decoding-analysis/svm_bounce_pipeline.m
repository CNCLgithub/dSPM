function svm_bounce_pipeline
%% SVM bounce-classification pipeline (formal). Saves per-model data; plot with
%% plot_svm_bounce.m.  (Script form: run individual %% model cells if you like.)
%
% Classifies model state -> {no-bounce=0, bounce=1} with a LINEAR SVM, reporting
% BALANCED ACCURACY (chance 0.5 despite the 26/53 imbalance).
%
%   time-course : balanced accuracy vs state-vector time (context; fixed C, fast)
%   marginal    : average each condition's state over the PRE-COLLISION window
%                 [250,500] ms (earliest real bounce = 550 ms) -> one feature
%                 vector per condition, classify once. Nested-CV C, matched CV
%                 splits across models, permutation null.
%
% From the marginal BA[rep x instance] grid (one nested-CV pass, AUC folded in)
% we derive two views:
%   instBA [nInst x 1]  mean over reps, per instance   -> the VISUAL (violins)
%   repBA  [NREP  x 1]  mean over instances, per split  -> the TEST statistic
% Matched splits (outerCV, built once from labels) make repBA paired across
% models, so the plotter can run a paired signed-rank test of each model vs DMFC.

%% ---- setup ----
load("../../data/brain_and_rishi_data.mat","rishi_data")
labels = double(rishi_data.nbounces(:) > 0);          % 0 no-bounce, 1 bounce
fprintf("no-bounce %d   bounce %d   majority-class acc %.3f\n", ...
    sum(labels==0), sum(labels==1), max(mean(labels==0), mean(labels==1)));

NT   = 28;
T0MS = 0;    % abs time of bin 1 

% matched outer CV partitions (depend on labels only)
NREP  = 100;  % CV repetitions
NFOLD = 5;    % 5-fold = 80/20 train/test
rng(0);
outerCV = cell(NREP,1);
for r = 1:NREP, outerCV{r} = cvpartition(labels, "KFold", NFOLD); end

opts = struct();
opts.nt       = NT;
opts.t0       = T0MS;
opts.marginMs = [250 500]; % time bins used in marginal

% descriptive time-waveform curve
opts.curve = struct( ...
    nrep   = 10                 , ...
    maxInst= 50                 , ...
    boxC   = 1                  , ...
    nestC  = false              , ...
    cGrid  = [0.01 0.1 1 10 100], ...
    innerK = 3                  , ...
    nfold  = NFOLD);   

% nperm small: null pinned to chance
opts.marg  = struct( ...
            nrep   = NREP               , ...
            maxInst= Inf                , ...
            cGrid  = [0.01 0.1 1 10 100], ...
            innerK = 3                  , ...
            nperm  = 50                 , ...
            boxC   = 1                  , ...
            nfold  = NFOLD);  

%% ---- Brain ----
disp("Running Neural Data...")
load("./data/neural_states_normalized.mat","brainStates")
save_sb("brain", svm_bounce(brainStates, labels, outerCV, opts))

%% ---- dSPM ----
disp("Running dSPM models...")
load("./data/dspm_states_normalized_1000neurons.mat","dspmStates")
save_sb("dspm_1000neurons", svm_bounce(dspmStates, labels, outerCV, opts))

%% ---- Next-time-point RNNs ----
disp("Running Next Timepoint Models...")
load("./data/rnn_states_normalized_analysisSubset.mat","nextTPstates")
save_sb("nextTP", svm_bounce(nextTPstates, labels, outerCV, opts))

%% ---- Paddle-only RNNs ----
disp("Running Paddle Only Models...")
load("./data/rnn_states_normalized_analysisSubset.mat","paddleStates")
save_sb("paddle", svm_bounce(paddleStates, labels, outerCV, opts))

%% ---- BallState / Linear Map ----
disp("Running Ball State Data...")
load("./data/ballStates_states_normalized.mat","ballStates")
save_sb("ballState", svm_bounce(ballStates, labels, outerCV, opts))
end
%% ============================ driver ============================

function sb = svm_bounce(states, labels, outerCV, opts)

    getT = @(s) size(s,3);
    
    if iscell(states)
          T = min(cellfun(getT, states)); 
    else, T = getT(states); 
    end
    
    nt = opts.nt;  if isempty(nt) || nt > T, nt = T; end
    
    tvec  = opts.t0 + (0:nt-1)*50;
    wmask = tvec >= opts.marginMs(1) & tvec <= opts.marginMs(2);
    
    % compute time-varying SVM computation
    [baCurve, baCurveStd] = curve_ba(states, labels, nt, opts.curve);   % time-course
    
    % window-averaged features for marginal calculation
    Xw = get_early_features(states, wmask, opts.marg.maxInst); 
    
    % run marginal permutations
    [repBA, instBA, auc] = marginal_grid(Xw, labels, outerCV, opts.marg);
    nullBA               = marginal_null(Xw, labels, opts.marg);
    
    % oraganize into output structure
    sb = struct();
    
    sb.baCurve    = baCurve;    % [nt x 1]
    sb.baCurveStd = baCurveStd; % [nt x 1]
    sb.repBA      = repBA;      % [NREP x 1]
    sb.instBA     = instBA;     % [nInst x 1]
    sb.nullBA     = nullBA;     % [nperm x 1]
    sb.auc        = auc;        % scalar
    
    sb.diag = struct( ...
        nBounce   = sum(labels==1), ...
        nNoBounce = sum(labels==0), ...
        marginMs  = opts.marginMs , ...
        nt        = nt            , ...
        binMs     = 50            , ...
        nInst     = numel(instBA) , ...
        nWinBins  = sum(wmask) );


end


function save_sb(name, sb)

    outdir = "./svm_bounce_output";

    if ~isfolder(outdir), mkdir(outdir); end

    save(fullfile(outdir, name + "_svm_bounce.mat"), "sb");
    
    fprintf("saved %s   BA=%.3f  AUC=%.3f\n", ...
        name, mean(sb.instBA), sb.auc);

end


%% ============================ marginal ============================

function [repBA, instBA, auc] = marginal_grid(Xw, labels, outerCV, m)
% One nested-CV pass per (split, instance) -> BA and AUC grids; 
% repBA  = mean over instances per split (test stat)
% instBA = mean over reps per instance (visual). 
% auc    = grand-mean AUC.

    if ~iscell(Xw), Xw = {Xw}; end
    
    nouter = numel(outerCV);  
    nInst  = numel(Xw);
    
    BA  = zeros(nouter, nInst);  % balanced accuracy
    AUC = zeros(nouter, nInst);  % area under the curve
    
    parfor r = 1:nouter
    
        cv = outerCV{r};
        ba = zeros(1,nInst);  au = zeros(1,nInst);
    
        for i = 1:nInst
    
            [yhat, sc] = nested_cv_predict(Xw{i}, labels, cv, m.cGrid, m.innerK);
            ba(i) = bal_acc(labels, yhat);
            au(i) = auc_from_scores(labels, sc);
    
        end
    
        BA(r,:) = ba;  AUC(r,:) = au;
    
    end

    repBA  = mean(BA, 2);
    instBA = mean(BA, 1).';
    auc    = mean(AUC(:), "omitnan");

end


function nullBA = marginal_null(Xw, labels, m)
% Permutation null (fixed C): 
% shuffle labels, mean BA over instances.

    if ~iscell(Xw), Xw = {Xw}; end

    nInst  = numel(Xw);  
    nperm  = m.nperm;  
    boxc   = m.boxC;
    nullBA = zeros(nperm,1);

    parfor p = 1:nperm

        ys = labels(randperm(numel(labels)));
        cv = cvpartition(ys, "KFold", m.nfold);
        b  = zeros(nInst,1);

        for i = 1:nInst
            yhat = fixed_cv_predict(Xw{i}, ys, cv, boxc);
            b(i) = bal_acc(ys, yhat);
        end

        nullBA(p) = mean(b);
    end

end


%% ============================ time-course ============================

function [mu, band] = curve_ba(states, labels, nt, c)

    if iscell(states)

        n = min(numel(states), c.maxInst);  
        M = zeros(nt,n);

        for i = 1:n
            fprintf("\t instance %d/%d ...\n", i, n)
            M(:,i) = one_curve(states{i}, labels, nt, c);
        end

        mu = mean(M,2,"omitnan");  band = std(M,0,2,"omitnan");
    else
        [mu, band] = one_curve(states, labels, nt, c);
    end

    mu = mu(:);  band = band(:);

end


function [mu, sd] = one_curve(state3d, labels, nt, c)

    % unpack control options
    nrep   = c.nrep;  
    nestC  = c.nestC;  
    boxc   = c.boxC;  
    cGrid  = c.cGrid;  
    innerK = c.innerK;  
    nfold  = c.nfold;

    mu = zeros(nt,1);  
    sd = zeros(nt,1);
    parfor t = 1:nt

        X  = state3d(:,:,t).';
        ba = zeros(nrep,1);

        for rep = 1:nrep

            cv = cvpartition(labels, "KFold", nfold);
            if nestC, yhat = nested_cv_predict(X, labels, cv, cGrid, innerK);
            else,     yhat = fixed_cv_predict(X, labels, cv, boxc); end

            ba(rep) = bal_acc(labels, yhat);
        end
        mu(t) = mean(ba,"omitnan");  
        sd(t) = std(ba,"omitnan");
    end

end


%% ============================ svm cores ============================

function [yhat, sc] = nested_cv_predict(X, labels, cv, cGrid, innerK)
% pooled held-out labels + scores 
% nested-CV C per outer fold
    n    = numel(labels);  
    yhat = nan(n,1);  
    sc   = nan(n,1);
    
    for k = 1:cv.NumTestSets
    
        tr = training(cv,k);  
        te = test(cv,k);
        C  = pick_c(X(tr,:), labels(tr), cGrid, innerK);
    
        mdl = fitcsvm( ...
            X(tr,:), labels(tr)           , ...
            KernelFunction = "linear", ...
            BoxConstraint  = C       , ...
            Standardize    = true);
    
        [lab, s] = predict(mdl, X(te,:));
        yhat(te) = lab;  
        sc(te)   = s(:,2);
    
    end

end


function [yhat, sc] = fixed_cv_predict(X, labels, cv, boxc)
% pooled held-out labels + scores, fixed C
    n    = numel(labels);  
    yhat = nan(n,1);  
    sc   = nan(n,1);
    for k = 1:cv.NumTestSets

        tr = training(cv,k);  
        te = test(cv,k);

        mdl = fitcsvm( ...
            X(tr,:), labels(tr)           , ...
            KernelFunction = "linear", ...
            BoxConstraint  = boxc    , ...
            Standardize    = true);

        [lab, s] = predict(mdl, X(te,:));
        yhat(te) = lab;  
        sc(te)   = s(:,2);

    end

end


function C = pick_c(X, labels, cGrid, innerK)
% inner-CV pick of BoxConstraint by balanced accuracy
    icv  = cvpartition(labels, "KFold", innerK);
    best = -inf;  
    C    = cGrid(1);

    for ci = 1:numel(cGrid)

        yh = nan(numel(labels),1);

        for k = 1:innerK
            tr = training(icv,k);  
            te = test(icv,k);
            mdl = fitcsvm( ...
                    X(tr,:), labels(tr)           , ...
                    KernelFunction = "linear", ...
                    BoxConstraint  = cGrid(ci)    , ...
                    Standardize    = true);

            yh(te) = predict(mdl, X(te,:));
        end

        b = bal_acc(labels, yh);
        if b > best, best = b;  C = cGrid(ci); end

    end

end


function X = get_early_features(states, wmask, maxInst)

    avgW = @(s) squeeze(mean(s(:,:,wmask), 3)).';   % [ncond x nneurons]
    if iscell(states)
        n = min(numel(states), maxInst);  X = cell(n,1);
        for i = 1:n, X{i} = avgW(states{i}); end
    else
        X = avgW(states);
    end

end


function b = bal_acc(labels, yhat)

    p = labels == 1;  
    n = labels == 0;
    b = (mean(yhat(p) == 1) + mean(yhat(n) == 0)) / 2;

end


function a = auc_from_scores(labels, sc)

    if numel(unique(labels)) < 2 || all(isnan(sc)), a = NaN; 
    return; end

    [~,~,~,a] = perfcurve(labels, sc, 1);

end