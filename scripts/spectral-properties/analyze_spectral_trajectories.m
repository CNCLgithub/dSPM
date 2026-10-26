%% ANALYZE_SPECTRAL_TRAJECTORIES  (v4)
% Leading eigenvalue of the programmed adjacency, evaluated at the reservoir's
% current state, along every trial of the legacy Pong reservoirs.
%
% Why v3
%   The legacy runs integrate every condition for the same 100 bins so that
%   the model matches the neural data and the alternative models in length.
%   The real trials are shorter (the longest ends at bin 71) and differ in
%   length. With no paddle the ball's horizontal position keeps growing after
%   the trial ends, which drives the reservoir out of its stable operating
%   range. Everything after a trial's true end must be excluded.
%
% What it does
%   - Labels (bounce / no-bounce) come from rishi_data.nbounces.
%   - States are unbinned (network_states_raw), N x T per condition.
%   - Each condition is analysed only inside its valid window. The window is
%     taken from netrun.trial_mask when a usable per-condition mask or length
%     is found there; otherwise it is the stable range of the trace itself
%     (up to one bin before the leading eigenvalue first exceeds lead_thr).
%     The source used is printed. CHECK that the longest window is ~71 bins.
%   - Within the valid window of a bounce condition, the bounce is the first
%     direction-switch flip in the readout W*r(t).
%   - parfor runs over conditions. run_network() uses parfor internally, so it
%     is called in a plain for-loop over networks.
%
% Quantity
%   lead(t) = largest real part of eig( diag(g(t)) * Ap ),
%   g(t)    = gradient of tanh at the current state, 1 - tanh(Ap*r + d).^2
%   A mode grows when lead > 1, is held at 1, and decays below 1.

%% 0. Settings

addpath("../create-dspm-networks/")

run_dir    = fullfile('../../hpc-outputs/programmed-networks', ...
                      '28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b', 'rnn-states');
rishi_file = "../../data/brain_and_rishi_data.mat";
files      = dir(fullfile(run_dir, 'prnn-states-id*.mat'));

nets_to_run = 1:numel(files);    % e.g. 1:2 for a first pass
gain_mode   = 'input';           % 'input': g = 1 - tanh(Ap*r + d).^2 ;  'state': g = 1 - r.^2
lead_thr    = 3;                 % fallback only: "left the stable range" when lead exceeds this
                                 % (a collision peaks near 1.1 to 1.2; a breakdown is > 100)
bin_ms      = 50;                % duration of one bin, for axis labels
rise_thr    = 1.0005;            % eigenvalue above this counts as part of the rise before a bounce
                                 % (the resting value is 1 to within ~2e-4)
row_vy      = 2;                 % readout row holding the ball's speed toward the top/bottom walls
rank_tol    = 1e-8;

%% 1. Labels from the dataset

S          = load(rishi_file, "rishi_data");
bounceMask = logical(S.rishi_data.nbounces(:));
fprintf('labels: bounce %d, no-bounce %d (of %d)\n', nnz(bounceMask), nnz(~bounceMask), numel(bounceMask));

%% 2. Loop over networks (plain for-loop: run_network uses parfor internally)

nNet = numel(nets_to_run);
R    = struct('netnum', [], 'coarse', [], 'fine', [], 'bstep', [], 'vend', [], ...
              'cgrid', [], 'win', [], 'spb', [], 'vsrc', "", ...
              'slope', [], 'speed', [], 'status', []);
R    = repmat(R, nNet, 1);

