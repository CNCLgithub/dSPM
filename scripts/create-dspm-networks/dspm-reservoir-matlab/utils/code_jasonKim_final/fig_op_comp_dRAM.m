%% Prepare Space
code_op_comp_dRAM;
params_fig;


%% Parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 12.5];                      % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00  7.50  5.50 5.00];...     % Subplot position in cm [x,y,w,h]
        [ 5.10  7.50  2.50 5.00];...
        [ 7.70 10.50  9.30 2.00];...
        [ 7.70  7.70  9.30 3.00];...
        [ 0.00  4.75  3.50 3.00];...
        [ 4.00  4.75 14.00 3.00];...
        [ 0.00  0.00  5.50 4.50];...
        [ 5.10  0.00  2.50 4.50];...
        [ 7.70  2.50  9.30 2.00];...
        [ 7.70  0.00  9.30 2.70]];

% Adjust position for margins
subp = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat = subp(:,3) ./ subp(:,4);

% Label Position in cm
labX = -fMarg(1);
labY = 0.1;
labY2 = 0.2;
labY3 = -0.1;
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'color','w');

% Set random seed for reproducibility
rng(0);


%% Draw reservoir representation space (a)
pInd = 1;
subplot('position',subpN(pInd,:)); cla;

% Axes
hold on;
plot_spline([.01 1.00; .15 .15], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.98; .15 .20], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.95; .15 .25], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.15; .15 .39], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.01; .15 .85], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
% Labels
text(1.01,.15,'$r_1$',TextL{:});
text(0.99,.21,'$r_2$',TextL{:});
text(0.97,.27,'$r_3$',TextL{:});
text(0.04,.29,'$r_{n-1}$',TextL{:},'rotation',60);
text(-.01,.88,'$r_n$',TextL{:});

% Representation matrices
yVES = .035;
xInd = [1, 2, 2+K^2, 49, 53];
xpInd = [1 (2:5)+.5 (6:10)+1];
xplInd = [1 (0:1)+xInd(2) (0:1)+xInd(3) xInd(4):xInd(5)];
[XGO,YGO] = meshgrid(xpInd*yVES,([1 2 3 5])*yVES);
xv = [.20 .65 .05 .53];
yv = [.42 .52 .74 .84];
for i = 1:4
    XGOp = XGO + xv(i); YGOp = yv(i) - YGO;
    mv = RsNPL1s{i}([1 2 3 5],xplInd); mv = tanh(2000*mv ./ sqrt(vecnorm(mv)));
    scatter(XGOp(:),YGOp(:),34,interp1([-1 0 1],Cw1,mv(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
end
text(labX,subp(pInd,4),'\textbf{a} unique sNPL $R_{c_1,c_2}$ per $c_1,c_2$',TitleL{:});

% Plot fixed points
scatter(xv,yv,20,'k','filled');
text(xv(1),yv(1)+.04,'$R_{c_1 = 0, c_2 = 0}$',TextL{:});
text(xv(2),yv(2)+.04,'$R_{c_1 = 0, c_2 = 1}$',TextL{:});
text(xv(3),yv(3)+.04,'$R_{c_1 = 1, c_2 = 0}$',TextL{:});
text(xv(4),yv(4)+.04,'$R_{c_1 = 1, c_2 = 1}$',TextL{:});
hold off;

axis([0 sRat(pInd) 0 1] + [.04 .04 0 0]);
set(gca,'visible',0);
drawnow;


%% Draw source code (b)
scv = 2;
gs = 0.65;
yVES = .08;
xpInd = 1:5;
mts = 100;
tysh = .07;

% Plot representation
pInd = 2;
subplot('position',subpN(pInd,:)); cla;
xLabL = {'$~1$','$p_{ij}$','$q_{ij}$','$p_{ij}q_{ij}$','$p_{ik}q_{kj}$'};
text(labX,subp(pInd,4),'\textbf{b} source code',TitleL{:});
[XGO,YGO] = meshgrid(xpInd*yVES,1*yVES); XGO = XGO - 0.00; YGO = 1.13 - YGO;

% Addition
hold on;
YGO = YGO - .215;
ColO = zeros(size(XGO)); ColO([2 3]) = 1;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,ColO(:)),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1)-.13,YGO(1,1),'$o_{ij}$', TextLv{:});
text(mean(XGO(:)),YGO(1,1)+tysh,'$\bar{O}_{00}: +$', TextC{:});

