%% =====================================================================
%  LDA GEOMETRY — ANALYSIS  (two-stage: LOCATE then CHARACTERIZE)
%
%  Splits the analysis half out of lda_geometry_analysis.m and restructures
%  it into two clean stages so selection and inference cannot contaminate
%  each other.
%
%  STAGE 1 — LOCATE  (all 79 trials, NO resampling)
%    For every PC-pair p and time-bin t, fit the two in-plane axes and score
%    the in-sample factorial (4-quadrant) accuracy. (p*, t*) = argmax acc.
%    This is where the four-condition structure you see in the raw PCA lives;
%    using all data (not held-out) means the choice can't chase bootstrap
%    noise onto the wrong pair. FIXED_PAIRS pins DMFC=(3,4), dSPM=(1,2); the
%    search still runs and reports whether it AGREES with the pinned pair.
%
%  STAGE 2 — CHARACTERIZE  (bootstrap ONLY at the fixed p*, t*)
%    Stratified-within-class trial resamples -> refit {v1,v2}_k -> theta_k.
%    Headline = median{theta_k} with [2.5, 97.5] percentile CI. This reports
%    the DISTRIBUTION of the angle, not the angle of the mean axes.
%    Null = marginal shuffle (permute bounce, hold ẏ) at p*,t*.
%    Plus per-bin theta(t) and separation(t) bootstrap ribbons on the fixed
%    pair, so DMFC's transient (~250 ms) vs dSPM's flat ≈90° is legible.
%    theta(t) is only interpretable where sep(t) is up (gated in the plotter).
%
%  Two Fisher-style axes (centroid-difference; no Sw^-1), NEUTRALLY NAMED:
%    v1 — ẏ-sign   contrast:  mean{+ẏ}  − mean{−ẏ}   = mean{1,3} − mean{2,4}
%    v2 — approach contrast:  mean{+app}− mean{−app} = mean{1,4} − mean{2,3}
%  approach = ẏ-sign XOR bounce = ball's final vertical direction at the paddle.
%  v1 and approach are CORRELATED in the stimulus (equal on the 53 no-bounce
%  trials, flipped on the 26 bounce trials), so orthogonalising them is the
%  non-trivial computation theta(v1,v2)->90° detects. (Bounce vs ẏ-sign are
%  ~independent -> generically wide angle for every system -> not diagnostic.)
%
%  4 classes = the 2×2 factorial (fixed index mapping, saved as CLASS_DEF):
%    1:{+ẏ,¬bounce}  2:{−ẏ,¬bounce}  3:{+ẏ,bounce}  4:{−ẏ,bounce}
%
%  Requires read_pca_js.m on the path.  Writes lda_results.mat.
% =====================================================================

rng(0, 'twister');            % reproducible selection + resampling

%% ── Read workspace variables from pca_data.js ────────────────────────
JS_FILE = 'pca_data.js';
S = read_pca_js(JS_FILE);

tvec_bs     = S.tvec_bs;
sys_labels  = S.sys_labels;
sys_colors  = S.sys_colors;
nSystems    = S.nSystems;
bounce_wall = S.bounce_wall;
endpoint_y  = S.endpoint_y;
all_traj    = S.all_traj;
all_expl    = S.all_expl;

if isfield(S,'ydot0') && ~isempty(S.ydot0)
    pacc_idx = S.ydot0 > 0;
else
    warning('ydot0 not in JS — using endpoint_y proxy. Re-run export_pca_data.m.');
    pacc_idx = endpoint_y > 0;
end

fprintf('\n===== LDA geometry (two-stage): v1=ẏ-sign, v2=approach =====\n');

%% ── Parameters ───────────────────────────────────────────────────────
EPOCH_IDX = 1;         % all_traj epoch (0–300 ms onset PCA basis)
nPC_MAX   = 8;         % top-N PCs -> C(N,2) candidate pairs
TBIN_WIN  = 1:20;      % time bins scored / shown (0–1000 ms)
TBIN_MAX_MS = 500;     % PREBOUNCE CAP: (p*,t*) search restricted to t ≤ this.
                       %   Earliest first bounce = 550 ms; capping at 500 keeps
                       %   every searched bin bounce-free, so the post-bounce ẏ
                       %   flip can't leak into v2/approach (this is what let
                       %   ballState wander to a spurious 700 ms peak). Ribbons
                       %   are still computed/shown over the full TBIN_WIN.

