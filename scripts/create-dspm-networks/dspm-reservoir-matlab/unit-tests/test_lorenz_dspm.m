% TEST_LORENZ_DSPM  Program and run Lorenz attractor using dspm_reservoir
%
% Uses the SCALED Lorenz dynamics from Jason Kim's code (code_virtualize.m):
%   
% -----------------------------------------------------
% SCALED LORENZ DYNAMICS:
%   scv = 200 (scaling factor)
%   f1  = sigma * (y2 - y1) / 10
%   f2  = (y1 * (rho - (scv*y3 + 27)) - y2) / 10
%       = (y1 - y2 - scv*y1*y3) / 10   [since rho-27 = 1]
%   f3  = (scv*y1*y2 - beta*(y3 + 27/scv)) / 10
%
% DNP formula: P(i,:) = y_i + (1/γ)*f_i(y)
% -----------------------------------------------------
%
% This keeps the dynamics in a smaller range (~0.1) which works better
% with the tanh nonlinearity and the spectral properties of the network
% adjacency.
%
% NO external dependencies - just dspm_reservoir.

clear; clc; close all
%% Parameters

scale = 200;
sigma = 10;
rho   = 28;
beta  = 8/3;

N     = 50;    % neurons
gamma = 100;    % time constant
dt    = 0.01;   % integration time step 

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  SCALED LORENZ ATTRACTOR TEST - dspm_reservoir\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('Scaled Lorenz: scale=%d, σ=%.1f, ρ=%.1f, β=%.4f\n', scale, sigma, rho, beta);
fprintf('Reservoir: N=%d, γ=%.1f, dt=%.4f\n\n', N, gamma, dt);

%% Step 1: Create reservoir(s)
fprintf('Step 1: Creating reservoir...\n');

res_prog = dspm_reservoir( ...
    'n_neurons',N, ...
    'B_scale',0.2,...
    'B_sparsity',0.7,...
    'n_recurrent_inputs', 3, ...   % y1, y2, y3 will be feedback
    'n_external_inputs', 0, ...    % no external forcing
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...            % just positions, no velocities
    'decompilation_order', 3, ...  % MATLAB taylor() needs order=3 to get degree-2 terms!
    'verbose', false);

res_byHand = dspm_reservoir( ...
    'n_neurons',N, ...
    'B_scale',0.2,...
    'B_sparsity',0.7,...
    'n_recurrent_inputs', 3, ...   % y1, y2, y3 will be feedback
    'n_external_inputs', 0, ...    % no external forcing
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...            % just positions, no velocities
    'decompilation_order', 3, ...  % MATLAB taylor() needs order=3 to get degree-2 terms!
    'decompile', 'eager', ...      % hand-built P below needs the basis up front
    'verbose', false);


fprintf('Loading Lorenz from JSON...\n');
netFile  = "saved-networks/presets/attractors/lorenz_scaled.json";
res_load = dspm_reservoir.load(netFile, ...
    'n_neurons',N, ...
    'B_scale',0.2,...
    'B_sparsity',0.7,...
    'n_recurrent_inputs', 3, ...   % y1, y2, y3 will be feedback
    'n_external_inputs', 0, ...    % no external forcing
    'gamma', gamma, ...
    'dt', dt, ...
    'jet_order', 1, ...            % just positions, no velocities
    'decompilation_order', 3, ...  % MATLAB taylor() needs order=3 to get degree-2 terms!
    'verbose', false);


fprintf('  ✓ Created %d-neuron reservoir\n', N);
fprintf('  ✓ R matrix: %d × %d\n', size(res_prog.R, 1), size(res_prog.R, 2));
fprintf('  ✓ Monomials: %d\n\n', res_prog.n_monomials);

%% Step 2: Inspect the basis
fprintf('Step 2: Basis structure...\n');
res_prog.printBasis(15);
fprintf('\n');

%% Step 3.1: Build program matrix P with symbolic equations

syms x1 x2 x3 real
dx = [
    sigma*(x2 - x1)
    x1 - x2 - scale*x1*x3
    scale*x1*x2 - beta*(x3 + (27/scale) )
    ]/10;

res_prog.program(dx);


%% Step 3.2: Build program matrix P by hand and compile directly

P = programReservoirByHand(res_byHand,sigma,rho,beta,scale);

% Compile
fprintf('Step 3.3: Compiling Hand programmed P → W ...\n');

[residual, rank_R, stats] = res_byHand.compile(P);