% Subtraction
YGO = YGO - .17;
ColO = zeros(size(XGO)); ColO([2 3]) = [1 -1];
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,ColO(:)),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1)-.13,YGO(1,1),'$o_{ij}$', TextLv{:});
text(mean(XGO(:)),YGO(1,1)+tysh,'$\bar{O}_{01}: -$', TextC{:});

% Elementwise multiplication
YGO = YGO - .17;
ColO = zeros(size(XGO)); ColO(4) = 2;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,ColO(:)),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1)-.13,YGO(1,1),'$o_{ij}$', TextLv{:});
text(mean(XGO(:)),YGO(1,1)+tysh,'$\bar{O}_{10}: 2\circ$', TextC{:});

% Matrix multiplication
YGO = YGO - .17;
ColO = zeros(size(XGO)); ColO(5) = 1;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,ColO(:)),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1)-.13,YGO(1,1),'$o_{ij}$', TextLv{:});
text(mean(XGO(:)),YGO(1,1)+tysh,'$\bar{O}_{1 1}: \times$', TextC{:});
for i = 1:length(xLabL)
    text(XGO(1,i)-.02,YGO(end,1)-.05,xLabL{i},TextL{:},'rotation',-45);
end

% Axes
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0,'xtick',[],'ytick',[]);
drawnow;


