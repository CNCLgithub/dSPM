%% Prepare Space
code_neural_circuits;
params_fig;


%% Parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 8.0];                      % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00 4.00  4.00 4.00];...     % Subplot position in cm [x,y,w,h]
        [ 5.00 4.00 13.00 4.00];...
        [ 0.00 0.00  6.20 4.00];...
        [ 6.50 0.00  5.30 4.00];...
        [12.40 0.00  5.60 4.00]];

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


%% Draw curve
xw = 0.025; xf = 0.1;
cx = 3/13; ax = -cx/(3*xw^2);
tv1 = linspace(-.10,.12,100);
tv2 = linspace(-.12,.10,100);
fx1 = cx*tv1 + ax*tv1.^3; 
fx2 = cx*tv2 + ax*tv2.^3; 
axw = .15;
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);

% Draw dynamical system
pInd = 1; 
subplot('position',subpN(pInd,:)); cla;
hold on;
% Axes
plot([-1 1]*.15, [0 0], 'k');
plot([0 0], [-1 1]*.2, 'k');
% Ticks
line([-1 1].*[1;1]*.1, [-1 -1; 1 1]*.03,'color','k');
% Curves
plot(tv1,fx1+.1,'color',CP(1,:),'linewidth',1);
plot(tv2,fx2-.1,'color',CP(2,:),'linewidth',1);
% Points
plot(.1,0,'.','markersize',15,'color',CP(1,:));
plot(-.1,0,'.','markersize',15,'color',CP(2,:));
% Arrows
plot_spline([ .121  .12; 0 0],'color',CP(1,:),'head',1);
plot_spline([ .079  .08; 0 0],'color',CP(1,:),'head',1);
plot_spline([-.121 -.12; 0 0],'color',CP(2,:),'head',1);
plot_spline([-.079 -.08; 0 0],'color',CP(2,:),'head',1);
% plot_spline([-.121 -.12; 0 0],'color',CP(2,:),'head',1);
hold off;
% Text
text(labX,subp(pInd,4)+labY,'\textbf{a} input $z$ shifts attractor',TitleL{:});
text(0,axw*1.5,'$\dot{x}$',TextC{:});
text(axw*1.15,0,'$x$',TextR{:});
text(-.125,-.07,'$-0.1$',TextC{:});
text(.09,-.07,'$0.1$',TextC{:});
text(0,.3,'$\dot{x} = ax^3 + bx + z$',TextC{:});
text(axw*1.15,.22,'$z = 0.1$',TextR{:},'color',CP(1,:));
text(axw*1.15,.15,'$z =-0.1$',TextR{:},'color',CP(2,:));
axis([-1.1 1.1 -1.5 2.5]*axw);
set(gca,'visible',0);
drawnow;

% Draw gates
pInd = 2; 
subplot('position',subpN(pInd,:)); cla;
scg = 1.3;

% Text
text(labX,subp(pInd,4)+labY,'\textbf{b} build logic gates with specific choices of $z$',TitleL{:});
TV = {'AND','NAND','OR','NOR','XOR','XNOR'};
% Grid
xv = [[1 1]*.1 [1 1]*1.08 [1 1]*2.06;...
      0.48 0.10 0.48 0.10 0.48 0.10]*scg + [0;.1];
xi = [-.08 .05;...
      -.08 -.05]*scg;
xr = [ 0.04  0.06;...
       0.04 -0.06;...
       0.09  0.00;...
       0.16  0.00]*scg;
xo = [.35 0];
Ari = [1 1; 2 2];
Arr = [1 4; 2 4; 4 3; 3 1; 3 2];
tv = linspace(0,1,size(pt,2));
for i = 1:size(xv,2)
    % Draw network
    text(xv(1,i)+.1,xv(2,i)+.17,TV{i},TextC{:},'fontsize',8);
    text(xi(1,1)+xv(1,i)-.03,xi(1,2)+xv(2,i),'$p$',TextR{:});
    text(xi(2,1)+xv(1,i)-.03,xi(2,2)+xv(2,i),'$q$',TextR{:});
    draw_reservoir(xi+xv(:,i)',xr+xv(:,i)',1:2,Ari,0*Ari(:,1),[.9;.1],sRat(pInd),...
                   'gs',.5*scg,'nc',CP(1:2,:),'ncb',1:2,'lcb',[0;1],'lc',CG([1 2],:));
    draw_reservoir(xr+xv(:,i)',xo+xv(:,i)',0*xr(:,1),[4 1],0,[1;1],sRat(pInd),...
                   'gs',.5*scg,'h',0,'lcb',[0;1],'lc',CG([1 2],:));
    draw_reservoir(xo+xv(:,i)',xo+xv(:,i)',0,[],[],[],sRat(pInd),...
                   'gs',.5*scg,'nc',CP([3 3],:),'ncb',[-1 1]);
    draw_gate(xv(:,i)',TV{i},.1*scg,'fill','w');
    draw_reservoir(xr+xv(:,i)',xr+xv(:,i)',0*xr(:,1),Arr,0*Arr(:,1),[.5;.1],sRat(pInd),...
                   'gs',.5*scg,'hp',.8,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:));
    
    % plot logic
    plot(tv*.6+xv(1,i)+.35,wrp{i}*scg +xv(2,i),'color',CP(3,:),'linewidth',3,'clipping',0);
    plot(tv*.6+xv(1,i)+.34,pt(1,:)*scg+xv(2,i),':','color',CP(1,:),'linewidth',1,'clipping',0);
    plot(tv*.6+xv(1,i)+.35,pt(2,:)*scg+xv(2,i),':','color',CP(2,:),'linewidth',1,'clipping',0);
