function R = gen_basis(Aa, PdS)
% GEN_BASIS  Generate polynomial basis by recursive shift application
%
% USAGE:
%   R = gen_basis(Aa, PdS)
%
% INPUTS:
%   Aa   - N × p matrix of initial coefficients (modified by A, B, d)
%   PdS  - p × p shift matrix encoding polynomial multiplication
%
% OUTPUTS:
%   R    - N × p matrix representing the full polynomial basis
%
% NOTE: This function generates the decompiled representation by 
%       recursively applying the shift matrix to build up all monomial
%       terms. The shift matrix encodes: PdS(i,j) = k means that
%       monomial_i * monomial_j = monomial_k
%
% The algorithm:
%   1. Start with Aa as the base coefficients
%   2. For each order, shift existing terms to generate higher-order terms
%   3. Accumulate all terms into the final basis R
%
% See also: deriv2shift, sym2deriv, decomp_poly4_ns

    [N, p] = size(Aa);
    R = Aa;
    
    % Determine maximum order from shift matrix structure
    % The shift matrix has non-zero entries for valid polynomial products
    max_order = floor(log2(p)) + 2;  % Conservative estimate
    
    % Iteratively build higher-order terms
    Rcurr = Aa;
    for order = 2:max_order
        Rnext = zeros(N, p);
        for i = 1:p
            pd = PdS(i, :);
            pdi = find(pd);
            if ~isempty(pdi)
                pd = pd(pdi);
                Rnext(:, pd) = Rnext(:, pd) + Rcurr(:, pdi) .* Aa(:, i)';
            end
        end
        
        % Check for convergence (no new significant terms)
        if norm(Rnext, 'fro') < 1e-14 * norm(R, 'fro')
            break;
        end
        
        R = R + Rnext;
        Rcurr = Rnext;
    end
end
