function indices = getPositionColumns(obj)
    % GETPOSITIONCOLUMNS  Get column indices for position-only terms
    %
    % Returns indices of monomials containing only x₁, x₂, ... (no derivatives)
    
    if isempty(obj.cached_basis), error('Call decompile() first'); end
    
    deg = obj.cached_basis.degrees;
    vel_and_higher = deg(:, obj.n_recurrent_inputs+1:end);
    indices = find(all(vel_and_higher == 0, 2));
end
