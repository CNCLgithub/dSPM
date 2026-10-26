function [Pd, C1, C2, C3a, C3b, C4a, C4b, C4c] = decomp_poly4_ns_refactored(A, B, r_star, d_eff, gamma, poly_order)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DECOMP_POLY4_NS  Decompose reservoir into polynomial jet expansion
%
% Computes the Taylor expansion coefficients for the reservoir response
% r(t) ≈ h(x, ẋ, ẍ, x⃛) as a polynomial in position and time derivatives.
%
% The reservoir dynamics are:
%   (1/γ) ṙ = -r + tanh(A·r + B·x + d)
%
% At quasi-steady state with time-varying input x(t), the reservoir
% "sees" a weighted history of the input trajectory. Expanding x(t-τ)
% where τ = 1/γ is the memory timescale:
%
%   x(t-τ) ≈ x - τẋ + (τ²/2!)(∂²x) - (τ³/3!)(∂³x) + ...
%
% This function computes coefficients for each jet order:
%   C1:  Position only (static response)
%   C2:  First time derivative (ẋ)
%   C3a: Second time derivative via ẋᵢẋⱼ products
%   C3b: Second time derivative via ẍ directly
%   C4a: Third time derivative via ẋᵢẋⱼẋₖ products
%   C4b: Third time derivative via ẍᵢẋⱼ products
%   C4c: Third time derivative via x⃛ directly
%
% INPUTS:
%   A          - [N × N] Recurrent connectivity matrix
%   B          - [N × k] Input weight matrix (k inputs)
%   r_star     - [N × 1] Fixed point of reservoir state
%   d_eff      - [N × 1] Effective bias: A*r_star + B*x_star + d
%   gamma      - [1 × 1] Time constant (inverse memory timescale)
%   poly_order - [1 × 1] Order of polynomial expansion in x
%
% OUTPUTS:
%   Pd   - [p × k] Monomial degree matrix (p monomials, k inputs)
%   C1   - [N × p] Static coefficients
%   C2   - [N × p × k] First jet order coefficients
%   C3a  - [N × p × k(k+1)/2] Second jet order (ẋẋ terms)
%   C3b  - [N × p × k] Second jet order (ẍ terms)
%   C4a  - [N × p × ?] Third jet order (ẋẋẋ terms)
%   C4b  - [N × p × ?] Third jet order (ẍẋ terms)
%   C4c  - [N × p × k] Third jet order (∂³x terms)
%
% MATHEMATICAL BACKGROUND:
%
% The Jacobian of the reservoir dynamics at the fixed point is:
%   J = sech²(d_eff) ⊙ A - I
%
% where ⊙ denotes element-wise multiplication. The inverse of this
% Jacobian (and its powers) appear in the quasi-steady-state expansion.
%
% For A = 0 (no recurrence), J = -I, so:
%   J⁻¹ = -I,  J⁻² = +I,  J⁻³ = -I,  J⁻⁴ = +I, ...
%
% This alternating sign pattern requires careful handling in the
% coefficient computations below.
%
% HISTORY:
%   Original: Jason Kim (Kim & Bassett 2023)
%   Bugfixes: Daniel Calbick [2025] - Added missing Taylor factorials (1/n!)
%             and corrected sign handling for odd Jacobian powers
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Dimensions
N = size(A, 1);      % Number of neurons
k = size(B, 2);      % Number of input variables

%% =======================================================================
%  STEP 1: Build monomial degree matrix Pd
%  =======================================================================
%  Pd is a [p × k] matrix where each row defines a monomial:
%    Pd(i,:) = [d1, d2, ..., dk] means x1^d1 * x2^d2 * ... * xk^dk
%
%  We enumerate all monomials up to total degree (poly_order - 1)

% Start with degree-1 monomials (just the k unit vectors)
Pd = eye(k);

% Incrementally build higher degree monomials
unit_vectors = reshape(eye(k), [1, k, k]);  % [1 × k × k] for broadcasting

for degree = 2:(poly_order - 1)
    % Add each unit vector to existing monomials
    Pd_extended = Pd + unit_vectors;                    % [p × k × k]
    Pd_extended = permute(Pd_extended, [2, 1, 3]);      % [k × p × k]
    Pd_extended = reshape(Pd_extended, [k, size(Pd_extended,2) * k])';  % [p*k × k]
    
    % Keep unique monomials
    Pd = unique([Pd; Pd_extended], 'rows', 'stable');
end

% Add constant term (all zeros) at the beginning
Pd = [zeros(1, k); Pd];

