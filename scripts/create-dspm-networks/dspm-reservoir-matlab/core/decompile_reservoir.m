function [sortedBasis, decompWeights, sortIdx, basisMapping] = decompile_reservoir(obj)
% DECOMPILE_RESERVOIR  Three-stage symbolic Taylor expansion of reservoir dynamics
%
% This is the core computational engine for decompiling a reservoir computer.
% It computes the matrix R such that:
%
%   r(t) ≈ R * φ(y)
%
% where:
%   r(t)  = tanh(B*x(t) + d) is the N-dimensional reservoir state
%   y     = [x; ẋ/γ; ẍ/γ²; ...] is the extended state (jet variables)
%   φ(y)  = [1, y₁, y₂, ..., y₁², y₁y₂, ...] is the monomial basis
%
% THREE-STAGE ARCHITECTURE WITH CACHING
% -------------------------------------
% Stage 1: jet_expansion_()     - EXPENSIVE, cached on (n_inputs, jet_order)
% Stage 2: taylor_expansion_()  - MODERATE, cached on (decompilation_order)
% Stage 3: eval_coefficients_() - CHEAP, runs every time
%
% This means:
%   - Changing B, r_star, x_star, gamma → Only Stage 3 runs (~ms)
%   - Changing decompilation_order → Stages 2+3 run (~100ms)
%   - Changing n_inputs or jet_order → All stages run (~seconds)
%
% INPUTS
%   obj - Reservoir object with fields:
%         .jet_order             - Order of time derivatives
%         .decompilation_order   - Polynomial order for spatial expansion
%         .n_inputs              - Number of input variables
%         .n_neurons             - Number of neurons (N)
%         .gamma                 - Time constant
%         .read_in_matrix_B      - Input weight matrix B (N × n_inputs)
%         .bias                  - Bias vector d (N × 1)
%         .jet_cache_valid_      - Jet cache validity flag
%         .taylor_cache_valid_   - Taylor cache validity flag
%         .verbose               - Print timing info if true
%
% OUTPUTS
%   sortedBasis   - Cell array of monomial strings in canonical order
%   decompWeights - (N × n_mono) decompiled weight matrix R
%   sortIdx       - Permutation indices for sorting
%   basisMapping  - Table with exponent info and physical interpretation
%
% See: Kim & Bassett (2023) "A neural machine code and programming framework
%      for the reservoir computer", Nature Machine Intelligence

%% ========================================================================
%  STAGE 1: JET EXPANSION (checks cache internally)
%  ========================================================================
%  Only runs if n_inputs or jet_order changed since last call.
%  This is the expensive str2sym step.

jet_expansion_(obj);

%% ========================================================================
%  STAGE 2: TAYLOR EXPANSION (checks cache internally)
%  ========================================================================
%  Only runs if decompilation_order changed or jet cache was invalidated.

polynomial_basis_expansion_(obj);

%% ========================================================================
%  STAGE 3: NUMERIC EVALUATION (always runs)
%  ========================================================================
%  Uses cached coefficient strings, evaluates with current B, d, gamma.
%  This is cheap (~ms).

[sortedBasis, decompWeights, sortIdx, basisMapping] = eval_coefficients_(obj);

end  
