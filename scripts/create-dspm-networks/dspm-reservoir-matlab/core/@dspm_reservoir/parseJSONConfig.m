function p = parseJSONConfig(config)
    % PARSEJSONCONFIG  Extract parameters from JSON config struct
    %
    % Maps JSON schema fields to dspm_reservoir_v2 constructor params
    
    p = struct();
    
    % Config section
    if isfield(config, 'config')
        c = config.config;
        p.n_neurons   = getFieldOr(c, 'n_neurons', 100);
        p.gamma       = getFieldOr(c, 'gamma', 100);
        p.dt          = getFieldOr(c, 'dt', 0.01);
        p.B_scale     = getFieldOr(c, 'B_scale', 0.4);
        p.B_sparsity  = getFieldOr(c, 'B_sparsity', 1.0);
        p.random_seed = getFieldOr(c, 'random_seed', 0);
    else
        % Direct fields (legacy support)
        p.n_neurons   = getFieldOr(config, 'n_neurons', 100);
        p.gamma       = getFieldOr(config, 'gamma', 100);
        p.dt          = getFieldOr(config, 'dt', 0.01);
        p.B_scale     = getFieldOr(config, 'B_scale', 0.4);
        p.B_sparsity  = getFieldOr(config, 'B_sparsity', 1.0);
        p.random_seed = getFieldOr(config, 'random_seed', 0);
    end
    
    % Topology section
    if isfield(config, 'topology')
        t = config.topology;
        p.n_recurrent_inputs  = getFieldOr(t, 'n_recurrent_inputs', 1);
        p.n_external_inputs   = getFieldOr(t, 'n_external_inputs', 0);
        p.n_recurrent_outputs = getFieldOr(t, 'n_recurrent_outputs', p.n_recurrent_inputs);
        p.n_external_outputs  = getFieldOr(t, 'n_external_outputs', 0);
    else
        p.n_recurrent_inputs  = getFieldOr(config, 'n_recurrent_inputs', 1);
        p.n_external_inputs   = getFieldOr(config, 'n_external_inputs', 0);
        p.n_recurrent_outputs = getFieldOr(config, 'n_recurrent_outputs', p.n_recurrent_inputs);
        p.n_external_outputs  = getFieldOr(config, 'n_external_outputs', 0);
    end
    
    % Ports section (schema v2) — optional; overrides topology counts
    p.ports      = string.empty;
    p.port_names = string.empty;
    if isfield(config, 'ports') && ~isempty(config.ports)
        pp = config.ports;
        if iscell(pp)   % jsondecode yields cell array when fields differ
            roles = cellfun(@(q) string(q.role), pp);
        else
            roles = string({pp.role});
        end
        p.ports = roles(:)';
        p.n_recurrent_inputs = nnz(p.ports == "recurrent");
        p.n_external_inputs  = numel(p.ports) - p.n_recurrent_inputs;
    end

    % Inferred section
    if isfield(config, 'inferred')
        inf = config.inferred;
        p.jet_order = getFieldOr(inf, 'jet_order', 1);
        p.decompilation_order = getFieldOr(inf, 'decompilation_order', 3);
    else
        p.jet_order = getFieldOr(config, 'jet_order', 1);
        p.decompilation_order = getFieldOr(config, 'decompilation_order', 3);
    end
    
    function val = getFieldOr(s, field, default)
        if isfield(s, field) && ~isempty(s.(field))
            val = s.(field);
        else
            val = default;
        end
    end
end
