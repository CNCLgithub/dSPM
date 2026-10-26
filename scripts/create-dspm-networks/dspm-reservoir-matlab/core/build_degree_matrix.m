function degrees = build_degree_matrix(k, max_order)
% BUILD_DEGREE_MATRIX  Generate matrix of monomial exponents
%
% Creates a matrix where each row represents the exponents of a monomial
% in k variables up to a given total degree.
%
% Monomials are ordered by total degree, then lexicographically.
% Example for k=2, max_order=2:
%   Row 1: [0,0] → 1
%   Row 2: [1,0] → x₁
%   Row 3: [0,1] → x₂
%   Row 4: [2,0] → x₁²
%   Row 5: [1,1] → x₁x₂
%   Row 6: [0,2] → x₂²
%
% Inputs:
%   k         - Number of variables
%   max_order - Maximum total polynomial degree
%
% Outputs:
%   degrees   - (n_mono × k) matrix of exponents
%
% Example:
%   degrees = build_degree_matrix(3, 2);
%   % Returns 10 monomials: 1, x1, x2, x3, x1^2, x1*x2, x1*x3, x2^2, x2*x3, x3^2

    % Count total monomials: nchoosek(k + max_order, k)
    n_mono = nchoosek(k + max_order, k);
    degrees = zeros(n_mono, k);
    
    row = 1;
    
    % Generate monomials by total degree
    for total_deg = 0:max_order
        % Generate all partitions of total_deg into k non-negative integers
        exponents = partitions_with_zeros(total_deg, k);
        
        n_exp = size(exponents, 1);
        degrees(row:row+n_exp-1, :) = exponents;
        row = row + n_exp;
    end
end

function P = partitions_with_zeros(n, k)
% PARTITIONS_WITH_ZEROS  All ways to write n as sum of k non-negative integers
%
% Returns partitions in reverse lexicographic order (largest first)
% This gives a consistent ordering: [n,0,0,...], [n-1,1,0,...], etc.

    if k == 1
        P = n;
        return;
    end
    
    % Count: nchoosek(n + k - 1, k - 1)
    n_partitions = nchoosek(n + k - 1, k - 1);
    P = zeros(n_partitions, k);
    
    row = 1;
    for first = n:-1:0
        % Recursively partition the remainder into k-1 parts
        rest = partitions_with_zeros(n - first, k - 1);
        n_rest = size(rest, 1);
        
        P(row:row+n_rest-1, 1) = first;
        P(row:row+n_rest-1, 2:k) = rest;
        row = row + n_rest;
    end
end
