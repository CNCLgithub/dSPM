%% Prepare Space
clear; clc;
% rng(0);                     % Set random seed for reproducibility


%% EXAMPLE: Decompile, program, and compile Lorenz into Guest RNN

clc

% Guest RNN parameters
NG = 15;  % Number of neurons for guest

time_stats = strings(4,1);

% Initial RNN connectivity
set_A_0 = true;
if set_A_0
    time_stats(1) = sprintf("Creating Guest RNN with A=0\n");
    AG = sparse(zeros(NG));
else
    time_stats(1) = sprintf("Running Guest RNN with A≠0\n");
    AG = (rand(NG)-.5);         
    AG = AG / abs(eigs(AG,1,'largestabs','MaxIterations',1e6)) * 0.01;
end

dt   = 0.001;               % Time step
gamG = 100;                 % Time constant
BG   = (rand(NG,3)-.5)*.4;  % Input matrix
rsG  = (rand(NG,1)-.5);     % Desired fixed point

% Set run time for evolution of Guest code block 
% Jason's original used: [100/dt , 200/dt] = {100,000 ; 200,000}
time_valuesG = [1000 2000];

RG = ReservoirTanhB_dc(AG,BG,rsG,[0;0;0],dt,gamG); 
dG = RG.d;                  % Bias term that yields desired fixed point

% Decompiling Guest
tic
% Decompile Guest RNN into dNPL
[PdG,GDNPG1,GDNPG2,GDNPG3a,GDNPG3b,GDNPG4a,GDNPG4b,GDNPG4c] = ...
    decomp_poly4_ns(AG, BG, rsG, AG*rsG+dG, gamG, 3);

