function varargout = reservoir_programming_gui(reservoir)
% PROGRAMMING_GUI  Launch the Reservoir Programming GUI
%
% Usage:
%   programming_gui()           % Standalone mode - create new reservoir
%   programming_gui(res)        % Edit existing reservoir object
%   fig = programming_gui()     % Return figure handle
%
% The GUI allows programming reservoir dynamics using symbolic equations
% and saves configurations as JSON files for reproducibility.
%
% See also: dspm_reservoir, compile, decompile

    % Determine mode
    if nargin < 1 || isempty(reservoir)
        standaloneMode = true;reservoir = [];
    else
        standaloneMode = false;
        validateattributes(reservoir, {'dspm_reservoir'}, {'scalar'});
    end

    % Create figure
    fig = uifigure('Name', 'Reservoir Programming GUI', ...
                   'Position', [100 100 1280 850], ...
                   'Resize', 'on', ...
                   'AutoResizeChildren', 'off');
    
    % Store state in figure's UserData
    fig.UserData.reservoir      = reservoir;
    fig.UserData.standaloneMode = standaloneMode;
    
    % Get project root directory (reservoir_dc/)
    guiPath = fileparts(mfilename('fullpath'));
    projectRoot = fullfile(guiPath, '..', '..');
    fig.UserData.projectRoot = projectRoot;
    fig.UserData.savedNetworksDir = fullfile(projectRoot, 'saved-networks');
    fig.UserData.presetsDir = fullfile(projectRoot, 'saved-networks', 'presets');
    
    % Ensure directories exist
    if ~exist(fig.UserData.savedNetworksDir, 'dir')
        mkdir(fig.UserData.savedNetworksDir);
    end

    if ~exist(fig.UserData.presetsDir, 'dir')
        mkdir(fig.UserData.presetsDir);
    end
    
    % Create the uihtml component
    html = uihtml(fig, 'Position', [0 0 fig.Position(3) fig.Position(4)]);
    
    % Get path to dist folder
    indexPath = fullfile(guiPath, '..', 'dist', 'index.html');
    
    if ~exist(indexPath, 'file')
        html.HTMLSource = ['<html><body style="font-family: sans-serif; padding: 40px;">' ...
            '<h1>GUI Not Built</h1>' ...
            '<p>Could not find: ' strrep(indexPath, '\', '\\') '</p>' ...
            '<p>Run: cd frontend && npm install && npm run build</p>' ...
            '</body></html>'];
        if nargout, varargout{1} = fig; end
        return;
    end
    
    % Load the HTML directly
    html.HTMLSource = indexPath;
    
    % % Initialize data to send to JavaScript
    % if ~standaloneMode
    %     initData = struct(...
    %         'action', 'init', ...
    %         'payload', struct(...
    %             'standaloneMode', false, ...
    %             'reservoir', struct(...
    %                 'nNeurons', reservoir.n_neurons, ...
    %                 'nRecurrentInputs', reservoir.n_recurrent_inputs, ...
    %                 'nExternalInputs', reservoir.n_external_inputs, ...
    %                 'nRecurrentOutputs', reservoir.n_recurrent_outputs, ...
    %                 'nExternalOutputs', reservoir.n_external_outputs, ...
    %                 'gamma', reservoir.gamma, ...
    %                 'dt', reservoir.dt ...
    %             ) ...
    %         ) ...
    %     );
    % else
    %     initData = struct(...
    %         'action', 'init', ...
    %         'payload', struct(...
    %             'standaloneMode', true ...
    %         ) ...
    %     );
    % end

    % Initialize data to send to JavaScript
    if ~standaloneMode
        % Build expansion point from reservoir (match JSON schema format)
        expPoint   = struct();
        expPoint.x = struct();
        expPoint.y = struct();
        for i = 1:reservoir.n_recurrent_inputs
            expPoint.y.(sprintf('x%d', i)) = 0;  % Default to 0
        end
        for i = 1:reservoir.n_external_inputs
            expPoint.x.(sprintf('x%d', i)) = 0;  % Default to 0
        end
        
        % Build config matching JSON schema (snake_case)
        configStruct = struct(...
            'n_neurons', reservoir.n_neurons, ...
            'gamma', reservoir.gamma, ...
            'dt', reservoir.dt, ...
            'B_scale', reservoir.B_scale, ...
            'B_sparsity', reservoir.B_sparsity, ...
            'random_seed', reservoir.random_seed, ...
            'expansion_point', expPoint ...
        );
        
        % Topology (snake_case)
        topology = struct(...
            'n_recurrent_inputs', reservoir.n_recurrent_inputs, ...
            'n_external_inputs', reservoir.n_external_inputs, ...
            'n_recurrent_outputs', reservoir.n_recurrent_outputs, ...
            'n_external_outputs', reservoir.n_external_outputs ...
        );
        
        % Inferred parameters
        inferred = struct(...
            'jet_order', reservoir.jet_order, ...
            'decompilation_order', reservoir.decompilation_order ...
        );
        
        % Build payload matching NetworkSaveFile schema
        payload = struct(...
            'standaloneMode', false, ...
            'version', '1.0', ...
            'name', reservoir.network_name, ...
            'description', reservoir.network_description, ...
            'config', configStruct, ...
            'topology', topology, ...
            'inferred', inferred ...
        );
        
        % Include equations if available (convert to cell array for JSON)
        if ~isempty(reservoir.source_equations)
            payload.equations = reservoir.source_equations;
        else
            % Create empty equations for each output
            nEqs = reservoir.n_recurrent_outputs + reservoir.n_external_outputs;
            eqs = cell(nEqs, 1);
            for i = 1:nEqs
                if i <= reservoir.n_external_outputs
                    outputType = 'external';
                else
                    outputType = 'recurrent';
                end
                eqs{i} = struct('index', i, 'outputType', outputType, 'tau', '1', 'latex', '');
            end
            payload.equations = [eqs{:}];  % Convert to struct array
        end
        
        % Include constants if available
        if ~isempty(reservoir.source_constants)
            % Convert cell array to struct array if needed
            consts = reservoir.source_constants;
            if iscell(consts)
                payload.constants = [consts{:}];  % Convert cell to struct array
            else
                payload.constants = consts;
            end
        else
            % Empty struct array (not just [])
            payload.constants = struct( ...
                'name', {}, 'value', {}, ...
                'display_name',{}, 'description', {});
        end
                
        initData = struct('action', 'init', 'payload', payload);
    else
        initData = struct(...
            'action', 'init', ...
            'payload', struct('standaloneMode', true) ...
        );
    end

    % Store init data for when JS is ready
    fig.UserData.initData = initData;
    
    % Set up callback for receiving data from JavaScript
    html.DataChangedFcn = @(src, event) handleJSMessage(src, event, fig);
    
    % Handle figure resize
    fig.SizeChangedFcn = @(src, event) resizeHandler(src, html);
    
    % Return figure handle if requested
    if nargout
        varargout{1} = fig;
    end
end

function resizeHandler(fig, html)
    % Enforce minimum dimensions
    minWidth = 900;
    minHeight = 650;
    pos = fig.Position;
    if pos(3) < minWidth || pos(4) < minHeight
        pos(3) = max(pos(3), minWidth);
        pos(4) = max(pos(4), minHeight);
        fig.Position = pos;
    end
    html.Position = [0 0 fig.Position(3) fig.Position(4)];
end

function handleJSMessage(html, ~, fig)
    data = html.Data;
    if isempty(data) || ~isfield(data, 'action')
        return;
    end
    
    switch data.action
        case 'ready'
            % fprintf('Received from JS: action=%s\n', data.action);
            % JavaScript is loaded and ready - send init data
            if isfield(fig.UserData, 'initData')
                html.Data = fig.UserData.initData;
            end

        case 'compile'
            result = handleCompile(data.payload, fig);
            html.Data = struct('action', 'compile_result', 'payload', result);
            
        case 'export'
            handleExport(data.payload, fig);
            
        case 'save'
            result = handleSave(data.payload, fig);
            html.Data = struct('action', 'save_result', 'payload', result);
            
        case 'list_presets'
            result = handleListPresets(fig);
            html.Data = struct('action', 'presets_list', 'payload', result);
            
        case 'remove_preset'
            result = handleRemovePreset(data.payload, fig);
            html.Data = struct('action', 'remove_preset_result', 'payload', result);
            
        case 'browse_saved_networks'
            result = handleBrowseSavedNetworks(fig);
            html.Data = struct('action', 'saved_networks_list', 'payload', result);
            
        case 'add_to_presets'
            result = handleAddToPresets(data.payload, fig);
            html.Data = struct('action', 'add_to_presets_result', 'payload', result);
            
        case 'load_network'
            % payload may be empty for load_network (just opens file picker)
            if isfield(data, 'payload')
                payload = data.payload;
            else
                payload = struct();
            end
            result = handleLoadNetwork(payload, fig);
            html.Data = struct('action', 'load_network_result', 'payload', result);
            
        otherwise
            % Ignore unknown actions
    end
end

%% =========================================================================
%  COMPILE - Build and program the reservoir
%  =========================================================================
function result = handleCompile(payload, fig)
    try
        % Extract configuration from payload
        cfg = payload.config;
        topology = payload.topology;
        equations = payload.equations;
        constants = payload.constants;
        
        % Infer jet order and decompilation order from equations
        [jetOrder, decompOrder] = inferOrders(equations);
        
        % Generate random seed if not provided or zero
        if cfg.random_seed == 0
            rng('shuffle');
            s = rng;
            seed = s.Seed;
        else
            seed = cfg.random_seed;
        end
        
        % Set random state for reproducibility
        rng(seed);
        
        % Build expansion point vector
        expansionPoint = buildExpansionPoint(cfg.expansion_point, topology, jetOrder);
        
        % Create reservoir with inferred parameters
        reservoir = dspm_reservoir(cfg.n_neurons, ...
            'n_recurrent_inputs', topology.n_recurrent_inputs, ...
            'n_external_inputs', topology.n_external_inputs, ...
            'n_recurrent_outputs', topology.n_recurrent_outputs, ...
            'n_external_outputs', topology.n_external_outputs, ...
            'gamma', cfg.gamma, ...
            'dt', cfg.dt, ...
            'jet_order', jetOrder, ...
            'decompilation_order', decompOrder, ...
            'B_scale', cfg.B_scale, ...
            'B_sparsity', cfg.B_sparsity, ...
            'expansion_point', expansionPoint, ...
            'verbose', false);
        
        % Build the programming matrix from equations
        P = buildProgramMatrix(equations, constants, reservoir);
        
        % Compile
        [residual, rank_R, stats] = reservoir.compile(P);
        
        % Close the loop for recurrent systems
        if topology.n_recurrent_outputs > 0
            reservoir.close_loop();
        end
        
        % Store in figure
        fig.UserData.reservoir = reservoir;
        fig.UserData.lastSeed = seed;
        
        result = struct(...
            'success', true, ...
            'residual', residual, ...
            'relative_error', stats.rel_error, ...
            'rank', rank_R, ...
            'condition_number', stats.cond_R, ...
            'n_monomials', stats.n_monomials, ...
            'jet_order', jetOrder, ...
            'decompilation_order', decompOrder ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'residual', 0, ...
            'relative_error', 0, ...
            'rank', 0, ...
            'condition_number', 0, ...
            'n_monomials', 0, ...
            'jet_order', 1, ...
            'decompilation_order', 2, ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  SAVE - Save network configuration to JSON
%  =========================================================================
function result = handleSave(payload, fig)
    try
        savedNetworksDir = fig.UserData.savedNetworksDir;
        presetsDir = fig.UserData.presetsDir;
        
        % Ensure directories exist
        if ~exist(savedNetworksDir, 'dir')
            mkdir(savedNetworksDir);
        end
        if ~exist(presetsDir, 'dir')
            mkdir(presetsDir);
        end
        
        % Sanitize filename
        filename = sanitizeFilename(payload.name) + ".json";
        
        % Primary save location: always saved-networks/
        primaryPath = fullfile(savedNetworksDir, filename);
        
        % Infer orders from equations
        [jetOrder, decompOrder] = inferOrders(payload.equations);
        
        % Generate seed if not set
        if payload.config.random_seed == 0
            rng('shuffle');
            s = rng;
            seed = s.Seed;
        else
            seed = payload.config.random_seed;
        end
        
        % Update payload with inferred values
        payload.config.random_seed = seed;
        payload.inferred.jet_order = jetOrder;
        payload.inferred.decompilation_order = decompOrder;
        payload.modified = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC'));
        
        % Convert to JSON and save to primary location
        jsonStr = jsonencode(payload, 'PrettyPrint', true);
        fid = fopen(primaryPath, 'w');
        if fid == -1
            error('Could not open file for writing: %s', primaryPath);
        end
        fprintf(fid, '%s', jsonStr);
        fclose(fid);
        
        fprintf('Network saved to: %s\n', primaryPath);
        
        % If marked as preset, also copy to presets/ directory
        if isfield(payload, 'is_preset') && payload.is_preset
            presetPath = fullfile(presetsDir, filename);
            copyfile(primaryPath, presetPath);
            fprintf('Added to presets: %s\n', presetPath);
        end
        
        result = struct(...
            'success', true, ...
            'filepath', primaryPath, ...
            'seed', seed ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'filepath', '', ...
            'seed', 0, ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  EXPORT - Export reservoir to MATLAB workspace
%  =========================================================================
function handleExport(payload, fig)
    try
        reservoir = fig.UserData.reservoir;
        
        if isempty(reservoir)
            % Need to compile first - do it with the payload
            result = handleCompile(payload, fig);
            if ~result.success
                warning('Could not compile before export: %s', result.error_message);
                return;
            end
            reservoir = fig.UserData.reservoir;
        end
        
        % Export to base workspace
        varName = matlab.lang.makeValidName(payload.name);
        if isempty(varName)
            varName = 'reservoir';
        end
        
        assignin('base', varName, reservoir);
        fprintf('Reservoir exported to workspace as ''%s''\n', varName);
        
    catch ME
        warning('Export failed: %s', ME.message);
    end
end

%% =========================================================================
%  LIST PRESETS - Scan presets directory for saved configurations
%  =========================================================================
function result = handleListPresets(fig)
    try
        presetsDir = fig.UserData.presetsDir;
        
        % Build nested tree structure
        presetTree = scanPresetsDir(presetsDir, presetsDir);
        
        % Also return flat list for backwards compatibility
        userPresets = flattenPresets(presetTree);
        
        result = struct(...
            'success', true, ...
            'user_presets', {userPresets}, ...
            'preset_tree', {presetTree} ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'user_presets', {{}}, ...
            'preset_tree', {{}}, ...
            'error_message', ME.message ...
        );
    end
end

function nodes = scanPresetsDir(dirPath, rootDir)
% SCANPRESETSDIR Recursively scan directory for presets
%   Returns cell array of nodes (folders and files)

    nodes = {};
    
    if ~exist(dirPath, 'dir')
        return;
    end
    
    % Get all items in directory
    items = dir(dirPath);
    
    % First, add subdirectories (folders)
    for i = 1:length(items)
        item = items(i);
        if item.isdir && ~startsWith(item.name, '.')
            folderPath = fullfile(dirPath, item.name);
            children = scanPresetsDir(folderPath, rootDir);
            
            % Only add folder if it has children
            if ~isempty(children)
                folder = struct(...
                    'type', 'folder', ...
                    'name', item.name, ...
                    'path', folderPath, ...
                    'children', {children} ...
                );
                nodes{end+1} = folder; %#ok<AGROW>
            end
        end
    end
    
    % Then, add JSON files
    jsonFiles = dir(fullfile(dirPath, '*.json'));
    for i = 1:length(jsonFiles)
        try
            filepath = fullfile(jsonFiles(i).folder, jsonFiles(i).name);
            jsonStr = fileread(filepath);
            data = jsondecode(jsonStr);
            
            % Add metadata
            data.filepath = filepath;
            data.isBuiltIn = false;
            
            fileNode = struct(...
                'type', 'file', ...
                'preset', data ...
            );
            nodes{end+1} = fileNode; %#ok<AGROW>
        catch
            % Skip invalid files
            continue;
        end
    end
end

function presets = flattenPresets(tree)
% FLATTENPRESETS Extract flat list of all presets from tree

    presets = {};
    
    for i = 1:length(tree)
        node = tree{i};
        if strcmp(node.type, 'file')
            presets{end+1} = node.preset; %#ok<AGROW>
        elseif strcmp(node.type, 'folder')
            % Recursively flatten children
            childPresets = flattenPresets(node.children);
            presets = [presets, childPresets]; %#ok<AGROW>
        end
    end
end

%% =========================================================================
%  REMOVE PRESET - Remove a network from presets/ (not from saved-networks/)
%  =========================================================================
function result = handleRemovePreset(payload, fig)
    try
        presetsDir = fig.UserData.presetsDir;
        
        % Get filepath from payload
        if isfield(payload, 'filepath')
            filepath = payload.filepath;
        elseif isfield(payload, 'name')
            filename = sanitizeFilename(payload.name) + ".json";
            filepath = fullfile(presetsDir, filename);
        else
            error('No filepath or name provided');
        end
        
        % Verify the file is in presets directory (safety check)
        [folder, ~, ~] = fileparts(filepath);
        if ~strcmp(folder, presetsDir)
            error('Can only remove files from presets directory');
        end
        
        % Delete the file from presets/
        if exist(filepath, 'file')
            delete(filepath);
            fprintf('Removed from presets: %s\n', filepath);
            
            result = struct(...
                'success', true, ...
                'filepath', filepath ...
            );
        else
            error('File not found: %s', filepath);
        end
        
    catch ME
        result = struct(...
            'success', false, ...
            'filepath', '', ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  BROWSE SAVED NETWORKS - List all networks in saved-networks/ (not presets)
%  =========================================================================
function result = handleBrowseSavedNetworks(fig)
    try
        savedNetworksDir = fig.UserData.savedNetworksDir;
        networks = {};
        
        if exist(savedNetworksDir, 'dir')
            files = dir(fullfile(savedNetworksDir, '*.json'));
            
            for i = 1:length(files)
                try
                    filepath = fullfile(files(i).folder, files(i).name);
                    jsonStr = fileread(filepath);
                    data = jsondecode(jsonStr);
                    
                    % Include basic info for display
                    network = struct(...
                        'name', data.name, ...
                        'description', data.description, ...
                        'filepath', filepath, ...
                        'filename', files(i).name, ...
                        'modified', files(i).datenum ...
                    );
                    networks{end+1} = network; %#ok<AGROW>
                catch
                    % Skip invalid files
                    continue;
                end
            end
        end
        
        result = struct(...
            'success', true, ...
            'networks', {networks} ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'networks', {{}}, ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  ADD TO PRESETS - Copy a network from saved-networks/ to presets/
%  =========================================================================
function result = handleAddToPresets(payload, fig)
    try
        savedNetworksDir = fig.UserData.savedNetworksDir;
        presetsDir = fig.UserData.presetsDir;
        
        % Get source filepath
        if isfield(payload, 'filepath')
            sourcePath = payload.filepath;
        elseif isfield(payload, 'filename')
            sourcePath = fullfile(savedNetworksDir, payload.filename);
        else
            error('No filepath or filename provided');
        end
        
        % Verify source exists
        if ~exist(sourcePath, 'file')
            error('Source file not found: %s', sourcePath);
        end
        
        % Get filename for destination
        [~, name, ext] = fileparts(sourcePath);
        destPath = fullfile(presetsDir, [name ext]);
        
        % Copy to presets/
        copyfile(sourcePath, destPath);
        fprintf('Added to presets: %s\n', destPath);
        
        result = struct(...
            'success', true, ...
            'filepath', destPath ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'filepath', '', ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  LOAD NETWORK - Load a network from saved-networks/ into the GUI
%  =========================================================================
function result = handleLoadNetwork(payload, fig)
    try
        % Get filepath - either from payload or open file dialog
        if isfield(payload, 'filepath') && ~isempty(payload.filepath)
            filepath = payload.filepath;
        else
            % Open file dialog starting in saved-networks/
            savedNetworksDir = fig.UserData.savedNetworksDir;
            [filename, pathname] = uigetfile(...
                {'*.json', 'Network Files (*.json)'}, ...
                'Load Network', ...
                savedNetworksDir);
            
            if filename == 0
                % User cancelled
                result = struct(...
                    'success', false, ...
                    'cancelled', true ...
                );
                return;
            end
            
            filepath = fullfile(pathname, filename);
        end
        
        % Read and parse the JSON file
        jsonStr = fileread(filepath);
        data = jsondecode(jsonStr);
        
        % Add filepath to data
        data.filepath = filepath;
        
        fprintf('Loaded network: %s\n', filepath);
        
        result = struct(...
            'success', true, ...
            'data', data ...
        );
        
    catch ME
        result = struct(...
            'success', false, ...
            'data', [], ...
            'error_message', ME.message ...
        );
    end
end

%% =========================================================================
%  HELPER FUNCTIONS
%  =========================================================================

function [jetOrder, decompOrder] = inferOrders(equations)
% INFERORDERS  Infer jet_order and decompilation_order from equations
%
% jet_order: highest time derivative (ẋ→1, ẍ→2, etc.)
% decompOrder: highest polynomial degree in combined variables

    jetOrder = 1;    % Default: first derivatives
    decompOrder = 1; % Default: linear
    
    for i = 1:length(equations)
        eq = equations(i);
        latex = eq.latex;
        
        % Check for higher derivatives in tau coefficient
        if isfield(eq, 'tau')
            tau = eq.tau;
            % Check for ddot (second derivative)
            if contains(tau, 'ddot') || contains(tau, '\ddot')
                jetOrder = max(jetOrder, 2);
            end
        end
        
        % Analyze polynomial degree in the equation
        % This is a simplified heuristic - looks for common patterns
        degree = analyzePolynomialDegree(latex);
        decompOrder = max(decompOrder, degree);
    end
    
    % Ensure minimum reasonable values
    jetOrder = max(1, jetOrder);
    decompOrder = max(2, decompOrder);  % At least quadratic for most dynamics
end

function degree = analyzePolynomialDegree(latex)
% ANALYZEPOLYNOMIALDEGREE  Estimate polynomial degree from LaTeX string
%
% This is a heuristic analysis - looks for:
%   - Explicit exponents: x^2, x^3, etc.
%   - Products of variables: x_1 x_2, y_1 y_2, etc.
%   - Cubic terms in common patterns

    degree = 1;
    
    % Check for explicit exponents
    expMatch = regexp(latex, '\^(\d+)', 'tokens');
    for j = 1:length(expMatch)
        exp = str2double(expMatch{j}{1});
        degree = max(degree, exp);
    end
    
    % Check for products of variables (e.g., x_1 x_2, y_1 y_2)
    % Count variable occurrences
    varPattern = '[xy]_?\{?\d+\}?';
    vars = regexp(latex, varPattern, 'match');
    
    % Simple heuristic: if multiple variables appear, assume degree 2
    % If same variable appears with exponent AND other variables, degree 3
    if length(vars) >= 2
        degree = max(degree, 2);
    end
    
    % Check for cubic patterns (x^3, x_1^3, etc.)
    if contains(latex, '^3') || contains(latex, '^{3}')
        degree = max(degree, 3);
    end
    
    % Common patterns in dynamical systems
    if contains(latex, 'x_1 x_2') || contains(latex, 'y_1 y_2') || ...
       contains(latex, 'x_1x_2') || contains(latex, 'y_1y_2')
        degree = max(degree, 2);
    end
end

function expPoint = buildExpansionPoint(expPointStruct, topology, jetOrder)
% BUILDEXPANSIONPOINT  Convert expansion point struct to vector
%
% The expansion point vector has structure:
%   [x_rec; x_ext; ẋ_rec; ẋ_ext; ...] for jet_order derivatives

    nRec = topology.n_recurrent_inputs;
    nExt = topology.n_external_inputs;
    nTotal = nRec + nExt;
    
    % Initialize with zeros
    expPoint = zeros(nTotal * jetOrder, 1);
    
    % Fill in recurrent (y) values
    if isfield(expPointStruct, 'y') && ~isempty(expPointStruct.y)
        yStruct = expPointStruct.y;
        if isstruct(yStruct)
            fields = fieldnames(yStruct);
            for i = 1:length(fields)
                idx = str2double(fields{i});
                if ~isnan(idx) && idx >= 1 && idx <= nRec
                    expPoint(idx) = yStruct.(fields{i});
                end
            end
        end
    end
    
    % Fill in external (x) values
    if isfield(expPointStruct, 'x') && ~isempty(expPointStruct.x)
        xStruct = expPointStruct.x;
        if isstruct(xStruct)
            fields = fieldnames(xStruct);
            for i = 1:length(fields)
                idx = str2double(fields{i});
                if ~isnan(idx) && idx >= 1 && idx <= nExt
                    expPoint(nRec + idx) = xStruct.(fields{i});
                end
            end
        end
    end
    
    % Higher jet orders default to zero (no expansion in derivatives)
end

function safe = sanitizeFilename(name)
% SANITIZEFILENAME  Convert name to safe filename
%
% Removes/replaces characters that aren't safe for filenames

    % Replace spaces with underscores
    safe = strrep(name, ' ', '_');
    
    % Remove unsafe characters
    safe = regexprep(safe, '[<>:"/\\|?*]', '');
    
    % Limit length
    if length(safe) > 100
        safe = safe(1:100);
    end
    
    % Ensure not empty
    if isempty(safe)
        safe = 'untitled';
    end
    
    safe = string(safe);
end
