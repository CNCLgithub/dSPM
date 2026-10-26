function out = run_pong_trial(net, opts)
% RUN_PONG_TRIAL  Condition, simulate and plot one pong trial on a programmed
% dspm_reservoir.
%
%   res = create_and_program_pong_rnns(1, 1000, "programmed");
%   out = run_pong_trial(res(1));
%   out = run_pong_trial(res(1), vx=-0.3, vy=0.15, y0=0.03, animate=true);
%
% Uses the new object directly (net.dspm): condition() on the open-loop
% tuple, then simulate() on the closed loop with the paddle as the only
% live input. Readout y = [W ; W_paddle] r gives all 13 channels.
%
% INPUT
%   net   one element of create_and_program_pong_rnns output; needs
%         .dspm (build with keep_dspm=true), .gen, .board_params
%
% NAME-VALUE ARGUMENTS
%   x0, y0       Ball start position in board units. The board spans
%                +/-(right_left_dist + buffer)/2 by
%                +/-(top_bottom_dist + buffer)/2.
%                Default 0, 0 (center).
%   vx, vy       Signed start velocity. Magnitudes seed x1, x2; signs set the
%                initial state of the x and y SR latches. Decoded ball speed
%                is about 0.1*|v| per unit time. Default 0.3, 0.2.
%   T            Closed-loop simulation length in steps (dt = res.dt, 0.01
%                by default, so T = 4000 is 40 time units). Default 4000.
%   T_condition  Open-loop burn-in steps before the trial, integrated from
%                r_star under constant drive c. 199 matches the old
%                basernn.train(repmat(c,[1 200 4])). Default 199.
%   paddle       Paddle position along its wall (y for a right/left paddle,
%                x for top/bottom). Scalar = held there for the whole
%                trial; 1 x T vector = paddle trajectory. The first
%                sample is also the paddle input during conditioning.
%                Has no effect on a network built with paddle_exist=false.
%                Default 0.
%   plot         Draw the summary figure. Default true.
%   animate      After plotting, step a ball/paddle marker and time cursors
%                through the trial (every 10th step). Default false.
%
% OUTPUT (struct)
%   t        1 x T time (res.dt units)
%   r        N x T reservoir states
%   y        13 x T decoded channels, rows as gen.info.names
%   ball     2 x T decoded ball position (y(3:4,:))
%   paddle   1 x T paddle input
%   init     12 x 1 recurrent initial condition c
%
% Initial condition follows run_rnn_trials/run_single_trial:
%   c = [|vx| |vy| x0 y0  sx*.1 -sx*.1  sy*.1 -sy*.1  0 0 0 0],  s = sign(v)
%
% WALL GEOMETRY
%   The buffer is the total delta over the board's extent, split between
%   the two walls: walls are drawn at +/-(dist + buffer)/2, i.e.
%   +/-(width + buffer/2). The paddle is drawn on that wall as well.
%
% NO PADDLE
%   Networks built with paddle_exist=false have the paddle folded into
%   their dynamics at a fixed far-away position (see
%   create_and_program_pong_rnns), so the paddle input is inert and no
%   paddle is drawn. Board structs without the field (e.g.
%   rishi_data.board_params) are treated as having a paddle.

arguments
    net (1,1) struct
    opts.x0          (1,1) double = 0
    opts.y0          (1,1) double = 0
    opts.vx          (1,1) double = 0.3
    opts.vy          (1,1) double = 0.2
    opts.T           (1,1) double {mustBeInteger, mustBePositive} = 4000
    opts.T_condition (1,1) double {mustBeInteger, mustBePositive} = 199
    opts.paddle      (1,:) double = 0       % scalar (held) or 1 x T trajectory
    opts.plot        (1,1) logical = true
    opts.animate     (1,1) logical = false
end

res = net.dspm;
bp  = net.board_params;
if isempty(res)
    error('run_pong_trial:noDspm', 'net.dspm is empty; build with keep_dspm=true.');
end

T = opts.T;
if isscalar(opts.paddle), pad = repmat(opts.paddle, 1, T);
else,                     pad = opts.paddle;
end
if numel(pad) ~= T
    error('run_pong_trial:paddleLength', 'paddle has %d samples, T = %d.', numel(pad), T);
end

has_paddle = ~isfield(bp, 'paddle_exist') || bp.paddle_exist;
if ~has_paddle && any(pad ~= 0)
    warning('run_pong_trial:paddleIgnored', ...
        'This network was built with paddle_exist=false; the paddle input has no effect.');
end

