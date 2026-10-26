%% Prepare Space
clear; clc;
params_fig
rng(0);


%% Plotting parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 9.5];                       % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00  5.00  9.00  4.50];...
        [ 9.00  5.00  4.50  4.50];...
        [13.50  5.00  4.50  4.50];...
        [ 0.00  0.00  4.50  4.50];...
        [ 4.50  0.00  4.50  4.50];...
        [ 9.00  0.00  4.50  4.50];...
        [13.50  0.00  4.50  4.50]];

% Adjust position for margins
subp = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat = subp(:,3) ./ subp(:,4);

% Label Position in cm
labX = -fMarg(1);
labY = fMarg(4)-.2;
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'color','w');

% Set random seed for reproducibility
rng(0);


%% Perform example true and RNN DFT 
% Parameters
Ts = 50;

% Signal
T = 500;
infun = @(Tm) (rand(1,Tm)-.5)*.2;
x = infun(T);

% RNN
N = 200;                               % Number of neurons
A = zeros(N);        % Connectivity matrix
B = (rand(N,Ts)-.5)*.01;                  % Input matrix
rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
d = atanh(rs)-A*rs;
% Generate symbolic decomposition
[Pd1,C1] = decomp_poly_ns_discrete(A,B,rs,A*rs+d,3,1);
C1M = reshape(C1,[size(C1,1),size(C1,2)*size(C1,3)]);
% Shift operator
Osh = zeros(size(Pd1)); 
Osh((2:Ts)+1,1:Ts-1) = eye(Ts-1)'; Osh = Osh';
Wp = lsqminnorm(C1M',Osh')';
% Lagged output
o = [0 1 zeros(1,size(Pd1,1)-2)];
W = lsqminnorm(C1M',o')';
% Generate input and prediction
Ap = B(:,1:Ts-1)*Wp(1:Ts-1,:);
R = zeros(N,T); R(:,1) = rs;
for i = 2:T; R(:,i) = tanh(Ap*R(:,i-1) + B(:,end)*x(i-1)' + d); end
WR = W*R;


%% Draw Signal (a)
pInd = 1;
subplot('position',subpN(pInd,:)); cla;
yR = .4*2/3;
CL = lines(4);

% Signal
plot(1:T,x,'color',CL(1,:),'linewidth',.7);
hold on;
plot(WR,'color',CL(2,:),'linewidth',.7);
plot(WR(Ts+1:end) - x(1:end-Ts),'color',CL(3,:),'linewidth',2);

% Axes
plot_spline([0,T; -yR*3/4,-yR*3/4],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,0; -yR*3/4,yR*3/4],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)

% Legend
plot([-40 40]+100,[1 1]*.16,'-','color',CL(1,:),'linewidth',.7);
text(100,.20,'input $x_t$',TextC{:});
plot([-40 40]+260,[1 1]*.16,'-','color',CL(2,:),'linewidth',.7);
text(260,.20,'output $W${\boldmath$r_t$}',TextC{:});
plot([-40 40]+420,[1 1]*.16,'-','color',CL(3,:),'linewidth',2);
text(420,.20,'error $W${\boldmath$r_{t+50}$}$- x_t$',TextC{:});

hold off;
axis([-T/17 T -yR yR]);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{a} RNN programmed to output a 50-step lagged input',TitleL{:});
text(0,-yR/1.15,'0',TextL{:});
text(T,-yR/1.15,num2str(T),TextR{:});
text(T/2,-yR/1.05,'$t$',TextC{:});
text(-T/80,0,'$0$',TextR{:});
text(-T/80,yR*3/4,num2str(yR*3/4),TextR{:});
text(-T/80,-yR*3/4,num2str(-yR*3/4),TextR{:});
set(gcf,'color','w');
set(gca,'visible',0);


%% Draw Signal (b)
pInd = 2;
subplot('position',subpN(pInd,:)); cla;
scv = .14; scva = .12;

% Signal
scatter(x(1:end-Ts),WR(Ts+1:end),5,CL(4,:),'filled');
% Axes
hold on;
plot_spline([-scva scva; 0 0],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,0; -scva scva],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
hold off;
axis([-1 1 -1 1]*scv);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{b} lagged input \textit{vs} RNN out',TitleL{:});
text(scv*.8,-scv/10,'$x_t$',TextC{:});
text(-scv/10,scv*.8,'$W${\boldmath$r_{t+50}$}',TextR{:});
set(gcf,'color','w');
set(gca,'visible',0);


