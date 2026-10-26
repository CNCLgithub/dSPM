function plot_condition_subspace_ftp(options)
% PLOT_CONDITION_SUBSPACE_FTP  Within-condition FTP endpoint decoding at the
% readout bin, split by trial condition. Interface-matched to the other
% figure functions (options arguments block, model registry table).
%
%   ONE figure: per model, a pair of bars in the model's color --
%       open bar    = "not Bounce" (no-bounce) trials, decoded within-condition
%       hatched bar = Bounce trials,             decoded within-condition
%   at options.readoutMs (default 250 ms). Error bars = decoding std at the
%   readout bin. Model names run vertically over the open bar (reference
%   figure layout). MATLAB has no native bar hatching, so the hatched bars
%   are drawn as diagonal lines clipped to the bar rectangle, in model color.
%
%   The cross-decoding curves/bars are NOT plotted anymore, but the console
%   diagnostic table (cross vs within-pooled vs within-foldwise, endpoint
%   std, lambdas) still prints from the same files so the paradox bookkeeping
%   is preserved (options.printDiag).
%
% Data: ./condition_subspace_ftp_output/<key>_condition_subspace_ftp_decoding.mat
%       each containing cs_data with withinBounce / withinNoBounce /
%       crossToBounce / crossToNoBounce blocks + meta + diag.

arguments
    options.readoutMs     = 250;         % readout bin shown (ms)
    options.withinMetric  = "pooled";    % "pooled" (cross-matched) | "foldwise" (paper bars)
    options.showBallState = false;       % add the Linear Map bar pair (off in reference figure)
    options.printDiag     = true;        % readout-bin cross/within console table
    options.yLim          = [-0.2 1.02];
    options.barWidth      = 0.36;
    options.pairOffset    = 0.22;        % half-distance between the two bars of a pair
    options.hatchSpacing  = 0.015;       % hatch line spacing, fraction of x-range
    options.hatchSlope    = 1.0;         % 1 = 45 deg in normalized axes units
    options.nameY         = 0.45;        % y of the vertical model-name labels
end

%% ---- colors + model table (row order = bar order) ----
c = pong_colors();
models = {
    "brain"     "Neural Data"     c.brain.color
    "dspm"      "dSPM Reservoirs" c.dspm.color
    "nextTP"    "Next Time-Point" c.nextTP.color
    "paddle"    "Paddle Only"     c.paddle.color
    "ballState" "Linear Map"      colorOr(c, "ballState", [0.6 0.2 0.2])
    };
if ~options.showBallState, models(end,:) = []; end

modelTable = cell2table(models(:,2:end), ...
    VariableNames = ["name" "color"], ...
    RowNames      = string(models(:,1)));
nM = height(modelTable);

%% ---- load (within AND cross come from the SAME file per model) ----
cs = cell(nM,1);
for m = 1:nM
    S = load("./condition_subspace_ftp_output/" + ...
        modelTable.Properties.RowNames{m} + ...
        "_condition_subspace_ftp_decoding.mat", "cs_data");
    cs{m} = S.cs_data;
end
modelTable.data = cs;
tbin = max(1, round(options.readoutMs / cs{1}.meta.binMs));

%% ==================== figure: within-condition bars ====================
figure(Color="w", Units="pixels", Position=[80 200 200*nM 480]);
ax = gca; hold(ax, "on");

% limits FIRST: the hatch geometry reads them to stay at a fixed visual angle
set(ax, XLim=[0.4 nM+0.6], YLim=options.yLim);

yline(ax, 0, "--", Color=[.2 .2 .2], LineWidth=1.2, Tag="cs");

w   = options.barWidth;
off = options.pairOffset;

for m = 1:nM
    clr = modelTable{m,"color"};
    d   = modelTable.data{m};

    [muNB, sdNB] = binStat(d.withinNoBounce, tbin, options.withinMetric);
    [muB,  sdB ] = binStat(d.withinBounce,   tbin, options.withinMetric);

    drawBar(ax, m-off, w, muNB, clr, false, options);   % open    = not-Bounce
    drawBar(ax, m+off, w, muB,  clr, true,  options);   % hatched = Bounce

    errorbar(ax, m-off, muNB, sdNB, "k", LineWidth=1.5, CapSize=7, Tag="cs");
    errorbar(ax, m+off, muB,  sdB,  "k", LineWidth=1.5, CapSize=7, Tag="cs");

    text(ax, m-off, options.nameY, modelTable.name{m}, Rotation=90, ...
        FontAngle="italic", FontWeight="bold", FontSize=13, ...
        FontName="Helvetica", HorizontalAlignment="center", Tag="cs");
end

set(ax, XTick=[], YTick=ceil(options.yLim(1)*5)/5:0.2:1, ...
    LineWidth=2.5, TickDir="out", Box="off", ...
    FontName="Helvetica", FontSize=12);

