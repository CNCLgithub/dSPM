%% MAKE_SPECTRAL_FIGURE  (v2)
% Supplementary figure for "Spectral properties of dSPM reservoirs".
%
% Panels
%   A  Three readings of the same connectivity across the 50 Pong reservoirs:
%      rho(Ap), spectral radius at r*, and at the conditional operating points.
%   B  One bounce trial aligned to the bounce: leading eigenvalue, collision
%      detectors, direction-switch pair.
%   C  Leading eigenvalue aligned to the bounce, mean +/- s.d. across reservoirs.
%   D  Slope of the eigenvalue's rise before the bounce vs the ball's speed.
%
% v2
%   - LOAD CHECK (Section 1): nothing is re-run or re-loaded if it is already
%     in the workspace. A reservoir is re-run only when the unbinned states
%     and the quantities that go with them are missing.
%   - Every variable this script creates is prefixed fg_ so it cannot collide
%     with variables left by the analysis scripts (the cause of the earlier
%     scatter error: a 79 x 50 rho_cond left in the workspace).
%
% Workspace variables reused when present
%   from analyze_spectral_distribution :  res
%   from analyze_spectral_trajectories :  R, bounceMask, mB, mNB, lags, bin_ms
%   from the LAST network of that script: states, W, Uk, SVk, d, bstep, spb

%% 0. Settings

fg_run_dir  = fullfile('../../hpc-outputs/programmed-networks', ...
                       '28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b', 'rnn-states');
fg_out_dir  = fullfile(fg_run_dir, '..');

fg_ex_file  = 1;          % reservoir file to re-run, ONLY if states are not in the workspace
fg_ex_cond  = [];         % bounce condition for panel B ([] = median ramp slope; e.g. 39)
fg_row_vy   = 2;   fg_rows_sw = 7:8;   fg_rows_det = 9:12;    % legacy readout rows

% ---- rise detection and plotting window ----
fg_rise_thr = 1.0005;     % leading eigenvalue must exceed this to count as part of the rise
                          %   (the resting value is 1 to within ~2e-4, so this is just above it)
fg_pre_bins = 8;          % width of the PLOTTING window before the bounce in panel B, in 50 ms bins
                          %   (the slope fit uses the whole trial before the bounce, not this window)

fg_col_eig  = [0.15 0.15 0.15];
fg_col_b    = [0.80 0.30 0.20];
fg_col_nb   = [0.45 0.45 0.45];
fg_col_pts  = [0.25 0.50 0.70];
fg_fs       = 11;

%% 1. Load check

% ---- distribution results (panel A) ----------------------------------------
if exist('res', 'var') && isstruct(res) && isfield(res, 'rho_raw') && isfield(res, 'rho_cond')
    fg_res = res;
    fprintf('[load check] distribution results: using "res" from the workspace\n');
else
    fg_tmp = load(fullfile(fg_out_dir, 'spectral_distribution.mat'), 'res');
    fg_res = fg_tmp.res;
    fprintf('[load check] distribution results: loaded spectral_distribution.mat\n');
end

% ---- trajectory results (panel C) ------------------------------------------
fg_need = {'R', 'bounceMask', 'mB', 'mNB', 'lags', 'bin_ms'};
if all(cellfun(@(v) exist(v, 'var') == 1, fg_need)) && isstruct(R) && isfield(R, 'bstep')
    fg_R = R;   fg_mask = bounceMask;   fg_mB = mB;   fg_mNB = mNB;   fg_lags = lags;   fg_bin_ms = bin_ms;
    fprintf('[load check] trajectory results: using workspace variables\n');
else
    fg_tmp = load(fullfile(fg_out_dir, 'spectral_trajectories.mat'));
    fg_R = fg_tmp.R;   fg_mask = fg_tmp.bounceMask;   fg_mB = fg_tmp.mB;   fg_mNB = fg_tmp.mNB;
    fg_lags = fg_tmp.lags;   fg_bin_ms = fg_tmp.bin_ms;
    fprintf('[load check] trajectory results: loaded spectral_trajectories.mat\n');
