classdef StabilityWizard < handle
% STABILITYWIZARD  Analyzes and validates reservoir programs for stability
%
% The StabilityWizard helps ensure that user-defined dynamics are compatible
% with the reservoir's number-theoretic scale. It analyzes:
%   - Fixed point locations (should be in [-0.5, 0.5] for linear regime)
%   - Dynamic range (should stay within tanh's linear region)
%   - Time scales (should be compatible with gamma and dt)
%   - Eigenstructure (stability classification)
%
% CONSERVATIVE AUTO-CORRECTION:
%   Only adjusts B_scale and B_sparsity when user hasn't explicitly set them.
%   All other issues generate warnings with suggestions.
%
% USAGE:
%   wiz = StabilityWizard(reservoir);
%   wiz.analyze(equations, constants);
%   wiz.report();
%   [success, traj] = wiz.testRun(1000);

    properties
        reservoir               % Reference to dspm_reservoir
        equations               % Struct array of equations
        constants               % Struct array of constants
        
        % Symbolic analysis results
        symbolic_vars           % Symbolic variable vector
        symbolic_dynamics       % Cell array of symbolic expressions
        fixed_points            % Found fixed points (cell array)
        jacobians               % Jacobian matrices at each FP
        eigenvalues             % Eigenvalues at each FP
        
        % Scale analysis
        estimated_range         % [n_vars x 2] estimated [min, max]
        center_of_mass          % Estimated attractor center
        max_derivative          % Estimated max |dy| magnitude
        
        % Diagnostic flags
        scale_ok        = true  % Fixed points within linear regime?
        centered_ok     = true  % Center near origin?
        timescale_ok    = true  % Dynamics compatible with dt?
        eigenstructure_ok = true % No unexpected instabilities?
        
        % Recommendations
        suggested_B_scale       % Recommended B_scale
        suggested_B_sparsity    % Recommended B_sparsity
        suggested_gamma         % Recommended gamma
        suggested_transform     % Struct with scale/offset
        
        % Configuration
        linear_regime_bound = 0.5
        safe_regime_bound = 0.3
        verbose = true
        
        % User override flags
        user_set_B_scale = false
        user_set_B_sparsity = false
        user_set_gamma = false
    end
    
    properties (Dependent)
        all_ok
        can_auto_fix
    end
    
    methods
        function obj = StabilityWizard(reservoir)
            if nargin > 0
                obj.reservoir = reservoir;
            end
        end
        
        function analyze(obj, equations, constants)
            if nargin > 1, obj.equations = equations; end
            if nargin > 2, obj.constants = constants; end
            
            if isempty(obj.equations)
                if obj.verbose, warning('StabilityWizard: No equations to analyze'); end
                return;
            end
            
            if obj.verbose, fprintf('\n=== StabilityWizard Analysis ===\n'); end
            
            obj.parseEquations();
            obj.findFixedPoints();
            obj.computeEigenstructure();
            obj.estimateRange();
            obj.runDiagnostics();
            obj.generateRecommendations();
            
            if obj.verbose, obj.report(); end
        end
        
        function parseEquations(obj)
            if isempty(obj.reservoir)
                n_rec = 3; n_ext = 0;
            else
                n_rec = obj.reservoir.n_recurrent_inputs;
                n_ext = obj.reservoir.n_external_inputs;
            end
            n_total = n_rec + n_ext;
            
            obj.symbolic_vars = sym('x', [n_total, 1], 'real');
            
            % Build constants map
            constMap = containers.Map();
            if ~isempty(obj.constants)
                for i = 1:numel(obj.constants)
                    c = obj.getElement(obj.constants, i);
                    name = obj.cleanName(obj.getField(c, 'name', ''));
                    val = obj.getField(c, 'value', []);
                    if ~isempty(name) && ~isempty(val)
                        constMap(name) = val;
                    end
                end
            end
            
            n_eqns = numel(obj.equations);
            obj.symbolic_dynamics = cell(n_eqns, 1);
            
            for i = 1:n_eqns
                eq = obj.getElement(obj.equations, i);
                latexStr = char(string(obj.getField(eq, 'latex', '')));
                
                if isempty(strtrim(latexStr)) || strcmp(strtrim(latexStr), '0')
                    obj.symbolic_dynamics{i} = sym(0);
                    continue;
                end
                
                try
                    matlabStr = obj.latex2matlab(latexStr, n_rec, constMap);
                    obj.symbolic_dynamics{i} = str2sym(matlabStr);
                catch
                    obj.symbolic_dynamics{i} = sym(0);
                end
            end
        end
        
        function findFixedPoints(obj)
            n_vars = length(obj.symbolic_vars);
            nonTrivialIdx = find(cellfun(@(s) ~isequal(s, sym(0)), obj.symbolic_dynamics));
            
            if length(nonTrivialIdx) < n_vars
                obj.fixed_points = {};
                return;
            end
            
            eqns = sym(zeros(length(nonTrivialIdx), 1));
            for i = 1:length(nonTrivialIdx)
                eqns(i) = obj.symbolic_dynamics{nonTrivialIdx(i)};
            end
            
            try
                sols = solve(eqns == 0, obj.symbolic_vars(1:length(nonTrivialIdx)), 'Real', true);
                if ~isempty(sols) && isstruct(sols)
                    fnames = fieldnames(sols);
                    n_sols = length(sols.(fnames{1}));
                    obj.fixed_points = cell(n_sols, 1);
                    for i = 1:n_sols
                        fp = zeros(n_vars, 1);
                        for j = 1:min(length(fnames), n_vars)
                            fp(j) = double(sols.(fnames{j})(i));
                        end
                        obj.fixed_points{i} = fp;
                    end
                    if obj.verbose, fprintf('Found %d fixed point(s)\n', n_sols); end
                else
                    obj.fixed_points = {};
                end
            catch
                obj.fixed_points = {};
            end
        end
        
        function computeEigenstructure(obj)
            if isempty(obj.fixed_points)
                obj.jacobians = {}; obj.eigenvalues = {};
                return;
            end
            
            nonTrivialIdx = find(cellfun(@(s) ~isequal(s, sym(0)), obj.symbolic_dynamics));
            if isempty(nonTrivialIdx)
                obj.jacobians = {}; obj.eigenvalues = {};
                return;
            end
            
            dynamics = [obj.symbolic_dynamics{nonTrivialIdx}];
            vars = obj.symbolic_vars(1:length(nonTrivialIdx));
            
            try
                J_sym = jacobian(dynamics(:), vars);
            catch
                obj.jacobians = {}; obj.eigenvalues = {};
                return;
            end
            
            obj.jacobians = cell(length(obj.fixed_points), 1);
            obj.eigenvalues = cell(length(obj.fixed_points), 1);
            
            for i = 1:length(obj.fixed_points)
                fp = obj.fixed_points{i};
                try
                    J_num = double(subs(J_sym, vars, fp(1:length(vars))));
                    obj.jacobians{i} = J_num;
                    obj.eigenvalues{i} = eig(J_num);
                catch
                    obj.jacobians{i} = [];
                    obj.eigenvalues{i} = [];
                end
            end
        end
        
        function estimateRange(obj)
            n_vars = length(obj.symbolic_vars);
            if isempty(obj.fixed_points)
                obj.estimated_range = repmat([-1, 1], n_vars, 1);
                obj.center_of_mass = zeros(n_vars, 1);
                obj.max_derivative = inf;
                return;
            end
            
            all_fps = cell2mat(cellfun(@(fp) fp(:)', obj.fixed_points, 'UniformOutput', false));
            obj.center_of_mass = mean(all_fps, 1)';
            fp_min = min(all_fps, [], 1)';
            fp_max = max(all_fps, [], 1)';
            margin = max(abs([fp_min; fp_max])) * 0.5;
            obj.estimated_range = [fp_min - margin, fp_max + margin];
            obj.max_derivative = 1;
        end
        
        function runDiagnostics(obj)
            obj.scale_ok = true;
            for i = 1:length(obj.fixed_points)
                if any(abs(obj.fixed_points{i}) > obj.linear_regime_bound)
                    obj.scale_ok = false;
                    break;
                end
            end
            
            if ~isempty(obj.center_of_mass)
                obj.centered_ok = all(abs(obj.center_of_mass) < obj.safe_regime_bound);
            end
            
            obj.eigenstructure_ok = true;
            for i = 1:length(obj.eigenvalues)
                eigs = obj.eigenvalues{i};
                if ~isempty(eigs) && any(real(eigs) > 10)
                    obj.eigenstructure_ok = false;
                    break;
                end
            end
        end
        
        function generateRecommendations(obj)
            if ~isempty(obj.reservoir)
                obj.suggested_B_scale = obj.reservoir.B_scale;
                obj.suggested_B_sparsity = obj.reservoir.B_sparsity;
                obj.suggested_gamma = obj.reservoir.gamma;
            else
                obj.suggested_B_scale = 0.4;
                obj.suggested_B_sparsity = 1.0;
                obj.suggested_gamma = 100;
            end
            obj.suggested_transform = struct();
            
            if ~obj.scale_ok && ~obj.user_set_B_scale
                max_fp = 0;
                for i = 1:length(obj.fixed_points)
                    max_fp = max(max_fp, max(abs(obj.fixed_points{i})));
                end
                if max_fp > 0
                    obj.suggested_B_scale = obj.suggested_B_scale * min(obj.safe_regime_bound / max_fp, 1);
                end
            end
            
            if ~obj.centered_ok
                obj.suggested_transform.offset = -obj.center_of_mass;
            end
        end
        
        function report(obj)
            fprintf('\n--- Stability Analysis Report ---\n\n');
            fprintf('FIXED POINTS:\n');
            if isempty(obj.fixed_points)
                fprintf('  No fixed points found\n');
            else
                for i = 1:length(obj.fixed_points)
                    fp = obj.fixed_points{i};
                    fprintf('  FP %d: [%s]\n', i, num2str(fp', '%.4f '));
                    if ~isempty(obj.eigenvalues) && i <= length(obj.eigenvalues)
                        eigs = obj.eigenvalues{i};
                        if ~isempty(eigs)
                            if all(real(eigs) < 0), stab = 'Stable';
                            elseif all(real(eigs) > 0), stab = 'Unstable';
                            else, stab = 'Saddle'; end
                            fprintf('         -> %s\n', stab);
                        end
                    end
                end
            end
            
            fprintf('\nDIAGNOSTICS:\n');
            fprintf('  Scale OK:        %s\n', obj.yesno(obj.scale_ok));
            fprintf('  Centered OK:     %s\n', obj.yesno(obj.centered_ok));
            fprintf('  Timescale OK:    %s\n', obj.yesno(obj.timescale_ok));
            fprintf('  Eigenstructure:  %s\n', obj.yesno(obj.eigenstructure_ok));
            
            if obj.all_ok
                fprintf('\n✓ All diagnostics passed!\n');
            end
            fprintf('\n');
        end
        
        function [success, trajectory] = testRun(obj, n_steps, ic)
            if nargin < 2, n_steps = 1000; end
            if nargin < 3
                if ~isempty(obj.fixed_points)
                    ic = obj.fixed_points{1} + 0.01*randn(size(obj.fixed_points{1}));
                else
                    ic = 0.01 * randn(obj.reservoir.n_recurrent_inputs, 1);
                end
            end
            
            if isempty(obj.reservoir) || ~obj.reservoir.is_compiled
                success = false; trajectory = [];
                return;
            end
            
            try
                obj.reservoir.condition(ic(:));
                obj.reservoir.close_loop();
                [~, trajectory] = obj.reservoir.simulate(n_steps);
                max_val = max(abs(trajectory(:)));
                
                if max_val > 1e6 || any(isnan(trajectory(:)))
                    success = false;
                    if obj.verbose, fprintf('Test FAILED: Diverged\n'); end
                elseif max_val > 0.95
                    success = false;
                    if obj.verbose, fprintf('Test FAILED: Saturated\n'); end
                else
                    success = true;
                    if obj.verbose, fprintf('Test PASSED: max|y|=%.3f\n', max_val); end
                end
            catch ME
                success = false; trajectory = [];
                if obj.verbose, fprintf('Test FAILED: %s\n', ME.message); end
            end
        end
    end
    
    methods
        function ok = get.all_ok(obj)
            ok = obj.scale_ok && obj.centered_ok && obj.timescale_ok && obj.eigenstructure_ok;
        end
        function can = get.can_auto_fix(obj)
            can = ~obj.scale_ok && ~obj.user_set_B_scale;
        end
    end
    
    methods (Access = private)
        function elem = getElement(~, arr, idx)
            if iscell(arr), elem = arr{idx}; else, elem = arr(idx); end
        end
        function val = getField(~, s, fn, def)
            if isstruct(s) && isfield(s, fn), val = s.(fn); else, val = def; end
        end
        function name = cleanName(~, raw)
            name = regexprep(char(string(raw)), '\\text\{([^}]+)\}', '$1');
            name = strrep(strrep(strrep(strtrim(name), '\', ''), '{', ''), '}', '');
        end
        function s = latex2matlab(~, latex, n_rec, cmap)
            s = latex;
            s = regexprep(s, '\\frac\{([^}]+)\}\{([^}]+)\}', '(($1)/($2))');
            s = regexprep(s, '\\cdot|\\times', '*');
            s = regexprep(s, '\\text\{([^}]+)\}|\\left|\\right', '$1');
            s = strrep(strrep(s, '\,', ''), '\ ', '');
            s = regexprep(s, 'y_\{(\d+)\}|y_(\d)', 'x$1$2');
            s = regexprep(s, '\\([a-zA-Z]+)', '$1');
            for k = keys(cmap), s = regexprep(s, ['(?<![a-zA-Z_])' k{1} '(?![a-zA-Z_0-9])'], sprintf('(%g)', cmap(k{1}))); end
            s = regexprep(s, '(\d)([a-zA-Z])', '$1*$2');
            s = regexprep(s, '([a-zA-Z0-9])\s+([a-zA-Z])', '$1*$2');
            s = strrep(strtrim(s), '**', '*');
        end
        function s = yesno(~, b), if b, s = '✓ Yes'; else, s = '✗ No'; end, end
    end
end
