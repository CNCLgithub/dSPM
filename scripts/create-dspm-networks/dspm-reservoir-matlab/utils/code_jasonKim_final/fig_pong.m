%% Prepare Space
code_pong;
params_fig


%% Parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 14];                       % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00 9.50  3.00 4.50];...     % Subplot position in cm [x,y,w,h]
        [ 3.00 9.50 15.00 4.50];...
        [ 0.00 6.75  4.50 2.25];...
        [ 0.00 4.50  4.50 2.25];...
        [ 4.50 4.50  4.50 4.50];...
        [ 9.00 4.50  3.00 4.50];...
        [12.00 4.50  3.00 4.50];...
        [15.00 4.50  3.00 4.50];...
        [ 0.00 0.00  9.00 4.50];...
        [ 9.00 0.00  9.00 4.50]];

% Adjust position for margins
subp = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat = subp(:,3) ./ subp(:,4);

% Label Position in cm
labX = -fMarg(1);
labY = 0.05;
labY2 = 0.2;
labY3 = -0.1;
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'renderer','opengl','Position',[fig.Position(1:2) fSize],'Units','centimeters');
set(gcf,'color','w');

% Set random seed for reproducibility
rng(0);


%% Draw 
% Setup
pInd = 1; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Parameters
ms = 60;
ss = 100;
% Walls
xo = 0.02;
plot([-1 -1 1 1]*(xw+xo), [-1 1 1 -1]*(yw+xo), 'k-', 'linewidth',4,...
     'clipping',0);
% Ball
plot_spline([-.01 .03; .05 .05],'head',1,'headpos',1); 
plot_spline([-.01 -.01; .05 .09],'head',1,'headpos',1); 
scatter(-.01,.05,ms,'k','filled','linewidth',1,...
        'MarkerFaceColor',[1 1 1], 'MarkerEdgeColor', [0 0 0]);
scatter(WRP(11,1),yp,ss,'k',...
        'filled','linewidth',3,'marker','s');
% Text
text(labX,subp(pInd,4)+labY,'\textbf{a}~ pong setup',TitleL{:});
text(-.01,.03,'$x,y$',TextC{:});
text( .04,.05,'$\dot{x}$',TextC{:});
text(-.01,.102,'$\dot{y}$',TextC{:});
text(-.025,yp,'$x_p$',TextC{:});
text(xw-.01,0,'$x_r$',TextL{:});
text(-xw-.01,0,'$x_l$',TextL{:});
text(0,yw+.036,'$y_u$',TextC{:});
% Axes
ax = [[-yw yw]*sRat(pInd) -yw yw]*1.3 + [.02 .02 .025 .025];
axis(ax);
set(gca,'visible',0);


% Code
pInd = 2;
subplot('position',subpN(pInd,:)); cla;
hold on;
% List of symbols
sL = {'x','\dot{x}','\dot{x}''','y','\dot{y}','\dot{y}''','c_r','c_l','c_u','c_p','x_p'};
dsL = {'\dot{x}','\ddot{x}','\ddot{x}''','\dot{y}','\ddot{y}','\ddot{y}''','\dot{c}_r','\dot{c}_l','\dot{c}_u','\dot{c}_p'};
% Representation matrices
yVES = .1;
npI = find(sum(abs(OdNPL),1));
xpInd = 1:length(npI);
[XGO,YGO] = meshgrid(xpInd*yVES,(1:m-1)*yVES);
% First batch
XGOp = XGO + .15; YGOp = 1.1 - YGO;
mv = OdNPL(1:end-1,npI); mv = tanh(mv/2);
scatter(XGOp(:),YGOp(:),220,interp1([-1 0 1],Cw1,mv(:)),'s','filled','clipping',0,...
            'linewidth',.4','MarkerEdgeColor',[1 1 1]*.9);
hold off;

% Text
for i = 1:10
    text(XGOp(i,1)-.06,YGOp(i,1),['$' sL{i} '+' dsL{i} '/\gamma$'],TextR{:});
end
for i = 1:length(npI)
    spl = [sL{find(Pd1(npI(i),:))}];
    text(XGOp(1,i),YGOp(end,i)-.07,['$' spl '$'],TextL{:},'rotation',-45);
end

% Axes
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0);


