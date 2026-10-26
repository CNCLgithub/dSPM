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
subp = [[ 0.00  5.00  4.50  4.50];...
        [ 4.50  5.00  4.50  4.50];...
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
Ts = 49;
mts = max(1*99/Ts,1);

% Signal
T = 500;
infun = @(Tm) .2*sawtooth(linspace(0,2*pi*25,Tm+1)) + (rand(1,Tm+1)-.5)*.1;
x = infun(T); x = x(2:end);

% FFT
S = (stft(x,Ts,'window',rectwin(Ts),'overlaplength',Ts-1,'FFTLength',Ts));
S = abs(S(:,1:end-2));

% RNN
N = 500;                               % Number of neurons
A = zeros(N);        % Connectivity matrix
B = (rand(N,Ts+1)-.5)*.01;                  % Input matrix
rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
d = atanh(rs)-A*rs;
% Generate symbolic decomposition
[Pd1,C1] = decomp_poly_ns_discrete(A,B,rs,A*rs+d,3,1);
C1M = reshape(C1,[size(C1,1),size(C1,2)*size(C1,3)]);
% Representation
kv = 0:Ts-1;
% Shift operator
Osh = zeros(size(Pd1)); 
Osh((2:Ts+1)+1,1:Ts) = eye(Ts)'; Osh = Osh';
Wp = lsqminnorm(C1M',Osh')';
% STFT operator
dftI = 1:Ts; dftL = length(dftI);
o1a = cos(2*pi/Ts*kv.*dftI')';
o1b = sin(2*pi/Ts*kv.*dftI')';
O1a = [zeros(1,dftL);o1a;zeros(size(Pd1,1)-Ts-1,dftL)];
O1b = [zeros(1,dftL);o1b;zeros(size(Pd1,1)-Ts-1,dftL)];
OA = [O1a O1b]';
W = lsqminnorm(C1M',OA')';
% Generate input and prediction
Ap = B(:,1:Ts)*Wp(1:Ts,:);
R = zeros(N,T); R(:,1) = rs;
for i = 2:T; R(:,i) = tanh(Ap*R(:,i-1) + B(:,end)*x(i-1)' + d); end
R = R(:,Ts+2:end);
WR = W*R;
Z = [sqrt(WR(1:dftL,:).^2 + WR((1:dftL)+dftL,:).^2)];
Z = Z([((Ts+1)/2:Ts), (1:(Ts+1)/2-1)],:);

% Analysis
maxv = max(abs([S(:);Z(:);S(:)-Z(:)]));


%% Draw Signal (a)
pInd = 1;
subplot('position',subpN(pInd,:)); cla;
yR = .4;

% Signal
plot(1:T,x);
% Axes
hold on;
plot_spline([0,T; -yR*3/4,-yR*3/4],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,0; -yR*3/4,yR*3/4],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,T; 0,0],'head',0,'ratio',sRat(pInd),'linewidth',.5)
hold off;
axis([-T/8 T -yR yR]);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{a} input: noisy sawtooth',TitleL{:});
text(0,-yR,'0',TextL{:});
text(T,-yR,num2str(T),TextR{:});
text(T/2,-yR*9/8,'$t$',TextC{:});
text(-T/80,0,'$0$',TextR{:});
text(-T/80,yR*3/4,num2str(yR*3/4),TextR{:});
text(-T/80,-yR*3/4,num2str(-yR*3/4),TextR{:});
set(gcf,'color','w');
set(gca,'visible',0);


%% Draw FFT (b)
pInd = 2;
subplot('position',subpN(pInd,:)); cla;

% Scatter
xVES = 1; yVES = .018*(49/Ts);
[XGO,YGO] = meshgrid((1:size(S,2))*xVES,(1:size(S,1))*yVES); 
XGO = XGO+.1; YGO = .95 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1],Cw1,S(:)/maxv),'s','filled','clipping',0);

