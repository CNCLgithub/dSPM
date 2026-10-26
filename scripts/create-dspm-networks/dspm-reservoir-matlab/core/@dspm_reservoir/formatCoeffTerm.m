function term = formatCoeffTerm(w, basisLatex, precision, isFirst)
    % FORMATCOEFFTERM  Format a coefficient × basis term for LaTeX
    %
    % Handles special cases:
    %   - Coefficient ≈ ±1 with non-constant basis: show ±basis
    %   - Constant term (empty basisLatex): show coefficient only
    %   - First term: no leading +
    
    isConstant = isempty(basisLatex);
    isUnitCoeff = abs(abs(w) - 1) < 1e-10;
    
    % Format the coefficient
    if isConstant
        % Pure constant term - always show the number
        coeffStr = sprintf('%.*g', precision, w);
        if ~isFirst && w > 0
            term = sprintf('+ %s', coeffStr);
        else
            term = coeffStr;
        end
        
    elseif isUnitCoeff
        % Coefficient is ±1, don't show "1"
        if w > 0
            if isFirst
                term = basisLatex;
            else
                term = sprintf('+ %s', basisLatex);
            end
        else
            if isFirst
                term = sprintf('-%s', basisLatex);
            else
                term = sprintf('- %s', basisLatex);
            end
        end
        
    else
        % General case: show coefficient
        absW = abs(w);
        coeffStr = sprintf('%.*g', precision, absW);
        
        if w > 0
            if isFirst
                term = sprintf('%s %s', coeffStr, basisLatex);
            else
                term = sprintf('+ %s %s', coeffStr, basisLatex);
            end
        else
            if isFirst
                term = sprintf('-%s %s', coeffStr, basisLatex);
            else
                term = sprintf('- %s %s', coeffStr, basisLatex);
            end
        end
    end
end
