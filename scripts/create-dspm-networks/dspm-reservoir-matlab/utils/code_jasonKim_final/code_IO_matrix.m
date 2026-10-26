%% Prepare Space
clear; clc;
rng(0);                         % Set random seed for reproducibility


%% EXAMPLE: Decompile, program, and compile Lyapunov equation
% Problem parameters
K = 6;                          % Size of one matrix dimension
I = eye(K);                     % Identity matrix

% Reservoir parameters
dt = 0.001;                     % Time step
gam = 100;                      % Time constant
N1 = 4000;                      % Number of neurons
A1 = sparse((rand(N1)-.5).*(rand(N1)<.05));
A1 = A1 / abs(eigs(A1,1,'largestabs','MaxIterations',1e6)) * 0.0001;
B1 = (rand(N1,2*K^2)-.5)*.005;  % Input matrix
rs1 = (rand(N1,1)-.5);          % Desired fixed point
xs = zeros(2*K^2,1);            % Operating point of inputs
d1 = atanh(rs1)-A1*rs1;         % Bias term that yields desired fixed point

% Decompile into our state NPL
[Pd1,RsNPL1] = decomp_poly1_ns(A1,B1,rs1,A1*rs1+d1,3);

% Define symbolic output
syms a [K,K]; assume(a,'real'); syms b [K,K]; assume(b,'real'); 
O1 = b*a + a*b' + eye(K) + a;

% Convert symbolic output to source code by extracting coefficients
pr = primes(1000); pr = pr(1:(2*K^2)); pri = prod(pr.^Pd1,2);
OsNPLp1 = zeros([K^2,size(Pd1,1)]);
for i = 1:K^2
    [as,bs] = coeffs(O1(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPLp1(i,ai) = as;
end

% Compile source code back into sNPL
Wp1 = lsqminnorm(RsNPL1', OsNPLp1')';
disp(['Compiler residual: ' num2str(norm(Wp1*RsNPL1 - OsNPLp1))]);

% Input matrix and true solution
AM = (rand(K)-.5); AM = AM - I;
CLAM = lyap(AM,1*I);

% Construct reservoir
R1 = ReservoirTanhB(A1+(B1(:,1:K^2)*Wp1),B1(:,K^2+1:end),rs1,xs(1:K^2),dt,gam);
R1.d = d1; R1.r = rs1;                      % Set initial bias and state

% Drive reservoir until convergence
Ro1 = R1.train(repmat(AM(:),[1,1000,4]));
while(norm(Ro1(:,end)-Ro1(:,end-1)) > 1e-5)
    disp(norm(Ro1(:,end)-Ro1(:,end-1)));
    Ro1 = cat(2,Ro1,R1.train(repmat(AM(:),[1,1000,4])));
end

% Output of reservoir
WRP = Wp1*Ro1;
WRPM1 = reshape(WRP(:,1),[K,K]);            % Time point 1 to plot
WRPM2 = reshape(WRP(:,5),[K,K]);            % TIme point 2 to plot
WRPM3 = reshape(WRP(:,end),[K,K]);          % Time point 3 to plot
disp(['Relative error: ' num2str(norm(CLAM - WRPM3) / norm(CLAM))]);


%% EXAMPLE: Decompile, program, and compile short-time Fourier transform
% Problem parameters
Ts = 49;                        % Number of time lags

% Reservoir parameters
N2 = 500;                       % Number of neurons
A2 = sparse((rand(N2)-.5).*(rand(N2)<.05));
A2 = A2 / abs(eigs(A2,1,'largestabs','MaxIterations',1e6)) * 0.01;
B2 = (rand(N2,Ts+1)-.5)*.001;   % Input matrix
rs2 = (rand(N2,1)-.5);          % RNN fixed point
d2 = atanh(rs2)-A2*rs2;         % Bias term that yields desired fixed point

% Decompile into our state NPL
[Pd2,RsNPL2] = decomp_poly_ns_discrete(A2,B2,rs2,A2*rs2+d2,3,1);
RsNPL2 = reshape(RsNPL2,[size(RsNPL2,1),size(RsNPL2,2)*size(RsNPL2,3)]);

% Define symbolic output
syms a [Ts,1]; assume(a,'real');
% Shift operator
OsNPLp2 = zeros(size(Pd2)); 
OsNPLp2((2:Ts+1)+1,1:Ts) = eye(Ts)'; OsNPLp2 = OsNPLp2';
% Short-Time Fourier Transform Operator
kv = 0:Ts-1;
dftI = 1:Ts; dftL = length(dftI);
o1a = cos(2*pi/Ts*kv.*dftI')';              % Coefficients: cosine
o1b = sin(2*pi/Ts*kv.*dftI')';              % Coefficients: sine
O1a = [zeros(1,dftL);o1a;zeros(size(Pd2,1)-Ts-1,dftL)];
O1b = [zeros(1,dftL);o1b;zeros(size(Pd2,1)-Ts-1,dftL)];
OsNPL2 = [O1a O1b]';

% Compile
Wp2 = lsqminnorm(RsNPL2',OsNPLp2')';        % Feedback
W2 = lsqminnorm(RsNPL2',OsNPL2')';          % No feedback
disp(['Compiler residual: ' num2str([norm(Wp2*RsNPL2-OsNPLp2) norm(W2*RsNPL2-OsNPL2)])]);

% Construct feedback reservoir
T = 200;
Ap2 = A2 + B2(:,1:Ts)*Wp2(1:Ts,:);
Ro2 = zeros(N2,T); Ro2(:,1) = rs2;

% Generate input and prediction
x = .2*sawtooth((1:T)*2*pi/8) + (rand(1,T)-.5)*.1; x = x-mean(x);
for i = 2:T; Ro2(:,i) = tanh(Ap2*Ro2(:,i-1) + B2(:,end)*x(i-1)' + d2); end
Ro2 = Ro2(:,Ts+2:end);
WR2 = W2*Ro2;
Z = [sqrt(WR2(1:dftL,:).^2 + WR2((1:dftL)+dftL,:).^2)];
Z = Z([((Ts+1)/2:Ts), (1:(Ts+1)/2-1)],:);

% True STFT
S = (stft(x,Ts,'window',rectwin(Ts),'overlaplength',Ts-1,'FFTLength',Ts));
S = abs(S(:,1:end-2));
errv = norm(S - Z) / norm(S);
disp(['Relative error: ' num2str(errv)]);