for ii = 1:nNet
    a      = load(fullfile(files(nets_to_run(ii)).folder, files(nets_to_run(ii)).name));
    netrun = a.prnn_validation.run_network();

    prnn = netrun.progrnn.prnn;
    Ap   = prnn.A;    d = prnn.d(:);    W = netrun.W;    N = size(Ap, 1);

    % unbinned states, N x T
    states = netrun.network_states_raw;
    for c = 1:numel(states)
        if size(states{c}, 1) ~= N && size(states{c}, 2) == N, states{c} = states{c}.'; end
    end
    nCond = numel(states);
    assert(nCond == numel(bounceMask), 'condition count does not match the labels');
    Tlen  = cellfun(@(s) size(s, 2), states);    Tlen = Tlen(:);
    Tmax  = max(Tlen);

    burn  = netrun.binned_states_raw.burninTime;
    nbTot = size(netrun.binned_states_raw.modelStates{1}, 2);     % bins incl. burn-in
    spb   = round(Tmax / (nbTot - burn));                         % integration steps per bin
    K     = spb;                                                  % plateau separation for flips
    win   = 4 * spb;                                              % aligned window: +/- 4 bins
    cgrid = 1:max(1, round(spb / 5)):Tmax;    nC = numel(cgrid);    nF = 2 * win + 1;

    % factorize Ap once: Ap = Uk * SVk  (rank 12)
    [U, Sg, V] = svd(Ap, 'econ');
    sg  = diag(Sg);
    k   = nnz(sg > rank_tol * sg(1));
    Uk  = U(:, 1:k);
    SVk = Sg(1:k, 1:k) * V(:, 1:k)';

    % ---- pass 1: whole-trace leading eigenvalue on the coarse grid ---------
    coarse_all = nan(nCond, nC);
    parfor c = 1:nCond
        ci  = cgrid(cgrid <= Tlen(c));
        row = nan(1, nC);
        row(1:numel(ci)) = lead_at(states{c}(:, ci), Uk, SVk, d, gain_mode);
        coarse_all(c, :) = row;
    end

    % ---- valid window per condition (integration steps) --------------------
    [len_bins, vsrc, first_bin] = lengths_from_mask(netrun, nCond);
    stab = nan(nCond, 1);                         % stable range from the trace itself
    for c = 1:nCond
        j = find(coarse_all(c, :) > lead_thr, 1);
        if isempty(j), stab(c) = Tlen(c); else, stab(c) = max(1, cgrid(j) - spb); end
    end
    if isempty(len_bins)
        vend = stab;    vsrc = "stable range of the trace (lead_thr)";
    else
        vend = min(Tlen, round(len_bins(:) * spb));
    end
    vend = min(vend, stab);                       % never analyse past a breakdown

    % ---- pass 2: bounce step, and fine window around it --------------------
    bstep = nan(nCond, 1);   nEv = zeros(nCond, 1);   frows = cell(nCond, 1);
    parfor c = 1:nCond
        Y        = W * states{c}(:, 1:vend(c));
        [tc, rw] = collision_events(Y, K);
        nEv(c)   = numel(tc);
        b = NaN;   fr = [];
        if bounceMask(c) && ~isempty(tc), b = tc(1);  fr = rw{1};  end
        bstep(c) = b;   frows{c} = fr;
    end

    ref   = round(median(bstep(bounceMask), 'omitnan'));     % matched step for no-bounce trials
    align = bstep;
    for c = find(~bounceMask)'
        align(c) = min(ref, vend(c) - win);
        if align(c) < 1 + win, align(c) = NaN; end
    end

    fine = nan(nCond, nF);
    parfor c = 1:nCond
        fr = nan(1, nF);
        if ~isnan(align(c))
            idx = align(c) + (-win:win);
            ok  = idx >= 1 & idx <= vend(c);
            if any(ok), fr(ok) = lead_at(states{c}(:, idx(ok)), Uk, SVk, d, gain_mode); end
        end
        fine(c, :) = fr;
    end

    % ---- pass 3: slope of the rise before each bounce, and the ball's speed --
    % Every bounce condition is analysed from the start of its trial to just
    % after its bounce, so early bounces and slow balls are included.
    rslope = nan(nCond, 1);   rspeed = nan(nCond, 1);   rstat = strings(nCond, 1);
    parfor c = 1:nCond
        sl = NaN;   sp = NaN;   stt = "";
        if bounceMask(c) && ~isnan(bstep(c))
            steps = 1:min(vend(c), bstep(c) + spb);
            Rt    = states{c}(:, steps);
            tr    = lead_at(Rt, Uk, SVk, d, gain_mode);      % leading eigenvalue, every step
            rel   = steps - bstep(c);                         % steps relative to the bounce
            Y     = W * Rt;
            if any(rel < -30), sp = mean(abs(Y(row_vy, rel < -30))); end
            [sl, stt] = rise_slope(tr, rel, rise_thr);
            sl = sl / (bin_ms / spb);                         % per ms
        end
        rslope(c) = sl;   rspeed(c) = sp;   rstat(c) = stt;
    end

    coarse = coarse_all;                          % keep only the valid window
    for c = 1:nCond, coarse(c, cgrid > vend(c)) = NaN; end

    R(ii).netnum = a.netnum;   R(ii).coarse = coarse;   R(ii).fine = fine;
    R(ii).bstep  = bstep;      R(ii).vend   = vend;     R(ii).cgrid = cgrid;
    R(ii).win    = win;        R(ii).spb    = spb;      R(ii).vsrc  = vsrc;
    R(ii).slope  = rslope;     R(ii).speed  = rspeed;   R(ii).status = rstat;

    fprintf(['net %2d | T = %d, %d steps/bin | window: %s, %d to %d bins\n' ...
             '        bounce found %d/%d (rows %s) | no-bounce trials with an event: %d/%d\n' ...
             '        median lead %.4f | peak near bounce %.3f | peak, no-bounce trials %.3f\n'], ...
            a.netnum, Tmax, spb, vsrc, round(min(vend) / spb), round(max(vend) / spb), ...
            nnz(~isnan(bstep(bounceMask))), nnz(bounceMask), mat2str(unique([frows{bounceMask}])), ...
            nnz(nEv(~bounceMask) > 0), nnz(~bounceMask), ...
            median(coarse(:), 'omitnan'), max(max(fine(bounceMask, :))), max(max(coarse(~bounceMask, :))));
    fprintf('        first valid bin in mask: %s | rise fitted in %d/%d bounce conditions\n', ...
            mat2str([min(first_bin), max(first_bin)]), nnz(rstat == "fitted"), nnz(bounceMask));
