function [GAM, DX, DDX, DDDX, DXDX, DXDXDX, DDXDX] = sym2deriv(dx, x, pr, Pd1, PdS)
% SYM2DERIV  Convert symbolic dynamics to derivative coefficient matrices
%
% USAGE:
%   [GAM, DX, DDX, DDDX, DXDX, DXDXDX, DDXDX] = sym2deriv(dx, x, pr, Pd1, PdS)
%
% INPUTS:
%   dx   - Symbolic equations of motion (n × 1 symbolic)
%   x    - Symbolic base variables (n × 1 symbolic)
%   pr   - List of prime numbers to uniquely identify monomials
%   Pd1  - p × k matrix of p polynomial basis terms as powers of k inputs
%   PdS  - p × p shift matrix for polynomial multiplication
%
% OUTPUTS:
%   GAM    - Full derivative map (p × p)
%   DX     - First derivative coefficients (n × p)
%   DDX    - Second derivative (n × p)
%   DDDX   - Third derivative (n × p)
%   DXDX   - First derivative squared (for quadratic terms)
%   DXDXDX - First derivative cubed (for cubic terms)
%   DDXDX  - Mixed second and first derivative
%
% NOTE: Uses prime number encoding to uniquely identify monomials.
%       Each monomial x1^a * x2^b * ... has ID = prod(pr.^[a,b,...])
%
% See also: deriv2shift, decomp_poly4_ns

    % Prime encoding for monomial identification
    pri = prod((pr').^Pd1, 2);
    
    % Obtain coefficients for the first derivative
    DX = zeros(length(dx), length(pri));
    for i = 1:length(dx)
        % Extract each term and coefficient in dx
        [a, b] = coeffs(dx(i)); 
        a = double(a);
        % Numerically fast way to identify each term
        bs = double(subs(b, x, pr));
        [ai, ~] = find(bs - pri == 0);
        DX(i, ai) = a;
    end
    
    % Obtain the full map GAM
    % This maps how each monomial transforms under the dynamics
    GAM = zeros(length(pri));
    for i = 2:size(Pd1, 1)
        p = Pd1(i, :); 
        pi = find(p);
        for j = 1:length(pi)
            ps = p;
            ps(pi(j)) = ps(pi(j)) - 1;
            pd = PdS(pri - prod(pr'.^ps) == 0, :);
            pdi = find(pd);
            pd = pd(pdi);
            GAM(i, pd) = GAM(i, pd) + p(pi(j)) * DX(pi(j), pdi);
        end
    end
    
    % Second derivative: DDX = DX * GAM
    DDX = DX * GAM;
    
    % Third derivative: DDDX = DDX * GAM
    DDDX = DDX * GAM;
    
    % Prepare product terms for higher-order combinations
    pd1i = find(sum(Pd1, 2) == 1); 
    Pd1p = Pd1(pd1i, :);
    pd2i = find(sum(Pd1, 2) == 2); 
    Pd2p = Pd1(pd2i, :);
    pd3i = find(sum(Pd1, 2) == 3); 
    Pd3p = Pd1(pd3i, :);
    
    % First derivative squared (DXDX)
    ppi = zeros(length(pd2i), 2);
    DXDX = zeros(length(pd2i), size(Pd1, 1));
    for i = 1:length(pd2i)
        p = Pd1(pd2i(i), :);
        pf = zeros(1, length(p));
        for j = 1:1
            f = find(p, 1);
            pf(f) = pf(f) + 1;
            p(f) = p(f) - 1;
        end
        ppi(i, :) = [find(prod(Pd1p == p, 2)), find(prod(Pd1p == pf, 2))];
    end
    for i = 1:size(Pd1, 1)
        pd = PdS(i, :);
        pdi = find(pd);
        pd = pd(pdi);
        DXDX(:, pd) = DXDX(:, pd) + DX(ppi(:, 1), pdi) .* DX(ppi(:, 2), i);
    end
    
    % First derivative cubed (DXDXDX)
    ppi = zeros(length(pd3i), 2);
    DXDXDX = zeros(length(pd3i), size(Pd1, 1));
    for i = 1:length(pd3i)
        p = Pd1(pd3i(i), :);
        pf = zeros(1, length(p));
        for j = 1:1
            f = find(p, 1);
            pf(f) = pf(f) + 1;
            p(f) = p(f) - 1;
        end
        ppi(i, :) = [find(prod(Pd2p == p, 2)), find(prod(Pd1p == pf, 2))];
    end
    for i = 1:size(Pd1, 1)
        pd = PdS(i, :);
        pdi = find(pd);
        pd = pd(pdi);
        DXDXDX(:, pd) = DXDXDX(:, pd) + DXDX(ppi(:, 1), pdi) .* DX(ppi(:, 2), i);
    end
    
    % Mixed second and first derivative (DDXDX)
    ppi = zeros(length(pd2i), 2);
    ppic = ones(length(pd2i), 1);
    DDXDX = zeros(length(pd2i), size(Pd1, 1));
    for i = 1:length(pd2i)
        p = Pd1(pd2i(i), :);
        pf = zeros(1, length(p));
        for j = 1:1
            f = find(p, 1);
            pf(f) = pf(f) + 1;
            p(f) = p(f) - 1;
        end
        ppi(i, :) = [find(prod(Pd1p == p, 2)), find(prod(Pd1p == pf, 2))];
        if ppi(i, 1) == ppi(i, 2)
            ppic(i) = 0.5;
        end
    end
    for i = 1:size(Pd1, 1)
        pd = PdS(i, :);
        pdi = find(pd);
        pd = pd(pdi);
        DDXDX(:, pd) = DDXDX(:, pd) + ppic .* (DDX(ppi(:, 1), pdi) .* DX(ppi(:, 2), i) + ...
                                                DDX(ppi(:, 2), pdi) .* DX(ppi(:, 1), i));
    end
end