%% Draw combining and compiling (c)
pInd = 3;
subplot('position',subpN(pInd,:)); cla;
% Representation matrices
yVES = .065;
xpInd = [1:10];
[XGR,YGR] = meshgrid(xpInd*yVES,([1 2 3 5 6])*yVES+.1);
[XGO,YGO] = meshgrid(xpInd*yVES,([2 3 4 5 6])*yVES+.1);
xv = [0:3]*.75;
yv = [0 0 0 0]+.7;
hold on;
aN = {'$\bar{O}_{00}$','$\bar{O}_{01}$','$\bar{O}_{10}$','$\bar{O}_{11}$'};
bN = {'$R_{00}$','$R_{01}$','$R_{10}$','$R_{11}$'};
for i = 1:4
    % Representation
    XGRp = XGR + xv(i); YGRp = yv(i) - YGR;
    mv = RsNPL1s{i}([1 2 3 end-1 end],xplInd); mv = tanh(2000*mv ./ sqrt(vecnorm(mv)));
    scatter(XGRp(:),YGRp(:),13,interp1([-1 0 1],Cw1,mv(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    % Output
    XGOp = XGO + xv(i) + 3.6; YGOp = yv(i) - YGO;
    ov = OsNPL1s{i}(1:5,xplInd); ov = tanh(ov ./ sqrt(vecnorm(ov+1e-10)));
    scatter(XGOp(:),YGOp(:),13,interp1([-1 0 1],Cw1,ov(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    % Text
    text(mean(XGRp(:)),YGRp(1,1)+.16,bN{i},TextC{:});
    text(mean(XGOp(:)),YGOp(1,1)+.16,aN{i},TextC{:});
end

plot_spline([3.05 3.50; .1 .15]);
plot_spline([3.05 3.50; .6 .55]);
text(3.3,.3,'$\bar{W}$',TextC{:});

% Text
text(min(xv(:))-.07,mean(YGO(:)),'[',TextL{:},'fontsize',21);
text(max(xv(:)+max(XGR(:)))+.02,mean(YGO(:)),']',TextL{:},'fontsize',21);
text(min(xv(:))-.07 + 3.6,mean(YGO(:)),'[',TextL{:},'fontsize',15);
text(max(xv(:)+max(XGR(:)))+.02+ 3.6,mean(YGO(:)),']',TextL{:},'fontsize',15);
text(labX+.13,subp(pInd,4),['\textbf{c} join $R = [R_{00},R_{01},R_{10},R_{11}]$',...
                            ', $\bar{O} = [\bar{O}_{00},\bar{O}_{01},\bar{O}_{10},\bar{O}_{11}]$, compile $\bar{W}$'],TitleL{:});
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0,'xtick',[],'ytick',[]);
drawnow;


%% Draw output (d)
pInd = 4;
subplot('position',subpN(pInd,:)); cla;
hold on;


% Matrix parameters
yVES = .08;
[XG,YG] = meshgrid((1:4)*yVES,(1:4)*yVES); YG = 0.96 - YG;
WRA = {WR1,WR2,WR3,WR4};
ABM = {ABM1,ABM2,ABM3,ABM4};
mts = 40;
CG = gray(10);
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];

% Draw RNN
xi = [0.0 0.0 0.0 0.0;...
      1.00 0.70 0.3 0.05]'*.4 + [0.35 0.4];
xr = [0.4 0.8 0.0 0.4 0.7 0.3;...
      0.9 0.7 0.6 0.5 0.2 0.1]'*.4 + [0.50 0.4];
xo = [0.25;...
      0.5]'*.4 + [0.90 0.4];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Air = [1 1; 1 6; 2 1; 2 6; 3 1; 3 6; 4 1; 4 6];
Aro = [1 1; 4 1; 6 1];
draw_reservoir(xi,xr,[-1;-1;0;0],Air,0*Air(:,1),[.5;.2],sRat(pInd),'h',0,'gs',gs,...
               'nc',[CG(8,:); CA],'ncb',[-1 0 .5 1],'lc',CP([1 1 1],:),'lcb',[-1 0 1]','lw',1);
draw_reservoir(xr,xo,0*xr(:,1),Aro,0*Aro(:,1),[.5;.3],sRat(pInd),'h',0,'gs',gs,...
               'lc',CP(1:3,:),'lcb',[-1 0 1],'lw',1);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',gs,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]');
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',35,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([3 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.7);
% Colorbar
ctv = linspace(-1,1,200);
scatter(ctv*.3+mean(xr(:,1)),0*ctv+.2,10,...
        interp1([-1 0 1], Cw1, ctv),'filled','marker','s','clipping',0);
text(-.3+mean(xr(:,1))-.05,.2,'$-2$',TextR{:});
text(.3+mean(xr(:,1))+.05,.2,'$2$',TextL{:});

sh = [0 1.35 0 1.35; .6 .6 .11 .11] + [1.78;-.6];
mOP = {'$P+Q$','$P-Q$','$2P\circ Q$','$P\times Q$'};
cOP1 = {'$c_1$:$0$','$c_1$:$0$','$c_1$:$1$','$c_1$:$1$'};
cOP2 = {'$c_2$:$0$','$c_2$:$1$','$c_2$:$0$','$c_2$:$1$'};
for i = 1:4
    % True
    XGO = XG+sh(1,i); YGO = YG+sh(2,i);
    scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,ABM{i}(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    text(mean(XGO(:)),mean(YGO(:))+.22,mOP{i},TextC{:});
    text(min(XGO(:))-.07,mean(YGO(:))+.1,cOP1{i},TextR{:});
    text(min(XGO(:))-.07,mean(YGO(:))-.1,cOP2{i},TextR{:});
    % Output
    XGO = XG+sh(1,i)+.5;
    scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*scv,Cw1,WRA{i}(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    text(mean(XGO(:)),mean(YGO(:))+.22,'$O$',TextC{:});
end
set(gca,'visible',0);
axis([0 sRat(pInd) 0 1]);

% Text
text(labX+.13,subp(pInd,4)-.0,'\textbf{d} select op with $c_1$ and $c_2$',TitleL{:});
text(xo(1,1)+.05,xo(1,2),'$O$',TextL{:});
text(xi(1,1)-.05,xi(1,2),'$P$',TextR{:});
text(xi(2,1)-.05,xi(2,2),'$Q$',TextR{:});
text(xi(3,1)-.05,xi(3,2),'$c_2$',TextR{:});
text(xi(4,1)-.05,xi(4,2),'$c_1$',TextR{:});
drawnow;


%% e: Linear regression
pInd = 5;
subplot('position',subpN(pInd,:)); cla;
% Plot RNN
xi = [0.0 0.0 0.0;...
      0.9 0.5 0.1]'/2.2 + [0.12 0.3];
xr = [0.4 0.8 0.0 0.4 0.7 0.3;...
      0.9 0.7 0.6 0.5 0.2 0.1]'/2.2 + [0.32 0.3];
xo = [0.0;...
      0.5]'/2.2 + [1.02 0.3];
Air = [1 4; 2 4; 3 4];
Aro = [4 1];
Aoi = [1 3];
rco = [1 .98 .95];
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'hp',.23,'gs',gs,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]','lc',CP([1 1 1],:),'lcb',[-1 0 1]','lw',1);
draw_reservoir(xr,xo,0*xr(:,1),Aro,0*Aro(:,1),[.1;.3],sRat(pInd),'hp',.9,'gs',gs,...
               'lc',CP(1:3,:),'lcb',[-1 0 1],'lw',1);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',gs,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]');
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',38,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),[],[],[.1;.5],sRat(pInd),...
              'gs',gs,'nc',CG(7:9,:),'ncb',[-1 0 1]');
text(xi(1,1)-.07,xi(1,2),'$M$',TextR{:});
text(xi(2,1)-.07,xi(2,2),'\boldmath{$b$}',TextR{:});
text(xi(3,1)-.07,xi(3,2),'\boldmath{$x$}',TextR{:});
text(xo(1,1)+.07,xo(1,2),'\boldmath$o$',TextL{:});
axis([0 sRat(pInd) 0 1]*1.1);
set(gca,'visible',0);

text(labX,subp(pInd,4)+labY,['\textbf{e} neural processing unit (NPU) and other',...
    ' RNNs can be recursively composed to solve more complex problems'],TitleL{:});
text(mean(xr(:,1)),.07,'{\boldmath$o$} $=M${\boldmath$x$} $+$ {\boldmath$b$}',TextC{:});
text(mean(xr(:,1)),.9,'NPU',TextC{:});


% Least squares solver
pInd = 6;
subplot('position',subpN(pInd,:)); cla;
% Plot RNN
xi = [0.0 0.0 0.0;...
      0.9 0.5 0.1]'/2.2 + [0.0 0.3];
xr = [0.4 0.8 0.0 0.4 0.7 0.3;...
      0.9 0.7 0.6 0.5 0.2 0.1]'/2.2 + [0.2 0.3];
xo1 = [0.0;...
       0.5]'/2.2 + [1.2 0.3];
xo2 = [0.0;...
       0.5]'/2 + [0.9 0.3];
Air = [1 4; 2 4; 3 4];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [4 1];
% Draw NPU 1
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'hp',.23,'gs',gs,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]','lc',CP([1 1 1],:),'lcb',[-1 0 1]','lw',1);
draw_reservoir(xr,xo1,0*xr(:,1),Aro,0*Aro(:,1),[.1;.5],sRat(pInd),'hp',.85,'gs',gs,...
               'lc',ones(3,3).*[.7;.8;.9],'lcb',[-1 0 1],'lw',1);
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',38,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),[],[],[.1;.5],sRat(pInd),...
              'gs',gs,'nc',CG(7:9,:),'ncb',[-1 0 1]');
text(xi(1,1)-.07,xi(1,2),'$-M$',TextR{:});
text(xi(2,1)-.07,xi(2,2),'\boldmath{$b$}',TextR{:});
text(xi(3,1)-.07,xi(3,2),'\boldmath{$x$}',TextR{:});

% Draw NPU 2
shv = [1.2 .2];
xi = xi + shv; 
xr = xr + shv; 
xo2 = xo2 + shv;
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'hp',.23,'gs',gs,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]','lc',CP([1 1 1],:),'lcb',[-1 0 1]','lw',1);
draw_reservoir(xr,xo2,0*xr(:,1),Aro,0*Aro(:,1),[.1;.3],sRat(pInd),'hp',.9,'gs',gs,...
               'lc',CP(1:3,:),'lcb',[-1 0 1],'lw',1);
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',38,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),[],[],[.1;.5],sRat(pInd),...
              'gs',gs,'nc',CG(7:9,:),'ncb',[-1 0 1]');
