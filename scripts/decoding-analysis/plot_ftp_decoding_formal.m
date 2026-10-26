function plot_ftp_decoding_formal(options)
% Panel C: ball end-point prediction correlation by latent state.
% Decodes the ball end-point from the state vector at each time t
% and plots decoding correlation (Pearson's r) vs time as mean lines
% with shaded bands.
%
% Layout follows the reference:
% Neural | dSPM | NextTP + Paddle (+ BallState dashed reference).
%
% Panel D: agreement of each model instance's decoding-vs-time curve with
% the BRAIN curve, restricted to the agreement window (agreeWindowMs,
% default 250-1200 ms). Ported from PLOT_MTP_DECODING_FORMAL Panel F:
% CCC by default (penalizes level/scale mismatch, so it tracks RMSE),
% Wilcoxon rank-sum (exact at small n) dSPM vs each trained control,
% one-sample t of dSPM vs the BallState average as a fixed reference,
% Holm-adjusted p-values, stars from ADJUSTED p.
%
% Panel D is drawn in the PLOT_SVM_BOUNCE marginal style: width-scaled
% built-in violins with a jittered per-instance strip, thin gray stacked
% comparison brackets, and a customViolin fallback for pre-R2024b.
%
% Data structures:
%   <model>_ftp_data.decoder_performance -> cell{nInst}, each [nTime x k], col 1 = r
%   <model>_ftp_data.decoder_std         -> matching std
%   brain_ftp_data.decoder_performance   -> [nTime x k] numeric, col 1 = r

arguments
    % Logical Inputs
    options.separatePannels (1,1) logical = false      % Plot C panels in separate or single figure(s)
    options.showBallState   (1,1) logical = true       % ballState avg as dashed reference line (C and D)
    options.showShuffled    (1,1) logical = false      % overlay shuffled chance line (black) in C

    % Panel D (agreement) flags
    options.showAgreement   (1,1) logical = true       % draw Panel D at all
    options.showRMSE        (1,1) logical = false      % add RMSE tile to D (redundant with CCC)
    options.showPoints      (1,1) logical = true       % jittered per-instance strip on the violins
    options.showPValues     (1,1) logical = false      % print adjusted p next to stars
    options.testDspmBall    (1,1) logical = true       % dSPM-vs-BallState one-sample test in the family
    options.subsampleCheck  (1,1) logical = true       % dSPM-vs-controls ranksum at matched n (console)

    % +/-1 sd across instances (matches MTP + F stats)
    options.bandType        (1,1) string ...
        {mustBeMember(options.bandType, ...
        ["acrossModels","decoderStd","sem"])} = "acrossModels"

    % The brain FTP curve is nearly FLAT inside the agreement window, so
    % every correlation-family metric (ccc, r2, pearson, spearman) is
    % degenerate there: CCC = 1 - MSE/(var(x)+var(y)+(mx-my)^2) and the
    % denominator goes to zero along with the numerator. "agreement" is
    % 1 - RMSE, bounded on [0,1] because r is, and reads like CCC (higher
    % = closer to the brain). ccc is kept for windows where the brain
    % curve actually moves (it is the MTP default).
    options.corrMetric      (1,1) string ...
        {mustBeMember(options.corrMetric, ...
        ["agreement","ccc","r2","pearson","spearman"])} = "agreement"

    options.pAdjust         (1,1) string ...
        {mustBeMember(options.pAdjust, ...
        ["holm","bonferroni","none"])} = "holm"

    options.grayWindowMs          double {mustBeReal} = [0 250]   % shaded epoch in C, [] = none
    options.agreeWindowMs   (1,2) double {mustBeReal} = [250 1200] % time bins used for Panel D
    options.alphaBand       (1,1) double {mustBeInRange(options.alphaBand,0,1)} = 0.15
    options.violinAlpha     (1,1) double {mustBeInRange(options.violinAlpha,0,1)} = 0.30
    options.yLim            (1,2) double {mustBeReal} = [-0.05 1.03]
    options.xLim                  double {mustBeReal} = []  % [] = full data range, else [lo hi] ms

end


%% ---- load decoding data (each guard skips a redundant reload) ----

if ~exist("brain_ftp_data","var")
    load("./ftp_data_output/brain_ftp_decoding_data.mat", ...
        "brain_ftp_data",  "brain_ftp_data_shuffled");
end
if ~exist("dspm_ftp_data","var")
    load("./ftp_data_output/dspm_ftp_decoding_data.mat", ...
        "dspm_ftp_data",   "dspm_ftp_data_shuffled");
end
if ~exist("paddle_ftp_data","var")
    load("./ftp_data_output/paddle_ftp_decoding_data.mat", ...
        "paddle_ftp_data", "paddle_ftp_data_shuffled");
end
if ~exist("nextTP_ftp_data","var")
    load("./ftp_data_output/nextTP_ftp_decoding_data.mat", ...
        "nextTP_ftp_data", "nextTP_ftp_data_shuffled");
end
if ~exist("ballState_ftp_data","var")
    load("./ftp_data_output/ballState_ftp_decoding_data.mat", ...
        "ballState_ftp_data", "ballState_ftp_data_shuffled");
end

%% ---- Parameters and Options ----

showBallState   = options.showBallState;
xLim            = options.xLim         ;
separatePannels = options.separatePannels;

% ---- colors (paper scheme) ----
c = pong_colors();
col_brain  = c.brain.color;
col_dspm   = c.dspm.color;
col_ntp    = c.nextTP.color;
col_ponly  = c.paddle.color;
col_bstate = colorOr(c, "ballState", [0.6 0.2 0.2]);

% ---- time base ----
nTime  = size(brain_ftp_data.decoder_performance, 1);
timeMs = (0:nTime-1) * 50;
if isempty(xLim), xLim = [min(timeMs) max(timeMs)]; end

options.timeMs = timeMs;
options.xLim   = xLim;


%%  ---- model table ----
% vars = name, data, shuffled, color, panel (row name = key)
% panel 0 = reference only (no C sub-panel, no D violin of its own).

models = {
    "brain"     "Neural Data"     brain_ftp_data     brain_ftp_data_shuffled     col_brain  1
    "dspm"      "dSPM Reservoirs" dspm_ftp_data      dspm_ftp_data_shuffled      col_dspm   2
    "nextTP"    "Next Time-point" nextTP_ftp_data    nextTP_ftp_data_shuffled    col_ntp    3
    "paddle"    "Paddle-Only"     paddle_ftp_data    paddle_ftp_data_shuffled    col_ponly  3
    "ballState" "Ball State"      ballState_ftp_data ballState_ftp_data_shuffled col_bstate 0
    };

if ~showBallState, models(end,:) = []; end

mdlkey     = string(models(:,1));
modelTable = cell2table(...
    models(:,2:end), ...
    VariableNames = ["name" "data" "shuf" "color" "panel"], ...
    RowNames      = mdlkey);

% BallState grand average (shared dashed-reference convention, C and D)
if showBallState
    options.ballStateAvg = mean(getCurves(modelTable{"ballState","data"}), ...
        "all", "omitnan");
else
    options.ballStateAvg = [];
end


%% ================================================================== C

if separatePannels, plotIndividual(modelTable,options)
else,               plotTogether(modelTable,options), end


%% ================================================================== D

if options.showAgreement
    brainCurve = getCurves(modelTable{"brain","data"});          % [nTime x 1]
    dTable     = modelTable(mdlkey ~= "brain", :);
    [rmseDist, corrDist, corrLab, corrYL, winIdx] = ...
        computeAgreement(dTable, brainCurve, options);
    plotPanelD(dTable, rmseDist, corrDist, corrLab, corrYL, winIdx, options);
    reportStats(dTable, rmseDist, corrDist, corrLab, options);
end

end

%% ==================================================================== C

function plotIndividual(modelTable,options)

    showShuffled    = options.showShuffled ;
    bandType        = options.bandType     ;
    grayWindowMs    = options.grayWindowMs ;
    alphaBand       = options.alphaBand    ;
    yLim            = options.yLim         ;
    xLim            = options.xLim         ;
    timeMs          = options.timeMs       ;

    npanels = max(modelTable.panel);

    fh = gobjects(npanels,1);
    ax = gobjects(npanels,1);

    for p = 1:npanels

        fh(p) = figure(Color   ="w", ...
                       Units   ="pixels", ...
                       Position=[100+(p-1)*500 200 500 500]);

        panelData = modelTable(modelTable.panel == p, :);
        ax(p)     = gca; hold(ax(p), "on");

        grayWindow(ax(p), grayWindowMs, yLim);

        for r = 1:height(panelData)

            data = panelData{r,"data"};
            clr  = panelData{r,"color"};
            [mu, band] = meanBand(data, bandType);

            drawBandLine(ax(p), timeMs, mu, band, clr, alphaBand);

            if showShuffled
                plot(ax(p), timeMs, meanBand(panelData{r,"shuf"}, bandType), "-", ...
                    Color=[0 0 0], LineWidth=1, Tag="ftp");
            end
        end
        styleAxis(ax(p), xLim, yLim, strjoin(panelData.name, " + "), p == 1);

        if ~isempty(options.ballStateAvg)
            plot(ax(p), timeMs([1 end]), [1 1]*options.ballStateAvg, "k--", Tag="ftp")
        end

        ax(p).Toolbar.Visible = true;

    end

    xlabel(ax, "Time (ms) for Decoding State Vector", ...
        FontSize=13, FontName="Helvetica");

    set(fh,"Name", "Ball End-Point Prediction Correlation by Latent State");

    annotation("textbox", [.01 .90 .05 .09], String="C.", ...
        EdgeColor="none", FontSize=22, ...
        FontWeight="bold", FontName="Helvetica");

end

function plotTogether(modelTable,options)

    showShuffled    = options.showShuffled ;
    bandType        = options.bandType     ;
    grayWindowMs    = options.grayWindowMs ;
    alphaBand       = options.alphaBand    ;
    yLim            = options.yLim         ;
    xLim            = options.xLim         ;
    timeMs          = options.timeMs       ;

    npanels = max(modelTable.panel);

    figure(Color="w", Units="pixels", Position=[250 500 1100 375]);
    tl = tiledlayout(1, npanels, TileSpacing="compact", Padding="compact");

    ax = gobjects(npanels,1);

    for p = 1:npanels

        panelData = modelTable(modelTable.panel == p, :);
        ax(p)     = nexttile; hold(ax(p), "on");

        grayWindow(ax(p), grayWindowMs, yLim);

        for r = 1:height(panelData)

            data = panelData{r,"data"};
            clr  = panelData{r,"color"};
            [mu, band] = meanBand(data, bandType);

            drawBandLine(ax(p), timeMs, mu, band, clr, alphaBand);

            if showShuffled
                plot(ax(p), timeMs, meanBand(panelData{r,"shuf"}, bandType), "-", ...
                    Color=[0 0 0], LineWidth=1, Tag="ftp");
            end
        end

        styleAxis(ax(p), xLim, yLim, strjoin(panelData.name, " + "), p == 1);

        if ~isempty(options.ballStateAvg)
            plot(ax(p), timeMs([1 end]), [1 1]*options.ballStateAvg, "k--", Tag="ftp")
        end

        ax(p).Toolbar.Visible = true;

    end

    xlabel(tl, "Time (ms) for Decoding State Vector", FontSize=13, FontName="Helvetica");
    sgtitle(tl, "Ball End-Point Prediction Correlation by Latent State", ...
        FontSize=18, FontWeight="bold", FontName="Helvetica");
    annotation("textbox", [.01 .90 .05 .09], String="C.", ...
        EdgeColor="none", FontSize=22, FontWeight="bold", FontName="Helvetica");

end


function [mu, band] = meanBand(modelData, bandType)
    % Mean curve and band half-width across model instances (or the brain's own std).
    perf = modelData.decoder_performance;
    if iscell(perf)
        curves = cell2mat( ...
            cellfun(@(m) m(:,1), perf(:).', UniformOutput=false));   % [time x nModels]
        mu = mean(curves, 2, "omitnan");

        switch bandType
            case "decoderStd"                       % mean per-model decoding std
                stds = cell2mat(cellfun(@(m) m(:,1), modelData.decoder_std(:).', UniformOutput=false));
                band = mean(stds, 2, "omitnan");
            case "acrossModels"                     % spread across model instances
                band = std(curves, 0, 2, "omitnan");
            case "sem"
                band = std(curves, 0, 2, "omitnan") / sqrt(size(curves, 2));
        end

    else
        mu   = perf(:,1);
        band = modelData.decoder_std(:,1);
    end
    mu = mu(:);  band = band(:);
end


function drawBandLine(ax, t, mu, band, color, alphaBand)
    t    = t(:).';
    mu   = mu(:).';
    band = band(:).';

    fill(ax, [t flip(t)], [mu+band flip(mu-band)], color, ...
        FaceAlpha=alphaBand, EdgeColor="none", Tag="ftp");

    plot(ax, t, mu, "-", Color=color, LineWidth=1.6, Tag="ftp");
end


function grayWindow(ax, win, yLim)
    if isempty(win), return; end
    patch(ax, win([1 2 2 1]), yLim([1 1 2 2]), [.85 .85 .85], ...
        EdgeColor="none", FaceAlpha=.5, Tag="ftp");
end


function styleAxis(ax, xLim, yLim, titleStr, showY)

    set(ax, YLim=yLim, XLim=xLim, ...
        YTick=0:.2:1, XTick=0:250:1250, ...
        LineWidth=2, TickDir="out", Box="off", ...
        FontSize=12, FontName="Helvetica");

    if showY
        ylabel(ax, "Correlation Pearson's r", FontSize=14);
    else
        ax.YTickLabel = [];
    end

    title( ax, titleStr, ...
        FontSize=14, ...
        FontWeight="normal", ...
        FontAngle="italic");

end


%% ==================================================================== D

function [rmseDist, corrDist, corrLab, corrYL, winIdx] = ...
    computeAgreement(dTable, brainCurve, options)
% Per-instance RMSE and agreement (CCC/R2/Pearson/Spearman) of each model's
% r-vs-time curve against the brain r-vs-time curve, restricted to the
% agreement window. RMSE is always computed (console report + subsample
% check use it) even when the RMSE tile is hidden.

    w      = options.agreeWindowMs;
    winIdx = find(options.timeMs >= w(1) & options.timeMs <= w(2));
    if numel(winIdx) < 3
        error("agreeWindowMs [%g %g] selects only %d time bins; need >= 3.", ...
            w(1), w(2), numel(winIdx));
    end
    yb = brainCurve(winIdx);

    n        = height(dTable);
    rmseDist = cell(1,n);
    corrDist = cell(1,n);

    for j = 1:n
        C = getCurves(dTable{j,"data"});                       % [nTime x nInst]
        C = C(winIdx, :);                                      % [nWin  x nInst]
        rmseDist{j} = sqrt(mean((C - yb).^2, 1)).';            % [nInst x 1]
        switch options.corrMetric
            case "pearson",  corrDist{j} = corr(C, yb);
            case "spearman", corrDist{j} = corr(C, yb, Type="Spearman");
            case "ccc",      corrDist{j} = cccColumns(C, yb);
            case "r2",       corrDist{j} = r2Columns(C, yb);
            case "agreement",corrDist{j} = 1 - rmseDist{j};
        end
    end

    % correlation-family metrics need variance in the reference curve
    vy = var(yb);
    if options.corrMetric ~= "agreement" && vy < 1e-3
        warning(['Brain curve variance in the %d-%d ms window is %.2e; ' ...
            '%s is degenerate on a flat reference. Use corrMetric="agreement" ' ...
            '(1 - RMSE) or the RMSE tile instead.'], ...
            w(1), w(2), vy, options.corrMetric);
    end

    switch options.corrMetric
        case "pearson",  corrLab = "Pearson's r";        corrYL = [0 1.08];
        case "spearman", corrLab = "Spearman's \rho";    corrYL = [0 1.08];
        case "ccc",      corrLab = "Concordance (CCC)";  corrYL = [0 1.08];
        case "agreement",corrLab = "Agreement (1 - RMSE)"; corrYL = [0 1.08];
        case "r2",       corrLab = "R^2";
            corrYL = [min(0, min(cellfun(@(d) min(d), corrDist)))-0.05 1.08];
    end
end


function plotPanelD(dTable, rmseDist, corrDist, corrLab, corrYL, winIdx, options)

    keys   = string(dTable.Properties.RowNames);
    gSel   = keys ~= "ballState";                 % violin groups (BallState = reference line)
    gTable = dTable(gSel,:);
    gKeys  = keys(gSel);
    n      = height(gTable);
    hasVP  = ~isempty(which("violinplot"));       % built-in since R2024b

    wMs    = options.timeMs(winIdx([1 end]));

    f = findall(0, "-depth", 1, "Name", "figureFTPAgreement");  delete(f)

    nTiles = 1 + double(options.showRMSE);
    figure(Color="w", Units="pixels", Position=[80 30 60+420*nTiles 500], ...
        Name="figureFTPAgreement");
    tl = tiledlayout(1, nTiles, TileSpacing="compact", Padding="compact");

    % --- RMSE tile (optional; lower = better) ---
    if options.showRMSE
        axR = nexttile(tl); hold(axR, "on");
        plotViolins(axR, rmseDist(gSel), gTable, hasVP, options);
        cmpR = buildComparisons(rmseDist, keys, "RMSE", true, options);
        drawComparisons(axR, cmpR, rmseDist, keys, gKeys, options);
        axFinish(axR, n, gTable.name, "RMSE", "Error vs neural profile", [0 1.08]);
    end

    % --- agreement tile (CCC by default) ---
    axC = nexttile(tl); hold(axC, "on");
    plotViolins(axC, corrDist(gSel), gTable, hasVP, options);
    cmpC = buildComparisons(corrDist, keys, corrLab, false, options);
    drawComparisons(axC, cmpC, corrDist, keys, gKeys, options);
    axFinish(axC, n, gTable.name, corrLab, ...
        sprintf("%s with neural profile, %d-%d ms", corrLab, wMs(1), wMs(2)), corrYL);

    sgtitle(tl, "Agreement with neural decoding profile", ...
        FontSize=15, FontWeight="bold", FontName="Helvetica");
    annotation("textbox", [.01 .90 .05 .09], String="D.", ...
        EdgeColor="none", FontSize=22, FontWeight="bold", FontName="Helvetica");

    % console justification report
    if options.showRMSE, printComparisons(cmpR, "RMSE", options); end
    printComparisons(cmpC, corrLab, options);
end


function plotViolins(ax, dists, gTable, hasVP, options)
% SVM-marginal style: jittered per-instance strip + width-scaled violin per
% model at integer x positions 1..n (built-in violinplot, else customViolin).

    dw  = 0.34;   % violin width
    jit = 0.04;   % point jitter

    for m = 1:height(gTable)

        d   = dists{m}(isfinite(dists{m}));
        clr = gTable{m,"color"};

        if options.showPoints && ~isempty(d)
            scatter(ax, ...
                m + randn(numel(d),1)*jit, d, ...
                8, clr, "filled", ...
                MarkerFaceAlpha = 0.35, ...
                MarkerEdgeColor = "none", ...
                Tag             = "ftp");
        end

        draw_viol(ax, m, d, clr, dw, hasVP, options.violinAlpha);

    end

    if isprop(ax,"Toolbar") && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = "off";
    end
end


function axFinish(ax, n, names, ylab, ttl, yl)
    set(ax, ...
        XLim=[.4 n+.6], XTick=1:n     , ...
        YLim=yl       , YTick=0:0.1:1 , ...
        XTickLabel=names              , ...
        XTickLabelRotation=30         , ...
        LineWidth = 2                 , ...
        TickDir   = "out"             , ...
        Box       = "off"             , ...
        FontName  = "Helvetica"       , ...
        FontSize  = 10);

    ylabel(ax, ylab, FontSize=13);

    title(ax, ttl, ...
        FontSize   = 11      , ...
        FontAngle  = "italic", ...
        FontWeight = "normal");
end


function cmp = buildComparisons(dists, keys, ~, lowerIsBetter, options)
% Planned-comparison family for ONE metric:
%   dSPM vs each trained control  -> two-sample rank-sum (exact if small n)
%   dSPM vs BallState reference   -> one-sample t vs mu0 (+ signed-rank)
% p-values are adjusted jointly across the family (Holm by default) and the
% stars are computed from the ADJUSTED p. Effect sizes and the minimum
% achievable exact rank-sum p ("floor") are carried along for reporting.

    iD = find(keys=="dspm",1);
    xd = dists{iD}(~isnan(dists{iD}));
    cmp = struct('label',{},'type',{},'bKey',{},'pRaw',{},'pAdj',{}, ...
                 'stars',{},'refLvl',{},'note',{});

    for k = find(keys=="nextTP" | keys=="paddle").'
        y  = dists{k}(~isnan(dists{k}));
        n1 = numel(xd); n2 = numel(y);
        if n1 < 2 || n2 < 2
            continue   % nothing testable; no bracket rather than an unjustified one
        end
        if min(n1,n2) <= 15
            p = ranksum(xd, y, "method","exact");  meth = "exact";
        else
            p = ranksum(xd, y);                     meth = "normal approx";
        end
        [~,~,st] = ranksum(xd, y);                  % rank sum of first sample
        U   = st.ranksum - n1*(n1+1)/2;
        rrb = 1 - 2*U/(n1*n2);                      % rank-biserial effect size
        pFloor = 2*exp(gammaln(n1+1)+gammaln(n2+1)-gammaln(n1+n2+1));
        cmp(end+1) = struct( ...
            'label', sprintf('dSPM vs %s', keys(k)), 'type',"ranksum", ...
            'bKey', keys(k), 'pRaw', p, 'pAdj', NaN, 'stars',"", 'refLvl',[], ...
            'note', sprintf('rank-sum (%s), n=%d/%d, U=%g, r_rb=%.2f, exact-p floor=%.1e', ...
                            meth, n1, n2, U, rrb, pFloor)); %#ok<AGROW>
    end

    iB = find(keys=="ballState",1);
    if options.testDspmBall && ~isempty(iB) && numel(xd) >= 2
        mu0 = mean(dists{iB}, "omitnan");
        if ~isnan(mu0)
            [~, p, ci, st] = ttest(xd, mu0);
            d   = (mean(xd) - mu0) / std(xd);       % Cohen's d vs the reference point
            psr = signrank(xd, mu0);                % nonparametric companion
            if (mean(xd) < mu0) == lowerIsBetter, tag = 'closer to brain than ref';
            else,                                 tag = 'farther from brain than ref'; end
            cmp(end+1) = struct( ...
                'label',"dSPM vs BallState (reference)", 'type',"onesample", ...
                'bKey',"ballState", 'pRaw',p, 'pAdj',NaN, 'stars',"", 'refLvl',mu0, ...
                'note', sprintf(['one-sample t vs mu0=%.4f (n_ref=%d): t(%d)=%.2f, ' ...
                    'Cohen d=%.2f, 95%%CI [%.4f %.4f], signed-rank p=%.1e; dSPM %s'], ...
                    mu0, numel(dists{iB}), st.df, st.tstat, d, ci(1), ci(2), psr, tag)); %#ok<AGROW>
        end
    end

    pAdj = padjust([cmp.pRaw], options.pAdjust);
    for i = 1:numel(cmp)
        cmp(i).pAdj  = pAdj(i);
        cmp(i).stars = star_str(pAdj(i));
    end
end


function drawComparisons(ax, cmp, dists, keys, gKeys, options)
% Two-sample comparisons -> SVM-style stacked brackets above the data,
% anchored at the dSPM violin. One-sample vs BallState -> dashed reference
% line + a thin connector from the dSPM median to the line.

    iD  = find(gKeys=="dspm",1);
    xdM = median(dists{keys=="dspm"}, "omitnan");

    yTopData = max(cellfun(@(d) max(d(isfinite(d))), dists(ismember(keys, gKeys))));
    y0   = yTopData + 0.08;
    step = 0.02;
    k    = 0;

    for i = 1:numel(cmp)
        txt = starText(cmp(i), options);
        if cmp(i).type == "ranksum"
            k  = k + 1;
            jB = find(gKeys==cmp(i).bKey, 1);
            sig_bracket(ax, iD, jB, y0 + (k-1)*step, txt);
        else  % onesample vs reference line
            lvl = cmp(i).refLvl;
            yline(ax, lvl, "--", "Ball State", ...
                Color=[0 0 0], LineWidth=1, ...
                LabelHorizontalAlignment="right", ...
                LabelVerticalAlignment="bottom", ...
                FontSize=9, FontAngle="italic", FontName="Helvetica");
            xc = iD + 0.30;
            yy = sort([xdM lvl]);
            if diff(yy) < 1e-3, yy = mean(yy) + [-0.01 0.01]; end
            plot(ax, [xc xc], yy, "-", Color=[.2 .2 .2], LineWidth=1.2, ...
                HandleVisibility="off", Tag="ftp");
            plot(ax, [xc-0.06 xc; xc-0.06 xc].', [yy; yy], "-", ...
                Color=[.2 .2 .2], LineWidth=1.2, HandleVisibility="off", Tag="ftp");
            text(ax, xc+0.06, mean(yy), txt, ...
                HorizontalAlignment="left", VerticalAlignment="middle", ...
                FontSize=9, Tag="ftp");
        end
    end
end


function txt = starText(c, options)
    txt = char(c.stars);
    if options.showPValues
        txt = sprintf('%s p=%.1e', txt, c.pAdj);
    end
end


function printComparisons(cmp, metricLab, options)
    fprintf('\n--- Panel D planned comparisons: %s (adjust = %s, family m = %d) ---\n', ...
        metricLab, options.pAdjust, numel(cmp));
    for i = 1:numel(cmp)
        fprintf('  %-34s p_raw=%.2e  p_adj=%.2e  -> %s\n      %s\n', ...
            cmp(i).label, cmp(i).pRaw, cmp(i).pAdj, cmp(i).stars, cmp(i).note);
    end
    % flag star claims the sample sizes cannot support
    for i = 1:numel(cmp)
        if cmp(i).type == "ranksum"
            fl = sscanf(extractAfter(cmp(i).note,"floor="), '%e');
            if ~isempty(fl) && fl > 0.05
                fprintf(['  WARNING: %s -- exact-p floor (%.1e) exceeds 0.05; ' ...
                    'significance is not achievable at these n''s.\n'], cmp(i).label, fl);
            end
        end
    end
end


function pa = padjust(p, method)
% Family-wise adjustment. Stars downstream are computed from these values.
    pa = p;
    if isempty(p), return; end
    switch string(method)
        case "none"
            % pa = p
        case "bonferroni"
            pa = min(1, p * numel(p));
        case "holm"
            [ps, ix] = sort(p);
            m = numel(p);
            adj = min(1, cummax(ps .* (m:-1:1)));
            pa(ix) = adj;
    end
end


function reportStats(dTable, rmseDist, corrDist, corrLab, options)
    fprintf('\n--- Panel D summary (median [IQR], n instances), window %d-%d ms ---\n', ...
        options.agreeWindowMs(1), options.agreeWindowMs(2));
    fprintf('correlation metric = %s   (RMSE tile shown: %d)\n', ...
        options.corrMetric, options.showRMSE);
    for j = 1:height(dTable)
        fprintf('%-16s  RMSE %.3f [%.3f %.3f]   %s %.3f [%.3f %.3f]   n=%d\n', ...
            dTable.name{j}, med3(rmseDist{j}), corrLab, med3(corrDist{j}), ...
            numel(rmseDist{j}));
    end

    if options.subsampleCheck
        subsampleReport(rmseDist, dTable, 500);
    end
end


function subsampleReport(rmseDist, dTable, K)
% Robustness to sample-size imbalance: repeatedly subsample every group to the
% smallest multi-instance group's n, re-run dSPM-vs-control ranksum, and report
% how stable the result is.
    keys  = string(dTable.Properties.RowNames);
    ns    = cellfun(@numel, rmseDist);
    valid = find(ns > 1);
    nmin  = min(ns(valid));
    iD = find(keys=="dspm",1);
    if isempty(iD) || ~ismember(iD,valid), return; end
    others = setdiff(valid, iD);
    fprintf('--- Subsample sensitivity: match all groups to n=%d, %d reps ---\n', nmin, K);
    for o = others(:).'
        p = nan(K,1);
        for k = 1:K
            a = rmseDist{iD}(randperm(numel(rmseDist{iD}), nmin));
            b = rmseDist{o};
            if numel(b) > nmin, b = b(randperm(numel(b), nmin)); end
            p(k) = ranksum(a, b);
        end
        fprintf('  dSPM vs %-14s : median p=%.2e   frac(p<0.05)=%.2f\n', ...
            dTable.name{o}, median(p), mean(p<0.05));
    end
    fprintf('\n');
end


%% ============================================== SVM-style violin helpers

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
        HandleVisibility = "off"               , ...
        Tag              = "ftp");

    text(ax, (x1+x2)/2, y - 0.02, s   , ...
        HorizontalAlignment = "center", ...
        VerticalAlignment   = "bottom", ...
        FontSize            = 9       , ...
        Tag                 = "ftp");

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


%% ================================================================ shared

function [curves, mu, sd] = getCurves(data)
% Returns per-instance curves [nTime x nInst], plus mean/std across instances.
    perf = data.decoder_performance;
    if iscell(perf)
        curves = cell2mat(cellfun(@(c) c(:,1), perf(:).', UniformOutput=false)); % [T x nInst]
    else
        curves = perf(:,1);                                                      % [T x 1]
    end
    mu = mean(curves, 2, "omitnan");
    sd = std(curves, 0, 2, "omitnan");
end


function v = cccColumns(C, y)
% Lin's concordance correlation coefficient of each column of C against ref y.
% CCC = 2*cov(x,y) / (var(x) + var(y) + (mean(x)-mean(y))^2)
% Population (N-normalized) moments.
    y  = y(:); my = mean(y); vy = mean((y-my).^2);
    n  = size(C,2); v = zeros(n,1);
    for i = 1:n
        x  = C(:,i); mx = mean(x); vx = mean((x-mx).^2);
        sxy = mean((x-mx).*(y-my));
        v(i) = 2*sxy / (vx + vy + (mx-my)^2);
    end
end


function v = r2Columns(C, y)
% R^2 = 1 - SS_res/SS_tot with the brain curve as target. Can go negative.
    y = y(:); sst = sum((y-mean(y)).^2);
    n = size(C,2); v = zeros(n,1);
    for i = 1:n
        v(i) = 1 - sum((y - C(:,i)).^2) / sst;
    end
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


function out = med3(x)
    x = x(~isnan(x)); out = [median(x) prctile(x,25) prctile(x,75)];
end