end

%% 3. Summary across networks (one mean per network, then across networks)

win  = R(1).win;   spb = R(1).spb;   lags = -win:win;
mB   = nan(nNet, numel(lags));   mNB = mB;
for ii = 1:nNet
    mB(ii, :)  = mean(R(ii).fine( bounceMask, :), 1, 'omitnan');
    mNB(ii, :) = mean(R(ii).fine(~bounceMask, :), 1, 'omitnan');
end
pkB  = arrayfun(@(r) mean(max(r.fine( bounceMask, :), [], 2), 'omitnan'), R);
pkNB = arrayfun(@(r) mean(max(r.coarse(~bounceMask, :), [], 2), 'omitnan'), R);
allc = cat(1, R.coarse);

% rise slope vs ball speed: one value per bounce condition per network
SL = [R.slope];   SP = [R.speed];                       % nCond x nNet
bcAll   = find(bounceMask);
slope_m = mean(SL(bcAll, :), 2, 'omitnan');   slope_s = std(SL(bcAll, :), 0, 2, 'omitnan');
speed_m = mean(SP(bcAll, :), 2, 'omitnan');
kNet    = nan(nNet, 1);                                 % proportionality constant per network (fit through the origin)
for ii = 1:nNet
    okk = ~isnan(SL(bcAll, ii)) & ~isnan(SP(bcAll, ii));
    kNet(ii) = sum(SP(bcAll(okk), ii) .* SL(bcAll(okk), ii)) / sum(SP(bcAll(okk), ii).^2);
end

fprintf('\nAcross %d networks (valid windows only)\n', nNet);
fprintf('  share of sampled steps with lead within 0.01 of 1: %.3f\n', mean(abs(allc(~isnan(allc)) - 1) < 0.01));
fprintf('  peak lead near the bounce (mean over bounce trials): %.3f +/- %.3f across networks\n', mean(pkB),  std(pkB));
fprintf('  peak lead in no-bounce trials:                       %.3f +/- %.3f across networks\n', mean(pkNB), std(pkNB));
okm = ~isnan(slope_m) & ~isnan(speed_m);
fprintf('  rise slope vs ball speed (condition means): r = %.3f, n = %d of %d bounce conditions\n', ...
        corr(speed_m(okm), slope_m(okm)), nnz(okm), numel(bcAll));