%% Parameter sweep: programmed RNN
% Parameters
NR = 200:200:2000;
BR = linspace(.01,1,10);
eEPG = zeros(length(NR),length(BR));


for i = 1:length(NR)
    disp(i);
    N = NR(i);
    for j = 1:length(BR)
        A = sparse(zeros(N));        % Connectivity matrix
        B = (rand(N,Ts)-.5)*BR(j);                  % Input matrix
        rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
        d = atanh(rs)-A*rs;

        % Generate symbolic decomposition
        [Pd1,C1] = decomp_poly_ns_discrete(A,B,rs,A*rs+d,3,1);
        C1M = reshape(C1,[size(C1,1),size(C1,2)*size(C1,3)]);

        % Shift operator
        Osh = zeros(size(Pd1)); 
        Osh((2:Ts)+1,1:Ts-1) = eye(Ts-1)'; Osh = Osh';
        Wp = lsqminnorm(C1M',Osh')';
        % Lagged output
        o = [0 1 zeros(1,size(Pd1,1)-2)];
        W = lsqminnorm(C1M',o')';

        % Generate signal
        x = infun(T);
        % Prediction
        Ap = B(:,1:Ts-1)*Wp(1:Ts-1,:);
        R = zeros(N,T); R(:,1) = rs;
        for k = 2:T; R(:,k) = tanh(Ap*R(:,k-1) + B(:,end)*x(k-1)' + d); end
        WR = W*R;

        % Error
        eEPG(i,j) = norm(x(1:end-Ts)-WR(Ts+1:end)) / norm(x(1:end-Ts));
    end
end


%% progRNN error: First training time (e)
pInd = 3;
subplot('position',subpN(pInd,:)); cla;
eEp = eEPG';
maxv = 1;
eEp(eEp > maxv) = maxv;
CP = parula(100);

% Scatter
xVES = 1; yVES = 1; mts = 160;
[XGO,YGO] = meshgrid((1:size(eEp,2))*xVES,(1:size(eEp,1))*yVES); 
XGO = XGO+.1; YGO = YGO+.2;
scatter(XGO(:),YGO(:),mts,interp1(linspace(0,maxv,100),CP,eEp(:)),'s','filled','clipping',0);

% Axes
bw = .3;
hold on;
plot_spline([bw,max(XGO(:))+1-bw; [0 0] + YGO(1,1)-1+bw],'head',1,'headpos',1,...
            'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3);
plot_spline([bw bw; min(YGO(:))-.5-bw,max(XGO(:))+1-bw],'head',1,'headpos',1,...
            'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3);
axis([-.5 length(BR)+2 -.5 length(NR)+2]);
set(gca,'visible',0);

% Colorbar
scatter(linspace(1,1,size(CP,1))*max(XGO(:))+1,linspace(1.8,9.2,size(CP,1)),10,CP,'filled','s');
text(max(XGO(:))+1.7,mean(YGO(:)),'relative error',TextC{:},'rotation',90);
text(max(XGO(:))+1,10,num2str(maxv),TextC{:});
text(max(XGO(:))+1,1,'0',TextC{:});
hold off;

% Text
text(labX,subp(pInd,4)+labY,'\textbf{c} rel. error: programmed',TitleL{:});
for i = [1 size(XGO,2)]; text(XGO(1,i)-bw,YGO(1,i)-1-bw,num2str(NR(i)),TextC{:}); end
text(mean(XGO(:)),min(YGO(:))-1.8,'# neurons',TextC{:});
text(min(XGO(:))-1.6,mean(YGO(:)),'$b$',TextR{:},'rotation',90);
text(min(XGO(:))-1.4,min(YGO(:))-.6,num2str(min(BR)),TextL{:},'rotation',90);
text(min(XGO(:))-1.4,max(YGO(:))+.6,num2str(max(BR)),TextR{:},'rotation',90);
drawnow;


%% Relative error matrix across multiple training lengths
Ttrain = [201 1001 2001 5001];
eE = zeros(length(NR),length(BR),length(Ttrain));
errM = zeros(length(NR),length(BR));
Wnorm = zeros(length(NR),length(BR),length(Ttrain));

for i = 1:length(NR)
    disp(i);
    N = NR(i);
    for j = 1:length(BR)
        % Normalize adjacency matrix
        A = (rand(N)-.5).*(rand(N)<.05);
        emax = abs(eigs(A,1,'largestabs','MaxIterations',1e7));
        A = A / emax;
        % Rest of parameters
        B = (rand(N,1)-.5)*BR(j);
        rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
        d = atanh(rs)-A*rs;

        for k = 1:length(Ttrain)
            % Input
            x = infun(Ttrain(k));
            % Evolve
            R = zeros(N,Ttrain(k)); R(:,1) = rs;
            for l = 2:Ttrain(k); R(:,l) = tanh(A*R(:,l-1) + B*x(l-1) + d); end
            R = R(:,Ts+1:end);
            W = lsqminnorm(R',x(1:end-Ts)')';
            errM(i,j,k) = norm(W*R - x(1:end-Ts));
    
            % Predict
            x = infun(T);
            R = zeros(N,T); R(:,1) = rs;
            for l = 2:T; R(:,l) = tanh(A*R(:,l-1) + B*x(l-1) + d); end
            WR = W*R(:,Ts+1:end);
            
            % Error
            eE(i,j,k) = norm(x(1:end-Ts)-WR)/norm(x(1:end-Ts));
            Wnorm(i,j,k) = norm(W);
        end
    end
end


%% randRNN error (d-g)
labT = {'d','e','f','g'};
for i = 1:4
    pInd = i+3;
    subplot('position',subpN(pInd,:)); cla;
    eEp = eE(:,:,i)';
    maxv = 1;
    eEp(eEp > maxv) = maxv;
    CP = parula(100);
    
    % Scatter
    xVES = 1; yVES = 1; mts = 160;
    [XGO,YGO] = meshgrid((1:size(eEp,2))*xVES,(1:size(eEp,1))*yVES); 
    XGO = XGO+.1; YGO = YGO+.2;
    scatter(XGO(:),YGO(:),mts,interp1(linspace(0,maxv,100),CP,eEp(:)),'s','filled','clipping',0);
    
    % Axes
    bw = .3;
    hold on;
    plot_spline([bw,max(XGO(:))+1-bw; [0 0] + YGO(1,1)-1+bw],'head',1,'headpos',1,...
                'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3);
    plot_spline([bw bw; min(YGO(:))-.5-bw,max(XGO(:))+1-bw],'head',1,'headpos',1,...
                'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3);
    axis([-.5 length(BR)+2 -.5 length(NR)+2]);
    set(gca,'visible',0);
    
    % Colorbar
    scatter(linspace(1,1,size(CP,1))*max(XGO(:))+1,linspace(1.8,9.2,size(CP,1)),10,CP,'filled','s');
    text(max(XGO(:))+1.7,mean(YGO(:)),'relative error',TextC{:},'rotation',90);
    text(max(XGO(:))+1,10,num2str(maxv),TextC{:});
    text(max(XGO(:))+1,1,'0',TextC{:});
    hold off;
    
    % Text
    text(labX,subp(pInd,4)+labY-.25,['\textbf{' labT{i} '} rel. error: $\mathrm{T_{train}} = $ ' num2str(Ttrain(i)-1)],TitleL{:});
    for j = [1 size(XGO,2)]; text(XGO(1,j)-bw,YGO(1,j)-1-bw,num2str(NR(j)),TextC{:}); end
    text(mean(XGO(:)),min(YGO(:))-1.8,'# neurons',TextC{:});
    text(min(XGO(:))-1.6,mean(YGO(:)),'$b$',TextR{:},'rotation',90);
    text(min(XGO(:))-1.4,min(YGO(:))-.6,num2str(min(BR)),TextL{:},'rotation',90);
    text(min(XGO(:))-1.4,max(YGO(:))+.6,num2str(max(BR)),TextR{:},'rotation',90);
    if(i==1); text(fSize(1)/2,subp(pInd,4)+.2,'relative errors for conventional RNN trained for duration $\mathrm{T_{train}}$', TitleC{:}); end
end


%% Save
fName = 'suppfig_nlag_50';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, fName, 'pdf');
set(gcf, 'Renderer', 'opengl');

