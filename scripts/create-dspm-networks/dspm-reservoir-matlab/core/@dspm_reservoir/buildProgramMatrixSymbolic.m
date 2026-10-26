function [P, sourceEqs, sourceConsts] = buildProgramMatrixSymbolic(obj, dx, tau, constants, uservars)
    % BUILDPROGRAMMATRIXSYMBOLIC  Build P matrix from symbolic dynamics
    %
    % Implements the DNP formula: P(i,:) = yᵢ + (1/γ)·f_i(y)
    %
    % For each equation row i:
    %   1. Extract coefficients of f_i(y) for each monomial
    %   2. Scale by tau(i)/gamma
    %   3. Add identity term for state variable y_i
    
    if nargin < 5, uservars = sym([]); end

    neqns  = numel(dx);
    nbases = obj.n_monomials;
    n_vars = obj.n_inputs*obj.jet_order;
    gam    = obj.gamma;
    
    P = zeros(neqns, nbases);
    
    % Create canonical symbolic variables x1, x2, ...
    xvars = sym('x', [n_vars, 1], 'real');

    % ===== SUBSTITUTE NUMERIC CONSTANTS INTO THE DYNAMICS =====
    % Constants passed as program(dx, constants=struct('sigma',10,...)) may be
    % used symbolically in dx; substitute their values before coefficient
    % extraction (previously they were storage-only).
    cn = fieldnames(constants);
    for c = 1:numel(cn)
        v = constants.(cn{c});
        if isnumeric(v) && isscalar(v)
            dx = subs(dx, sym(cn{c}), v);
        end
    end

    % ===== NAME-AGNOSTIC VARIABLE DECODE =====
    % The user's symbolic variables may be named ANYTHING (x1.., y1.., u/v/w,
    % theta/omega, ...). Map them onto the canonical basis slots:
    %   slot i (1..m03)  = recurrent port i = state variable of equation i
    %   slots m03+1..m  = exogenous/external ports (drive terms), in port order
    % Explicit control: program(dx, vars=[q1 q2 ...]) fixes the slot order.
    % Default: canonical index names (x<k>/y<k>/x_<k>/y_<k>) map by index as
    % before; any other names map in symvar (alphabetical) order, announced.
    vs = symvar(dx);
    if ~isempty(vs)
        isCanon = false(1, numel(vs));
        for k = 1:numel(vs)
            isCanon(k) = ~isempty(regexp(char(vs(k)), '^[xy]_?\d+$', 'once'));
        end
        if isempty(uservars) && ~all(isCanon)
            uservars = vs;   % alphabetical — deterministic, announced below
            if obj.verbose
                fprintf('program: mapping symbolic variables to basis slots (alphabetical):\n');
            end
        end
        if ~isempty(uservars)
            uservars = uservars(:);
            if numel(uservars) > n_vars
                error('dspm_reservoir:tooManyVars', ...
                    '%d symbolic variables supplied but the basis has %d input slots.', ...
                    numel(uservars), n_vars);
            end
            if obj.verbose
                for k = 1:numel(uservars)
                    if k <= numel(obj.ports)
                        fprintf('    %-10s -> x%d   (port %s, %s)\n', char(uservars(k)), k, ...
                            obj.ports(k).id, obj.ports(k).role);
                    else
                        fprintf('    %-10s -> x%d\n', char(uservars(k)), k);
                    end
                end
            end
            dx = subs(dx, uservars, xvars(1:numel(uservars)));   % simultaneous
        end
    end
    
    for i = 1:neqns
        expr = dx(i);
        
        % ===== NORMALIZE VARIABLE NAMES =====
        % Handle various naming conventions: y1, y_1, x1(t), etc.
        for k = 1:n_vars
            % x1(t), x2(t), ... → x1, x2, ...
            expr = subs(expr, str2sym(sprintf('x%d(t)', k)), xvars(k));
            % y1(t), y2(t), ... → x1, x2, ...
            expr = subs(expr, str2sym(sprintf('y%d(t)', k)), xvars(k));
            % x_1, x_2, ... → x1, x2, ...
            expr = subs(expr, str2sym(sprintf('x_%d', k)), xvars(k));
            % y_1, y_2, ... → x1, x2, ...
            expr = subs(expr, str2sym(sprintf('y_%d', k)), xvars(k));
            % y1, y2, ... → x1, x2, ...
            expr = subs(expr, str2sym(sprintf('y%d', k)), xvars(k));
        end
        
        % ===== EXPAND AND EXTRACT COEFFICIENTS =====
        expr = expand(expr);
        [coeffVec, monomials] = coeffs(expr, xvars);
        
        % Map each monomial to P matrix column
        for j = 1:length(monomials)
            mono  = monomials(j);
            coeff = double(coeffVec(j));
            
            colStr = obj.sym2colstr(mono, n_vars);
            colIdx = obj.getColumnIndex(colStr);
            
            if colIdx > 0
                % DNP formula: scale dynamics by tau/gamma
                P(i, colIdx) = P(i, colIdx) + coeff / (gam * tau(i));
            else
                warning('dspm_reservoir:unmappedMonomial', ...
                    'Monomial "%s" not in basis (max order=%d). Increase decompilation_order.', ...
                    char(mono), obj.decompilation_order);
            end
        end
        
        
        % ===== ADD IDENTITY TERM FOR RECURRENT OUTPUTS =====
        % DNP formula: P(i,:) = yᵢ + (1/γ)·f_i(y)
        if i <= obj.n_recurrent_outputs
            identityIdx = obj.getColumnIndex(sprintf('x%d', i));
            if identityIdx > 0
                P(i, identityIdx) = P(i, identityIdx) + 1;
            end
        end
    end
    
    % ===== BUILD SOURCE STRUCTS FOR GUI COMPATIBILITY =====
    sourceEqs = struct('index', {}, 'outputType', {}, 'tau', {}, 'latex', {});
    for i = 1:neqns
        if i <= obj.n_external_outputs
            outType = 'external';
        else
            outType = 'recurrent';
        end
        sourceEqs(i).index = i;
        sourceEqs(i).outputType = outType;
        sourceEqs(i).tau = num2str(tau(i));
        sourceEqs(i).latex = latex(dx(i));  % Convert symbolic to LaTeX
    end
    
    % Build source constants struct
    constNames = fieldnames(constants);
    sourceConsts = struct('name', {}, 'value', {}, 'display_value', {}, 'description', {});
    for i = 1:numel(constNames)
        sourceConsts(i).name = constNames{i};
        sourceConsts(i).value = constants.(constNames{i});
        sourceConsts(i).display_value = num2str(constants.(constNames{i}));
        sourceConsts(i).description = '';
    end
end
