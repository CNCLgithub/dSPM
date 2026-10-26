%% Prepare Space
clear; clc;
rng(0);                     % Set random seed for reproducibility


%% EXAMPLE: program multiple matrix operations with op-codes
% Problem parameters
K = 4;                          % size of K x K matrix

% Reservoir parameters
dt = 0.001;                     % Time step
gam = 100;                      % Time constant
N1 = 5000;                      % Number of neurons
if 1 % try A = 0
    A1 = sparse(zeros(N1));
else
    A1 = sparse((rand(N1)-.5).*(rand(N1)<.05))*1;         % Connectivity matrix
    A1 = A1 / abs(eigs(A1,1,'largestabs','MaxIterations',1e8))*.001;
end
B1 = (rand(N1,2*K^2)-.5)*.02;  % Input matrix
Bs1 = (rand(N1,2)-.5)*3;        % Input matrix for control variables c1, c2
xs1 = zeros(2*K^2,1);           % Operating point for inputs

% Find equilibrium points for different control variables c1, c2
rs1a = (rand(N1,1)-.5);         % Equilibrium point for c1=0, c2=0
d1a = atanh(rs1a)-A1*rs1a;      % Bias term that gives rs1 as equilibrium
d1b = d1a + Bs1(:,1);           % Bias term plus contributoin from c1=1
d1c = d1a + Bs1(:,2);           % Bias term plus contribution from c2=1
d1d = d1a + Bs1(:,1)+Bs1(:,2);  % Bias term plus contribution form c1=c2=1
R1 = ReservoirTanhB(A1,B1,rs1a,xs1,dt,gam);     % RNN object    
% Find equilibrium points rs2, rs3, and rs4 through simulation
R1.d = d1b; rs1b = R1.train(zeros(size(B1,2),1000,4)); rs1b = rs1b(:,end);
R1.d = d1c; rs1c = R1.train(zeros(size(B1,2),1000,4)); rs1c = rs1c(:,end);
R1.d = d1d; rs1d = R1.train(zeros(size(B1,2),1000,4)); rs1d = rs1d(:,end);

% Decompile into state NPL
[Pd1a,RsNPL1a] = decomp_poly1_ns(A1,B1,rs1a,A1*rs1a+d1a,3);
[Pd1b,RsNPL1b] = decomp_poly1_ns(A1,B1,rs1b,A1*rs1b+d1b,3);
[Pd1c,RsNPL1c] = decomp_poly1_ns(A1,B1,rs1c,A1*rs1c+d1c,3);
[Pd1d,RsNPL1d] = decomp_poly1_ns(A1,B1,rs1d,A1*rs1d+d1d,3);
RsNPL1  = [RsNPL1a RsNPL1b RsNPL1c RsNPL1d];
RsNPL1s = {RsNPL1a,RsNPL1b,RsNPL1c,RsNPL1d};

% Symbolic operations we want to program
syms a [K,K]; assume(a,'real'); syms b [K,K]; assume(b,'real'); 
OsNPL1a = zeros([K^2,size(Pd1a,1)]);
OsNPL1b = zeros([K^2,size(Pd1a,1)]);
OsNPL1c = zeros([K^2,size(Pd1a,1)]);
OsNPL1d = zeros([K^2,size(Pd1a,1)]);

% Operations to program
O1a = a+b;       % Addition
O1b = a-b;       % Subtraction
O1c = 2*a.*b;    % Element-wise multiplication
O1d = a*b;       % Matrix multiplication