% Compute shift matrix
[PdMsx,PdMsy] = find((sum(PdG,2) + sum(PdG,2)') <= max(sum(PdG,2)));
PdSG = zeros(size(PdG,1));
for i = 1:length(PdMsx)
    Pdv = PdG(PdMsx(i),:)+PdG(PdMsy(i),:);
    PdSG(PdMsx(i),PdMsy(i)) = find(sum(PdG==Pdv,2)==3);
end
time_stats(2) = sprintf("\t Decompilation time %.5f\n",toc);

% Programming Guest
tic
% Define symbolic dynamics
syms t; assume(t,'real'); syms y(t) [3,1]; syms ys [3,1]; y = y(t);
assume(y,'real'); assume(ys,'real');
scv = 200;
dy = [-10*y(1) + 10*y(2);...
      y(1)*(28-(scv*y(3)+27)) - y(2);...
      scv*y(1)*y(2) - 8/3*(y(3)+27/scv)]/10;

% Shift basis
prs = primes(6)';
[GAMs,DXCs,DDXCs,DDDXCs,DXDXCs,DXDXDXCs,DDXDXCs] = sym2deriv(dy,y,prs,PdG,PdSG);
C2Ss  = sum(deriv2shift(GDNPG2 ,DXCs     ,PdG,PdSG),3);
C3aSs = sum(deriv2shift(GDNPG3a,DXDXCs   ,PdG,PdSG),3);
C3bSs = sum(deriv2shift(GDNPG3b,DDXCs    ,PdG,PdSG),3);
C4aSs = sum(deriv2shift(GDNPG4a,DXDXDXCs ,PdG,PdSG),3);
C4bSs = sum(deriv2shift(GDNPG4b,DDXDXCs  ,PdG,PdSG),3);
C4cSs = sum(deriv2shift(GDNPG4c,DDDXCs   ,PdG,PdSG),3);

% Finish generating basis
AAa = AG*(GDNPG1 + C2Ss + C3aSs + C3bSs + C4aSs + C4bSs + C4cSs);
AAa(:,(1:3)+1)  = AAa(:,(1:3)+1)+BG;  AAa(:,1) = AAa(:,1) + dG;
GDNPG1          = gen_basis(AAa,PdSG);

% Convert symbolic output to source code by extracting coefficients
OdNPLG            = zeros(3,size(GDNPG1,2));
OdNPLG(:,(1:3)+1) = eye(3);
OdNPLG            = OdNPLG + DXCs/gamG;

% Compile source code back into sNPL
WG  = lsqminnorm(GDNPG1', OdNPLG')';


ABW = AG+BG*WG;    % New recurrent connectivity
% disp(['Compiler residual: ' num2str(norm(WG*GDNPG1 - OdNPLG))]);
time_stats(3) = sprintf("\t Programming time %.5f\n",toc);

% Evolving Guest 
tic
% Perform feedback and generate Lorenz
L   = LorenzZs([10;4;8]/scv,dt,[10 28 8/3 scv]);
LX  = L.propagate(time_valuesG(1));

% Running the actual Lorenz attractor through the network?
RG    = ReservoirTanhB_dc(AG,BG,rsG,[0;0;0],dt,gamG); 
RG.r  = rsG;
RTG   = RG.train(LX); 
RTG   = RTG(:,1001:end); % gets rid of the "burn in" from initial condition
WRTG  = WG*RTG;

% Just running the network with no inputs?
RPG   = RG.predict4(WG,time_valuesG(2)); 
WWRPG = WG*RPG(:,:,1);
time_stats(4) = sprintf("\t Evolution time %.5f\n",toc);

cellfun(@fprintf,time_stats)

figure
plot3(WWRPG(1,:),WWRPG(2,:),WWRPG(3,:)), hold on
plot3(WRTG(1,:),WRTG(2,:),WRTG(3,:),'--')
legend(["Network Self Evolution" , "Network with Lorenz Conditioning"],...
    "Location","southoutside")

%% EXAMPLE: Decompile, program, and compile Guest RNN into Host RNN

% Host RNN parameters
N = 2000; % Number of neurons for host

time_stats = strings(5,1);

% Initial RNN connectivity
set_A_0 = true;
if set_A_0
    time_stats(1) = sprintf("Running Host RNN with A=0\n");
    A = sparse(zeros(N));
else
    time_stats(1) = sprintf("Running Host RNN with A≠0\n");
    A = sparse((rand(N)-.5).*(rand(N)<.05)); 
    A = A / abs(eigs(A,1,'largestabs','MaxIterations',1e7))*.01;
end

% RNN parameters
gam = 100;                % Time constant
B   = (rand(N,NG)-.5)*.4; % Input matrix

host_r_star  = (rand(N,1)-.5); % RNN fixed point
host_x_star  = zeros(NG,1);    % Input operating point

% Set run time for evolution of Host code block 
% Jason's original used: [2000 , 400/dt]
time_valuesH = [100 1000];

% Conditioning the Host RNN
% Obtain Host RNN fixed point by running the Guest r* (rsG) as input
tic
RO   = ReservoirTanhB_dc(A,B,host_r_star,host_x_star,dt,gam); 
d    = RO.d;
RO.r = host_r_star; 
guest_r_star = repmat(rsG,[1,time_valuesH(1),4]); % repeat for T time steps
host_state_trajectory = RO.train(guest_r_star); 
host_r0_conditioned   = host_state_trajectory(:,end);
time_stats(2) = sprintf("\t Conditioning time %.5f\n",toc);

% Decompiling the Host RNN
tic
% Decompile Host RNN into dNPL
% [Pd1,GdNPLH] = decomp_poly1_ns(A,B,rsT,A*rsT + B*(xs+rsG) + d,4);

% find "anealed" bias term (dv) given the conditioned 
%    •  r0 = r_star 
%    •  x0 = host_x_star+rsG; where rsG is the guest_r_star 
%    •   d = atanh(rs) - A*host_r_star - B*host_x_star; 
%           This is implicitly set in object constructor 
%           RO = ReservoirTanhB_dc(...) above
dv = A*host_r0_conditioned + B*(host_x_star+rsG) + d;

% decompile the open-loop version of the Host
[Pd1,GDNPH1,GDNPH2,GDNPH3a,GDNPH3b,GDNPH4a,GDNPH4b,GDNPH4c] = ...
    decomp_poly4_ns(A,B,host_r0_conditioned,dv,gam,4);

% Compute shift matrix
[Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
PdS       = zeros(size(Pd1,1));
for i = 1:length(Pdx)
    PdS(Pdx(i),Pdy(i)) = find(sum(Pd1==(Pd1(Pdx(i),:)+Pd1(Pdy(i),:)),2)==NG);
end
time_stats(3) = sprintf("\t Decompilation time %.5f\n",toc);

% Programming the Host RNN
tic
% Define symbolic dynamics
syms t; assume(t,'real'); syms x(t) [NG,1]; syms xc [NG,1]; x = x(t); 
assume(x,'real'); assume(xc,'real');

% NOTE: this is where the programming is!!
%     specifically via the ABW transfering between the host and guest with 
%     ABW*xc being programmed_A*(symbolic input as guest state)
%     ABW*rsG implementing the feedback into the guest network
%     dG = atanh(rsG)-B(x_star_guest)- guest_A(r_star_guest) as bias
dxc = gamG*(-xc + tanh(ABW*xc+dG+ABW*rsG) - rsG);
dxc = taylor(dxc,xc,'order',4);
dx  = subs(dxc,xc,x);

% Shift basis
pr = primes(1000)'; pr = pr(1:size(Pd1,2));
[GAM,DXC,DDXC,DDDXC,DXDXC,DXDXDXC,DDXDXC] = sym2deriv(dx,x,pr,Pd1,PdS);
C2S  = sum(deriv2shift(GDNPH2 ,DXC     ,Pd1,PdS),3);
C3aS = sum(deriv2shift(GDNPH3a,DXDXC   ,Pd1,PdS),3);
C3bS = sum(deriv2shift(GDNPH3b,DDXC    ,Pd1,PdS),3);
C4aS = sum(deriv2shift(GDNPH4a,DXDXDXC ,Pd1,PdS),3);
C4bS = sum(deriv2shift(GDNPH4b,DDXDXC  ,Pd1,PdS),3);
C4cS = sum(deriv2shift(GDNPH4c,DDDXC   ,Pd1,PdS),3);

% Finish generating basis
Aa = A*(GDNPH1 + C2S + C3aS + C3bS + C4aS + C4bS + C4cS);
Aa(:,(1:NG)+1) = Aa(:,(1:NG)+1)+B;  Aa(:,1) = Aa(:,1) + d + B*rsG;
GdNPLH = gen_basis(Aa,PdS);

% Convert symbolic output to source code by extracting coefficients
OdNPLH = zeros(NG,size(GdNPLH,2));
OdNPLH(:,(1:NG)+1) = eye(NG);
oS      = DXC; 
oS(:,1) = oS(:,1) + gam*rsG;
OdNPLH  = OdNPLH + oS/gam;

% Compile source code back into sNPL
W = lsqminnorm(GdNPLH', OdNPLH')';
% disp(['Compiler residual: ' num2str(norm(W*GdNPLH - OdNPLH))]);
time_stats(4) = sprintf("\t Programming time %.5f\n",toc);

% Evolving the Host RNN
tic

% Perform feedback and generate Guest RNN, which itself generates a Lorenz
RO = ReservoirTanhB_dc(A,B,host_r_star,host_x_star,dt,gam);

% Runs conditioned on the first 1000 time points of the guest 
% self-feedback values from earlier:
%
%    % Just running the network with no inputs?
%    RPG   = RG.predict4(WG,time_valuesG(2)); 
%    
RT = RO.train(RPG(:,1:min(1000,time_valuesG(2)),:));

% Runs via host self-feedback
RP = RO.predict(W,time_valuesH(2));

% WG = lsqminnorm(GDNPG1', OdNPLG')'; Guest readout matrix
% W  = lsqminnorm(GdNPLH', OdNPLH')'; Host readout matrix

WRT  = W*RT;   % reading out W(host)->guest (guest conditioned)  
WRP  = W*RP;   % reading out W(host)->guest (self-feedback)  
WWRT = WG*WRT; % reading out Wguest(host->guest)->Lorenz (guest conditioned)  
WWRP = WG*WRP; % reading out Wguest(host->guest)->Lorenz (self-feedback)
time_stats(5) = sprintf("\t Evolution time %.5f\n",toc);

cellfun(@fprintf,time_stats)

figure,plot3(WWRP(1,:),WWRP(2,:),WWRP(3,:)),hold on
plot3(WRP(1,:),WRP(2,:),WRP(3,:),'--')