end
% Axes
axis([0 sRat(pInd) 0 1]);
set(gca,'visible',0);
drawnow;


%% Draw logic circuit
pInd = 3; 
subplot('position',subpN(pInd,:)); cla;
xv = [ 0.05  0.43  0.43  0.43  0.76;...
       0.78  0.73  0.50  0.27  0.385] + [.20;-.215];
TV = {'XOR', 'XOR', 'AND', 'AND', 'OR'};

xi = [-.08 .05;...
      -.08 -.05];
xr = [ 0.04  0.06;...
       0.04 -0.06;...
       0.09  0.00;...
       0.16  0.00];
xo = [ .25 0];
hold on;
% Branch off to gate 4
scatter([xv(1,1)-.05 xv(1,1)-.10]+xi(1,1), [xi(1,2) xi(2,2)]+xv(2,1),1.4^2,...
        'filled','MarkerEdgeColor','k');
plot([xv(1,1)-.05 xv(1,1)-.05 xv(1,4)]+xi(1,1),...
     [xv(2,1)     xv(2,4)      xv(2,4)]+xi(1,2),'k-');
plot([xv(1,1)-.10 xv(1,1)-.10 xv(1,4)]+xi(2,1),...
     [xv(2,1)     xv(2,4)     xv(2,4)]+xi(2,2),'k-');
% Carrier to gate 2
plot([xv(1,1)-.08-.15 xv(1,2)-.17 xv(1,2)-.17 xv(1,2)-.08],...
     [xv(2,1)-.15    xv(2,1)-.15 xv(2,2)-.05 xv(2,2)-.05], 'k');
% Carrier to gate 3
scatter(xv(1,2)-.17,xv(2,1)-.15,1.4^2,'filled','MarkerEdgeColor','k');
plot([xv(1,2)-.17 xv(1,2)-.17 xv(1,2)-.08],...
     [xv(2,1)-.15 xv(2,3)-.05 xv(2,3)-.05], 'k');
% Gates 3 and 4 to gate 5
plot([xv(1,5)-.08 xv(1,5)-.08],[xv(2,5)+.05 xv(2,3)], 'k');
plot([xv(1,5)-.08 xv(1,5)-.08],[xv(2,5)-.05 xv(2,4)], 'k');
% Gate 1 to gates 2 and 3
plot([0 .04]+xv(1,2)-0.13,[0 0]+xv(2,1), 'k-');
plot([0 0 .04]+xv(1,2)-0.13, [0 -1 -1]*.23+xv(2,1), 'k-');
% Inputs to gate 1
plot([xv(1,1)-.15;xv(1,1)].*[1 1]+xi(1,1),[xv(2,1);xv(2,1)]+xi(:,2)','k-');
scatter([-1 -1 -1]*.08+xv(1,1)-.15, [.05 -.05 -.15]+xv(2,1),3.5^2,[1 1 1]*.9,...
        'filled','MarkerEdgeColor','k');

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
% Draw scatterplot
yVES = .045;
[XG,YG] = meshgrid((1:5)*yVES,(1:8)*yVES);
XG = XG + 0.91; YG = 0.67 - YG;
WRP = [pt2(:,(1:8)*10000,1); Wradp1(:,(1:8)*10000)]';
scatter(XG(:),YG(:), 55, interp1([-.105 0 .105], Cw1, WRP(:)),...
        'filled', 'marker', 's', 'clipping', 0,'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
text(XG(1,1),YG(1,1)+.06,'$p$',TextC{:});
text(XG(1,2),YG(1,1)+.06,'$q$',TextC{:});
text(XG(1,3),YG(1,1)+.06,'$u$',TextC{:});
text(XG(1,4),YG(1,1)+.06,'$s$',TextC{:},'color',CP(4,:));
text(XG(1,5),YG(1,1)+.06,'$v$',TextC{:},'color',CP(5,:));
text(XG(1,end)+.06,YG(end,1)-.02,'logic table',TextL{:},'rotation',90);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{c} full adder of neural circuit elements',TitleL{:});
text(xv(1,1)-.26, .05+xv(2,1),'$p$',TextR{:});
text(xv(1,1)-.26,-.05+xv(2,1),'$q$',TextR{:});
text(xv(1,1)-.26,-.15+xv(2,1),'$u$',TextR{:});
text(xv(1,2)+.25,xv(2,2)-.05,'$s$',TextC{:},'color',CP(4,:));
text(xv(1,5)+.25,xv(2,5)-.05,'$v$',TextC{:},'color',CP(5,:));
% Axes
axis([0 sRat(pInd) 0 1]*.75);
set(gca,'visible',0);
drawnow;


%% Draw latch circuit
pInd = 4; 
subplot('position',subpN(pInd,:)); cla;
xv = [ 0.05  0.05 ;...
       0.78  0.38] + [.07;-.215];
TV = {'NOR', 'NOR'};

xi = [-.08 .05;...
      -.08 -.05];
xr = [ 0.04  0.06;...
       0.04 -0.06;...
       0.09  0.00;...
       0.16  0.00];
xo = [ .25 0];

hold on;
% Draw circuits
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,1),...
     [[0  0 .1 .25]+xo(2)+xv(2,2) [0 0]+xi(2,2)+xv(2,1)],'k-','clipping',0);
