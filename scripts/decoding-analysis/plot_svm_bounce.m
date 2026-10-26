function plot_svm_bounce
% Reads svm_bounce_pipeline.m output. Two panels:
%   (1) balanced-accuracy time-course (chance 0.5), pre-collision window shaded
%       (drawn only if the pipeline saved one)
%   (2) pre-collision marginal: violins of repBA (instance-averaged balanced
%       accuracy per matched CV split, one point per split). Chance line 0.5,
%       dSPM reference line.
%
% STATISTICS. Every system is compared with dSPM by direct bootstrap
% hypothesis testing on the matched CV splits. The pipeline gives each system
% one balanced accuracy per split, on the same splits, so the values are
% paired. For each system we take the paired differences (dSPM - system),
% resample them with replacement NBOOT times, and take the mean of each
% resample. p is the fraction of those bootstrap means that are <= 0, i.e.
% that do not favor dSPM (one-sided). The 2.5th and 97.5th percentiles of the
% same bootstrap means give the 95% interval on the difference. No SVM is
% refit here: the bootstrap resamples numbers already saved by the pipeline.

NBOOT    = 1000;                 % bootstrap resamples for the direct test
DSPM_TAG = "dspm_1000neurons";   % must match the name used in save_sb(...)

%% ---- model table (row order = plot order) ----
c = pong_colors();
models = {
    "brain"     "Neural Data"     c.brain.color
    "dspm"      "dSPM Reservoirs" c.dspm.color
    "nextTP"    "Next Time-Point" c.nextTP.color
    "paddle"    "Paddle Only"     c.paddle.color
    "ballState" "Ball State"      colorOr(c,"ballState",[0.6 0.2 0.2])
    };

nmodels  = size(models,1);
refModel = find(strcmpi([models{:,1}],"dspm"));    % dSPM reference 

%% ---- load ----

fileNames = strcat("./svm_bounce_output/", string(models(:,1)), "_svm_bounce.mat");
fileNames = replace(fileNames, "dspm_", DSPM_TAG + "_");

sb = cell(nmodels,1);

for m = 1:nmodels

    S = load(fileNames(m), "sb");
    sb{m} = S.sb;

end

d     = sb{1}.diag;
t     = (0:numel(sb{1}.baCurve)-1) * d.binMs; % assumes bin 1 = 0 ms
winMs = d.marginMs;
hasCurve = all(cellfun(@(s) ~isempty(s.baCurve), sb));

% direct bootstrap test of every system against dSPM (computed once, used by
% both the brackets and the printed table)
stats = cell(nmodels,1);
for m = 1:nmodels
    if m == refModel, continue; end
    stats{m} = boot_test(sb{refModel}.repBA, sb{m}.repBA, NBOOT);
end
hasVP = ~isempty(which("violinplot"));        % built-in since R2024b

%% ---- figure ----

f = findall(0,"-depth",1,"Name","figureSVM");  delete(f)

figure(Color="w", Position=[126 279 1491 787], Name="figureSVM");

tiles = tiledlayout(1, 1 + hasCurve, TileSpacing="compact", Padding="compact");

if hasCurve
    plot_timecourse(nexttile(tiles), sb, models, t, winMs);
    xlabel(tiles, ...
        "Time (ms) for Decoding State Vector", ...
        FontSize = 13, ...
        FontName = "Helvetica");
end

plot_marginal(nexttile(tiles), sb, models, refModel, winMs, hasVP, stats);

sgtitle(tiles, ...
    "SVM bounce classification", ...
    FontSize   = 15, ...
    FontWeight = "bold");

print_table(sb, models, refModel, stats, NBOOT);

end


% ====================================================================

