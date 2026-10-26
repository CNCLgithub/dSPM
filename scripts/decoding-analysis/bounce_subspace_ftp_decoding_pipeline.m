function bounce_subspace_ftp_decoding_pipeline
%% Condition-subspace FTP decoding: within AND between, one pipeline, one file.
% For each model and each state-vector time bin, decode the ball's FINAL
% endpoint (FTP) four ways against the SAME globally z-scored target, with the
% SAME ridge estimator (fit_ridge_cv -> ridge_fit_svd), SAME lambda grid, SAME
% bin convention:
%
%   withinBounce      train+test WITHIN bounce   (nested-CV, pooled held-out r)
%   withinNoBounce    train+test WITHIN no-bounce (nested-CV, pooled held-out r)
%   crossToBounce     train no-bounce -> test bounce      (test-set bootstrap)
%   crossToNoBounce   train bounce    -> test no-bounce   (test-set bootstrap)
%
% Running all four in one pass off one load removes every cross-FILE source of
% disparity (different masks, different normalized-state files, different
% z-scoring), so any within-vs-cross gap is a within-vs-cross gap, not an
% artifact of mismatched inputs.
%
% WITHIN scoring note: r is computed on POOLED held-out predictions (each
% condition predicted exactly once per rep), so it is the SAME quantity as the
% cross full-group r -- length, range and target all matched. The per-fold mean
% r (paper bars) is also kept as repR_foldwise.
%
% Each model saves ./condition_subspace_ftp_output/<name>_condition_subspace_ftp_decoding.mat
% holding one struct `cs_data`.

%% ---- setup ----
load("../../data/brain_and_rishi_data.mat","rishi_data")

% ONE endpoint target, z-scored ONCE over all conditions -> within/cross share
% the exact same scale, so RMSE (col 3) is comparable across analyses too.
predvec = zscore(rishi_data.ball_pos_final(:));

% ONE bounce mask (the field the within/paper pipeline used). Confirm nbounces
% is per-condition AND row-aligned to predvec / the states' condition axis.
bounceMask = logical(rishi_data.nbounces(:));
assert(numel(bounceMask) == numel(predvec), "mask/target length mismatch")
assert(sum(bounceMask) > 0 && sum(~bounceMask) > 0, "need both groups non-empty")
fprintf("bounce: %d   no-bounce: %d   (of %d)\n", ...
    sum(bounceMask), sum(~bounceMask), numel(bounceMask));
fprintf("endpoint std (z): bounce %.3f   no-bounce %.3f\n", ...
    std(predvec(bounceMask)), std(predvec(~bounceMask)));

opts = struct( ...
    nrep        = 100, ...          % within: CV reps;  cross: test bootstraps
    ntptsDecode = 28,  ...          % bin horizon ([] = all bins; clamps to data)
    lambda      = logspace(-2,2,10), ...
    inner_k     = 4,   ...          % lambda inner CV
    outer_k     = 2,   ...          % within outer CV (2 = 50/50 train/test)
    nTrainCap   = 26);              % [] = use all training conds. Set to match
                                    % training N across cross directions (and the
                                    % within decoders): see suggestion below.
fprintf("set opts.nTrainCap = %d to match training size across directions " + ...
    "(= smaller group)\n", min(sum(bounceMask), sum(~bounceMask)));

%% ---- Brain ----
load("./data/neural_states_normalized.mat","brainStates")
cs_data = condition_subspace_ftp(brainStates, predvec, bounceMask, opts);
save_cs("brain", cs_data)

%% ---- dSPM ----
load("../../data/dspm_states_normalized_1000neurons.mat","dspmStates")
cs_data = condition_subspace_ftp(dspmStates, predvec, bounceMask, opts);
save_cs("dspm", cs_data)

%% ---- Next-time-point RNNs ----
load("./data/rnn_states_normalized_analysisSubset.mat","nextTPstates")
cs_data = condition_subspace_ftp(nextTPstates, predvec, bounceMask, opts);
save_cs("nextTP", cs_data)

%% ---- Paddle-only RNNs ----
load("./data/rnn_states_normalized_analysisSubset.mat","paddleStates")
cs_data = condition_subspace_ftp(paddleStates, predvec, bounceMask, opts);
save_cs("paddle", cs_data)

%% ---- BallState / Linear Map ----
load("./data/ballStates_states_normalized.mat","ballStates")
cs_data = condition_subspace_ftp(ballStates, predvec, bounceMask, opts);
save_cs("ballState", cs_data)

end

%% ============================ driver ============================

function cs = condition_subspace_ftp(states, predvec, bounceMask, opts)
% All four analyses for one model (3D array) or many instances (cell of those).
nrep = opts.nrep;  lam = opts.lambda;  ik = opts.inner_k;  ok = opts.outer_k;
ntc = opts.nTrainCap;

getT = @(s) size(s, 3);
if iscell(states), T = min(cellfun(getT, states)); else, T = getT(states); end
nt = opts.ntptsDecode;
if isempty(nt) || nt > T, nt = T; end