%% Pitchfork
pInd = 3; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Draw axes
plot([-1 1]*.95, [0 0], 'k-', 'linewidth', 1,'clipping',0);
plot([0 0], [-1 1]*.35, 'k-', 'linewidth', 1,'clipping',0);
% Plot bifuraction
CP = lines(4);
tv1 = linspace(-.5,.5,101);
tv2 = linspace(-.95,.95,101);
plot(tv1,-.5*tv1-tv1.^3, 'linewidth', 1,'clipping',0,'color',CP(1,:));
plot(tv2,0.5*tv2-tv2.^3, 'linewidth', 1,'clipping',0,'color',CP(2,:));
% Plot arrows
s2 = sqrt(2)/2;
plot_spline([.2,.05;0 0],'head',1,'headpos',1,'color',CP(1,:));
plot_spline(-[.2,.05;0 0],'head',1,'headpos',1,'color',CP(1,:));
plot_spline([s2-.2,s2-.05;0 0],'head',1,'headpos',1,'color',CP(2,:));
plot_spline([s2+.2,s2+.05;0 0],'head',1,'headpos',1,'color',CP(2,:));
plot_spline([-s2-.2,-s2-.05;0 0],'head',1,'headpos',1,'color',CP(2,:));
plot_spline([-s2+.2,-s2+.05;0 0],'head',1,'headpos',1,'color',CP(2,:));
% Plot points
scatter(0,0,20,CP(1,:),'filled');
scatter(s2,0,20,CP(2,:),'filled');
scatter(-s2,0,20,CP(2,:),'filled');
% Text
text(labX,subp(pInd,4)+labY,'\textbf{b} contact yields bifurcation',TitleL{:});
text(0,.45,'$\dot{c}_r$',TextC{:});
text(.98,0,'$c_r$',TextL{:});
text(.5,.45,'$x < x_r$',TextC{:},'color',CP(1,:));
text(.5,.26,'$x > x_r$',TextC{:},'color',CP(2,:));
% Axes
axis([[-1 1]+.1 [-.5 .5]+.15]);
set(gca,'visible',0);


%% SR-latch
pInd = 4; 
subplot('position',subpN(pInd,:)); cla;
xv = [ 0.05  0.05  0.70  0.70;...
       0.65  0.35  0.65  0.35] + [.07;-.3];
TV = {'NOR', 'NOR', 'NOR', 'NOR'};
% Define coordinates for neural circuit nodes
xi = [-.08 .05;...
      -.08 -.05];
xr = [ 0.04  0.06;...
       0.04 -0.06;...
       0.09  0.00;...
       0.16  0.00];
xo = [ .25 0];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Ari = [1 1; 2 2];
Arr = [1 4; 2 4; 4 3; 3 1; 3 2];
hold on;
% Draw circuits
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,1),...
     [[0  0 .1 .2]+xo(2)+xv(2,2) [0 0]+xi(2,2)+xv(2,1)],'k-','clipping',0);
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,2),...
     [[0  0 -.1 -.2]+xo(2)+xv(2,1) [0 0]+xi(1,2)+xv(2,2)],'k-','clipping',0);
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,3),...
     [[0  0 .1 .2]+xo(2)+xv(2,2) [0 0]+xi(2,2)+xv(2,3)],'k-','clipping',0);
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,4),...
     [[0  0 -.1 -.2]+xo(2)+xv(2,1) [0 0]+xi(1,2)+xv(2,4)],'k-','clipping',0);
% Gates
for i = 1:size(xv,2)
    % Draw network
    draw_reservoir(xi+xv(:,i)',xr+xv(:,i)',1:2,Ari,0*Ari(:,1),[.9;.1],sRat(pInd),...
                   'gs',.5,'nc',[1;1].*[1 1 1]*.9,'ncb',1:2,'lcb',[0;1],'lc',CG([1 2],:));
    draw_reservoir(xr+xv(:,i)',xo+xv(:,i)',0*xr(:,1),[4 1],0,[1;1],sRat(pInd),...
                   'gs',.5,'h',0,'lcb',[0;1],'lc',CG([1 2],:));
    draw_reservoir(xo+xv(:,i)',xo+xv(:,i)',0,[],[],[],sRat(pInd),...
                   'gs',.2,'nc',[1;1].*[1 1 1]*.9,'ncb',[-1 1]);
    draw_gate(xv(:,i)',TV{i},.1,'fill','w');
    draw_reservoir(xr+xv(:,i)',xr+xv(:,i)',0*xr(:,1),Arr,0*Arr(:,1),[.5;.1],sRat(pInd),...
                   'gs',.5,'hp',.8,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:));
