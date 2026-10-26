function render_program(obj, varargin)
    % RENDER_PROGRAM  Display the programmed dynamics as LaTeX equations
    %
    % Renders the compiled program matrix P as a system of differential equations
    % using the symbolic basis monomials. Transforms from constraint form
    % (y + (1/γ)ẏ = P·φ) to dynamics form (ẏ = f(y)).
    %
    % Usage:
    %   res.render_program()
    %   res.render_program('Precision', 3, 'Theme', 'dark')
    %
    % Options:
    %   'Precision'  - Significant figures for coefficients (default: 4)
    %   'Tolerance'  - Coefficients below this are treated as zero (default: 1e-10)
    %   'Theme'      - 'light' or 'dark' (default: 'dark')
    %   'Title'      - Figure title (default: 'Programmed Dynamics')
    %
    % See also: compile, decompile, renderLatex
    
    p = inputParser;
    addParameter(p, 'Precision', 4, @isnumeric);
    addParameter(p, 'Tolerance', 1e-10, @isnumeric);
    addParameter(p, 'Theme', 'dark', @ischar);
    addParameter(p, 'Title', 'Programmed Dynamics', @ischar);
    parse(p, varargin{:});
    opts = p.Results;
    
    % Validate state
    if ~obj.is_compiled
        error('dspm_reservoir:notCompiled', ...
            'Network not compiled. Call compile(P) first.');
    end
    
    if isempty(obj.symbolic_basis_strings)
        error('dspm_reservoir:noBasis', ...
            "No symbolic basis available. Call decompile() and " + ...
            "compile(P) first.");
    end
    
    P     = obj.compiled_program_matrix;
    basis = obj.symbolic_basis_strings;
    neqns = size(P, 1);
    
    latexEqns = cell(neqns, 1);
    
    for i = 1:neqns
        weights = P(i, :);
        
        % ============================================================
        % TRANSFORM FROM CONSTRAINT FORM TO DYNAMICS FORM
        % The program encodes: y + (1/γ)ẏ = P·φ(y)
        % We want to display: ẏ = γ·(P·φ(y) - y)
        % So: subtract 1 from the y_i coefficient, 
        %     then multiply by the time constant γ
        % ============================================================
        yi_col = find(strcmp(basis, sprintf('y%d', i)), 1);
        if ~isempty(yi_col)
            weights(yi_col) = weights(yi_col) - 1;
        end
        weights = obj.gamma * weights;

        terms = {};
        isFirstTerm = true;
        
        for j = 1:length(weights)
            w = weights(j);
            
            % Skip negligible terms
            if abs(w) <= opts.Tolerance,continue;end
            
            % Convert basis string to LaTeX
            basisLatex = obj.basisToLatex(basis{j});
            
            % Format the term with coefficient
            term = obj.formatCoeffTerm(w, basisLatex, opts.Precision, isFirstTerm);
            terms{end+1} = term; %#ok<AGROW>
            isFirstTerm  = false;
        end
        
        % join monomial terms into RHS of equation
        if isempty(terms),rhs = '0';
        else,rhs = strjoin(terms, ' ');end
        
        latexEqns{i} = sprintf('\\dot{y}_{%d} = %s', i, rhs);
    end
    
    % Add pedagogical explaination of actual transformation to
    % programmed matrix due to the W(r + (1/𝛾)ṙ) = 𝑦 + (1/𝛾)𝑦̇ = P
    latexEqns{neqns} = latexEqns{neqns}+"\\ \, \\"+...
        "\text{Compilation Pipeline:}"+...
        "\\ \, \\"+...
        "\qquad\dot{\vec{y}} = " + ...
            "\begin{bmatrix}" + ...
            "    \dot{y}_1\\ \vdots \\ \dot{y}_"+neqns+ ...
            "\end{bmatrix}"+...
            "\overset{\text{programmed}}{\Longrightarrow} " + ...
            "W(r + \frac{1}{\gamma}\dot{r}) =" + ...
            "\vec{y} + \frac{1}{\gamma}\dot{\vec{y}} " + ...
            "\implies  P\cdot\phi(\vec{y})" + ...
        "\\ \, \\ " + ...
        "\qquad\text{where } \phi(\vec{y}) = " + ...
            "\set{\text{symbolic monomial basis}} " + ...
            "\text{ and } \gamma = " + obj.gamma +...
            "= (\text{the network time constant})" + ...
        "\\ \, \\" + ...
        "\qquad\text{Compiled Program}: W = \mathrm{argmin}_{W}" + ...
            "||WR - P||_{F}"+ ...
        "\\ \, \\" + ...
        "\qquad\text{Closed-loop Network Adjacency}: " + ...
            "\tilde{A} = B_{rec}W"...
        ;

    % Call renderLatex
    renderLatex(latexEqns, ...
        'Title', opts.Title, ...
        'Theme', opts.Theme,...
        "HorizontalAlignment","left" );

end
