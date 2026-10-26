function [x,dx,board_params] = get_symbolic_pong_logic_BY_MODULE(paddle_sensativity)
%%
% Set up symbolic variables
syms t; assume(t,'real'); 
syms x(t) [4,1];  x = x(t); assume(x,'real');

% Phase bifrucation constants, makes x-intercept of the phase diagram
% x_dot(x) 0.1 or -0.1, depending on the regime
fixedpoint = 0.1;
b = .01; 
a = -(1 + b) / (fixedpoint^2); 

% ------------------- Linear Update Block ------------------- 
dx.linear_update = [
    0         % x( 1)  d(dx), velocity (no 𝛥 , constant velosity)
    x(1)*x(2) % x( 2 )  x+dx, position (gets signed xvelocity and magnitude added to update position)
];

% ------------------- SR Latch Block ------------------- 
mult_sr_walls       = 10; % Multiplication for collision input
mult_sr_paddle      = 50; % Multiplication for collision input
nor_rec_func        = @(var) a*var.^3 + b*var - fixedpoint;
nor_col_input_func  = @(mult,var) mult*var^2  - 2*fixedpoint;
nor_sr_connect_func = @(var) ( var - fixedpoint );

nor_logic   = @(var1,var2)  (var1*var2)/(2*fixedpoint);

dx.sr_block_walls = [
    0
    0
    nor_rec_func(x(3)) + ... reccurrent part of the eqn setting shape of nullcline
        nor_logic( ... takes two input variables, here one from the collision detector and one from the other NOR gate
            nor_col_input_func(mult_sr_walls,x(1)),...
            nor_sr_connect_func(x(4)) ...
            )
    nor_rec_func(x(4)) + ... Other NOR gate in Latch
        nor_logic( ... 
            nor_col_input_func(mult_sr_walls,x(2)),... % opposite collision output as input here
            nor_sr_connect_func(x(3)) ...% other NOR gate output as input here
            )
];

dx.sr_block_paddle   = [
    0
    0
    nor_rec_func(x(1)) + ... reccurrent part of the eqn setting shape of nullcline
        nor_logic( ... takes two input variables, here one from the collision detector and one from the other NOR gate
            nor_col_input_func(mult_sr_walls,x(1)),...
            nor_sr_connect_func(x(4)) ...
            )
    nor_rec_func(x(3)) + ... Other NOR gate in Latch BUT with paddle multiplier!
        nor_logic( ... 
            nor_col_input_func(mult_sr_paddle,x(2)),... % opposite collision output as input here
            nor_sr_connect_func(x(3)) ...% other NOR gate output as input here
            )
];


% ------------------- Collision Detection Block ------------------- 
mult_col_walls  = 1000;
dx.collision_wall = @(wall_pos) ...
     [
     mult_col_walls*((wall_pos - x(2))*x(1) - x(1)^3 )
     0
     ];

ps =  paddle_sensativity; % paddle sensativity
mult_col_paddle = 2000;

dx.collision_paddle = @(paddle_fix ) ...
     [
     mult_col_paddle*( ... multiply the whole equation by sensativity-time constant
     (...
         ps - (... paddle sensativity,threshold for square distance to trigger phase shift dynamics
         (x(2) - x(3))^2 +... calcultate the distance between paddle's variable position and balls position
         (x(4) - paddle_fix)^2 )... calcultate the distance between paddle's fixed position and balls position
     )*x(1) ... multiply logic by linear reccurence variable to change fixed point dynamics
     - x(1)^3 ... set overall shape of curve as a 3rd order polynomial with a negative slope
     ) ; 
     0
     0
     0];




end