end
% Text
text(labX,subp(pInd,4)+labY,'\textbf{c} velocity with an SR-latch',TitleL{:});
text(xv(1,1)+xi(1,1)-.11,xv(2,1)+xi(1,2),'$c_r^2$',TextL{:});
text(xv(1,2)+xi(2,1)-.11,xv(2,2)+xi(2,2),'$c_l^2$',TextL{:});
text(xv(1,1)+xo(1,1)+.00,xv(2,1)+xo(1,2)+.06,'$\dot{x}$',TextL{:});
text(xv(1,2)+xo(1,1)+.00,xv(2,2)+xo(1,2)-.07,'$\dot{x}''$',TextL{:});
text(xv(1,3)+xi(1,1)-.11,xv(2,3)+xi(1,2),'$c_u^2$',TextL{:});
text(xv(1,4)+xi(2,1)-.11,xv(2,4)+xi(2,2),'$c_p^2$',TextL{:});
text(xv(1,3)+xo(1,1)+.00,xv(2,3)+xo(1,2)+.06,'$\dot{y}$',TextL{:});
text(xv(1,4)+xo(1,1)+.00,xv(2,4)+xo(1,2)-.07,'$\dot{y}''$',TextL{:});
% Axes
axis([0 sRat(pInd) 0 1]/2);
set(gca,'visible',0);


%% Draw RNN
pInd = 5; 
subplot('position',subpN(pInd,:)); cla;
% Draw RNN
xi = [0.0;...
      0.2]'*.5 + [0.15 0.2];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.5 + [0.25 0.2];
xo = [0.00 0.00;...
      0.75 0.55]'*.5 + [0.8 0.2];
Air = [1 4; 1 6];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [1 1; 3 1; 2 2; 4 2];
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([1 2],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.3);
draw_reservoir(xr,xo,0*xr(:,1),Aro,0*Aro(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([2 3],:),'lw',1.5,'hl',10,'hw',10,'hp',.85);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',15,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',52,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.8);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*0];
axis(ax);

% Text
% Macroscopic labels
text(0.00,1.01,'\textbf{d} compile $\bar{W}$+ feedback',TextL{:});
% Input labels
text(xi(1,1)-.05,xi(1,2),'$x_p$',TextRv{:});
text(xo(1,1)+.05,xo(1,2),'$o_1$',TextLv{:});
text(xo(2,1)+.05,xo(2,2),'$o_2$',TextLv{:});
drawnow;


%% Draw Pong
pInd = 6; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Walls
xo = 0.02; nsk = 300;
plot([-1 -1 1 1]*(xw+xo), [-1 1 1 -1]*(yw+xo), 'k-', 'linewidth',4,...
     'clipping',0);
% Ball
tp1 = t1; %+t2/5;
tp2 = t1+t2*.65; %+t3;
tpa = t1+t2+t3;
scatter(WRP(1,1:nsk:tp1),WRP(4,1:nsk:tp1),ms/2,(1:nsk:tp1)/tpa,'linewidth',.8);
% Marker
scatter(WRP(m,1:nsk:tp1),yp.*ones(size(WRP(m,1:nsk:tp1))),ss,(1:nsk:tp1)/tpa,...
        'filled','linewidth',3,'marker','s');
% Text
text(labX,subp(pInd,4)+labY,'\textbf{e} recurrent neural video games: pong',TitleL{:});
% Axes
ax = [[-yw yw]*sRat(pInd) -yw yw]*1.3 + [.02 .02 .025 .025];
axis(ax);
set(gca,'visible',0);


% Draw Pong 2
pInd = 7; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Walls
xo = 0.02; nsk = 300;
plot([-1 -1 1 1]*(xw+xo), [-1 1 1 -1]*(yw+xo), 'k-', 'linewidth',4,...
     'clipping',0);
% Ball
scatter(WRP(1,tp1:nsk:tp2),WRP(4,tp1:nsk:tp2),ms/2,(tp1:nsk:tp2)/t3,...
     'linewidth',.8,'clipping',0);
% Marker
scatter(WRP(m,tp1:nsk:tp2),yp.*ones(size(WRP(m,tp1:nsk:tp2))),ss,(tp1:nsk:tp2)/t3,...
        'filled','linewidth',3,'marker','s');
% Text
% Axes
ax = [[-yw yw]*sRat(pInd) -yw yw]*1.3 + [.02 .02 .025 .025];
axis(ax);
set(gca,'visible',0);


% Draw Pong 3
pInd = 8; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Walls
xo = 0.02; nsk = 300;
plot([-1 -1 1 1]*(xw+xo), [-1 1 1 -1]*(yw+xo), 'k-', 'linewidth',4,...
     'clipping',0);
% Ball
scatter(WRP(1,tp2:nsk:tpa),WRP(4,tp2:nsk:tpa),ms/2,(tp2:nsk:tpa)/t3,...
     'linewidth',.8,'clipping',0);
% Marker
scatter(WRP(m,tp2:nsk:tpa),yp.*ones(size(WRP(m,tp2:nsk:tpa))),ss,(tp2:nsk:tpa)/t3,...
        'filled','linewidth',3,'marker','s');
