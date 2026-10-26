function [D] = tanh_deriv(d, n)
% TANH_DERIV  Compute derivatives of tanh function at points d
%
% USAGE:
%   D = tanh_deriv(d, n)
%
% INPUTS:
%   d - Vector of input values (N × 1)
%   n - Order of derivatives to compute (scalar)
%
% OUTPUTS:
%   D - Matrix of outputs (N × n), where D(:,k) = d^(k-1)/dx^(k-1) tanh(x)|_{x=d}
%
% EXAMPLE:
%   D = tanh_deriv([0; 0.5; 1], 4);
%   % D(:,1) = tanh(d)
%   % D(:,2) = sech²(d) 
%   % D(:,3) = -2*tanh(d)*sech²(d)
%   % D(:,4) = ...
%
% NOTE: Uses symbolic differentiation then evaluates numerically.
%       For large vectors, this is the main computational cost.
%
% See also: decomp_poly4_ns, decomp_poly1_ns

    % Validate inputs
    arguments
        d (:,1) double
        n (1,1) {mustBePositive, mustBeInteger}
    end
    
    % Use symbolic computation for derivatives
    syms z real
    D_sym = tanh(z);
    
    for i = 2:n
        D_sym(:,i) = diff(D_sym(:,i-1));
    end
    
    % Convert to function handle and evaluate
    Df = matlabFunction(D_sym);
    D = Df(d);
end
