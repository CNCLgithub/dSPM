%% Prepare Space
clear; clc;

%% Global parameters
% Neurons
m = 2;
n = 30;

% Time
dt  = 0.001;
gam = 100;

% Reservoir
% Define reservoir
A  = sparse(zeros(n));
B  = (rand(n,m)-.5)*.1;
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
Aa(:,(1:m)+1)  = Aa(:,(1:m)+1)+B;  
Aa(:,1)        = Aa(:,1) + d;

GdNPL = gen_basis(Aa,PdS);

% Define symbolic dynamics
syms t; assume(t,'real'); syms x(t) [m,1]; syms xc [m,1]; x = x(t); 
assume(x,'real'); assume(xc,'real');

% Logic
a = 2/3; b = 4/3; c = 1; d = 1;

dx = [
    a*x(1) - b*x(1)*x(2);
   -c*x(2) + d*x(1)*x(2)
      ]; 

% Convert symbolic output to source code by extracting coefficients
pr = primes(2000)'; 
pr = pr(1:m);
[GAM,DXC] = sym2deriv(dx,x,pr,Pd1,PdS);
o         = zeros(m,size(C1,2)); 

o(:,(1:m)+1) = eye(m);
oS           = DXC;
OdNPL        = o+(1/gam)*oS;

% Compile
W = lsqminnorm(GdNPL', OdNPL')';
disp([log10(norm(W*GdNPL - (o + oS/gam),1)) log10(norm(W,1))]);

