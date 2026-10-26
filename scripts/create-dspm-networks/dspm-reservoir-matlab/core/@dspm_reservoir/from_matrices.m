function obj = from_matrices(options)
% FROM_MATRICES  Declarative factory: build a reservoir from solved artifacts.
%
% The composite/hand-built entry point. Performs NO symbolic work and NO
% random generation. Enforces the fixed-point identity
%
%     d⋆ = arctanh(r⋆) − A·r⋆ − B·x₀
%
% with give-one/derive-other/assert-both semantics on the {r⋆, d⋆} pair.
%
% USAGE:
%   res = dspm_reservoir.from_matrices(A=A_prog, B=B, ports=["exo","exo","ext"], ...
%                                      W=W, r_star=rs, gamma=300, dt=1e-3);
%   res = dspm_reservoir.from_matrices(A=A_prog, r_star=rs, d_star=ds, gamma=300);
%
% RULES:
%   r_star given            → d_star computed from the identity
%   d_star given            → r_star solved as the fixed point (damped iteration)
%   both given              → identity asserted to tolerance (error on violation)
%   A empty                 → treated as 0 (open substrate)
%   B empty                 → runnable but not decompilable/composable-target
%
% Provenance:
%   Pass A0 (and optionally B_full) to record full pre-closure provenance;
%   otherwise the tier is "none": the reservoir runs, and composes if it has
%   W (source) / unbound exogenous ports (target), but cannot be re-opened.
%
% See also: dspm_reservoir, close_loop, condition, capabilities

    arguments
        options.A (:,:) double = []
        options.B (:,:) double = []
        options.ports string = string.empty          % roles for B's columns
        options.port_names string = string.empty
        options.W (:,:) double = []
        options.r_star (:,1) double = []
        options.d_star (:,1) double = []
        options.x0 (:,1) double = []                 % per-port expansion values
        options.gamma (1,1) double {mustBePositive} = 100
        options.dt (1,1) double {mustBePositive} = 0.01
        options.integrator (1,1) string {mustBeMember(options.integrator,["euler","rk4"])} = "euler"
        options.jet_order (1,1) double {mustBePositive, mustBeInteger} = 2
        options.decompilation_order (1,1) double {mustBePositive, mustBeInteger} = 3
        options.n_recurrent_outputs (1,1) double = NaN
        options.n_external_outputs (1,1) double = 0
        options.A0 (:,:) double = []                 % optional provenance
        options.identity_tol (1,1) double {mustBePositive} = 1e-6
        options.verbose (1,1) logical = false
    end

    % ---- infer N --------------------------------------------------------
    cands = [size(options.A,1), size(options.B,1), numel(options.r_star), ...
             numel(options.d_star), size(options.W,2)];
    cands = cands(cands > 0);
    if isempty(cands)
        error('dspm_reservoir:underdetermined', ...
            'from_matrices needs at least one of A, B, W, r_star, d_star to infer N.');
    end
    N = cands(1);
    if any(cands ~= N)
        error('dspm_reservoir:dimensionMismatch', ...
            'Inconsistent neuron counts across supplied matrices: %s', mat2str(cands));
    end

    % ---- empty object, then fill the tuple directly ---------------------
    obj = dspm_reservoir();
    obj.n_neurons  = N;
    obj.gamma      = options.gamma;
    obj.dt         = options.dt;
    obj.integrator = options.integrator;
    obj.verbose    = options.verbose;
    obj.jet_order           = options.jet_order;
    obj.decompilation_order = options.decompilation_order;

    % ---- ports (roles for the LIVE columns of B) ------------------------
    m = size(options.B, 2);
    if ~isempty(options.ports) && ~(isscalar(options.ports) && options.ports == "")
        if numel(options.ports) ~= m
            error('dspm_reservoir:portMismatch', ...
                'ports has %d roles but B has %d columns.', numel(options.ports), m);
        end
        obj.build_ports_(options.ports, options.port_names);
    elseif m > 0
        % default: all supplied read-in columns are external drive
        obj.build_ports_(repmat("external", 1, m), options.port_names);
    end
    if ~isempty(options.x0)
        if numel(options.x0) ~= m
            error('dspm_reservoir:portMismatch', ...
                'x0 has %d entries but B has %d columns.', numel(options.x0), m);
        end
        obj.x_star = options.x0;
    end

    % ---- provenance (before identity, so A0 participates) ---------------
    if ~isempty(options.A0)
        obj.set_provenance_("full", options.A0);
    else
        obj.set_provenance_("none", []);
    end

    % ---- matrices (direct backing writes: no downstream to clear yet) ---
    obj.B = options.B;                 % validates against ports
    if ~isempty(options.W)
        obj.W = options.W;
        if isnan(options.n_recurrent_outputs)
            obj.n_recurrent_outputs = size(options.W, 1) - options.n_external_outputs;
        end
    end
    if isnan(options.n_recurrent_outputs) && isempty(options.W)
        obj.n_recurrent_outputs = 0;
    elseif ~isnan(options.n_recurrent_outputs)
        obj.n_recurrent_outputs = options.n_recurrent_outputs;
    end
    obj.n_external_outputs = options.n_external_outputs;

    % ---- the {r⋆, d⋆} pair ----------------------------------------------
    rs = options.r_star;
    ds = options.d_star;
    have_r = ~isempty(rs);
    have_d = ~isempty(ds);

    if ~have_r && ~have_d
        error('dspm_reservoir:underdetermined', ...
            'Supply r_star, d_star, or both (identity: d\x22c6 = atanh(r\x22c6) - A r\x22c6 - B x\x2080).');
    end

    A_eff = options.A; if isempty(A_eff), A_eff = sparse(N, N); end
    B_eff = options.B; if isempty(B_eff), B_eff = zeros(N, 0);  end
    x0    = obj.x_star; if isempty(x0),   x0    = zeros(size(B_eff,2), 1); end

    if have_r && ~have_d
        ds = atanh(rs) - A_eff * rs - B_eff * x0;
    elseif have_d && ~have_r
        % solve r⋆ = tanh(A r⋆ + B x₀ + d) by damped fixed-point iteration
        rs = zeros(N, 1); alpha = 0.5;
        for it = 1:500
            rn = tanh(A_eff * rs + B_eff * x0 + ds);
            if norm(rn - rs, inf) < 1e-12, rs = rn; break; end
            rs = (1 - alpha) * rs + alpha * rn;
        end
        resid = norm(rs - tanh(A_eff * rs + B_eff * x0 + ds), inf);
        if resid > 1e-8
            warning('dspm_reservoir:fixedPoint', ...
                'Fixed-point solve for r_star converged to residual %.2e only.', resid);
        end
    else % both given: assert the identity
        ref = atanh(rs) - A_eff * rs - B_eff * x0;
        err = norm(ds - ref, inf);
        if err > options.identity_tol * max(1, norm(ref, inf))
            error('dspm_reservoir:identityViolated', ...
                ['{r\x22c6, d\x22c6} pair violates the fixed-point identity by %.2e (inf-norm, tol %.1e). ' ...
                 'Give one and let the object derive the other, or fix the pair.'], ...
                err, options.identity_tol);
        end
    end

    obj.set_pair_(rs, ds);
    obj.r = rs;

    % ---- adjacency last (so its setter''s r0-clear is harmless) ----------
    if ~isempty(options.A)
        obj.A = options.A;
        % declarative closure state: any recurrent-role ports are considered
        % already folded into A (born closed)
        obj.bind_recurrent_ports_();
    end
end