B_THETA   = 2000;      % Stage-2 bootstrap (theta_k dist, CI, ribbons, paired)
B_NULL    = 2000;      % marginal-shuffle null at (p*, t*)
B_NULL_TC = 1000;      % per-bin marginal-shuffle null for the theta(t) gate

SEP_GATE_FRAC = 0.5;   % plotter greys theta(t) where sep(t) < frac * max sep

% CLASS_SIGNS: expected sign-quadrant per class, columns = [v1 sign, v2 sign]
%   v1 = +1 for +ẏ (1,3);  v2 = +1 for +approach (1,4)
CLASS_SIGNS = [ +1  +1;    % 1: +ẏ, ¬bounce  -> +approach
                -1  -1;    % 2: −ẏ, ¬bounce  -> −approach
                +1  -1;    % 3: +ẏ,  bounce  -> −approach
                -1  +1 ];  % 4: −ẏ,  bounce  -> +approach
CLASS_DEF = {'+ẏ, ¬bounce', '−ẏ, ¬bounce', '+ẏ, bounce', '−ẏ, bounce'};

% Fixed pairs from independent PCA inspection. Systems not listed are searched.
FIXED_PAIRS = containers.Map();
% FIXED_PAIRS('Brain (DMFC)') = [3 4];
% FIXED_PAIRS('dSPM')         = [1 2];

%% ── Build 4-class labels (bounce × ẏ-sign) ───────────────────────────
n_ref        = size(all_traj{EPOCH_IDX,1}, 3);
vel_up       = pacc_idx(1:n_ref)';                 % [n×1] logical, true = +ẏ
if isfield(S,'bounceIdx') && ~isempty(S.bounceIdx)
    is_bnc = logical(S.bounceIdx(1:n_ref))';
else
    warning('bounceIdx not in JS — falling back to bounce_wall>0.');
    is_bnc = bounce_wall(1:n_ref)' > 0;
end

labels4 = make_labels4(is_bnc, vel_up);
assert(all(labels4>0), 'a trial fell through all 4 classes (ydot0==0?)');
fprintf('4-class counts: [+ẏ¬b]=%d [−ẏ¬b]=%d [+ẏb]=%d [−ẏb]=%d\n', ...
    sum(labels4==1),sum(labels4==2),sum(labels4==3),sum(labels4==4));

% Shared stratified-within-class bootstrap draws (paired across systems)
cls        = 1:4;
idxByClass = arrayfun(@(c) find(labels4==c), cls, 'UniformOutput', false);
boot_idx   = zeros(B_THETA, n_ref);
for b = 1:B_THETA
    d = [];
    for c = 1:4
        ic = idxByClass{c};  m = numel(ic);
        d  = [d; ic(randi(m,[m,1]))]; %#ok<AGROW>
    end
    boot_idx(b,:) = d';
end

%% =====================================================================
%  STAGE 1 (locate) + STAGE 2 (characterize), per system
% =====================================================================
geo_results = struct();
theta_bs    = nan(B_THETA, nSystems);   % assembled for paired diffs (shared draws)