% Define RNN
RO = ReservoirTanhB(A,B,rs,xs,dt,gam); d = RO.d;
RT = RO.train(repmat([.9 .9]',[1,100,4]));

A     = B*W;
ROP   = ReservoirTanhB(A,0,rs,0,dt,gam);
ROP.d = d; 
ROP.r = RT(:,end);

% Output from conditioning
WRT = W*RT;

xt = zeros(1,10000);
% RP = ROP.trainSVD(repmat(xt,[1,1,4]),rank(W)); 
RP = ROP.train(repmat(xt,[1,1,4])); 

% Output from closed-loop network
WRP = W*RP;

%%

res = dspm_reservoir(...
    "n_neurons",n,...
    "n_recurrent_inputs",m,...
    "n_external_inputs",0,...
    "decompilation_order",4,...
    "jet_order",1,...
    "r_star",rs,... uses same r_star
    "dt",dt, ...
    "gamma",gam,...
    "integrator","rk4");

res.read_in_matrix_B = B; % uses same B as read in matrix for decompilation

res.decompile();  % decompile network
res.program(dx);  % use same symbolic ODE for programming
res.close_loop(); % compute and used programmed connectivity 

clc

err = round(log10(norm(W - res.read_out_matrix_W)));
fprintf("Error between methods' compiled readout W: ~1e%d\n", err)

errA = round(log10(norm(ROP.A - res.programmed_adjacency)));
fprintf("Error between methods' programmed adjacency, A: ~1e%d\n", errA)

% Use same initial state from Jason's run?
useSameConditionedState = false;

if useSameConditionedState,res.r0 = RT(:,end);
else,c_traj = res.condition([.9 .9]',[],100);end

[~,yt] = res.simulate(10000);

% fix different indexing assumptions between methods
jnet = WRP(:,2:end);
dnet =  yt(:,1:end-1);

% plot evolved trajectories over time
plot(dnet(1,1:end-1),dnet(2,1:end-1));hold on
plot(jnet(1,:),jnet(2,:))

err = round(log10(norm(norm(dnet - jnet))));
fprintf("Error between methods' trajectories (same r0, %s): ~1e%d\n",...
    string(useSameConditionedState),err)
%%

% n  = 100;
% dt = 0.001;

% syms t real; 
% syms x(t) [4,1]; x = x(t); assume(x,"real");
% 
% % Logic
% a = 2/3; b = 4/3; c = 1; d = 1;
% 
% dx = [
%     a*x(1) - b*x(1)*x(2);
%    -c*x(2) + d*x(1)*x(2)
%       ]; 

% Define symbolic dynamics
syms t; assume(t,'real'); syms x(t) [m,1]; syms xc [m,1]; x = x(t); 
assume(x,'real'); assume(xc,'real');

% Logic
a = 2/3; b = 4/3; c = 1; d = 1;

dx = [
    a*x(1) - b*x(1)*x(2);
   -c*x(2) + d*x(1)*x(2)
      ]; 

res = dspm_reservoir(...
    "n_neurons",n,...
    "n_recurrent_inputs",m,...
    "n_external_inputs",0,...
    "decompilation_order",6,...
    "jet_order",2,...
    "r_star",rs,... uses same r_star
    "dt",0.01, ...
    "gamma",gam,...
    "integrator","rk4");

res.read_in_matrix_B = B; % uses same B as read in matrix for decompilation

res.decompile();
res.program(-dx);
res.close_loop();

yt_cell = cell(6,1);

Tsim = 20000;
for i = 1:6

    res.condition([.9 .9]'+(i-1)*.1,[],100);
        
    [~,yt_cell{i}] = res.simulate(Tsim);

end


close all
figure; hold on

for i = 1:6
    plot(yt_cell{i}(1,:),yt_cell{i}(2,:))
end

A = res.programmed_adjacency;
fprintf("Spectral Radius of Compiled Adjecency: %f\n",norm(A,'fro'))
%%

% Compute Hamiltonian along trajectory
H = @(x,y) x - log(x) + (4/3)*y - (2/3)*log(y);

H_cell = cell(6,1);
for i = 1:6
    H_traj = zeros(1, size(yt,2));
    yt = yt_cell{i};
    for t = 1:size(yt,2)
        H_traj(t) = H(yt(1,t), yt(2,t));
    end
    
    H_cell{i} = H_traj;
end

figure;
aa = cell(6,1);
for i = 1:6
    data = H_cell{i}(1:end-1);
    plot(data); hold on

    xd = 1:numel(data);
    aa{i} = polyfit(xd, data, 1);

end

xlabel('Time step'); ylabel('H');
title('Hamiltonian (should be constant)');

dr = cellfun(@(x) x(1),aa)

%% Show reciprocity in r0
% If jason uses my conditioned state we converge and above shows that if I
% uses jason's conditioned state we converge

% ------- Jason uses my conditioned state

% Our Conditioning:
res.condition([.9 .9]',[],100);

% Jason's Simulation
ROP.r = res.r0;
xt    = zeros(1,10000);
RP    = ROP.train(repmat(xt,[1,1,4])); 
WRP   = W*RP;

% Our simulation
[~,yt] = res.simulate(10000);

% Test error
jnet = WRP(:,2:end);
dnet =  yt(:,1:end-1);

err1 = round(log10(norm(dnet - jnet)));


% ------- I use jason's conditioned state

% Jason's Conditioning:
RO = ReservoirTanhB(A,B,rs,xs,dt,gam);
RT = RO.train(repmat([.9 .9]',[1,100,4]));
r0 = RT(:,end);

% Jason's Simulation
ROP.r = r0;
xt    = zeros(1,10000);
RP    = ROP.train(repmat(xt,[1,1,4])); 
WRP   = W*RP;

% Our simulation
res.r0 = r0;
[~,yt] = res.simulate(10000);

% Test error
jnet = WRP(:,2:end);
dnet =  yt(:,1:end-1);

err2 = round(log10(norm(dnet - jnet)));

fprintf("Error between methods using our r0: ~1e%d\n", err1)
fprintf("Error between methods using Jason's r0: ~1e%d\n", err2)

%%

% Compute Hamiltonian along trajectory
H = @(x,y) x - log(x) + (4/3)*y - (2/3)*log(y);

H_traj = zeros(1, size(yt,2));
for i = 1:size(yt,2)
    H_traj(i) = H(yt(1,i), yt(2,i));
end

figure;
plot(H_traj);
xlabel('Time step'); ylabel('H');
title('Hamiltonian (should be constant)');






%%

% Compute dH/dt along trajectory
yt = yt_cell{3};  % pick middle orbit
H_vals = arrayfun(@(i) H(yt(1,i), yt(2,i)), 1:size(yt,2));
dH = diff(H_vals);

figure;
scatter(yt(1,1:end-1), yt(2,1:end-1), 10, dH, 'filled');
colorbar;
title('Energy injection rate around orbit');
xlabel('x'); ylabel('y');

%% Run the ~0.9-1.3 magnitude parameter set

n  = 30;
dt = 0.001;

% Define symbolic dynamics
syms t; assume(t,'real'); syms x(t) [m,1]; syms xc [m,1]; x = x(t); 
assume(x,'real'); assume(xc,'real');

% Logic
a = 2/3; b = 4/3; c = 1; d = 1;

dx = [
    a*x(1) - b*x(1)*x(2);
   -c*x(2) + d*x(1)*x(2)
      ]; 

res = dspm_reservoir(...
    "n_neurons",n,...
    "n_recurrent_inputs",m,...
    "n_external_inputs",0,...
    "decompilation_order",6,...
    "B_scale",0.05,...
    "jet_order",1,...
    "r_star",rs,... uses same r_star
    "dt",0.01, ...
    "gamma",gam,...
    "integrator","rk4");


res.decompile();
res.program(-dx);
res.close_loop();

yt_cell = cell(6,1);

Tsim = 20000;
for i = 1:6

    res.condition([.9 .9]'+(i-1)*.1,[],100);
        
    [~,yt_cell{i}] = res.simulate(Tsim);

end

Ham = computeHamiltonian(yt_cell,a,b,c,d);

%%

close all
figure; hold on

for i = 1:6
    plot(yt_cell{i}(1,:),yt_cell{i}(2,:))
end

A = res.programmed_adjacency;
fprintf("Spectral Radius of Compiled Adjecency: %f\n",norm(A,'fro'))



figure;
aa = cell(6,1);
for i = 1:6
    data = H_cell{i}(1:end-1);
    plot(data); hold on

    xd = 1:numel(data);
    aa{i} = polyfit(xd, data, 1);

end

xlabel('Time step'); ylabel('H');
title('Hamiltonian (should be constant)');

dr = cellfun(@(x) x(1),aa);






%%

function Ham = computeHamiltonian(yt_cell,a,b,c,d)
% Compute Hamiltonian along trajectory
H = @(x,y) d*x - c*log(x) + b*y - a*log(y);

H_cell = cell(6,1);
for i = 1:6
    H_traj = zeros(1, size(yt,2));
    yt = yt_cell{i};
    for t = 1:size(yt,2)
        H_traj(t) = H(yt(1,t), yt(2,t));
    end
    
    H_cell{i} = H_traj;
end

end