end

% ---- unbinned states of one reservoir (panels B and D) ---------------------
fg_need = {'states', 'W', 'Uk', 'SVk', 'd', 'bstep', 'spb'};
fg_have = all(cellfun(@(v) exist(v, 'var') == 1, fg_need));
if fg_have
    fg_have = iscell(states) && numel(states) == numel(fg_mask) && numel(bstep) == numel(states) ...
              && any(size(states{1}) == size(Uk, 1)) && size(W, 2) == size(Uk, 1);
end
if fg_have
    fg_states = states;   fg_W = W;   fg_Uk = Uk;   fg_SVk = SVk;   fg_d = d(:);
    fg_bstep  = bstep;    fg_spb = spb;
    fprintf('[load check] unbinned states: using the reservoir already in the workspace (no re-run)\n');
else
    fprintf('[load check] unbinned states: not in the workspace, re-running one reservoir...\n');
    addpath("../create-dspm-networks/")
    fg_files  = dir(fullfile(fg_run_dir, 'prnn-states-id*.mat'));
    fg_a      = load(fullfile(fg_files(fg_ex_file).folder, fg_files(fg_ex_file).name));
    fg_netrun = fg_a.prnn_validation.run_network();
    fg_prnn   = fg_netrun.progrnn.prnn;
    fg_states = fg_netrun.network_states_raw;   fg_W = fg_netrun.W;   fg_d = fg_prnn.d(:);
    [fg_U, fg_S, fg_V] = svd(fg_prnn.A, 'econ');
    fg_Uk  = fg_U(:, 1:12);   fg_SVk = fg_S(1:12, 1:12) * fg_V(:, 1:12)';
    fg_k   = find([fg_R.netnum] == fg_a.netnum, 1);
    assert(~isempty(fg_k), 'this reservoir is not in the trajectory results');
    fg_bstep = fg_R(fg_k).bstep;   fg_spb = fg_R(fg_k).spb;
end
fg_N  = size(fg_Uk, 1);
fg_ms = fg_bin_ms / fg_spb;                    % ms per integration step

%% 2. Quantities for the panels

% panel A: one value per reservoir
fg_rho_raw  = [fg_res.rho_raw];    fg_rho_raw  = fg_rho_raw(:);
fg_rho_star = [fg_res.rho_star];   fg_rho_star = fg_rho_star(:);
fg_rho_cond = arrayfun(@(r) mean(r.rho_cond(:)), fg_res);   fg_rho_cond = fg_rho_cond(:);

% panels B and D: EVERY bounce condition of one reservoir, analysed from the
% start of the trial to just after the bounce (no fixed lead-in is required,
% so early bounces and slow balls are not dropped)
fg_pre = fg_pre_bins * fg_spb;   fg_post = 1 * fg_spb;   fg_lg = -fg_pre:fg_post;   % plotting window for panel B
fg_bc  = find(fg_mask(:) & ~isnan(fg_bstep(:)));
fg_nb  = numel(fg_bc);
fg_lead = nan(fg_nb, numel(fg_lg));   fg_vy = nan(fg_nb, 1);   fg_slope = fg_vy;
fg_why  = strings(fg_nb, 1);          fg_Ysw = cell(fg_nb, 1);   fg_Ydet = fg_Ysw;