draw_reservoir(xo2,xi,0*xi(1,1),[1 2],0,...
               [-.1 .4 1.4;.05 .3 .2],sRat(pInd),'gs',gs,'Ad',[0;1],'hp',.9,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]','lc',ones(3,3).*[.7;.8;.9],'lcb',[-1 0 1],'lw',1);
draw_reservoir(xo2,xi-shv,0*xi(1,1),[1 3],0,...
               [-.05 .5 1.05;.2 .38 .35],sRat(pInd),'gs',gs,'Ad',[0;-1],'hp',.8,...
               'nc',CG(7:9,:),'ncb',[-1 0 1]','lc',ones(3,3).*[.7;.8;.9],'lcb',[-1 0 1],'lw',1);
text(xi(1,1)-.0,xi(1,2),'$M^\top$',TextR{:});
text(xi(2,1)-.07,xi(2,2),'\boldmath{$x$}',TextR{:});
text(xo2(1,1)+.07,xo2(1,2),'\boldmath$o$',TextL{:});
text(xi(3,1)-.12,0.3,'$-M${\boldmath$x$} $+$ {\boldmath$b$}',TextC{:});
text(xi(3,1)-.12,.07,'{\boldmath$o$} $=$ $-M^{\top}M${\boldmath$x$} $+ M^\top${\boldmath$b$} $+$ {\boldmath$x$} $=$ {\boldmath$x$}',TextC{:});

% Draw inputs
mts = 55;
yVES = .1;
plI = 1:50:1000;
WRP2p = [WRP2(:,plI(1:end-4)) WRP2(:,end)];
mv = max(abs([WRP2p(:);AM2\z;AM2(:)]));
[XGO,YGO] = meshgrid((1:Kp)*yVES,(1:Kp)*yVES); XGO = XGO + 2.5; YGO = 0.8 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*mv,Cw1,AM2(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,end),YGO(1,1)+.28,'inputs',TextC{:});
text(XGO(1,3),YGO(1,1)+.12,'$M$',TextC{:});
[XGO,YGO] = meshgrid(1*yVES,(1:Kp)*yVES); XGO = XGO + 3.1; YGO = 0.8 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*mv,Cw1,z(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1),YGO(1,1)+.12,'{\boldmath$b$}',TextC{:});

