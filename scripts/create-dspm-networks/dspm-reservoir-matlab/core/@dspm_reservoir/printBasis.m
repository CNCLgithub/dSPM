function printBasis(obj, maxRows)
    % PRINTBASIS  Display the symbolic mapping table
    
    if isempty(obj.symbolic_basis_mapping)
        error('Call decompile() first');
    end
    if nargin < 2, maxRows = 20; end
    
    nRows = min(maxRows, height(obj.symbolic_basis_mapping));
    
    fprintf('\n=== Symbolic Basis Mapping ===\n');
    fprintf('jet_order=%d, poly_order=%d, n_monomials=%d\n', ...
        obj.jet_order, obj.decompilation_order, obj.n_monomials);
    fprintf('Note: (∂ⁿxₘ) denotes dⁿxₘ/dtⁿ\n\n');
    
    disp(obj.symbolic_basis_mapping(1:nRows, :));
    
    if nRows < height(obj.symbolic_basis_mapping)
        fprintf('... (%d more rows)\n', height(obj.symbolic_basis_mapping) - nRows);
    end
end
