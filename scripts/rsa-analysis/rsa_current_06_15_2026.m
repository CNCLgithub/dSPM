%% RSA Pipeline (Cleaned and Commented)
% Author: Daniel Calbick
% Date: 2026-06-15
% Description: Full RSA pipeline for comparing brain, black-box, and programmed networks.

%% -------------------------------------------------------------------------
%                             Load Programmed Data
% -------------------------------------------------------------------------
output_dir = "../../hpc-outputs/programmed-networks";
runid      = "28-Feb-2025_1000neurons_44a04e02-6fc5-4389-9109-584de368715b";

pth     = fullfile(output_dir, runid);
statedir = "rnn-states";
svdir   = "rnn-analysis";
svname  = "rdm-vectors.mat";

if ~exist("brain", "var")
    load("../../data/brain_and_rishi_data.mat", "brain")
end

if exist(fullfile(pth, svdir, svname), "file")
    load(fullfile(pth, svdir, svname))
else
    files   = dir(fullfile(pth, "*.mat"));
    nfiles  = numel(files); 
    progMat = cell(nfiles, 1);

    mask = brain.all_mask(:, 7:end);
    tpts = cellfun(@(s) find(s, 1, "last"), num2cell(mask, 2));

    for i = 1:nfiles
        a = load(fullfile(pth, files(i).name), "prnn_validation");
        prnn = a.prnn_validation;
        prnn.run_network;

        states = cellfun(@(x) x(:, 5:end), prnn.binned_states.modelStates, 'UniformOutput', false);
        ntrials = numel(states);

        stateCell = cell(ntrials, 1);
        for j = 1:ntrials
            stateCell{j} = zscore(states{j}(:, 1:tpts(j)), [], 2);
        end

        progMat{i} = cat(2, stateCell{:});
    end

    rdmProg = cellfun(@(s) pdist(s', "euclidean"), progMat, 'UniformOutput', false);

    if ~exist(fullfile(pth, svdir), 'dir'), mkdir(fullfile(pth, svdir)); end
    save(fullfile(pth, svdir, "state-matrices.mat"), "progMat")
    save(fullfile(pth, svdir, svname), "rdmProg", "-v7.3")
end

%% -------------------------------------------------------------------------
%                        Load Brain & Black Box Data
% -------------------------------------------------------------------------
load("../../data/bbrnns.mat", "bbrnns")

if exist("../../data/staticRDMs_brain_bbrnn.mat", "file")
    load("../../data/staticRDMs_brain_bbrnn.mat")
else
    braindata = zscore(brain.data(:, :, 7:end-1), [], 3);
    brainData = squeeze_cell(braindata);

    bbData = cellfun(@(s) squeeze_cell(zscore(double(s), [], 3)), {bbrnns.data_neur_nxcxt}', 'UniformOutput', false);
    bbData = cat(1, bbData{:});

    mask = brain.all_mask(:, 7:end);
    tpts = cellfun(@(s) find(s, 1, "last"), num2cell(mask, 2));
    ntrials = size(mask, 1);

    brainCell = cell(ntrials, 1);
    bbCell = cell(ntrials, 1);

    for i = 1:ntrials
        brainCell{i} = brainData{i}(:, 1:tpts(i));
        bbCell{i} = cellfun(@(s) s(:, 1:tpts(i)), bbData(:, i), 'UniformOutput', false);
    end

    bbCell = cat(2, bbCell{:});
    bbMats = cellfun(@(s) horzcat(s{:}), num2cell(bbCell, 2), 'UniformOutput', false);
    brainMat = cat(2, brainCell{:});

    rdmBBs = cellfun(@(s) pdist(s', "euclidean"), bbMats, 'UniformOutput', false);
    rdmBrain = pdist(brainMat', "euclidean");

    save("../../data/staticRDMs_brain_bbrnn.mat", "rdmBBs", "rdmBrain", '-v7.3')
end

%% -------------------------------------------------------------------------
%                        Load Linear Map Data 
% -------------------------------------------------------------------------


if exist("../../data/staticRDMs_linearMap.mat", "file")*false
    load("../../data/staticRDMs_linearMap.mat")
else
    lmdata = squeeze_cell(permute(linearMap.state,[1 3 2]));
    
    mask    = brain.all_mask(:, 7:end);
    tpts    = cellfun(@(s) find(s, 1, "last"), num2cell(mask, 2));
    ntrials = size(mask, 1);

    lmCell = cell(ntrials, 1);

    for i = 1:ntrials
        lmd = lmdata{i}(:, 1:tpts(i));
        try lmd(:,isnan(lmd(1,:))) = lmd(:,end-1);catch,end
        lmCell{i} = lmd;
    end

    lmMat = cat(2, lmCell{:});
    rdmLM = pdist(lmMat', "euclidean");

    save("../../data/staticRDMs_linearMap.mat", "rdmLM", '-v7.3')
end

%% -------------------------------------------------------------------------
%                        Gather Oracle Data
% -------------------------------------------------------------------------

if ~exist("rishi_data", "var")
    load("../../data/brain_and_rishi_data.mat", "rishi_data")
end

rd  = rishi_data;
gtx = rd.sim_coordinates.x;
gty = rd.sim_coordinates.y;

mask     = brain.all_mask(:,7:end);
ntrials  = size(mask,1);
tpts     = cellfun(@(s) find(s,1,"last"),num2cell(mask,2))*50;

gtCell = cell(ntrials,1);

for i = 1:ntrials
    gtCell{i} = [
        gtx{i}(1:50:tpts(i))'
        gty{i}(1:50:tpts(i))'
        repmat(rd.xdot0(i),1,tpts(i)/50)
        repmat(rd.ydot0(i),1,tpts(i)/50)
        ];
end

gtCell = cat(2,gtCell{:});
oracleLM  = {pdist(gtCell',"euclidean")};



%% -------------------------------------------------------------------------
%                        Run Raw Correlations with parfeval
%% -------------------------------------------------------------------------

bbrnncor  = asyncCorr(rdmBrain, rdmBBs);
dSPMcor   = asyncCorr(rdmBrain, rdmProg);
linmapcor = asyncCorr(rdmBrain, {rdmLM}); 
oraclecor = asyncCorr(rdmBrain, oracleLM);

%% -------------------------------------------------------------------------
%                     Plot Raw RSA Correlations Grouped
%% -------------------------------------------------------------------------

plotGroupedRawCorrelations(bbrnncor, dSPMcor, bbrnns);
% plotGroupedRawCorrelations(bbrnncor, oraclecor, bbrnns);

%% -------------------------------------------------------------------------
%                    Run Residual RSA
%% -------------------------------------------------------------------------

% Define logical keys for model grouping
losskey = contains(string({bbrnns.loss_type}), "-mov");
neurkey = cellfun(@(s) size(s,1), {bbrnns.data_neur_nxcxt}) == 40;
inpkey  = contains(string({bbrnns.input_representation}), "gabor");

% Group indices
nextp   = losskey & neurkey & inpkey;
pdlonly = ~losskey & neurkey & inpkey;

% Assign RDM sets
nextTimePoint_rdms = rdmBBs(nextp);
paddleOnly_rdms    = rdmBBs(pdlonly);
programmed_rdms    = rdmProg;
oracle_rdms        = rdmOracle;
linmap_rdms        = {rdmLM};
neural_rdms        = rdmBrain;

corrtype = "Spearman";
RDMCELL = {neural_rdms,...
           programmed_rdms,...
           nextTimePoint_rdms,...
           paddleOnly_rdms,...
           oracle_rdms,...
           linmap_rdms
           };

% force run triggers are there to make sure these functions don't get run
% accidently if they have already been computed. Switch to "true" if you
% have any of the rsa structures in your workspace but want to rerun the
% residualized computations.

% Run Residual RSA for Programmed Models
forceRun1 = false;
if ~exist("dSPM_rsaStruct","var") || forceRun1  
    dSPM_rsaStruct = dSPM_residualization(RDMCELL, corrtype);  
end

% Run Residual RSA for Next Timepoint Models
forceRun2 = false;
if ~exist("nextTP_rsaStruct","var") || forceRun2
    nextTP_rsaStruct = nextTP_residualization(RDMCELL, corrtype);
end

% Run Residual RSA for Paddle Only Models
forceRun3 = false;
if ~exist("paddle_rsaStruct","var") || forceRun3
    paddle_rsaStruct = paddle_residualization(RDMCELL, corrtype);
end

% Run Residual RSA for Linear Map
forceRun4 = false;
if ~exist("oracle_rsaStruct","var") || forceRun4
    oracle_rsaStruct = oracle_residualization(RDMCELL, corrtype);
end

% Run Residual RSA for Linear Map
forceRun5 = true;
if ~exist("linmap_rsaStruct","var") || forceRun5
    linmap_rsaStruct = linmap_residualization(RDMCELL, corrtype);
end

% %%
% % Plot programmed residuals
% plotResidualRSAProgrammed(dSPM_rsaStruct);

%%
% Plot black box residuals
plotResidualRSABlackBox(nextTP_rsaStruct, paddle_rsaStruct);

% close all
% clc

% Plot violin comparison with significance (Programmed vs. NextTP)
plotViolinComparisonRSA(dSPM_rsaStruct, nextTP_rsaStruct);

%% Main Text Figure 3 RSA 

rsaStructCell = {
      dSPM_rsaStruct , "dspm"
    nextTP_rsaStruct , "nextTP"
    linmap_rsaStruct , "linmap"
    oracle_rsaStruct , "ballState"
    paddle_rsaStruct , "paddle"};

fields = cellfun(@fieldnames, rsaStructCell(:,1),UniformOutput=0);

typestr = "_residual_one";
strKey = [
    "minus_nextTP","minus_linmap","minus_nextTP_lm"
     "minus_dSPM","minus_linmap","minus_dSPM_lm"
     "minus_dSPM","minus_nextTP","minus_dSPM_nextTP"
        ]+typestr;

cfn = @(fld,strs) string(fld(contains(fld,strs)));
values = cellfun(@(c,s) cfn(c,s), ...
    fields(1:3), num2cell(strKey,2),uniformoutput=0);

rsaStructsPlot = [rsaStructCell(1:3,:) values];

plotViolinComparisonRSA_new(rsaStructsPlot)

%% Supplementary Text RSA Figure--all models, all condintions

typestr = "_residual_one";

cfn = @(fld,strs) string(fld(~contains(fld,strs)));

values = cellfun(@(c) cfn(c,typestr), ...
    fields,uniformoutput=0);

values{1} = values{1}([3 1 2 4 6 7 5 8]);
values{2} = values{2}([3 1 4 2 5 7 6 8]);
values{3} = values{3}([3 1 2 4 6 5 7 8]);
values{4} = values{4}([3 1 2 4 6 5 7 8]);
values{5} = values{5}([3 1 2 4 6 5 7 8]);

rsaStructsPlot = [rsaStructCell(1:5,:) values];

plotBoxComparisonRSA(rsaStructsPlot)

%}
%% -------------------------------------------------------------------------
%                    Local Plotting Functions
%% -------------------------------------------------------------------------

function plotViolinComparisonRSA_new(rsaStructs)
    % ---------------------------------------------------------------
    % ---------- 1.  Collect column-vectors -------------------------
       
    unfurl2 = @(stct) vertcat(stct{:});
    unfurl1 = @(stct,flds) unfurl2(cellfun(@(f) [stct.(f)],flds,uniformoutput=0));
    
    corrs = cellfun(@(s) num2cell(unfurl1(s{1},s{2}),2), ...
        num2cell(rsaStructs(:,[1 3]),2),UniformOutput=0 );
    
    corrs = vertcat(corrs{:});
    
    fld1    = string(strsplit(rsaStructs{1,3}{1},"_"));
    trimstr = [strjoin(fld1([1 2]),"_")+"_" "_"+strjoin(fld1(end-[1 0]),"_")];
    labels  = [
            rsaStructs{1,2}+"-"+erase(string(rsaStructs{1,3}),trimstr)
            rsaStructs{2,2}+"-"+erase(string(rsaStructs{2,3}),trimstr)
            rsaStructs{3,2}+"-"+erase(string(rsaStructs{3,3}),trimstr)
            ];
    
    % Common length (shorter vectors keep all rows, longer ones are clipped)
    N     = min(cellfun(@numel, corrs));
    corrs = cellfun(@(v)v(1:N)', corrs, 'uni', 0);   % force row-vectors
    
    % % ---------- 2.  Long-form arrays for built-in violinplot -------
    y   = vertcat(corrs{:});         % numeric column
    grp = repelem(labels, N).';      % cell array of char vectors
    grp = categorical(grp, labels, 'Ordinal', true);  % preserves left→right order
    
    % ---------- 3.  Plot -------------------------------------------
    figure;
    v = violinplot(grp,y , "DensityScale","count");
    ylabel('RSA (Spearman)');
    title('RSA residuals (-one regressors): Programmed vs NextTP');
    ylim([0 1]); grid on;
    
    % ---------- 4.  Optional paired-star annotations ---------------
    pairs = [1 5; 2 7; 3 6];          % Raw, NextTP-resid, Paddle-resid comparisons
    addStars(gca, reshape(y, N, []), pairs);  % your existing helper
    
    fx = @(y) randn(numel(y),1)*0.1;
    
    for i = 1:numel(corrs)
        scatter(fx(corrs{i})+i,corrs{i});
    end

end

function plotViolinComparisonRSA(rsaStruct, staticRSA_nextTP)
% ---------------------------------------------------------------
% Seven-way violin plot (built-in violinplot)
% Order: Prog-Raw • Prog-NextTP • Prog-PaddleOnly • Prog-Both •
%        NextTP-Raw • NextTP-PaddleOnly • NextTP-Prog
% ---------------------------------------------------------------

% ---------- 1.  Collect column-vectors -------------------------
P = vertcat(rsaStruct);    % programmed model struct array

vals = { ...
    double([P.raw]),                                             ... % Prog-Raw
    double([P.brain_minus_nextTimePoint_residual_allRegressor]), ... % Prog-NextTP
    double([P.brain_minus_paddleOnly_residual_allRegressor]),    ... % Prog-Pdl
    double([P.brain_minus_oracle_residual_oneRegressor]),        ... % Prog-Oracle
    double([P.brain_minus_all_residual_allRegressor]),           ... % Prog-Both
    double([staticRSA_nextTP.raw]),                              ... % NextTP-Raw
    double([staticRSA_nextTP.brain_minus_paddleOnly_residual_allRegressor]), ... % NextTP-Pdl
    double([staticRSA_nextTP.brain_minus_prnn_residual_allRegressor]),...   % NextTP-Prog
    double([staticRSA_nextTP.brain_minus_oracle_residual_oneRegressor]),... % NextTP-Oracle
    double([staticRSA_nextTP.brain_minus_all_residual_allRegressor])};      

% Common length (shorter vectors keep all rows, longer ones are clipped)
N    = min(cellfun(@numel, vals));
vals = cellfun(@(v)v(1:N)', vals, 'uni', 0);   % force row-vectors

% ---------- 2.  Long-form arrays for built-in violinplot -------
labels = {'Prog-Raw','Prog-NextTP','Prog-PaddleOnly','Prog-Oracle','Prog-Both', ...
          'NextTP-Raw','NextTP-PaddleOnly','NextTP-Prog','NextTP-Oracle','NextTP-Both'};

y = vertcat(vals{:});          % numeric column
grp = repelem(labels, N).';      % cell array of char vectors
grp = categorical(grp, labels, 'Ordinal', true);  % preserves left→right order

% ---------- 3.  Plot -------------------------------------------
figure;
v = violinplot(grp,y , "DensityScale","count");
ylabel('RSA (Pearson / Spearman)');
title('RSA residuals (-one regressors): Programmed vs NextTP');
ylim([0 1]); grid on;

% ---------- 4.  Optional paired-star annotations ---------------
pairs = [1 5; 2 7; 3 6];          % Raw, NextTP-resid, Paddle-resid comparisons
addStars(gca, reshape(y, N, []), pairs);  % your existing helper

fx = @(y) randn(numel(y),1)*0.1;

for i = 1:numel(vals)
    scatter(fx(vals{i})+i,vals{i});
end



end

function addStars(axHandle, data, pairs)
    nPair  = size(pairs,1);
    p_data = zeros(nPair,1);

    for p = 1:nPair
        i = pairs(p,1); j = pairs(p,2);
        [~, p_data(p)]    = ttest2(data(:,i), data(:,j), 'Vartype','unequal');
    end

    starfun = @(p) ...
        repmat('*',1, 3*(p<0.001) + 2*(p>=0.001 & p<0.01) + ...
                      1*(p>=0.01 & p<0.05) );  % '', *, **, ***
    stars = arrayfun(starfun, p_data, 'uni', 0);

    hold(axHandle, "on");
    yl = ylim; yStart = yl(2) * 1.02;
    yStep = diff(yl) * 0.07;

    for p = 1:nPair
        x1 = pairs(p,1); x2 = pairs(p,2);
        y = yStart + (p-1)*yStep;
        plot(axHandle, [x1 x1 x2 x2], [y-0.01 y y y-0.01], 'k', 'LineWidth', 1)
        text(axHandle, mean([x1 x2]), y+0.01, stars{p}, ...
            'HorizontalAlignment','center','FontSize',12)
    end

    ylim(axHandle, [yl(1) yStart + (nPair-1)*yStep + 0.05])
end

function plotBarComparisonRSA(rsaStructs)
    % ---------------------------------------------------------------
    % ---------- 1. Collect column-vectors -------------------------
    unfurl2 = @(stct) vertcat(stct{:});
    
    % Build flat lists of all data
    allCorrs = {};
    allModelTypes = string([]);
    allComparisonTypes = string([]);
    
    for i = 1:size(rsaStructs, 1)
        modelName = string(rsaStructs{i, 2});
        fieldList = rsaStructs{i, 3}; % Cell array of field names
        structData = rsaStructs{i, 1};
        
        % Extract data for each field in this model
        for j = 1:numel(fieldList)
            fieldName = string(fieldList{j});
            data = unfurl2({structData.(fieldList{j})});
            
            allCorrs{end+1} = data;
            allModelTypes(end+1) = modelName;
            allComparisonTypes(end+1) = fieldName;
        end
    end
    
    % Common length
    N = min(cellfun(@numel, allCorrs));
    allCorrs = cellfun(@(v)v(1:N)', allCorrs, 'uni', 0);
    
    % ---------- 2. Compute statistics -----------------------------
    means = cellfun(@mean, allCorrs);
    sems = cellfun(@(x) std(x)/sqrt(numel(x)), allCorrs);
    
    % ---------- 3. Organize data by model -------------------------
    uniqueModels = unique(allModelTypes, 'stable');
    nModels = numel(uniqueModels);
    
    % Group data by model
    modelData = cell(nModels, 1);
    for i = 1:nModels
        idx = allModelTypes == uniqueModels(i);
        modelData{i}.corrs = allCorrs(idx);
        modelData{i}.means = means(idx);
        modelData{i}.sems  = sems(idx);
        modelData{i}.labels = allComparisonTypes(idx);
        modelData{i}.nBars = sum(idx);
    end
    
    % ---------- 4. Create grouped bar plot ------------------------
    figure;
    hold on;
    
    % Calculate positions
    barWidth = 0.8;
    groupGap = 1.5;
    
    currentX = 0;
    allXPositions = [];
    allMeans = [];
    allSems = [];
    allCorrsForPlot = {};
    groupCenters = [];
    
    for i = 1:nModels
        nBars = modelData{i}.nBars;
        xPositions = currentX + (1:nBars);
        
        allXPositions   = [allXPositions, xPositions];
        allMeans        = [allMeans, modelData{i}.means];
        allSems         = [allSems, modelData{i}.sems];
        allCorrsForPlot = [allCorrsForPlot, modelData{i}.corrs];
        
        groupCenters(i) = mean(xPositions);
        currentX = xPositions(end) + groupGap;
    end
    
    % Create bars
    b = bar(allXPositions, allMeans, barWidth);
    b.FaceColor = 'flat';
    b.EdgeColor = 'k';
    b.LineWidth = 1;
    
    % Add error bars
    errorbar(allXPositions, allMeans, allSems, 'k.', ...
        'LineWidth', 1.5, 'CapSize', 8);
    
    % Add individual data points with jitter
    fx = @(n) randn(n,1)*0.05;
    for i = 1:numel(allCorrsForPlot)
        scatter(fx(numel(allCorrsForPlot{i}))+allXPositions(i), ...
            allCorrsForPlot{i}, 15, 'k', 'filled', ...
            'MarkerFaceAlpha', 0.3);
    end
    
    % ---------- 5. Formatting -------------------------------------
    set(gca, 'XTick', groupCenters, 'XTickLabel', uniqueModels);
    ylabel('RSA (Spearman)');
    title('RSA residuals (-one regressors): Programmed vs NextTP');
    ylim([0 1]);
    grid on;
    box on;
    hold off;
    
    % Add vertical lines between groups
    for i = 1:nModels-1
        xline(groupCenters(i) + (groupCenters(i+1)-groupCenters(i))/2, ...
            '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    end
end

function plotBoxComparisonRSA(rsaStructs)
    % ---------------------------------------------------------------
    % ---------- 1. Collect column-vectors -------------------------
    unfurl2 = @(stct) vertcat(stct{:});
    
    % Build flat lists of all data
    allCorrs = {};
    allModelTypes = string([]);
    allComparisonTypes = string([]);
    
    for i = 1:size(rsaStructs, 1)
        modelName = string(rsaStructs{i, 2});
        fieldList = rsaStructs{i, 3}; % Cell array of field names
        structData = rsaStructs{i, 1};
        
        % Extract data for each field in this model
        for j = 1:numel(fieldList)
            fieldName = string(fieldList{j});
            data = unfurl2({structData.(fieldList{j})});
            
            allCorrs{end+1} = data;
            allModelTypes(end+1) = modelName;
            allComparisonTypes(end+1) = fieldName;
        end
    end
    
    % Common length
    N = min(cellfun(@numel, allCorrs));
    allCorrs = cellfun(@(v)v(1:N)', allCorrs, 'uni', 0);
    
    % ---------- 2. Organize data by model -------------------------
    uniqueModels = unique(allModelTypes, 'stable');
    nModels = numel(uniqueModels);
    
    % Group data by model
    modelData = cell(nModels, 1);
    for i = 1:nModels
        idx = allModelTypes == uniqueModels(i);
        modelData{i}.corrs = allCorrs(idx);
        modelData{i}.labels = allComparisonTypes(idx);
        modelData{i}.nBoxes = sum(idx);
    end
    
    % ---------- 3. Create grouped box plot ------------------------
    figure;
    hold on;
    
    % Calculate positions
    boxWidth = 0.6;
    groupGap = 1.5;
    
    currentX = 0;
    allXPositions = [];
    groupCenters = [];
    allCorrsForPlot=[];
    for i = 1:nModels
        nBoxes = modelData{i}.nBoxes;
        xPositions = currentX + (1:nBoxes);
        
        allXPositions   = [allXPositions, xPositions];
        allCorrsForPlot = [allCorrsForPlot, modelData{i}.corrs];
        groupCenters(i) = mean(xPositions);
        currentX = xPositions(end) + groupGap;
    end
    
    % Prepare data for boxplot
    allData = [];
    groupLabels = [];
    for i = 1:numel(allCorrs)
        allData = [allData; allCorrs{i}(:)];
        groupLabels = [groupLabels; repmat(i, numel(allCorrs{i}), 1)];
    end
    
    % Create box plot
    boxplot(allData, groupLabels, 'Positions', allXPositions, ...
        'Widths', boxWidth, 'Colors', 'k', ...
        'Symbol', 'o', 'OutlierSize', 4);
    
    % Customize box appearance
    h = findobj(gca, 'Tag', 'Box');
    for j = 1:length(h)
        patch(get(h(j), 'XData'), get(h(j), 'YData'), [0.8 0.8 0.8], ...
            'FaceAlpha', 0.5, 'EdgeColor', 'k', 'LineWidth', 1.5);
    end

    % Add individual data points with jitter
    

    fx = @(n) randn(n,1)*0.05;
    for i = 1:numel(allCorrsForPlot)
        scatter(fx(numel(allCorrsForPlot{i}))+allXPositions(i), ...
            allCorrsForPlot{i}, 15, 'k', 'filled', ...
            'MarkerFaceAlpha', 0.3);
    end
    
    
    % ---------- 4. Formatting -------------------------------------
    set(gca, 'XTick', groupCenters, 'XTickLabel', uniqueModels);
    ylabel('RSA (Spearman)');
    title('RSA residuals (-one regressors): Programmed vs NextTP');
    ylim([0 1]);
    grid on;
    box on;
    
    % Add vertical lines between groups
    for i = 1:nModels-1
        xline(groupCenters(i) + (groupCenters(i+1)-groupCenters(i))/2, ...
            '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    end
    
    hold off;
end
%% -------------------------------------------------------------------------
%                    Local Plotting Functions
%% -------------------------------------------------------------------------

function plotResidualRSAProgrammed(rsaStruct)
    fields = [
        "raw"                    "Raw"
        "brain_minus_nextTimePoint_residual_oneRegressor"  "-nextOne"
        "brain_minus_nextTimePoint_residual_allRegressor"  "-nextAll"
        "brain_minus_oracle_residual_oneRegressor"         "-oracleOne"
        "brain_minus_paddleOnly_residual_oneRegressor"     "-paddleOne"
        "brain_minus_paddleOnly_residual_allRegressor"     "-paddleAll"
        "brain_minus_all_residual_oneRegressor"            "-bothOne"
        "brain_minus_all_residual_allRegressor"            "-bothAll"
    ];

    nfields = size(fields, 1);
    a = vertcat(rsaStruct);
    fx = @(d) randn(numel(d),1) * .1;

    figure; gca; hold on
    for i = 1:nfields
        data = [a.(fields(i,1))];
        scatter(fx(data) + i, data, 'filled')
    end
    hold off
    ylim([0, 1])
    xticks(1:nfields)
    xticklabels(fields(:,2))
    title('Programmed Residual RSA')
    grid on
end

function plotResidualRSABlackBox(staticRSA_nextTP, staticRSA_paddle)
    % Panel 1 - Next Time Point
    fields1 = [
        "raw"             "Raw"
        "brain_minus_prnn_residual_oneRegressor"         "-prnnOne"
        "brain_minus_prnn_residual_allRegressor"         "-prnnAll"
        "brain_minus_paddleOnly_residual_oneRegressor"   "-paddleOne"
        "brain_minus_paddleOnly_residual_allRegressor"   "-paddleAll"
        "brain_minus_oracle_residual_oneRegressor"       "-oracle"
    ];

    % Panel 2 - Paddle Only
    fields2 = [
        "raw" "Raw"
        "brain_minus_prnn_residual_oneRegressor" "-prnnOne"
        "brain_minus_prnn_residual_allRegressor" "-prnnAll"
    ];

    fx = @(d) randn(numel(d), 1) * .1;

    figure;
    subplot(1,3,1), hold on, title("Next TP Residual RSA")
    for i = 1:size(fields1,1)
        data = [staticRSA_nextTP.(fields1(i,1))];
        scatter(fx(data) + i, data, 'filled')
    end
    hold off, ylim([0,1]), xticks(1:size(fields1,1)), xticklabels(fields1(:,2)), grid on

    subplot(1,3,2), hold on, title("Paddle Only Residual RSA")
    for i = 1:size(fields2,1)
        data = [staticRSA_paddle.(fields2(i,1))];
        scatter(fx(data) + i, data, 'filled')
    end
    hold off, ylim([0,1]), xticks(1:size(fields2,1)), xticklabels(fields2(:,2)), grid on

    subplot(1,3,3), hold on, title("Overlayed RSA Residuals")
    for i = 1:size(fields1,1)
        d1 = [staticRSA_nextTP.(fields1(i,1))];
        d2 = [staticRSA_paddle.(fields1(min(i, size(fields2,1)),1))];
        scatter(fx(d1) + i - 0.15, d1, 'filled')
        scatter(fx(d2) + i + 0.15, d2, 'filled')
    end
    hold off, ylim([0,1]), xticks(1:size(fields1,1)), xticklabels(fields1(:,2)), grid on
end

%% residualization helpers


function dSPM_rsaStruct = dSPM_residualization(RDMCELL, corrtype)
%%
[neural_rdms,programmed_rdms,...
    nextTimePoint_rdms,paddleOnly_rdms,linmap_rdms] = ...
            RDMCELL{:};

    % Run residual RSA
    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "nextTP", ...
        {nextTimePoint_rdms}, ...
        corrtype); % dSPM - next time point models

    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "paddle", ...
        {paddleOnly_rdms}, ...
        corrtype, dSPM_rsaStruct); % dSPM - paddle only
    
    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "linmap", ...
        {linmap_rdms}, ...
        corrtype, dSPM_rsaStruct); % dSPM - linear map

    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "paddle_lm", ...
        {paddleOnly_rdms linmap_rdms}, ...
        corrtype,dSPM_rsaStruct); % dSPM - {paddle,LM}

    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "nextTP_lm", ...
        {nextTimePoint_rdms linmap_rdms}, ...
        corrtype, dSPM_rsaStruct); % dSPM - {nextTP,LM}
    
    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "nextTP_paddle", ...
        {nextTimePoint_rdms paddleOnly_rdms}, ...
        corrtype, dSPM_rsaStruct); % dSPM - {nextTP,paddle}
    
    dSPM_rsaStruct = run_time_collapsed_residual_programmed( ...
        programmed_rdms, ...
        neural_rdms, "all", ...
        {nextTimePoint_rdms paddleOnly_rdms linmap_rdms}, ...
        corrtype, dSPM_rsaStruct); % dSPM - {nextTP,paddle,LM}
end

function nextTP_rsaStruct = nextTP_residualization(RDMCELL, corrtype)

[neural_rdms,programmed_rdms,...
    nextTimePoint_rdms,paddleOnly_rdms,linmap_rdms] = ...
            RDMCELL{:};

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "dSPM", ...
        {programmed_rdms}, ...
        corrtype); % nextTP - dSPM

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "paddle", ...
        {paddleOnly_rdms}, ...
        corrtype, nextTP_rsaStruct); % nextTP - paddle only

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "linmap", ...
        {linmap_rdms}, ...
        corrtype, nextTP_rsaStruct); % nextTP - linear map (LM)

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "dSPM_lm", ...
        {programmed_rdms linmap_rdms}, ...
        corrtype,nextTP_rsaStruct); % nextTP - {dSPM, LM}

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "dSPM_paddle", ...
        {programmed_rdms paddleOnly_rdms}, ...
        corrtype,nextTP_rsaStruct); % nextTP - {dSPM, paddle}

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "paddle_lm", ...
        {paddleOnly_rdms linmap_rdms}, ...
        corrtype,nextTP_rsaStruct); % nextTP - {LM, paddle}

    nextTP_rsaStruct = run_time_collapsed_residual_programmed( ...
        nextTimePoint_rdms, ...
        neural_rdms, "all", ...
        {programmed_rdms paddleOnly_rdms linmap_rdms}, ...
        corrtype,nextTP_rsaStruct); % nextTP - {dSPM, LM, paddle}

end

function paddle_rsaStruct = paddle_residualization(RDMCELL, corrtype)

[neural_rdms,programmed_rdms,...
    nextTimePoint_rdms,paddleOnly_rdms,linmap_rdms] = ...
            RDMCELL{:};

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "dSPM", ...
        {programmed_rdms}, ...
        corrtype); % paddle - dSPM

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "nextTP", ...
        {nextTimePoint_rdms}, ...
        corrtype, paddle_rsaStruct); % paddle - nextTP


    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "linmap", ...
        {linmap_rdms}, ...
        corrtype, paddle_rsaStruct); % paddle - linear map (LM)

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "dSPM_lm", ...
        {programmed_rdms linmap_rdms}, ...
        corrtype,paddle_rsaStruct); % paddle - {dSPM, LM}

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "dSPM_nextTP", ...
        {programmed_rdms nextTimePoint_rdms}, ...
        corrtype,paddle_rsaStruct); % paddle - {dSPM, nextTP}

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "nextTP_lm", ...
        {nextTimePoint_rdms linmap_rdms}, ...
        corrtype,paddle_rsaStruct); % paddle - {LM, nextTP}

    paddle_rsaStruct = run_time_collapsed_residual_programmed( ...
        paddleOnly_rdms, ...
        neural_rdms, "all", ...
        {programmed_rdms nextTimePoint_rdms linmap_rdms}, ...
        corrtype,paddle_rsaStruct); % paddle - {dSPM, LM, nextTP}
