function indices = getQuadraticColumns(obj)
    % GETQUADRATICCOLUMNS  Get column indices for quadratic terms (total degree = 2)
    %
    % Returns indices for: x₁², x₁·x₂, x₁·(∂x₁), (∂x₁)², ...
    
    if isempty(obj.cached_basis), error('Call decompile() first'); end
    
    total_deg = sum(obj.cached_basis.degrees, 2);
    indices = find(total_deg == 2);
end
