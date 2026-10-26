function symbolic_jet_expansion = jet_expansion_(obj)
% JET_EXPANSION_  Compute h(y) = tanh(B·x(t+T) + d) expanded in time derivatives
%
% This is the EXPENSIVE step (str2sym). Only runs when:
%   - n_inputs changes
%   - jet_order changes
%
% Output is cached in obj.symbolic_jet_equation_
%
% SYMBOLIC TAYLOR EXPANSION IN TIME
% ---------------------------------
% Goal: Expand tanh(B*x(t+T) + d) around T=0 to order (jet_order-1)
%  
% This captures how the reservoir state depends on x and its time
% derivatives ẋ, ẍ, etc. The symbolic toolbox handles the chain rule
% automatically.
%
% INPUTS
%   obj - Reservoir object with fields:
%         .jet_order           - Order of time derivatives (1 = static, 2 = velocity, etc.)
%         .n_inputs            - Number of input variables (k_rec + k_ext)
%         .jet_cache_valid_    - Cache validity flag
%         .symbolic_jet_equation_ - Cached result
%         .verbose             - Print timing info if true
%
% OUTPUTS
%   symbolic_jet_expansion - Symbolic state equation h(y) up to jet_order
%
% SIDE EFFECTS
%   Sets obj.symbolic_jet_equation_ (cache)
%   Sets obj.jet_cache_valid_ = true
%
% MATHEMATICAL BACKGROUND
% -----------------------
% The reservoir equation is:
%
%   (1/γ) ṙ = -r + tanh(B*x + d)
%
% At steady state with slowly-varying input x(t), we can Taylor expand
% tanh(B*x(t+T) + d) around T=0 to capture how r depends on x and its
% time derivatives. This gives the "jet" structure:
%
%   tanh(B*x(t+T) + d) ≈ tanh(B*x + d) + T*(d/dt)tanh(...) + T²/2*(d²/dt²)tanh(...) + ...
%
% where each time derivative introduces terms in ẋ, ẍ, etc. via chain rule.
% The parameter T = -1/γ relates to the reservoir's memory timescale.
%
% After the time expansion, we have the resulting approximation of our
% state where r(t) ≈ h(x, ẋ, ẍ, ...)
%
% See: Kim & Bassett (2023) "A neural machine code and programming framework
%      for the reservoir computer", Nature Machine Intelligence

%% ========================================================================
%  CHECK CACHE FIRST
%  ========================================================================
%  This is the most expensive step - only run if cache is invalid

if obj.jet_cache_valid_ && ~isempty(obj.symbolic_jet_equation_)
    symbolic_jet_expansion = obj.symbolic_jet_equation_;
    if obj.verbose
        fprintf('jet_expansion_: Using cached symbolic jet equation\n');
    end
    return
end

%% ========================================================================
%  EXTRACT PARAMETERS FROM RESERVOIR OBJECT
%  ========================================================================

jet_order = obj.jet_order;       % Time derivative order (1=static, 2=velocity, 3=accel)
ninputs   = obj.n_inputs;        % Number of inputs (k_rec + k_ext)
nyvars    = jet_order * ninputs; %#ok<NASGU> % Extended state dimension

if obj.verbose
    fprintf('jet_expansion_: Computing symbolic jet (n_inputs=%d, jet_order=%d)...\n', ...
        ninputs, jet_order);
    tic
end

%% ========================================================================
%  DEFINE SYMBOLIC VARIABLES
%  ========================================================================
% NOTE: Variable names are chosen carefully to avoid conflicts:
%   - Bsym, dsym: Placeholders for B, d (avoid shadowing numeric vars)
%   - tau, t, T: Time variables for Taylor expansion
%   - x(tau): Input as function of time (for symbolic differentiation)
%   - y: Extended state variables [x; ẋ/γ; ẍ/γ²; ...]

syms Bsym [1 ninputs] real      % Symbolic B matrix (row vector for each neuron)
syms tau t dsym T real          % Time variables and symbolic bias
syms x(tau) [ninputs 1]         % Input as function of time
syms y [nyvars 1] real          % Extended state variables

