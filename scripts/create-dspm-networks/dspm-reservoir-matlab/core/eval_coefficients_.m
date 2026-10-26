function [sortedBasis, decompWeights, sortIdx, basisMapping] = eval_coefficients_(obj)
% EVAL_COEFFICIENTS_  Evaluate cached symbolic coefficients with current numeric values
%
% This is CHEAP. Runs every time decompile() is called.
% Uses eval() on pre-built strings - no symbolic computation!

    % Ensure Taylor coefficients are computed
    if ~obj.taylor_cache_valid_ || isempty(obj.symbolic_taylor_coefficients_)
        taylor_expansion_(obj);
    end
    
    if obj.verbose
        fprintf('eval_coefficients_: Evaluating with current numeric values...\n');
        tic
    end
    
    %% Extract numeric values into local workspace for eval()
    %  These variable names must match what's in the coefficient strings
    N     = obj.n_neurons;          %#ok<NASGU> - used in eval()
    gamma = obj.gamma;              %#ok<NASGU> - used in eval()
    B     = obj.read_in_matrix_B;   %#ok<NASGU> - used in eval()
    d     = obj.bias;               %#ok<NASGU> - used in eval()
    
    ninputs = obj.n_inputs;
    nyvars  = obj.jet_order * ninputs;
    
    %% Evaluate each coefficient string
    taylor_coeffs = obj.symbolic_taylor_coefficients_;
    decompWeights = cellfun(@eval, taylor_coeffs, 'UniformOutput', false);
    decompWeights = cat(2, decompWeights{:});
    
    %% Sort into canonical order
    taylor_basis = obj.symbolic_taylor_basis_;
    
    [sortedBasis, decompWeights, sortIdx, basisMapping] = ...
        sort_canonical(taylor_basis, decompWeights, nyvars, ninputs);
    
    if obj.verbose
        fprintf('eval_coefficients_: Done (%.4f sec), R is %d × %d\n', ...
            toc, size(decompWeights, 1), size(decompWeights, 2));
    end

end  % function eval_coefficients_

%%  HELPER FUNCTIONS

function [sortedBasis, sortedWeights, sortIdx, degreeTable] = sort_canonical(...
    basisMapping, decompWeights, nyvars, nvars_per_deriv)
% SORT_CANONICAL  Sort polynomial basis into canonical ordering
%
% Canonical order prioritizes:
%   1. Total degree (ascending): constants, then linear, then quadratic, ...
%   2. Max single-variable degree (ascending): mixed terms before pure powers
%      e.g., y1*y2 comes before y1^2
%   3. Minimum variable index: y1 terms before y2 terms
%
% This ordering makes the basis predictable and interpretable:
%   [1, y1, y2, y3, y1*y2, y1*y3, y2*y3, y1^2, y2^2, y3^2, y1*y2*y3, ...]

    % Transpose for easier row-wise operations
    b = basisMapping';
    
    % Extract the minimum variable index appearing in each monomial
    minScalar = cellfun(@(s) extract_min_var_index(s), b, 'UniformOutput', true);
    minScalar(isnan(minScalar)) = 0;  % Constant term has no variables
    
    % Build exponent map: entry (m, j) = exponent of y_j in monomial m
    exponentMap = zeros(numel(b), nyvars);
    for i = 1:nyvars
        exponentMap(:, i) = getExponentValues(b, "y" + i);
    end
    
    % Compute sorting keys
    totalDegree = sum(exponentMap, 2);      % Total polynomial degree
    maxExponent = max(exponentMap, [], 2);  % Highest power of any single variable
    
    % Sort by [totalDegree, maxExponent, minVarIndex]
    sortKeys = [totalDegree, maxExponent, minScalar];
    [~, sortIdx] = sortrows(sortKeys, [1, 2, 3], 'ascend');
    
    % Apply permutation
    sortedBasis   = b(sortIdx);
    sortedWeights = decompWeights(:, sortIdx);
    exponentMapSorted = exponentMap(sortIdx, :);
    
    % Build human-readable physical notation
    physicalBasis = buildPhysicalBasis(exponentMapSorted, nvars_per_deriv);
    
    % Create summary table
    varNames = "y" + (1:nyvars) + "^n";
    degreeTable = array2table(exponentMapSorted, ...
        'VariableNames', varNames, ...
        'RowNames', sortedBasis);
    degreeTable.Physical = string(physicalBasis);
    degreeTable = degreeTable(:, ['Physical', varNames]);  % Reorder columns
    
