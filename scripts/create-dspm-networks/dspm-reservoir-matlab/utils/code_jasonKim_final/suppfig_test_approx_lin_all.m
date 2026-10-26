%% Prepare Space
clear; clc;
params_fig
rng(0);


%% Fig.1d-f
% Parameters
dt = 0.001;                                 % Time step
gam = 100;                                  % Time constant
N = 1000;                                   % Number of neurons
nIter = 100;
errF1_1 = zeros(nIter,1);

% Input data: Thomas attractor
T = Thomas([0;0;1],dt);
n = 100000;                                 % Number of simulation steps
X = T.propagate(n);

parfor q = 1:nIter
    disp(q);
    A = (rand(N)-.5).*(rand(N)<.05);    
    eMax = abs(eigs(A,1,'largestabs','MaxIterations',1e7));
    A = sparse(A / eMax) * .01;
    B = (rand(N,3)-.5)*.2;                  % Input matrix
    rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
    xs = [0;0;0];                           % Input Operating Point
    RO = ReservoirTanhB(A,B,rs,xs,dt,gam);  % RNN object
    RO.r = rs;
    d = RO.d;
    
    % Linear RNN
    AL = sparse(gam*((1-tanh(A*rs+B*xs+d).^2).*A - eye(N)));
    BL = gam*sparse(eye(N));
    ROL = ReservoirLin(AL,BL,dt);
    
    % Simulate trajectory
    tpmt = tanh(pagemtimes(B,X)+A*rs + d); 
    XL = tpmt - (A*rs).*(1-tpmt.^2);
    
    % Train RNNs
    R = RO.train(X);                % Drive nonlinear RNN with Thomas
    RL = ROL.train(XL);              % Drive linear RNN with Thomas
    R = R(:,(.2*n+1):end);
    RL = RL(:,(.2*n+1):end);
    
    % Error
    errF1_1(q) = norm(R-RL) / norm(R-rs);
end


%% Fig.1g-j
% Parameters
errF1_2 = zeros(nIter,1);
N = 1000;                               % Number of neurons

parfor q = 1:nIter
    disp(q);
    A = (rand(N)-.5).*(rand(N)<.05);
    eMax = abs(eigs(A,1,'largestabs','MaxIterations',1e7));
    A = sparse(A / eMax) * .2;
    B = (rand(N,1)-.5)*.2;                  % Input matrix
    rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
    xs = 0;                                 % Input Operating Point
    d = atanh(rs)-A*rs;
    
    % Linear RNN
    AL = sparse((1-tanh(A*rs+B*xs+d).^2).*A);
    BL = sparse(eye(N));
    
    % Simulate trajectory
    t = linspace(0,2,61);
    X = sin(t*2*pi) + sin(t*8*pi)*.2;
    tpmt = tanh(pagemtimes(B,X)+A*rs + d);
    XL = tpmt - (A*rs).*(1-tpmt.^2);
    
    % Simulate RNNs
    R = zeros(N,length(t));
    RL = zeros(N,length(t));
    R(:,1) = rs;
    RL(:,1) = rs;
    for i = 2:length(t)
        R(:,i) = tanh(A*R(:,i-1) + B*X(i-1) + d);
        RL(:,i) = AL*RL(:,i-1) + BL*XL(:,i-1);
    end
    
    % Error
    errF1_2(q) = norm(R - RL) / norm(R-rs);
end


%% Fig.2d-f
% Parameters
errF2_1 = zeros(nIter,1);
n = 4000;
K = 6;                          % Size of RNN
I = eye(K);                     % Identity matrix
gam = 100;                      % Time constant
N = 5000;                       % Number of neurons

