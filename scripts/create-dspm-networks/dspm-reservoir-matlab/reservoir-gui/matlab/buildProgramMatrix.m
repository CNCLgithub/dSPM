function P = buildProgramMatrix(equations, constants, reservoir)
% BUILDPROGRAMMATRIX  Convert symbolic equations to program matrix P
%
% The approach:
%   1. Parse LaTeX string → clean MATLAB string
%   2. Substitute constant values
%   3. Use str2sym to get symbolic expression
%   4. Use coeffs() to extract polynomial coefficients
%   5. Use reservoir.getColumnIndex() to map monomials to columns
%
% Programming matrix format: P where row i gives coefficients for
%   y_i + (1/γ) ẏ_i = Σ_j P(i,j) * monomial_j

    n_outputs = numel(equations);
    n_monomials = reservoir.n_monomials;
    n_rec = reservoir.n_recurrent_inputs;
    n_ext = reservoir.n_external_inputs;
    n_total = n_rec + n_ext;
    gamma = reservoir.gamma;
    
    P = zeros(n_outputs, n_monomials);
    
    %% Step 1: Build constants map from JSON
    constMap = containers.Map();
    if ~isempty(constants)
        for i = 1:numel(constants)
            c = getElement(constants, i);
            name = cleanConstantName(getField(c, 'name', ''));
            val = getField(c, 'value', []);
            if ~isempty(name) && ~isempty(val)
                constMap(name) = val;
            end
        end
    end
    
    %% Step 2: Create symbolic variables x1, x2, x3, ...
    % These match the reservoir's internal naming convention
    xvars = sym('x', [n_total, 1], 'real');
    
    %% Step 3: Process each equation
    for eqIdx = 1:n_outputs
        eq = getElement(equations, eqIdx);
        
        % Get the LaTeX string and tau
        latexStr = char(string(getField(eq, 'latex', '')));
        tauStr = char(string(getField(eq, 'tau', '1')));
        
        if isempty(strtrim(latexStr))
            continue;
        end
        
        try
            % Parse tau (may reference constants)
            tau = evalWithConstants(tauStr, constMap);
            
            % Convert LaTeX to clean MATLAB expression string
            matlabStr = latex2matlab(latexStr, n_rec, constMap);
            
            fprintf('Eq %d: "%s" -> "%s" (tau=%g)\n', eqIdx, latexStr, matlabStr, tau);
            
            % Parse to symbolic
            symExpr = str2sym(matlabStr);
            
            % Get polynomial coefficients
            % coeffs returns: [coeff_vector, monomial_vector]
            [coeffVec, monomials] = coeffs(expand(symExpr), xvars);
            
            % Map each monomial to the correct column in P
            for j = 1:length(monomials)
                mono = monomials(j);
                coeff = double(coeffVec(j));
                
                % Convert monomial to column index string
                colStr = sym2colstr(mono, n_total);
                colIdx = reservoir.getColumnIndex(colStr);
                
                if colIdx > 0
                    % Scale by 1/(gamma*tau) and add to P
                    P(eqIdx, colIdx) = P(eqIdx, colIdx) + coeff / (gamma * tau);
                else
                    warning('Could not find column for monomial: %s (from %s)', ...
                        char(mono), colStr);
                end
            end
            
            % % Add constant term (coeffs doesn't include it if there's no constant)
            % constTerm = double(subs(symExpr, xvars, zeros(n_total, 1)));
            % if constTerm ~= 0
            %     constColIdx = reservoir.getColumnIndex('1');
            %     if constColIdx > 0
            %         P(eqIdx, constColIdx) = P(eqIdx, constColIdx) + constTerm / (gamma * tau);
            %     end
            % end
            
            % Add identity term: P(i, col_xi) += 1 for recurrent outputs
            outputType = char(string(getField(eq, 'outputType', 'recurrent')));
            varIdx = getField(eq, 'index', eqIdx);
            
            if strcmpi(outputType, 'recurrent') && varIdx <= n_rec
                identityColIdx = reservoir.getColumnIndex(sprintf('x%d', varIdx));
                if identityColIdx > 0
                    P(eqIdx, identityColIdx) = P(eqIdx, identityColIdx) + 1;
                end
            end
            
        catch ME
            warning('Failed to parse equation %d: %s\nError: %s', ...
                eqIdx, latexStr, ME.message);
        end
    end
    
    fprintf('\nProgram matrix constructed: %d x %d\n', size(P,1), size(P,2));
end

%% ========== HELPER FUNCTIONS ==========

function elem = getElement(arr, idx)
    % Get element from struct array or cell array
    if iscell(arr)
        elem = arr{idx};
    else
        elem = arr(idx);
    end
end

function val = getField(s, fieldName, default)
    % Get struct field with default
    if isstruct(s) && isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end

