function [P, report] = pong_program_matrix(res, dx, xvars, tau)
% PONG_PROGRAM_MATRIX  DNP program matrix P = e_i + f_i/(gamma*tau_i), keyed
% by exponent vector against the decompiled basis.
%
%   [P, report] = pong_program_matrix(res, dx, xvars)
%   [P, report] = pong_program_matrix(res, dx, xvars, tau)
%
% Same math as dspm_reservoir.buildProgramMatrixSymbolic, but matches each
% monomial of dx to a column of R by its exponent vector (from
% res.symbolic_basis_mapping) instead of by string. The string path in the
% package (sym2colstr -> getColumnIndex) does not currently match:
%   * repeated factors: sym2colstr emits "y1*y1*y1", the basis stores "y1^3"
%   * two-digit indices: normalizeTermString rewrites "x1" inside "x13"
% and pong has both (x5^3, x9^3, x9^2*x6, x13*x4*x9, ...). Unmatched terms
% are warned and dropped there; here they are a hard error.
%
% Inputs
%   res    decompiled dspm_reservoir (jet_order 1 or higher)
%   dx     m_rec x 1 sym, recurrent dynamics
%   xvars  n_inputs x 1 sym, [recurrent states ; drive ports] in port order
%   tau    optional m_rec x 1 time scales (default ones)
%
% Outputs
%   P       m_rec x K
%   report  struct: .n_terms per row, .max_basis_degree

if isempty(res.decompiled_weight_matrix)
    error('pong_program_matrix:notDecompiled', 'Call res.decompile() first.');
end

dx    = dx(:);
xvars = xvars(:);
neq   = numel(dx);
nin   = res.n_inputs;
gam   = res.gamma;

if numel(xvars) ~= nin
    error('pong_program_matrix:varCount', ...
        'xvars has %d symbols but the reservoir has %d ports.', numel(xvars), nin);
end
if nargin < 4 || isempty(tau), tau = ones(neq, 1); end
tau = tau(:);

% Exponent table: K x (jet_order*n_inputs). The position block is the first
% n_inputs columns; pong only uses positions, so every higher jet column of
% a matched row must be zero.
tbl = res.symbolic_basis_mapping;
E   = table2array(removevars(tbl, 'Physical'));
K   = size(E, 1);
Epos = E(:, 1:nin);
pure = all(E(:, nin+1:end) == 0, 2);

report.max_basis_degree = max(sum(E, 2));
report.n_terms          = zeros(neq, 1);

P = zeros(neq, K);
missing = strings(0);

for i = 1:neq
    expr = expand(dx(i));

    if ~isequal(expr, sym(0))
        [cf, mons] = coeffs(expr, xvars);
        for j = 1:numel(mons)
            e = zeros(1, nin);
            for k = 1:nin
                e(k) = polynomialDegree(mons(j), xvars(k));
            end
            col = find(pure & all(Epos == e, 2));
            if isempty(col)
                missing(end+1) = sprintf("row %d: %s", i, char(mons(j))); %#ok<AGROW>
                continue
            end
            P(i, col) = P(i, col) + double(cf(j)) / (gam * tau(i));
        end
        report.n_terms(i) = numel(mons);
    end

    % identity term e_i (state i reads itself out)
    e = zeros(1, nin); e(i) = 1;
    col = find(pure & all(Epos == e, 2));
    P(i, col) = P(i, col) + 1;
end

if ~isempty(missing)
    error('pong_program_matrix:unmappedMonomial', ...
        ['%d monomial(s) of dx are not in the decompiled basis (basis max degree %d). ' ...
         'Raise decompilation_order.\n  %s'], ...
        numel(missing), report.max_basis_degree, strjoin(missing, "\n  "));
end

end
