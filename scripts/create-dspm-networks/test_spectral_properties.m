%% TEST_SPECTRAL_PROPERTIES
% Spectral properties of a programmed dSPM Pong reservoir.
%
%
% What this script establishes (reference values from the 1 Oct 2026 run,
% one reservoir, one trial):
%   1. Raw coupling strength:        rho(Ap)            ~ 3.4e3
%   2. Local dynamics at r*:         leading eig(D*Ap)  = 1.202
%      and eig(D*Ap) = eig(L) = 1 + lambda/gamma to ~1e-11
%   3. Local dynamics at r_i:        leading eig        = 1.000 (within 2e-4)
%   4. Along a trial:                leading eig stays at 1, rises briefly
%                                    (~1.12) when a collision flips a switch
%   5. Geometry of the cancellation: large-weight directions of W are
%                                    orthogonal to the gain-weighted column
%                                    space to ~1e-6; product is order 1
%   6. Where the large weights live: switches and detectors (y5..y12), not
%                                    position and speed (y1..y4)
%
% Notation:
%   Ap    programmed adjacency, Ap = Brec * W (A0 = 0), rank <= 12
%   Brec  recurrent input matrix (N x 12)
%   W     readout / feedback matrix (12 x N)
%   r*    operating point the network is programmed about
%   r_i   conditioned state that encodes one trial's initial configuration
%   gain  slope of tanh at a unit's current input
%
% Sections can be run one at a time. Sections 3 to 8 need Section 1;
% Sections 5 and 6 also need the trial from Section 2.


%% 1. Build and program the Pong reservoir
% One 1000-unit programmed reservoir, no paddle input.

addpath('dependencies/')                  % package core only
addpath('dspm-reservoir-matlab/core')     % package core only

res = create_and_program_pong_rnns(1, 1000, "programmed", "paddle_exist", false);

% Shorthand used by every section below
d      = res.dspm;
Ap     = d.programmed_adjacency;          % N x N
Brec   = d.B(:, 1:12);                    % recurrent columns of B (column 13 is the external input)
W      = d.W;                             % 12 x N
D_star = 1 - d.r_star.^2;                 % gains at the operating point r*


%% 2. Run one trial from a random initial configuration
% Random direction at speed 0.5, random start position in [-0.08, 0].
% No seed is set, so each run gives a different trial.

theta = 2*pi*rand;                        % random angle in [0, 2*pi]
s0    = rand(2,1) * (-0.08);              % initial position
v0    = [cos(theta), sin(theta)] * 0.5;   % initial velocity

close all
out = run_pong_trial(res(1), ...
                     x0 = s0(1), y0 = s0(2), ...   % initial position
                     vx = v0(1), vy = v0(2), ...   % initial velocity
                     T = 800, animate = true);     % number of time steps


%% 3. Coupling strength: raw spectral radius vs gain-weighted value at r*
% The nonzero eigenvalues of Ap = Brec*W equal those of the 12 x 12 matrix
% W*Brec, so the small matrix is used throughout.
%   rho      raw spectral radius of Ap (how large the weights are)
%   sig      largest singular value of Ap
%   rho_eff  same as rho, with each unit weighted by its gain at r*

rho     = max(abs(eig(W * Brec)));
sig     = norm(Ap, 2);
rho_eff = max(abs(eig(W * (D_star .* Brec))));

fprintf("rho(A) = %.3f   sigma_max = %.3e   rho(DA) = %.3f\n", rho, sig, rho_eff)


%% 4. Semiconjugacy at r*: eig(D*Ap) vs the linear block of the program
% The compiled program matrix P holds the target in the monomial basis:
% column 1 is the constant, columns 2:13 are the linear terms in y1..y12.
% Three candidate relations are tested. In the reference run the first one
% matches (max|diff| ~ 1e-11), which means L = I + J/gamma, so the
% eigenvalues of D*Ap are 1 + lambda/gamma with lambda the eigenvalues of
% the target flow at the operating point.

P  = d.compiled_program_matrix; % 12 x 560
L  = P(:, 2:13);                % linear block: d(target_i)/d(y_j) at y = 0
c0 = P(:, 1);                   % constant term

srt = @(v) sort(v, 'ComparisonMethod', 'real');
mu  = srt(eig(W * (D_star .* Brec))); % nonzero eigenvalues of D*Ap

cand = {srt(eig(L)), srt(1 + eig(L)/d.gamma), srt(eig(L)/d.gamma)};
name = {'eig(L)', '1 + eig(L)/gamma', 'eig(L)/gamma'};
for k = 1:3
    fprintf('%-18s max|diff| = %.3e\n', name{k}, max(abs(mu - cand{k})));
end

disp(table(mu, cand{1}, cand{2}, ...
     'VariableNames', {'eig_DAp', 'eig_L', 'one_plus_eigL_over_gamma'}))