% Sort by maximum degree, then by total degree
[~, sort_by_max] = sort(max(Pd, [], 2));
[~, sort_by_sum] = sort(sum(Pd(sort_by_max, :), 2));
sort_indices = sort_by_max(sort_by_sum);
Pd = Pd(sort_indices, :);


%% =======================================================================
%  STEP 2: Precompute B-monomial products and multinomial coefficients
%  =======================================================================
%  For each degree d, we need:
%    B_monomials{d}(:,j) = ∏ᵢ Bᵢ^(Pd(j,i))  (element-wise product of B columns)
%    multinomial_coeffs{d}(j) = d! / ∏ᵢ (Pd(j,i)!)  (multinomial coefficient)

B_monomials        = cell(poly_order, 1);
multinomial_coeffs = cell(poly_order, 1);

for degree = 1:(poly_order - 1)
    % Find monomials of this total degree
    monomial_indices = find(sum(Pd, 2) == degree);
    n_degree_monomials = length(monomial_indices);
    
    B_monomials{degree} = zeros(N, n_degree_monomials);
    multinomial_coeffs{degree} = zeros(1, n_degree_monomials);
    
    for j = 1:n_degree_monomials
        idx = monomial_indices(j);
        exponents = Pd(idx, :);
        
        % Product of B columns raised to exponents: ∏ᵢ Bᵢ^eᵢ
        B_monomials{degree}(:, j) = prod(B .^ exponents, 2);
        
        % Multinomial coefficient: d! / (e₁! e₂! ... eₖ!)
        multinomial_coeffs{degree}(1, j) = factorial(degree) / prod(factorial(exponents));
    end
end

%% =======================================================================
%  STEP 3: Compute tanh derivatives at the operating point
%  =======================================================================
%  D(:,n) = (d^n/dx^n) tanh(x) evaluated at x = d_eff
%  We need derivatives up to order (poly_order + 4) for the jet expansion

tanh_derivs = tanh_deriv(d_eff, poly_order + 4);

% DD combines the derivatives with the recurrent term A*r_star
% This appears in the chain rule when differentiating tanh(A*r + B*x + d)
A_times_r_star = A * r_star;
DD = tanh_derivs(:, 2:end) .* A_times_r_star - tanh_derivs(:, 1:end-1);

%% =======================================================================
%  STEP 4: Compute Jacobian and its inverse powers
%  =======================================================================
%  The Jacobian at the fixed point is:
%    J = sech²(d_eff) ⊙ A - I
%
%  For the quasi-steady-state expansion, we need J⁻¹, J⁻², J⁻³, J⁻⁴
%
%  IMPORTANT: For A = 0, J = -I, so:
%    J⁻¹ = -I  (sign flip)
%    J⁻² = +I  (no sign flip)
%    J⁻³ = -I  (sign flip)
%    J⁻⁴ = +I  (no sign flip)
%
%  The sign alternation affects which tensors need negation below.

sech_squared = 1 - tanh(d_eff).^2;         % sech²(d_eff)
Jacobian     = sech_squared .* A - eye(N); % J = sech² ⊙ A - I

J_inv   = inv(Jacobian);    % J⁻¹  (sign flip for A=0)
J_inv_2 = J_inv * J_inv;    % J⁻²  (no flip for A=0)
J_inv_3 = J_inv_2 * J_inv;  % J⁻³  (sign flip for A=0)
J_inv_4 = J_inv_3 * J_inv;  % J⁻⁴  (no flip for A=0)

%% =======================================================================
%  STEP 5: Build coefficient matrix CM for different derivative orders
%  =======================================================================
%  CM(:, :, d) contains the d-th derivative contributions
%  Dimensions: [N × n_monomials × 4] (we need up to 4th derivative)

% Start with constant term
coefficient_matrix = reshape(DD(:, 1:4), [N, 1, 4]);  

for degree = 2:poly_order
    % Contribution from degree-(degree-1) monomials
    Bc = multinomial_coeffs{degree - 1};
    Bk = B_monomials{degree - 1};
    
    % The factorial(degree-1) is the spatial Taylor coefficient
    derivative_contrib = reshape(DD(:, (0:3) + degree), [N, 1, 4]);
    monomial_contrib   = (Bc .* Bk) / factorial(degree - 1);
    
    coefficient_matrix = cat(2, coefficient_matrix, derivative_contrib .* monomial_contrib);
end

