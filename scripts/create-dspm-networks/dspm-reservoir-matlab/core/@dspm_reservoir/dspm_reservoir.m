classdef dspm_reservoir < matlab.mixin.Copyable & handle
% DSPM_RESERVOIR  Dynamical reservoir for structure-preserving manifold computing
%
% One machine, one equation, at every lifecycle stage:
%
%     (1/γ) ṙ = -r + tanh( A·r + B·x + d )
%
% with the fixed-point identity as the class invariant:
%
%     d⋆ = arctanh(r⋆) − A·r⋆ − B·x₀
%
% Stages differ only in the (A, B, d) tuple:
%   open/fresh  : A = A₀ (usually empty ⟹ 0),  B = [B̃ B̅ B̂]  (all ports live)
%   programmed  : A = A₀ + B̃W,                 B = [B̅ B̂]     (rec ports bound)
%   composite   : A = A꜀ block matrix,          B = blkdiag(B̂ₖ)   (Phase 2)
%
% PORTS — every input channel has a role:
%   "recurrent"  (x̃) consumed by programming: A ← A₀ + B̃W
%   "exogenous"  (x̅) reserved for other reservoirs (composition surface)
%   "external"   (x̂) true world input; survives composition
%
% TWO FACTORIES:
%   res = dspm_reservoir(500, ports=["rec","rec","exo"], gamma=100)   % generative
%   res = dspm_reservoir.from_matrices(A=A, B=B, W=W, r_star=rs, ...) % declarative
%
% Old-style construction still works:
%   res = dspm_reservoir(n_neurons=500, n_recurrent_inputs=3, n_external_inputs=0)
%
% HAPPY PATH (one verb — program() decompiles lazily and closes the loop):
%   syms x1 x2 x3 real
%   res = dspm_reservoir(500, ports=["rec","rec","rec"]);
%   res.program([10*(x2-x1); x1*(28-x3)-x2; x1*x2-(8/3)*x3]);
%   res.condition(y0);
%   [r, y] = res.simulate(1e4);
%
% STATUS is derived from data, never stored: res.status() / disp(res).
% There are no pipeline flags to desync; setters clear downstream data only,
% and nothing recomputes until program()/simulate() need it.
%
% See also: from_matrices, program, decompile, compile, close_loop, condition,
%           simulate, status, capabilities, printBasis, getColumnIndex

%% ======================================================================
%  CONFIGURATION
%  ======================================================================
    properties (SetObservable)
        n_neurons                       % (N) number of reservoir units
        gamma       (1,1) double = 100  % time constant (τ = 1/γ)
        dt          (1,1) double = 0.01 % integration step
        integrator  (1,1) string = "rk4"  % {"euler","rk4"}
        equilibrate (1,1) logical = false  % scale monomial columns of R to unit norm before solving for W

        % generative-factory hyperparameters
        B_scale     = 0.4
        B_sparsity  = 1.0
        random_seed = 0

        % readout row split (m̃ feedback rows ; observation rows)
        n_recurrent_outputs = []
        n_external_outputs  = 0

        % metadata
        network_name        = ''
        network_description = ''
        source_filepath     = ''
        verbose     (1,1) logical = true
    end

%% ======================================================================
%  PORTS, PROVENANCE, MODULES
%  ======================================================================
    properties (SetAccess = protected)
        % Port table: one row per input channel (column of B).
        % Fields: id (immutable ascii), label (display, math symbol),
        %         role ("recurrent"|"exogenous"|"external"), x0 (expansion
        %         point), bound (true once consumed by close_loop / binding),
        %         aliases (string array of user names).
        ports = struct('id',{},'label',{},'role',{},'x0',{},'bound',{},'aliases',{})

        % Provenance — what close_loop() retains so closure is reversible and
        % condition() can integrate the pre-closure tuple.
        %   tier: "full" | "seed" | "none"
        provenance = struct('tier',"none",'A0',[],'seed',[], ...
                            'generator_version',"dspm-gen-1",'hyperparams',struct())

        % Composition metadata tree (Phase 2). Empty for a plain reservoir.
        modules = []
    end

%% ======================================================================
%  PIPELINE ARTIFACTS  (presence of these IS the status — no flags)
%  ======================================================================
    properties (SetAccess = protected)
        decompiled_weight_matrix        % (N×K) R̂
        n_monomials
        n_symbolic_vars
        symbolic_basis_mapping
        symbolic_basis_strings
        physical_basis_strings
        cached_basis

        compiled_program_matrix         % (m̃×K) P̂ from last compile()

        source_equations                % from loadProgram()/GUI
        source_constants
    end

%% ======================================================================
%  SIMULATION STATE
%  ======================================================================
    properties
        r                               % (N×1) current state
    end

