%% FIRST_ORDER_SPECTRAL_RADIUS
% Where the large spectral radius of the programmed adjacency comes from.
% Supports Supplementary Section 2: "solving for W against the first-order
% terms alone gives a spectral radius of 1.3 in each of 50 reservoirs
% generated with the same settings".
%
% For each of nNet freshly programmed Pong reservoirs (same settings as the
% paper's: N = 1000, no paddle) this computes
%   rho_full        rho(Ap),               Ap = Brec*W, W solved against the full cubic program
%   rho_star        rho(diag(1-r*^2) Ap),  the same at the analytic operating point
%   rho_first       rho(Brec*W1),          W1 solved against the constant + first-order columns only
%   rho_first_star  rho(diag(1-r*^2) Brec*W1)
% The nonzero eigenvalues of Brec*W equal those of the 12 x 12 matrix W*Brec,
% so the small matrix is used throughout (as in test_spectral_properties.m).
%
% Run from scripts/create-dspm-networks after setup_paths.

%% 0. Settings

nNet      = 50;
nNeurons  = 1000;
seed0     = 100;             % reservoir i uses random_seed = seed0 + i
save_file = "../spectral-properties/first_order_spectral_radius.mat";   % "" to skip

%% 1. Build the reservoirs

prnns = create_and_program_pong_rnns(nNet, nNeurons, "programmed", ...
            paddle_exist = false, keep_dspm = true, random_seed = seed0);

%% 2. Spectral radii

[rho_full, rho_star, rho_first, rho_first_star] = deal(nan(nNet, 1));
lin = 1:14;                  % constant + 13 first-order columns of the basis

for i = 1:nNet
    d      = prnns(i).dspm;
    Brec   = d.B(:, 1:12);
    D_star = 1 - d.r_star.^2;
    R      = d.decompiled_weight_matrix;
    P      = d.compiled_program_matrix;
    W1     = P(:, lin) * pinv(R(:, lin));

    rho_full(i)       = max(abs(eig(d.W * Brec)));
    rho_star(i)       = max(abs(eig(d.W * (D_star .* Brec))));
    rho_first(i)      = max(abs(eig(W1  * Brec)));
    rho_first_star(i) = max(abs(eig(W1  * (D_star .* Brec))));
end

%% 3. Summary

T = table(rho_full, rho_star, rho_first, rho_first_star);
disp(varfun(@(v) [mean(v) std(v) min(v) max(v)], T))   % rows: mean, s.d., min, max
fprintf('first-order program: rho = %.2f +/- %.3f (range %.3f to %.3f)\n', ...
        mean(rho_first), std(rho_first), min(rho_first), max(rho_first));

if strlength(save_file) > 0
    save(save_file, "rho_full", "rho_star", "rho_first", "rho_first_star", "seed0");
end