% Axes
hold on;
plot_spline([0,T-Ts; .06 .06],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,0; .06 .94],'head',0,'ratio',sRat(pInd),'linewidth',1);
hold off;
axis([-T/20 T-Ts 0 1]);
set(gca,'visible',0);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{b} true windowed DFT',TitleL{:});
text(0,0,'$0$',TextL{:});
text(size(S,2),0,num2str(size(S,2)),TextR{:});
text((T-Ts)/2,-.055,'$t$',TextC{:});
text(-(T-Ts)/80,mean(YGO(:)),'$0$',TextR{:});
text(-(T-Ts)/80,min(YGO(:)),'$1$',TextR{:});
text(-(T-Ts)/80,max(YGO(:))-.01,'$1$',TextR{:});
text(-(T-Ts)/10,mean(YGO(:)),'cycles per window size',TextC{:},'rotation',90);
drawnow;


%% RNN FFT (c)
pInd = 3;
subplot('position',subpN(pInd,:)); cla;

% Scatter
xVES = 1; yVES = .018*(49/Ts);
[XGO,YGO] = meshgrid((1:size(Z,2))*xVES,(1:size(Z,1))*yVES); 
XGO = XGO+.1; YGO = .95 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1],Cw1,Z(:)/maxv),'s','filled','clipping',0);