% Convert symbolic operations into source code using coefficients
pr = primes(1000); pr = pr(1:2*K^2); pri = prod(pr.^Pd1a,2);
% For each output element, find the input elements that yield the operation
for i = 1:K^2
    % Addition
    [as,bs] = coeffs(O1a(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPL1a(i,ai) = as;
    % Subtraction
    [as,bs] = coeffs(O1b(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPL1b(i,ai) = as;
    % Element-wise multiplication
    [as,bs] = coeffs(O1c(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPL1c(i,ai) = as;
    % Matrix multiplication
    [as,bs] = coeffs(O1d(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPL1d(i,ai) = as;
end
OsNPL1s = {OsNPL1a,OsNPL1b,OsNPL1c,OsNPL1d};
OsNPL1 = [OsNPL1a OsNPL1b OsNPL1c OsNPL1d];

% Compile source code back into sNPL
W1 = lsqminnorm((RsNPL1)', (OsNPL1)')';
disp(['Compiler residual: ' num2str(norm(W1*RsNPL1 - OsNPL1,1))]);

% Simulate RNN using two random numerical instantiations of matrices
AM1 = (rand(K)-.5)*2; AM1 = AM1 / max(abs(AM1(:)));     % First matrix
BM1 = (rand(K)-.5)*2; BM1 = BM1 / max(abs(BM1(:)));     % Second matrix
X1 = repmat([AM1(:); BM1(:)],[1,500,4]);               % Reshape to input dim
R1 = ReservoirTanhB(A1,B1,rs1a,xs1,dt,gam); R1.r = rs1a; Ro1a = R1.train(X1);
R1 = ReservoirTanhB(A1,B1,rs1b,xs1,dt,gam); R1.r = rs1b; Ro1b = R1.train(X1);
R1 = ReservoirTanhB(A1,B1,rs1c,xs1,dt,gam); R1.r = rs1c; Ro1c = R1.train(X1);
R1 = ReservoirTanhB(A1,B1,rs1d,xs1,dt,gam); R1.r = rs1d; Ro1d = R1.train(X1);

% Predicted outputs
WR1 = reshape(W1*Ro1a(:,end), [K,K]);   % Prediction: addition
WR2 = reshape(W1*Ro1b(:,end), [K,K]);   % Prediction: subtraction
WR3 = reshape(W1*Ro1c(:,end), [K,K]);   % Prediction: element multiplication
WR4 = reshape(W1*Ro1d(:,end), [K,K]);   % Prediction: matrix multiplication
% True outputs
ABM1 = AM1+BM1;                         % Truth: addition
ABM2 = AM1-BM1;                         % Truth: subtraction
ABM3 = 2*AM1.*BM1;                      % Truth: element multiplication
ABM4 = AM1*BM1;                         % Truth: matrix multiplication
disp(['relative errors for operations: ',...
      num2str(norm(WR1-ABM1)/norm(ABM1)), ', ',...
      num2str(norm(WR2-ABM2)/norm(ABM2)), ', ',...
      num2str(norm(WR3-ABM3)/norm(ABM3)), ', ',...
      num2str(norm(WR4-ABM4)/norm(ABM4))]);


%% EXAMPLE: code composition with linear regression as an example

% Problem parameters
Kp = 5;                     % Input matrix size: K x K
AM2 = (rand(Kp)-.5)*2;      % Generate random matrix
AMT2 = AM2';
z = rand(Kp,1)-.5;
if(min(svd(AM2)) < 0.15)        
    disp('Max singular value of matrix is close to 0: solution may converge slowly');
end

% Reservoir parameters
gam = 100;                          % Time constant
N2 = 2500;                          % Number of neurons
A2 = sparse(zeros(N2));             % Initial connectivity
B2 = (rand(N2,Kp^2+2*Kp)-.5)*.001;  % Input matrix
rs2 = (rand(N2,1)-.5);              % Fixed point
d2 = atanh(rs2)-A2*rs2;             % Bias term that yields fixed point

% Decompile into state NPL
[Pd2,RsNPL2a] = decomp_poly1_ns(A2,B2,rs2,A2*rs2+d2,3);

% Symbolic operation we want to program
syms a [Kp,Kp]; assume(a,'real'); 
syms b [Kp,1]; assume(b,'real'); 
syms c [Kp,1]; assume(c,'real'); 
O2 = a*b + c;                       % Output function to program

% Convert symbolic operations into source code using coefficients
OsNPL2a = zeros([Kp,size(Pd2,1)]);
pr = primes(1000); pr = pr(1:(Kp^2+2*Kp)); pri = prod(pr.^Pd2,2);
for i = 1:Kp
    % Just multiplication
    [as,bs] = coeffs(O2(i)); as = double(as);
    bs = double(subs(bs,[a(:); b(:); c(:)],pr')); [ai,~] = find(bs-pri == 0);
    OsNPL2a(i,ai) = as;
end

% Compile source code back into sNPL
W2a = lsqminnorm(RsNPL2a', OsNPL2a')';        % Program using least squares
disp(['Compiler residual: ' num2str(norm(W2a*RsNPL2a - OsNPL2a,1))]);

% Define new RNN with the connection topology of 2 NPUs
AC = [zeros(N2)               B2(:,(1:Kp)+Kp^2)*W2a;...
      B2(:,(1:Kp)+Kp^2)*W2a   B2(:,(1:Kp)+Kp^2+Kp)*W2a];
BC = [B2(:,1:Kp^2) B2(:,(1:Kp)+Kp^2+Kp) zeros(N2,Kp^2);...
      zeros(N2,Kp^2+Kp) B2(:,1:Kp^2)];
R2 = ReservoirTanhB(AC,BC,[rs2;rs2],zeros(size(BC,2),1),dt,gam);
R2.d = [d2;d2]; R2.r = [rs2;rs2];

% Evolve RNN with matrix, vector, and matrix transpose until convergence
Ro2 = R2.trainSVD(repmat([-AM2(:);z;AMT2(:)],[1,1000,4]),2*size(W2a,1));
while(norm(Ro2(:,end)-Ro2(:,end-1)) > 1e-7)
    Ro2 = cat(2,Ro2,R2.trainSVD(repmat([-AM2(:);z;AMT2(:)],[1,1000,4]),2*size(W2a,1)));
end
WRP2  = W2a*Ro2(N2+1:end,:);
WRPM2 = WRP2(:,end);  % Predicted output
disp(['Relative error: ' num2str(norm(AM2\z - WRPM2) / norm(AM2\z))]);


%% EXAMPLE: dynamical Random Access Memory using control 
% Reservoir Parameters
gam = 100;
N3 = 1000;
dt = 0.01;
% A3 = sparse(zeros(N3));
A3 = sparse((rand(N3)-.5).*(rand(N3)<.05))*1;         % Connectivity matrix
A3 = A3 / abs(eigs(A3,1,'largestabs','MaxIterations',1e8))*.01;
% A3 = sparse(zeros(N3));
B3 = (rand(N3,3)-.5)*.6;
rs3 = (rand(N3,1)-.5);
xs3 = [0;0;0];

% Symbolic dynamics we want to program
syms t; assume(t,'real');
syms x(t) [3,1]; x = x(t); assume(x,'real');
dX = cell(4,1);
dX{1} = [10*(x(2)-x(1));...
         x(1) - 20*x(1).*x(3) - x(2);...
         20*x(1).*x(2) - 8/3*(x(3)+27/20)];
dX{2} = [-5*x(2) - 5*x(3) - 5*3/5;...
          5*x(1) + x(2);...
          50*5/3*x(1).*x(3) + 50*x(1) - 28.5*x(3) - 28.4*3/5];
dX{3} = [-1.4*x(1) - 4*x(2) - 4*x(3) - 10*x(2).^2;...
         -1.4*x(2) - 4*x(3) - 4*x(1) - 10*x(3).^2;...
         -1.4*x(3) - 4*x(1) - 4*x(2) - 10*x(1).^2]*1.5;
dX{4} = [-8*x(2);...
         25/4*x(1) + 8*x(3).^2;...
         25/32 + 20*x(2) - 10*x(3)];

% Decompile into dNPL
shv = [0 0; 0 1; 1 0; 1 1];             % Shift values
Bsh = (rand(N3,2)-.5)*2;
rsS3 = zeros(N3,size(shv,1));            % Fixed points for new shifts
dvS3 = zeros(N3,size(shv,1));

% Symbolic representaiton
GdNPL3p = cell(size(shv,1),1);
RO = ReservoirTanhB(A3,Bsh,rs3,zeros(size(Bsh,2),1),dt,gam); d = RO.d;
for i = 1:size(rsS3,2)
    % Obtain new fixed point
    RO.r = rs3;
    rsT  = RO.train(repmat(shv(i,:)',[1,2000,4]));
    rsS3(:,i) = rsT(:,end);
    dvS3(:,i) = A3*rsS3(:,i) + B3*xs3 + Bsh*shv(i,:)' + d;
    
    % Compute representation
%     [Pd1,C1] = decomp_poly1_ns(A3, B3, rs, dvS3(:,i), 6);
    [Pd1,C1,C2,C3a,C3b,C4a,C4b,C4c] = decomp_poly4_ns(A3,B3,rsS3(:,i),dvS3(:,i),gam,6);
    % Compute shift matrix
    [Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
    PdS = zeros(size(Pd1,1));
    for j = 1:length(Pdx)
        PdS(Pdx(j),Pdy(j)) = find(sum(Pd1==(Pd1(Pdx(j),:)+Pd1(Pdy(j),:)),2)==3);
    end
    % Shift basis
    pr = primes(20)'; pr = pr(1:size(Pd1,2));
    [GAM,DXC,DDXC,DDDXC,DXDXC,DXDXDXC,DDXDXC] = sym2deriv(dX{i},x,pr,Pd1,PdS);
    C2S  = sum(deriv2shift(C2 ,DXC     ,Pd1,PdS),3);
    C3aS = sum(deriv2shift(C3a,DXDXC   ,Pd1,PdS),3);
    C3bS = sum(deriv2shift(C3b,DDXC    ,Pd1,PdS),3);
    C4aS = sum(deriv2shift(C4a,DXDXDXC ,Pd1,PdS),3);
    C4bS = sum(deriv2shift(C4b,DDXDXC  ,Pd1,PdS),3);
    C4cS = sum(deriv2shift(C4c,DDDXC   ,Pd1,PdS),3);
    % Finish generating basis
    Aa = A3*(C1 + C2S + C3aS + C3bS + C4aS + C4bS + C4cS);
    Aa(:,(1:3)+1) = Aa(:,(1:3)+1) + B3; 
    Aa(:,1) = Aa(:,1) + Bsh*shv(i,:)' + d;
    GdNPL3p{i} = gen_basis(Aa,PdS);
end

% Convert symbolic dynamics to source code matrix
OdNPL3p = cell(size(shv,1),1);
for i = 1:size(rsS3,2)
    % Symbolic
    dx = dX{i}; 
    pr = primes(5)';
    [~,DX]  = sym2deriv(dx,x,pr,Pd1,PdS);
    OdNPL3p{i} = DX;
end

% Train
op  = zeros(3,size(GdNPL3p{1},2)); op(:,(1:3)+1) = eye(3);
OdNPL3 = []; GdNPL3 = [];
oM = cell(size(shv,1),1);
oSM = cell(size(shv,1),1);
for i = 1:size(shv,1)
    OdNPL3 = [OdNPL3 op+OdNPL3p{i}/gam];
    oM{i}  = op;
    oSM{i} = OdNPL3p{i};
    GdNPL3 = [GdNPL3 GdNPL3p{i}];
end
W3 = lsqminnorm(GdNPL3', OdNPL3')';
disp(log10([norm(W3*GdNPL3 - OdNPL3) norm(W3)]));

%%

% Predict
R3   = ReservoirTanhB(A3+B3*W3,Bsh,rs3,zeros(size(Bsh,2),1),dt,gam); R3.d = d;
WRP3 = cell(size(shv,1),1);

ds   = (rand(N3,1)-.5);
R3.r = rsS3(:,i) + ds;
timeEvolve = 5000;

Ro3 = R3.trainSVD(repmat(shv(2,:)',[1,timeEvolve,4]),rank(W3));
Wrp = W3*Ro3;

trajectory = Wrp;
nt = size(trajectory,2);
    
h = linspace(0,300,nt)'/360;
s = linspace(1,.4,nt)';
v = linspace(1,.4,nt)';

clr   = hsv2rgb([h s v]);


v = trajectory';
f = 1:nt;
v(end) = nan;
    
patch('Faces',f,'Vertices',v,...
    'FaceColor','none','FaceVertexCData',clr, ...
    'FaceVertexAlphaData',1,'AlphaDataMapping','none',...
    'FaceAlpha','flat','EdgeAlpha','flat','EdgeColor','flat',...
    'LineWidth',2,'tag','lines');

view(3)

% xlim([-1 1])
% ylim([-1 1])
% zlim([-1 1])

%%


R3.r = mean(rsS3,2) + (rand(N3,1)-.5)*.001;
Ro3 = R3.trainSVD(repmat(shv(1,:)',[1,50000,4]),rank(W3));
Wrp = W3*Ro3;

plot3(Wrp(1,:),Wrp(2,:),Wrp(3,:))


%%

% Vertices: N x 3
V = [ ...
    0 0 0
    1 0 0
    1 1 0
    0 1 0 ];

% Faces: M x K (indices into V)
F = [1 2 3 4];

figure
patch('Vertices', V, 'Faces', F, ...
      'FaceColor', 'cyan', ...
      'EdgeColor', 'k')

axis equal
view(3)
grid on








