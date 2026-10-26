function obj = fromStruct(config, options)
    % FROMSTRUCT  Create a dspm_reservoir from a config struct
    %
    % USAGE:
    %   res = dspm_reservoir.fromStruct(config)
    %   res = dspm_reservoir.fromStruct(config, n_neurons=200)  % override
    %
    % The config struct follows the JSON schema used by the GUI.
    %
    % See also: dspm_reservoir.load, toStruct
    
    arguments
        config (1,1) struct
        
        % Override options
        options.n_neurons (1,1) double = NaN
        options.n_recurrent_inputs (1,1) double = NaN
        options.n_external_inputs (1,1) double = NaN
        options.n_recurrent_outputs (1,1) double = NaN
        options.n_external_outputs (1,1) double = NaN
        options.gamma (1,1) double = NaN
        options.dt (1,1) double = NaN
        options.B_scale (1,1) double = NaN
        options.B_sparsity (1,1) double = NaN
        options.jet_order (1,1) double = NaN
        options.decompilation_order (1,1) double = NaN
        options.random_seed (1,1) double = NaN
        options.verbose (1,1) logical = false
    end
    
    % Extract parameters from JSON struct
    p = dspm_reservoir.parseJSONConfig(config);
    
    % Apply overrides from options
    optFields = fieldnames(options);
    for i = 1:numel(optFields)
        fn  = optFields{i};
        val = options.(fn);

        % Skip unset
        if isnumeric(val) && isnan(val),continue;end

        p.(fn) = val;
    end
    
    % Create empty object
    % pcell = [fieldnames(p) struct2cell(p)]';
    % obj   = dspm_reservoir(pcell{:});
    obj = dspm_reservoir();

    % Set random seed for reproducibility
    if p.random_seed > 0
        rng(p.random_seed);
    end
    
    % Build options struct for initializeFromOptions
    initOpts.n_neurons           = p.n_neurons;
    if isfield(p, 'ports'),      initOpts.ports      = p.ports;      end
    if isfield(p, 'port_names'), initOpts.port_names = p.port_names; end
    initOpts.n_recurrent_inputs  = p.n_recurrent_inputs;
    initOpts.n_external_inputs   = p.n_external_inputs;
    initOpts.n_recurrent_outputs = p.n_recurrent_outputs;
    initOpts.n_external_outputs  = p.n_external_outputs;
    initOpts.gamma               = p.gamma;
    initOpts.dt                  = p.dt;
    initOpts.integrator          = "euler";
    initOpts.B_scale             = p.B_scale;
    initOpts.B_sparsity          = p.B_sparsity;
    initOpts.r_star              = [];
    initOpts.x_star              = [];
    initOpts.random_seed         = p.random_seed;
    initOpts.jet_order           = p.jet_order;
    initOpts.decompilation_order = p.decompilation_order;
    initOpts.read_in_matrix      = [];
    initOpts.read_out_matrix     = [];
    initOpts.initialize          = true;
    initOpts.verbose             = options.verbose;
    
    % Initialize
    obj.initializeFromOptions(initOpts);
    
    % Store metadata
    if isfield(config, 'name')
        obj.network_name = config.name;
    end
    if isfield(config, 'description')
        obj.network_description = config.description;
    end
    
    % Build and compile program if equations present
    if isfield(config, 'equations') && ~isempty(config.equations)
        constants = [];
        if isfield(config, 'constants')
            constants = config.constants;
        end
        obj.loadProgram(config.equations, constants);
    end
end
