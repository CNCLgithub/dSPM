function [dx, x, info] = define_pong_dynamics(board_params)
% DEFINE_PONG_DYNAMICS  Pong world-model ODE in the form dspm_reservoir expects.
%
%   [dx, x, info] = define_pong_dynamics(board_params)
%
% Port of define_symbolic_logic.m with three structural changes and no
% changes to constants or gains:
%
%   1. Plain real symbols x1..x13 instead of symfuns x1(t)..x13(t).
%      (program-matrix construction keys monomials by exponent vector, and
%      symvar() on symfun calls returns t, not the state variables.)
%
%   2. dx has 12 rows, not 13. x13 (paddle) is not a state with dynamics; it
%      is an external port. The old code carried it as dx(13) = 0 and then
%      split W(1:12,:) / B(:,13) by hand in run_rnn_trials. In the new
%      package that split is the port table: 12 "rec" ports + 1 "ext" port.
%
%   3. The paddle-wall distance is polynomial. The old form used
%      (abs(x3) + xw)^2 and (abs(x4) - paddle)^2. abs() has no polynomial
%      coefficients, so it cannot be compiled. Replacements:
%        fixed coordinate (distance to the paddle's wall line):
%            abs(x3) -> side*x3   (side = +1 right/top, -1 left/bottom)
%          which is exact on the paddle's half of the board, the only place
%          that term can fire.
%        variable coordinate (distance along the paddle):
%            abs(x4) - paddle -> x4 - paddle
%          which is the true distance to a paddle centered at `paddle`. The
%          abs() form detected a mirror paddle at -paddle as well. With
%          paddle driven at 0 (all current runs), both forms are identical.
%      compare_generation_old_vs_new.m reports how the old compile treated
%      this row so you can confirm the choice.
%
%   4. paddle_exist = false folds x13 = no_paddle_position into dx as a
%      constant (default 2*paddle_var_limits). x13 stays a port so the
%      legacy 13-channel layout is intact, but nothing depends on it.
%
% Outputs
%   dx    12x1 sym   recurrent dynamics  dx_i/dt = f_i(x1..x13)
%   x     13x1 sym   [recurrent states x1..x12 ; paddle input x13]
%   info  struct     names, roles, max polynomial degree

m_rec = 12;
m     = 13;
x     = sym('x', [m 1], 'real');

xo = board_params.buffer;
xw = -board_params.x_width + xo;     % signed offset to the x walls
yw = -board_params.y_width + xo;     % signed offset to the y walls
ps =  board_params.sensativity;      % paddle hit radius^2

% Pitchfork constants for the NAND recurrences (unchanged)
fixedpoint = 0.1;
b = 0.01;
a = -(1 + b) / (fixedpoint^2);

xvel   = x(1);
yvel   = x(2);
xpos   = x(5) * xvel;                % x-latch sign * |vx|
ypos   = x(7) * yvel;                % y-latch sign * |vy|
paddle = x(13);

walls     = ["right" "left" "top" "bottom"];
col_eqn   = sym(zeros(4,1));
sr_input  = sym(zeros(4,1));
paddle_pos = string(board_params.paddle_pos);

for i = 1:numel(walls)
    wall = walls(i);
    c    = x(8 + i);                 % collision detector x9..x12

    if wall == paddle_pos
        switch wall
            case {"right","top"},   side = +1;
            otherwise,              side = -1;
        end
        switch wall
            case {"right","left"}
                x_dist = (side*x(3) + xw)^2;
                y_dist = (x(4) - paddle)^2;
            case {"top","bottom"}
                x_dist = (x(3) - paddle)^2;
                y_dist = (side*x(4) + yw)^2;
        end
        mult_sr = 50; mult_col = 2000;
        ball_dist = ps - (x_dist + y_dist);
    else
        mult_sr = 10; mult_col = 1000;
        switch wall
            case "right",  ball_dist =  x(3) + xw;
            case "left",   ball_dist =  xw - x(3);
            case "top",    ball_dist =  x(4) + yw;
            case "bottom", ball_dist =  yw - x(4);
        end
    end

    col_eqn(i)  = mult_col * (ball_dist*c - c^3);
    sr_input(i) = mult_sr*c^2 - 2*fixedpoint;
end

% NAND recurrences + cross-coupled SR-latch logic (unchanged pairing:
% right->x6, left->x5, top->x8, bottom->x7)
nand_rec   = a*x(5:8).^3 + b*x(5:8) - fixedpoint;
nand_logic = [ sr_input(1)*(x(6) - fixedpoint)
               sr_input(2)*(x(5) - fixedpoint)
               sr_input(3)*(x(8) - fixedpoint)
               sr_input(4)*(x(7) - fixedpoint) ] ./ (2*fixedpoint);

latch = 20*(nand_rec + nand_logic);

dx = [ 0            % x1  |vx|        constant
       0            % x2  |vy|        constant
       xpos         % x3  ball x
       ypos         % x4  ball y
       latch(1:2)   % x5,x6   x-velocity SR latch
       latch(3:4)   % x7,x8   y-velocity SR latch
       col_eqn ];   % x9..x12 collision detectors (R, L, T, B)

assert(numel(dx) == m_rec);

% ---- no paddle: fold a far-away paddle into the dynamics -----------------
% Lowering sensativity alone leaves the paddle detector only weakly stable
% when the ball arrives near the paddle center (margin ~ mult_col*(ps - d^2)).
% Pinning the paddle off the end of its wall makes d large everywhere, and
% substituting it as a constant removes any dependence on the x13 input.
info.paddle_folded = false;
if isfield(board_params, 'paddle_exist') && ~board_params.paddle_exist
    if isfield(board_params, 'no_paddle_position')
        p_off = board_params.no_paddle_position;
    else
        p_off = 2 * board_params.paddle_var_limits;
    end
    dx = expand(subs(dx, x(13), p_off));
    info.paddle_folded      = true;
    info.no_paddle_position = p_off;
end

% ---- metadata -----------------------------------------------------------
info.names = ["vx" "vy" "ballx" "bally" ...
              "srxA" "srxB" "sryA" "sryB" ...
              "colR" "colL" "colT" "colB" "paddle"];
info.roles = [repmat("rec", 1, m_rec) "ext"];
info.n_rec = m_rec;

deg = 0;
for i = 1:m_rec
    if ~isequal(dx(i), sym(0))
        deg = max(deg, polynomialDegree(expand(dx(i)), x));
    end
end
info.max_degree = deg;

end