sx = sign(opts.vx); sy = sign(opts.vy);
c  = [abs(opts.vx); abs(opts.vy); opts.x0; opts.y0; ...
      sx*0.1; -sx*0.1; sy*0.1; -sy*0.1; 0; 0; 0; 0];

% ---- run -----------------------------------------------------------------
res.condition(c, pad(1), opts.T_condition);
r = res.simulate(T, pad);

W = [res.W; net.gen.W_paddle];
y = W * r;

out.t      = (1:T) * res.dt;
out.r      = r;
out.y      = y;
out.ball   = y(3:4, :);
out.paddle = pad;
out.init   = c;

if ~opts.plot, return, end

% ---- plot ----------------------------------------------------------------
names = net.gen.info.names;
g     = wall_geometry(bp);
lim   = 1.2 * max(g.xw, g.yw);

fig = figure('Name', 'pong trial', 'Position', [100 100 1200 650]);
tl  = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact');

% arena
ax = nexttile(tl, 1, [3 1]); hold(ax, 'on'); axis(ax, 'equal')
plot(ax, g.wall_x,   g.wall_y,   'k-', 'LineWidth', 3)
scatter(ax, out.ball(1,:), out.ball(2,:), 8, out.t, 'filled')
plot(ax, out.ball(1,1), out.ball(2,1), 'ko', 'MarkerSize', 9, 'LineWidth', 2)
if has_paddle
    [px, py] = paddle_xy(bp, g, pad);
    rad = sqrt(bp.sensativity);                  % paddle hit radius
    plot(ax, px, py, 's', 'Color', [.8 .2 .2], 'MarkerSize', 4)
    rectangle(ax, 'Position', [px(end)-rad, py(end)-rad, 2*rad, 2*rad], ...
        'Curvature', 1, 'EdgeColor', [.8 .2 .2], 'LineStyle', '--')
end
set(ax, 'XLim', [-lim lim], 'YLim', [-lim lim])
cb = colorbar(ax); cb.Label.String = 'time';
title(ax, 'ball (W_{3:4} r)')

% ball coordinates
ax2 = nexttile(tl, 2);
plot(ax2, out.t, out.ball'); legend(ax2, names(3:4), 'Location', 'eastoutside', 'AutoUpdate', 'off')
yline(ax2, unique([[-1 1]*g.xw, [-1 1]*g.yw]), 'k-')
title(ax2, 'position')

% latches
ax3 = nexttile(tl, 4);
plot(ax3, out.t, y(5:8,:)'); legend(ax3, names(5:8), 'Location', 'eastoutside', 'AutoUpdate', 'off')
yline(ax3, 0, ':'); title(ax3, 'SR latches')

% collision detectors
ax4 = nexttile(tl, 6);
plot(ax4, out.t, y(9:12,:)'); legend(ax4, names(9:12), 'Location', 'eastoutside', 'AutoUpdate', 'off')
title(ax4, 'collision detectors'); xlabel(ax4, 'time')
linkaxes([ax2 ax3 ax4], 'x')

% ---- optional animation --------------------------------------------------
if opts.animate
    hb = plot(ax, nan, nan, 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');
    if has_paddle
        hp = plot(ax, nan, nan, 's', 'MarkerSize', 12, 'MarkerFaceColor', [.8 .2 .2]);
    end
    ht = [xline(ax2, nan), xline(ax3, nan), xline(ax4, nan)];
    for k = 1:10:T
        set(hb, 'XData', out.ball(1,k), 'YData', out.ball(2,k));
        if has_paddle, set(hp, 'XData', px(k), 'YData', py(k)); end
        set(ht, 'Value', out.t(k));
        drawnow limitrate
    end
end

end

function g = wall_geometry(bp)
% Effective elastic walls at (dist + buffer)/2: the buffer is the total
% delta across the board, split between the two walls. Rescales plot_wall_x/y so the paddle-wall gap (NaNs)
% is preserved.
g.xw = (bp.right_left_dist + bp.buffer) / 2;
g.yw = (bp.top_bottom_dist + bp.buffer) / 2;
g.wall_x   = bp.plot_wall_x * (g.xw / bp.x_width);
g.wall_y   = bp.plot_wall_y * (g.yw / bp.y_width);
end

function [px, py] = paddle_xy(bp, g, pad)
% Paddle position in board coordinates, on the effective wall.
if bp.paddle_var_index == 4          % left/right wall: paddle slides in y
    px = repmat(sign(bp.paddle_fix_value) * g.xw, size(pad)); py = pad;
else                                 % top/bottom wall: paddle slides in x
    px = pad; py = repmat(sign(bp.paddle_fix_value) * g.yw, size(pad));
end
end
