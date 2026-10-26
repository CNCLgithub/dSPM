function programming_help(~)
% PROGRAMMING_HELP  Display guide for programming reservoir dynamics
    
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
    fprintf('║            PROGRAMMING A RESERVOIR - THREE METHODS                   ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                                                                      ║\n');
    fprintf('║  METHOD 1: Symbolic Equations (recommended for MATLAB users)         ║\n');
    fprintf('║  ─────────────────────────────────────────────────────────────────── ║\n');
    fprintf('║    syms x1 x2 x3 real                                                ║\n');
    fprintf('║    dx = [sigma*(x2-x1); rho*x1-x2-x1*x3; x1*x2-beta*x3];             ║\n');
    fprintf('║    res.program(dx)                                                   ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║    ✓ Requires Symbolic Math Toolbox                                  ║\n');
    fprintf('║    ✓ Most intuitive for dynamical systems                            ║\n');
    fprintf('║    ✓ Run res.printExampleDynamics() for templates                    ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║  METHOD 2: Load from JSON (recommended for GUI workflow)             ║\n');
    fprintf('║  ─────────────────────────────────────────────────────────────────── ║\n');
    fprintf('║    res = dspm_reservoir.load(''lorenz.json'')                          ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║    ✓ No toolbox required                                             ║\n');
    fprintf('║    ✓ Shareable, version-controllable configurations                  ║\n');
    fprintf('║    ✓ Export JSON files with res.programming_gui()                    ║\n');
    fprintf('║    ✓ For direct JSON definitions look at examples in:                ║\n');
    fprintf('║          reservoir_dc/saved-networks/presets/*/*.json                ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║  METHOD 3: Direct P Matrix (advanced users)                          ║\n');
    fprintf('║  ─────────────────────────────────────────────────────────────────── ║\n');
    fprintf('║    P = zeros(n_outputs, res.n_monomials);                            ║\n');
    fprintf('║    P(1, res.getColumnIndex(''x1'')) = 1 - sigma/(gamma);               ║\n');
    fprintf('║    P(1, res.getColumnIndex(''x2'')) = sigma/gamma;                     ║\n');
    fprintf('║    ...                                                               ║\n');
    fprintf('║    res.compile(P)                                                    ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║    ✓ Full control over DNP formula                                   ║\n');
    fprintf('║    ✓ Useful for custom/optimized implementations or debugging        ║\n');
    fprintf('║    ✓ Run res.printBasis() to see available monomials                 ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('║  DNP FORMULA: P(i,:) = yᵢ + (1/γ)·f_i(y)  where ẏᵢ = f_i(y)          ║\n');
    fprintf('║                                                                      ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('See also: program, programming_gui, compile, printExampleDynamics, printBasis\n\n');
end
