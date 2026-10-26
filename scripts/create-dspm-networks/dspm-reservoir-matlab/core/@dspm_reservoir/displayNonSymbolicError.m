function displayNonSymbolicError(obj, dx)
    % DISPLAYNONSYMBOLICERROR  Show helpful error for non-symbolic input
    
    inputType = class(dx);
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  SYMBOLIC INPUT REQUIRED                                           ║\n');
    fprintf('╠════════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  program() requires symbolic expressions. You passed: %-12s ║\n', inputType);
    fprintf('║                                                                    ║\n');
    fprintf('║  ───────────────────────────────────────────────────────────────── ║\n');
    fprintf('║  OPTION 1: Use symbolic expressions (recommended for MATLAB)       ║\n');
    fprintf('║  ───────────────────────────────────────────────────────────────── ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  Example - Lorenz attractor:                                       ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║    syms x1 x2 x3 real                                              ║\n');
    fprintf('║    sigma = 10; rho = 28; beta = 8/3;                               ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║    dx = [sigma*(x2 - x1);                                          ║\n');
    fprintf('║          x1*(rho - x3) - x2;                                       ║\n');
    fprintf('║          x1*x2 - beta*x3];                                         ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║    res.program(dx)                                                 ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  ───────────────────────────────────────────────────────────────── ║\n');
    fprintf('║  OPTION 2: Use the graphical interface (no toolbox needed)         ║\n');
    fprintf('║  ───────────────────────────────────────────────────────────────── ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║    >> res.programming_gui()                                        ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  The GUI lets you enter LaTeX equations interactively.             ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
end