for si = 1:nSystems
    fprintf('\n[%d/%d] %s\n', si, nSystems, sys_labels{si});
    traj = all_traj{EPOCH_IDX, si};

    geo_results(si).system    = sys_labels{si};
    geo_results(si).CLASS_DEF = CLASS_DEF;

    if isempty(traj)
        fprintf('  SKIPPED (no data)\n');
        nw = numel(TBIN_WIN);
        geo_results(si).best_pair='N/A'; geo_results(si).best_pci=NaN; geo_results(si).best_pcj=NaN;
        geo_results(si).search_pair='N/A'; geo_results(si).search_agrees=false;
        geo_results(si).wi_star=1; geo_results(si).tb_star=TBIN_WIN(1); geo_results(si).t_star_ms=NaN;
        geo_results(si).acc_star=NaN; geo_results(si).X2d_peak=[]; geo_results(si).labs=labels4;
        geo_results(si).v1_pk=[NaN;NaN]; geo_results(si).v2_pk=[NaN;NaN];
        geo_results(si).p_v1_pk=[]; geo_results(si).p_v2_pk=[]; geo_results(si).theta_insample=NaN;
        geo_results(si).theta_hat=NaN; geo_results(si).theta_ci=[NaN NaN]; geo_results(si).theta_boot=[];
        geo_results(si).theta_null=[]; geo_results(si).theta_null_band=[NaN NaN NaN]; geo_results(si).theta_null_p=NaN;
        geo_results(si).tvec_win=tvec_bs(TBIN_WIN); geo_results(si).theta_t=nan(nw,3);
        geo_results(si).sep_t=nan(nw,3); geo_results(si).theta_null_t95=nan(nw,1);
        geo_results(si).acc_grid=[]; geo_results(si).theta_grid=[]; geo_results(si).pairs_si=[]; geo_results(si).best_pi=NaN;
        continue
    end

    nPC_si = min(nPC_MAX, size(traj,1));
    traj   = traj(1:nPC_si, :, :);
    [~, n_tbins, n_tr] = size(traj);
    assert(n_tr == n_ref, 'system %d has %d trials, expected %d.', si, n_tr, n_ref);
    labs   = labels4;

    pairs_si  = nchoosek(1:nPC_si, 2);
    nPairs_si = size(pairs_si,1);
    n_win     = numel(TBIN_WIN);

    % ── STAGE 1: in-sample factorial-accuracy grid over (pair, bin) ───
    acc_grid   = nan(nPairs_si, n_win);
    theta_grid = nan(nPairs_si, n_win);
    for wi = 1:n_win
        tb = TBIN_WIN(wi);  if tb > n_tbins, continue; end
        X_all = squeeze(traj(:, tb, :))';
        if any(isnan(X_all(:))), continue; end
        for pi = 1:nPairs_si
            st = plane_stats(X_all(:, pairs_si(pi,:)), labs, CLASS_SIGNS);
            acc_grid(pi,wi)   = st.acc;
            theta_grid(pi,wi) = st.theta;
        end
    end

    % Restrict SELECTION to the prebounce window (ribbons stay full-range)
    win_ms = tvec_bs(TBIN_WIN);
    sel_ok = win_ms(:)' <= TBIN_MAX_MS;              % [1 × n_win]
    acc_sel = acc_grid;  acc_sel(~isfinite(acc_sel)) = -inf;
    acc_sel(:, ~sel_ok) = -inf;

    % Free argmax over the (prebounce) grid (validation target)
    [~, lin_free] = max(acc_sel(:));
    [pi_free, wi_free] = ind2sub(size(acc_sel), lin_free);
    pair_free = pairs_si(pi_free,:);

    % Apply FIXED_PAIRS (search still ran, for the agreement check)
    if isKey(FIXED_PAIRS, sys_labels{si})
        fp   = sort(FIXED_PAIRS(sys_labels{si}));
        pi_s = find(pairs_si(:,1)==fp(1) & pairs_si(:,2)==fp(2), 1);
        assert(~isempty(pi_s), 'fixed pair [%d %d] not available for %s (nPC=%d).', ...
            fp(1), fp(2), sys_labels{si}, nPC_si);
        best_pi = pi_s;
        [~, wi_star] = max(acc_sel(best_pi,:));       % best PREBOUNCE bin at fixed pair
        agrees = isequal(sort(pair_free), fp);
        fprintf('  FIXED pair PC%d–PC%d | search argmax PC%d–PC%d  ->  %s\n', ...
            fp(1),fp(2), pair_free(1),pair_free(2), ...
            ternary(agrees,'AGREE','DISAGREE (search differs)'));
    else
        best_pi = pi_free;  wi_star = wi_free;  agrees = true;
        fprintf('  SEARCH pair PC%d–PC%d\n', pair_free(1), pair_free(2));
    end

    pci = pairs_si(best_pi,1);  pcj = pairs_si(best_pi,2);
    tb_star = TBIN_WIN(wi_star);
    fprintf('  (p*,t*) = PC%d–PC%d @ %.0f ms   in-sample acc=%.0f%%\n', ...
        pci, pcj, tvec_bs(tb_star), acc_grid(best_pi,wi_star)*100);

    % Peak-bin scores + in-sample axes (for the scatter figure)
    X2d_star = squeeze(traj([pci pcj], tb_star, :))';   % [n×2]
    st_in    = plane_stats(X2d_star, labs, CLASS_SIGNS);

    % ── STAGE 2a: theta_k distribution at (p*, t*), shared draws ──────
    thk = nan(B_THETA,1);
    for b = 1:B_THETA
        ix = boot_idx(b,:);
        thk(b) = theta_of(X2d_star(ix,:), labs(ix));
    end
    theta_bs(:,si) = thk;
    theta_hat = median(thk, 'omitnan');
    theta_ci  = pctl(thk, [2.5 97.5]);

    % ── STAGE 2b: marginal-shuffle null at (p*, t*) ──────────────────
    nb = nan(B_NULL,1);
    for b = 1:B_NULL
        lb = make_labels4(is_bnc(randperm(n_ref)), vel_up);   % permute bounce, hold ẏ
        nb(b) = theta_of(X2d_star, lb);
    end
    theta_null_band = pctl(nb, [2.5 50 97.5]);
    theta_null_p    = mean(nb >= theta_hat);

    % ── STAGE 2c: theta(t) and sep(t) ribbons on the FIXED pair ──────
    th_t  = nan(n_win, 3);  sep_t = nan(n_win, 3);  null_t95 = nan(n_win,1);
    for wi = 1:n_win
        tb = TBIN_WIN(wi);  if tb > n_tbins, continue; end
        Xt = squeeze(traj([pci pcj], tb, :))';
        if any(isnan(Xt(:))), continue; end
        tb_boot = nan(B_THETA,1);  sp_boot = nan(B_THETA,1);
        for b = 1:B_THETA
            ix = boot_idx(b,:);
            [tb_boot(b), sp_boot(b)] = theta_sep(Xt(ix,:), labs(ix));
        end
        th_t(wi,:)  = pctl(tb_boot, [2.5 50 97.5]);
        sep_t(wi,:) = pctl(sp_boot, [2.5 50 97.5]);
        nn = nan(B_NULL_TC,1);
        for b = 1:B_NULL_TC
            lb = make_labels4(is_bnc(randperm(n_ref)), vel_up);
            nn(b) = theta_of(Xt, lb);
        end
        null_t95(wi) = pctl(nn, 95);
    end

    % ── Store ─────────────────────────────────────────────────────────
    geo_results(si).acc_grid     = acc_grid;
    geo_results(si).theta_grid   = theta_grid;
    geo_results(si).pairs_si     = pairs_si;
    geo_results(si).best_pi      = best_pi;
    geo_results(si).best_pair    = sprintf('PC%d–PC%d', pci, pcj);
    geo_results(si).best_pci     = pci;
    geo_results(si).best_pcj     = pcj;
    geo_results(si).search_pair  = sprintf('PC%d–PC%d', pair_free(1), pair_free(2));
    geo_results(si).search_agrees= agrees;
    geo_results(si).wi_star      = wi_star;
    geo_results(si).tb_star      = tb_star;
    geo_results(si).t_star_ms    = tvec_bs(tb_star);
    geo_results(si).acc_star     = acc_grid(best_pi, wi_star);   % in-sample
    geo_results(si).X2d_peak     = X2d_star;
    geo_results(si).labs         = labs;
    geo_results(si).v1_pk        = st_in.v1;
    geo_results(si).v2_pk        = st_in.v2;
    geo_results(si).p_v1_pk      = X2d_star * st_in.v1;
    geo_results(si).p_v2_pk      = X2d_star * st_in.v2;
    geo_results(si).theta_insample = st_in.theta;
    geo_results(si).theta_hat    = theta_hat;
    geo_results(si).theta_ci     = theta_ci;
    geo_results(si).theta_boot   = thk;
    geo_results(si).theta_null   = nb;
    geo_results(si).theta_null_band = theta_null_band;
    geo_results(si).theta_null_p = theta_null_p;
    geo_results(si).tvec_win     = tvec_bs(TBIN_WIN(TBIN_WIN <= n_tbins));
    geo_results(si).theta_t      = th_t;      % [n_win × (2.5,50,97.5)]
    geo_results(si).sep_t        = sep_t;
    geo_results(si).theta_null_t95 = null_t95;

    fprintf('  theta_hat = %.1f°  [%.1f, %.1f]   null 95th=%.1f°   p=%.3f\n', ...
        theta_hat, theta_ci(1), theta_ci(2), theta_null_band(3), theta_null_p);
