%% Prepare Space
code_decomposition;
params_fig;


%% Plotting parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 10.5];                       % Figure Size in cm  [w,h]
fMarg = [.25 .25 .10 .40];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00  7.20  6.00 4.00];...
        [ 6.00  7.20  6.00 4.00];...
        [12.00  7.20  6.00 4.00];...
        [ 0.00  3.70  7.00 4.00];...
        [ 7.00  3.70  7.00 4.00];...
        [14.00  3.70  4.00 4.00];...
        [ 0.00  0.00  7.00 4.00];...
        [ 7.00  0.00  7.00 4.00];...
        [14.00  0.00  4.00 4.00]];

% Adjust position for margins
subp = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat = subp(:,3) ./ subp(:,4);

% Label Position in cm
labY = fMarg(4)-.2;
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'color','w');

% Set random seed for reproducibility
rng(0);


%% PLOT a: Draw RNN Schematic
pInd = 1;
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xi = [0.0 0.0 0.0;...
      0.75 0.55 0.2]'*.72 + [0.2 0.25];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.72 + [0.45 0.25];
xo = [0.0 0.0 0.0;...
      0.75 0.55 0.2]'*.72 + [1.35 0.25];
CP = lines(4);
CG = gray(10);
Air = [1 4; 1 2; 2 4; 2 6; 3 5; 3 1];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [1 1; 3 1; 2 2; 4 2; 4 3; 6 3];
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([1 2],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.3);
draw_reservoir(xr,xo,0*xr(:,1),Aro,0*Aro(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([2 3],:),'lw',1.5,'hl',10,'hw',10,'hp',.85);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',15,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',65,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([3 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.8);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*.15];
axis(ax);

% Text
text(-.05,1.01,'\textbf{a} machine: recurrent neural network',TextL{:});
text(xi(1,1)-.05,xi(1,2),'$x_1$',TextRv{:});
text(xi(2,1)-.05,xi(2,2),'$x_2$',TextRv{:});
text(xi(3,1)-.05,xi(3,2),'$x_k$',TextRv{:});
text(xo(1,1)+.05,xo(1,2),'$o_1$',TextLv{:});
text(xo(2,1)+.05,xo(2,2),'$o_2$',TextLv{:});
text(xo(3,1)+.05,xo(3,2),'$o_m$',TextLv{:});
drawnow;


%% PLOT b: Draw Instructions
pInd = 2;
subplot('position',subpN(pInd,:)); cla;

% Continuous
xcent = 0.02; xvc = .02; yvc = .65;
text(xcent,yvc+.13,'continuous time: ',TextL{:});
text(xvc,yvc,'$\frac{1}{\gamma}${\boldmath$\dot{r}$} $= -${\boldmath$r$} $+$ {\boldmath$g$}$(~$ {\boldmath$r$} $+ ~~~${\boldmath$x$} $+${\boldmath$d$}$)$');
text(xvc+.63,yvc+.005,'$A$','Color',CP(3,:));
text(xvc+.90,yvc+.005,'$B$','Color',CP(1,:));
text(xvc+.78,yvc+.13,'{\boldmath$o$} $= ~~~${\boldmath$r$}')
text(xvc+.98,yvc+.125,'$W$','Color',CP(2,:));

% Discrete
xcent = 0.02; xvc = .02; yvc = .3;
text(xcent,yvc+.13,'discrete time: ',TextL{:});
text(xvc,yvc,'{\boldmath$r$}$_{t+1}$ $=$ {\boldmath$g$}$(~$ {\boldmath$r$}$_t$ $+ ~~~${\boldmath$x$}$_t$ $+${\boldmath$d$}$)$');
text(xvc+.41,yvc,'$A$','Color',CP(3,:));
text(xvc+.71,yvc,'$B$','Color',CP(1,:));
text(xvc+.63,yvc+.13,'{\boldmath$o$}$_{t+1} = ~~~${\boldmath$r$}$_{t+1}$')
text(xvc+.94,yvc+.125,'$W$','Color',CP(2,:));

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*.15];
axis(ax);

% Text
text(0,1.01,'\textbf{b} instructions: $\times$, $+$, $g$, time step',TextL{:});
drawnow;


%% PLOT c: Draw machine code schematic
pInd = 3;
subplot('position',subpN(pInd,:)); cla;
hold on;