function name = cleanConstantName(rawName)
    % Clean LaTeX constant name: \sigma -> sigma, \text{scv} -> scv
    name = char(string(rawName));
    name = regexprep(name, '\\text\{([^}]+)\}', '$1');  % \text{foo} -> foo
    name = strrep(name, '\', '');      % remove backslashes
    name = strrep(name, '{', '');
    name = strrep(name, '}', '');
    name = strtrim(name);
end

function val = evalWithConstants(str, constMap)
    % Evaluate a string expression, substituting constants
    s = str;
    s = strrep(s, '\', '');
    s = strrep(s, '{', '');
    s = strrep(s, '}', '');
    
    % Substitute constants
    names = keys(constMap);
    for i = 1:length(names)
        s = regexprep(s, ['(?<![a-zA-Z_])' names{i} '(?![a-zA-Z_0-9])'], ...
            sprintf('(%g)', constMap(names{i})));
    end
    
    val = eval(s);
end

function matlabStr = latex2matlab(latexStr, n_rec, constMap)
    % Convert LaTeX equation to MATLAB symbolic expression string
    %
    % GUI convention: y_k = recurrent (becomes x_k), x_n = external (becomes x_{n_rec+n})
    % Reservoir convention: x1, x2, ... for all inputs
    
    s = latexStr;
    
    % Step 1: Handle LaTeX constructs
    % \frac{a}{b} -> ((a)/(b))
    s = regexprep(s, '\\frac\{([^}]+)\}\{([^}]+)\}', '(($1)/($2))');
    
    % \cdot, \times -> *
    s = regexprep(s, '\\cdot', '*');
    s = regexprep(s, '\\times', '*');
    
    % \text{foo} -> foo
    s = regexprep(s, '\\text\{([^}]+)\}', '$1');
    
    % Remove formatting: \left, \right, \, \ 
    s = regexprep(s, '\\left|\\right', '');
    s = strrep(s, '\,', '');
    s = strrep(s, '\ ', '');
    
    % Step 2: Convert variables
    % y_k or y_{k} -> x_k (recurrent inputs are first n_rec)
    s = regexprep(s, 'y_\{(\d+)\}', 'x$1');
    s = regexprep(s, 'y_(\d)', 'x$1');
    
    % x_n or x_{n} from GUI -> x_{n_rec+n} (external inputs come after)
    % Mark them first to avoid double-processing
    s = regexprep(s, 'x_\{(\d+)\}', 'EXTVAR$1');
    s = regexprep(s, 'x_(\d)(?!\d)', 'EXTVAR$1');
    
    % Now convert EXTVAR to proper index
    tokens = regexp(s, 'EXTVAR(\d+)', 'tokens');
    for i = 1:length(tokens)
        oldIdx = str2double(tokens{i}{1});
        newIdx = n_rec + oldIdx;
        s = regexprep(s, sprintf('EXTVAR%d', oldIdx), sprintf('x%d', newIdx), 'once');
    end
    
    % Step 3: Convert Greek letters (remove backslash)
    % \sigma -> sigma, \rho -> rho, etc.
    s = regexprep(s, '\\([a-zA-Z]+)', '$1');
    
    % Step 4: Substitute constant values
    names = keys(constMap);
    for i = 1:length(names)
        name = names{i};
        val = constMap(name);
        % Use word boundaries
        s = regexprep(s, ['(?<![a-zA-Z_])' name '(?![a-zA-Z_0-9])'], ...
            sprintf('(%g)', val));
    end
    
    % Step 5: Handle implicit multiplication
    % Cases: 2x, x y, )(, x1x2, )x, x(
    s = regexprep(s, '(\d)([a-zA-Z])', '$1*$2');           % 2x -> 2*x
    s = regexprep(s, '([a-zA-Z0-9])\s+([a-zA-Z])', '$1*$2'); % x y -> x*y
    s = regexprep(s, '\)\s*\(', ')*(');                     % )( -> )*(
    s = regexprep(s, '(\))\s*([a-zA-Z])', '$1*$2');         % )x -> )*x
    s = regexprep(s, '([a-zA-Z0-9])\s*(\()', '$1*$2');      % x( -> x*(
    s = regexprep(s, '(x\d+)\s*(x\d+)', '$1*$2');           % x1x2 -> x1*x2
    
    % Step 6: Clean up any remaining issues
    s = strrep(s, '**', '*');  % Fix double multiplication
    s = strtrim(s);
    
    matlabStr = s;
end

function colStr = sym2colstr(mono, n_total)
    % Convert symbolic monomial to column index string for getColumnIndex
    %
    % Examples:
    %   sym(1) -> '1'
    %   x1 -> 'x1'
    %   x1*x2 -> 'x1*x2'
    %   x1^2 -> 'x1*x1'
    %   x1^2*x3 -> 'x1*x1*x3'
    
    if mono == 1
        colStr = '1';
        return;
    end
    
    % Convert to string and parse
    monoStr = char(mono);
    
    % Handle powers: x1^2 -> x1*x1
    % Find patterns like x1^n
    while true
        match = regexp(monoStr, 'x(\d+)\^(\d+)', 'tokens', 'once');
        if isempty(match)
            break;
        end
        varNum = match{1};
        power = str2double(match{2});
        expanded = strjoin(repmat({sprintf('x%s', varNum)}, 1, power), '*');
        monoStr = regexprep(monoStr, sprintf('x%s\\^%d', varNum, power), expanded, 'once');
    end
    
    colStr = monoStr;
end
