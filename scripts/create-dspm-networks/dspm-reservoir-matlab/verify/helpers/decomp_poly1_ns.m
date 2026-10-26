function [Pd1, C1] = decomp_poly1_ns(A, B, rs, dv, o)
% DECOMP_POLY1_NS  First-order decompilation of reservoir into polynomial basis
%
% USAGE:
%   [Pd1, C1] = decomp_poly1_ns(A, B, rs, dv, o)
%
% INPUTS:
%   A    - N × N recurrent connectivity matrix
%   B    - N × k input matrix (k inputs)
%   rs   - N × 1 equilibrium point of the RNN
%   dv   - N × 1 effective bias vector: A*rs + B*xs + d
%   o    - Order of the Taylor series in x (typically 3-6)
%
% OUTPUTS:
%   Pd1  - p × k matrix of polynomial exponents (each row is [a1,a2,...,ak])
%          representing monomial x1^a1 * x2^a2 * ... * xk^ak
%   C1   - N × p coefficient matrix mapping monomials to neuron states
%
% NOTE: This implements the zeroth-order time expansion (just ṙ term),
%       suitable for static computations. For dynamics requiring time
%       derivatives, use decomp_poly4_ns instead.
%
% The decompilation solves:
%   (A* - I) * C1 = RHS
% where A* = diag(1-tanh²(dv)) * A
%
% See also: decomp_poly4_ns, tanh_deriv

    %% Base parameters
    N = size(A, 1);    % Number of neurons
    k = size(B, 2);    % Number of inputs

    %% Build polynomial index grid Pd1
    % Enumerate all monomials up to total degree (o-1)
    v = reshape(eye(k), [1, k, k]);
    Pd1 = eye(k);

    for i = 2:(o-1)
        Pdp = Pd1 + v;
        Pdp = permute(Pdp, [2, 1, 3]);
        Pdp = reshape(Pdp, [k, size(Pdp, 2) * size(Pdp, 3)])';
        Pd1 = unique([Pd1; Pdp], 'rows', 'stable');
    end

    % Add constant term and sort by degree
    Pd1 = [zeros(1, k); Pd1];
    [~, sI1] = sort(max(Pd1, [], 2));
    [~, sI1a] = sort(sum(Pd1(sI1, :), 2));
    sI1 = sI1(sI1a);
    Pd1 = Pd1(sI1, :);

    %% Compute coefficients
    Ars = A * rs;

    % Compute higher order B terms (B^exponents for each monomial)
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

    % Tanh derivatives at operating point
    D = tanh_deriv(dv, o + 1);
    DD = D(:, 2:end) .* Ars - D(:, 1:end-1);

    % Prefactor matrix: A* - I where A* = diag(sech²(dv)) * A
    As = (1 - tanh(dv).^2) .* A - eye(N);

    % Build RHS: higher derivative terms scaled by B products
    CM = DD(:, 1);
    for j = 2:o
        CM = cat(2, CM, DD(:, j) .* (Bc{j-1} .* Bk{j-1}) / factorial(j-1));
    end

    % Solve linear system: As * C1 = CM
    C1 = As \ CM;
end
