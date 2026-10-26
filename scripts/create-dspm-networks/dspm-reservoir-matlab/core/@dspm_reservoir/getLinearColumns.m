function indices = getLinearColumns(obj)
    % GETLINEARCOLUMNS  Get column indices for linear terms (total degree = 1)
    %
    % Returns indices for: x₁, x₂, ..., (∂x₁), (∂x₂), ..., (∂²x₁), ...
    
    if isempty(obj.cached_basis), error('Call decompile() first'); end
    
    total_deg = sum(obj.cached_basis.degrees, 2);
    indices = find(total_deg == 1);
end