% closures bind the shared knobs so the packers only vary states + mask
wb = @(s) within_pooled_ftp(s, predvec,  bounceMask, nrep, lam, ik, ok, nt, ntc);
wn = @(s) within_pooled_ftp(s, predvec, ~bounceMask, nrep, lam, ik, ok, nt, ntc);
cb = @(s) cross_ftp        (s, predvec, ~bounceMask, nrep, lam, ik,     nt, ntc);  % train ~bounce -> test bounce
cn = @(s) cross_ftp        (s, predvec,  bounceMask, nrep, lam, ik,     nt, ntc);  % train  bounce -> test no-bounce

cs = struct();
cs.withinBounce    = packWithin(states, wb);
cs.withinNoBounce  = packWithin(states, wn);
cs.crossToBounce   = packCross (states, cb);
cs.crossToNoBounce = packCross (states, cn);

cs.diag = struct( ...
    nBounce            = sum(bounceMask), ...
    nNoBounce          = sum(~bounceMask), ...
    endpointStdBounce  = std(predvec(bounceMask)), ...
    endpointStdNoBounce= std(predvec(~bounceMask)), ...
    ntpts              = nt);
cs.meta = struct(readoutMs = 250, binMs = 50, target = "ball_pos_final (global zscore)");
end


function a = packWithin(states, fn)
% [perf, sd, repR(pooled), repR_foldwise, lambdaMed] -> matrix fields, or cells.
a = struct();
if iscell(states)
    n = numel(states);  [P,Sd,RP,RF,LM] = deal(cell(n,1));
    for i = 1:n, [P{i},Sd{i},RP{i},RF{i},LM{i}] = fn(states{i}); end
else
    [P,Sd,RP,RF,LM] = fn(states);
end
a.decoder_performance = P;   % [nt x 3] = [R R^2 MSE], R/MSE on POOLED held-out
a.decoder_std         = Sd;  % [nt x 3] std across reps
a.repR                = RP;  % [nt x nrep] pooled R per rep
a.repR_foldwise       = RF;  % [nt x nrep] per-fold-mean R per rep (paper bars)
a.lambdaMed           = LM;  % [nt x 1] median selected lambda
end


function a = packCross(states, fn)
% [perf, sd, repR(bootstrap), lambdaMed] -> matrix fields, or cells.
a = struct();
if iscell(states)
    n = numel(states);  [P,Sd,RR,LM] = deal(cell(n,1));
    for i = 1:n, [P{i},Sd{i},RR{i},LM{i}] = fn(states{i}); end
else
    [P,Sd,RR,LM] = fn(states);
end
a.decoder_performance = P;   % [nt x 3], R/MSE on the FULL held-out group
a.decoder_std         = Sd;  % [nt x 3] std across test bootstraps
a.repR                = RR;  % [nt x nrep] bootstrap R per rep
a.lambdaMed           = LM;  % [nt x 1] selected lambda (canonical decoder)
end


function save_cs(name, cs_data)
outdir = "./condition_subspace_ftp_output";
if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir, name + "_condition_subspace_ftp_decoding.mat"), "cs_data");
fprintf("saved %s\n", name);
end


%% ============================ decoders ============================

function [perf, sd, repP, repF, lamMed] = ...
    within_pooled_ftp(state3d, y, mask, nrep, lambda, inner_k, outer_k, nt, nTrainCap)
% Nested-CV ridge WITHIN the masked group, sliding the readout bin. Per bin and
% rep: assemble pooled held-out predictions (each condition predicted once) and
% score r/R^2/MSE on the full group -> matched to the cross full-group score.
% Also keep the per-fold mean r (paper-bar quantity).
% nTrainCap : [] -> use the whole outer-train fold; k -> subsample it to k
%             conditions before fitting (match training N to the cross decoders).
    g  = find(mask);
    ng = numel(g);
    yG = y(g);

    perf = zeros(nt,3);  sd = zeros(nt,3);
    repP = zeros(nt,nrep);  repF = zeros(nt,nrep);  lamMed = zeros(nt,1);

    parfor t = 1:nt
        X = state3d(:, g, t).';                     % [ng x nneurons]
        assert(all(isfinite(X(:))), "non-finite state at bin %d", t)

        rP = zeros(nrep,3);  rF = zeros(nrep,1);  lamAll = zeros(nrep*outer_k,1);
        c = 0;
        for rep = 1:nrep
            cv    = cvpartition(ng, "KFold", outer_k);   % fresh partition each rep
            yhat  = nan(ng,1);
            foldR = zeros(outer_k,1);
            for k = 1:outer_k
                trI = find(training(cv,k));  te = test(cv,k);
                if ~isempty(nTrainCap) && nTrainCap < numel(trI)
                    trI = trI(randperm(numel(trI), nTrainCap));   % match training N
                end
                [w, mux, muy, lam] = fit_ridge_cv(X(trI,:), yG(trI), lambda, inner_k, true);
                yp = (X(te,:) - mux) * w + muy;
                yhat(te) = yp;
                foldR(k) = corr(yp, yG(te));
                c = c + 1;  lamAll(c) = lam;
            end
            rr = corr(yhat, yG);                         % pooled full-group r
            rP(rep,:) = [rr, rr^2, mean((yhat - yG).^2)];
            rF(rep)   = mean(foldR, "omitnan");
        end

        perf(t,:)  = mean(rP, 1, "omitnan");
        sd(t,:)    = std(rP, [], 1, "omitnan");
        repP(t,:)  = rP(:,1).';
        repF(t,:)  = rF.';
        lamMed(t)  = median(lamAll(1:c));
    end
