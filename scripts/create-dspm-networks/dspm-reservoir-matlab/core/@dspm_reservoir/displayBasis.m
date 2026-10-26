function displayBasis(obj)
    % DISPLAYBASIS  Display comprehensive basis information with programming template
    %
    % Shows:
    %   - Reservoir configuration
    %   - Jet and polynomial structure
    %   - Column mapping (y-variables ↔ physical)
    %   - Template code for programming (Lorenz attractor example)
    
    if isempty(obj.symbolic_basis_mapping)
        error('Call decompile() first');
    end
    
    sup = {'⁰','¹','²','³','⁴','⁵','⁶','⁷','⁸','⁹'};
    
    funicode = @dspm_reservoir.idx2unicode;
    % Build jet order symbols: x, (∂x), (∂²x), ...
    jetSyms = "x";
    for k = 2:obj.jet_order
        if k == 2
            jetSyms = jetSyms + ", (∂x)";
        else
            jetSyms = jetSyms + ", (∂" + funicode(k-1, sup) + "x)";
        end
    end
    
    % Build polynomial order symbols: 1, x, x², x³, ...
    polySyms = "1";
    for k = 1:obj.decompilation_order
        polySyms = polySyms + ", x" + funicode(k, sup);
    end
    
    % Header
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    RESERVOIR CONFIGURATION                       ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Neurons (N):              %-6d                                  ║\n', obj.n_neurons);
    fprintf('║  Recurrent inputs (k_rec): %-6d                                  ║\n', obj.n_recurrent_inputs);
    fprintf('║  External inputs (k_ext):  %-6d                                  ║\n', obj.n_external_inputs);
    fprintf('║  Time constant (γ):        %-6.1f                                ║\n', obj.gamma);
    fprintf('║  Time step (dt):           %-6.4f                                ║\n', obj.dt);
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                    DECOMPILATION STRUCTURE                       ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Jet Order:          %d  →  {%s}\n', obj.jet_order, jetSyms);
    fprintf('║  Polynomial Order:   %d  →  {%s}\n', obj.decompilation_order, polySyms);
    fprintf('║  Extended Variables: %d  (jet_order × n_recurrent_inputs)\n', obj.n_symbolic_vars);
    fprintf('║  Basis Monomials:    %d\n', obj.n_monomials);
    fprintf('║                                                                  ║\n');
    fprintf('║  Note: (∂ⁿxₘ) denotes the n-th time derivative dⁿxₘ/dtⁿ          ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                    COLUMN MAPPING                                ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    
    % Show first ~15 basis terms in aligned columns
    nShow = min(15, obj.n_monomials);
    
    % Build column index row
    cRow = "  Columns:  [";
    for i = 1:nShow
        cRow = cRow + sprintf(' %d', i);
        if i < nShow, cRow = cRow + ","; end
    end
    if obj.n_monomials > nShow, cRow = cRow + ", ..."; end
    cRow = cRow + " ]";
    
    % Build y-variable row
    yRow = "  y-vars:   [";
    for i = 1:nShow
        yRow = yRow + " " + obj.symbolic_basis_strings{i};
        if i < nShow, yRow = yRow + ","; end
    end
    if obj.n_monomials > nShow, yRow = yRow + ", ..."; end
    yRow = yRow + " ]";
    
    % Build physical row
    pRow = "  Physical: [";
    for i = 1:nShow
        pRow = pRow + " " + obj.physical_basis_strings{i};
        if i < nShow, pRow = pRow + ","; end
    end
    if obj.n_monomials > nShow, pRow = pRow + ", ..."; end
    pRow = pRow + " ]";
    
    fprintf('║%s\n', cRow);
    fprintf('║%s\n', yRow);
    fprintf('║%s\n', pRow);
    
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                    PROGRAMMING TEMPLATE                          ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
    fprintf('║  %% Example: Lorenz attractor (σ=10, ρ=28, β=8/3)                ║\n');
    fprintf('║  %%                                                              ║\n');
    fprintf('║  %% Target dynamics:                                             ║\n');
    fprintf('║  %%   ẋ₁ = σ(x₂ - x₁)                                            ║\n');
    fprintf('║  %%   ẋ₂ = x₁(ρ - x₃) - x₂                                       ║\n');
    fprintf('║  %%   ẋ₃ = x₁x₂ - βx₃                                            ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  sigma = 10; rho = 28; beta = 8/3;                               ║\n');
    fprintf('║  gam = res.gamma;                                                ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Build program matrix P where each row is: xᵢ + (1/γ)ẋᵢ       ║\n');
    fprintf('║  P = zeros(res.n_recurrent_inputs, res.n_monomials);             ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Row 1: x₁ + (σ/γ)(x₂ - x₁)                                   ║\n');
    fprintf('║  P(1, res.getColumnIndex(''x1'')) = 1 - sigma/gam;               ║\n');
    fprintf('║  P(1, res.getColumnIndex(''x2'')) = sigma/gam;                   ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Row 2: x₂ + (1/γ)(ρx₁ - x₁x₃ - x₂)                           ║\n');
    fprintf('║  P(2, res.getColumnIndex(''x1'')) = rho/gam;                     ║\n');
    fprintf('║  P(2, res.getColumnIndex(''x2'')) = 1 - 1/gam;                   ║\n');
    fprintf('║  P(2, res.getColumnIndex(''x1*x3'')) = -1/gam;                   ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Row 3: x₃ + (1/γ)(x₁x₂ - βx₃)                                ║\n');
    fprintf('║  P(3, res.getColumnIndex(''x3'')) = 1 - beta/gam;                ║\n');
    fprintf('║  P(3, res.getColumnIndex(''x1*x2'')) = 1/gam;                    ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Compile, condition, close loop, simulate:                    ║\n');
    fprintf('║  res.compile(P);                                                 ║\n');
    fprintf('║  res.condition([1; 1; 1]);                                       ║\n');
    fprintf('║  res.close_loop();                                               ║\n');
    fprintf('║  [r_traj, y_traj] = res.evolve(10000);                           ║\n');
    fprintf('║                                                                  ║\n');
    fprintf('║  %% Plot attractor:                                              ║\n');
    fprintf('║  plot3(y_traj(1,:), y_traj(2,:), y_traj(3,:));                   ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
end