% Fit residual: how closely W*R reproduces P
fit = norm(W * d.decompiled_weight_matrix - P, 'fro') / norm(P, 'fro');
fprintf('rho(D*Ap) = %.4f   max Re = %.4f   |const| = %.2e   fit residual = %.2e\n', ...
        max(abs(mu)), max(real(mu)), norm(c0), fit);


%% 5. Local dynamics at the conditioned state r_i
% r_i is the state the open-loop network relaxes to when driven with the
% trial's initial configuration. Here the switches sit on their stable
% states, so the switch and detector modes should be below 1 and the four
% position/speed modes should sit at 1.

ri  = d.r0;                               % conditioned state for the trial
Di  = 1 - ri.^2;                          % gains at r_i
mui = srt(eig(W * (Di .* Brec)));

disp(table(mui, d.gamma*(mui - 1), 'VariableNames', {'eig_DiAp', 'implied_target_eig'}))

% Readback: should return the 12 conditioned values
% (|vx|, |vy|, sx, sy, the four switch outputs near +/-0.1, detectors near 0)
disp((W * ri)')


%% 6. Leading eigenvalue of the gain-weighted connectivity along the trial
% Gains are computed from each unit's input, not from r, because r lags its
% input slightly away from rest. The external input is zero in this run
% (paddle_exist = false), so column 13 of B is omitted.
%   lead  largest real part: the instability criterion (grows if > 1)
%   rho_t largest modulus: can be large for a fast-DECAYING mode, so it is
%         not a measure of instability; plotted for reference only

G = 1 - tanh(Brec * (W * out.r) + d.d_star).^2; % gains at every time step (N x T)

T    = 500;    % number of time steps to analyse (out.t has 800)
mu_t = zeros(12, T);
for k = 1:T
    mu_t(:, k) = eig(W * (G(:, k) .* Brec));
end
lead  = max(real(mu_t), [], 1);
rho_t = max(abs(mu_t),  [], 1);

figure; tiledlayout(3, 1);
nexttile; plot(out.t(1:T), lead, out.t(1:T), rho_t, '--'); yline(1, ':');
          ylabel('leading eigenvalue'); legend('max Re', 'max | |', '1');
nexttile; plot(out.t(1:T), out.y(5:8, 1:T));   ylabel('switch outputs');
nexttile; plot(out.t(1:T), out.ball(:, 1:T));  ylabel('ball position'); xlabel('t');

[m, i] = max(lead);
fprintf('median = %.4f   max = %.4f at t = %.2f\n', median(lead), m, out.t(i));


%% 7. Geometry of the cancellation: row space vs column space of Ap
% Row space of Ap = span of the rows of W. Column space = span of Brec
% (raw) or of D*Brec (with gains). Cosines of the principal angles between
% them are compared with the level expected for two random 12-dimensional
% subspaces of R^1000.

QW     = orth(W');                                 % row space of Ap
c_raw  = svd(orth(Brec)'           * QW);          % cosines, raw
c_gain = svd(orth(D_star .* Brec)' * QW);          % cosines, with gains

fprintf('raw:   max cos = %.3g, min cos = %.3g\n', max(c_raw),  min(c_raw));
fprintf('gain:  max cos = %.3g, min cos = %.3g\n', max(c_gain), min(c_gain));
fprintf('random 12-dim subspaces in R^1000: about %.2f\n', 2*sqrt(12/1000));

% Per direction of W (strongest first): weight scale, overlap with the
% gain-weighted column space, and their product. In the reference run the
% first two vary by ~5 orders of magnitude in opposite directions and the
% product stays of order 1.
[~, S, V] = svd(W, 'econ');
QDB = orth(D_star .* Brec);
ov  = vecnorm(QDB' * V)';

disp(table(diag(S), ov, diag(S).*ov, 'VariableNames', {'weight_scale', 'overlap', 'product'}))


%% 8. Where the large weights live: weight norm per programmed variable
% Rows of W in order y1..y12:
%   y1, y2    speeds          y5..y8    switch outputs
%   y3, y4    positions       y9..y12   collision detectors
% Printed with fprintf so MATLAB's common scale factor cannot hide the
% four-orders-of-magnitude gap between the two groups.

w_norm = vecnorm(W, 2, 2)';
fprintf('%10.3g', w_norm); fprintf('\n');


%%

d    = res.dspm;   Brec = d.B(:, 1:12);
R    = d.decompiled_weight_matrix;      % N x 560
P    = d.compiled_program_matrix;       % 12 x 560
lin  = 1:14;                            % constant + 13 first-order columns
W1   = P(:, lin) * pinv(R(:, lin));     % readout solved to first order only
fprintf('rho, first-order program: %.3f    full cubic program: %.1f\n', ...
    max(abs(eig(W1 * Brec))), max(abs(eig(d.W * Brec))));