end

function oracle_rsaStruct = oracle_residualization(RDMCELL, corrtype)
%%
[neural_rdms,programmed_rdms,...
    nextTimePoint_rdms,paddleOnly_rdms,oracle_rdms,linmap_rdms] = ...
            RDMCELL{:};

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "dSPM", ...
        {programmed_rdms}, ...
        corrtype); % linear map - dSPM

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "nextTP", ...
        {nextTimePoint_rdms}, ...
        corrtype, oracle_rsaStruct); % linear map - nextTP

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "paddle", ...
        {paddleOnly_rdms}, ...
        corrtype, oracle_rsaStruct); % linear map - paddle 

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "dSPM_paddle", ...
        {programmed_rdms paddleOnly_rdms}, ...
        corrtype,oracle_rsaStruct); % LM - {dSPM, paddle}

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "dSPM_nextTP", ...
        {programmed_rdms nextTimePoint_rdms}, ...
        corrtype,oracle_rsaStruct); % LM - {dSPM, nextTP}

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "nextTP_paddle", ...
        {nextTimePoint_rdms paddleOnly_rdms}, ...
        corrtype,oracle_rsaStruct); % LM - {nextTP, paddle}

    oracle_rsaStruct = run_time_collapsed_residual_combined( ...
        oracle_rdms, ...
        neural_rdms, "all", ...
        {programmed_rdms nextTimePoint_rdms paddleOnly_rdms}, ...
        corrtype,oracle_rsaStruct); % LM - {dSPM, paddle, nextTP}

