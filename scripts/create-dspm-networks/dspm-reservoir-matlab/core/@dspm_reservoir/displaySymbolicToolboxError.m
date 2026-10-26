function displaySymbolicToolboxError(obj)
    % DISPLAYSYMBOLICTOOLBOXERROR  Show helpful error for missing toolbox
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  SYMBOLIC MATH TOOLBOX NOT FOUND                                   ║\n');
    fprintf('╠════════════════════════════════════════════════════════════════════╣\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  The program() method requires the Symbolic Math Toolbox.          ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  ALTERNATIVE: Use the graphical programming interface:             ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║    >> res.programming_gui()                                        ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('║  The GUI lets you enter equations as LaTeX without needing         ║\n');
    fprintf('║  the Symbolic Toolbox.                                             ║\n');
    fprintf('║                                                                    ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
end