% Draw outputs
[XGO,YGO] = meshgrid([1:length(plI)-4 length(plI)] *yVES,(1:Kp)*yVES); XGO = XGO + 3.4; YGO = 0.8 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*mv,Cw1,WRP2p(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,1)-.04,YGO(1,1)+.12,'evolution of output over time',TextL{:});
text(mean(XGO(1,[end-1:end])),mean(YGO(:)),'$\dots$',TextC{:});

scatter(XGO(:,end)+.26,YGO(:,end),mts,interp1([-1 0 1]*mv,Cw1,AM2\z),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
scatter(XGO(:,end)+.52,YGO(:,end),mts,interp1([-1 0 1]*mv,Cw1,WRPM2 - AM2\z),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XGO(1,end)-.11+.26,mean(YGO(:)),'true \boldmath$x$',TextC{:},'rotation',90);
text(XGO(1,end)-.11+.52,mean(YGO(:)),'error',TextC{:},'rotation',90);

% colorbar
ctv = linspace(-1,1,200);
scatter(ctv*.17+mean(XGO(:))+.15,0*ctv+.11,10,...
        interp1([-1 0 1], Cw1, ctv),'filled','marker','s','clipping',0);
text(mean(XGO(:))-.1,.11,['$-' num2str(mv,2) '$'], TextR{:});
text(mean(XGO(:))+.4,.11,['$' num2str(mv,2) '$'], TextL{:});

axis([0 sRat(pInd) 0 1]*1.1);
set(gca,'visible',0);
drawnow;


%% Draw reservoir representation space (f)
pInd = 7;
subplot('position',subpN(pInd,:)); cla;

% Axes
hold on;
plot_spline([.01 1.15; .03 .03], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 1.13; .03 .08], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 1.10; .03 .13], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.15; .03 .25], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
plot_spline([.01 0.01; .03 .82], 'head', 1, 'headpos', 1, 'ratio', sRat(pInd));
% Labels
text(1.16,.03,'$r_1$',TextL{:});
text(1.14,.09,'$r_2$',TextL{:});
text(1.12,.15,'$r_3$',TextL{:});
text(0.04,.15,'$r_{n-1}$',TextL{:},'rotation',60);
text(-.01,.88,'$r_n$',TextL{:});