end


function [perf, sd, repR, lamMed] = ...
    cross_ftp(state3d, y, trainMask, nrep, lambda, inner_k, nt, nTrainCap)
% Train on trainMask conditions, test on the complement, sliding the readout
% bin. nTrainCap = [] -> canonical decoder on the full training group + nrep
% test-set bootstraps. nTrainCap = k -> each rep subsample the training group to
% k conditions, refit, test on the FULL held-out group (matches training N to
% the other direction; rep spread = training-subsample variability).
    trIdx = find(trainMask);
    teIdx = find(~trainMask);
    nTe   = numel(teIdx);
    nTr   = numel(trIdx);
    useCap = ~isempty(nTrainCap) && nTrainCap < nTr;

    perf = zeros(nt,3);  sd = zeros(nt,3);  repR = zeros(nt,nrep);  lamMed = zeros(nt,1);

    parfor t = 1:nt
        X = state3d(:, :, t).';                     % [ncond x nneurons]
        assert(all(isfinite(X(:))), "non-finite state at bin %d", t)

        rep = zeros(nrep,3);
        if useCap
            yt  = y(teIdx);
            Xte = X(teIdx,:);
            lamRep = zeros(nrep,1);
            for b = 1:nrep
                tr = trIdx(randperm(nTr, nTrainCap));        % match training N
                [w, mux, muy, lam] = fit_ridge_cv(X(tr,:), y(tr), lambda, inner_k, true);
                yp = (Xte - mux) * w + muy;
                r  = corr(yp, yt);
                rep(b,:) = [r, r^2, mean((yp - yt).^2)];
                lamRep(b) = lam;
            end
            lamMed(t) = median(lamRep);
        else
            [w, mux, muy, lam] = fit_ridge_cv(X(trIdx,:), y(trIdx), lambda, inner_k, true);
            for b = 1:nrep
                te = teIdx(randi(nTe, nTe, 1));              % test-set bootstrap
                yp = (X(te,:) - mux) * w + muy;
                yt = y(te);
                r  = corr(yp, yt);
                rep(b,:) = [r, r^2, mean((yp - yt).^2)];
            end
            lamMed(t) = lam;
        end

        perf(t,:) = mean(rep, 1, "omitnan");
        sd(t,:)   = std(rep, [], 1, "omitnan");
        repR(t,:) = rep(:,1).';
    end
end


%% ============================ ridge ============================

function [w, mux, muy, lam] = fit_ridge_cv(X, y, lambda_values, inner_k, fitIntercept)
% Pick lambda by inner k-fold (corr), refit on all of (X,y) via the SVD path.
% Returns the selected lambda too (diagnostic; older callers can ignore it).
    inner_cv = cvpartition(numel(y), "KFold", inner_k);
    lambda_scores = zeros(numel(lambda_values), 1);

    for f = 1:inner_k
        itr = training(inner_cv, f);
        ivl = test(inner_cv, f);
        [U,s,V,mux,muy] = ridge_fit_svd(X(itr,:), y(itr), fitIntercept);
        P   = (X(ivl,:) - mux) * V;
        Uty = U' * (y(itr) - muy);
        yv  = y(ivl);
        for li = 1:numel(lambda_values)
            coef = s ./ (s.^2 + lambda_values(li));
            yhat = P * (coef .* Uty) + muy;
            lambda_scores(li) = lambda_scores(li) + corr(yhat, yv);
        end
    end

    [~, bi] = max(lambda_scores);
    lam = lambda_values(bi);
    [U,s,V,mux,muy] = ridge_fit_svd(X, y, fitIntercept);
    coef = s ./ (s.^2 + lam);
    w = V * (coef .* (U' * (y - muy)));
end


function [U,s,V,mux,muy] = ridge_fit_svd(Xtr, ytr, fitIntercept)
% Center on train (if fitIntercept), thin SVD; factors for the ridge path:
%   w(lam) = V * diag( s/(s^2+lam) ) * (U' * (ytr - muy)),  intercept = muy
    if fitIntercept
        mux = mean(Xtr, 1);
        muy = mean(ytr);
    else
        mux = zeros(1, size(Xtr,2));
        muy = 0;
    end
    Xc = Xtr - mux;
    [U,S,V] = svd(Xc, "econ");
    s = diag(S);
    tol = max(size(Xc)) * eps(max(s));
    keep = s > tol;                             % drop null directions (n << p)
    U = U(:,keep);  s = s(keep);  V = V(:,keep);
end