function save(obj, filepath, varargin)
    % SAVE  Save the reservoir configuration to a JSON file
    %
    % Usage:
    %   res.save('output.json')
    %   res.save('output.json', 'Name', 'value', ...)
    %
    % Options:
    %   'name'        - Network name (default: obj.network_name)
    %   'description' - Description (default: obj.network_description)
    %   'is_preset'   - Mark as preset (default: false)
    %
    % Note: This saves the configuration, not the compiled weights.
    % To reload, you need to recompile with the equations.
    %
    % See also: toStruct, loadFromFile
    
    p = inputParser;
    addParameter(p, 'name', obj.network_name, @ischar);
    addParameter(p, 'description', obj.network_description, @ischar);
    addParameter(p, 'is_preset', false, @islogical);
    parse(p, varargin{:});
    opts = p.Results;
    
    % Build struct
    s = obj.toStruct();
    s.name = opts.name;
    s.description = opts.description;
    s.is_preset = opts.is_preset;
    
    % Write JSON
    jsonText = jsonencode(s, 'PrettyPrint', true);
    fid = fopen(filepath, 'w');
    if fid == -1
        error('dspm_reservoir:saveError', 'Could not open file for writing: %s', filepath);
    end
    fprintf(fid, '%s', jsonText);
    fclose(fid);
    
    if obj.verbose
        fprintf('Saved to: %s\n', filepath);
    end
end
