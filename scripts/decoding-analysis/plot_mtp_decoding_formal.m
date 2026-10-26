function plot_mtp_decoding_formal(options)
% PLOT_MTP_DECODING_FIGURES  Panels E & F of the MTP decoding analysis.
% Interface-matched to PLOT_FTP_DECODING_FORMAL: options arguments block,
% model registry table with panel assignments, separatePannels toggle, and
% the BallState-as-dashed-reference-line convention (both panels).
%
%   Panel E : "Entire Future Trajectory Decoding at 250 ms"
%             Per-timepoint decoder performance (Pearson's r) vs. ball-
%             trajectory prediction time point. Models are drawn either as
%             FTP-style mean lines + shaded bands (eStyle="band", default;
%             band half-width set by bandType) or as per-timepoint violins
%             (eStyle="violin", built-in violinplot, R2024b+). The brain
%             gets a mean line + its own decoder-std band regardless;
%             shuffled controls in black. BallState is a dashed black
%             reference line (its grand average), not its own panel.
%
%   Panel F : agreement of each model instance's decoding-vs-time curve
%             with the BRAIN curve. Violins across instances for the three
%             model classes; BallState enters as a dashed reference line at
%             its average level (matching E). CCC is the default metric;
%             the RMSE tile is off by default (showRMSE) since CCC folds
%             error and correlation together.
%
%   Panel F is drawn in the PLOT_SVM_BOUNCE marginal style: width-scaled
%   built-in violins (customViolin fallback pre-R2024b), a jittered
%   per-instance strip, and thin gray stacked comparison brackets.
%
%   Panel F statistics (planned-comparison family, per metric):
%     - dSPM vs NextTP and dSPM vs Paddle: Wilcoxon rank-sum, computed with
%       the EXACT method when the smaller group has n <= 15 (the normal
%       approximation is anticonservative at small n). Rank-biserial effect
%       size reported.
%     - dSPM vs BallState: one-sample t-test against the BallState average
%       as a fixed reference (mu0), drawn as a connector from the dSPM
%       violin to the dashed line -- so the figure no longer implies a
%       two-sample test against a single point. Cohen's d + signed-rank
%       companion reported.
%     - All p-values in the family are Holm-adjusted (options.pAdjust);
%       stars reflect ADJUSTED p. The console also reports the minimum
%       achievable exact rank-sum p at the given n's (the "floor"), so a
%       claimed *** is checkable against what the sample sizes permit.
%
% Works directly on your data structures:
%   <model>_mtp_data.decoder_performance  -> cell{nInst}, each [ntpts x k], col 1 = r
%   <model>_mtp_data.decoder_std          -> matching std
%   brain_mtp_data.decoder_performance    -> [ntpts x k] numeric, col 1 = r

arguments
    % Logical Flags
    options.showBallState   (1,1) logical = true  % dashed ref line in E and F + one-sample test in F
    options.showShuffled    (1,1) logical = true  % overlay shuffled chance lines (black) in E
    options.showRMSE        (1,1) logical = false % add RMSE tile to F (redundant: CCC folds error + corr)
    options.separatePannels (1,1) logical = false % Ploit in single panel or separate figures
    options.showPValues     (1,1) logical = false % print adjusted p under the stars on the figure
    options.testDspmBall    (1,1) logical = true  % dSPM-vs-BallState one-sample test in the family
    options.showPoints      (1,1) logical = true  % jittered per-instance strip in F (SVM style)
    options.subsampleCheck  (1,1) logical = true  % dSPM-vs-controls ranksum at matched n (console)

    % String options with lists
    
    % Error band options between violin plots or patch std
    % "acrossModels" = std of instance mean-curves (the violin quantity; matches F stats)
    % "decoderStd"   = mean per-instance decoder std (estimation noise; different quantity)
    % "sem"          = acrossModels / sqrt(nInst)  (shrinks with instance count -- avoid for models)
    options.eStyle          (1,1) string ...
        {mustBeMember(options.eStyle, ...
            ["band","violin"])}                   = "band"

    options.bandType        (1,1) string ...
        {mustBeMember(options.bandType, ...
            ["acrossModels","decoderStd","sem"])} = "acrossModels"
    
    options.brainStyle      (1,1) string ...
        {mustBeMember(options.brainStyle, ...
            ["band","violin"])}                   = "band"  
    
    % pearson/spearman are level-invariant: on curves that all decline they
    % score the bad models nearly as high as dSPM, so they do NOT invert
    % RMSE. ccc penalizes mean/variance mismatch -> tracks RMSE. r2 explodes
    % negative here because the (nearly flat) brain curve has tiny variance.
    options.corrMetric      (1,1) string ...
        {mustBeMember(options.corrMetric, ...
            ["ccc","r2","pearson","spearman"])}    = "ccc"  
    
    % (stars use ADJUSTED p)
    options.pAdjust         (1,1) string ...
        {mustBeMember(options.pAdjust, ...
            ["holm","bonferroni","none"])}         = "holm" 

    % Metric Options
    options.grayWindowMs    double {mustBeReal} = []   % shaded epoch, [] = none (FTP-consistent option)
    options.violinAlpha     (1,1) double {mustBeInRange(options.violinAlpha,0,1)} = 0.35
    options.alphaBand       (1,1) double {mustBeInRange(options.alphaBand,0,1)}   = 0.15
    options.edgeColor       (1,3) double {mustBeInRange(options.edgeColor,0,1)}   = [0.15 0.15 0.15]
    options.yLim            (1,2) double {mustBeReal} = [-0.2 1.0]
    options.xLim                  double {mustBeReal} = [] % [] = data range +/- 25 ms, else [lo hi] ms
    
end


%% ---- load decoding data (each guard skips a redundant reload) ----

if ~exist("brain_mtp_data","var")
    load("./mtp_data_output/brain_mtp_decoding_data.mat", ...
        "brain_mtp_data","brain_mtp_data_shuffled");
end
if ~exist("dspm_mtp_data","var")
    load("./mtp_data_output/dspm_mtp_decoding_data.mat", ...
        "dspm_mtp_data","dspm_mtp_data_shuffled");
end
if ~exist("paddle_mtp_data","var")
    load("./mtp_data_output/paddle_mtp_decoding_data.mat", ...
        "paddle_mtp_data","paddle_mtp_data_shuffled");
end
if ~exist("nextTP_mtp_data","var")
    load("./mtp_data_output/nextTP_mtp_decoding_data.mat", ...
        "nextTP_mtp_data","nextTP_mtp_data_shuffled");
end
if ~exist("ballState_mtp_data","var")
    load("./mtp_data_output/ballState_mtp_decoding_data.mat", ...
        "ballState_mtp_data","ballState_mtp_data_shuffled");
end

%% ---- colors (paper scheme) ----
c = pong_colors();
col_brain  = c.brain.color;
col_dspm   = c.dspm.color;
col_ntp    = c.nextTP.color;
col_ponly  = c.paddle.color;
if isfield(c,'ballState') && isfield(c.ballState,'color')
    col_bstate = c.ballState.color;
else
    col_bstate = [0.55 0.45 0.70];   % fallback; add ballState to pong_colors to override
end

%% ---- model table ----
% vars = name, data, shuffled, color, panel (row name = key)
% panel 0 = reference only (no E sub-panel, no F violin of its own).

models = {
    "brain"     "Neural Data"     brain_mtp_data     brain_mtp_data_shuffled     col_brain   1
    "dspm"      "dSPM Reservoirs" dspm_mtp_data      dspm_mtp_data_shuffled      col_dspm    2
    "nextTP"    "Next Time-point" nextTP_mtp_data    nextTP_mtp_data_shuffled    col_ntp     3
    "paddle"    "Paddle-Only"     paddle_mtp_data    paddle_mtp_data_shuffled    col_ponly   3
    "ballState" "BallState"       ballState_mtp_data ballState_mtp_data_shuffled col_bstate  0
    };

if ~options.showBallState, models(end,:) = []; end

mdlkey = string(models(:,1));

modelTable = cell2table(...
    models(:,2:end), ...
    VariableNames = ["name" "data" "shuf" "color" "panel"], ...
    RowNames      = mdlkey);

%% ---- time base ----
brainCurve = modelTable{"brain","data"}.decoder_performance(:,1);
ntpts      = numel(brainCurve);
xdata      = (-(ntpts-1):0)*50;            % ms relative to paddle interception
dx         = median(diff(xdata));
if isempty(options.xLim), options.xLim = [min(xdata)-25 max(xdata)+25]; end

options.xdata = xdata;
options.hw    = 0.40*dx;                   % violin half-width in x-units

% BallState grand average (one dashed reference level, shared convention)
if options.showBallState
    options.ballStateAvg = mean(getCurves(modelTable{"ballState","data"}), ...
        'all', 'omitnan');
else
    options.ballStateAvg = [];
end

%% ================================================================== E
if options.separatePannels, plotIndividualE(modelTable, options)
else,                       plotTogetherE(modelTable, options), end

%% ================================================================== F
fTable = modelTable(~strcmp(modelTable.Properties.RowNames,"brain"), :);
[rmseDist, corrDist, corrLab, corrYL] = computeF(fTable, brainCurve, options);
plotPanelF(fTable, rmseDist, corrDist, corrLab, corrYL, options);
reportStats(fTable, rmseDist, corrDist, corrLab, options);

% exportgraphics(figE,'panelE.pdf','ContentType','vector');
% exportgraphics(figF,'panelF.pdf','ContentType','vector');
end


%% ==================================================================== E
function plotTogetherE(modelTable, options)
npanels = max(modelTable.panel);

figure(Color="w", Units="pixels", Position=[80 420 360*npanels 430]);
tl = tiledlayout(1, npanels, TileSpacing="compact", Padding="compact");

ax = gobjects(npanels,1);
for p = 1:npanels
    ax(p) = nexttile; hold(ax(p), "on");
    drawPanelE(ax(p), modelTable(modelTable.panel == p, :), options, p == 1);
end

xlabel(tl, "Ball Trajectory Prediction Time Point Relative to Paddle Interception (ms)", ...
    FontSize=13, FontName="Helvetica");
sgtitle(tl, "Entire Future Trajectory Decoding at 250 ms", ...
    FontSize=18, FontWeight="bold", FontName="Helvetica");
annotation("textbox", [.01 .90 .05 .09], String="E.", ...
    EdgeColor="none", FontSize=22, FontWeight="bold", FontName="Helvetica");
end

function plotIndividualE(modelTable, options)
npanels = max(modelTable.panel);

for p = 1:npanels
    figure(Color="w", Units="pixels", ...
        Position=[100+(p-1)*500 420 500 500]);
    ax = gca; hold(ax, "on");
    drawPanelE(ax, modelTable(modelTable.panel == p, :), options, p == 1);
    xlabel(ax, "Ball Trajectory Prediction Time Point Relative to Paddle Interception (ms)", ...
        FontSize=13, FontName="Helvetica");
    set(gcf, Name="Entire Future Trajectory Decoding at 250 ms");
    if p == 1
        annotation("textbox", [.01 .90 .05 .09], String="E.", ...
            EdgeColor="none", FontSize=22, FontWeight="bold", FontName="Helvetica");
    end
end
end

function drawPanelE(ax, panelData, opt, showY)
% Draw one E sub-panel: all rows of panelData onto ax, plus references.
grayWindow(ax, opt.grayWindowMs, opt.yLim);

for r = 1:height(panelData)
    key  = string(panelData.Properties.RowNames{r});
    data = panelData{r,"data"};
    clr  = panelData{r,"color"};

    if key == "brain"
        mu = data.decoder_performance(:,1);
        sd = data.decoder_std(:,1);
        drawBrain(ax, opt.xdata, mu, sd, clr, opt.brainStyle, ...
            opt.hw, opt.edgeColor, opt.violinAlpha, opt.alphaBand);
    elseif opt.eStyle == "band"
        [mu, band] = meanBand(data, opt.bandType);     % FTP-style summary
        drawBandLine(ax, opt.xdata, mu, band, clr, opt.alphaBand);
    else  % "violin"
        [curves, mu] = getCurves(data);            % [ntpts x nInst]
        timeViolins(ax, opt.xdata, curves, opt.hw, clr, ...
            opt.edgeColor, opt.violinAlpha);
        plot(ax, opt.xdata, mu, "-o", Color=clr, MarkerFaceColor=clr, ...
            MarkerSize=3, LineWidth=1.4, Tag="mtp");
    end

    if opt.showShuffled
        sm = mean(getCurves(panelData{r,"shuf"}), 2, "omitnan");
        plot(ax, opt.xdata, sm, "-", Color=[0 0 0], LineWidth=1, Tag="mtp");
    end
end

if ~isempty(opt.ballStateAvg)
    plot(ax, opt.xLim, [1 1]*opt.ballStateAvg, "k--", Tag="mtp");
end

styleTimeAxis(ax, opt, strjoin(panelData.name, " + "), showY);
end

function timeViolins(ax, x, curves, hw, faceCol, edgeCol, a)
% One violin per time point, all drawn by a SINGLE built-in violinplot call
% (R2024b+). Numeric x positions (ms) are the positional grouping data, so
% violins land exactly where the old manual patches did. DensityScale="width"
% matches the old max-width normalization; DensityWidth = 2*hw is the full
% width (hw is a half-width).
nInst = size(curves, 2);
if nInst < 3
    plot(ax, x, mean(curves,2,'omitnan'), 'o', MarkerFaceColor=faceCol, ...
        MarkerEdgeColor=edgeCol, MarkerSize=4, Tag="mtp");
    return
end
xg = repmat(x(:), nInst, 1);      % column-stacked to match curves(:)
y  = curves(:);
keep = ~isnan(y);
v = violinplot(ax, xg(keep), y(keep), ...
    DensityScale="width", DensityWidth=2*hw);
set(v, FaceColor=faceCol, FaceAlpha=a, ...
    EdgeColor=edgeCol, LineWidth=0.4, Tag="mtp");
end

function drawBrain(ax, x, mu, sd, col, style, hw, edge, aViolin, aBand)
if style == "violin"
    % Reconstruct per-timepoint Gaussians and reuse the same violin helper.
    synth = mu(:) + sd(:).*randn(numel(x), 200);      % [T x 200]
    timeViolins(ax, x, synth, hw, col, edge, aViolin);
else  % band
    fill(ax, [x fliplr(x)], [mu+sd; flipud(mu-sd)].', col, ...
        FaceAlpha=aBand, EdgeColor="none", Tag="mtp");
end
plot(ax, x, mu, "-o", Color=col, MarkerFaceColor=col, ...
    MarkerSize=3, LineWidth=1.4, Tag="mtp");
end

function [mu, band] = meanBand(modelData, bandType)
% Mean curve and band half-width across model instances (or the brain's own
% std). Identical to the FTP helper so the two figures stay visually and
% semantically aligned.
perf = modelData.decoder_performance;
if iscell(perf)
    curves = cell2mat(cellfun(@(m) m(:,1), perf(:).', UniformOutput=false));  % [T x nInst]
    mu = mean(curves, 2, "omitnan");
    switch bandType
        case "decoderStd"                       % mean per-instance decoding std
            stds = cell2mat(cellfun(@(m) m(:,1), modelData.decoder_std(:).', UniformOutput=false));
            band = mean(stds, 2, "omitnan");
        case "acrossModels"                     % spread across model instances
            band = std(curves, 0, 2, "omitnan");
        case "sem"
            band = std(curves, 0, 2, "omitnan") / sqrt(size(curves, 2));
        otherwise
            error("Unknown bandType: %s", bandType);
    end
else
    mu   = perf(:,1);
    band = modelData.decoder_std(:,1);
end
mu = mu(:);  band = band(:);
end

function drawBandLine(ax, t, mu, band, color, alphaBand)
t = t(:).';  mu = mu(:).';  band = band(:).';
fill(ax, [t flip(t)], [mu+band flip(mu-band)], color, ...
    FaceAlpha=alphaBand, EdgeColor="none", Tag="mtp");
plot(ax, t, mu, "-", Color=color, LineWidth=1.6, Tag="mtp");
end

function grayWindow(ax, win, yLim)
if isempty(win), return; end
patch(ax, win([1 2 2 1]), yLim([1 1 2 2]), [.85 .85 .85], ...
    EdgeColor="none", FaceAlpha=.5, Tag="mtp");
end

function styleTimeAxis(ax, opt, ttl, showY)
    set(ax, YLim=opt.yLim, XLim=opt.xLim, ...
        XTick=fliplr(0:-200:min(opt.xdata)), ...   % clean 200 ms intervals
        XTickLabelRotation=0, ...
        LineWidth=2, TickDir="out", Box="off", ...
        FontSize=12, FontName="Helvetica");
    if showY
        ylabel(ax, "Pearson's r", FontSize=14, FontAngle="italic");
    else
        ax.YTickLabel = [];
    end
    title(ax, ttl, FontSize=14, FontWeight="normal", FontAngle="italic");
end


%% ==================================================================== F
function [rmseDist, corrDist, corrLab, corrYL] = computeF(fTable, brainCurve, options)
% Per-instance RMSE and agreement (CCC/R2/Pearson) of each model's r-curve
% vs the brain r-curve. RMSE is always computed (console report + subsample
% check use it) even when the RMSE tile is hidden.
n = height(fTable);
rmseDist = cell(1,n);
corrDist = cell(1,n);
for j = 1:n
    C = getCurves(fTable{j,"data"});                       % [ntpts x nInst]
    rmseDist{j} = sqrt(mean((C - brainCurve).^2, 1)).';    % [nInst x 1]
    switch options.corrMetric
        case "pearson",  corrDist{j} = corr(C, brainCurve);
        case "spearman", corrDist{j} = corr(C, brainCurve, Type="Spearman");
        case "ccc",      corrDist{j} = cccColumns(C, brainCurve);
        case "r2",       corrDist{j} = r2Columns(C, brainCurve);
        otherwise, error("Unknown corrMetric: %s", options.corrMetric);
    end
end
switch options.corrMetric
    case "pearson",  corrLab = "Pearson's r";        corrYL = [0 1.08];
    case "spearman", corrLab = "Spearman's \rho";    corrYL = [0 1.08];
    case "ccc",      corrLab = "Concordance (CCC)";  corrYL = [0 1.08];
    case "r2",       corrLab = "R^2";                corrYL = [min(0,min(cellfun(@(d)min(d),corrDist)))-0.05 1.08];
end
end

function plotPanelF(fTable, rmseDist, corrDist, corrLab, corrYL, options)
keys   = string(fTable.Properties.RowNames);
gSel   = keys ~= "ballState";                 % violin groups (BallState = reference line)
gTable = fTable(gSel,:);
gKeys  = keys(gSel);
n      = height(gTable);
hasVP  = ~isempty(which("violinplot"));       % built-in since R2024b

f = findall(0, "-depth", 1, "Name", "figureMTPAgreement");  delete(f)

nTiles = 1 + double(options.showRMSE);
figure(Color="w", Units="pixels", Position=[80 30 60+420*nTiles 500], ...
    Name="figureMTPAgreement");
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
    sprintf("%s with neural profile", corrLab), corrYL);

sgtitle(tl, "Agreement with neural decoding profile", ...
    FontSize=15, FontWeight="bold", FontName="Helvetica");
annotation("textbox", [.01 .90 .05 .09], String="F.", ...
    EdgeColor="none", FontSize=22, FontWeight="bold", FontName="Helvetica");

% console justification report
if options.showRMSE, printComparisons(cmpR, "RMSE", options); end
printComparisons(cmpC, corrLab, options);
end

function cmp = buildComparisons(dists, keys, metricLab, lowerIsBetter, options)
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
    % two-sided exact p floor under complete separation, at these n's:
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
                mu0, numel(dists{iB}), st.df, st.tstat, d, ci(1), ci(2), psr, tag));
    end
end

pAdj = padjust([cmp.pRaw], options.pAdjust);
for i = 1:numel(cmp)
    cmp(i).pAdj  = pAdj(i);
    cmp(i).stars = starsFromP(pAdj(i));
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
        yline(ax, lvl, "--", "BallState", ...
            Color=[0 0 0], LineWidth=1, ...
            LabelHorizontalAlignment="right", ...
            LabelVerticalAlignment="bottom", ...
            FontSize=9, FontAngle="italic", FontName="Helvetica");
        xc = iD + 0.30;
        yy = sort([xdM lvl]);
        if diff(yy) < 1e-3, yy = mean(yy) + [-0.01 0.01]; end
        plot(ax, [xc xc], yy, "-", Color=[.2 .2 .2], LineWidth=1.2, ...
            HandleVisibility="off", Tag="mtp");
        plot(ax, [xc-0.06 xc; xc-0.06 xc].', [yy; yy], "-", ...
            Color=[.2 .2 .2], LineWidth=1.2, HandleVisibility="off", Tag="mtp");
        text(ax, xc+0.06, mean(yy), txt, ...
            HorizontalAlignment="left", VerticalAlignment="middle", ...
            FontSize=9, Tag="mtp");
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
fprintf('\n--- Panel F planned comparisons: %s (adjust = %s, family m = %d) ---\n', ...
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
    otherwise
        error("Unknown pAdjust: %s", method);
end
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
            Tag             = "mtp");
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
title(ax, ttl, FontSize=11, FontAngle="italic", FontWeight="normal");
end

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
    Tag              = "mtp");

text(ax, (x1+x2)/2, y - 0.02, s   , ...
    HorizontalAlignment = "center", ...
    VerticalAlignment   = "bottom", ...
    FontSize            = 9       , ...
    Tag                 = "mtp");
end

function customViolin(ax, xc, vals, w, faceColor, faceAlpha)
% Fallback violin (pre-R2024b, if built-in violinplot is unavailable).
vals = vals(:);
vals = vals(isfinite(vals));
if numel(vals) < 3
    plot(ax, [xc-w xc+w], [mean(vals) mean(vals)], ...
        Color=faceColor, LineWidth=2);
    return
end

[f, xi] = ksdensity(vals);
f = f / max(f) * w;

patch(ax, [xc+f, fliplr(xc-f)], [xi, fliplr(xi)], faceColor, ...
    FaceAlpha=faceAlpha, EdgeColor=faceColor, LineWidth=1, ...
    HandleVisibility="off");

q = quantile(vals, [.25 .5 .75]);
plot(ax, [xc xc], [q(1) q(3)], "-", Color=[.15 .15 .15], ...
    LineWidth=1.2, HandleVisibility="off");
plot(ax, xc, q(2), "o", MarkerFaceColor="w", MarkerEdgeColor=[.15 .15 .15], ...
    MarkerSize=4, HandleVisibility="off");
end

function reportStats(fTable, rmseDist, corrDist, corrLab, options)
fprintf('\n--- Panel F summary (median [IQR], n instances) ---\n');
fprintf('correlation metric = %s   (RMSE tile shown: %d)\n', ...
    options.corrMetric, options.showRMSE);
for j = 1:height(fTable)
    fprintf('%-16s  RMSE %.3f [%.3f %.3f]   %s %.3f [%.3f %.3f]   n=%d\n', ...
        fTable.name{j}, med3(rmseDist{j}), corrLab, med3(corrDist{j}), ...
        numel(rmseDist{j}));
end

if options.subsampleCheck
    subsampleReport(rmseDist, fTable, 500);
end
end

function subsampleReport(rmseDist, fTable, K)
% Robustness to sample-size imbalance: repeatedly subsample every group to the
% smallest multi-instance group's n, re-run dSPM-vs-control ranksum, and report
% how stable the result is. Demonstrates the conclusion is not an artifact of
% dSPM having more instances than the trained controls.
keys  = string(fTable.Properties.RowNames);
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
        fTable.name{o}, median(p), mean(p<0.05));
