%% Prepare Space
clear; clc;
rng(0);                     % Set random seed for reproducibility


%% Logic gate simulations
% Problem parameters
m = 3;                      % Number: inputs (1 for feedback, 2 for signal)
n = 30;                     % Neurons per logic gate

% Reservoir parameters
dt   = 0.001;
gam  = 100;
A    = sparse(zeros(n));       % Initial RNN connectivity
B1   = (rand(n,m)-.5)*.05;     % Input matrix
rs1  = (rand(n,1)-.5);
xs   = zeros(m,1);
RO1  = ReservoirTanhB(A,B1,rs1,xs,dt,gam); 
d1   = RO1.d;

% Decompile RNN into dNPL
dv1 = A*rs1 + B1*xs + d1;
[Pd1,C1] = decomp_poly1_ns(A, B1, rs1, dv1, 4);

% Compute shift matrix
[Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
PdS       = zeros(size(Pd1,1));

for i = 1:length(Pdx)
    PdS(Pdx(i),Pdy(i)) = find(sum(Pd1==(Pd1(Pdx(i),:)+Pd1(Pdy(i),:)),2)==m);
end

% Define symbolic dynamics
xw = 0.025; xf = 0.1;
cx = 3/13;  ax = -cx/(3*xw^2);

syms t; assume(t,'real'); 
syms x(t) [m,1]; x = x(t); assume(x,'real');
dx = cell(6,1); dxb = cx*x(3)  + ax*x(3)^3;
dx{1} = dxb + -.1 + ( x(1) +xf)*( x(2) +xf)/(2*xf); % AND
dx{2} = dxb +  .1 + ( x(1) +xf)*(-x(2) -xf)/(2*xf); % NAND
dx{3} = dxb +  .1 + ( x(1) -xf)*(-x(2) +xf)/(2*xf); % OR
dx{4} = dxb + -.1 + ( x(1) -xf)*( x(2) -xf)/(2*xf); % NOR
dx{5} = dxb +  .0 + (-x(1)    )*( x(2)    )/(  xf); % XOR
dx{6} = dxb +  .0 + ( x(1)    )*( x(2)    )/(  xf); % XNOR

% Construct, train and predict
W = cell(6,1);
pr = primes(2000)'; pr = pr(1:m);

R = cell(6,1);
for i = 1:6
    % Shift basis
    [~,DX] = sym2deriv([0;0;10*dx{i}],x,pr,Pd1,PdS);
    
    % Finish generating basis
    Aa  = zeros(size(C1));
    Aa(:,(1:m)+1)  = Aa(:,(1:m)+1)+B1; 
    Aa(:,1) = Aa(:,1) + d1;
    RdNPL = gen_basis(Aa,PdS); 
    
    R{i} = RdNPL;

    % Train
    o = zeros(1,size(C1,2)); 
    o(1,m+1) = 1;
    oS = DX(end,:);
    OdNPL = o+oS/gam;
    W{i} = lsqminnorm(RdNPL', OdNPL')';
    disp(['Compiler residual: ' num2str(norm(W{i}*RdNPL - OdNPL))]);
end

% Predict
ot = ones(2,10000,4);
pt = cat(2,[-.1;-.1].*ot,[-.1;.1].*ot,[.1;-.1].*ot,[.1;.1].*ot);
wrp = cell(6,1);
for i = 1:6
    RP = ReservoirTanhB(A+B1(:,3)*W{i},B1(:,1:2),rs1,[0;0],dt,gam);
    RP.d = d1;
    rp = RP.train(pt);
    wrp{i} = W{i}*rp;
end



%% Combine to form adder for neural logic unit
O  = zeros(n); 
OB = zeros(n,1);
b1 = B1(:,1);
b2 = B1(:,2);
b3 = B1(:,3);
AC = [b3*W{5}  O        O       O       O;...
      b1*W{5}  b3*W{5}  O       O       O;...
      b1*W{5}  O        b3*W{1} O       O;...
      O        O        O       b3*W{1} O;...
      O        O        b1*W{1} b2*W{1} b3*W{3}];
BC = [[B1(:,1) B1(:,2) OB    ];...
      [OB     OB     B1(:,2)];...
      [OB     OB     B1(:,2)];...
      [B1(:,1) B1(:,2) OB    ];...
      [OB     OB     OB    ]];

% Predict
ot2 = ones(3,10000,4);
pt2 = cat(2,[-1;-1;-1].*ot2,...
            [-1;-1; 1].*ot2,...
            [-1; 1;-1].*ot2,...
            [-1; 1; 1].*ot2,...
            [ 1;-1;-1].*ot2,...
            [ 1;-1; 1].*ot2,...
            [ 1; 1;-1].*ot2,...
            [ 1; 1; 1].*ot2)*.1;
RAD = ReservoirTanhB(AC,BC,repmat(rs1,[5,1]),xs,dt,gam);
RAD.d = repmat(d1,[5,1]);
radp = RAD.train(pt2);
Wradp1 = [W{5}*radp((1:n)+n,:); W{3}*radp((1:n)+4*n,:)];
Wradp1(:,end)


%% Combine to form SR-latch
O = zeros(n); OB = zeros(n,1);
b1 = B1(:,1);
b2 = B1(:,2);
b3 = B1(:,3);
AC = [b3*W{4}  b2*W{4};...
      b1*W{4}  b3*W{4}];
BC = [[b1 OB ];...
      [OB b2]];

% Predict
ot3 = ones(2,10000,4);
pt3 = cat(2,[-1; 1].*ot3(:,1:1000,:),...
            [-1;-1].*ot3,...
            [ 1;-1].*ot3(:,1:1000,:),...
            [-1;-1].*ot3,...
            [-1; 1].*ot3(:,1:1000,:),...
            [-1;-1].*ot3)*.1;
RAD = ReservoirTanhB(AC,BC,repmat(rs1,[2,1]),[0;0],dt,gam);
RAD.d = repmat(d1,[2,1]);
radp = RAD.train(pt3);
Wradp2 = [W{4}*radp((1:n),:);W{4}*radp((1:n)+n,:)];
pt3 = pt3(:,1001:end,1);
Wradp2 = Wradp2(:,1001:end);
Wradp2(:,end)


%% Combine to form oscillator
O = zeros(n); OB = zeros(n,1);
b1 = B1(:,1);
b2 = B1(:,2);
b3 = B1(:,3);
AC = [b3*W{2}       O             (b1+b2)*W{2};...
      (b1+b2)*W{2}  b3*W{2}       O           ;...
      O             (b1+b2)*W{2}  b3*W{2}         ];
BC = repmat(OB,[3,1]);

% Predict
RAD = ReservoirTanhB(AC,BC,repmat(rs1,[3,1]),0,dt,gam);
RAD.d = repmat(d1,[3,1]); RAD.r = repmat(rs1,[3,1]);
radp = RAD.train(zeros(1,7000,4));
Wradp3 = [W{2}*radp((1:n),:);W{2}*radp((1:n)+n,:);W{2}*radp((1:n)+2*n,:)];


[R,D,L] = eig(AC);

lambda = diag(D);

scatter(real(lambda),imag(lambda)); hold on

t  = linspace(0,2*pi,1000);
xa = real(lambda(1:3));
ya = imag(lambda(1:3));
ra = abs(mean(xa) - xa(3));


scatter(mean(xa),mean(ya),'m')



plot(ra*cos(t)+mean(xa) , ra*sin(t))

hold off


%% Combine to form oscillator
O = zeros(n); OB = zeros(n,1);
b1 = B1(:,1);
b2 = B1(:,2);
b3 = B1(:,3);
AC = [b3*W{2}       O O O    (b1+b2)*W{2}      ;...
      (b1+b2)*W{2}  b3*W{2}       O O O        ;...
      O             (b1+b2)*W{2}  b3*W{2}   O O;...
      O O                       (b1+b2)*W{2}  b3*W{2}  O  ;...
      O O O                                 (b1+b2)*W{2}  b3*W{2}   
      ];
BC = repmat(OB,[5,1]);

% Predict
RAD = ReservoirTanhB(AC,BC,repmat(rs1,[5,1]),0,dt,gam);
RAD.d = repmat(d1,[5,1]); RAD.r = repmat(rs1,[5,1]);
radp = RAD.train(zeros(1,7000,4));
Wradp3 = [
    W{2}*radp((1:n),:)
    W{2}*radp((1:n)+n,:)
    W{2}*radp((1:n)+2*n,:)
    W{2}*radp((1:n)+3*n,:)
    W{2}*radp((1:n)+4*n,:)
    ];


zeta = 5;
[R,D,L] = eig(AC);

lambda = diag(D);
scatter(real(lambda),imag(lambda)); hold on

t  = linspace(0,2*pi,1000);
xa = real(lambda(1:zeta));
ya = imag(lambda(1:zeta));
ra = abs(mean(xa) - xa(zeta));


scatter(mean(xa),mean(ya),'m')



plot(ra*cos(t)+mean(xa) , ra*sin(t))

hold off

