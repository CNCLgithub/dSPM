%% Prepare Space
code_IO_matrix;
params_fig;


%% Plotting parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 12.3];                       % Figure Size in cm  [w,h]
fMarg = [.25 .25 .05 .45];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00  8.50  5.00 4.00];...
        [ 5.25  8.50  7.00 4.00];...
        [12.00  8.50  6.00 4.00];...
        [ 0.00  4.25  7.00 4.00];...
        [ 6.75  4.25  7.00 4.00];...
        [13.75  4.25  4.25 4.00];...
        [ 0.00  0.00  7.00 4.00];...
        [ 6.75  0.00  7.00 4.00];...
        [13.75  0.00  4.25 4.00]];

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


%% PLOT a: Draw RNN Schematic
pInd = 1;
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xi = [0.00 0.00 0.00 0.00;...
      0.85 0.60 0.35 0.10]'*.9 + [0.15 0.0];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.9 + [0.25 0.0];
xo = [0.00 0.00 0.00 0.00;...
      0.85 0.60 0.35 0.10]'*.9 + [1.15 0];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Air = [1 4; 1 2; 2 4; 2 6; 3 5; 3 1; 4 5; 4 1];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [1 1; 3 1; 2 2; 4 2; 4 3; 6 3; 5 4; 6 4];
hold on;
plot_spline([xo(1,:)' xo(1,:)'+[.05;.06] xi(1,:)'+[-.05;.06] xi(1,:)'],...
            'linewidth',1.5,'color',[1 1 1]*.7,'head',1,'headpos',.53,'linestyle',':');
plot_spline([xo(2,:)' xo(2,:)'+[.15;.27] xi(2,:)'+[-.15;.27] xi(2,:)'],...
            'linewidth',1.5,'color',[1 1 1]*.7,'head',1,'headpos',.53,'linestyle',':');