for fg_i = 1:fg_nb
    fg_X = fg_states{fg_bc(fg_i)};   if size(fg_X, 1) ~= fg_N, fg_X = fg_X.'; end
    fg_b     = fg_bstep(fg_bc(fg_i));                         % bounce step
    fg_steps = 1:min(size(fg_X, 2), fg_b + fg_post);          % trial start -> just after the bounce
    fg_rel   = fg_steps - fg_b;                               % steps relative to the bounce
    fg_Rt    = fg_X(:, fg_steps);
    fg_G     = 1 - tanh(fg_Uk * (fg_SVk * fg_Rt) + fg_d).^2;
    fg_tr    = nan(1, numel(fg_steps));                       % leading eigenvalue over the whole lead-in
    for fg_t = 1:numel(fg_steps)
        fg_tr(fg_t) = max(real(eig(fg_SVk * (fg_G(:, fg_t) .* fg_Uk))));
    end
    fg_Y = fg_W * fg_Rt;

    % keep the part inside the plotting window (NaN where the trial had not started yet)
    [fg_in, fg_loc] = ismember(fg_rel, fg_lg);
    fg_lead(fg_i, fg_loc(fg_in)) = fg_tr(fg_in);
    fg_Ysw{fg_i}  = nan(numel(fg_rows_sw),  numel(fg_lg));   fg_Ysw{fg_i}(:,  fg_loc(fg_in)) = fg_Y(fg_rows_sw,  fg_in);
    fg_Ydet{fg_i} = nan(numel(fg_rows_det), numel(fg_lg));   fg_Ydet{fg_i}(:, fg_loc(fg_in)) = fg_Y(fg_rows_det, fg_in);

    % ---- slope of the rise that precedes the switch flip --------------------
    fg_ps = find(fg_rel < -30);                               % everything before the spike
    if isempty(fg_ps), fg_why(fg_i) = "bounce at trial start"; continue, end
    fg_vy(fg_i) = mean(abs(fg_Y(fg_row_vy, fg_ps)));          % ball speed toward the wall

    fg_above = fg_tr(fg_ps) > fg_rise_thr;
    fg_dd    = diff([0, fg_above, 0]);
    fg_s     = find(fg_dd == 1);   fg_e = find(fg_dd == -1) - 1;
    fg_keep  = fg_e < numel(fg_ps);                           % a run reaching the late edge is the spike's onset
    fg_s     = fg_s(fg_keep);   fg_e = fg_e(fg_keep);
    if isempty(fg_s), fg_why(fg_i) = "no rise above threshold"; continue, end
    [~, fg_j] = max(fg_e - fg_s);                             % the rise = longest such run
    fg_run    = fg_ps(fg_s(fg_j):fg_e(fg_j));
    fg_h      = fg_tr(fg_run) - 1;
    [fg_hmax, fg_pk] = max(fg_h);
    fg_lin    = find(fg_h(1:fg_pk) <= 0.7 * fg_hmax);         % initial, linear part only
    if numel(fg_lin) < 5, fg_why(fg_i) = "rise too short to fit"; continue, end
    fg_p = polyfit(fg_rel(fg_run(fg_lin)), fg_tr(fg_run(fg_lin)), 1);
    fg_slope(fg_i) = fg_p(1) / fg_ms;                         % per ms
    fg_why(fg_i)   = "fitted";
end
fg_ok = ~isnan(fg_slope);
[fg_rr, fg_pp] = corr(fg_vy(fg_ok), fg_slope(fg_ok));
disp(table(fg_bc, fg_vy, fg_slope, fg_why, 'VariableNames', {'condition', 'speed', 'slope_per_ms', 'status'}))

if isempty(fg_ex_cond)
    fg_idx = find(fg_ok);   [~, fg_o] = sort(fg_slope(fg_ok));
    fg_iEx = fg_idx(fg_o(ceil(numel(fg_o) / 2)));
else
    fg_iEx = find(fg_bc == fg_ex_cond, 1);
    assert(~isempty(fg_iEx), 'fg_ex_cond is not a bounce condition with enough lead-in');
end

%% 3. Figure

fg_fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 26 15]);
fg_tl  = tiledlayout(fg_fig, 2, 5, 'TileSpacing', 'compact', 'Padding', 'loose');   % A: 1 col, B: 2 cols, C/D: 2 cols