end

function linmap_rsaStruct = linmap_residualization(RDMCELL, corrtype)
%%
[neural_rdms,programmed_rdms,...
    nextTimePoint_rdms,paddleOnly_rdms,oracle_rdms,linmap_rdms] = ...
            RDMCELL{:};

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "dSPM", ...
        {programmed_rdms}, ...
        corrtype); % linear map - dSPM

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "nextTP", ...
        {nextTimePoint_rdms}, ...
        corrtype, linmap_rsaStruct); % linear map - nextTP

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "paddle", ...
        {paddleOnly_rdms}, ...
        corrtype, linmap_rsaStruct); % linear map - paddle 

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "dSPM_paddle", ...
        {programmed_rdms paddleOnly_rdms}, ...
        corrtype,linmap_rsaStruct); % LM - {dSPM, paddle}

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "dSPM_nextTP", ...
        {programmed_rdms nextTimePoint_rdms}, ...
        corrtype,linmap_rsaStruct); % LM - {dSPM, nextTP}

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "nextTP_paddle", ...
        {nextTimePoint_rdms paddleOnly_rdms}, ...
        corrtype,linmap_rsaStruct); % LM - {nextTP, paddle}

    linmap_rsaStruct = run_time_collapsed_residual_combined( ...
        linmap_rdms, ...
        neural_rdms, "all", ...
        {programmed_rdms nextTimePoint_rdms paddleOnly_rdms}, ...
        corrtype,linmap_rsaStruct); % LM - {dSPM, paddle, nextTP}

