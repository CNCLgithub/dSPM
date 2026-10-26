function idx = getColumnIndex(obj, term_str)
    % GETCOLUMNINDEX  Find column index for a basis term
    %
    % Accepts EITHER y-variable notation OR physical notation:
    %   idx = res.getColumnIndex('y1')          % y-variable form
    %   idx = res.getColumnIndex('y1*y4')       % y-variable product
    %   idx = res.getColumnIndex('x₁')          % physical form
    %   idx = res.getColumnIndex('x₁·(∂x₂)')    % physical product
    %   idx = res.getColumnIndex('1')           % constant term
    %
    % For convenience, also accepts ASCII-friendly versions:
    %   idx = res.getColumnIndex('x1')          % x₁
    %   idx = res.getColumnIndex('x1*x2')       % x₁·x₂
    %   idx = res.getColumnIndex('(dx1)')       % (∂x₁)
    %   idx = res.getColumnIndex('(d2x1)')      % (∂²x₁)
    %
    % Note: (∂ⁿxₘ) denotes the n-th time derivative of xₘ, i.e., dⁿxₘ/dtⁿ
    
    if isempty(obj.physical_basis_strings)
        error('Call decompile() first');
    end
    
    % Normalize input for flexible matching
    term_str = obj.normalizeTermString(term_str);
    
    % First try physical basis
    idx = find(strcmp(obj.physical_basis_strings, term_str));
    
    % If not found, try y-variable basis
    if isempty(idx)
        term_y = strrep(term_str, '·', '*');
        idx = find(strcmp(obj.symbolic_basis_strings, term_y));
    end

    % If not found, try y-variable basis
    if isempty(idx)
        term_y = replace(term_str,'x','y');
        idx = find(strcmp(obj.symbolic_basis_strings, term_y));
    end

    if isempty(idx)
        warning('Term "%s" not found in basis. Use printBasis() to see available terms.', term_str);
    end
end
