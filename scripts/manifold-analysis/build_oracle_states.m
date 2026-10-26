function oracleStates = build_oracle_states(rishi_data, all_mask_bs, tvec_bs)
%BUILD_ORACLE_STATES  Construct oracle [4 x ntbins x ntrials] state tensor
%                     from rishi_data simulation coordinates.
%
%  The 4 state variables per time bin are:
%    row 1: x position   (from sim_coordinates.x, downsampled to 50ms)
%    row 2: y position   (from sim_coordinates.y, downsampled to 50ms)
%    row 3: xdot0        (initial x velocity, constant across all bins)
%    row 4: ydot0        (initial y velocity, constant across all bins)
%
%  This matches exactly the oracle construction in oracle_rsa_posthoc.m:
%    gtCell{i} = [gtx{i}(1:50:tpts(i))'; gty{i}(1:50:tpts(i))';
%                 repmat(rd.xdot0(i), 1, tpts(i)/50);
%                 repmat(rd.ydot0(i), 1, tpts(i)/50)];
%
%  The simulation is at 1ms resolution. We downsample to 50ms to match
%  tvec_bs. Trial length is determined per-trial from all_mask_bs.
%
%  Inactive bins (beyond trial end) are left as zero, matching how
%  compute_pca_masked handles the neural/dSPM states.
%
%  Inputs:
%    rishi_data   — struct with fields:
%                     .sim_coordinates.x  {ntrials x 1} 1ms x positions
%                     .sim_coordinates.y  {ntrials x 1} 1ms y positions
%                     .xdot0              [ntrials x 1] initial x velocity
%                     .ydot0              [ntrials x 1] initial y velocity
%    all_mask_bs  — [ntbins x ntrials] logical, active time bins
%    tvec_bs      — [1 x ntbins] ms, time vector (dt must be 50ms)
%
%  Output:
%    oracleStates — [4 x ntbins x ntrials]
%%

all_mask_bs = brain.all_mask';

ntbins  = numel(tvec_bs);
ntrials = size(all_mask_bs, 2);
dt      = 50;   % ms per bin — matches neural data binning

gtx = rishi_data.sim_coordinates.x;
gty = rishi_data.sim_coordinates.y;

% Verify dt
if ntbins > 1
    dt_check = tvec_bs(2) - tvec_bs(1);
    if abs(dt_check - dt) > 1
        warning('tvec_bs dt=%.0f ms, expected 50 ms — check alignment', dt_check);
        dt = round(dt_check);
    end
end

fprintf('  Building oracle: %d trials x %d bins x 6 vars (dt=%d ms)\n', ...
    ntrials, ntbins, dt);
fprintf('  Vars: x(t), y(t), xdot0, ydot0, x_final, y_final\n');

oracleStates = zeros(6, ntbins, ntrials);

for i = 1:ntrials

    mask_row = all_mask_bs(:, i);
    last_bin = find(mask_row, 1, 'last');
    if isempty(last_bin), continue; end
    tpts_i   = last_bin * dt;

    sim_idx  = 1 : dt : tpts_i;
    n_bins_i = numel(sim_idx);

    x_sim    = gtx{i};
    y_sim    = gty{i};
    n_bins_i = min(n_bins_i, floor(numel(x_sim) / dt));
    sim_idx  = sim_idx(1:n_bins_i);
    n_bins_i = min(n_bins_i, ntbins);
    sim_idx  = sim_idx(1:n_bins_i);

    oracleStates(1, 1:n_bins_i, i) = x_sim(sim_idx);       % x position (time-varying)
    oracleStates(2, 1:n_bins_i, i) = y_sim(sim_idx);       % y position (time-varying)
    oracleStates(3, 1:n_bins_i, i) = rishi_data.xdot0(i);  % initial x vel (constant)
    oracleStates(4, 1:n_bins_i, i) = rishi_data.ydot0(i);  % initial y vel (constant)
    oracleStates(5, 1:n_bins_i, i) = x_sim(sim_idx(end));  % final x pos  (constant)
    oracleStates(6, 1:n_bins_i, i) = y_sim(sim_idx(end));  % final y pos  (constant)

end

% ── Z-score each variable across all active (time, trial) entries ─────
%  Without this, x/y position (which vary over time) swamp xdot0/ydot0
%  (which only vary across trials), and PCA reduces to ball trajectories.
%  Z-scoring equalises each variable's contribution to the PCA basis.
active_mask = oracleStates(1,:,:) ~= 0;   % [1 x ntbins x ntrials]
for v = 1:6
    vals = squeeze(oracleStates(v,:,:));   % [ntbins x ntrials]
    active_vals = vals(squeeze(active_mask));
    mu_v  = mean(active_vals);
    std_v = std(active_vals);
    if std_v > 0
        vals_z = (vals - mu_v) / std_v;
        vals_z(~squeeze(active_mask)) = 0;   % keep inactive bins at zero
        oracleStates(v,:,:) = vals_z;
    end
end
fprintf('  Z-scored 4 oracle variables across active entries.\n');

fprintf('  Done. Non-zero entries: %d / %d\n', ...
    sum(oracleStates(1,:,:) ~= 0, 'all'), ntbins * ntrials);

end