ylabel(ax, "Endpoint Decoding Correlation", FontSize=15);
title(ax, sprintf("Endpoint Decoding at %d ms by Condition", options.readoutMs), ...
    FontSize=16, FontWeight="bold", FontName="Helvetica");
subtitle(ax, sprintf("open = \\negBounce, hatched = Bounce (within-condition, %s)", ...
    options.withinMetric), FontAngle="italic", FontSize=12);

%% ==================== readout-bin diagnostic table ====================
if options.printDiag
    fprintf("\n=== endpoint decoding at %d ms (bin %d) ===\n", options.readoutMs, tbin);
    fprintf("%-16s | test      | cross  win-pool  win-fold | epStd  lamX/lamW\n", "model");
    for m = 1:nM
        d = modelTable.data{m};
        printRow(modelTable.name{m}, "bounce",    d.crossToBounce,   d.withinBounce,   tbin, d.diag.endpointStdBounce);
        printRow("",                 "no-bounce", d.crossToNoBounce, d.withinNoBounce, tbin, d.diag.endpointStdNoBounce);
    end
    fprintf(['win-pool is the cross-matched quantity (pooled full-group r). ' ...
        'If win-pool >= cross for a given test group, the paradox is gone; ' ...
        'if cross still wins, it is a real training-side effect ' ...
        '(compare epStd and lambda).\n']);
end

% exportgraphics(gcf,'panel_condition_bars.pdf','ContentType','vector');
end


% ====================================================================
function drawBar(ax, xc, w, h, clr, hatched, opt)
% Open (outline-only) or hatched bar in the model color. Hatching = diagonal
% lines clipped to the bar rectangle; slope is set in normalized axes units
% so the visual angle is stable across data ranges.
x0 = xc - w/2;  y0 = min(0, h);  y1 = max(0, h);
if (y1 - y0) < eps    % degenerate bar -> tick mark
    plot(ax, [x0 x0+w], [h h], Color=clr, LineWidth=2.5, Tag="cs");
    return
end
if hatched
    xl = ax.XLim;  yl = ax.YLim;
    mSlope = opt.hatchSlope * diff(yl)/diff(xl);        % data-unit slope
    dxs    = opt.hatchSpacing * diff(xl);               % spacing along x
    for cc = (x0 - (y1-y0)/mSlope) : dxs : (x0 + w)     % lines y = y0 + m*(x-cc)
        xs = max(x0, cc);
        xe = min(x0 + w, cc + (y1-y0)/mSlope);
        if xe > xs
            ys = min(y0 + mSlope*([xs xe]-cc), y1);     % clip top
            plot(ax, [xs xe], ys, Color=clr, LineWidth=1.4, Tag="cs");
        end
    end
end
rectangle(Parent=ax, Position=[x0, y0, w, y1-y0], ...
    EdgeColor=clr, LineWidth=2.5, Tag="cs");
end


function [mu, sd] = binStat(A, tbin, metric)
% Across-instance bar height + error at one bin.
%   "pooled"   -> decoder_performance col 1 (full-group r), decoder_std col 1
%   "foldwise" -> mean/std of per-fold-mean r (within only)
if metric == "foldwise"
    src = A.repR_foldwise;
    if iscell(src)
        mu = mean(cellfun(@(r) mean(r(tbin,:), "omitnan"), src));
        sd = mean(cellfun(@(r) std(r(tbin,:),  "omitnan"), src));
    else
        mu = mean(src(tbin,:), "omitnan");
        sd = std(src(tbin,:),  "omitnan");
    end
else
    perf = A.decoder_performance;
    if iscell(perf)
        mu = mean(cellfun(@(p) p(tbin,1), perf));
        sd = mean(cellfun(@(p) p(tbin,1), A.decoder_std));
    else
        mu = perf(tbin,1);
        sd = A.decoder_std(tbin,1);
    end
end
end


function printRow(name, testGrp, X, W, tbin, epStd)
% cross R | within pooled R | within foldwise R | endpoint std | lambdas
xR = colMean(X.decoder_performance, tbin, 1);
wP = colMean(W.decoder_performance, tbin, 1);
wF = repMean(W.repR_foldwise, tbin);
lamX = colMean(X.lambdaMed, tbin, 1);
lamW = colMean(W.lambdaMed, tbin, 1);
fprintf("%-16s | %-9s | %5.2f  %7.2f  %7.2f | %5.2f  %.0e/%.0e\n", ...
    name, testGrp, xR, wP, wF, epStd, lamX, lamW);
end


function v = colMean(P, tbin, col)
if iscell(P), v = mean(cellfun(@(p) p(tbin,col), P)); else, v = P(tbin,col); end
end


function v = repMean(R, tbin)
if iscell(R), v = mean(cellfun(@(r) mean(r(tbin,:), "omitnan"), R));
else,         v = mean(R(tbin,:), "omitnan"); end
end


function v = colorOr(c, key, default)
if isfield(c, key), v = c.(key).color; else, v = default; end
end