fprintf('  slope / speed, per network: %.3e +/- %.1e\n', mean(kNet, 'omitnan'), std(kNet, 'omitnan'));
fprintf('  largest s.d. of a condition''s slope across networks: %.1e (mean slope %.1e)\n', max(slope_s), mean(slope_m, 'omitnan'));

%% 4. Figure

ms  = bin_ms / spb;                                   % ms per integration step
ex  = 1;                                              % example network
bb  = R(ex).bstep;   cg = R(ex).cgrid;
cEx = find(bounceMask & ~isnan(bb), 1);               % example bounce condition
[~, order] = sortrows([~bounceMask, bb]);             % bounce conditions first, by bounce time

figure('Color', 'w', 'Position', [100 100 1100 700]);
tiledlayout(2, 2, 'TileSpacing', 'compact');

% A. one bounce trial
nexttile; hold on
plot(cg * ms, R(ex).coarse(cEx, :), 'LineWidth', 1.2);
plot((bb(cEx) + lags) * ms, R(ex).fine(cEx, :), 'LineWidth', 1.5);
yline(1, ':');   xline(bb(cEx) * ms, '--');
xlabel('time from trial start (ms)');   ylabel('leading eigenvalue (max Re)');
title(sprintf('A. One bounce trial (net %d, condition %d)', R(ex).netnum, cEx));

% B. all conditions of one network, valid window only
nexttile; hold on
M = R(ex).coarse(order, :);
imagesc(cg * ms, 1:numel(bb), M, 'AlphaData', ~isnan(M));
axis ij tight;   colorbar;
nb = nnz(bounceMask);
plot(bb(order(1:nb)) * ms, 1:nb, 'k.', 'MarkerSize', 6);
xlabel('time from trial start (ms)');   ylabel('condition (bounce first, by bounce time)');
title(sprintf('B. All conditions (net %d)', R(ex).netnum));

% C. aligned to the bounce: mean over trials per network, then across networks
nexttile; hold on
shade(lags * ms, mB,  [0.80 0.30 0.20]);
shade(lags * ms, mNB, [0.40 0.40 0.40]);
yline(1, ':');   xline(0, '--');
xlabel('time from bounce (ms)');   ylabel('leading eigenvalue (max Re)');
legend({'', 'bounce', '', 'no bounce (matched time)'}, 'Location', 'best');
title(sprintf('C. Aligned to the bounce (mean \\pm s.d. across %d networks)', nNet));

% D. distribution of all sampled values
nexttile;
histogram(allc(:), 100);   set(gca, 'YScale', 'log');   xline(1, ':');
xlabel('leading eigenvalue (max Re)');   ylabel('sampled steps (log scale)');
title('D. All networks and conditions');

%% 5. Save

out_file = fullfile(run_dir, '..', 'spectral_trajectories.mat');
save(out_file, 'R', 'bounceMask', 'mB', 'mNB', 'lags', 'gain_mode', 'bin_ms', 'slope_m', 'slope_s', 'speed_m', 'kNet');
fprintf('Saved %s\n', out_file);


%% ============================ local functions ============================