% ---- A. three readings of the same connectivity ---------------------------
fg_ax = nexttile(fg_tl, 1, [2 1]);   hold(fg_ax, 'on');
rng(1);
fg_groups = {fg_rho_raw, fg_rho_star, fg_rho_cond};
for fg_g = 1:3
    fg_y = fg_groups{fg_g};
    fg_x = fg_g + (rand(numel(fg_y), 1) - 0.5) * 0.35;
    scatter(fg_ax, fg_x, fg_y, 18, fg_col_pts, 'filled', 'MarkerFaceAlpha', 0.7);
end
yline(fg_ax, 1, ':');
set(fg_ax, 'YScale', 'log', 'XLim', [0.4 3.6], 'XTick', 1:3, 'FontSize', fg_fs, 'YLim', [0.5 2e4], ...
    'XTickLabel', {'\rho(A_p)', 'at r^{*}', 'at r_i^{*}'});
ylabel(fg_ax, 'spectral radius');
text(fg_ax, 1, 1.3e4, sprintf('%.1f\\times10^{3}', mean(fg_rho_raw) / 1e3), 'HorizontalAlignment', 'center', 'FontSize', fg_fs);
text(fg_ax, 2, 2.0,   sprintf('%.2f', mean(fg_rho_star)), 'HorizontalAlignment', 'center', 'FontSize', fg_fs);
text(fg_ax, 3, 1.6,   sprintf('%.2f', mean(fg_rho_cond)), 'HorizontalAlignment', 'center', 'FontSize', fg_fs);
title(fg_ax, sprintf('A.  Three readings (%d reservoirs)', numel(fg_rho_raw)), 'FontSize', fg_fs);

% ---- B. one bounce trial: eigenvalue, detectors, switch --------------------
fg_tB = tiledlayout(fg_tl, 3, 1, 'TileSpacing', 'tight');
fg_tB.Layout.Tile = 2;   fg_tB.Layout.TileSpan = [2 2];
fg_xb = fg_lg * fg_ms;

fg_ax = nexttile(fg_tB);
plot(fg_ax, fg_xb, fg_lead(fg_iEx, :), 'Color', fg_col_eig, 'LineWidth', 1.5);
yline(fg_ax, 1, ':');   xline(fg_ax, 0, '--');   ylabel(fg_ax, 'leading eigenvalue');
set(fg_ax, 'FontSize', fg_fs, 'XTickLabel', [], 'YLim', [0.99 1.13]);
title(fg_ax, sprintf('B.  One bounce trial (condition %d)', fg_bc(fg_iEx)), 'FontSize', fg_fs);