end

%% -------------------------------------------------------------------------
%                    Utility Function Definitions (Local)
%% -------------------------------------------------------------------------

function staticRSA = run_time_collapsed_residual_combined( ...
    rdm_model, rdm_brain,losstype,regressors,corrtype,staticRSA)
%%  

    if ~exist("staticRSA","var"),staticRSA(1:2)=struct;end

    nmodels  = numel(rdm_model); 
    dBrain   = zscore(rdm_brain);

    nregress = numel(regressors);

    switch nregress
        case 1
            dReg1      = zscore(vertcat(regressors{1}{:})');

            fcall1     = @(x) dReg1(:,randi(size(dReg1,2)));
            fcallAll   = dReg1;
        case 2
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2)))];
            fcallAll = @(x) [dReg1 dReg2];
        case 3
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
            dReg3    = zscore(vertcat(regressors{3}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2))),...
                             dReg3(:,randi(size(dReg3,2)))];
            fcallAll = @(x) [dReg1 dReg2 dReg3];
    end

    dBrain_all = regress_out(dBrain, fcallAll());
    dBrain_one = zeros(numel(dBrain_all),nmodels);
    dModel_one = dBrain_one;
    dModel_all = dBrain_one;
    dModel_raw = cellfun(@zscore,rdm_model,UniformOutput=false);

    if nmodels == 1
          nruns = 24;
          dModel_raw = num2cell(repmat(dModel_raw{1},nruns,1),2);  
    else, nruns = nmodels;
    end

    for i = 1:nruns
        printloop(i,nruns)
        dBrain_one(:,i) = regress_out(dBrain, fcall1());   
        dModel_one(:,i) = regress_out(dModel_raw{i}, fcall1());
        dModel_all(:,i) = regress_out(dModel_raw{i}, fcallAll());
    end
    
    rawTrig = ~strcmp(string(fieldnames(staticRSA)),"raw");
    parfor i = 1:nruns

        printloop(i,nruns)
        dModel = dModel_raw{i}; 
    
        rsa_static_raw   = corr(dBrain', dModel', 'type',corrtype);
        rsa_static_one   = corr(dBrain_one(:,i), dModel_one(:,i), 'type',corrtype);
        rsa_static_all   = corr(dBrain_all, dModel_all(:,i), 'type',corrtype);
                
        strid    = "brain_minus_"+losstype;
        staticRSA(i).(strid+"_residual_oneRegressor")   =  rsa_static_one ;                       
        staticRSA(i).(strid+"_residual_allRegressor")   =  rsa_static_all ; 
        
        if rawTrig,staticRSA(i).("raw")   =  rsa_static_raw ; end

    end

