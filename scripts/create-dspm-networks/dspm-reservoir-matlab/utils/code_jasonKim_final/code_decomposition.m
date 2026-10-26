%% Prepare Space
clear; clc;
rng(0);                         % Set random seed for reproducibility


%% EXAMPLE: Decompile, program, and compile rotation for continuous-time
% Reservoir parameters
dt = 0.001;                     % Time step
gam = 100;                      % Time constant
N1 = 1000;                      % Number of neurons
A1 = (rand(N1)-.5).*(rand(N1)<.05);                     % Recurrent matrix
A1 = sparse(A1 / abs(eigs(A1,1,'largestabs','MaxIterations',1e6))) * .01;   % Normalize
B1 = (rand(N1,3)-.5)*.2;        % Input matrix
rs1 = (rand(N1,1)-.5);          % RNN Fixed Point
xs1 = [0;0;0];                  % Input Operating Point
R1 = ReservoirTanhB(A1,B1,rs1,xs1,dt,gam);               % RNN object
R1.r = rs1;                     % Set initial state to fixed point
d1   = R1.d;                    % Bias term that yields desired fixed point

% Decompile into state NPL
[~,C1,C1a] = decomp_poly4_ns(A1, B1, rs1, A1*rs1+B1*xs1+d1, gam, 3);
RsNPL1     = [C1 reshape(C1a,[N1,size(C1a,2)*3])];

% Write source code for rotation
Rz = [0 -1 0; 1 0 0; 0 0 1];
OsNPL1 = zeros(3,size(C1,2)*4);
OsNPL1(:,2:4) = Rz;

% Compile source code back into sNPL
W1 = lsqminnorm(RsNPL1', OsNPL1')';
disp(['Compiler residual: ' num2str(norm(W1*RsNPL1 - OsNPL1,1))]);

% Generate input and drive RNN
n = 100000;                     % Number of simulation steps
T = Thomas([0;0;1],dt);         % Thomas attractor object
X1 = T.propagate(n);            % Simulate Thomas
Ro1 = R1.train(X1);             % Drive RNN with Thomas
X1 = X1(:,(0.2*n+1):end,1);     % Throw away initial transient
Ro1 = Ro1(:,(0.2*n+1):end,1);   % Throw away initial transient
WR1 = W1*Ro1;                   % Predicted rotation
XRot = Rz*X1;                   % True rotated trajectory

% Calculate relative error
errv = norm(XRot - WR1) / norm(XRot - X1);
disp(['Relative error: ' num2str(errv)]);


%% EXAMPLE: Program simple high-pass filter for discrete-time
% Reservoir parameters
N2 = 1000;                      % Number of neurons
A2 = (rand(N2)-.5).*(rand(N2)<.05);                     % Recurrent matrix
A2 = sparse(A2 / abs(eigs(A2,1,'largestabs','MaxIterations',1e6))) * .2;    % Normalize
B2 = (rand(N2,1)-.5)*.2;        % Input matrix
rs2 = (rand(N2,1)-.5);          % RNN Fixed Point
xs2 = 0;                        % Input Operating Point
d2 = atanh(rs2)-A2*rs2;         % Bias term that yields desired fixed point

% Decompile into sNPL
[Pd2,C2] = decomp_poly_ns_discrete(A2, B2, rs2, A2*rs2+B2*xs2+d2, 4, 3);
RsNPL2 = [C2(:,1,1) reshape(C2(:,2:end,:),[N2,(size(C2,2)-1)*size(C2,3)])];

% Write source code for high-pass filter
OsNPL2 = zeros(3,size(RsNPL2,2));
of = [fir1(2,.1,'high',[1 1 1]);...
      fir1(2,.2,'high',[1 1 1])
      fir1(2,.3,'high',[1 1 1])];
OsNPL2(1:3,2:3:end) = of;

% Compile source code back into sNPL
W2 = lsqminnorm(RsNPL2',OsNPL2')';

% Generate input and drive RNN
t = linspace(0,3,91);
X2 = sin(t*2*pi) + sin(t*8*pi)*.2;
Ro2 = zeros(N2,length(t)); Ro2(:,1) = rs2;
for i = 2:length(t)
    Ro2(:,i) = tanh(A2*Ro2(:,i-1) + B2*X2(i-1) + d2);
end
WR2 = W2*Ro2;
XFilt = zeros(3,size(Ro2,2)-2);
for i = 1:size(XFilt,2)
    XFilt(:,i) = of*X2(i:i+2)';
end

% Calculate relative error
errv = norm(XFilt(:,1:end-1) - WR2(:,4:end)) / norm(XFilt(:,1:end-1));
disp(['Relative error: ' num2str(errv)]);

