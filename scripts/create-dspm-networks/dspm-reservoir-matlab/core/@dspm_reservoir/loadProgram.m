function loadProgram(obj, equations, constants)
    % LOADPROGRAM  Build P matrix from equations/constants and compile
    %
    % Usage:
    %   res.loadProgram(equations, constants)
    %
    % Inputs:
    %   equations - Struct array with fields:
    %               .index, .outputType, .tau, .latex
    %   constants - Struct array with fields:
    %               .name, .value, .description (optional)
    %
    % This method:
    %   1. Ensures the reservoir is decompiled
    %   2. Builds the P matrix from the equations
    %   3. Compiles the network
    %
    % See also: buildProgramMatrix, compile
    
    % Ensure decompiled
    if ~obj.is_decompiled
        obj.decompile();
    end
    
    % Handle empty constants
    if isempty(constants)
        constants = struct( ...
            'name', {}, 'value', {}, ...
            'display_value',{},'description',{});
    end
    
    % Store source equations and constants for later export
    obj.source_equations = equations;
    obj.source_constants = constants;
    
    % Build program matrix using the GUI helper
    P = buildProgramMatrix(equations, constants, obj);
    
    % Compile
    obj.compile(P);
    
    if obj.verbose
        fprintf('Program loaded: %d equations compiled\n', numel(equations));
    end
end
