%% Logic gate simulations
% Problem parameters
m = 3;                      % Number: inputs (1 for feedback, 2 for signal)
n = 70;                     % Neurons per logic gate

% Reservoir parameters
dt   = 0.001;
gam  = 300;
A    = sparse(zeros(n));       % Initial RNN connectivity
B    = (rand(n,m)-.5)*.05;     % Input matrix
rs   = (rand(n,1)-.5);
xs   = zeros(m,1);
RO1  = ReservoirTanhB(A,B,rs,xs,dt,gam); 
d1   = RO1.d;

% Decompile RNN into dNPL
dv1 = A*rs + B*xs + d1;
[Pd1,C1] = decomp_poly1_ns(A, B, rs, dv1, 4);

% Compute shift matrix
[Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
PdS       = zeros(size(Pd1,1));

for i = 1:length(Pdx)
    PdS(Pdx(i),Pdy(i)) = find(sum(Pd1==(Pd1(Pdx(i),:)+Pd1(Pdy(i),:)),2)==m);
end

% Finish generating basis
Aa  = zeros(size(C1));
Aa(:,(1:m)+1)  = Aa(:,(1:m)+1)+B; 
Aa(:,1)        = Aa(:,1) + d1;
RdNPL          = gen_basis(Aa,PdS); % polynomial weights R in R·𝜙(𝑦⃗)

% Define symbolic dynamics
xf = 0.1;  % desired fixed point for binary computation ±xf⟼[0,1]
m3 = -123.076923076923; % third order slope (global)
m1 = -(1+(1+m3)*xf^2); % first order slope (supercritical velocity correction to 
                       % enforce the Boolean fixed point)

syms t; assume(t,'real'); 
syms x(t) [m,1]; x = x(t); assume(x,'real');

tau     = 50; % time scale for dynamics 
dxbase  = m3*x(3)^3 + m1*x(3)  ;
dxlogic = (+xf) + (1/(2*xf))*(x(1)+xf)*(-x(2)-xf); % NAND


dx = [
    0 % external input 1
    0 % external input 2
    tau*(dxbase + dxlogic) % recurrent input/output
    ]; 

% Construct Programming Matrix
pr = primes(2000)'; pr = pr(1:m);
% Shift basis
[~,DX] = sym2deriv(dx,x,pr,Pd1,PdS);

% Compile
xp = zeros(1,size(C1,2)); 
xp(1,m+1) = 1;
dxp       = DX(end,:);

OdNPL = xp+(1/gam)*dxp; % Programmed weights P in P·𝜙(𝑦⃗)
W     = lsqminnorm(RdNPL', OdNPL')'; % Solve WR·𝜙(𝑦⃗) = P·𝜙(𝑦⃗)

disp("Compiler residual: " + norm(W*RdNPL - OdNPL));
%% Show standard 3-gate ring

% Combine to form oscillator
O  = zeros(n);   % zero blocks 
close all

Bext = B(:,1)+B(:,2); % output NPUⱼ bridging both inputs of NPUₖ (off-diagonal)
Brec = B(:,3); % recurrent input mapping (on-diagonal)

AC = [
      Brec*W    O      Bext*W % NPU₃ ⟼ (↺ NPU₁)
      Bext*W  Brec*W     O    % NPU₁ ⟼ (↺ NPU₂)
        O     Bext*W   Brec*W % NPU₂ ⟼ (↺ NPU₃)
      ];

BC = zeros(3*n,1); % No external inputs in composition
rs_extended = repmat(rs,[3,1]);
ds_extended = repmat(d1,[3,1]); 

% idx1  = find(AC~=0);
% nCull = 1;
% AC(idx1(randperm(numel(idx1),nCull))) = 0;

% Create closed-loop reservoir
RAD    = ReservoirTanhB(AC,BC,rs_extended,0,dt,gam);
RAD.r  = rs_extended;
RAD.d  = ds_extended;

tsim = 10000; 
xt   = zeros(1,tsim,4);
radp = RAD.train(xt);

% Index into NPU subspaces of the composed 3n dimensional network
NPU1_state = radp((1:n)+(0*n),:);
NPU2_state = radp((1:n)+(1*n),:);
NPU3_state = radp((1:n)+(2*n),:);

y_traj = [
    W*NPU1_state
    W*NPU2_state
    W*NPU3_state
    ];

% plot projected observable state space variables
tdh = findall(0,"-depth",3,"tag","timeDomain");
u1h = findall(0,"-depth",3,"tag","U(1)");

if isempty(tdh),figure,ax = subplot(313); ax(2) = subplot(3,1,[1,2]);
else, delete([tdh, u1h]),end
hold(ax,"on")

tvec = (1:tsim)*dt;
plot(ax(1),tvec , y_traj,'tag','timeDomain');

% show eignstructure of composed adjacency 
[R,D,L] = eig(AC);
lambda  = diag(D); % eigenvalues
nn0     = lambda(abs(lambda)>1e-6);

xa  = real(nn0); % cos(𝜃)
ya  = imag(nn0); % isin(𝜃)
x0  = nn0(mod(angle(nn0),pi)==0);
com = mean(nn0);
ra  = abs(com - x0); % radius

t  = linspace(0,2*pi,1000);

plot(ax(2),ra*cos(t)+mean(xa) , ra*sin(t),'k','tag','U(1)')
scatter(ax(2),mean(xa),mean(ya),'m',"tag","U(1)")
scatter(ax(2),xa,ya,'cyan',"tag","U(1)")
set(ax(2),"XAxisLocation","origin","YAxisLocation","origin")
axis(ax(2),"equal")

%%

zero_block  = zeros(n); 
readin_zero = 0;

Bext = sum(B(:,1:2),2); % output NPUⱼ bridging both inputs of NPUₖ (off-diagonal)
Brec = B(:,3); % recurrent input mapping (on-diagonal)

A_nand     = Brec*W;
B_implicit = Bext*W;

AC = [  
        A_nand     zero_block     B_implicit % NPU₃ ⟼ (↺ NPU₁) 
      B_implicit     A_nand       zero_block % NPU₁ ⟼ (↺ NPU₂) 
      zero_block   B_implicit       A_nand   % NPU₂ ⟼ (↺ NPU₃)
     ];

ACh = [  
        A_nand     zero_block     -B_implicit  ;...
      -B_implicit     A_nand       zero_block  ;...
       zero_block   -B_implicit       A_nand   
     ];

AC  = (1/3)*((1/gam)^2)*(AC + ACh');
BC  = readin_zero;
rsC = repmat(rs,[3,1]);

NC2 = numel(AC);
close all

% AC(randperm(floor(NC2)*.1)) = 0;

% Run
samples  = 7000;

RAD   = ReservoirTanhB(AC,BC,rsC,0,dt,gam);
RAD.d = repmat( d1,[3,1]); 
RAD.r = rsC;

tsim = 7000; 
xt   = zeros(1,7000,4);
radp = RAD.train(xt);

% Index into NPU subspaces of the composed 3n dimensional network
NPU1_state = radp((1:n)+(0*n),:);
NPU2_state = radp((1:n)+(1*n),:);
NPU3_state = radp((1:n)+(2*n),:);

y_traj = [
    W*NPU1_state
    W*NPU2_state
    W*NPU3_state
    ];

% plot projected observable state space variables
tdh = findall(0,"-depth",3,"tag","timeDomain");
u1h = findall(0,"-depth",3,"tag","U(1)");

if isempty(tdh),figure,ax = subplot(313); ax(2) = subplot(3,1,[1,2]);
else, delete([tdh, u1h]),end
hold(ax,"on")

tvec = (1:tsim)*dt;
plot(ax(1),tvec , y_traj,'tag','timeDomain');

% show eignstructure of composed adjacency 
[R,D,L] = eig(AC);
lambda  = diag(D); % eigenvalues
nn0     = lambda(abs(lambda)>1e-6);

xa  = real(nn0); % cos(𝜃)
ya  = imag(nn0); % isin(𝜃)
x0  = nn0(mod(angle(nn0),pi)==0);
com = mean(nn0);
ra  = abs(com - x0); % radius

t  = linspace(0,2*pi,1000);

% plot(ax(2),ra*cos(t)+mean(xa) , ra*sin(t),'k','tag','U(1)')
scatter(ax(2),mean(xa),mean(ya),'m',"tag","U(1)")
scatter(ax(2),xa,ya,'cyan',"tag","U(1)")
set(ax(2),"XAxisLocation","origin","YAxisLocation","origin")
axis(ax(2),"equal")


%% Augmented 3-gate ring
% Combine to form oscillator
O    = zeros(n);   % zero blocks 
Bext = B(:,1)+B(:,2); % output NPUⱼ bridging both inputs of NPUₖ (off-diagonal)
Brec = B(:,3); % recurrent input mapping (on-diagonal)

AC = [
      Brec*W    O      Bext*W % NPU₃ ⟼ (↺ NPU₁)
      Bext*W  Brec*W     O    % NPU₁ ⟼ (↺ NPU₂)
        O     Bext*W   Brec*W % NPU₂ ⟼ (↺ NPU₃)
      ];

ACconj = [
        Brec*W      -(Bext*W)'     O       % NPU₃ ⟼ (↺ NPU₁)
        O           Brec*W     -(Bext*W)'  % NPU₁ ⟼ (↺ NPU₂)
     -(Bext*W)'     O         Brec*W       % NPU₂ ⟼ (↺ NPU₃)
        ];

AC = (1/gam)^2*(AC + ACconj);

BC = zeros(3*n,1); % No external inputs in composition
rs_extended = repmat(rs,[3,1]);
ds_extended = repmat(d1,[3,1]); 

% Create closed-loop reservoir
RAD    = ReservoirTanhB(AC,BC,rs_extended,0,dt,gam);
RAD.r  = rs_extended;
RAD.d  = ds_extended;

tsim = 7000; 
xt   = zeros(1,7000,4);
radp = RAD.train(xt);

% Index into NPU subspaces of the composed 3n dimensional network
NPU1_state = radp((1:n)+(0*n),:);
NPU2_state = radp((1:n)+(1*n),:);
NPU3_state = radp((1:n)+(2*n),:);

y_traj = [
    W*NPU1_state
    W*NPU2_state
    W*NPU3_state
    ];

% plot projected observable state space variables
tdh = findall(0,"-depth",3,"tag","timeDomain");
u1h = findall(0,"-depth",3,"tag","U(1)");

if isempty(tdh),figure,ax = subplot(313); ax(2) = subplot(3,1,[1,2]);
else, delete([tdh; u1h]),end
hold(ax,"on")

tvec = (1:tsim)*dt;
plot(ax(1),tvec , y_traj,'tag','timeDomain');

% show eignstructure of composed adjacency 
[R,D,L] = eig(AC);
lambda  = diag(D); % eigenvalues
nn0     = lambda(abs(lambda)>1e-6);

xa  = real(nn0); % cos(𝜃)
ya  = imag(nn0); % isin(𝜃)
x0  = nn0(mod(angle(nn0),pi)==0);
com = mean(nn0);
ra  = abs(com - x0); % radius

t  = linspace(0,2*pi,1000);

plot(ax(2),ra*cos(t)+mean(xa) , ra*sin(t),'k','tag','U(1)')
scatter(ax(2),mean(xa),mean(ya),'m',"tag","U(1)")
scatter(ax(2),xa,ya,'cyan',"tag","U(1)")
set(ax(2),"XAxisLocation","origin","YAxisLocation","origin")
axis(ax(2),"equal")



%% Show 5-gate ring
O    = zeros(n);   % zero blocks 
Bext = B(:,1)+B(:,2); % output NPUⱼ bridging both inputs of NPUₖ (off-diagonal)
Brec = B(:,3); % recurrent input mapping (on-diagonal)

AC = [Brec*W     O      Bext*W     O      Bext*W     
      Bext*W   Brec*W     O      Bext*W     O       
        O      Bext*W   Brec*W     O      Bext*W 
      Bext*W     O      Bext*W   Brec*W     O   
        O      Bext*W    O       Bext*W   Brec*W    
      ];

BC = 0;

rs_extended = repmat(rs,[5,1]);
ds_extended = repmat(d1,[5,1]); 

% Create closed-loop reservoir
RAD    = ReservoirTanhB(AC,BC,rs_extended,0,dt,gam);
RAD.r  = rs_extended;
RAD.d  = ds_extended;

tsim = 7000; 
xt   = zeros(1,7000,4);
radp = RAD.train(xt);

% Index into NPU subspaces of the composed 3n dimensional network
NPU1_state = radp((1:n)+(0*n),:);
NPU2_state = radp((1:n)+(1*n),:);
NPU3_state = radp((1:n)+(2*n),:);
NPU4_state = radp((1:n)+(3*n),:);
NPU5_state = radp((1:n)+(4*n),:);

y_traj = [
    W*NPU1_state
    W*NPU2_state
    W*NPU3_state
    W*NPU4_state
    W*NPU5_state
    ];

% plot projected observable state space variables
tdh = findall(0,"-depth",3,"tag","timeDomain");
u1h = findall(0,"-depth",3,"tag","U(1)");

if isempty(tdh),figure,ax = subplot(313); ax(2) = subplot(3,1,[1,2]);
else, delete([tdh; u1h]),end
hold(ax,"on")

tvec = (1:tsim)*dt;
plot(ax(1),tvec , y_traj,'tag','timeDomain');

% show eignstructure of composed adjacency 
[R,D,L] = eig(AC);
lambda  = diag(D); % eigenvalues
nn0     = lambda(abs(lambda)>1e-6);

xa  = real(nn0); % cos(𝜃)
ya  = imag(nn0); % isin(𝜃)
x0  = nn0(mod(angle(nn0),pi)==0);
com = mean(nn0);
ra  = abs(com - x0); % radius

t  = linspace(0,2*pi,1000);

plot(ax(2),ra*cos(t)+mean(xa) , ra*sin(t),'k','tag','U(1)')
scatter(ax(2),mean(xa),mean(ya),'m',"tag","U(1)")
scatter(ax(2),xa,ya,'cyan',"tag","U(1)")
set(ax(2),"XAxisLocation","origin","YAxisLocation","origin")
axis(ax(2),"equal")