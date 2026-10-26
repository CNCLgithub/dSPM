function indices = getVelocityColumns(obj)
    % GETVELOCITYCOLUMNS  Get column indices involving velocity terms
    %
    % Returns indices of monomials containing (∂x₁), (∂x₂), ... 
    
    if isempty(obj.cached_basis), error('Call decompile() first'); end
    if obj.jet_order < 2, indices = []; return; end
    
    deg = obj.cached_basis.degrees;
    vel_cols = deg(:, obj.n_recurrent_inputs+1:min(2*obj.n_recurrent_inputs, obj.n_symbolic_vars));
    indices = find(any(vel_cols > 0, 2));
end