function plot_timecourse(ax, sb, models, t, winMs)

    hold(ax,"on");
    
    patch(ax, ...
        [winMs(1) winMs(2) winMs(2) winMs(1)], ... xdata
        [0 0 1.02 1.02]        , ... ydata
        [.85 .85 .85]          , ... color
        EdgeColor       ="none", ...
        FaceAlpha       =.5    , ...
        HandleVisibility="off");
    
    yline(ax, 0.5, "--", Color=[.4 .4 .4], ...
        LineWidth=1, HandleVisibility="off");
    
    h = gobjects(size(models,1),1);
    
    for m = 1:size(models,1)
    
        mu = sb{m}.baCurve;  
        sd = sb{m}.baCurveStd;
    
        fill(ax, [t flip(t)], [mu+sd; flip(mu-sd)].', ...
            models{m,3}              , ...
            FaceAlpha        = .12   , ...
            EdgeColor        = "none", ...
            HandleVisibility = "off");
    
        h(m) = plot(ax, t, mu, "-"   , ...
            Color       = models{m,3}, ...
            LineWidth   = 1.8        , ...
            DisplayName = models{m,2});
    end
    
    set(ax, ...
        YLim=[0.4 1.0]      , YTick=0.4:0.1:1   , ...
        XLim=[min(t) max(t)], XTick=0:500:max(t), ...
        LineWidth=2, TickDir="out", Box="off", ...
        FontName="Helvetica", FontSize=11);
    
    ylabel(ax, "Balanced accuracy", FontSize=13);
    
    title(ax, "Did-it-bounce classification (SVM)", ...
        FontSize   = 13      , ...
        FontAngle  = "italic", ...
        FontWeight = "normal");
    
    legend(h, Box="off", Location="southeast", FontSize=9);

end


function plot_marginal(ax, sb, models, ref, winMs, hasVP, stats)

    hold(ax,"on");
    
    nM = size(models,1);  
    
    yline(ax, 0.5, "--", Color=[.4 .4 .4], LineWidth=1);          % chance
    
    refVal = mean(sb{ref}.repBA);
    yline(ax, refVal, ":", Color=models{ref,3}, LineWidth=1.2);   % dSPM reference
    
    dw  = 0.34;   % violin width
    jit = 0.04;   % rep-point jitter
    for m = 1:nM
    
        rb = sb{m}.repBA;  % one value per CV split
    
        scatter(ax, ...
            m + randn(numel(rb),1)*jit, rb, ...
            8, models{m,3}, "filled", ... size, color, filled
            MarkerFaceAlpha = 0.35  , ...
            MarkerEdgeColor = "none");
    
        draw_viol(ax, m, rb, models{m,3}, dw, hasVP, 0.30);
    
    end
    
    % direct bootstrap test of matched-split repBA vs dSPM
    % stacked brackets
    yTopData = max(cellfun(@(s) max(s.repBA), sb));
    y0   = yTopData + 0.08;  
    step = 0.02;  
    k    = 0;
    
    for m = 1:nM
        if m == ref, continue; end
        k = k + 1;
        sig_bracket(ax, ref, m, y0 + (k-1)*step, star_str(stats{m}.p));
    end
    
    set(ax, ...
        XLim=[.4 nM+.6], XTick=1:nM   , ...
        YLim=[0.2 1.08], YTick=0:0.1:1, ...
        XTickLabel=[models{:,2}]      , ...
        XTickLabelRotation=30         , ...
        LineWidth = 2                 , ...
        TickDir   = "out"             , ...
        Box       = "off"             , ...
        FontName  = "Helvetica"       , ...
        FontSize  = 10);
    
    tltStr = sprintf( ...
        "Pre-collision marginal (%d-%d ms) ; "+ ...
        "violin=CV reps ; " + ...
        "stars=direct bootstrap vs dSPM", ...
        winMs(1), winMs(2) ...
            );
    
    title(ax, tltStr         , ...
        FontSize   = 11      , ...
        FontAngle  = "italic", ...
        FontWeight = "normal");

end


function st = boot_test(refBA, modBA, nboot)
% Direct bootstrap hypothesis test on matched CV splits.
%   d       paired differences, reference (dSPM) minus system, one per split
%   db      nboot bootstrap means of d (resampling splits with replacement)
%   p       fraction of bootstrap means <= 0 (one-sided: dSPM > system),
%           with the +1 correction so p is never reported as exactly 0
%   ci      95% percentile interval on the mean difference

    n = min(numel(refBA), numel(modBA));   % matched: same splits, same order
    if numel(refBA) ~= numel(modBA)
        warning("boot_test:unequalReps", ...
            "Unequal number of CV splits (%d vs %d); using the first %d of each.", ...
            numel(refBA), numel(modBA), n);
    end

    d  = refBA(1:n) - modBA(1:n);
    d  = d(isfinite(d));
    n  = numel(d);

    rs = RandStream("mt19937ar", Seed = 1);         % reproducible
    db = mean(d(randi(rs, n, n, nboot)), 1);        % [1 x nboot]

    st       = struct();
    st.n     = n;
    st.dMean = mean(d);
    st.ci    = prctile(db, [2.5 97.5]);
    st.nOpp  = sum(db <= 0);
    st.p     = (1 + st.nOpp) / (nboot + 1);