end

%% ── Paired DMFC − control differences (shared draws) ─────────────────
findsys = @(pat) find(~cellfun(@isempty, regexpi(sys_labels, pat, 'once')), 1);
di = findsys('DMFC');  bi = findsys('Ball\s*State');  ni = findsys('nextTP');
paired = struct();
if ~isempty(di) && ~isempty(bi)
    d = theta_bs(:,di) - theta_bs(:,bi);
    paired.dmfc_minus_ballstate = d;
    paired.ci_ballstate = pctl(d,[2.5 97.5]);  paired.p_ballstate = mean(d<=0);
end
if ~isempty(di) && ~isempty(ni)
    d = theta_bs(:,di) - theta_bs(:,ni);
    paired.dmfc_minus_nexttp = d;
    paired.ci_nexttp = pctl(d,[2.5 97.5]);  paired.p_nexttp = mean(d<=0);
end

%% ── Summary table ────────────────────────────────────────────────────
fprintf('\n%-16s  %-11s  %-9s  %6s  %-18s  %7s  %7s\n', ...
    'System','pair (p*)','vs search','t* ms','theta med [95% CI]','null95','p(null)');
fprintf('%s\n', repmat('-',1,92));
for si = 1:nSystems
    r = geo_results(si);
    if ~isfield(r,'theta_hat') || isnan(r.theta_hat), continue; end
    tag = 'search';
    if isKey(FIXED_PAIRS, sys_labels{si})
        tag = ternary(r.search_agrees, 'fix=agree', 'fix≠search');
    end
    fprintf('%-16s  %-11s  %-9s  %6.0f  %5.1f [%4.1f,%4.1f]  %7.1f  %7.3f\n', ...
        r.system, r.best_pair, tag, r.t_star_ms, ...
        r.theta_hat, r.theta_ci(1), r.theta_ci(2), r.theta_null_band(3), r.theta_null_p);