% Plot parameters
ysp = .06; xsh = .05; ysh = .47;            % Positioning
N = 6; k = 3; m = 4;                        % Matrix dimensions
ms = 40;                                    % Marker size

% B
[XB,YB] = meshgrid(1:k,1:N);
XB = XB*ysp+xsh; YB = YB*ysp + ysh;
scatter(XB(:),YB(:),ms,ones(numel(XB),1).*CP(1,:),'filled','s');

% A
[XA,YA] = meshgrid(1:N,1:N);
XA = XA*ysp+xsh + .25; YA = YA*ysp + ysh;
scatter(XA(:),YA(:),ms,ones(numel(XA),1).*CP(3,:),'filled','s');

% d
[Xd,Yd] = meshgrid(1:1,1:N);
Xd = Xd*ysp+xsh + .7; Yd = Yd*ysp + ysh;
scatter(Xd(:),Yd(:),ms,ones(numel(Xd),1).*CG(4,:),'filled','s');

% W
[XW,YW] = meshgrid(1:N,1:m);
XW = XW*ysp + 1.12; YW = YW*ysp + ysh;
scatter(XW(:),YW(:),ms,ones(numel(XW),1).*CP(2,:),'filled','s');

% Brackets
line_coordinates([[XB(1,1) XB(1,1)]; [YB(1,1) YB(end,1)]],'nw',.02,'style','-','lw',.7,'lSh',.07,'color',CG(5,:));
line_coordinates([[XB(end,1) XB(end,end)]; [YB(1,1) YB(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XA(end,1) XA(end,end)]; [YA(1,1) YA(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XW(1,1) XW(1,1)]; [YW(1,1) YW(end,1)]],'nw',.02,'style','-','lw',.7,'lSh',.07,'color',CG(5,:));
line_coordinates([[XW(end,1) XW(end,end)]; [YW(1,1) YW(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XB(1,1) Xd(1,1)]; [YB(1,1) Yd(1,1)]],'nw',.02,'style','-','lw',.7,'lSh',-.19);
line_coordinates([[XW(end,1) XW(end,end)]; [YW(1,1) YW(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.18);

% Dimensions
text(mean(XB(1,:)),YB(1,1)-.125,'$k$',TextC{:},'Color',CG(5,:));
text(mean(XA(1,:)),YA(1,1)-.125,'$N$',TextC{:},'Color',CG(5,:));
text(mean(Xd(1,:)),Yd(1,1)-.125,'$1$',TextC{:},'Color',CG(5,:));
text(mean(XW(1,:)),YW(1,1)-.125,'$N$',TextC{:},'Color',CG(5,:));
text(XB(1,1)-.13,mean(YB(:,1)),'$N$',TextC{:},'Color',CG(5,:));
text(XW(1,1)-.13,mean(YW(:,1)),'$m$',TextC{:},'Color',CG(5,:));

% Labels
text(mean(XB(1,:)),YB(end,1)+.075,'$B$','Color',CP(1,:),TextC{:});
text(mean(XA(1,:)),YA(end,1)+.075,'$A$','Color',CP(3,:),TextC{:});
text(mean(Xd(1,:)),Yd(end,1)+.075,'{\boldmath$d$}','Color',CG(4,:),TextC{:});
text(mean(XW(1,:)),YW(end,1)+.075,'$W$','Color',CP(2,:),TextC{:});
text((XB(1,1)+Xd(1,1))/2,YB(1,1)-.25,'random',TextC{:});
text(mean(XW(1,:)),YW(1,1)-.25,'programmed',TextC{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]  + [0 0 1 1]*.15;
axis(ax);

% Text
% Macroscopic labels
text(-.07,1.01,'\textbf{c} machine code: weighted $B, A, $ {\boldmath$d$}$, W$',TextL{:});
drawnow;


%% PLOT d: Draw schematic of decompiled sNPL
pInd = 4;
subplot('position',subpN(pInd,:)); cla;

% RNN Parameters
N = 5;                                              % # Neurons
As = (rand(N)-.5); As = As / max(real(eig(As)));    % recurrent
B = (rand(N,3)-.5)*.5;                              % Input
rs = (rand(N,1)-.5);                                % fixed point
xs = zeros(3,1);                                    % equilibrium point
d = atanh(rs)-As*rs;                                % bias

% Decompile
[~,C1,C2] = decomp_poly4_ns(As,B,rs,As*rs+B*xs+d,50,4);

% Plot parameters
yVES = .13;                     % Spacing
xpInd = [1 (2:4)+.5 (5:10)+1.0 (11:11)+1.5];
[XG,YG] = meshgrid(xpInd*yVES,[0:1 2.5]*yVES);
XG = XG + 0.1; YG = .58 - YG;

% Decompiled matrix to plot
RcMat = [C1([1:N-3 N],1:10) squeeze(C2([1:N-3 N],1,1))]; 
RcMat = tanh(10*RcMat ./ vecnorm(RcMat).^.5);      % Scale to visualize
RcCol = interp1([-1 0 1], Cw1, RcMat(:));
scatter(XG(:),YG(:),200,RcCol,'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,0.88,'\textbf{d} programming matrix: $R_c$ (cont. time)',TextL{:});
% Inputs
tRot = -45;
xLabL = {'$~1$','$x_1$','$x_2$','$x_3$','$x_1x_2$','$x_1x_3$','$x_2x_3$','$x_1^2$','$x_2^2$','$x_3^2$',...
         '$\dot{x}_1$'};
for i = 1:length(xLabL)
    text(XG(1,i)-.02,YG(end,1)-.08,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = .04; yesh = .17;
for i = 1:2; text(XG(i,1)+xesh-.33,YG(i,1),['$r_' num2str(i) '\approx$'],TextL{:}); end
text(XG(1,1)+xesh-.33,YG(3,1),'$r_N\approx$',TextL{:});
% Derivatives
text(XG(1,1)+xesh-0.33,YG(1,1)+yesh,['$r_1\approx~~~+\hspace{3.6mm}x_1$+$',...
     '\dots$+$\hspace{8.5mm}x_1x_2$+$\cdots$'],TextL{:});
text(XG(1,1)+xesh-0.04,YG(1,1)+yesh,'$h_1^*$',TextC{:},'color',RcCol(1,:))
text(XG(1,1)+xesh+0.16,YG(1,1)+yesh,'$\frac{\partial h_1^*}{\partial x_1}$',TextC{:},'color',RcCol(4,:))
text(XG(1,1)+xesh+0.71,YG(1,1)+yesh,'$\frac{\partial^2 h_1^*}{\partial x_1 \partial x_2}$',TextC{:},'color',RcCol(13,:))
hold on;

% Draw Arrows
plot_spline([XG(1,1)+xesh-0.04,YG(1,1)+yesh-.09; XG(1,1),YG(1,1)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([XG(1,1)+xesh+0.16,YG(1,1)+yesh-.09; XG(1,2),YG(1,2)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([XG(1,1)+xesh+0.71,YG(1,1)+yesh-.09; XG(1,5),YG(1,5)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% PLOT e: Draw source code schematic for rotation
pInd = 5;
subplot('position',subpN(pInd,:)); cla;

% Spacing
yVES = .13;
xpInd = [1 (2:4)+.5 (5:10)+1.0 (11:11)+1.5];
[XG,YG] = meshgrid(xpInd*yVES,((0:2)+.5)*yVES);
XG = XG + 0.12;
YG = .58 - YG;

% Source code matrix
OcMat = zeros(3,11); OcMat(1,3) = -1; OcMat(2,2) = 1; OcMat(3,4) = 1;
OcMat = OcMat(:);
OcCol = interp1([-1 0 1], Cw1, OcMat);
scatter(XG(:),YG(:),200,repmat([1 1 1]*.85,[numel(XG),1]),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;
scatter(XG(OcMat~=0),YG(OcMat~=0),200,OcCol(OcMat~=0,:),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,0.88,'\textbf{e} source code matrix: $O_c$ (rotation by $90^\circ$)',TextL{:});
% Inputs
tRot = -45;
xLabL = {'$~1$','$x_1$','$x_2$','$x_3$','$x_1x_2$','$x_1x_3$','$x_2x_3$','$x_1^2$','$x_2^2$','$x_3^2$',...
         '$\dot{x}_1$'};
for i = 1:length(xLabL)
    text(XG(1,i)-.02,YG(end,1)-.08,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = .04; yesh = .33;
for i = 1:3; text(XG(i,1)+xesh-.33,YG(i,1),['$o_' num2str(i) '=$'],TextL{:}); end
% Equations
text(sRat(pInd)/2,YG(1,1)+yesh-.1,'$o_1=-x_2, ~~~~~~o_2=x_1, ~~~~~~o_3=x_3$',TextC{:});
% text(sRat(pInd)/2,YG(1,1)+yesh-.26,'\textbf{source code}: construct $O_c$',TextC{:});
hold off;

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% PLOT f: Draw original signal and RNN output
pInd = 6;
subplot('position',subpN(pInd,:)); cla;

% Downsample time-series based on curvature to save figure memory
vw = [-10 20];
Xp = downsample_curvature(X1+[.15;0;0],0.01,vw)*.75;
WRp = downsample_curvature(WR1+[.15;0;0],0.01,vw)*.75;
ax = [-1.1 1.1 -1 1 -0.75 1.25]*0.83;

% Draw original input time series
hold on;
plot3(Xp(1,:),Xp(2,:),Xp(3,:),'clipping',0,'linewidth',.3,'color',CP(1,:));
plot3(WRp(1,:),WRp(2,:),WRp(3,:),'clipping',0,'linewidth',.3,'color',CP(2,:));
shv = [-.75 0 -.65]*1.2; scv = 0.2;
plot3([0 1]*scv+shv(1),[0 0]*scv+shv(2),[0 0]*scv+shv(3),...
      'k-','linewidth',.7,'clipping',0);
plot3([0 0]*scv+shv(1),[0 1]*scv+shv(2),[0 0]*scv+shv(3),...
      'k-','linewidth',.7,'clipping',0);
plot3([0 0]*scv+shv(1),[0 0]*scv+shv(2),[0 1]*scv+shv(3),...
      'k-','linewidth',.7,'clipping',0);
hold off;
axis(ax); view(vw);
text(scv+shv(1)+.1,shv(2),shv(3),'$x_1$',TextC{:});
text(shv(1)-.05,scv+shv(2)+.3,shv(3),'$x_2$',TextC{:});
text(shv(1)+.1,shv(2),scv+shv(3)+.1,'$x_3$',TextC{:});
set(gca,'visible',0);
drawnow;

% Text
text(-1.14,0,1.17,'\textbf{f} compile matrix: $W_c$',TextL{:});
text(.91,0,.75,'input',TextC{:},'color',CP(1,:));
text(.91,0,.5,'{\boldmath$x$}',TextC{:},'color',CP(1,:));
text(-.80,0,.85,'output',TextC{:},'color',CP(2,:));
text(-.80,0,.6,'{\boldmath$o$}',TextC{:},'color',CP(2,:));


%% PLOT g: Draw schematic of decompiled sNPL
pInd = 7;
subplot('position',subpN(pInd,:)); cla;

% RNN Parameters
N = 5;
B = (rand(N,1)-.5)*2;
rs = (rand(N,1)-.5);
d = atanh(rs)-As*rs;
[~,C1] = decomp_poly_ns_discrete(As,B,rs,As*rs+d,4,3);

% Scaling parameters
yVES = .13;
xpInd = [1 (2:4)+.5 (5:7)+1.0 (8:10)+1.5];
[XG,YG] = meshgrid(xpInd*yVES,[0:1 2.5]*yVES);
XG = XG + 0.23;
YG = .58 - YG;

% Decompiled matrix to plot
RdMat = [C1([1:N-3 N],1:4,1) C1([1:N-3 N],2:4,2) C1([1:N-3 N],2:4,3)];
RdMat = tanh(10*RdMat ./ vecnorm(RdMat).^.5);
RdCol = interp1([-1 0 1], Cw1, RdMat(:));
scatter(XG(:),YG(:),200,RdCol,'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,0.90,'\textbf{g} programming matrix: $R_d$ (disc. time)',TextL{:});
% Inputs
tRot = -45;
xLabL = {'$~1$','$x_{1,t}$','$x_{1,t}^2$','$x_{1,t}^3$',...
                '$x_{1,t-1}$','$x_{1,t-1}^2$','$x_{1,t-1}^3$',...
                '$x_{1,t-2}$','$x_{1,t-2}^2$','$x_{1,t-2}^3$',};
for i = 1:length(xLabL)
    text(XG(1,i)-.02,YG(end,1)-.08,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = -.09; yesh = .17;
for i = 1:2; text(XG(i,1)+xesh-.33,YG(i,1),['$r_{' num2str(i) ',t+1}\approx$'],TextL{:}); end
text(XG(1,1)+xesh-.33,YG(3,1),'$r_{N,t+1}\approx$',TextL{:});
% Derivatives
text(XG(1,1)+xesh-0.33,YG(1,1)+yesh,'$r_{1,t+1}\approx~~~+~~~~x_{1,t}+~~~~x_{1,t}^2 + \dots$',TextL{:});
text(XG(1,1)+xesh+0.09,YG(1,1)+yesh,'$h_1^*$',TextC{:},'color',RdCol(1,:));
text(XG(1,1)+xesh+0.31,YG(1,1)+yesh,'$\frac{\partial h_1^*}{\partial x_{1,t}}$',TextC{:},'color',RdCol(4,:));
text(XG(1,1)+xesh+0.70,YG(1,1)+yesh,'$\frac{\partial^2 h_1^*}{\partial x_{1,t}^2}$',TextC{:},'color',RdCol(7,:));
% text(XG(1,1)+xesh+0.945,YG(1,1)+yesh,'$\frac{\partial^3 h_1^*}{\partial x_{1,t}^3}$',TextC{:},'color',RdCol(10,:));
hold on;

% Draw Arrows
plot_spline([XG(1,1)+xesh+0.09,YG(1,1)+yesh-.08; XG(1,1),YG(1,1)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([XG(1,1)+xesh+0.31,YG(1,1)+yesh-.08; XG(1,2),YG(1,2)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([XG(1,1)+xesh+0.70,YG(1,1)+yesh-.08; XG(1,3),YG(1,3)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
% plot_spline([XG(1,1)+xesh+0.945,YG(1,1)+yesh-.08; XG(1,4),YG(1,4)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% PLOT h: Draw source code for high-pass filter
pInd = 8;
subplot('position',subpN(pInd,:)); cla;

yVES = .13;
xpInd = [1 (2:4)+.5 (5:7)+1.0 (8:10)+1.5];
[XG,YG] = meshgrid(xpInd*yVES,((0:2)+.5)*yVES);
XG = XG + 0.25;
YG = .58 - YG;
OdMat = OsNPL2(:);
OdCol = interp1([-1 0 1]*max(abs(OdMat(:))), Cw1, OdMat);
scatter(XG(:),YG(:),200,repmat([1 1 1]*.85,[numel(XG),1]),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;
scatter(XG(OdMat~=0),YG(OdMat~=0),200,OdCol(OdMat~=0,:),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,0.90,'\textbf{h} source code matrix: $O_d$ (highpass filter)',TextL{:});
% Inputs
tRot = -45;
xLabL = {'$~1$','$x_{1,t}$','$x_{1,t}^2$','$x_{1,t}^3$',...
                '$x_{1,t-1}$','$x_{1,t-1}^2$','$x_{1,t-1}^3$',...
                '$x_{1,t-2}$','$x_{1,t-2}^2$','$x_{1,t-2}^3$',};
for i = 1:length(xLabL)
    text(XG(1,i)-.02,YG(end,1)-.08,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = -.09; yesh = .35;
for i = 1:3; text(XG(i,1)+xesh-.33,YG(i,1),['$o_{' num2str(i) ',t+1}=$'],TextL{:}); end
% Derivatives
text(sRat(pInd)/2,YG(1,1)+yesh-.12,'$o_{3,t+1}= - 0.2x_{1,t} + 0.6x_{1,t-1} - 0.2x_{1,t-2}$',TextC{:});
% text(sRat(pInd)/2,YG(1,1)+yesh-.26,'\textbf{source code}: construct $O_d$',TextC{:});
hold on;

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% PLOT i: Draw sinusoidal input, and three RNN outputs
pInd = 9;
subplot('position',subpN(pInd,:)); cla;

shv = 30;
tv = linspace(.03,sRat(pInd),length(X2)-shv);
plot(tv,X2(shv+1:end)*.32+.36,'linewidth',1,'clipping',0);
hold on;
plot(tv,(WR2 ...
    (:,shv+1:end))'*.32+.36,'linewidth',1,'clipping',0);
labX = {'$x_1$','$o_1$','$o_2$','$o_3$'};
for i = 1:4
    plot([0 .1]+(i-1)*.27,[0 0]+.80,'-','linewidth',1,'color',CP(i,:));
    text(.1+(i-1)*.27+.02,.80,labX{i},TextL{:},'color',CP(i,:));
end
hold off;

% Text
text(0,0.90,'\textbf{i} compile matrix: $W_d$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% Save
fName = 'fig_decomposition';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');