function [len_bins, src, first_bin] = lengths_from_mask(netrun, nCond)
% Per-condition trial lengths (in bins) from netrun.trial_mask, stored as a
% condition-by-bin mask, a cell of masks, or a vector of lengths.
% The length is the NUMBER of valid bins, last - first + 1. (v3 used the last
% valid bin as the length, which overran every trial when the valid region
% does not start at bin 1.) first_bin returns where the valid region starts.
% Returns [] if nothing usable is found.
    len_bins = [];   src = "";   first_bin = NaN;
    try, tm = netrun.trial_mask; catch, return, end
    if ~isstruct(tm), return, end
    fn = fieldnames(tm);
    for i = 1:numel(fn)
        v = tm.(fn{i});   L = [];   F = nan(nCond, 1);
        if iscell(v) && numel(v) == nCond
            [F, La] = cellfun(@valid_span, v(:));
            L = La - F + 1;
        elseif (isnumeric(v) || islogical(v)) && ismatrix(v) && ~isvector(v) && any(size(v) == nCond)
            if size(v, 1) ~= nCond, v = v.'; end
            [F, La] = arrayfun(@(r) valid_span(v(r, :)), (1:nCond)');
            L = La - F + 1;
        elseif isnumeric(v) && isvector(v) && numel(v) == nCond
            L = double(v(:));
        end
        if isempty(L) || any(~isfinite(L)) || any(L < 1), continue, end
        if numel(unique(L)) > 1                           % a real per-condition quantity
            len_bins = L;   first_bin = F;   src = "trial_mask." + string(fn{i});   return
        end
    end
end

function [f, l] = valid_span(m)
% first and last valid entry of a mask (valid = nonzero and not NaN)
    m = m(:);   ok = ~isnan(m) & m ~= 0;
    f = find(ok, 1, 'first');   l = find(ok, 1, 'last');
    if isempty(f), f = NaN;   l = NaN; end
end

function [slope, status] = rise_slope(tr, rel, thr)
% Slope (per step) of the rise in the leading eigenvalue that precedes a bounce.
%   tr   leading eigenvalue at each step, from trial start to just after the bounce
%   rel  step index relative to the bounce
% The rise is the longest run above thr before the spike (rel < -30) that does
% not run into the spike. Only its initial, linear part (up to 70% of its
% height) is fitted.
    slope = NaN;
    ps = find(rel < -30);
    if isempty(ps), status = "bounce at trial start"; return, end
    above = tr(ps) > thr;
    dd    = diff([0, above, 0]);
    s     = find(dd == 1);   e = find(dd == -1) - 1;
    keep  = e < numel(ps);                               % a run reaching the edge is the spike's onset
    s     = s(keep);   e = e(keep);
    if isempty(s), status = "no rise above threshold"; return, end
    [~, j]     = max(e - s);
    run        = ps(s(j):e(j));
    h          = tr(run) - 1;
    [hmax, pk] = max(h);
    lin        = find(h(1:pk) <= 0.7 * hmax);
    if numel(lin) < 5, status = "rise too short to fit"; return, end
    p      = polyfit(rel(run(lin)), tr(run(lin)), 1);
    slope  = p(1);
    status = "fitted";
end

function [tc, rows] = collision_events(Y, K)
% Direction-switch flips in the readout Y (nOut x T), grouped into events.
% A flip is a zero crossing between two plateaus of opposite sign, each at
% least half the row's maximum magnitude, K steps either side.
    T   = size(Y, 2);
    amp = max(abs(Y), [], 2);
    evt = [];   evr = [];
    for j = find(amp > 0.05 * max(amp))'
        y  = Y(j, :);
        zc = find(y(1:end-1) .* y(2:end) < 0);
        for z = zc
            p = max(1, z - K);   q = min(T, z + 1 + K);
            if sign(y(p)) ~= sign(y(q)) && abs(y(p)) > 0.5 * amp(j) && abs(y(q)) > 0.5 * amp(j)
                evt(end+1) = z + 1;   evr(end+1) = j; %#ok<AGROW>
            end
        end
    end
    tc = [];   rows = {};
    if isempty(evt), return, end
    [evt, o] = sort(evt);   evr = evr(o);
    grp = cumsum([1, diff(evt) > 2 * K]);
    for g = 1:grp(end)
        tc(g)   = round(median(evt(grp == g)));      %#ok<AGROW>
        rows{g} = unique(evr(grp == g));             %#ok<AGROW>
    end
end

function lead = lead_at(Rt, Uk, SVk, d, gain_mode)
% Largest real part of eig(diag(g) * Ap) at each column of Rt, using Ap = Uk*SVk.
    if strcmp(gain_mode, 'input')
        G = 1 - tanh(Uk * (SVk * Rt) + d).^2;
    else
        G = 1 - Rt.^2;
    end
    nT   = size(Rt, 2);
    lead = nan(1, nT);
    for t = 1:nT
        lead(t) = max(real(eig(SVk * (G(:, t) .* Uk))));
    end
end

function shade(x, M, col)
% mean +/- s.d. band across the rows of M
    m  = mean(M, 1, 'omitnan');   sd = std(M, 0, 1, 'omitnan');
    fill([x, fliplr(x)], [m - sd, fliplr(m + sd)], col, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, m, 'Color', col, 'LineWidth', 1.5);
end