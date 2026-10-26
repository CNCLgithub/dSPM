function indices = getColumnIndices(obj, term_strs)
    % GETCOLUMNINDICES  Find column indices for multiple terms
    %
    % Input: cell array or string array of term strings
    % Output: array of indices (NaN for not found)
    %
    % Example:
    %   idx = res.getColumnIndices({'x₁', 'x₂', 'x₁·x₂'});
    %   idx = res.getColumnIndices({'x1', '(dx1)', '(d2x1)'});  % ASCII-friendly
    
    if ischar(term_strs) || isstring(term_strs) && isscalar(term_strs)
        term_strs = {term_strs};
    end
    
    indices = zeros(1, numel(term_strs));
    for i = 1:numel(term_strs)
        idx = obj.getColumnIndex(term_strs{i});
        if isempty(idx)
            indices(i) = NaN;
        else
            indices(i) = idx;
        end
    end
end
