function P = buildProgramMatrix(equations, constants, reservoir)
% BUILDPROGRAMMATRIX  Convert symbolic equations to program matrix P
%
% Usage:
%   P = buildProgramMatrix(equations, constants, reservoir)
%
% Inputs:
%   equations  - Struct array with fields (SavedEquation format):
%                  .index      - Equation index (1-based)
%                  .outputType - 'external' or 'recurrent'
%                  .tau        - Time scale coefficient (string)
%                  .latex      - LaTeX string for RHS
%   constants  - Struct array with fields (SavedConstant format):
%                  .name        - Parameter name (LaTeX, e.g., '\sigma')
%                  .value       - Numeric value
%                  .description - Optional description
%   reservoir  - Reservoir object (for basis information)
%
% Outputs:
%   P - (n_outputs × n_monomials) program matrix
%
% Description:
%   Parses LaTeX equations and extracts polynomial coefficients that
%   correspond to the reservoir's decompiled basis monomials.
%
%   Variable naming convention in GUI:
%     x_n = external inputs (exogenous)
%     y_k = recurrent inputs (feedback after compilation)
%
%   Internally maps to reservoir convention:
%     x(1:k_rec) = recurrent inputs
%     x(k_rec+1:k) = external inputs
%
% See also: programming_gui, compile

    n_outputs = numel(equations);
    n_monomials = reservoir.n_monomials;
    n_rec = reservoir.n_recurrent_inputs;
    n_ext = reservoir.n_external_inputs;
    
    P = zeros(n_outputs, n_monomials);
    
    % Create parameter substitution map from constants
    paramMap = containers.Map();
    for i = 1:numel(constants)
        c = constants(i);
        % Handle LaTeX-style names (e.g., '\sigma' -> 'sigma')
        name = strrep(c.name, '\', '');
        name = regexprep(name, '[\{\}]', '');  % Remove braces
        paramMap(name) = c.value;
    end
    
    % Process each equation
    for eqIdx = 1:n_outputs
        eq = equations(eqIdx);
        latexStr = eq.latex;
        
        % Get tau coefficient (may be symbolic or numeric string)
        if isfield(eq, 'tau') && ~isempty(eq.tau)
            tauStr = eq.tau;
            % Try to evaluate tau
            try
                tau = evalTauString(tauStr, paramMap);
            catch
                tau = 1;
                warning('Could not parse tau "%s", using 1', tauStr);
            end
        else
            tau = 1;
        end
        
        if isempty(strtrim(latexStr))
            continue;
        end
        
        try
            % Parse LaTeX to symbolic expression
            % Note: In GUI, y_k are recurrent, x_n are external
            % In reservoir, x(1:k_rec) are recurrent, x(k_rec+1:k) are external
            symExpr = parseLatexToSymbolic(latexStr, n_rec, n_ext, paramMap);
            
            % Scale by time constant
            symExpr = symExpr * tau;
            
            % Get the basis mapping from reservoir
            basis = reservoir.symbolic_basis_mapping;
            
            % Extract coefficients for each monomial
            for monoIdx = 1:n_monomials
                basisEntry = basis(monoIdx, :);
                coeff = extractCoefficientForBasisEntry(symExpr, basisEntry, n_rec, n_ext);
                P(eqIdx, monoIdx) = double(coeff);
            end
            
        catch ME
            warning('Failed to parse equation %d: %s\nError: %s', ...
                eqIdx, latexStr, ME.message);
        end
    end
end

function tau = evalTauString(tauStr, paramMap)
% EVALTAUSTRING  Evaluate tau coefficient string
    
    str = tauStr;
    
    % Substitute known parameters
    paramNames = keys(paramMap);
    for i = 1:length(paramNames)
        name = paramNames{i};
        value = paramMap(name);
        str = regexprep(str, ['(?<![a-zA-Z])' name '(?![a-zA-Z])'], ...
            sprintf('(%g)', value));
    end
    
    % Remove LaTeX formatting
    str = strrep(str, '\', '');
    str = regexprep(str, '[\{\}]', '');
    
    % Evaluate
    tau = eval(str);
end

function symExpr = parseLatexToSymbolic(latexStr, n_rec, n_ext, paramMap)
% PARSELATEXTOSYMBOLIC  Convert LaTeX equation to symbolic expression
%
% Handles the GUI variable convention:
%   y_k (k=1..n_rec) -> x(k)       [recurrent inputs]
%   x_n (n=1..n_ext) -> x(n_rec+n) [external inputs]
    
    str = latexStr;
    
    % Remove common LaTeX commands
    str = regexprep(str, '\\frac\{([^}]+)\}\{([^}]+)\}', '(($1)/($2))');
    str = regexprep(str, '\\left|\\right', '');
    str = regexprep(str, '\\cdot', '*');
    str = regexprep(str, '\\times', '*');
    str = strrep(str, '\\,', '');  % thin space
    
    % Convert y_{k} or y_k to x(k) (recurrent -> first k_rec indices)
    str = regexprep(str, 'y_\{(\d+)\}', 'x($1)');
    str = regexprep(str, 'y_(\d+)', 'x($1)');
    
    % Convert x_{n} or x_n to x(n_rec + n) (external -> indices after recurrent)
    % First, temporarily mark them to avoid double-conversion
    str = regexprep(str, 'x_\{(\d+)\}', 'EXTVAR($1)');
    str = regexprep(str, 'x_(\d+)', 'EXTVAR($1)');
    
    % Now replace EXTVAR with proper index
    matches = regexp(str, 'EXTVAR\((\d+)\)', 'tokens');
    for i = 1:length(matches)
        oldIdx = str2double(matches{i}{1});
        newIdx = n_rec + oldIdx;
        str = regexprep(str, sprintf('EXTVAR\\(%d\\)', oldIdx), ...
            sprintf('x(%d)', newIdx), 'once');
    end
    
    % Convert Greek letters (remove backslash)
    str = regexprep(str, '\\([a-zA-Z]+)', '$1');
    
    % Handle implicit multiplication
    str = regexprep(str, '(\d)([a-zA-Z])', '$1*$2');    % 2x -> 2*x
    str = regexprep(str, '([a-zA-Z\)])(\s+)([a-zA-Z\(])', '$1*$3');  % x y -> x*y
    str = regexprep(str, '\)\(', ')*(');                % )( -> )*(
    str = regexprep(str, '([a-zA-Z\)])([a-zA-Z\(])', '$1*$2');  % xy -> x*y
    
    % Substitute parameter values
    paramNames = keys(paramMap);
    for i = 1:length(paramNames)
        name = paramNames{i};
        value = paramMap(name);
        % Use word boundaries to avoid partial matches
        str = regexprep(str, ['(?<![a-zA-Z_])' name '(?![a-zA-Z_0-9])'], ...
            sprintf('(%g)', value));
    end
    
    % Create symbolic variables
    n_total = n_rec + n_ext;
    x = sym('x', [n_total, 1], 'real');
    
    % Parse to symbolic
    try
        symExpr = str2sym(str);
    catch
        % Fallback: try eval with sym variables
        for i = 1:n_total
            eval(sprintf('x%d = x(%d);', i, i));
        end
        symExpr = eval(str);
    end
    
    % Substitute x(i) notation
    for i = 1:n_total
        symExpr = subs(symExpr, sym(sprintf('x(%d)', i)), x(i));
    end
end

function coeff = extractCoefficientForBasisEntry(symExpr, basisEntry, n_rec, n_ext)
% EXTRACTCOEFFICIENTFORBASISENTRY  Extract coefficient for a basis monomial
%
% basisEntry is a row from symbolic_basis_mapping table with columns:
%   [x1_exp, x2_exp, ..., xk_exp, dx1_exp, dx2_exp, ..., const_flag]
%
% Returns the coefficient of this monomial in symExpr
    
    n_total = n_rec + n_ext;
    x = sym('x', [n_total, 1], 'real');
    
    % Build the monomial from the exponents
    % basisEntry format: [exp_x1, exp_x2, ..., exp_xk, exp_dx1, ...]
    % For jet_order=1, it's just [exp_x1, ..., exp_xk]
    
    monomial = sym(1);
    degree = 0;
    
    % Process position variables (first n_total columns for jet_order=1)
    for i = 1:min(n_total, length(basisEntry))
        exp_i = basisEntry(i);
        if exp_i > 0
            monomial = monomial * x(i)^exp_i;
            degree = degree + exp_i;
        end
    end
    
    % If monomial is 1 (constant term), get the constant part
    if degree == 0
        % Constant term: substitute x=0
        coeff = subs(symExpr, x, zeros(size(x)));
    else
        % Extract coefficient of this monomial
        try
            [coeffs_list, terms] = coeffs(expand(symExpr), x);
            
            coeff = sym(0);
            for i = 1:length(terms)
                if isequal(simplify(terms(i) - monomial), sym(0))
                    coeff = coeffs_list(i);
                    break;
                end
            end
        catch
            % Fallback: differentiate to get coefficient
            % For monomial x1^a * x2^b, coefficient is 
            % (1/(a!*b!)) * d^(a+b)f / dx1^a dx2^b evaluated at 0
            coeff = symExpr;
            factorial_term = 1;
            for i = 1:n_total
                exp_i = basisEntry(i);
                if exp_i > 0
                    for j = 1:exp_i
                        coeff = diff(coeff, x(i));
                    end
                    factorial_term = factorial_term * factorial(exp_i);
                end
            end
            coeff = subs(coeff, x, zeros(size(x))) / factorial_term;
        end
    end
    
    % Convert to double
    coeff = double(coeff);
end