end

function staticRSA = run_time_collapsed_residual_programmed( ...
    rdm_prnn, rdm_brain,losstype,regressors,corrtype,staticRSA)
%%  

    if ~exist("staticRSA","var"),staticRSA(1:2)=struct;end

    nmodels  = numel(rdm_prnn); 
    dBrain   = zscore(rdm_brain);

    nregress = numel(regressors);

    switch nregress
        case 1
            dReg1      = zscore(vertcat(regressors{1}{:})');

            fcall1     = @(x) dReg1(:,randi(size(dReg1,2)));
            fcallAll   = dReg1;
        case 2
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2)))];
    
            fcallAll = @(x) [dReg1 dReg2];
        case 3
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
            dReg3    = zscore(vertcat(regressors{3}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2))),...
                             dReg3(:,randi(size(dReg3,2)))];
    
            fcallAll = @(x) [dReg1 dReg2 dReg3];
    end

    dBrain_all = regress_out(dBrain, fcallAll());
    dBrain_one = zeros(numel(dBrain_all),nmodels);
    dModel_one = dBrain_one;
    dModel_all = dBrain_one;
    dModel_raw = cellfun(@zscore,rdm_prnn,UniformOutput=false);
    for i = 1:nmodels
        printloop(i,nmodels)
        dBrain_one(:,i) = regress_out(dBrain, fcall1());   
        dModel_one(:,i) = regress_out(dModel_raw{i}, fcall1());
        dModel_all(:,i) = regress_out(dModel_raw{i}, fcallAll());
    end
    
    rawTrig = ~strcmp(string(fieldnames(staticRSA)),"raw");
    parfor i = 1:nmodels

        printloop(i,nmodels)
        dModel   = dModel_raw{i}; 
    
        rsa_static_raw   = corr(dBrain', dModel', 'type',corrtype);
        rsa_static_one   = corr(dBrain_one(:,i), dModel_one(:,i), 'type',corrtype);
        rsa_static_all   = corr(dBrain_all, dModel_all(:,i), 'type',corrtype);
                
        strid    = "brain_minus_"+losstype;
        staticRSA(i).(strid+"_residual_oneRegressor")   =  rsa_static_one ;                       
        staticRSA(i).(strid+"_residual_allRegressor")   =  rsa_static_all ; 
        
        if rawTrig,staticRSA(i).("raw")   =  rsa_static_raw ; end

    end