%% ========================================================================
%  BUILD AND EXPAND ACTIVATION FUNCTION
%  ========================================================================

% h = tanh(Bsym * x(tau) + dsym) represents one neuron's activation
h = tanh(Bsym * x + dsym);

% Taylor expand in time: h(t+T) ≈ h(t) + T*h'(t) + T²/2*h''(t) + ...
% The 'Order' parameter specifies how many terms to keep
tay = taylor(h, tau, t, 'Order', jet_order);

% Rename the time offset variable for cleaner manipulation
% The symbolic toolbox produces terms in (tau - t), we rename to T
tay = subs(tay, (-tau + t), T);

% Convert to string for manipulation
% This is where we leave the symbolic world and enter string processing
S1 = string(tay);

%% ========================================================================
%  REPLACE SYMBOLIC DERIVATIVES WITH Y-VARIABLES
%  ========================================================================
%  The symbolic expansion contains terms like:
%    diff(x1(t), t)      → ẋ₁  → y_{ninputs+1}
%    diff(x1(t), t, t)   → ẍ₁  → y_{2*ninputs+1}
%  
%  We replace these with y-variables and substitute T^k → (-1)^k/γ^(k-1)
%  
%  CRITICAL: We must process HIGHER-order derivatives FIRST!
%  Otherwise "diff(x1(t), t, t)" might partially match "diff(x1(t), t)"

% Loop from highest derivative order down to 1
% (jet_order-1) is the highest derivative we have (jet_order=2 means we have ẋ)
for i = (jet_order-1):-1:1
    for j = 1:ninputs
        % Compute index in extended y-vector
        % y = [x₁, x₂, ..., x_k, ẋ₁, ẋ₂, ..., ẋ_k, ẍ₁, ...]
        %     [  1st block   ] [   2nd block    ] [3rd block]
        jdx = i * ninputs + j;
        
        % Build pattern for i-th derivative of x_j
        % diff(x1(t), t)     for i=1
        % diff(x1(t), t, t)  for i=2, etc.
        dxi   = sprintf("diff(x%d(t),", j);
        treps = repmat(' t,', 1, i-1) + " t)";  % " t)" or " t, t)" or " t, t, t)" etc.
        
        % Replace derivative expression with y-variable
        S1 = replace(S1, dxi + treps, string(y(jdx)));
    end
    
    % Replace T^i with appropriate gamma scaling
    % From the jet expansion: T = -1/γ, so T^i = (-1)^i / γ^i
    % But we absorb one factor of γ into the definition of y, giving γ^(-(i-1))
    gsign = "(-1)^("+(i+1)+")";
    greps = gsign + "*gamma^(-" + (i) + ")";
    S1 = replace(S1, "T^" + i, greps);
end

% Replace remaining T (first power) and x(t) terms
% T^1 doesn't have an explicit "^1" in the string, so we handle it separately
S1 = replace(S1, "T", "gamma^(-1)");

% Replace x_j(t) with corresponding y-variable (position block)
% x1(t) → y1, x2(t) → y2, etc.
S1 = replace(S1, "x" + (1:ninputs) + "(t)", string(y(1:ninputs))');

%% ========================================================================
%  CONVERT BACK TO SYMBOLIC (THE EXPENSIVE STEP)
%  ========================================================================
% This is the MOST time/computationally intensive step of the whole
% decompilation scheme. It MUST be run if either:
%   - The NUMBER OF INPUTS to the network changes
%   - The JET ORDER changes
%
% All other changes (B, r_star, x_star, gamma, decompilation_order) can
% use the cached result.

symbolic_jet_expansion(y) = str2sym(S1);

%% ========================================================================
%  CACHE THE RESULT
%  ========================================================================

obj.symbolic_jet_equation_ = symbolic_jet_expansion;
obj.jet_cache_valid_       = true;

if obj.verbose
    fprintf('jet_expansion_: Done (%.2f sec)\n', toc);
end

end