end  % function sort_canonical
    
    
function minIdx = extract_min_var_index(str)
    % EXTRACT_MIN_VAR_INDEX  Find smallest variable index in monomial string
    
    tokens = regexp(str, 'y(\d+)', 'tokens');
    if isempty(tokens)
        minIdx = NaN;
    else
        indices = cellfun(@(c) str2double(c{1}), tokens);
        minIdx = min(indices);
    end

end  % function extract_min_var_index
    
    
function exponentValues = getExponentValues(basisStrings, yPattern)
% GETEXPONENTVALUES  Extract exponent of specific y-variable from each monomial
    
    n = numel(basisStrings);
    exponentValues = zeros(n, 1);
    
    for i = 1:n
        s = basisStrings{i};
        
        if ~contains(s, yPattern)
            continue;
        end
        
        % Look for explicit exponent: "y1^3" → capture "3"
        pattern = yPattern + "\^(\d+)";
        tokens = regexp(s, pattern, 'tokens');
        
        if ~isempty(tokens)
            exponentValues(i) = str2double(tokens{1}{1});
        else
            % Check if variable appears without exponent (implicit ^1)
            patternExact = yPattern + "(?!\d)";  % Negative lookahead for digit
            if ~isempty(regexp(s, patternExact, 'once'))
                exponentValues(i) = 1;
            end
        end
    end

end  % function getExponentValues


function physicalBasis = buildPhysicalBasis(exponentMap, nvars_per_deriv)
% BUILDPHYSICALBASIS  Convert y-basis to physical notation
% Note: (∂ⁿxₘ) denotes the n-th *time* derivative of xₘ, i.e., dⁿxₘ/dtⁿ

% Maps:
%   y1, y2, ..., y_k       →  x₁, x₂, ..., xₖ           (position)
%   y_{k+1}, ..., y_{2k}   →  (∂x₁), (∂x₂), ..., (∂xₖ)  (velocity)
%   y_{2k+1}, ..., y_{3k}  →  (∂²x₁), (∂²x₂), ...       (acceleration)
%   y_{3k+1}, ..., y_{4k}  →  (∂³x₁), (∂³x₂), ...       (jerk)
%
% Examples given three symbolic inputs (x₁, x₂, x₃):
%   y1*y4      →  x₁·(∂x₁)
%   y2^2*y7    →  x₂²·(∂²x₁)
%   y1*y2*y3   →  x₁·x₂·x₃

    n_mono = size(exponentMap, 1);
    physicalBasis = cell(n_mono, 1);
    
    sup = {'⁰','¹','²','³','⁴','⁵','⁶','⁷','⁸','⁹'};
    sub = {'₀','₁','₂','₃','₄','₅','₆','₇','₈','₉'};
    
    for m = 1:n_mono
        exp_vec = exponentMap(m, :);
        
        if all(exp_vec == 0),physicalBasis{m} = '1';continue,end
        
        loop_indices = find(exp_vec ~= 0);
        terms = strings(numel(loop_indices), 1);
        
        for i = 1:numel(loop_indices)

            j = loop_indices(i);

            exp_val     = exp_vec(j);
            deriv_order = floor((j - 1) / nvars_per_deriv);
            base_idx    = mod(j - 1, nvars_per_deriv) + 1;

            varStr = "x" + idx2unicode(base_idx, sub);

            if deriv_order == 1
                varStr = "(∂" + varStr + ")";
            elseif deriv_order > 1
                varStr = "(∂" + idx2unicode(deriv_order, sup) + varStr + ")";
            end

            if exp_val > 1
                varStr = varStr + idx2unicode(exp_val, sup);
            end
            
            terms(i) = varStr;
        end
        
        physicalBasis{m} = strjoin(terms, '·');
    end

end


function str = idx2unicode(n, charMap)
    digits = num2str(n) - '0';
    str    = [charMap{digits + 1}];
end