end

function staticRSA = run_time_collapsed_residual_blackbox(rdm_bbrnn, rdm_brain,losstype,regressors,corrtype,staticRSA)
%%  

    if ~exist("staticRSA","var"),staticRSA(1:2)=struct;end

    % nprnns  = numel(regressors);
    % dRegress = zscore(vertcat(regressors{:})');

    nmodels  = numel(rdm_bbrnn); 
    dBrain   = zscore(rdm_brain);

    nregress = numel(regressors);

    switch nregress
        case 1
            nmodelsreg = numel(regressors);
            dRegress   = zscore(vertcat(regressors{:})');
            fcall1     = @(x) dRegress(:,randi(nmodelsreg));
            fcallAll   = dRegress;
        case 2
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2)))];
    
            fcallAll = @(x) [dReg1 dReg2];
        case 3
            dReg1    = zscore(vertcat(regressors{1}{:})');
            dReg2    = zscore(vertcat(regressors{2}{:})');
            dReg3    = zscore(vertcat(regressors{3}{:})');
    
            fcall1   = @(x) [dReg1(:,randi(size(dReg1,2))),...
                             dReg2(:,randi(size(dReg2,2))),...
                             dReg3(:,randi(size(dReg3,2)))];
    
            fcallAll = @(x) [dReg1 dReg2 dReg3];
    end


    dBrain_all = regress_out(dBrain, fcallAll());
    dBrain_one = zeros(numel(dBrain_all),nmodels);
    dModel_one = dBrain_one;
    dModel_all = dBrain_one;
    dModel_raw = cellfun(@zscore,rdm_bbrnn,UniformOutput=false);
    for i = 1:nmodels
        printloop(i,nmodels)
        dBrain_one(:,i) = regress_out(dBrain, fcall1());   
        dModel_one(:,i) = regress_out(dModel_raw{i}, fcall1());
        dModel_all(:,i) = regress_out(dModel_raw{i}, fcallAll());
    end

    % dBrain_all = regress_out(dBrain, dRegress);
    % dBrain_one = zeros(numel(dBrain_all),nmodels);
    % dModel_one = dBrain_one;
    % dModel_all = dBrain_one;
    % dModel_raw = cellfun(@zscore,rdm_bbrnn,UniformOutput=false);
    % for i = 1:nmodels
    %     printloop(i,nmodels)
    %     reg1 = dRegress(:,randi(nprnns));
    %     dBrain_one(:,i) = regress_out(dBrain, reg1);   
    %     dModel_one(:,i) = regress_out(dModel_raw{i}, reg1);
    %     dModel_all(:,i) = regress_out(dModel_raw{i}, dRegress);
    % end
    
    rawTrig = isempty(fieldnames(staticRSA));
    parfor i = 1:nmodels

        printloop(i,nmodels)
    
        rsa_static_raw   = corr(rdm_brain', rdm_bbrnn{i}', 'type',corrtype);
        rsa_static_one   = corr(dBrain_one(:,i), dModel_one(:,i), 'type',corrtype);
        rsa_static_all   = corr(dBrain_all, dModel_all(:,i), 'type',corrtype);
                
        strid    = "brain_minus_"+losstype;
        staticRSA(i).(strid+"_residual_oneRegressor")   =  rsa_static_one ;                       
        staticRSA(i).(strid+"_residual_allRegressor")   =  rsa_static_all ; 
        
        if rawTrig, staticRSA(i).("raw") =  rsa_static_raw ; end

    end

end

function result = asyncCorr(rdmBrain, rdmSet)
    n = numel(rdmSet);
    result = zeros(n, 1);
    futures = parallel.FevalFuture.empty(n, 0);
    pool = gcp();

    for i = 1:n
        futures(i) = parfeval(pool, @computeCorr, 1, rdmBrain, rdmSet{i}, i, n);
    end
    for i = 1:n
        [idx, val] = fetchNext(futures);
        result(idx) = val;
    end
end

function r = computeCorr(rdm1, rdm2, idx, total)
    printloop(idx, total);
    r = corr(rdm1', rdm2', 'Type', 'Spearman');
end

function squeezed = squeeze_cell(data)
    tmp = num2cell(data, [1 3])';
    squeezed = cellfun(@squeeze, tmp, 'UniformOutput', false);
end

function plotGroupedRawCorrelations(bbrnncor, prnncor, bbrnns)
    losskey = contains(string({bbrnns.loss_type}), "-mov");
    neurkey = cellfun(@(s) size(s, 1), {bbrnns.data_neur_nxcxt}) == 40;
    inpkey  = contains(string({bbrnns.input_representation}), "gabor");

    nextp   = losskey & neurkey & inpkey;
    pdlonly = ~losskey & neurkey & inpkey;

    cor_next_tp  = bbrnncor(nextp);
    cor_pdl_only = bbrnncor(pdlonly);

    fx = @(d) randn(numel(d), 1) * 0.1;

    figure;
    scatter(fx(cor_next_tp), cor_next_tp, 'filled'); hold on
    scatter(fx(cor_pdl_only)+1, cor_pdl_only, 'filled');
    scatter(fx(prnncor)+2, prnncor, 'filled');

    xticks(0:2)
    xticklabels({"NextTP", "PaddleOnly", "Programmed"})
    ylabel("Spearman Correlation")
    title("RSA Similarity with Brain RDM")
    ylim([0, 1])
    grid on
    hold off
end


function residualVec = regress_out(targetVec, regressors)

%% ========================================================================
% This function removes the linear contribution of one or more regressor
% vectors from a target vector by ordinary least squares. 
%
% Usage:
%   dBrain_res = regress_out(dBrain, dReg);
%   dBrain_res = regress_out(dBrain, [dReg1, dReg2, ...]);
%
% Inputs:
%   - targetVec: (N x 1) or (1 x N) vector of distances (e.g., from the brain)
%   - regressors: (N x k) matrix (or (1 x N) for single regressor) 
%                 where each column is a regressor distance vector.
%
% Output:
%   - residualVec: same size as targetVec, the residual after regressing out
%                  all columns in `regressors`.
%
% The formula is: residual = targetVec - X * (X \ targetVec),
% where X = [ones(N,1), regressors].
%% ========================================================================
    % Ensure column vectors
    targetVec = targetVec(:);  
    

    % If there are no regressors, just return targetVec
    if isempty(regressors), residualVec = targetVec;return;end

    % Check that sizes match
    if size(regressors,1) ~= length(targetVec)
        error('Target and regressors must have the same number of rows (trials).');
    end

    % Build design matrix X: first column is intercept (all ones),
    % then each column is one regressor
    X = [ones(size(regressors,1),1), regressors];

    % Solve for betas: b = X \ targetVec  (least squares)
    b = X \ targetVec;

    % Predicted = X*b
    predicted = X * b;

    % Residual = targetVec - predicted
    residualVec = targetVec - predicted;

end

