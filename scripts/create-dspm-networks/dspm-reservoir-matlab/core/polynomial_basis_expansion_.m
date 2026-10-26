function polynomial_basis_expansion_(obj)
% TAYLOR_EXPANSION_  Taylor expand h(y) around y_star, extract coefficient strings
%
% This is MODERATE cost. Only runs when:
%   - decompilation_order changes
%   - jet cache was invalidated
%
% Output: cell arrays of STRINGS ready for eval()
% Cached in obj.symbolic_taylor_coeffs_, obj.symbolic_taylor_basis_

    % Check cache
    if obj.taylor_cache_valid_ && ~isempty(obj.symbolic_taylor_coefficients_)
        if obj.verbose
            fprintf('taylor_expansion_: Using cached Taylor coefficients\n');
        end
        return
    end
    
    % Ensure jet is computed
    if ~obj.jet_cache_valid_ || isempty(obj.symbolic_jet_equation_)
        jet_expansion_(obj);
    end
    
    if obj.verbose
        fprintf('taylor_expansion_: Computing Taylor expansion (order=%d)...\n', ...
            obj.decompilation_order);
        tic
    end
    
    decomp_order = obj.decompilation_order;
    ninputs      = obj.n_inputs;
    nyvars       = obj.jet_order * ninputs;
    
    % Define symbolic y-variables (must match jet_expansion_)
    syms y [nyvars 1] real
    
    % Get cached jet equation
    symbolic_jet_equation = obj.symbolic_jet_equation_;
    
    %% Taylor expand around y = 0
    %  We expand around origin here; non-zero y_star would require coordinate shift
    %  which can be handled at eval time if needed.
    %
    %  "OrderMode"="relative" means expand to order decomp_order in TOTAL degree
    
    tayy = taylor(symbolic_jet_equation, y, zeros(nyvars, 1), ...
        "order", decomp_order, "OrderMode", "relative");
    
    % Extract polynomial coefficients and basis monomials
    [rDecompiled, bases] = coeffs(tayy, y);
    
    % Convert to cell arrays of strings
    rDecompiled  = strsplit(erase(string(rDecompiled), ["[","]"]), ",");
    taylor_basis = strsplit(erase(string(bases), ["[","]"]), ",");
    
    %% Prepare coefficient strings for eval()
    %  Replace symbolic placeholders with MATLAB array syntax
    
    % for i = 1:ninputs
    %     rDecompiled = replace(rDecompiled, "Bsym" + i, sprintf("B(:,%d)", i));
    % end
    rDecompiled = regexprep(rDecompiled, 'Bsym(\d+)', 'B(:,$1)');
    rDecompiled = replace(rDecompiled, "dsym", "d");
    
    % Convert to element-wise operations for vectorization
    rDecompiled = replace(rDecompiled, ["*", "^", "/"], [".*", ".^", "./"]);
    
    %% Cache results
    obj.symbolic_taylor_coefficients_ = rDecompiled;
    obj.symbolic_taylor_basis_  = taylor_basis;
    obj.taylor_cache_valid_     = true;
    
    if obj.verbose
        fprintf('taylor_expansion_: Done (%.2f sec), %d monomials\n', ...
            toc, numel(taylor_basis));
    end

end  % function taylor_expansion_