end


function print_table(sb, models, ref, stats, nboot)

    fprintf("\nDirect bootstrap test vs %s (%d resamples of matched CV splits, one-sided)\n", ...
        models{ref,2}, nboot);
    fprintf("%-16s  BA     AUC    p(null)  dBA (dSPM - model) [95%% CI]     p\n", "model");

    for m = 1:size(models,1)

        ba = mean(sb{m}.repBA);
        pn = (1 + sum(sb{m}.nullBA >= ba)) / (numel(sb{m}.nullBA) + 1);

        if m == ref
            vs = "ref";
        else
            st = stats{m};
            if st.nOpp == 0
                pStr = sprintf("p < %.3g", 1/nboot);   % none of the resamples
            else
                pStr = sprintf("p = %.3g", st.p);
            end
            vs = sprintf("%+.3f [%+.3f, %+.3f]        %s %s  (n=%d splits)", ...
                st.dMean, st.ci(1), st.ci(2), pStr, star_str(st.p), st.n);
        end

        fprintf("%-16s  %.3f  %.3f  %.4f   %s\n", models{m,2}, ba, sb{m}.auc, pn, vs);

    end

end

% ====================================================================
function draw_viol(ax, xc, vals, color, dw, hasVP, alpha)
% Full violin at xc using built-in violinplot (R2024b+) or the fallback.

    vals = vals(:);  
    vals = vals(isfinite(vals));
    
    if hasVP && numel(vals) >= 3
    
        v = violinplot(ax, ...
                xc*ones(numel(vals),1), ...
                vals                  , ...
                DensityScale = "width", ...
                DensityWidth = dw);
    
        v.FaceColor = color;
    
        try v.FaceAlpha = alpha; catch, end
    
    else
        customViolin(ax, xc, vals, dw/2, color, alpha);
    end

end


function sig_bracket(ax, x1, x2, y, s)
% Horizontal comparison bracket with end drop-ticks and a star label.
tick = 0.012;

plot(ax, ...
    [x1 x1 x2 x2], [y-tick y y y-tick], "-", ...
    Color            = [.2 .2 .2]          , ...
    LineWidth        = 1.2                 , ...
    HandleVisibility = "off");

text(ax, (x1+x2)/2, y - 0.02, s   , ...
    HorizontalAlignment = "center", ...
    VerticalAlignment   = "bottom", ...
    FontSize            = 9);

end


function s = star_str(p)

    if     p < 0.001, s = "***";
    elseif p < 0.01 , s = "**";
    elseif p < 0.05 , s = "*";
    else,             s = "n.s.";
    end

end


function v = colorOr(c, key, default)
    if isfield(c, key), v = c.(key).color; 
    else, v = default; end
end


function customViolin(ax, xc, vals, w, faceColor, faceAlpha)
% Fallback violin (pre-R2024b, if built-in violinplot is unavailable).

vals = vals(:);  
vals = vals(isfinite(vals));
if numel(vals) < 3
    plot(ax, ...
        [xc-w xc+w], [mean(vals) mean(vals)], ...
        Color     = faceColor, ...
        LineWidth = 2);
    return
end

[f, xi] = ksdensity(vals);

f = f / max(f) * w;

patch(ax, ...
    [xc+f, fliplr(xc-f)], [xi, fliplr(xi)], ...
    faceColor                   , ...
    FaceAlpha        = faceAlpha, ...
    EdgeColor        = faceColor, ...
    LineWidth        = 1        , ...
    HandleVisibility = "off");

q = quantile(vals, [.25 .5 .75]);

plot(ax, [xc xc], [q(1) q(3)], "-"  , ...
    Color            = [.15 .15 .15], ...
    LineWidth        = 1.2          , ...
    HandleVisibility = "off");

plot(ax, xc, q(2), "o"              , ...
    MarkerFaceColor  = "w"          , ...
    MarkerEdgeColor  = [.15 .15 .15], ...
    MarkerSize       = 4            , ...
    HandleVisibility = "off");

end