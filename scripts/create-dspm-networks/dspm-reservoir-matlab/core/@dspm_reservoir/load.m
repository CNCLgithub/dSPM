function obj = load(filepath, options)
    % LOAD  Load a dspm_reservoir from a JSON file
    %
    % USAGE:
    %   res = dspm_reservoir.load('network.json')
    %   res = dspm_reservoir.load('presets/lorenz.json')
    %   res = dspm_reservoir.load('network.json', n_neurons=200)  % override
    %
    % See also: dspm_reservoir, dspm_reservoir.fromStruct, save
    
    arguments
        filepath (1,1) string
        
        % Override options
        options.n_neurons (1,1) double = NaN
        options.n_recurrent_inputs (1,1) double = NaN
        options.n_external_inputs (1,1) double = NaN
        options.gamma (1,1) double = NaN
        options.dt (1,1) double = NaN
        options.B_scale (1,1) double = NaN
        options.B_sparsity (1,1) double = NaN
        options.jet_order (1,1) double = NaN
        options.decompilation_order (1,1) double = NaN
        options.random_seed (1,1) double = NaN
        options.verbose (1,1) logical = false
    end
    
    if ~isfile(filepath)
        error('dspm_reservoir:fileNotFound', 'File not found: %s', filepath);
    end
    
    % Read JSON
    jsonText = fileread(filepath);
    config   = jsondecode(jsonText);
    
    % Build overrides cell array from non-NaN options
    overrides = {};
    optFields = fieldnames(options);
    for i = 1:numel(optFields)
        fn = optFields{i};
        val = options.(fn);
        if isnumeric(val) && isnan(val)
            continue;  % Skip unset options
        end
        overrides{end+1} = fn; %#ok<AGROW>
        overrides{end+1} = val; %#ok<AGROW>
    end
    
    % Construct from struct with overrides
    obj = dspm_reservoir.fromStruct(config, overrides{:});
    
    % Store source path
    obj.source_filepath = filepath;

end