end
fprintf('\nPaired Δtheta (DMFC − control), shared stratified draws:\n');
if isfield(paired,'dmfc_minus_ballstate')
    fprintf('  DMFC − Ball State : %+5.1f°  [%+.1f, %+.1f]   p=%.3f\n', ...
        median(paired.dmfc_minus_ballstate), paired.ci_ballstate, paired.p_ballstate);
end
if isfield(paired,'dmfc_minus_nexttp')
    fprintf('  DMFC − nextTP RNN : %+5.1f°  [%+.1f, %+.1f]   p=%.3f\n', ...
        median(paired.dmfc_minus_nexttp), paired.ci_nexttp, paired.p_nexttp);
end

%%

di, bi, ni                                   % which columns the block picked
sys_labels(:)'                               % what order the systems are in
median(theta_bs, 1, 'omitnan')               % should reproduce the theta column: 70, 82, 19, 52, 68

%% ── Save ─────────────────────────────────────────────────────────────
save('lda_results.mat', 'geo_results', 'paired', 'theta_bs', ...
     'sys_labels', 'sys_colors', 'nSystems', 'tvec_bs', 'TBIN_WIN', ...
     'CLASS_SIGNS', 'CLASS_DEF', 'SEP_GATE_FRAC', 'TBIN_MAX_MS', '-v7.3');
fprintf('\nSaved lda_results.mat  →  run lda_plots.m.\n');


%% =====================================================================
%  LOCAL FUNCTIONS
% =====================================================================