plot([.05*[0 1 1]+xo(1) .05*[-1 -1 0]+xi(1,1)]+xv(1,2),...
     [[0  0 -.1 -.25]+xo(2)+xv(2,1) [0 0]+xi(1,2)+xv(2,2)],'k-','clipping',0);

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

% Plot time series
tv = linspace(0,1,size(pt3,2))*.5+.56;
plot(tv,pt3(1,:)+.6,'clipping',0,'color',CP(1,:),'linewidth',1);
plot(tv,pt3(2,:)+.35,'clipping',0,'color',CP(2,:),'linewidth',1);
plot(tv,Wradp2(1,:)+.06,'clipping',0,'color',CP(3,:),'linewidth',3);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{d} persistent memory: an SR-latch',TitleL{:});
text(xv(1,1)+xi(1,1)-.03, xv(2,1)+xi(1,2),'$p$',TextR{:});
text(xv(1,2)+xi(2,1)-.03, xv(2,2)+xi(2,2),'$q$',TextR{:});
text(xv(1,2)+xo(1,1), xv(2,1)+xi(1,2),'$o$',TextL{:});
text(xv(1,2)+xo(1,1), xv(2,2)-xi(1,2),'$o''$',TextL{:});
text(tv(1),.6,'$p$',TextL{:});
text(tv(1),.35,'$q$',TextL{:});
text(tv(1),.05,'$o$',TextL{:});
% Axes
axis([0 sRat(pInd) 0 1]*.75);
set(gca,'visible',0);
drawnow;


%% Draw oscillator
pInd = 5; 
subplot('position',subpN(pInd,:)); cla;
xv = [ 0.05  0.43  0.81 ;...
       0.78  0.78  0.78] + [.07;-.215];
TV = {'NAND', 'NAND', 'NAND'};

xi = [-.08 .05;...
      -.08 -.05];
xr = [ 0.04  0.06;...
       0.04 -0.06;...
       0.09  0.00;...
       0.16  0.00];
xo = [ .25 0];

hold on;
% Draw circuits
plot(0.05*[1 0 0 1]+xo(1)+xv(1,1), 0.05*[-1 -1 1 1]+xo(2)+xv(2,1),'k-');
plot(0.05*[1 0 0 1]+xo(1)+xv(1,2), 0.05*[-1 -1 1 1]+xo(2)+xv(2,2),'k-');
plot(     [0 0 -1.15 -1.15 -1.09]+xo(1)+xv(1,3),...
     0.13*[0 1 1 0 0]+xo(2)+xv(2,3),'k-','clipping',0);
plot([0 0]+xi(1)+xv(1,1), 0.05*[-1 1]+xo(2)+xv(2,2),'k-');

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

% Plot time series
tv = linspace(0,1,size(Wradp3,2))*1.10+.03;
plot(tv,Wradp3(1,:)*.8+.34,'clipping',0,'color',CP(1,:),'linewidth',1);
plot(tv,Wradp3(2,:)*.8+.18,'clipping',0,'color',CP(2,:),'linewidth',1);
plot(tv,Wradp3(3,:)*.8+.02,'clipping',0,'color',CP(3,:),'linewidth',1);

% Text
text(labX,subp(pInd,4)+labY,'\textbf{e} multivibrator circuit oscillations',TitleL{:});
text(xv(1,1)+xo(1)-.015, xv(2,1)+xo(2)-.05,'$p$',TextR{:});
text(xv(1,2)+xo(1)-.015, xv(2,2)+xo(2)-.05,'$q$',TextR{:});
text(xv(1,3)+xo(1)-.015, xv(2,3)+xo(2)-.05,'$o$',TextR{:});
text(tv(1)-.05,.35,'$p$',TextL{:});
text(tv(1)-.05,.20,'$q$',TextL{:});
text(tv(1)-.05,.05,'$o$',TextL{:});
% Axes
axis([0 sRat(pInd) 0 1]*.75);
set(gca,'visible',0);
drawnow;


%% Save
fName = 'fig_neural_circuits';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');