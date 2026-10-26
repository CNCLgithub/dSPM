function normalized = normalizeTermString(term_str)
    % NORMALIZETERMSTRING  Convert ASCII-friendly notation to Unicode
    %
    % Conversions:
    %   'x1', 'x2', ...     →  'x₁', 'x₂', ...
    %   '(dx1)', '(dx2)'    →  '(∂x₁)', '(∂x₂)'
    %   '(d2x1)', '(d3x2)'  →  '(∂²x₁)', '(∂³x₂)'
    %   'x1*x2', 'x1·x2'    →  'x₁·x₂'
    %   '*'                 →  '·'
    
    sub = {'₀','₁','₂','₃','₄','₅','₆','₇','₈','₉'};
    sup = {'⁰','¹','²','³','⁴','⁵','⁶','⁷','⁸','⁹'};
    
    normalized = string(term_str);
    
    % Replace * with ·
    normalized = replace(normalized, '*', '·');
    
    % Replace (dNxM) patterns with (∂ᴺxₘ)
    % Match patterns like (d2x1), (dx3), (d12x5)
    tokens = regexp(normalized, '\(d(\d*)x(\d+)\)', 'tokens');
    for t = 1:numel(tokens)
        deriv_order = tokens{t}{1};
        var_idx = tokens{t}{2};
        
        if isempty(deriv_order)
            deriv_order = '1';
        end
        
        % Build Unicode version
        if str2double(deriv_order) == 1
            deriv_sup = '';
        else
            deriv_sup = idx2unicode(str2double(deriv_order), sup);
        end
        var_sub = idx2unicode(str2double(var_idx), sub);
        
        old_pattern = sprintf('(d%sx%s)', tokens{t}{1}, var_idx);
        new_pattern = sprintf('(∂%sx%s)', deriv_sup, var_sub);
        normalized = replace(normalized, old_pattern, new_pattern);
    end
    
    % Replace xN patterns with xₙ (but not inside parentheses, already handled)
    tokens = regexp(normalized, '(?<!\()x(\d+)(?!\))', 'tokens');
    for t = 1:numel(tokens)
        var_idx = tokens{t}{1};
        var_sub = idx2unicode(str2double(var_idx), sub);
        
        old_pattern = sprintf('x%s', var_idx);
        new_pattern = sprintf('x%s', var_sub);
        normalized = replace(normalized, old_pattern, new_pattern);
    end
    
    normalized = char(normalized);

    % Helper function to go from index to the unicode character
    function str = idx2unicode(n, charMap)
        digits = num2str(n) - '0';
        str = [charMap{digits + 1}];
    end
end