% Text
% Axes
ax = [[-yw yw]*sRat(pInd) -yw yw]*1.3 + [.02 .02 .025 .025];
axis(ax);
set(gca,'visible',0);


%% Draw Training RNN Data
pInd = 9; 
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xi = [0.0;...
      0.5]'*.5 + [0.65 0.1];
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.5 + [0.8 0.1];
xo = [0.00 0.00 0.00;...
      1.10 0.50 -.10]'*.5 + [1.35 0.1];
Air = [1 1; 1 6];
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [1 1; 3 1; 2 2; 4 2; 4 3; 6 3];
draw_reservoir(xi,xr,0*xi(:,1),Air,0*Air(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([1 2],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.3);
draw_reservoir(xr,xo,0*xr(:,1),Aro,0*Aro(:,1),[.5;.3],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([2 3],:),'lw',1.5,'hl',10,'hw',10,'hp',.85);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',15,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',52,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',15,'lw',1.5,'lcb',[0;1],'lc',CP([3 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',10,'hw',10,'hp',.8);

% Plot data
scv2 = .2; sct = 0.35;
plot(tz*sct-.04,X2*scv2+xi(1,2),'color',CP(1,:),'clipping',0,'linewidth',1);
plot(tz*sct+1.5,Y2(1,:)*scv2+xo(1,2),'color',CP(2,:),'clipping',0,'linewidth',1);
plot(tz*sct+1.5,Y2(2,:)*scv2+xo(2,2),'color',CP(2,:),'clipping',0,'linewidth',1);
plot(tz*sct+1.5,Y2(3,:)*scv2+xo(3,2),'color',CP(2,:),'clipping',0,'linewidth',1);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1]*1 + [[1 1]*0 [1 1]*0];
axis(ax);

% Text
% Macroscopic labels
text(-.055,0.87,'\textbf{f} conventional training of $W$ on highpass filtered data',TextL{:});
% Input labels
text(xi(1,1)-.05,xi(1,2),'$x$',TextRv{:});
text(xo(1,1)+.05,xo(1,2),'$o_1$',TextLv{:});
text(xo(2,1)+.05,xo(2,2),'$o_2$',TextLv{:});
text(xo(3,1)+.05,xo(3,2),'$o_3$',TextLv{:});
text(.25,.71,'input:',TextCv{:});
text(.25,.62,'sum of sines',TextCv{:});
drawnow;


%% Draw Decompiled Representations
pInd = 10; 
subplot('position',subpN(pInd,:)); cla;

yVES = .10;
xpInd = [1 (2:4)+.5 (5:7)+1.0 (8:10)+1.5 (11:13)+2.0];
[XG,YG] = meshgrid(xpInd*yVES,((0:2)+.5)*yVES);
XG = XG + 0.5;
xesh = -.05; yesh = .35;
hold on;

% Plot decompiled representation
YG = .8-YG;
OdMat = OsNPL2(:);
OdCol = interp1([-1 0 1]*max(abs(OdMat(:))), Cw1, OdMat);
scatter(XG(:),YG(:),200,OdCol,'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
for i = 1:3; text(XG(i,1)+xesh-.33,YG(i,1),['$x_{' num2str(i) ',t+1}=$'],TextL{:}); end

YG = YG - .35;
OdMat = WC2(:);
OdCol = interp1([-1 0 1]*max(abs(OdMat(:))), Cw1, OdMat);
scatter(XG(:),YG(:),200,OdCol,'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
% Text
for i = 1:3; text(XG(i,1)+xesh-.33,YG(i,1),['$o_{' num2str(i) ',t+1}=$'],TextL{:}); end

% Text
tRot = -45;
xLabL = {'$~1$','$x_{1,t}$','$x_{1,t}^2$','$x_{1,t}^3$',...
                '$x_{1,t-1}$','$x_{1,t-1}^2$','$x_{1,t-1}^3$',...
                '$x_{1,t-2}$','$x_{1,t-2}^2$','$x_{1,t-2}^3$',...
                '$x_{1,t-3}$','$x_{1,t-3}^2$','$x_{1,t-3}^3$'};
for i = 1:length(xLabL)
    text(XG(1,i)-.02,YG(end,1)-.08,xLabL{i},TextL{:},'rotation',tRot);
end

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);

% Text
% Macroscopic labels
text(-.055,0.87,'\textbf{g} decompiled RNN representation of output operator',TextL{:});
text(0,.65,'true',TextC{:},'rotation',90)
text(.1,.65,'filter',TextC{:},'rotation',90)
text(0,.22,'decompiled',TextC{:},'rotation',90)
text(.1,.22,'weights',TextC{:},'rotation',90)
drawnow;


%% Save
fName = 'fig_pong';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');