% Representation matrices
yVES = .04;
xpInd = [1 (2:4)+.5 (5:10)+1];
[XGO,YGO] = meshgrid(xpInd*yVES,([1 2 3 5])*yVES);
xv = [.20 .72 .05 .60];
yv = [.35 .45 .74 .84];
for i = 1:4
    XGOp = XGO + xv(i); YGOp = yv(i) - YGO;
    mv = GdNPL3p{i}([1 2 3 end],1:10); mv = tanh(10*mv ./ sqrt(vecnorm(mv)));
    scatter(XGOp(:),YGOp(:),40,interp1([-1 0 1],Cw1,mv(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
end
text(labX,subp(pInd,4),'\textbf{f} unique dNPL $G_{c_1,c_2}$ per $c_1,c_2$',TitleL{:});

% Plot fixed points
scatter(xv,yv,20,'k','filled');
text(xv(1),yv(1)+.04,'$G_{c_1 = 0, c_2 = 0}$',TextL{:});
text(xv(2),yv(2)+.04,'$G_{c_1 = 0, c_2 = 1}$',TextL{:});
text(xv(3),yv(3)+.04,'$G_{c_1 = 1, c_2 = 0}$',TextL{:});
text(xv(4),yv(4)+.04,'$G_{c_1 = 1, c_2 = 1}$',TextL{:});
hold off;

axis([0 sRat(pInd) 0 1] + [.04 .04 0 0]);
set(gca,'visible',0);
drawnow;


%% Draw source code (g)
pInd = 8;
subplot('position',subpN(pInd,:)); cla;
% Representation matrices
yVES = .045;
xpInd = [1 (2:4)+.5 (5:10)+1];
[XGR,YGR] = meshgrid(xpInd*yVES,([1 2 3 5 6])*yVES);
[XGO,YGO] = meshgrid(xpInd*yVES,([4 5 6])*yVES);
yv = [1.02 .78 .52 .28];
hold on;
aN = {'$\bar{O}_{00}$ Lorenz','$\bar{O}_{01}$ Rossler',...
      '$\bar{O}_{10}$ Halvorsen','$\bar{O}_{11}$ Sprott N'};
for i = 1:4
    % Output
    XGOp = XGO - .02; YGOp = yv(i) - YGO;
    ov = oM{i}(:,1:10) + oSM{i}(:,1:10)/gam; ov = ov ./ sqrt(vecnorm(ov+1e-10));
    scatter(XGOp(:),YGOp(:),40,interp1([-1 0 1],Cw1,ov(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    % Text
    text(mean(XGOp(:)),YGOp(1,1)+.06,aN{i},TextC{:});
end
text(labX+.25,subp(pInd,4),'\textbf{g} source code',TitleL{:});
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0);
drawnow;


%% Draw combining and compiling (h)
pInd = 9;
subplot('position',subpN(pInd,:)); cla;
% Representation matrices
yVES = .065;
xpInd = [1 (2:4)+.5 (5:10)+1];
[XGR,YGR] = meshgrid(xpInd*yVES,([1 2 3 5 6])*yVES+.1);
[XGO,YGO] = meshgrid(xpInd*yVES,([4 5 6])*yVES+.1);
xv = [0:3]*.75;
yv = [0 0 0 0]+.74;
hold on;
aN = {'$\bar{O}_{00}$','$\bar{O}_{01}$','$\bar{O}_{10}$','$\bar{O}_{11}$'};
bN = {'$G_{00}$','$G_{01}$','$G_{10}$','$G_{11}$'};
for i = 1:4
    % Representation
    XGRp = XGR + xv(i); YGRp = yv(i) - YGR;
    mv = GdNPL3p{i}([1 2 3 end-1 end],1:10); mv = tanh(10*mv ./ sqrt(vecnorm(mv)));
    scatter(XGRp(:),YGRp(:),16,interp1([-1 0 1],Cw1,mv(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    % Output
    XGOp = XGO + xv(i) + 3.6; YGOp = yv(i) - YGO + yVES;
    ov = oM{i}(:,1:10) + oSM{i}(:,1:10)/gam; ov = ov ./ sqrt(vecnorm(ov+1e-10));
    scatter(XGOp(:),YGOp(:),16,interp1([-1 0 1],Cw1,ov(:)),'s','filled','clipping',0,...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
    % Text
    text(mean(XGRp(:)),YGRp(1,1)+.16,bN{i},TextC{:});
    text(mean(XGOp(:)),YGOp(1,1)+.16,aN{i},TextC{:});
end

plot_spline([3.1 3.55; .2 .2]);
plot_spline([3.1 3.55; .65 .5]);
text(3.3,.35,'$\bar{W}$',TextC{:});

% Text
text(min(xv(:))-.07,mean(YGO(:)),'[',TextL{:},'fontsize',21);
text(max(xv(:)+max(XGR(:)))+.02,mean(YGO(:)),']',TextL{:},'fontsize',21);
text(min(xv(:))-.07 + 3.6,min(YGO(:)),'[',TextL{:},'fontsize',14);
text(max(xv(:)+max(XGR(:)))+.02+ 3.6,mean(YGO(:)),']',TextL{:},'fontsize',14);
text(labX,subp(pInd,4),['\textbf{h} join $G = [G_{00},G_{01},G_{10},G_{11}]$',...
                            ', $\bar{O} = [\bar{O}_{00},\bar{O}_{01},\bar{O}_{10},\bar{O}_{11}]$, compile $\bar{W}$'],TitleL{:});
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0,'xtick',[],'ytick',[]);
drawnow;


%% Plot attractors (i)
pInd = 10;
subplot('position',subpN(pInd,:)); cla;
hold on;

% Draw RNN
xi = [0.00 0.00;...
      0.10 0.30]'*.6 + [0.10 0.10];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.6 + [0.202 0.10];
xo = [0.00 0.00 0.00;...
      0.20 0.50 0.80]'*.6 + [0.84 0.10];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Air = [1 6; 1 4; 2 5; 2 1];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [6 1; 1 1; 6 2; 1 2; 6 3; 1 3];
hold on;
draw_reservoir(xi,xr,0*xi(:,1),Air,[1 1 1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([4 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.25);
draw_reservoir(xr,xo,0*xr(:,1),Aro,[1 1 1 1 1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([5 2],:),'lw',1.0,'hl',7,'hw',7,'hp',.91);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',10,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',38,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.7);

CL = lines(1);
vw = [10 20];
sh = [0 .8 2.0 2.8; .12 0 .22 .05] + [1.6;.33];
cN = {'$(0,0)$','$(0,1)$','$(1,0)$','$(1,1)$'};
for i = 1:4
    % Reduce number of points via projection curvature thresholding
    [~,~,wrp] = downsample_curvature(WRP3{i}*.47,0.001,vw);
    % Plot
    plot(wrp(1,:)+sh(1,i),wrp(2,:)+sh(2,i),'clipping',0,'linewidth',.3,'color',CL(1,:));
    axis([0 sRat(pInd) 0 1]);
    set(gca,'visible',0);
    % Text
    text(mean(wrp(1,:))+sh(1,i)+.06,0.8,cN{i},TextC{:});
    drawnow;
end

% Text
text(labX+.13,subp(pInd,4)-.0,'\textbf{i} After feedback, RNN randomly accesses memories by $c_1$ and $c_2$',TitleL{:});
text(xo(1,1)+.05,xo(1,2),'$o_3$',TextL{:});
text(xo(2,1)+.05,xo(2,2),'$o_2$',TextL{:});
text(xo(3,1)+.05,xo(3,2),'$o_1$',TextL{:});
text(xi(1,1)-.05,xi(1,2),'$c_2$',TextR{:});
text(xi(2,1)-.05,xi(2,2),'$c_1$',TextR{:});
text(mean(xr(:,1)),max(xr(:,2))+.2,'$A = \bar{A} + \bar{B}\bar{W}$',TextC{:});
set(gca,'visible',0);


%% Save
fName = 'fig_op_comp_dRAM';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');