% Axes
hold on;
plot_spline([0,T-Ts; .06 .06],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',1,'headwidth',3,'headlength',3)
plot_spline([0,0; .06 .94],'head',0,'ratio',sRat(pInd),'linewidth',1);
hold off;
axis([-T/20 T-Ts 0 1]);
set(gca,'visible',0);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{c} RNN windowed DFT',TitleL{:});
text(0,0,'$0$',TextL{:});
text(size(Z,2),0,num2str(size(Z,2)),TextR{:});
text((T-Ts)/2,-.055,'$t$',TextC{:});
text(-(T-Ts)/80,mean(YGO(:)),'$0$',TextR{:});
text(-(T-Ts)/80,min(YGO(:)),'$1$',TextR{:});
text(-(T-Ts)/80,max(YGO(:))-.01,'$1$',TextR{:});
text(-(T-Ts)/10,mean(YGO(:)),'cycles per window size',TextC{:},'rotation',90);
drawnow;


%% Relative error matrix for programmed RNN across multiple parameters
NR = 200:200:2000;
BR = linspace(.01,1,10);
Ttest = 501;
eEPG = zeros(length(NR),length(BR));

% Representation
kv = 0:Ts-1;

for i = 1:length(NR)
    disp(i);
    N = NR(i);
    for j = 1:length(BR)
        A = sparse(zeros(N));        % Connectivity matrix
        B = (rand(N,Ts+1)-.5)*BR(j);                  % Input matrix
        rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
        d = atanh(rs)-A*rs;

        % Generate signal
        x = infun(Ttest); x = x(2:end);
    
        % Generate symbolic decomposition
        [Pd1,C1] = decomp_poly_ns_discrete(A,B,rs,A*rs+d,3,1);
        C1M = reshape(C1,[size(C1,1),size(C1,2)*size(C1,3)]);

        % Shift operator
        Osh = zeros(size(Pd1)); 
        Osh((2:Ts+1)+1,1:Ts) = eye(Ts)'; Osh = Osh';
        Wp = lsqminnorm(C1M',Osh')';
        % STFT operator
        dftI = 1:Ts; dftL = length(dftI);
        o1a = cos(2*pi/Ts*kv.*dftI')';
        o1b = sin(2*pi/Ts*kv.*dftI')';
        O1a = [zeros(1,dftL);o1a;zeros(size(Pd1,1)-Ts-1,dftL)];
        O1b = [zeros(1,dftL);o1b;zeros(size(Pd1,1)-Ts-1,dftL)];
        OA = [O1a O1b]';

        % Train
        W = lsqminnorm(C1M',OA')';
        % Generate input and prediction
        Ap = B(:,1:Ts)*Wp(1:Ts,:);
        R = zeros(N,Ttest); R(:,1) = rs;
        for k = 2:Ttest; R(:,k) = tanh(Ap*R(:,k-1) + B(:,end)*x(k-1)' + d); end
        R = R(:,Ts+2:end);
        WR = W*R;
        Z = [sqrt(WR(1:dftL,:).^2 + WR((1:dftL)+dftL,:).^2)];
        Z = Z([((Ts+1)/2:Ts), (1:(Ts+1)/2-1)],:);

        % FFT
        S = (stft(x,Ts,'window',rectwin(Ts),'overlaplength',Ts-1,'FFTLength',Ts));
        S = abs(S(:,1:end-2));

        % Error
        eEPG(i,j) = norm(S-Z)/norm(S);
    end
end


%% progRNN error: First training time (d)
pInd = 4;
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
text(labX,subp(pInd,4)+labY,'\textbf{d} rel. error: programmed',TitleL{:});
for i = [1 size(XGO,2)]; text(XGO(1,i)-bw,YGO(1,i)-1-bw,num2str(NR(i)),TextC{:}); end
text(mean(XGO(:)),min(YGO(:))-1.8,'# neurons',TextC{:});
text(min(XGO(:))-1.6,mean(YGO(:)),'$b$',TextR{:},'rotation',90);
text(min(XGO(:))-1.4,min(YGO(:))-.6,num2str(min(BR)),TextL{:},'rotation',90);
text(min(XGO(:))-1.4,max(YGO(:))+.6,num2str(max(BR)),TextR{:},'rotation',90);
drawnow;


%% Relative error matrix across multiple training lengths
NR = 200:200:2000;
BR = linspace(.01,1,10);
Ttrain = [201 1001 2001 5001];
Ttest = 501;
eE = zeros(length(NR),length(BR));
Wnorm = zeros(length(NR),length(BR),length(Ttrain));

for i = 1:length(NR)
    disp(i);
    N = NR(i);
    for j = 1:length(BR)
        % Normalize adjacency matrix
        A = (rand(N)-.5).*(rand(N)<.05);
        emax = abs(eigs(A,1,'largestabs','MaxIteration',1e7));
        A = A / emax;
        % Rest of parameters
        B = (rand(N,1)-.5)*BR(j);
        rs = (rand(N,1)-.5);                    % RNN Operating/Fixed Point
        d = atanh(rs)-A*rs;

        for k = 1:length(Ttrain)
            % Input
            x = infun(Ttrain(k)); x = x(2:end);
            % Evolve
            R = zeros(N,Ttrain(k)); R(:,1) = rs;
            for l = 2:Ttrain(k); R(:,l) = tanh(A*R(:,l-1) + B*x(l-1) + d); end
            R = R(:,Ts+2:end,:);
            % FFT
            S = (stft(x,Ts,'window',rectwin(Ts),'overlaplength',Ts-1,'FFTLength',Ts));
            S = S(:,1:end-2);
            Strain = [real(S); imag(S)];
            % Train
            W = lsqminnorm(R',Strain')';
    
            % Predict
            x = infun(Ttest); x = x(2:end);
            R = zeros(N,Ttest); R(:,1) = rs;
            for l = 2:Ttest; R(:,l) = tanh(A*R(:,l-1) + B*x(l-1) + d); end
            WR = W*R(:,Ts+2:end);
            Z = sqrt(WR(1:Ts,:).^2 + WR(Ts+1:end,:).^2);
            S = (stft(x,Ts,'window',rectwin(Ts),'overlaplength',Ts-1,'FFTLength',Ts));
            Stest = abs(S(:,1:end-2));
            
            % Error
            eE(i,j,k) = norm(Z-Stest)/norm(Stest);
            Wnorm(i,j,k) = norm(W);
        end
    end
end


%% randRNN error: First training time (e)
labT = {'e','f','g','h'};
for i = 1:4
    pInd = i+4;
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
fName = 'suppfig_STFT_RNN_49';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, fName, 'pdf');
set(gcf, 'Renderer', 'opengl');