fprintf('  ✓ Compiled\n');
fprintf('    Residual: %.2e\n', residual);
fprintf('    Relative error: %.2f%%\n', stats.rel_error * 100);
fprintf('    Rank(R): %d / %d\n', rank_R, res_prog.n_monomials);
fprintf('\n');

%% Step 6: Close loop 
fprintf('Step 7: Closing loop ...\n');

% Close the feedback loop
A_tilde = res_byHand.close_loop();

fprintf('  ✓ Loop closed\n');
fprintf('    ||Ã||_F = %.4f\n', norm(A_tilde, 'fro'));
fprintf('    Spectral radius: %.4f\n', max(abs(eig(A_tilde))));

res_prog.close_loop();
res_load.close_loop();

%% Step 4: Generate ground truth (scaled Lorenz)
fprintf('Step 5: Generating ground truth (scaled Lorenz)...\n');

% Scaled Lorenz ODE (matching Jason's LorenzZs)
scaled_lorenz = @(t, y) [
    sigma * (y(2) - y(1));
    y(1) * (rho - (scale*y(3) + 27)) - y(2);
    scale * y(1) * y(2) - beta * (y(3) + 27/scale)
] / 10;

% In scaled coordinates, typical values are [-0.4 , +0.4]
y0 = randn(3,1)*0.3;% y1, y2, y3

% Generate trajectory
T_sim = 10000*dt;  % seconds total
[t_ode, y_ode] = ode45(scaled_lorenz, [0, T_sim], y0, odeset('MaxStep', dt));

% Interpolate to fixed dt grid
t_grid  = (0:dt:T_sim)';
y_truth = interp1(t_ode, y_ode, t_grid)';

fprintf('  ✓ Ground truth: %d time steps\n', size(y_truth, 2));
fprintf('  ✓ y0 = [%.4f, %.4f, %.4f]\n', y0(1), y0(2), y0(3));
fprintf('  ✓ Range: y1∈[%.3f,%.3f], y2∈[%.3f,%.3f], y3∈[%.3f,%.3f]\n', ...
    min(y_truth(1,:)), max(y_truth(1,:)), ...
    min(y_truth(2,:)), max(y_truth(2,:)), ...
    min(y_truth(3,:)), max(y_truth(3,:)));
fprintf('\n');

%%

fnorm = @(r1,r2) norm(r1.compiled_program_matrix' ...
                - r2.compiled_program_matrix');

fprint = @(n1,n2,x) fprintf("programming error between %s and %s: %f\n",n1,n2,x);

fprint("symbolic","loaded",fnorm(res_prog,res_load))
fprint("symbolic","hand coded",fnorm(res_prog,res_byHand))
fprint("hand coded","loaded",fnorm(res_load,res_byHand))

% printMatrix(res_prog.compiled_program_matrix)
% printMatrix(res_load.compiled_program_matrix)
% printMatrix(res_byHand.compiled_program_matrix)

%%

% Condition r0 initial state by running open loop with input y0
res_prog.condition(y0);
res_load.condition(y0);
res_byHand.condition(y0);

tsim = 10000;

y_truth = y_truth(:,1:tsim);

fprintf('\n=== Running Simulations ===\n');

res_array = [res_prog , res_load , res_byHand]';
netlbls = ["program(dx)" , "load(JSON)" , "hand coded"]';
lbls = "Ready to run from "+netlbls+": %s\n";
sim_results = cell(numel(res_array),1);

for i = 1:numel(res_array)
    fprintf(lbls(i), mat2str(res_array(i).ready_to_run));
    if res_array(i).ready_to_run
        [~,y] = res_array(i).simulate(tsim);
        
        sim_results{i} = y;
        fprintf('Trajectory size: %d timesteps\n', size(y, 2));
        fprintf('\t y1 range: [%.4f, %.4f]\n', min(y(1,:)), max(y(1,:)));
        fprintf('\t y2 range: [%.4f, %.4f]\n', min(y(2,:)), max(y(2,:)));
        fprintf('\t y3 range: [%.4f, %.4f]\n', min(y(3,:)), max(y(3,:)));
    end
end


%% Plot Trajectories

pats = findall(0,"-depth",3,'tag','lorenz_dspm');
if isempty(pats),figure("Name","lorenz");ax = gca;hold(ax,"on"),
else, delete(pats), end


nets_output = [{y_truth};sim_results];
lbls = ["ground truth";netlbls];

huevalues = [0 60 180 300]/360;
satvalues = [0 0 ; 1 .6 ; 1 .6 ; 1 .6];
valvalues = satvalues(:,[2,1]);

for i = 1:numel(nets_output)
    v      = nets_output{i}';
    f      = 1:tsim;
    v(end,:) = nan;
    
    hues = ones(tsim,1)*huevalues(i);
    sats = linspace(satvalues(i,1),satvalues(i,2) , tsim)';
    vals = linspace(valvalues(i,1),valvalues(i,2) , tsim)';
    
    clr   = hsv2rgb([hues sats vals]);
       
    patch(ax,'Faces',f,'Vertices',v,...
        'FaceColor','none','FaceVertexCData',clr, ...
        'FaceVertexAlphaData',1,'AlphaDataMapping','none',...
        'FaceAlpha','flat','EdgeAlpha','flat','EdgeColor','flat',...
        'LineWidth',2,'tag','partial','tag','lorenz_dspm');
    
end

view(ax,3)
xlabel(ax,'y_1'); ylabel(ax,'y_2'); zlabel(ax,'y_3');
title(ax,"Lorenz Attractor (Scaled)" + newline + ...
    "time: $[0\rightarrow t]$ :: [dark $\rightarrow$ light]",...
    'Interpreter','latex');
xlim(ax,[-1 1]*.5)
ylim(ax,[-1 1]*.5)
zlim(ax,[-1 1]*.5)
grid(ax, "on");
legend(ax,lbls)


%% Hand Programming function

function P = programReservoirByHand(res_byHand,sigma,rho,beta,scv)
    fprintf('\t Building program matrix P by hand ...\n\n');
    
    % Get column indices for the terms we need
    idx_const = res_byHand.getColumnIndex('1');       % constant term
    idx_y1    = res_byHand.getColumnIndex('x1');      % y₁
    idx_y2    = res_byHand.getColumnIndex('x2');      % y₂
    idx_y3    = res_byHand.getColumnIndex('x3');      % y₃
    idx_y1y2  = res_byHand.getColumnIndex('x1*x2');   % y₁y₂
    idx_y1y3  = res_byHand.getColumnIndex('x1*x3');   % y₁y₃
    
    fprintf('  Column indices:\n');
    fprintf('    1    → col %d\n', idx_const);
    fprintf('    y₁   → col %d\n', idx_y1);
    fprintf('    y₂   → col %d\n', idx_y2);
    fprintf('    y₃   → col %d\n', idx_y3);
    fprintf('    y₁y₂ → col %d\n', idx_y1y2);
    fprintf('    y₁y₃ → col %d\n', idx_y1y3);
    fprintf('\n');
    
    % Check we have quadratic terms
    if isempty(idx_y1y2) || isempty(idx_y1y3)
        error('Missing quadratic terms! Need decompilation_order >= 3');
    end
    
    gamma = res_byHand.gamma;
    % Initialize P (3 outputs × n_monomials)
    P = zeros(3, res_byHand.n_monomials);
    
    % Row 1: y₁ + (1/γ)*f₁ = y₁ + (σ/10γ)*(y₂ - y₁)
    %      = (1 - σ/(10γ))*y₁ + (σ/(10γ))*y₂
    P(1, idx_y1) = 1 - sigma/(10*gamma);
    P(1, idx_y2) = sigma/(10*gamma);
    
    % Row 2: y₂ + (1/γ)*f₂ = y₂ + (1/(10γ))*(y₁ - y₂ - scv*y₁*y₃)
    %      = (1/(10γ))*y₁ + (1 - 1/(10γ))*y₂ - (scv/(10γ))*y₁y₃
    P(2, idx_y1)   = (rho - 27)/(10*gamma);  % = 1/(10*100) = 0.001
    P(2, idx_y2)   = 1 - 1/(10*gamma);       % = 1 - 0.001 = 0.999
    P(2, idx_y1y3) = -scv/(10*gamma);        % = -200/(10*100) = -0.2
    
    % Row 3: y₃ + (1/γ)*f₃ = y₃ + (1/(10γ))*(scv*y₁y₂ - β*y₃ - 27β/scv)
    %      = const + (scv/(10γ))*y₁y₂ + (1 - β/(10γ))*y₃
    P(3, idx_const) = -27*beta/(scv*10*gamma);  % constant offset
    P(3, idx_y3)    = 1 - beta/(10*gamma);
    P(3, idx_y1y2)  = scv/(10*gamma);           % = 200/(10*100) = 0.2
    
    fprintf('  Program matrix P (non-zero entries):\n');
    for row = 1:3
        nz = find(abs(P(row,:)) > 1e-10);
        fprintf('    Row %d: ', row);
        for j = nz
            fprintf('P(%d,%d)=%.6f  ', row, j, P(row,j));
        end
        fprintf('\n');
    end
    fprintf('\n');


end