%% =======================================================================
%  STEP 6: Compute jet expansion coefficients
%  =======================================================================
%
%  The Taylor series in time is:
%    h(t-τ) = h - τh' + (τ²/2!)h'' - (τ³/3!)h''' + ...
%
%  where τ = 1/γ. The coefficients below implement this expansion.
%
%  CRITICAL: The (1/n!) Taylor factors were missing in the original code!
%  Also, odd powers of J_inv introduce sign flips that must be corrected.

%% ----- C1: Static response (zeroth jet order) -----

% No time derivatives, just the polynomial expansion in x
C1 = Jacobian \ coefficient_matrix(:, :, 1);

%% ----- C2: First jet order (ẋ terms) -----

% Coefficient: 1/(1! · γ) = 1/γ
% Uses J⁻² (no sign flip for A=0)
Bc1 = multinomial_coeffs{1};
Bk1 = B_monomials{1};
n_monomials_deg1 = size(Bk1, 2);

tanh_deriv_contrib    = coefficient_matrix(:, :, 2);
monomial_factor       = reshape(Bc1 .* Bk1, [N, 1, n_monomials_deg1]);
taylor_factor_order1  = 1 / gamma;  % 1/(1! · γ)

expansion_terms = tanh_deriv_contrib .* monomial_factor * taylor_factor_order1;
C2 = pagemtimes(J_inv_2, expansion_terms); % applies prefactor

%% ----- C3b: Second jet order, pure ∂²x terms -----
% Coefficient: 1/(2! · γ²) = 1/(2γ²)
% Uses J⁻¹ via recurrence from C2
% SIGN FLIP required (odd power of J_inv)
taylor_factor_order2 = 1/(gamma * 2);  % Additional 1/(2γ) beyond C2's 1/γ

C3b = -taylor_factor_order2*pagemtimes(J_inv, C2); % NEGATED for sign flip

%% ----- C4c: Third jet order, pure ∂³x terms -----
% Coefficient: 1/(3! · γ³) = 1/(6γ³)
% Uses J⁻¹ via recurrence from C3b
% Recurrence: (1/2) × (1/3) = 1/6 = 1/3!
% SIGN FLIP required (builds on already-flipped C3b, then another J_inv)

taylor_factor_order3 = 1 / (gamma * 3);  % Additional 1/(3γ) beyond C3b

C4c = -taylor_factor_order3*pagemtimes(J_inv, C3b); % NEGATED for sign flip

%% ----- C3a: Second jet order, ẋᵢẋⱼ terms -----
% Coefficient: 1/(2! · γ²) = 1/(2γ²)
% Uses J⁻³ (sign flip for A=0)
Bc2 = multinomial_coeffs{2};
Bk2 = B_monomials{2};
n_monomials_deg2 = size(Bk2, 2);

tanh_deriv_contrib = coefficient_matrix(:, :, 3);
monomial_factor = reshape(Bc2 .* Bk2, [N, 1, n_monomials_deg2]);
taylor_factor_order1 = 1 / (gamma^2 * 2);  % 1/(2! · γ²)

C3a = -pagemtimes(J_inv_3, tanh_deriv_contrib .* monomial_factor * taylor_factor_order1);  % NEGATED

%% ----- C4b: Third jet order, (∂²xᵢ)ẋⱼ terms -----
% Coefficient: 1/(2! · γ³) — the 2! comes from the ẍ factor
% Uses J⁻⁴ (no sign flip for A=0)
% Note: Original code had erroneous factor of 3 here
monomial_factor_no_coeff = reshape(Bk2, [N, 1, n_monomials_deg2]);
taylor_factor_order1 = 1 / (gamma^3 * 2);  % 1/(2! · γ³)

C4b = pagemtimes(J_inv_4, tanh_deriv_contrib .* monomial_factor_no_coeff * taylor_factor_order1);

%% ----- C4a: Third jet order, ẋᵢẋⱼẋₖ terms -----
% Coefficient: 1/(3! · γ³) = 1/(6γ³)
% Uses J⁻⁴ (no sign flip for A=0)

Bc3 = multinomial_coeffs{3};
Bk3 = B_monomials{3};
n_monomials_deg3 = size(Bk3, 2);

tanh_deriv_contrib   = coefficient_matrix(:, :, 4);
monomial_factor      = reshape(Bc3 .* Bk3, [N, 1, n_monomials_deg3]);
taylor_factor_order1 = 1 / (gamma^3 * 6);  % 1/(3! · γ³)

expansion_terms = tanh_deriv_contrib .* monomial_factor * taylor_factor_order1;
C4a = pagemtimes(J_inv_4, expansion_terms);

%% Complete
fprintf('decomp_poly4_ns complete.\n');

end