parfor q = 1:nIter
    disp(q);

    % Reservoir
    A = sparse((rand(N)-.5).*(rand(N)<.05));
    A = A / abs(eigs(A,1,'largestabs','MaxIterations',1e7)) * 0.0001;
    B = (rand(N,2*K^2)-.5)*.005;    % Input matrix
    rs = (rand(N,1)-.5);           % Desired equilibrium points
    xs = zeros(2*K^2,1);
    AM = (rand(K)-.5); AM = AM - I;
    CLAM = lyap(AM,1*I);
    RO = ReservoirTanhB(A,B,rs,xs,dt,gam);
    RO.r = rs;
    d = RO.d;
    
    % Linear RNN
    AL = sparse(gam*((1-tanh(A*rs+B*xs+d).^2).*A - eye(N)));
    BL = gam*sparse(eye(N));
    ROL = ReservoirLin(AL,BL,dt);
    X = repmat([CLAM(:);AM(:)], [1, n, 4]);
    
    % Simulate trajectory
    tpmt = tanh(pagemtimes(B,X)+A*rs + d); 
    XL = tpmt - (A*rs).*(1-tpmt.^2);
        
    % Train RNNs
    R = RO.train(X);                % Drive nonlinear RNN with Thomas
    RL = ROL.train(XL);              % Drive linear RNN with Thomas
    R = R(:,end);
    RL = RL(:,end);
    
    % Error
    errF2_1(q) = norm(R-RL) / norm(R-rs);
end


%% Fig.2g-i
% Parameters
errF2_2 = zeros(nIter,1);
Ts = 49;
N = 500;                                % Number of neurons
T = 200;

parfor q = 1:nIter
    disp(q);
    A = sparse((rand(N)-.5).*(rand(N)<.05));
    A = A / abs(eigs(A,1,'largestabs','MaxIterations',1e7)) * 0.01;
    B = (rand(N,Ts+1)-.5)*.001;         % Input matrix
    rs = (rand(N,1)-.5);                % RNN Operating/Fixed Point
    xs = zeros(Ts+1,1);
    d = atanh(rs)-A*rs;

    % Linear RNN
    AL = sparse((1-tanh(A*rs+B*xs+d).^2).*A);
    BL = sparse(eye(N));

    % Simulate trajectory
    x = sin((1:T)*(2*pi/5)) + sin((1:T)*(2*pi/25)) + (rand(1,T)-.5)*3;
    X = lagmatrix(x,(0:Ts))'; X = X(:,50:end);
    tpmt = tanh(pagemtimes(B,X)+A*rs + d);
    XL = tpmt - (A*rs).*(1-tpmt.^2);

    % Train RNN
    R = zeros(N,T-Ts); R(:,1) = rs;
    RL = zeros(N,T-Ts); RL(:,1) = rs;
    for i = 2:T-Ts
        R(:,i) = tanh(A*R(:,i-1) + B*X(:,i-1) + d);
        RL(:,i) = AL*RL(:,i-1) + BL*XL(:,i-1);
    end
    errF2_2(q) = norm(R - RL) / norm(R-rs);
end


%% Parameters and dimensions
fig = figure(2); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 5];                      % Figure Size in cm  [w,h]
fMarg = [.5 .5 .5 .5];              % Margins in cm, [l,r,d,u]
subp = [[ 0.50  0.50  4.50  4.50];...     % Subplot position in cm [x,y,w,h]
        [ 4.50  0.50  4.50  4.50];...
        [ 9.00  0.50  4.50  4.50];...
        [13.50  0.50  4.50  4.50]];

% Adjust position for margins
subp = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat = subp(:,3) ./ subp(:,4);

% Label Position in cm
labX = -fMarg(1);
labY = 0.05;
labY2 = 0.2;
labY3 = -0.1;
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'color','w');

histogram(errF1_1,'binwidth',0.0005);
hold on;
histogram(errF1_2,'binwidth',0.0005);
histogram(errF2_1,'binwidth',0.0005);
histogram(errF2_2,'binwidth',0.0005);
hold off;
legend('Fig.1d-f','Fig.1g-i','Fig.2d-f','Fig.2g-i');
xlabel('relative error');
ylabel('count');
set(gca,'fontsize',10);


%% Save
fName = 'suppfig_test_approx_lin_all';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, fName, 'pdf');
set(gcf, 'Renderer', 'opengl');