draw_reservoir(xi,xr,0*xi(:,1),Air,[0 0 0 0 1 1 1 1],[.5;.3],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([4 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.2);
draw_reservoir(xr,xo,0*xr(:,1),Aro,[0 0 0 0 1 1 1 1],[.5;.3],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([5 2],:),'lw',1.5,'hl',10,'hw',10,'hp',.88);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',15,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',77,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([3 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.8);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*0];
axis(ax);

% Text
% Macroscopic labels
text(-.05,1.0,'\textbf{a} feedback RNN:',TextL{:});
text(0.73,1.0,'$A$',TextL{:},'color',CP(6,:));
text(0.83,1.0,'$=$',TextL{:});
text(0.93,1.0,'$\bar{A}$',TextL{:},'color',CP(3,:));
text(1.03,1.0,'$+$',TextL{:});
text(1.13,1.0,'$\bar{B}$',TextL{:},'color',CP(4,:));
text(1.23,1.0,'$\bar{W}$',TextL{:},'color',CP(5,:));
% Input labels
text(xi(1,1)-.05,xi(1,2),'$\bar{x}_1$',TextRv{:});
text(xi(2,1)-.05,xi(2,2),'$\bar{x}_n$',TextRv{:});
text(xi(1,1)+.02,mean(xi([1 2],2))+.01,'$\vdots$',TextRv{:});
text(xi(3,1)-.05,xi(3,2),'$x_1$',TextRv{:});
text(xi(4,1)-.05,xi(4,2),'$x_k$',TextRv{:});
text(xi(3,1)+.02,mean(xi([3 4],2))+.01,'$\vdots$',TextRv{:});
text(xo(1,1)+.05,xo(1,2),'$\bar{o}_1$',TextLv{:});
text(xo(2,1)+.05,xo(2,2),'$\bar{o}_n$',TextLv{:});
text(xo(1,1)+.02,mean(xo([1 2],2))+.01,'$\vdots$',TextRv{:});
text(xo(3,1)+.05,xo(3,2),'$o_1$',TextLv{:});
text(xo(4,1)+.05,xo(4,2),'$o_m$',TextLv{:});
text(xo(3,1)+.02,mean(xo([3 4],2))+.01,'$\vdots$',TextRv{:});
drawnow;


%% PLOT b: Draw Instructions
pInd = 2;
subplot('position',subpN(pInd,:)); cla;

% Pre-feedback
xvc = .26; yvc = .86;
text(0,yvc,'cont: $\frac{1}{\gamma}${\boldmath$\dot{r}$} $= -${\boldmath$r$} $+$ {\boldmath$g$}$(~~${\boldmath$r$}$+~~${\boldmath$\bar{x}$}$+~~${\boldmath$x$}$+${\boldmath$d$}$)$',TextL{:});
text(xvc+.63,yvc+.005,'$\bar{A}$','Color',CP(3,:));
text(xvc+.835,yvc+.005,'$\bar{B}$','Color',CP(4,:));
text(xvc+1.045,yvc+.005,'$B$','Color',CP(1,:));
text(0,yvc-.15,'disc: {\boldmath$r$}$_{t+1}$ $=$ {\boldmath$g$}$(~$ {\boldmath$r_t$}$+~$ {\boldmath$\bar{x}_t$}$+~~${\boldmath$x$}$_t+${\boldmath$d$}$)$',TextL{:});
text(xvc+.39,yvc-.15,'$\bar{A}$','Color',CP(3,:));
text(xvc+.63,yvc-.15,'$\bar{B}$','Color',CP(4,:));
text(xvc+.87,yvc-.15,'$B$','Color',CP(1,:));

% Feedback
xcent = sRat(pInd)/2; xvc = .24; yvc = .24;
text(0,yvc+.15,'feedback: replace {\boldmath$\bar{x}$} with {\boldmath$\bar{o}$} $=~~~${\boldmath$r$}',TextL{:});
text(1.32,yvc+.15,'$\bar{W}$','Color',CP(5,:));
text(0,yvc,'cont: $\frac{1}{\gamma}${\boldmath$\dot{r}$} $= -${\boldmath$r$} $+$ {\boldmath$g$}$(~~${\boldmath$r$}$+~~${\boldmath$x$}$+${\boldmath$d$}$)$',TextL{:});
text(xvc+.655,yvc+.005,'$A$','Color',CP(6,:));
text(xvc+0.85,yvc+.005,'$B$','Color',CP(1,:));
text(0,yvc-.15,'disc: {\boldmath$r$}$_{t+1}$ $=$ {\boldmath$g$}$(~$ {\boldmath$r_t$}$+~~${\boldmath$x$}$_t+${\boldmath$d$}$)$',TextL{:});
text(xvc+.41,yvc-.15,'$A$','Color',CP(6,:));
text(xvc+0.65,yvc-.15,'$B$','Color',CP(1,:));

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*0];
axis(ax);

% Text
% Macroscopic labels
text(-0.01,1.0,'\textbf{b} instructions pre-feedback',TextL{:});
drawnow;


%% PLOT c: Draw machine code schematic
pInd = 3;
subplot('position',subpN(pInd,:)); cla;
hold on;

% RNN schematic dimensions
ysp = .06; xsh = 0.04; ysh = .36;
N = 6; n = 2; k = 3; m = 3;
ms = 40;

% B~
[XBp,YBp] = meshgrid(1:n,1:N);
XBp = XBp*ysp+xsh; YBp = YBp*ysp + ysh;
scatter(XBp(:),YBp(:),ms,ones(numel(XBp),1).*CP(4,:),'filled','s');

% B
[XB,YB] = meshgrid(1:k,1:N);
XB = XB*ysp+xsh + .15; YB = YB*ysp + ysh;
scatter(XB(:),YB(:),ms,ones(numel(XB),1).*CP(1,:),'filled','s');

% A
[XA,YA] = meshgrid(1:N,1:N);
XA = XA*ysp+xsh + .36; YA = YA*ysp + ysh;
scatter(XA(:),YA(:),ms,ones(numel(XA),1).*CP(3,:),'filled','s');

% d
[Xd,Yd] = meshgrid(1:1,1:N);
Xd = Xd*ysp+xsh + .75; Yd = Yd*ysp + ysh;
scatter(Xd(:),Yd(:),ms,ones(numel(Xd),1).*CG(4,:),'filled','s');

% W~
[XWp,YWp] = meshgrid(1:N,1:n);
XWp = XWp*ysp + 1.1; YWp = YWp*ysp + ysh + .3;
scatter(XWp(:),YWp(:),ms,ones(numel(XWp),1).*CP(5,:),'filled','s');

% W
[XW,YW] = meshgrid(1:N,1:m);
XW = XW*ysp + 1.1; YW = YW*ysp + ysh;
scatter(XW(:),YW(:),ms,ones(numel(XW),1).*CP(2,:),'filled','s');

% Brackets
line_coordinates([[XBp(1,1) XBp(1,1)]; [YB(1,1) YB(end,1)]],'nw',.02,'style','-','lw',.7,'lSh',.07,'color',CG(5,:));
line_coordinates([[XBp(end,1) XBp(end,end)]; [YB(1,1) YB(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XB(end,1) XB(end,end)]; [YB(1,1) YB(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XA(end,1) XA(end,end)]; [YA(1,1) YA(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XW(1,1) XW(1,1)]; [YW(1,1) YW(end,1)]],'nw',.02,'style','-','lw',.7,'lSh',.07,'color',CG(5,:));
line_coordinates([[XWp(1,1) XWp(1,1)]; [YWp(1,1) YWp(end,1)]],'nw',.02,'style','-','lw',.7,'lSh',.07,'color',CG(5,:));
line_coordinates([[XW(end,1) XW(end,end)]; [YW(1,1) YW(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.05,'color',CG(5,:));
line_coordinates([[XBp(1,1) Xd(1,1)]; [YB(1,1) Yd(1,1)]],'nw',.02,'style','-','lw',.7,'lSh',-.22);
line_coordinates([[XW(end,1) XW(end,end)]; [YW(1,1) YW(1,1)]-.01],'nw',.02,'style','-','lw',.7,'lSh',-.22);

% Dimensions
text(mean(XBp(1,:)),YB(1,1)-.14,'$n$',TextC{:},'Color',CG(5,:));
text(mean(XB(1,:)),YB(1,1)-.14,'$k$',TextC{:},'Color',CG(5,:));
text(mean(XA(1,:)),YA(1,1)-.14,'$N$',TextC{:},'Color',CG(5,:));
text(mean(Xd(1,:)),Yd(1,1)-.14,'$1$',TextC{:},'Color',CG(5,:));
text(mean(XW(1,:)),YW(1,1)-.14,'$N$',TextC{:},'Color',CG(5,:));
text(XBp(1,1)-.13,mean(YBp(:,1)),'$N$',TextC{:},'Color',CG(5,:));
text(XWp(1,1)-.14,mean(YWp(:,1)),'$n$',TextC{:},'Color',CG(5,:));
text(XW(1,1)-.14,mean(YW(:,1)),'$m$',TextC{:},'Color',CG(5,:));

% Labels
text(mean(XBp(1,:)),YB(end,1)+.07,'$\bar{B}$','Color',CP(4,:),TextC{:});
text(mean(XB(1,:)),YB(end,1)+.07,'$B$','Color',CP(1,:),TextC{:});
text(mean(XA(1,:)),YA(end,1)+.075,'$\bar{A}$','Color',CP(3,:),TextC{:});
text(mean(Xd(1,:)),Yd(end,1)+.07,'{\boldmath$d$}','Color',CG(4,:),TextC{:});
text(XW(1,end)+.10,mean(YW(:,1,1)),'$W$','Color',CP(2,:),TextC{:});
text(XWp(1,end)+.11,mean(YWp(:,1,1)),'$\bar{W}$','Color',CP(5,:),TextC{:});
text((XBp(1,1)+Xd(1,1))/2,YB(1,1)-.3,'random',TextC{:});
text(mean(XW(1,:)),YW(1,1)-.3,'programmed',TextC{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);

% Text
text(-.07,1.0,'\textbf{c} machine code: $\bar{B}, B, \bar{A}, $ {\boldmath$d$}$, \bar{W}, W$',TextL{:});
drawnow;


%% PLOT d: Draw schematic of decompiled sNPL
pInd = 4;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.03;
Np = 25;
xInd = {1,2:10,(52:66)+20,(size(Pd1,1)-49:size(Pd1,1)-40),(size(Pd1,1)-24:size(Pd1,1)-15)};
xpInd = [xInd{1} xInd{2}+1.5 xInd{3}-58.5 xInd{4}-size(Pd1,1)+79 xInd{5}-size(Pd1,1)+65.5];
[XG,YG] = meshgrid(xpInd*yVES,[0:Np-4 Np]*yVES);
XG = XG + 0.15;
YG = .9 - YG;
RcMat = [RsNPL1([1:Np-3 Np],[xInd{:}])];
RcMat = tanh(10*RcMat ./ vecnorm(RcMat).^(.9));
RcCol = interp1([-1 0 1], Cw1, RcMat(:));
scatter(XG(:),YG(:),13,RcCol,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,1.01,'\textbf{d} decompile as pre-feedback (matrix $R_c$)',TextL{:});
% Inputs
text(XG(1,1),YG(end,1)-.1,'$1$',TextC{:});
text(XG(1,6),YG(end,1)-.1,'{\boldmath$\bar{x}$}, {\boldmath$x$}',TextC{:});
text(XG(1,18),YG(end,1)-.1,'{\boldmath$\bar{x}$}$\otimes${\boldmath$x$}',TextC{:});
text(XG(1,31),YG(end,1)-.1,'{\boldmath$\bar{x}$}$\otimes${\boldmath$\bar{x}$}',TextC{:});
text(XG(1,41),YG(end,1)-.1,'{\boldmath$x$}$\otimes${\boldmath$x$}',TextC{:});
% Neurons
xesh = .04;
text(XG(1,1)+xesh-.27,YG(9,1),'{\boldmath$r$} $\approx$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% PLOT e: Draw source code schematic for Lyapunov equation
pInd = 5;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.03;
Np = 12;
xInd = {1,2:10,(1:15)+108,(size(Pd1,1)-49:size(Pd1,1)-40),(size(Pd1,1)-24:size(Pd1,1)-15)};
xpInd = [xInd{1} xInd{2}+1.5 xInd{3}-95 xInd{4}-size(Pd1,1)+79 xInd{5}-size(Pd1,1)+65.5];
[XG,YG] = meshgrid(xpInd*yVES,(0:Np-4)*yVES);
XG = XG + 0.15;
YG = .39 - YG;
OcMat = [OsNPLp1(1:Np-3,[xInd{:}])];
OcCol = interp1([-2 0 2], Cw1, OcMat(:));
scatter(XG(:),YG(:),13,OcCol,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;

% Text
text(-.05,1.01,'\textbf{e} program output function (matrix $O_c$)',TextL{:});
text(-.05,.88,'solves algebraic equation: $f(${\boldmath$\bar{x}$},{\boldmath$x$}$) =$ {\boldmath$\bar{x}$}')
text(-.05,.73,'equation: $I + \bar{X} + X\bar{X} + \bar{X}X^{\top} = \bar{X}$',TextL{:});
% Inputs
text(XG(1,1),YG(end,1)-.1,'$1$',TextC{:});
text(XG(1,6),YG(end,1)-.1,'{\boldmath$\bar{x}$}, {\boldmath$x$}',TextC{:});
text(XG(1,18),YG(end,1)-.1,'{\boldmath$\bar{x}$}$\otimes${\boldmath$x$}',TextC{:});
text(XG(1,31),YG(end,1)-.1,'{\boldmath$\bar{x}$}$\otimes${\boldmath$\bar{x}$}',TextC{:});
text(XG(1,41),YG(end,1)-.1,'{\boldmath$x$}$\otimes${\boldmath$x$}',TextC{:});
% Neurons
xesh = .04;
text(XG(1,1)+xesh-.27,YG(6,1),'{\boldmath$\bar{o}$} $=$',TextL{:});

% Draw Arrows
plot_spline([.42,.185; .68,.42],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([.62,.385; .68,.42],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([.9,.73; .68,.42],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)
plot_spline([1.23,.85; .68,.42],'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3)

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% PLOT f: Draw original signal and RNN output
% Gramian calculation
pInd = 6;
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xi = [0.00;...
      0.50]'*.3 + [0.25 0.43];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.3 + [0.35 0.43];
xo = [0.00;...
      0.50]'*.3 + [0.71 .43];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Air = [1 6; 1 1];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [6 1; 1 1];
hold on;
draw_reservoir(xi,xr,0*xi(:,1),Air,[1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([4 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.35);
draw_reservoir(xr,xo,0*xr(:,1),Aro,[1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([5 2],:),'lw',1.0,'hl',7,'hw',7,'hp',.91);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',10,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',30,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.7);

% Text
text(-.1,1.01,'\textbf{f} compile: min$\|\bar{W}R_c-O_c\|$',TextL{:});
text(-.1,.9,'new feedback connectivity: $~=$',TextL{:});
text(.32,.78,'$A$',TextC{:},'color',CP(6,:));
text(.42,.78,'$=$',TextC{:});
text(.52,.78,'$\bar{A}$',TextC{:},'color',CP(3,:));
text(.62,.78,'$+$',TextC{:});
text(.70,.78,'$\bar{B}$',TextC{:},'color',CP(4,:));
text(.80,.78,'$\bar{W}$',TextC{:},'color',CP(5,:));
text(-.1,.78,'input {\boldmath$x$}',TextL{:});
text(xo(1)+.1,xo(2)+.01,'{\boldmath$o$} = {\boldmath$\bar{o}$}',TextL{:});

yVES = .045; mts = 40;
mv = max(abs([WRPM1(:);WRPM2(:);WRPM3(:);CLAM(:);AM(:)]));

% Draw input
[XGO,YGO] = meshgrid((1:K)*yVES,(1:K)*yVES); XGO = XGO -.12; YGO = 0.74 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*mv,Cw1,AM(:)),'s','filled','clipping',0,...
        'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Draw learning sequence
[XGO,YGO] = meshgrid((1:K)*yVES,(1:K)*yVES); XGO = XGO -.12; YGO = 0.30 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1]*mv,Cw1,WRPM1(:)),'s','filled','clipping',0,...
        'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
scatter(XGO(:)+.3,YGO(:),mts,interp1([-1 0 1]*mv,Cw1,WRPM2(:)),'s','filled','clipping',0,...
        'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
scatter(XGO(:)+.6,YGO(:),mts,interp1([-1 0 1]*mv,Cw1,WRPM3(:)),'s','filled','clipping',0,...
        'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Draw true output
[XGO,YGO] = meshgrid((1:K)*yVES,(1:K)*yVES); XGO = XGO +.4; YGO = 0.30 - YGO;
scatter(XGO(:)+.43,YGO(:),mts,interp1([-1 0 1]*mv,Cw1,CLAM(:)),'s','filled','clipping',0,...
        'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Time axis
plot_spline([-.09,.78; .30,.30],'head',1,'headpos',1,'ratio',sRat(pInd),...
            'linewidth',.7,'headwidth',3,'headlength',3);
text(-.1,.35,'output {\boldmath$o$} over time',TextL{:});
text(.98,.33,'true $\bar{X}$',TextC{:});

% colorbar
ctv = linspace(-1,1,200);
scatter(ctv*.07+.925,ctv*0+.45,10,...
        interp1([-1 0 1], Cw1, ctv),'filled','marker','s','clipping',0);
text(ctv(1)*.07+.9,0.45,['$-' num2str(mv,2) '$'], TextR{:});
text(ctv(end)*.07+.94,.45,['$' num2str(mv,2) '$'], TextL{:});

axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0);
drawnow;


%% PLOT g: Draw schematic of decompiled sNPL
pInd = 7;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.03;
Np = 25;
xInd = {1,2:21,51,(52:61)+20,(size(Pd2,1)-49:size(Pd2,1)-45),(size(Pd2,1)-24:size(Pd2,1)-20)};
xpInd = [xInd{1} xInd{2}+1.5 xInd{3}-25.5 xInd{4}-43.5 xInd{5}-size(Pd2,1)+89 xInd{6}-size(Pd2,1)+70.5];
[XG,YG] = meshgrid(xpInd*yVES,[0:Np-4 Np]*yVES);
XG = XG + 0.15;
YG = .9 - YG;
RdMat = [RsNPL2([1:Np-3 Np],[xInd{:}])];
RdMat = tanh(10*RdMat ./ vecnorm(RdMat).^.9);
RdCol = interp1([-1 0 1], Cw1, RdMat(:));
scatter(XG(:),YG(:),13,RdCol,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,1.01,'\textbf{g} decompile as pre-feedback (matrix $R_d$)',TextL{:});
% Inputs
text(XG(1,1),YG(end,1)-.1,'$1$',TextC{:});
text(XG(1,13),YG(end,1)-.1,'{\boldmath$\bar{x}$}$_t$',TextC{:});
text(XG(1,22),YG(end,1)-.1,'$x_t$',TextC{:});
text(XG(1,31)+yVES*2.8,YG(end,1)-.1,'({\boldmath$\bar{x}$}$_t,x_t)\otimes$({\boldmath$\bar{x}$}$_t,x_t)$',TextC{:});
% Neurons
xesh = .04;
text(XG(1,1)+xesh-.27,YG(9,1),'{\boldmath$r$}$_{t+1}$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% PLOT h: Draw source code for STFT
pInd = 8;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.03;
Np1 = 4;
Np2 = 10;
xInd = {1,2:21,51,(52:61)+20,(size(Pd2,1)-49:size(Pd2,1)-45),(size(Pd2,1)-24:size(Pd2,1)-20)};
xpInd = [xInd{1} xInd{2}+1.5 xInd{3}-25.5 xInd{4}-43.5 xInd{5}-size(Pd2,1)+89 xInd{6}-size(Pd2,1)+70.5];
[XG,YG] = meshgrid(xpInd*yVES,[(1:Np1-1)-1 Np1 (1:Np2)+Np1+7.5]*yVES);
XG = XG + 0.15;
YG = .8 - YG;
OdMat = [OsNPLp2([1:Np1-1 49],[xInd{:}]); OsNPL2((1:Np2),[xInd{:}])];
OcMat = interp1([-1 0 1], Cw1, OdMat(:));
scatter(XG(:),YG(:),13,OcMat,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;

% Text
text(-.05,1.01,'\textbf{h} program output function (matrix $O_d$)',TextL{:});
text(-.05,.88,'sample lag operator: $f(\bar{x}_{i+1,t}) = \bar{x}_{i,t+1}$')
text(-.05,.54,'Fourier coeffs: $o_{i,t}$=$\sum_{j=0}^{T-1} \cos(\frac{2\pi ij}{T})\bar{x}_{j+1,t}$')
% Inputs
text(XG(1,1),YG(end,1)-.1,'$1$',TextC{:});
text(XG(1,13),YG(end,1)-.1,'{\boldmath$\bar{x}$}$_t$',TextC{:});
text(XG(1,22),YG(end,1)-.1,'$x_t$',TextC{:});
text(XG(1,31)+yVES*2.8,YG(end,1)-.1,'({\boldmath$\bar{x}$}$_t,x_t)\otimes$({\boldmath$\bar{x}$}$_t,x_t)$',TextC{:});
% Neurons
xesh = .04; yesh = .25;
text(XG(1,1)+xesh-.27,YG(3,1),'{\boldmath$\bar{o}$}$_t=$',TextL{:});
text(XG(1,1)+xesh-.27,YG(9,1),'{\boldmath$o$}$_t=$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);


%% PLOT i: Draw true STFT and RNN output
% Gramian calculation
pInd = 9;
subplot('position',subpN(pInd,:)); cla;
hold on;

% Plot signal
t = linspace(-.09,sRat(pInd)+.07,length(x));
plot(t,x*.35+.68,'clipping',0);

% Text
text(-.1,1.01,'\textbf{i} compile: min$\|\bar{W}R_d-O_d\|$',TextL{:});
text(.37,.9,'$A$',TextC{:},'color',CP(6,:));
text(.47,.9,'$=$',TextC{:});
text(.57,.9,'$\bar{A}$',TextC{:},'color',CP(3,:));
text(.67,.9,'$+$',TextC{:});
text(.75,.9,'$\bar{B}$',TextC{:},'color',CP(4,:));
text(.85,.9,'$\bar{W}$',TextC{:},'color',CP(5,:));

text(-.1,.9,'feedback: $~~=$',TextL{:});
text(-.1,.8,'input $x_t$: noisy sawtooth',TextL{:});

% Plot STFT
yVES = .009; mts = 2;
maxv = max(abs([S(:);Z(:)]));

% Draw learning sequence
[XGO,YGO] = meshgrid((1:size(S,2))*yVES*.35,(1:size(S,1))*yVES);
XGO = XGO -.10; YGO = 0.46 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1],Cw1,S(:)/maxv),'s','filled','clipping',0);
plot_spline([XGO(end,[1,end]) + [0 .04]; YGO(end,[end,end])],'head',1,'headpos',1,'ratio',sRat(pInd),...
            'linewidth',.7,'headwidth',3,'headlength',3);
text(XGO(end,end)+.05,YGO(end,end),'$t$',TextL{:});
text(mean(XGO(:)),YGO(1,1)+.04,'true STFT',TextC{:});
[XGO,YGO] = meshgrid((1:size(S,2))*yVES*.35,(1:size(S,1))*yVES); 
XGO = XGO +.57; YGO = 0.46 - YGO;
scatter(XGO(:),YGO(:),mts,interp1([-1 0 1],Cw1,Z(:)/maxv),'s','filled','clipping',0);
plot_spline([XGO(end,[1,end]) + [0 .04]; YGO(end,[end,end])],'head',1,'headpos',1,'ratio',sRat(pInd),...
            'linewidth',.7,'headwidth',3,'headlength',3);
text(XGO(end,end)+.05,YGO(end,end),'$t$',TextL{:});
text(XGO(1,1)-.05,mean(YGO(:)),'frequency',TextC{:},'rotation',90);
text(mean(XGO(:)),YGO(1,1)+.04,'RNN STFT',TextC{:});

axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0);
drawnow;


%% Save
fName = 'fig_IO_matrix';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');

