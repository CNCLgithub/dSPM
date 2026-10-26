function printExampleDynamics(~, system)
% PRINTEXAMPLEDYNAMICS  Display example symbolic code for common systems
%
% USAGE:
%   res.printExampleDynamics('lorenz')
%   res.printExampleDynamics('vanderpol')
%   res.printExampleDynamics('harmonic')
%   res.printExampleDynamics()  % List all available
%
% Prints ready-to-copy MATLAB code for programming common dynamical systems.
    
    if nargin < 2 || isempty(system)
        fprintf('\nAvailable example systems:\n');
        fprintf('  res.printExampleDynamics(''lorenz'')     - Lorenz attractor (3D chaotic)\n');
        fprintf('  res.printExampleDynamics(''vanderpol'')  - Van der Pol oscillator (2D limit cycle)\n');
        fprintf('  res.printExampleDynamics(''harmonic'')   - Harmonic oscillator (2D linear)\n');
        fprintf('  res.printExampleDynamics(''fitzhugh'')   - FitzHugh-Nagumo (2D excitable)\n');
        fprintf('  res.printExampleDynamics(''rossler'')    - Rössler attractor (3D chaotic)\n');
        fprintf('  res.printExampleDynamics(''lotka'')      - Lotka-Volterra (2D predator-prey)\n');
        fprintf('\n');
        return;
    end
    
    fprintf('\n');
    fprintf('══════════════════════════════════════════════════════════════════\n');
    
    switch lower(system)
        case 'lorenz'
            fprintf('  LORENZ ATTRACTOR (3D chaotic)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  sigma = 10; rho = 28; beta = 8/3;\n\n');
            fprintf('  %% Create reservoir (3 recurrent inputs for x, y, z)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=3, ...\n');
            fprintf('                       B_scale=0.4, decompilation_order=3);\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 x3 real\n');
            fprintf('  dx = [sigma*(x2 - x1);\n');
            fprintf('        x1*(rho - x3) - x2;\n');
            fprintf('        x1*x2 - beta*x3];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        case 'vanderpol'
            fprintf('  VAN DER POL OSCILLATOR (2D limit cycle)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  mu = 1.0;  %% Nonlinearity strength\n\n');
            fprintf('  %% Create reservoir (2 recurrent inputs)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=2, ...\n');
            fprintf('                       decompilation_order=4);  %% needs cubic\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 real\n');
            fprintf('  dx = [x2;\n');
            fprintf('        mu*(1 - x1^2)*x2 - x1];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        case 'harmonic'
            fprintf('  HARMONIC OSCILLATOR (2D linear)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  omega = 2*pi;  %% Angular frequency\n\n');
            fprintf('  %% Create reservoir (2 recurrent inputs)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=2);\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 real\n');
            fprintf('  dx = [x2;\n');
            fprintf('        -omega^2 * x1];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        case 'fitzhugh'
            fprintf('  FITZHUGH-NAGUMO (2D excitable neuron)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  a = 0.7; b = 0.8; tau = 12.5;\n\n');
            fprintf('  %% Create reservoir (2 recurrent inputs)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=2, ...\n');
            fprintf('                       decompilation_order=4);  %% needs cubic\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 real\n');
            fprintf('  dx = [x1 - x1^3/3 - x2;\n');
            fprintf('        (x1 + a - b*x2)/tau];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        case 'rossler'
            fprintf('  RÖSSLER ATTRACTOR (3D chaotic)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  a = 0.2; b = 0.2; c = 5.7;\n\n');
            fprintf('  %% Create reservoir (3 recurrent inputs)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=3, ...\n');
            fprintf('                       decompilation_order=3);\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 x3 real\n');
            fprintf('  dx = [-x2 - x3;\n');
            fprintf('        x1 + a*x2;\n');
            fprintf('        b + x3*(x1 - c)];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        case {'lotka', 'lotkavolterra', 'lotka-volterra'}
            fprintf('  LOTKA-VOLTERRA (2D predator-prey)\n');
            fprintf('══════════════════════════════════════════════════════════════════\n\n');
            fprintf('  %% Parameters\n');
            fprintf('  alpha = 1.1; beta = 0.4; delta = 0.1; gamma = 0.4;\n\n');
            fprintf('  %% Create reservoir (2 recurrent inputs)\n');
            fprintf('  res = dspm_reservoir(100, n_recurrent_inputs=2, ...\n');
            fprintf('                       decompilation_order=3);\n\n');
            fprintf('  %% Define symbolic dynamics\n');
            fprintf('  syms x1 x2 real  %% x1=prey, x2=predator\n');
            fprintf('  dx = [alpha*x1 - beta*x1*x2;\n');
            fprintf('        delta*x1*x2 - gamma*x2];\n\n');
            fprintf('  %% Program the reservoir\n');
            fprintf('  res.program(dx)\n\n');
            
        otherwise
            fprintf('  Unknown system: %s\n', system);
            fprintf('══════════════════════════════════════════════════════════════════\n');
            fprintf('\n  Run res.printExampleDynamics() to see available systems.\n\n');
            return;
    end
    
    fprintf('══════════════════════════════════════════════════════════════════\n\n');
end