%% ======================================================================
%  PRIVATE BACKING
%  ======================================================================
    properties (Access = private)
        A_          % (N×N) live adjacency (empty ⟹ 0, open loop)
        B_          % (N×m) full read-in (all ports, incl. bound columns)
        W_          % (m_out×N) readout
        r_star_     % (N×1)
        d_star_     % (N×1) identity-consistent bias (tanh's d)
        r0_         % (N×1) conditioned initial state
        jet_order_           = 2
        decompilation_order_ = 3
        ports_infer_ = false     % ports="infer": provision at first program()
    end

%% ======================================================================
%  SYMBOLIC CACHE (read/written by jet_expansion_/eval_coefficients_ etc.)
%  ======================================================================
    properties (Hidden)
        jet_cache_valid_    = false
        taylor_cache_valid_ = false
        symbolic_jet_equation_
        symbolic_taylor_coefficients_
        symbolic_taylor_basis_
    end

%% ======================================================================
%  CANONICAL TUPLE (Dependent — setters clear downstream data, never compute)
%  ======================================================================
    properties (Dependent)
        A               % live adjacency (empty ⟹ open / A=0)
        B               % (N×m) full read-in
        W               % (m_out×N) readout
        r_star          % (N×1) operating point
        d_star          % (N×1) bias d (identity-consistent)
        x_star          % (m×1) expansion point, assembled from ports.x0
        jet_order
        decompilation_order
        r0
    end

    properties (Dependent, SetAccess = private)
        n_inputs                % m = numel(ports)
        n_outputs
        n_recurrent_inputs      % m̃
        n_exogenous_inputs      % m̅
        n_external_inputs       % legacy meaning: everything non-recurrent (m̅+m̂)
        live_input_width        % # unbound ports (what step()/simulate() expect)
        is_initialized
    end

%% ======================================================================
%  LEGACY ALIASES (Hidden; one deprecation cycle)
%  ======================================================================
    properties (Hidden, Dependent)
        read_in_matrix_B
        read_in_matrix_recurrent
        read_in_matrix_external
        read_out_matrix_W
        read_out_matrix_recurrent
        read_out_matrix_external
        programmed_adjacency
        bias                    % = d_star (the d used by the decompiler)
        x_recurrent_star
        x_external_star
        expansion_point
        recurrent_input_indices
        external_input_indices
        recurrent_output_indices
        external_output_indices
        % legacy pipeline flags — READ-ONLY, derived live from data
        is_decompiled
        is_compiled
        is_closed
        is_conditioned
        ready_to_run
        % path inference (used by programming_gui / save)
        classpath
        rootpath
        prog_gui_path
        save_path
    end

%% ======================================================================
%  CONSTRUCTOR (generative factory)
%  ======================================================================
    methods
        function obj = dspm_reservoir(n_neurons_pos, options)
            % DSPM_RESERVOIR  Generative factory (random substrate).
            %
            %   res = dspm_reservoir(500, ports=["rec","rec","exo"], gamma=300)
            %   res = dspm_reservoir(n_neurons=500, n_recurrent_inputs=3)
            %   res = dspm_reservoir(500, ports="infer")   % m̃ set by program(dx)
            %
            % decompile="lazy" (default) defers symbolic work to the first
            % program(); decompile="eager" reproduces the old constructor
            % behavior. For hand-built matrices use dspm_reservoir.from_matrices.
            arguments
                n_neurons_pos (1,1) double = NaN
                options.n_neurons (1,1) double = NaN
                options.ports string = string.empty
                options.port_names string = string.empty
                options.n_recurrent_inputs (1,1) double = NaN
                options.n_external_inputs (1,1) double {mustBeNonnegative, mustBeInteger} = 0
                options.n_recurrent_outputs (1,1) double = NaN
                options.n_external_outputs (1,1) double {mustBeNonnegative, mustBeInteger} = 0
                options.gamma (1,1) double {mustBePositive} = 100
                options.dt (1,1) double {mustBePositive} = 0.01
                options.equilibrate (1,1) logical = false
                options.integrator (1,1) string {mustBeMember(options.integrator,["euler","rk4"])} = "rk4"
                options.B_scale (1,1) double {mustBePositive} = 0.4
                options.B_sparsity (1,1) double = 1.0
                options.r_star (:,1) double = []
                options.x_star (:,1) double = []
                options.random_seed (1,1) double {mustBeNonnegative, mustBeInteger} = 0
                options.jet_order (1,1) double {mustBePositive, mustBeInteger} = 2
                options.decompilation_order (1,1) double {mustBePositive, mustBeInteger} = 3
                options.read_in_matrix (:,:) double = []
                options.read_out_matrix (:,:) double = []
                options.decompile (1,1) string {mustBeMember(options.decompile,["lazy","eager"])} = "lazy"
                options.initialize (1,1) logical = true
                options.verbose (1,1) logical = true
            end

            % merge optional leading positional N
            if ~isnan(n_neurons_pos), options.n_neurons = n_neurons_pos; end

            % empty constructor (internal use by factories)
            if isnan(options.n_neurons), return, end

            obj.build_from_options_(options);
        end
    end

%% ======================================================================
%  STATIC FACTORIES (external files) + STATIC HELPERS (extracted verbatim)
%  ======================================================================
    methods (Static)
        obj = from_matrices(options)
        obj = load(filepath, options)
        obj = fromStruct(config, options)
        p = parseJSONConfig(config)
        latexStr = basisToLatex(basisStr)
        term = formatCoeffTerm(w, basisLatex, precision, isFirst)
        path = filepartsR(path,depth)
        normalized = normalizeTermString(term_str)
    end

%% ======================================================================
%  PIPELINE — decompile / compile / program / close_loop
%  ======================================================================
    methods
        function [R, basis] = decompile(obj)
            % DECOMPILE  Symbolic Taylor/jet decompilation → R̂ and basis.
            % Cached three-tier machinery (jet → Taylor → eval) unchanged.
            if ~obj.is_initialized
                error('dspm_reservoir:notInitialized', ...
                    'Network not initialized (need B, r_star, ports). Cannot decompile.');
            end
            if obj.verbose
                fprintf("Decompiling Reservoir (jet order %d , decompilation order %d) ...\n", ...
                    obj.jet_order, obj.decompilation_order);
                tic
            end

            try
                [sortedBasis, decompWeights, sortIdx, basisMapping] = decompile_reservoir(obj);
            catch ME
                if contains(ME.message, "Unrecognized function or variable 'y")
                    error('dspm_reservoir:stageVersionMismatch', ...
                        ['Decompilation stages disagree about the jet variable count ' ...
                         '(a coefficient references a y-variable the basis never substituted). ' ...
                         'This almost always means shadowed helper versions on your path ' ...
                         '(e.g. a sandbox/archive copy of jet_expansion_ using jet_order+1). ' ...
                         'Run:  which jet_expansion_ -all ;  which polynomial_basis_expansion_ -all\n' ...
                         'and keep only core/ versions on the path. Original error: %s'], ME.message);
                end
                rethrow(ME);
            end

            nyvars            = obj.jet_order * obj.n_inputs;
            basis.sortIdx     = sortIdx;
            basis.n_monomials = numel(sortedBasis);
            basis.nyvars      = nyvars;
            basis.k_rec       = obj.n_recurrent_inputs;
            basis.k_ext       = obj.n_inputs - obj.n_recurrent_inputs;
            basis.jet_order   = obj.jet_order;
            basis.poly_order  = obj.decompilation_order;
            basis.sortedBasis = sortedBasis;

            R = decompWeights;
            obj.decompiled_weight_matrix = R;
            obj.cached_basis             = basis;
            obj.symbolic_basis_mapping   = basisMapping;
            obj.symbolic_basis_strings   = sortedBasis;
            obj.physical_basis_strings   = basisMapping.Physical;
            obj.n_monomials              = basis.n_monomials;
            obj.n_symbolic_vars          = nyvars;

            if obj.verbose
                fprintf('Decompilation complete: R is %d × %d\n', size(R,1), size(R,2));
                toc
            end
        end

        function [residual, rank_R, stats] = compile(obj, P)

            % COMPILE  Solve W̃ = argmin ‖W̃R − P‖^2 (lsqminnorm).
            if isempty(obj.decompiled_weight_matrix)
                error('dspm_reservoir:notDecompiled', ...
                    'No R matrix. Call decompile() first (program() does this automatically).');
            end
            R = obj.decompiled_weight_matrix;

            % Optional: scale every monomial column of R (and of P) to unit norm.
            % The equations W̃R = P are unchanged, so the exact solution is the same;
            % only which columns the solver treats as numerically zero changes.
            if obj.equilibrate
                cs = vecnorm(R, 2, 1);
                cs(cs == 0) = 1;                 % leave an all-zero column alone
            else
                cs = ones(1, size(R, 2));
            end
            Rs = R ./ cs;                        % the matrix actually solved
            Ps = P ./ cs;

            obj.read_out_matrix_recurrent = lsqminnorm(Rs', Ps')';

            residual = norm(obj.read_out_matrix_recurrent * R - P, 'fro');
            rank_R   = rank(Rs);
            [~, S, ~] = svd(Rs', 'econ');
            sv = diag(S);

            stats.residual    = residual;
            stats.rel_error   = residual / norm(P, 'fro');
            stats.rank_R      = rank_R;
            stats.cond_R      = sv(1) / sv(max(rank_R, 1));
            stats.equilibrate = obj.equilibrate;
            stats.n_neurons   = obj.n_neurons;
            stats.n_monomials = size(R, 2);

            if stats.rel_error > 0.1
                warning('compile: High relative error (%.1f%%)', stats.rel_error * 100);
            end
            obj.compiled_program_matrix = P;
            if obj.verbose
                fprintf('Compiled: residual=%.2e, rel_error=%.2f%%, rank=%d/%d\n', ...
                    residual, stats.rel_error*100, rank_R, size(R, 2));
            end

        end

        function stats = program(obj, dx, options)
            % PROGRAM  One-verb happy path: signature check → decompile (lazy)
            % → P̂ → compile → close_loop. Symbolic dx only.
            arguments
                obj
                dx
                options.tau (:,1) double = []
                options.constants struct = struct()
                options.vars (:,1) sym = sym([])
            end

            if ~obj.hasSymbolicToolbox()
                obj.displaySymbolicToolboxError();
                error('dspm_reservoir:noSymbolicToolbox', ...
                    'Symbolic Math Toolbox is required for program(). Use the GUI instead.');
            end
            if ~isa(dx, 'sym')
                obj.displayNonSymbolicError(dx);
                error('dspm_reservoir:notSymbolic', ...
                    'Input must be symbolic. See the example above or use res.programming_gui()');
            end

            dx   = dx(:);
            eqns = numel(dx);

            % ---- signature: m̃ is dictated by the target -------------------
            if obj.ports_infer_
                obj.provision_ports_(eqns);
            end
            expected = obj.n_recurrent_outputs + obj.n_external_outputs;
            if eqns ~= expected
                error('dspm_reservoir:dimensionMismatch', ...
                    ['Program declares %d equations but reservoir expects %d ' ...
                     '(n_recurrent_outputs=%d + n_external_outputs=%d). ' ...
                     'The recurrent port count m\x0303 and the target''s state-variable ' ...
                     'count are the same integer.'], ...
                    eqns, expected, obj.n_recurrent_outputs, obj.n_external_outputs);
            end

            % ---- lazy decompile ------------------------------------------
            if isempty(obj.decompiled_weight_matrix)
                obj.decompile();
            end

            % ---- tau ------------------------------------------------------
            if isempty(options.tau), tau = ones(eqns, 1);
            else
                tau = options.tau(:);
                if numel(tau) ~= eqns
                    error('dspm_reservoir:tauMismatch', ...
                        'tau length (%d) must match number of outputs (%d)', numel(tau), eqns);
                end
            end

            % ---- P̂, W, closure -------------------------------------------
            [P, sourceEqs, sourceConsts] = obj.buildProgramMatrixSymbolic(dx, tau, options.constants, options.vars);
            obj.source_equations = sourceEqs;
            obj.source_constants = sourceConsts;

            [~, ~, stats]  = obj.compile(P);
            obj.close_loop();

            if obj.verbose
                fprintf('Program compiled & loop closed: %d equations → P (%d×%d)\n', ...
                    eqns, size(P,1), size(P,2));
            end
        end

        function A_out = close_loop(obj)
            % CLOSE_LOOP  Fold B̃W into A and retire the recurrent ports.
            % Idempotent: recomputes from provenance if already closed.
            if isempty(obj.W_)
                error('dspm_reservoir:notCompiled', 'Must compile() before closing the loop');
            end
            rec = obj.role_mask_("recurrent");
            if ~any(rec)
                error('dspm_reservoir:noRecurrentPorts', ...
                    'No recurrent ports to close. (Declarative/composite reservoirs are born closed.)');
            end

            B_rec = obj.B_(:, rec);
            A0    = obj.provenance.A0;
            if isempty(A0), A_out = B_rec * obj.read_out_matrix_recurrent;
            else,           A_out = A0 + B_rec * obj.read_out_matrix_recurrent;
            end
            obj.A_ = A_out;

            % retire recurrent ports (columns stay in B_ as provenance)
            idx = find(rec);
            for i = idx(:)'
                obj.ports(i).bound = true;
            end
        end
    end

%% ======================================================================
%  DYNAMICS — one integrator, no branches
%  ======================================================================
    methods
        function r_new = step(obj, x)
            % STEP  One integration step of (1/γ)ṙ = −r + tanh(A r + B x + d).
            % x has live_input_width rows (unbound ports). Empty x ⟹ x_star.
            live = ~[obj.ports.bound];
            w = nnz(live);
            if nargin < 2 || isempty(x)
                x = obj.live_x_star_();
            elseif isscalar(x) && w ~= 1
                x = x * ones(w, 1);       % legacy: scalar 0 ⟹ uniform drive
            end
            Blive = obj.B_(:, live);
            zfun = @(r) obj.z_(r, Blive, x);
            obj.r = obj.advance_(obj.r, zfun);
            r_new = obj.r;
        end

        function [r_traj, y_traj] = simulate(obj, T_steps, x_traj)
            % SIMULATE  Run T_steps from r0 (or r_star with a warning).
            % x_traj: (live_input_width × T) drive for unbound ports.
            if isempty(obj.r0_)
                warning('simulate: Starting from r_star. Consider using condition().');
                obj.r = obj.r_star_;
            else
                obj.r = obj.r0_;
            end
            w = obj.live_input_width;
            if nargin < 3 || isempty(x_traj)
                x_traj = zeros(w, T_steps);
            elseif size(x_traj, 2) == 1 && T_steps > 1
                x_traj = repmat(x_traj, 1, T_steps);   % constant drive
            end
            if size(x_traj, 1) ~= w
                error('dspm_reservoir:driveWidth', ...
                    'x_traj has %d rows; live input width is %d (unbound ports).', ...
                    size(x_traj,1), w);
            end

            r_traj = zeros(obj.n_neurons, T_steps);
            m_til  = max(obj.n_recurrent_outputs, 0);
            y_traj = zeros(m_til, T_steps);
            haveW  = ~isempty(obj.W_);
            for t = 1:T_steps
                obj.step(x_traj(:, t));
                r_traj(:, t) = obj.r;
                if haveW, y_traj(:, t) = obj.readout(); end
            end
        end

        function varargout = condition(obj, x_rec_0, x_ext_0, T_anneal)
            % CONDITION  Anneal the PRE-CLOSURE tuple under constant drive
            % (uses provenance; no flag toggling), then store r0.
            if nargin < 3 || isempty(x_ext_0)
                nonrec = ~obj.role_mask_("recurrent");
                x_ext_0 = obj.port_x0_(nonrec);
            end
            if nargin < 4 || isempty(T_anneal), T_anneal = 1000; end

            if isempty(obj.B_)
                error('dspm_reservoir:noProvenance', ...
                    ['condition() integrates the open-loop (pre-closure) tuple, ' ...
                     'which requires the full read-in B. This reservoir has no ' ...
                     'stored B (provenance tier "%s").'], obj.provenance.tier);
            end

            obj.r = obj.r_star_;
            xconst = [x_rec_0(:); x_ext_0(:)];
            if numel(xconst) ~= size(obj.B_, 2)
                error('dspm_reservoir:driveWidth', ...
                    'condition drive has %d entries; full input width is %d.', ...
                    numel(xconst), size(obj.B_, 2));
            end

            A0 = obj.provenance.A0;   % empty ⟹ 0
            states = nan(obj.n_neurons, T_anneal);
            zfun = @(r) obj.z_open_(r, A0, xconst);
            for t = 1:T_anneal
                obj.r = obj.advance_(obj.r, zfun);
                states(:, t) = obj.r;
            end
            obj.r0_ = obj.r;
            if nargout, varargout = {states}; end
        end

        function y = readout(obj, r)
            % READOUT  y = W̃ r (feedback rows of W).
            if nargin < 2, r = obj.r; end
            if isempty(obj.W_)
                error('dspm_reservoir:notCompiled', 'Reservoir not compiled.');
            end
            y = obj.read_out_matrix_recurrent * r;
        end

        function reset(obj)
            % RESET  State back to r_star (does not reopen the loop; see reopen()).
            obj.r = obj.r_star_;
        end

        function reopen(obj)
            % REOPEN  Undo closure using provenance: A ← A₀, rec ports unbound.
            if isempty(obj.B_)
                error('dspm_reservoir:noProvenance', ...
                    'Cannot reopen: no stored pre-closure read-in (tier "%s").', obj.provenance.tier);
            end
            obj.A_ = obj.provenance.A0;
            for i = 1:numel(obj.ports), obj.ports(i).bound = false; end
            obj.r0_ = [];
        end
    end

%% ======================================================================
%  STATUS & CAPABILITIES — derived, visible, never stored
%  ======================================================================
    methods
        function s = status(obj)
            % STATUS  Pipeline position + capabilities, computed from data.
            s = obj.get_status();
            s.capabilities = obj.capabilities();
        end

        function c = capabilities(obj)
            % CAPABILITIES  What this instance can do, from artifact presence.
            c.runnable          = ~isempty(obj.A_) && ~isempty(obj.d_star) && ~isempty(obj.r_star_);
            c.programmable      = any(obj.role_mask_("recurrent") & ~[obj.ports.bound]) && ~isempty(obj.B_);
            c.composable_target = any(obj.role_mask_("exogenous") & ~[obj.ports.bound]);
            c.composable_source = ~isempty(obj.W_);
            c.reopenable        = ~isempty(obj.B_) && obj.provenance.tier ~= "none";
        end

        function status = get_status(obj)
            % GET_STATUS  Legacy-shaped struct, now derived live.
            status.is_initialized = obj.is_initialized;
            status.is_decompiled  = obj.is_decompiled;
            status.is_compiled    = obj.is_compiled;
            status.is_closed      = obj.is_closed;
            status.is_conditioned = obj.is_conditioned;
            status.ready_to_run   = obj.ready_to_run;
            if ~status.is_initialized,     status.next_action = 'construct with dimensions (or from_matrices)';
            elseif ~status.is_decompiled,  status.next_action = 'program(dx)   % decompiles automatically';
            elseif ~status.is_compiled,    status.next_action = 'program(dx) or compile(P)';
            elseif ~status.is_closed,      status.next_action = 'close_loop()';
            elseif ~status.is_conditioned, status.next_action = 'condition(x0)';
            else,                          status.next_action = 'ready';
            end
        end

        function disp_status(obj)
            s = obj.status();
            fprintf('\nReservoir Pipeline Status (derived from data):\n');
            fprintf('─────────────────────────────\n');
            stages = {'is_initialized','is_decompiled','is_compiled','is_closed','is_conditioned'};
            names  = {'Network initialized','Decompiled','Compiled','Loop closed','Conditioned'};
            for i = 1:numel(stages)
                mark = ' '; if s.(stages{i}), mark = '✓'; end
                fprintf('  [%s] %s\n', mark, names{i});
            end
            fprintf('─────────────────────────────\n');
            c = s.capabilities; caps = strings(0);
            if c.runnable,          caps(end+1) = "runnable";          end %#ok<AGROW>
            if c.programmable,      caps(end+1) = "programmable";      end %#ok<AGROW>
            if c.composable_target, caps(end+1) = "composable-target"; end %#ok<AGROW>
            if c.composable_source, caps(end+1) = "composable-source"; end %#ok<AGROW>
            if c.reopenable,        caps(end+1) = "reopenable";        end %#ok<AGROW>
            fprintf('  capabilities: %s\n', strjoin(caps, ', '));
            if strcmp(s.next_action, 'ready'), fprintf('  Ready to simulate!\n');
            else,                              fprintf('  Next: %s\n', s.next_action);
            end
            fprintf('\n');
        end

        function port_table(obj)
            % PORT_TABLE  Print the port ontology.
            fprintf('\n  #   id      label   role        bound  x0\n');
            for i = 1:numel(obj.ports)
                p = obj.ports(i);
                fprintf('  %-3d %-7s %-7s %-11s %-6s %g\n', i, p.id, p.label, p.role, ...
                    string(p.bound), p.x0);
            end
            fprintf('\n');
        end
    end

%% ======================================================================
%  CANONICAL GET/SET  (setters clear downstream DATA; nothing computes here
%  except the O(N) identity refresh of d⋆ — allowed by the cost hierarchy)
%  ======================================================================
    methods
        % ----- substrate hyperparameters that invalidate the eval tier -----
        function set.gamma(obj, v)
            changed = ~isequal(obj.gamma, v);
            obj.gamma = v;
            if changed, obj.clear_decompiled_(); end   % γ ⟹ eval tier + P̂ + W (§1.9)
        end
        function set.n_neurons(obj, v)
            changed = ~isequal(obj.n_neurons, v) && ~isempty(obj.n_neurons);
            obj.n_neurons = v;
            if changed
                obj.B_ = []; obj.r_star_ = []; obj.d_star_ = []; obj.r0_ = [];
                obj.clear_decompiled_();
            end
        end

        % ----- A -----
        function v = get.A(obj), v = obj.A_; end
        function set.A(obj, v)
            obj.A_ = v;
            obj.r0_ = [];               % injected adjacency ⟹ stale conditioning
        end

        % ----- B -----
        function v = get.B(obj), v = obj.B_; end
        function set.B(obj, v)
            if ~isempty(v) && ~isempty(obj.ports) && size(v,2) ~= numel(obj.ports)
                error('dspm_reservoir:portMismatch', ...
                    'B has %d columns but the port table has %d ports.', size(v,2), numel(obj.ports));
            end
            obj.B_ = v;
            obj.refresh_dstar_();
            obj.clear_decompiled_();
        end

        % ----- W -----
        function v = get.W(obj), v = obj.W_; end
        function set.W(obj, v)
            obj.W_ = v;
            obj.clear_closed_();
        end

        % ----- r_star / d_star -----
        function v = get.r_star(obj), v = obj.r_star_; end
        function set.r_star(obj, v)
            obj.r_star_ = v(:);
            obj.refresh_dstar_();       % identity: d⋆ = atanh(r⋆) − A₀r⋆ − Bx₀
            obj.clear_decompiled_();
        end

        function v = get.d_star(obj)
            if ~isempty(obj.d_star_), v = obj.d_star_; return; end
            v = obj.identity_dstar_();
        end
        function set.d_star(obj, v)
            v = v(:);
            ref = obj.identity_dstar_();
            if ~isempty(ref) && ~isempty(v)
                err = norm(v - ref, inf);
                if err > 1e-6 * max(1, norm(ref, inf))
                    warning('dspm_reservoir:identityMismatch', ...
                        ['Supplied d_star violates the fixed-point identity ' ...
                         'd\x22c6 = atanh(r\x22c6) - A\x2080r\x22c6 - Bx\x2080 by %.2e (inf-norm). Storing anyway.'], err);
                end
            end
            obj.d_star_ = v;
            obj.clear_decompiled_();
        end

        % ----- x_star (assembled from ports) -----
        function v = get.x_star(obj)
            if isempty(obj.ports), v = []; return; end
            v = reshape([obj.ports.x0], [], 1);
        end
        function set.x_star(obj, v)
            v = v(:);
            if numel(v) ~= numel(obj.ports)
                error('dspm_reservoir:portMismatch', ...
                    'x_star has %d entries but the port table has %d ports.', numel(v), numel(obj.ports));
            end
            for i = 1:numel(obj.ports), obj.ports(i).x0 = v(i); end
            obj.refresh_dstar_();
            obj.clear_decompiled_();
        end

        % ----- expansion orders (content-addressed cache keys) -----
        function v = get.jet_order(obj), v = obj.jet_order_; end
        function set.jet_order(obj, v)
            if isequal(obj.jet_order_, v), return; end
            obj.jet_order_ = v;
            obj.jet_cache_valid_    = false;
            obj.taylor_cache_valid_ = false;
            obj.clear_decompiled_();
        end
        function v = get.decompilation_order(obj), v = obj.decompilation_order_; end
        function set.decompilation_order(obj, v)
            if isequal(obj.decompilation_order_, v), return; end
            obj.decompilation_order_ = v;
            obj.taylor_cache_valid_ = false;
            obj.clear_decompiled_();
        end

        % ----- r0 -----
        function v = get.r0(obj), v = obj.r0_; end
        function set.r0(obj, v), obj.r0_ = v; end

        % ----- derived dimensions -----
        function v = get.n_inputs(obj),            v = numel(obj.ports); end
        function v = get.n_outputs(obj),           v = obj.n_recurrent_outputs + obj.n_external_outputs; end
        function v = get.n_recurrent_inputs(obj),  v = nnz(obj.role_mask_("recurrent")); end
        function v = get.n_exogenous_inputs(obj),  v = nnz(obj.role_mask_("exogenous")); end
        function v = get.n_external_inputs(obj),   v = numel(obj.ports) - obj.n_recurrent_inputs; end
        function v = get.live_input_width(obj)
            if isempty(obj.ports), v = 0; else, v = nnz(~[obj.ports.bound]); end
        end
        function v = get.is_initialized(obj)
            v = ~isempty(obj.B_) && ~isempty(obj.r_star_) && ~isempty(obj.ports);
        end
    end

%% ======================================================================
%  LEGACY ALIAS GET/SET  (thin forwarding; slated for deprecation)
%  ======================================================================
    methods
        function v = get.read_in_matrix_B(obj), v = obj.B; end
        function set.read_in_matrix_B(obj, v), obj.B = v; end

        function v = get.read_in_matrix_recurrent(obj)
            if isempty(obj.B_), v = []; return; end
            v = obj.B_(:, obj.role_mask_("recurrent"));
        end
        function set.read_in_matrix_recurrent(obj, v)
            obj.B_(:, obj.role_mask_("recurrent")) = v;
            obj.refresh_dstar_(); obj.clear_decompiled_();
        end

        function v = get.read_in_matrix_external(obj)
            if isempty(obj.B_), v = []; return; end
            m = ~obj.role_mask_("recurrent");
            if ~any(m), v = 0; else, v = obj.B_(:, m); end
        end
        function set.read_in_matrix_external(obj, v)
            obj.B_(:, ~obj.role_mask_("recurrent")) = v;
            obj.refresh_dstar_(); obj.clear_decompiled_();
        end

        function v = get.read_out_matrix_W(obj), v = obj.W_; end
        function set.read_out_matrix_W(obj, v), obj.W = v; end

        function v = get.read_out_matrix_recurrent(obj)
            if isempty(obj.W_), v = []; return; end
            v = obj.W_(1:obj.n_recurrent_outputs, :);
        end
        function set.read_out_matrix_recurrent(obj, v)
            if isempty(obj.W_)
                obj.W_ = zeros(obj.n_outputs, obj.n_neurons);
            end
            obj.W_(1:obj.n_recurrent_outputs, :) = v;
            obj.clear_closed_();
        end

        function v = get.read_out_matrix_external(obj)
            if isempty(obj.W_), v = []; return; end
            v = obj.W_(obj.n_recurrent_outputs+1:end, :);
        end
        function set.read_out_matrix_external(obj, v)
            if isempty(obj.W_)
                obj.W_ = zeros(obj.n_outputs, obj.n_neurons);
            end
            obj.W_(obj.n_recurrent_outputs+1:end, :) = v;
            obj.clear_closed_();
        end

        function v = get.programmed_adjacency(obj), v = obj.A_; end
        function set.programmed_adjacency(obj, v), obj.A = v; end

        function v = get.bias(obj), v = obj.d_star; end

        function v = get.x_recurrent_star(obj)
            v = obj.port_x0_(obj.role_mask_("recurrent"));
        end
        function set.x_recurrent_star(obj, v)
            obj.set_port_x0_(obj.role_mask_("recurrent"), v);
        end
        function v = get.x_external_star(obj)
            m = ~obj.role_mask_("recurrent");
            if ~any(m), v = 0; else, v = obj.port_x0_(m); end
        end
        function set.x_external_star(obj, v)
            obj.set_port_x0_(~obj.role_mask_("recurrent"), v);
        end

        function v = get.expansion_point(obj)
            v = [obj.x_star; zeros(obj.n_inputs * max(obj.jet_order_-1, 0), 1)];
        end
        function set.expansion_point(obj, v)
            if ~isempty(v) && ~isempty(obj.ports)
                obj.x_star = v(1:obj.n_inputs);
            end
        end

        function v = get.recurrent_input_indices(obj),  v = find(obj.role_mask_("recurrent"))'; end
        function v = get.external_input_indices(obj),   v = find(~obj.role_mask_("recurrent"))'; end
        function v = get.recurrent_output_indices(obj), v = 1:obj.n_recurrent_outputs; end
        function v = get.external_output_indices(obj),  v = (obj.n_recurrent_outputs+1):obj.n_outputs; end

        % legacy flags — derived, read-only
        function v = get.is_decompiled(obj),  v = ~isempty(obj.decompiled_weight_matrix); end
        function v = get.is_compiled(obj),    v = ~isempty(obj.W_); end
        function v = get.is_closed(obj),      v = ~isempty(obj.A_); end
        function v = get.is_conditioned(obj), v = ~isempty(obj.r0_); end
        function v = get.ready_to_run(obj),   v = obj.is_closed && obj.is_conditioned; end

        % path inference
        function v = get.classpath(~),    v = string(mfilename("fullpath")) + ".m"; end
        function v = get.rootpath(obj),   v = obj.filepartsR(obj.classpath, 3); end
        function v = get.prog_gui_path(obj), v = fullfile(obj.rootpath, "reservoir-gui"); end
        function v = get.save_path(obj),  v = fullfile(obj.rootpath, "saved-networks"); end
    end

%% ======================================================================
%  EXTERNAL-FILE INSTANCE METHODS (extracted verbatim from the monolith)
%  ======================================================================
    methods
        programming_gui(obj)
        idx = getColumnIndex(obj, term_str)
        indices = getColumnIndices(obj, term_strs)
        indices = getPositionColumns(obj)
        indices = getVelocityColumns(obj)
        indices = getLinearColumns(obj)
        indices = getQuadraticColumns(obj)
        render_program(obj, varargin)
        printBasis(obj, maxRows)
        displayBasis(obj)
        summary(obj)
        loadProgram(obj, equations, constants)
        save(obj, filepath, varargin)
        s = toStruct(obj)
        programming_help(~)
        printExampleDynamics(~, system)
        colStr = sym2colstr(~, mono, n_vars)
        tf = hasSymbolicToolbox(~)
    end

    methods (Hidden)
        function initialize_network_random(obj)
            % legacy public name
            obj.generate_();
        end

        function initializeFromOptions(obj, opts)
            % Legacy initializer used by fromStruct()/load(): eager decompile,
            % identical observable behavior to the old constructor path.
            o = obj.default_options_();
            f = fieldnames(opts);
            for i = 1:numel(f), o.(f{i}) = opts.(f{i}); end
            o.decompile = "eager";
            obj.build_from_options_(o);
        end
    end

%% ======================================================================
%  PRIVATE MACHINERY
%  ======================================================================
    methods (Access = private)

        function build_from_options_(obj, o)
            % shared generative construction (constructor + legacy io path)
            obj.jet_order_           = o.jet_order;
            obj.decompilation_order_ = o.decompilation_order;
            obj.n_neurons            = o.n_neurons;
            obj.gamma       = o.gamma;
            obj.dt          = o.dt;
            obj.integrator  = o.integrator;
            obj.verbose     = o.verbose;
            obj.random_seed = o.random_seed;
            obj.B_scale     = o.B_scale;
            obj.B_sparsity  = o.B_sparsity;
            obj.equilibrate = o.equilibrate;

            % ---- ports ----------------------------------------------------
            if ~isempty(o.ports) && ~(isscalar(o.ports) && o.ports == "")
                if isscalar(o.ports) && o.ports == "infer"
                    obj.ports_infer_ = true;
                else
                    obj.build_ports_(o.ports, o.port_names);
                end
            elseif ~isnan(o.n_recurrent_inputs)
                roles = [repmat("recurrent", 1, o.n_recurrent_inputs), ...
                         repmat("external",  1, o.n_external_inputs)];
                obj.build_ports_(roles, string.empty);
            else
                obj.ports_infer_ = true;   % m̃ provisioned by first program(dx)
            end

            % readout row split
            if isnan(o.n_recurrent_outputs)
                obj.n_recurrent_outputs = obj.n_recurrent_inputs;
            else
                obj.n_recurrent_outputs = o.n_recurrent_outputs;
            end
            obj.n_external_outputs = o.n_external_outputs;

            % custom matrices
            if ~isempty(o.read_in_matrix),  obj.B_ = o.read_in_matrix;  end
            if ~isempty(o.read_out_matrix), obj.W_ = o.read_out_matrix; end

            if ~isempty(o.r_star)
                obj.r_star_ = o.r_star(:);
                obj.r       = o.r_star(:);
            end
            if ~isempty(o.x_star) && ~isempty(obj.ports)
                obj.x_star = o.x_star(:);
            end

            % ---- generate + (maybe) decompile -----------------------------
            if o.initialize && ~obj.ports_infer_
                if obj.random_seed > 0, rng(obj.random_seed); end
                if ~obj.is_initialized, obj.generate_(); end
                if o.decompile == "eager"
                    obj.decompile();
                end
                if obj.random_seed > 0, rng("shuffle"); end
            end
        end

        function o = default_options_(obj) %#ok<MANU>
            o = struct('n_neurons',NaN,'ports',string.empty,...
                'port_names',string.empty, ...
                'n_recurrent_inputs',NaN,'n_external_inputs',0, ...
                'n_recurrent_outputs',NaN,'n_external_outputs',0, ...
                'gamma',100,'dt',0.01,'integrator',"rk4", ...
                'B_scale',0.1,'B_sparsity',1.0,'equilibrate',false,...
                'r_star',[],'x_star',[], ...
                'random_seed',0,'jet_order',2,'decompilation_order',3, ...
                'read_in_matrix',[],'read_out_matrix',[], ...
                'decompile',"lazy",'initialize',true,'verbose',true);
        end

        function build_ports_(obj, roles, names)
            roles = obj.canon_roles_(roles);
            counters = struct('recurrent',0,'exogenous',0,'external',0);
            prefix   = struct('recurrent',"rec",'exogenous',"exo",'external',"ext");
            sym      = struct('recurrent',"x̃",'exogenous',"x̅",'external',"x̂");
            P = struct('id',{},'label',{},'role',{},'x0',{},'bound',{},'aliases',{});
            for i = 1:numel(roles)
                ro = char(roles(i));
                counters.(ro) = counters.(ro) + 1;
                k = counters.(ro);
                P(i).id      = prefix.(ro) + string(k);
                P(i).label   = sym.(ro) + string(k);
                P(i).role    = roles(i);
                P(i).x0      = 0;
                P(i).bound   = false;
                P(i).aliases = string.empty;
                if numel(names) >= i && names(i) ~= ""
                    P(i).aliases = names(i);
                end
            end
            obj.ports = P;
        end

        function provision_ports_(obj, m_til)
            % ports="infer": m̃ dictated by the target's equation count
            if obj.verbose
                fprintf('Provisioning %d recurrent ports from program signature...\n', m_til);
            end
            obj.build_ports_(repmat("recurrent", 1, m_til), string.empty);
            obj.ports_infer_ = false;
            if isempty(obj.n_recurrent_outputs) || any(isnan(obj.n_recurrent_outputs)) ...
                    || obj.n_recurrent_outputs == 0
                obj.n_recurrent_outputs = m_til;
            end
            if obj.random_seed > 0, rng(obj.random_seed); end
            obj.generate_();
            if obj.random_seed > 0, rng("shuffle"); end
        end

        function generate_(obj)
            % random substrate (old initialize_network_random) + provenance
            if obj.verbose, disp("Initializing Default Reservoir..."); end
            N    = obj.n_neurons;
            krec = obj.n_recurrent_inputs;
            kext = obj.n_inputs - krec;

            if isempty(obj.B_)
                scale    = obj.B_scale    .* [1, 1];
                sparsity = obj.B_sparsity .* [1, 1];
                mask_rec = rand(N, krec) < sparsity(1);
                mask_ext = rand(N, kext) < sparsity(2);
                B_rec = scale(1) * (2*rand(N, krec) - 1) .* mask_rec;
                B_ext = scale(2) * (2*rand(N, kext) - 1) .* mask_ext;
                obj.B_ = [B_rec, B_ext];
            else
                obj.B_scale    = max(abs(obj.B_(:)), [], "all");
                obj.B_sparsity = nnz(obj.B_) / numel(obj.B_);
                if obj.verbose
                    fprintf("\t Using provided B matrix (inferred scale=%.3f, sparsity=%.3f)\n", ...
                        obj.B_scale, obj.B_sparsity);
                end
            end

            if isempty(obj.r_star_)
                obj.r_star_ = rand(N, 1) - 0.5;
            end
            obj.r = obj.r_star_;
            obj.refresh_dstar_();

            % provenance
            obj.provenance.tier = "full";
            obj.provenance.A0   = [];        % A₀ = 0 for the generative substrate
            obj.provenance.seed = obj.random_seed;
            obj.provenance.hyperparams = struct('N',N,'krec',krec,'kext',kext, ...
                'B_scale',obj.B_scale,'B_sparsity',obj.B_sparsity);
        end

        % ---- identity ----------------------------------------------------
        function d = identity_dstar_(obj)
            % d⋆ = atanh(r⋆) − A₀r⋆ − B·x₀  (pre-closure tuple; A₀ empty ⟹ 0)
            if isempty(obj.r_star_) || isempty(obj.B_) || isempty(obj.ports)
                d = []; return
            end
            d = atanh(obj.r_star_) - obj.B_ * obj.x_star;
            A0 = obj.provenance.A0;
            if ~isempty(A0), d = d - A0 * obj.r_star_; end
        end
        function refresh_dstar_(obj)
            d = obj.identity_dstar_();
            if ~isempty(d), obj.d_star_ = d; end
        end

        % ---- integrator --------------------------------------------------
        function z = z_(obj, r, Blive, x)
            z = obj.d_star;
            if ~isempty(Blive) && ~isempty(x), z = z + Blive * x; end
            if ~isempty(obj.A_), z = z + obj.A_ * r; end
        end
        function z = z_open_(obj, r, A0, xfull)
            z = obj.B_ * xfull + obj.d_star;
            if ~isempty(A0), z = z + A0 * r; end
        end
        function r_new = advance_(obj, r, zfun)
            drdt = @(rs) obj.gamma * (-rs + tanh(zfun(rs)));
            switch lower(obj.integrator)
                case "rk4"
                    k1 = obj.dt * drdt(r);
                    k2 = obj.dt * drdt(r + k1/2);
                    k3 = obj.dt * drdt(r + k2/2);
                    k4 = obj.dt * drdt(r + k3);
                    dr = (k1 + 2*k2 + 2*k3 + k4) / 6;
                otherwise   % euler
                    dr = obj.dt * drdt(r);
            end
            r_new = r + dr;
        end

        function x = live_x_star_(obj)
            live = ~[obj.ports.bound];
            x = obj.port_x0_(live);
            if isempty(x), x = zeros(0, 1); end
        end

        % ---- ports helpers ----------------------------------------------
        function m = role_mask_(obj, role)
            if isempty(obj.ports), m = false(1, 0); return; end
            m = strcmp(string({obj.ports.role}), role);
        end
        function v = port_x0_(obj, mask)
            idx = find(mask);
            v = reshape([obj.ports(idx).x0], [], 1);
        end
        function set_port_x0_(obj, mask, v)
            idx = find(mask); v = v(:);
            for k = 1:numel(idx), obj.ports(idx(k)).x0 = v(k); end
            obj.refresh_dstar_(); obj.clear_decompiled_();
        end
        function r = canon_roles_(~, roles)
            roles = string(roles(:)');
            r = strings(size(roles));
            for i = 1:numel(roles)
                switch lower(roles(i))
                    case {"rec","recurrent"},  r(i) = "recurrent";
                    case {"exo","exogenous"},  r(i) = "exogenous";
                    case {"ext","external"},   r(i) = "external";
                    otherwise
                        error('dspm_reservoir:badRole', ...
                            'Unknown port role "%s" (use rec/exo/ext).', roles(i));
                end
            end
        end

        % ---- declarative-factory helpers ---------------------------------
        function set_provenance_(obj, tier, A0)
            obj.provenance.tier = tier;
            obj.provenance.A0   = A0;
        end
        function set_pair_(obj, rs, ds)
            % direct backing write: factory-validated pair, no downstream clears
            obj.r_star_ = rs(:);
            obj.d_star_ = ds(:);
        end
        function bind_recurrent_ports_(obj)
            rec = find(obj.role_mask_("recurrent"));
            for i = rec(:)'
                obj.ports(i).bound = true;
            end
        end

        % ---- downstream data clearing (replaces the flag machine) --------
        function clear_decompiled_(obj)
            obj.decompiled_weight_matrix = [];
            obj.n_monomials = []; obj.n_symbolic_vars = [];
            obj.symbolic_basis_mapping = []; obj.symbolic_basis_strings = [];
            obj.physical_basis_strings = []; obj.cached_basis = [];
            obj.clear_program_();
        end
        function clear_program_(obj)
            obj.W_ = [];
            obj.compiled_program_matrix = [];
            obj.clear_closed_();
        end
        function clear_closed_(obj)
            obj.A_ = [];
            for i = 1:numel(obj.ports), obj.ports(i).bound = false; end
            obj.r0_ = [];
        end
    end

%% ======================================================================
%  HIDDEN EXTERNAL METHODS (extracted verbatim)
%  ======================================================================
    methods (Hidden)
        [P, sourceEqs, sourceConsts] = buildProgramMatrixSymbolic(obj, dx, tau, constants, uservars)
        displaySymbolicToolboxError(obj)
        displayNonSymbolicError(obj, dx)
    end

end