function st = plane_stats(X2d, labs, CS)
%PLANE_STATS  In-sample axes + factorial accuracy + separation on a 2D plane.
    st = struct('v1',[NaN;NaN],'v2',[NaN;NaN],'theta',NaN,'acc',NaN,'sep',NaN);
    v1p=labs==1|labs==3; v1n=labs==2|labs==4;       % +ẏ vs −ẏ
    v2p=labs==1|labs==4; v2n=labs==2|labs==3;       % +approach vs −approach
    if ~any(v1p)||~any(v1n)||~any(v2p)||~any(v2n), return; end
    w1=(mean(X2d(v1p,:),1)-mean(X2d(v1n,:),1))';
    w2=(mean(X2d(v2p,:),1)-mean(X2d(v2n,:),1))';
    n1=norm(w1); n2=norm(w2); if n1<eps||n2<eps, return; end
    w1=w1/n1; w2=w2/n2; st.v1=w1; st.v2=w2;
    st.theta = acosd(min(abs(w1'*w2),1));
    p1=X2d*w1; p2=X2d*w2; nc=0;
    for k=1:4
        ik=labs==k; if ~any(ik), continue; end
        nc = nc + sum(sign(p1(ik))==CS(k,1) & sign(p2(ik))==CS(k,2));
    end
    st.acc = nc/numel(labs);
    st.sep = sep_index(X2d, labs);
end

function [th, sp] = theta_sep(X2d, labs)
%THETA_SEP  Angle(v1,v2) and separation index — hot-loop version (no acc).
    th = theta_of(X2d, labs);
    sp = sep_index(X2d, labs);
end

function th = theta_of(X2d, labs)
%THETA_OF  Acute angle between v1 (ẏ-sign) and v2 (approach) axes, in deg.
    v1p=labs==1|labs==3; v1n=labs==2|labs==4;
    v2p=labs==1|labs==4; v2n=labs==2|labs==3;
    if ~any(v1p)||~any(v1n)||~any(v2p)||~any(v2n), th=NaN; return; end
    w1=mean(X2d(v1p,:),1)-mean(X2d(v1n,:),1); n1=norm(w1);
    w2=mean(X2d(v2p,:),1)-mean(X2d(v2n,:),1); n2=norm(w2);
    if n1<eps||n2<eps, th=NaN; return; end
    th = acosd(min(abs((w1/n1)*(w2/n2)'),1));
end

function s = sep_index(X2d, labs)
%SEP_INDEX  d'-style, arrangement-agnostic: mean centroid→grand-mean distance
%  over pooled within-class RMS spread. Isolates "how separated" from
%  "how arranged", so it doesn't contaminate theta.
    gm = mean(X2d,1); btw = 0; wss = 0; nk = 0;
    for k=1:4
        ik=labs==k; if ~any(ik), continue; end
        ck = mean(X2d(ik,:),1);
        btw = btw + norm(ck-gm);  nk = nk+1;
        wss = wss + sum(sum((X2d(ik,:)-ck).^2, 2));
    end
    if nk==0, s=NaN; return; end
    within = sqrt(wss/numel(labs));
    if within<eps, s=NaN; else, s=(btw/nk)/within; end
end

function labs = make_labels4(is_bnc, vel_up)
    labs = zeros(numel(is_bnc),1);
    labs(~is_bnc &  vel_up) = 1;   % +ẏ, ¬bounce
    labs(~is_bnc & ~vel_up) = 2;   % −ẏ, ¬bounce
    labs( is_bnc &  vel_up) = 3;   % +ẏ,  bounce
    labs( is_bnc & ~vel_up) = 4;   % −ẏ,  bounce
end

function y = pctl(x, p)
%PCTL  Percentile via linear interpolation, NaNs dropped. No toolbox needed.
    x = sort(x(~isnan(x(:))));
    if isempty(x), y = nan(size(p)); return; end
    n = numel(x);  h = (n-1)*(p(:)/100) + 1;
    lo = min(max(floor(h),1),n);  hi = min(max(ceil(h),1),n);
    y = x(lo) + (h - floor(h)).*(x(hi) - x(lo));
    y = reshape(y, size(p));
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
