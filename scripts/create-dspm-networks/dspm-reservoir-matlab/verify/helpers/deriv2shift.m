function XC = deriv2shift(C, DX, Pd1, PdS)
% DERIV2SHIFT  Shift Taylor series coefficients by time derivative
%
% USAGE:
%   XC = deriv2shift(C, DX, Pd1, PdS)
%
% INPUTS:
%   C    - N × p × q matrix of coefficients of Taylor series expansion
%   DX   - q × p matrix of weights determined by time derivative
%   Pd1  - p × k matrix of polynomial basis terms as powers of k inputs
%   PdS  - p × p shift matrix for polynomial multiplication
%
% OUTPUTS:
%   XC   - N × p × q matrix of shifted coefficients
%
% NOTE: This function implements the multiplication of a polynomial 
%       expansion by a time derivative in the monomial basis. The shift
%       matrix PdS encodes how monomials multiply together.
%
% See also: sym2deriv, decomp_poly4_ns

    XC = zeros(size(C));
    
    for i = 1:size(Pd1, 1)
        pd = PdS(i, :);
        pdi = find(pd);
        pd = pd(pdi);
        XC(:, pd, :) = XC(:, pd, :) + C(:, pdi, :) .* reshape(DX(:, i), [1, 1, size(DX, 1)]);
    end
end
