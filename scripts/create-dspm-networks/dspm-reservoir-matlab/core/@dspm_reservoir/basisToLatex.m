function latexStr = basisToLatex(basisStr)
    % BASISTOLATEX  Convert symbolic basis string to LaTeX
    %
    % Examples:
    %   "1"        → ""  (constant term)
    %   "y1"       → "y_{1}"
    %   "y1*y2"    → "y_{1} y_{2}"
    %   "y1^2"     → "y_{1}^{2}"
    %   "y1*y3^2"  → "y_{1} y_{3}^{2}"
    
    s = string(basisStr);
    
    % Handle constant term
    if s == "1"
        latexStr = '';  % Will be handled specially
        return;
    end
    
    % Replace * with space (implicit multiplication in LaTeX)
    s = replace(s, '*', ' ');
    
    % Handle patterns like "y1^2" → "y_{1}^{2}" (with exponent)
    % Must do this BEFORE the simple y1 → y_{1} replacement
    s = regexprep(s, 'y(\d+)\^(\d+)', 'y_{$1}^{$2}');
    
    % Handle patterns like "y1" → "y_{1}" (no exponent)
    % Negative lookbehind to avoid matching already-processed y_{1}
    s = regexprep(s, 'y(\d+)(?!\})', 'y_{$1}');
    
    % Handle derivative notation if present: (dy1) → \dot{y}_{1}
    s = regexprep(s, '\(dy(\d+)\)', '\\dot{y}_{$1}');
    s = regexprep(s, '\(d2y(\d+)\)', '\\ddot{y}_{$1}');
    
    latexStr = char(s);
end
