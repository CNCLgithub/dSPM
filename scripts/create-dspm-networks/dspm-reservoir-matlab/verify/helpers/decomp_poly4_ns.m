function [Pd1, C1, C2, C3a, C3b, C4a, C4b, C4c] = decomp_poly4_ns(A, B, rs, dv, gam, o)
% DECOMP_POLY4_NS  Fourth-order jet decompilation of reservoir into polynomial basis
%
% USAGE:
%   [Pd1, C1, C2, C3a, C3b, C4a, C4b, C4c] = decomp_poly4_ns(A, B, rs, dv, gam, o)
%
% INPUTS:
%   A    - N × N recurrent connectivity matrix
%   B    - N × k input matrix (k inputs)
%   rs   - N × 1 equilibrium point of the RNN
%   dv   - N × 1 effective bias vector: A*rs + B*xs + d
%   gam  - Time constant γ of the RNN
%   o    - Order of the Taylor series in x (typically 3-6)
%
% OUTPUTS:
%   Pd1  - p × k matrix of polynomial exponents
%   C1   - N × p coefficients for zeroth-order time expansion (r term)
%   C2   - N × p × k coefficients for first time derivative (ṙ term)
%   C3a  - N × p × ? coefficients for ẍ² contribution to r̈
%   C3b  - N × p × k coefficients for ẍ contribution to r̈  
%   C4a  - N × p × ? coefficients for ẍ³ contribution to r⃛
%   C4b  - N × p × ? coefficients for ẍ·ẍ contribution to r⃛
%   C4c  - N × p × k coefficients for ẍ contribution to r⃛
%
% NOTE: This implements the full 4th-order jet expansion for the reservoir
%       dynamics, capturing the relationship between input time derivatives
%       and reservoir state.
%
%       r(t) ≈ h(x, ẋ, ẍ, ẍ) where each coefficient captures different
%       orders of input time derivatives.
%
% See also: decomp_poly1_ns, deriv2shift, sym2deriv

    %% Base parameters
    N = size(A, 1);    % Number of neurons
    k = size(B, 2);    % Number of inputs

    %% Build polynomial index grid Pd1
    v = reshape(eye(k), [1, k, k]);
    Pd1 = eye(k);

    for i = 2:(o-1)
        Pdp = Pd1 + v;
        Pdp = permute(Pdp, [2, 1, 3]);
        Pdp = reshape(Pdp, [k, size(Pdp, 2) * size(Pdp, 3)])';
        Pd1 = unique([Pd1; Pdp], 'rows', 'stable');
    end

    % Add constant term and sort
    Pd1 = [zeros(1, k); Pd1];
    [~, sI1] = sort(max(Pd1, [], 2));
    [~, sI1a] = sort(sum(Pd1(sI1, :), 2));
    sI1 = sI1(sI1a);
    Pd1 = Pd1(sI1, :);

    %% Compute coefficients
    Ars = A * rs;

    % Compute higher order B terms
    Bk = cell(o, 1);
    Bc = cell(o, 1);
    for i = 1:(o-1)
        PdI = find(sum(Pd1, 2) == i);
        Bk{i} = zeros(N, length(PdI));
        Bc{i} = zeros(1, length(PdI));
        for j = 1:length(PdI)
            Bk{i}(:, j) = prod(B.^Pd1(PdI(j), :), 2);
            Bc{i}(1, j) = factorial(i) / prod(factorial(Pd1(PdI(j), :)));
        end
    end

    % Tanh derivatives (need extra orders for jet expansion)
    D = tanh_deriv(dv, o + 4);
    DD = D(:, 2:end) .* Ars - D(:, 1:end-1);

    % Prefactor matrices
    As = (1 - tanh(dv).^2) .* A - eye(N);   % (A* - I)
    AsI = inv(As);                           % (A* - I)^{-1}
    AsI2 = AsI * AsI;                        % (A* - I)^{-2}
    AsI3 = AsI2 * AsI;                       % (A* - I)^{-3}
    AsI4 = AsI3 * AsI;                       % (A* - I)^{-4}

    % Build multi-derivative terms
    CM = reshape(DD(:, 1:4), [N, 1, 4]);
    for j = 2:o
        CM = cat(2, CM, reshape(DD(:, (0:3) + j), [N, 1, 4]) .* ...
                       (Bc{j-1} .* Bk{j-1}) / factorial(j-1));
    end

    %% Coefficient computations with correct signs and factorial divisors
    % (Daniel's corrections to Jason's original code)

    % C1: zeroth-order time term (just r dependence on x)
    C1 = As \ CM(:, :, 1);

    % C2: first time derivative term (ṙ contribution)
    C2 = pagemtimes(AsI2, CM(:, :, 2) .* ...
         reshape(Bc{1} .* Bk{1}, [N, 1, size(Bk{1}, 2)]) / gam);

    % C3b: second time derivative contribution from ẍ (with 1/2! factor)
    C3b = -pagemtimes(AsI, C2) / (gam * 2);

    % C4c: third time derivative contribution (with 1/3! factor via recursion)
    C4c = -pagemtimes(AsI, C3b) / (gam * 3);

    % C3a: ẋ² terms (with correct sign and 1/2! factor)
    C3a = -pagemtimes(AsI3, CM(:, :, 3) .* ...
          reshape(Bc{2} .* Bk{2}, [N, 1, size(Bk{2}, 2)]) / (gam^2 * 2));

    % C4b: mixed ẍ·ẋ terms
    C4b = pagemtimes(AsI4, CM(:, :, 3) .* ...
          reshape(Bk{2}, [N, 1, size(Bk{2}, 2)]) / (gam^3 * 2));

    % C4a: ẋ³ terms (with 1/3! factor)
    C4a = pagemtimes(AsI4, CM(:, :, 4) .* ...
          reshape(Bc{3} .* Bk{3}, [N, 1, size(Bk{3}, 2)]) / (gam^3 * 6));
end