fg_ax = nexttile(fg_tB);
plot(fg_ax, fg_xb, fg_Ydet{fg_iEx}', 'LineWidth', 1.2);
xline(fg_ax, 0, '--');   ylabel(fg_ax, 'collision detectors');
set(fg_ax, 'FontSize', fg_fs, 'XTickLabel', []);

fg_ax = nexttile(fg_tB);
plot(fg_ax, fg_xb, fg_Ysw{fg_iEx}', 'LineWidth', 1.2);
xline(fg_ax, 0, '--');   ylabel(fg_ax, 'direction switch');   xlabel(fg_ax, 'time from bounce (ms)');
set(fg_ax, 'FontSize', fg_fs);

% ---- C. aligned to the bounce, across reservoirs ---------------------------
fg_ax = nexttile(fg_tl, 4, [1 2]);   hold(fg_ax, 'on');
fg_xc = fg_lags * fg_ms;
fg_shade(fg_ax, fg_xc, fg_mB,  fg_col_b);
fg_shade(fg_ax, fg_xc, fg_mNB, fg_col_nb);
yline(fg_ax, 1, ':');   xline(fg_ax, 0, '--');
xlabel(fg_ax, 'time from bounce (ms)');   ylabel(fg_ax, 'leading eigenvalue');
legend(fg_ax, {'', 'bounce', '', 'no bounce'}, 'Location', 'northwest', 'Box', 'off');
set(fg_ax, 'FontSize', fg_fs);
title(fg_ax, sprintf('C.  Aligned to the bounce (%d reservoirs)', size(fg_mB, 1)), 'FontSize', fg_fs);

% ---- D. ramp slope against ball speed --------------------------------------
% If the trajectory results hold slopes for every reservoir (v4 of the
% analysis script), each point is a bounce condition's mean across reservoirs
% with an error bar for the s.d. Otherwise the single reservoir above is shown.
fg_ax = nexttile(fg_tl, 9, [1 2]);   hold(fg_ax, 'on');
fg_multi = isfield(fg_R, 'slope') && ~isempty(fg_R(1).slope);
if fg_multi
    fg_SL = [fg_R.slope];   fg_SP = [fg_R.speed];            % nCond x nNet
    fg_bcA = find(fg_mask(:));
    fg_dx  = mean(fg_SP(fg_bcA, :), 2, 'omitnan');
    fg_dy  = mean(fg_SL(fg_bcA, :), 2, 'omitnan');
    fg_de  = std(fg_SL(fg_bcA, :), 0, 2, 'omitnan');
    fg_dok = ~isnan(fg_dx) & ~isnan(fg_dy);
    errorbar(fg_ax, fg_dx(fg_dok), fg_dy(fg_dok), fg_de(fg_dok), 'o', 'Color', fg_col_pts, ...
             'MarkerFaceColor', fg_col_pts, 'MarkerSize', 4, 'CapSize', 3, 'LineWidth', 0.8);
    fg_dlab = sprintf('r = %.2f, n = %d of %d conditions\nmean ± s.d. across %d reservoirs', ...
                      corr(fg_dx(fg_dok), fg_dy(fg_dok)), nnz(fg_dok), numel(fg_bcA), size(fg_SL, 2));
else
    fg_dx = fg_vy;   fg_dy = fg_slope;   fg_dok = fg_ok;
    scatter(fg_ax, fg_dx(fg_dok), fg_dy(fg_dok), 28, fg_col_pts, 'filled');
    fg_dlab = sprintf('r = %.2f, n = %d of %d (one reservoir)', fg_rr, nnz(fg_dok), numel(fg_bc));
end
fg_pf = polyfit(fg_dx(fg_dok), fg_dy(fg_dok), 1);
fg_xv = linspace(0, max(fg_dx(fg_dok)) * 1.05, 50);
plot(fg_ax, fg_xv, polyval(fg_pf, fg_xv), 'Color', fg_col_eig, 'LineWidth', 1);
xlabel(fg_ax, 'ball speed toward the wall');   ylabel(fg_ax, 'slope of the rise (per ms)');
text(fg_ax, 0.05, 0.88, fg_dlab, 'Units', 'normalized', 'FontSize', fg_fs - 1);
set(fg_ax, 'FontSize', fg_fs);   xlim(fg_ax, [0 fg_xv(end)]);
title(fg_ax, 'D.  Rise before the bounce tracks the ball', 'FontSize', fg_fs);

%% 4. Save

fg_pdf = fullfile(fg_out_dir, 'supp_spectral_properties.svg');
exportgraphics(fg_fig, fg_pdf, 'ContentType', 'vector');
fprintf('Saved %s\n', fg_pdf);
fprintf('Panel B: condition %d.   Panel D: r = %.3f, p = %.1e, n = %d of %d bounce conditions\n', ...
        fg_bc(fg_iEx), fg_rr, fg_pp, nnz(fg_ok), numel(fg_bc));

%%

function fg_shade(ax, x, M, col)
% mean +/- s.d. band across the rows of M
    m = mean(M, 1, 'omitnan');   sd = std(M, 0, 1, 'omitnan');
    fill(ax, [x, fliplr(x)], [m - sd, fliplr(m + sd)], col, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ax, x, m, 'Color', col, 'LineWidth', 1.5);
end