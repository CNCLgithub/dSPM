function s = toStruct(obj)
    % TOSTRUCT  Export reservoir configuration to struct
    %
    % Returns a struct compatible with the JSON schema used by the GUI.
    %
    % See also: save, fromStruct
    
    s = struct();
    
    s.version = '1.0';
    s.schema_version = 2;
    s.name = obj.network_name;
    s.description = obj.network_description;
    s.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    s.modified = s.created;
    s.is_preset = false;
    
    % Config section
    s.config.n_neurons = obj.n_neurons;
    s.config.gamma = obj.gamma;
    s.config.dt = obj.dt;
    s.config.B_scale = obj.B_scale;
    s.config.B_sparsity = obj.B_sparsity;
    s.config.random_seed = obj.random_seed;
    
    % Expansion point
    s.config.expansion_point.x = struct();
    s.config.expansion_point.y = struct();
    for i = 1:obj.n_recurrent_inputs
        s.config.expansion_point.y.(sprintf('x%d', i)) = obj.x_recurrent_star(i);
    end
    for i = 1:obj.n_external_inputs
        s.config.expansion_point.x.(sprintf('x%d', i)) = obj.x_external_star(i);
    end
    
    % Topology section
    s.topology.n_external_inputs = obj.n_external_inputs;
    s.topology.n_external_outputs = obj.n_external_outputs;
    s.topology.n_recurrent_inputs = obj.n_recurrent_inputs;
    s.topology.n_recurrent_outputs = obj.n_recurrent_outputs;
    
    % Ports section (schema v2): roles/ids/labels/x0 for every input channel
    s.ports = struct('id',{},'label',{},'role',{},'x0',{},'aliases',{});
    for i = 1:numel(obj.ports)
        s.ports(i).id      = char(obj.ports(i).id);
        s.ports(i).label   = char(obj.ports(i).label);
        s.ports(i).role    = char(obj.ports(i).role);
        s.ports(i).x0      = obj.ports(i).x0;
        s.ports(i).aliases = cellstr(obj.ports(i).aliases);
    end

    % Provenance section (schema v2)
    s.provenance.tier              = char(obj.provenance.tier);
    s.provenance.generator_version = char(obj.provenance.generator_version);
    s.provenance.seed              = obj.provenance.seed;

    % Inferred section
    s.inferred.jet_order = obj.jet_order;
    s.inferred.decompilation_order = obj.decompilation_order;
    
    % Include stored equations and constants if available
    if ~isempty(obj.source_equations)
        s.equations = obj.source_equations;
    else
        s.equations = [];
    end
    if ~isempty(obj.source_constants)
        s.constants = obj.source_constants;
    else
        s.constants = [];
    end
end
