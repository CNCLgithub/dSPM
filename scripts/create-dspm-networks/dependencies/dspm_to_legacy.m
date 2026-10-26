function basernn = dspm_to_legacy(res, W_full, A_base)
% DSPM_TO_LEGACY  Package a programmed dspm_reservoir as the open-loop
% ReservoirTanhB_dc that run_rnn_trials / prnnvars expect.
%
%   basernn = dspm_to_legacy(res, W_full)
%   basernn = dspm_to_legacy(res, W_full, A_base)
%
% run_rnn_trials consumes the OPEN-loop base network and closes it itself:
%   basernn.train(...)                  conditioning burn-in (A = A_base)
%   A + B(:,1:12)*W(1:12,:), B(:,13)    closed pRNN with paddle drive
% so this returns the pre-closure tuple, not res.A.
%
% Inputs
%   res     programmed dspm_reservoir (12 rec + 1 ext ports)
%   W_full  13 x N readout: 12 compiled rows + paddle passthrough row
%   A_base  N x N base adjacency (default sparse zeros). For
%           connectivity="random" this is the random matrix. As in the old
%           getexpansion/program_rnn, d is computed with A = 0 and A_base is
%           attached afterwards.

N = res.n_neurons;
if nargin < 3 || isempty(A_base), A_base = sparse(N, N); end

B  = res.B;
rs = res.r_star;
xs = zeros(size(B, 2), 1);

basernn = ReservoirTanhB_dc(sparse(N, N), B, rs, xs, res.dt, res.gamma);

% d from the legacy constructor must equal the package's identity value
err = norm(basernn.d - res.d_star, inf);
if err > 1e-10
    error('dspm_to_legacy:identity', ...
        'Legacy d differs from res.d_star by %.2e; x_star or A0 is nonzero.', err);
end

basernn.A = A_base;
basernn.r = rs;
basernn.W = W_full;

% Decompiled artifacts (informational; nothing downstream reads them)
basernn.weights      = res.decompiled_weight_matrix;
basernn.bases_map    = table2array(removevars(res.symbolic_basis_mapping, 'Physical'));
basernn.shift_matrix = [];

end
