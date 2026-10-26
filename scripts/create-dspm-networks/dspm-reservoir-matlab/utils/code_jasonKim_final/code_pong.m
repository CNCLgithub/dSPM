%% Prepare Space
clear; clc;
rng(0);                     % Set random seed for reproducibility


%% Global parameters
% Neurons
m = 11;
n = 1000;
% Time
dt  = 0.001;
gam = 100;


%% Reservoir
% Define reservoir
A = sparse(zeros(n));
B = (rand(n,m)-.5)*.5;
rs = (rand(n,1)-.5);
xs = zeros(m,1);
RO = ReservoirTanhB(A,B,rs,xs,dt,gam); d = RO.d;
% Fixed points for new shift
RO.r = rs; rsT = rs;

% Decompile
dv = A*rsT + B*xs + d;
[Pd1,C1] = decomp_poly1_ns(A,B,rsT,dv,4);
% Compute shift matrix
[Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
PdS = zeros(size(Pd1,1));
for i = 1:length(Pdx)
    PdS(Pdx(i),Pdy(i)) = find(sum(Pd1==(Pd1(Pdx(i),:)+Pd1(Pdy(i),:)),2)==m);
end
% Finish generating basis
Aa = zeros(size(C1));
Aa(:,(1:m)+1)  = Aa(:,(1:m)+1)+B;  Aa(:,1) = Aa(:,1) + d;
GdNPL = gen_basis(Aa,PdS);

% Define symbolic dynamics
xw = 0.05; yw = 0.1;
xp = 0.05; yp = -0.1;
syms t; assume(t,'real'); syms x(t) [m,1]; syms xc [m,1]; x = x(t); 
assume(x,'real'); assume(xc,'real');
% Logic
xf = 0.1; cx = 3/13; ax = -cx/(3*0.025^2);
dx = [x(2)*.1;...% x(1) ball xpos
      20*(-.1 + (10*x(7)^2 -xf -xf)*( x(3) -xf)/(2*xf)  + cx*x(2)  + ax*x(2)^3);... x(2) srlatch output 
      20*(-.1 + (10*x(8)^2-xf -xf)*( x(2) -xf)/(2*xf)  + cx*x(3)  + ax*x(3)^3);... x(3) other nor for sr latch
      x(5)*.1;... % x(4)
      20*(-.1 + (10*x(9)^2 -xf -xf)*( x(6) -xf)/(2*xf)  + cx*x(5)  + ax*x(5)^3);... x(5)
      20*(-.1 + (50*x(10)^2 -xf-xf)*( x(5) -xf)/(2*xf)  + cx*x(6)  + ax*x(6)^3);... x(6)
      1000*(( x(1) -xw   )*x(7) - x(7)^3);... x(7) right wall collisoin reolution
      1000*(( -xw  -x(1) )*x(8) - x(8)^3);... x(8)
      1000*(( x(4)-yw)*x(9) - x(9)^3);... x(9)
      2000*((.002-((x(1)-x(11))^2+(x(4)-yp)^2))*x(10) - x(10)^3);... x(10)
      0 % x(11)
      ]; 

% Convert symbolic output to source code by extracting coefficients
pr = primes(2000)'; pr = pr(1:m);
[GAM,DXC] = sym2deriv(dx,x,pr,Pd1,PdS);
o = zeros(m,size(C1,2)); o(:,(1:m)+1) = eye(m);
oS = DXC;
OdNPL = o+oS/gam;

% Compile
W = lsqminnorm(GdNPL', OdNPL')';
disp([log10(norm(W*GdNPL - (o + oS/gam),1)) log10(norm(W,1))]);

% Define RNN
RO = ReservoirTanhB(A,B,rs,xs,dt,gam); d = RO.d;
RT = RO.train(repmat([-.05;.1;-.1;...
                      -.02;.1;-.1;...
                      0;0;0;0;-.05],[1,1000,4]));
ROP = ReservoirTanhB(A+B(:,1:m-1)*W(1:m-1,:),B(:,m),rs,0,dt,gam);
ROP.d = d; ROP.r = RT(:,end);

% Drive with inputs and play game
t1 = 30/dt; t2 = 43/dt; t3 = 5/dt;
xt = [linspace(-0.05,0.04,t1),...
      linspace(0.04,0.04,t2),...
      linspace(0.04,-0.02,t3)];
RP = ROP.trainSVD(repmat(xt,[1,1,4]),rank(W)); 

% Output
WRT = W*RT;    WRP = W*RP;


%% Decompiler Code
% Define RNN
N2 = 2000;
A2 = (rand(N2)-.5).*(rand(N2)<.05);  % Recurrent matrix
A2 = sparse(A2 / abs(eigs(A2,1,'largestabs','MaxIterations',1e6))) * .4;    % Normalize
B2 = (rand(N2,1)-.5)*.2;        % Input matrix
rs2 = (rand(N2,1)-.5);          % RNN Fixed Point
xs2 = 0;                        % Input Operating Point
d2 = atanh(rs2)-A2*rs2;         % Bias term that yields desired fixed point


% Data + Training
T2 = 200;
tz = linspace(0,3,T2);
X2 = sin(tz*2*pi*4) + sin(tz*8*pi*4)*.2;
R2 = zeros(N2,T2); R2(:,1:2) = [rs2 rs2];
Y2 = zeros(3,T2);
oF = 2;
of = [fir1(oF,.1,'high',[1 1 1]);...
      fir1(oF,.25,'high',[1 1 1])
      fir1(oF,.4,'high',[1 1 1])];
for i = oF+2:length(tz)
    R2(:,i) = tanh(A2*R2(:,i-1) + B2*X2(i-1) + d2);
    Y2(:,i) = of*X2(i-oF-1:i-1)';
end
R2 = R2(:,101:end);
Y2 = Y2(:,101:end);
X2 = X2(101:end);
tz = tz(1:T2-100);
W2 = lsqminnorm(R2',Y2')';
disp(['Compiler error: ' num2str(norm(W2*R2-Y2))]);

% Decompile
oO = 4;
oT = 4;
[Pd2,C2] = decomp_poly_ns_discrete(A2, B2, rs2, A2*rs2+B2*xs2+d2, oO, oT);
RsNPL2 = [C2(:,1,1) reshape(C2(:,2:end,:),[N2,(size(C2,2)-1)*size(C2,3)])];
OsNPL2 = zeros(3,size(RsNPL2,2));
OsNPL2(:,(0:oF)*(oO-1)+2) = of;


WC2 = zeros(3,oO,oT);
for i = 1:oT
    WC2(:,:,i) = W2*C2(:,:,i);
end
WC2 = [WC2(:,1,1) reshape(WC2(:,2:end,end:-1:1), [3,(size(C2,2)-1)*size(C2,3)])];
% O2 = [zeros(3,1) of zeros(3,oT-oF-1)];
disp(['Relative error: ' num2str(norm(WC2 - OsNPL2)/norm(OsNPL2))]);



