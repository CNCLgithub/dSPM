function fig = stability_wizard(reservoir, options)
% STABILITY_WIZARD  Launch the Stability Wizard GUI
%
% Usage:
%   stability_wizard()                    % Standalone mode
%   stability_wizard(res)                 % With reservoir
%   stability_wizard(res, 'Option', val)  % With options
%
% Options:
%   'equations'  - Equation struct array
%   'constants'  - Constants struct array
%   'position'   - [x, y, width, height] figure position
%
% The Stability Wizard provides:
%   - Nullcline visualization
%   - Flow field analysis
%   - Eigenstructure analysis
%   - Scaling recommendations
%   - Interactive tutorials
%
% See also: dspm_reservoir, programming_gui, StabilityWizard

    arguments
        reservoir = []
        options.equations = []
        options.constants = []
        options.position = [100 100 1400 900]
    end

    thisFile = mfilename('fullpath');
    wizardDir = fileparts(thisFile);
    frontendDir = fullfile(fileparts(wizardDir), 'frontend');
    distDir = fullfile(frontendDir, 'dist');
    
    indexPath = fullfile(distDir, 'index.html');
    if ~isfile(indexPath)
        warning(['Frontend not built. Run "npm run build" in:\n  %s\n\n' ...
                 'Using placeholder UI for now.'], frontendDir);
        fig = createPlaceholderUI(reservoir, options);
        return;
    end
    
    fig = uifigure('Name', 'Stability Wizard - dSPM Framework', ...
                   'Position', options.position, ...
                   'Color', [0.1 0.1 0.12]);
    
    html = uihtml(fig, 'Position', [0 0 fig.Position(3) fig.Position(4)], ...
                  'HTMLSource', indexPath);
    
    fig.SizeChangedFcn = @(~,~) set(html, 'Position', [0 0 fig.Position(3) fig.Position(4)]);
    
    fig.UserData.reservoir = reservoir;
    fig.UserData.equations = options.equations;
    fig.UserData.constants = options.constants;
    fig.UserData.wizard = [];
    
    if ~isempty(reservoir)
        fig.UserData.wizard = StabilityWizard(reservoir);
        if isempty(options.equations) && isprop(reservoir, 'source_equations') && ~isempty(reservoir.source_equations)
            fig.UserData.equations = reservoir.source_equations;
            fig.UserData.constants = reservoir.source_constants;
        end
    end
    
    html.DataChangedFcn = @(src, ~) handleMessage(fig, src.Data);
    
    if ~isempty(fig.UserData.equations)
        sendSystemUpdate(html, fig.UserData);
    end
end

function handleMessage(fig, data)
    if isempty(data) || ~isstruct(data), return; end
    html = findobj(fig, 'Type', 'uihtml');
    if isempty(html), return; end
    
    switch data.type
        case 'REQUEST_ANALYSIS'
            runAnalysis(fig, html);
        case 'REQUEST_TRAJECTORY'
            runTrajectory(fig, html, data.payload);
    end
end

function runAnalysis(fig, html)
    ud = fig.UserData;
    if isempty(ud.wizard) && ~isempty(ud.reservoir)
        ud.wizard = StabilityWizard(ud.reservoir);
        fig.UserData = ud;
    end
    
    if ~isempty(ud.wizard)
        ud.wizard.analyze(ud.equations, ud.constants);
        result.fixedPoints = ud.wizard.fixed_points;
        result.analysis = struct('scaleOk', ud.wizard.scale_ok, ...
            'centeredOk', ud.wizard.centered_ok, ...
            'timescaleOk', ud.wizard.timescale_ok);
        html.Data = struct('type', 'ANALYSIS_RESULT', 'payload', result);
    end
end

function runTrajectory(fig, html, payload)
    ud = fig.UserData;
    if ~isempty(ud.reservoir) && ud.reservoir.is_compiled
        ic = payload.initialCondition(:);
        steps = round(payload.duration / ud.reservoir.dt);
        try
            ud.reservoir.condition(ic);
            ud.reservoir.close_loop();
            [~, y] = ud.reservoir.simulate(steps);
            html.Data = struct('type', 'TRAJECTORY_RESULT', 'payload', struct('trajectory', y'));
        catch
        end
    end
end

function sendSystemUpdate(html, ud)
    payload = struct('name', '', 'equations', ud.equations, 'constants', ud.constants);
    if ~isempty(ud.reservoir) && isprop(ud.reservoir, 'network_name')
        payload.name = ud.reservoir.network_name;
    end
    html.Data = struct('type', 'SYSTEM_UPDATE', 'payload', payload);
end

function fig = createPlaceholderUI(reservoir, options)
    fig = uifigure('Name', 'Stability Wizard (Placeholder)', 'Position', options.position);
    uilabel(fig, 'Text', sprintf(['Stability Wizard Frontend Not Built\n\n' ...
        'To build:\n  cd stability-wizard/frontend\n  npm install\n  npm run build\n\n' ...
        'For now, use StabilityWizard class directly:\n\n' ...
        '  wiz = StabilityWizard(res);\n  wiz.analyze(equations, constants);\n  wiz.report();']), ...
        'Position', [50 200 700 400], 'FontSize', 14, 'FontName', 'Consolas');
    fig.UserData.reservoir = reservoir;
end