end
fprintf('\n');
end


%% ================================================================ shared
function [curves, mu, sd] = getCurves(data)
% Returns per-instance curves [ntpts x nInst], plus mean/std across instances.
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
% Penalizes offset and scale mismatch -> low for a steep curve vs a flat brain
% curve even when Pearson r is high. Population (N-normalized) moments.
y  = y(:); my = mean(y); vy = mean((y-my).^2);
n  = size(C,2); v = zeros(n,1);
for i = 1:n
    x  = C(:,i); mx = mean(x); vx = mean((x-mx).^2);
    sxy = mean((x-mx).*(y-my));
    v(i) = 2*sxy / (vx + vy + (mx-my)^2);
end
end

function v = r2Columns(C, y)
% Coefficient of determination treating brain y as the target the model must
% reproduce: R^2 = 1 - SS_res/SS_tot. Can go negative for poor fits.
y = y(:); sst = sum((y-mean(y)).^2);
n = size(C,2); v = zeros(n,1);
for i = 1:n
    v(i) = 1 - sum((y - C(:,i)).^2) / sst;
end
end

function s = starsFromP(p)
if     p < 1e-3, s = '***';
elseif p < 1e-2, s = '**';
elseif p < 0.05, s = '*';
else             s = 'n.s.';
end
end

function out = med3(x)
x = x(~isnan(x)); out = [median(x) prctile(x,25) prctile(x,75)];
end