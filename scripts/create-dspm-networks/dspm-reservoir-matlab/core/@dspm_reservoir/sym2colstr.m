function colStr = sym2colstr(~, mono, n_vars)
    % SYM2COLSTR  Convert symbolic monomial to canonical column index string
    
    if mono == 1,colStr = '1';return;end
    
    % Use symbolic degree extraction for each variable
    xvars = sym('x', [n_vars, 1], 'real');
    parts = {};
    
    for k = 1:n_vars
        deg = polynomialDegree(mono, xvars(k));
        for rep = 1:deg
            parts{end+1} = sprintf('y%d', k); %#ok<AGROW>
        end
    end
    
    if isempty(parts),colStr = '1';
    else,colStr = strjoin(parts, '*');end

end
