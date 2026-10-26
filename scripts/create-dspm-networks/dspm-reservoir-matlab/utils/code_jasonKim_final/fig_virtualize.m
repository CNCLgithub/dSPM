%% Prepare Space
code_virtualize;
params_fig;


%% Parameters and dimensions
fig = figure(1); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 8.25];                      % Figure Size in cm  [w,h]
fMarg = [.25 .25 .0 .5];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00  4.50  6.50 4.00];...
        [ 6.25  4.50  6.50 4.00];...
        [12.50  4.50  5.50 4.00];...
        [ 0.00  0.00  6.50 4.00];...
        [ 6.25  0.00  6.50 4.00];...
        [12.50  0.00  5.50 4.00];...
        [ 0.00  0.00  4.50 4.50];...     % Subplot position in cm [x,y,w,h]
        [ 4.50  0.00  4.50 4.50];...
        [ 9.00  2.25  4.50 2.25];...
        [ 9.00  0.00  4.50 2.25];...
        [13.50  0.00  4.50 4.50]];

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


%% Panel a: Decompiler
pInd = 1;
subplot('position',subpN(pInd,:)); cla;

N = 5; yVES = .13;
xpInd = [1 (2:4)+.5 (5:10)+1.0];
[XG,YG] = meshgrid(xpInd*yVES,[0:1 2.5]*yVES);
XG = XG + 0.1;
YG = .58 - YG;
Co1Prox = GDNPG1([1:N-3 N],1:10);
Co1Prox = 30*Co1Prox;
cv = tanh(Co1Prox(:));
Cv = interp1([-1 0 1], Cw1, abs(cv).^(1).*sign(cv));
scatter(XG(:),YG(:),200,Cv,'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,1.0,'\textbf{a} dynamical decompiler (matrix $G^{\circ}_c$)',TextL{:});
% Inputs
tRot = -90;
xLabL = {'$1$','$\bar{x}_1$','$\bar{x}_2$','$\bar{x}_3$','$\bar{x}_1\bar{x}_2$',...
         '$\bar{x}_1\bar{x}_3$','$\bar{x}_2\bar{x}_3$','$\bar{x}_1^2$','$\bar{x}_2^2$','$\bar{x}_3^2$'};
for i = 1:length(xLabL)
    text(XG(1,i)-.01,YG(end,1)-.06,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = .04; yesh = .25;
for i = 1:2; text(XG(i,1)+xesh-.33,YG(i,1),['$g^{\circ}_' num2str(i) '\approx$'],TextL{:}); end
text(XG(1,1)+xesh-.33,YG(3,1),'$g^{\circ}_{15}\approx$',TextL{:});
% Derivatives
text(XG(1,1)+xesh-0.33,YG(1,1)+yesh,'$g^{\circ}_1\approx~~~+~~~\bar{x}_1+~~~\bar{x}_2+~~~\bar{x}_3+\dots$',TextL{:});
text(XG(1,1)+xesh-0.04,YG(1,1)+yesh,'$g^{\circ*}_1$',TextC{:},'color',Cv(1,:))
text(XG(1,1)+xesh+0.16,YG(1,1)+yesh,'$\frac{\partial g_1^{\circ*}}{\partial \bar{x}_1}$',TextC{:},'color',Cv(4,:))
text(XG(1,1)+xesh+0.48,YG(1,1)+yesh,'$\frac{\partial g_1^{\circ*}}{\partial \bar{x}_2}$',TextC{:},'color',Cv(7,:))
text(XG(1,1)+xesh+0.80,YG(1,1)+yesh,'$\frac{\partial g_1^{\circ*}}{\partial \bar{x}_3}$',TextC{:},'color',Cv(10,:))
hold on;

% Draw Arrows
plot_spline([XG(1,1)+xesh-0.04,YG(1,1)+yesh-.08; XG(1,1),YG(1,1)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
plot_spline([XG(1,1)+xesh+0.16,YG(1,1)+yesh-.08; XG(1,2),YG(1,2)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
plot_spline([XG(1,1)+xesh+0.48,YG(1,1)+yesh-.08; XG(1,3),YG(1,3)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
plot_spline([XG(1,1)+xesh+0.80,YG(1,1)+yesh-.08; XG(1,4),YG(1,4)+.00]','head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Plot b
pInd = 2;
subplot('position',subpN(pInd,:)); cla;

yVES = .13;
xpInd = [1 (2:4)+.5 (5:10)+1.0];
[XG,YG] = meshgrid(xpInd*yVES,[(0:2)+.5]*yVES);
XG = XG + 0.1;
YG = .58 - YG;
cv = OdNPLG;
cv = cv(:);
Cv = interp1([-1 0 1], Cw1, cv);
scatter(XG(:),YG(:),200,repmat([1 1 1]*.85,[numel(XG),1]),'s','filled',...
            'linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;
scatter(XG(cv~=0),YG(cv~=0),200,Cv(cv~=0,:),'s','filled');

% Text
text(-.05,1.0,'\textbf{b} code dynamic memory (matrix $\bar{O}^{\circ}_c$)',TextL{:});
text(-.05,.87,'code {\boldmath$\bar{o}^{\circ}$} $=$ {\boldmath$\bar{x}$}$+\frac{1}{\gamma^{\circ}}${\boldmath$\dot{\bar{x}}$}, where {\boldmath$\dot{\bar{x}}$}$=f(${\boldmath$\bar{x}$}$)$',TextL{:})
% Inputs
tRot = -90;
xLabL = {'$1$','$\bar{x}_1$','$\bar{x}_2$','$\bar{x}_3$','$\bar{x}_1\bar{x}_2$',...
         '$\bar{x}_1\bar{x}_3$','$\bar{x}_2\bar{x}_3$','$\bar{x}_1^2$','$\bar{x}_2^2$','$\bar{x}_3^2$'};
for i = 1:length(xLabL)
    text(XG(1,i)-.01,YG(end,1)-.06,xLabL{i},TextL{:},'rotation',tRot);
end
% Neurons
xesh = .04; yesh = .17;
for i = 1:3; text(XG(i,1)+xesh-.33,YG(i,1),['$\bar{o}^{\circ}_' num2str(i) '=$'],TextL{:}); end
% Derivatives
text(-.05,.7,'$\bar{o}^{\circ}_1 = \bar{x}_1 + \frac{\bar{x}_2-\bar{x}_1}{\gamma^{\circ}}=\left(1-\frac{1}{\gamma^{\circ}}\right)\bar{x}_1 + \frac{1}{\gamma^{\circ}}\bar{x}_2$',TextL{:});
hold on;
plot_spline([XG(1,2)+xesh+0.45,YG(1,1)+yesh-.08; XG(1,2),YG(1,1)+.00]',...
            'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
plot_spline([XG(1,3)+xesh+0.78,YG(1,1)+yesh-.08; XG(1,3),YG(1,1)+.00]',...
            'head',1,'headpos',1,'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Panel c: Output
pInd = 3;
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.4 + [-0.02 0.58];
xo = [0.00 0.00 0.00;...
      0.80 0.50 0.20]'*.4 + [0.42 .58];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
Aro = [6 1; 1 1; 6 2; 1 2; 6 3; 1 3];
hold on;
draw_reservoir(xr,xo,0*xr(:,1),Aro,[1 1 1 1 1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([5 2],:),'lw',1.0,'hl',7,'hw',7,'hp',.91);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',10,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',37,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.7);
text(xo(1,1)+.04,xo(1,2)+.01,'$o^{\circ}_1$');
text(xo(2,1)+.04,xo(2,2)+.01,'$o^{\circ}_2$');
text(xo(3,1)+.04,xo(3,2)+.01,'$o^{\circ}_3$');

vw = [24 13]; VM = viewmtx(vw(1),vw(2),0);
tv = linspace(0.15,1,size(WWRPG,2));
[XC,xI,XP] = downsample_curvature(WWRPG,.001,vw);
plot(tv(xI)+xo(1,1),XC*.4 + xo(:,2),'color',CP(2,:),'clipping',0);
scvp = 2.5;
plot(XP(1,:)*scvp+1,XP(2,:)*scvp+.26,'clipping',0,'color',CP(2,:));

% Axes
xshv = .45; yshv = .05;
for i = 1:3
    plot_spline([0 VM(1,i); 0 VM(2,i)]*.2 + [xshv;yshv],'head',1,'headpos',1,...
                'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
    text(VM(1,i)*.2+xshv+.02, VM(2,i)*.2+yshv+.02,['$o_' num2str(i) '$'])
end


% Text
text(-.05,1.0,'\textbf{c} compile $\|\bar{W}^{\circ}G^{\circ}_c - \bar{O}^{\circ}_c\|$, feedback',TextL{:});
xerel = 0.02; yerel = .5;
text(xerel,yerel,'$A^{\circ}$',TextC{:},'color',CP(6,:));
text(xerel+.11,yerel,'$=$',TextC{:});
text(xerel+.22,yerel,'$\bar{A}^{\circ}$',TextC{:},'color',CP(3,:));
text(xerel+.31,yerel,'$+$',TextC{:});
text(xerel+.40,yerel,'$\bar{B}^{\circ}$',TextC{:},'color',CP(4,:));
text(xerel+.53,yerel,'$\bar{W}^{\circ}$',TextC{:},'color',CP(5,:));
text(xerel,yerel-.15,'$W^{\circ}$',TextC{:},'color',CP(2,:));
text(xerel+.23,yerel-.15,'$\bar{W}^{\circ}$',TextC{:},'color',CP(5,:));
text(xerel+.11,yerel-.15,'$=$',TextC{:});
text(1,.54,'output: $W^{\circ}${\boldmath$r^{\circ}$}',TextC{:});

set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Panel d: draw
pInd = 4;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.03;
Np = 25;
xInd = {1,2:NG+1,16:42};
xpInd = [xInd{1} xInd{2}+2.5 xInd{3}+5];
[XG,YG] = meshgrid(xpInd*yVES,[0:Np-4 Np]*yVES);
XG = XG + 0.15;
YG = .9 - YG;
Co1Prox = [GdNPLH([1:Np-3 Np],[xInd{:}])];
Co1Prox = 10*Co1Prox ./ sqrt(sqrt(sum(Co1Prox.^2)));
cv = tanh(Co1Prox(:));
Cv = interp1([-1 0 1], Cw1, cv);
scatter(XG(:),YG(:),13,Cv,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);

% Text
text(-.05,1.01,'\textbf{d} dynamical decompiler (matrix $G_c$)',TextL{:});
% Inputs
tRot = 0;
text(XG(1,1),YG(end,1)-.08,'$1$',TextC{:},'rotation',tRot);
text(XG(1,round(NG/2)+2),YG(end,1)-.08,'$r^{\circ}_1,\dots,r^{\circ}_{15}$',TextC{:},'rotation',tRot);
text(XG(1,NG+4 + 11),YG(end,1)-.08,'{\boldmath$r^{\circ}$}$\otimes$ {\boldmath$r^{\circ}$}',TextC{:},'rotation',tRot);
% Neurons
xesh = .04; yesh = .25;
text(XG(1,1)+xesh-.27,YG(12,1),'{\boldmath$g$} $\approx$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Panel e: draw
pInd = 5;
subplot('position',subpN(pInd,:)); cla;

yVES = 0.0285;
Np = 15;
xInd = {1,2:NG+1,16:41};
xpInd = [xInd{1} xInd{2}+2.5 xInd{3}+5];
[XG,YG] = meshgrid(xpInd*yVES,(0:Np-1)*yVES);
XG = XG + 0.18;
YG = .54 - YG;
Co1Prox = [OdNPLH(1:Np,[xInd{:}])];
Co1Prox = 2*Co1Prox ./ sqrt(sqrt(sum(Co1Prox.^2)));
cv = tanh(Co1Prox(:));
Cv = interp1([-1 0 1], Cw1, cv);
scatter(XG(:),YG(:),13,Cv,'s','filled','linewidth',.1','MarkerEdgeColor',[1 1 1]*.9);
hold on;

% Draw small RNN
xr = [0.40 0.75 0.10 0.45 0.65 0.30;...
      0.80 0.60 0.50 0.45 0.25 0.15]'*.35 + [1.24 0.60];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Arr = [2 1; 1 3; 2 4; 2 5; 3 1; 3 4; 3 6; 4 1; 4 6; 5 6; 6 4];
hold on;
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',33,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',10,'lw',1.0,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',7,'hw',7,'hp',.7);

delete(findall(gcf,'type','annotation'));
ar = annotation('arrow'); ar.HeadLength = 4; ar.HeadWidth = 4; ar.Position = [.67 .325 .025 0];

% Text
text(-.05,1.01,'\textbf{e} code RNN dynamics (matrix $\bar{O}_c$)',TextL{:});
text(-.05,.87,'code {\boldmath$\bar{o}$} $=$ {\boldmath$r^{\circ}$}$+\frac{1}{\gamma}${\boldmath$\dot{r}^{\circ}$}, where {\boldmath$\dot{r}^{\circ}$}',TextL{:});
text(-.05,.73,'is the guest RNN dynamics')
% Inputs
tRot = 0;
text(XG(1,1),YG(end,1)-.08,'$1$',TextC{:},'rotation',tRot);
text(XG(1,round(NG/2)+2),YG(end,1)-.08,'$r_1^{\circ},\dots,r_{15}^{\circ}$',TextC{:},'rotation',tRot);
text(XG(1,NG+4 + 11),YG(end,1)-.08,'{\boldmath$r^{\circ}$}$\otimes$ {\boldmath$r^{\circ}$}',TextC{:},'rotation',tRot);
% Neurons
xesh = .04; yesh = .25;
text(XG(1,1)+xesh-.3,YG(1,1),'$\bar{o}_1=$',TextL{:});
text(XG(1,1)+xesh-.3,YG(15,1),'$\bar{o}_{15}=$',TextL{:});

% axis
set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Panel f: Output
pInd = 6;
subplot('position',subpN(pInd,:)); cla;

% Draw RNN
xr = [0.40 0.65 0.20 0.50 0.75 0.30 0.10 0.45 0.65 0.25 0.45 0.65 0.30;...
      0.80 0.75 0.70 0.65 0.60 0.55 0.50 0.45 0.43 0.35 0.30 0.25 0.20]'*.43 + [-0.05 0.55];
xo = [0.00 0.00 0.00 0.00;...
      0.80 0.65 0.50 0.3]'*.43 + [0.42 .55];
CP = lines(4); CP = [CP(1:3,:); CP(1:2,:).^.6; CP(4,:)];
CG = gray(10);
Arr = [2 1; 3 1; 1 4; 5 2; 2 4; 3 4; 3 6; 4 5; 4 6; 4 8; 5 8; 5 9; 5 12; 6 7; 6 8; 6 10;...
       7 3; 7 10; 11 8; 10 11; 11 12; 11 9; 11 13; 13 10; 7 13; 12 13; 9 11];
Aro = [1 1; 6 1; 1 2; 8 2; 1 3; 10 3; 8 4; 13 4];
hold on;
draw_reservoir(xr,xo,0*xr(:,1),Aro,[1 1 1 1 1 1 1 1],[.5;.5],sRat(pInd),'gs',.5,...
               'lcb',[0;1],'lc',CP([5 2],:),'lw',0.7,'hl',5,'hw',5,'hp',.91);
draw_reservoir(xo,xo,0*xo(:,1),[],[],[],sRat(pInd),'gs',.5,...
               'ns',6,'lcb',[0;1],'lc',CP([2 3],:),'ncb',[0;1],'nc',CG([8 10],:));
plot(mean(xr(:,1)),mean(xr(:,2)),'ko','linewidth',1,'markersize',37,'markerfacecolor','w');
draw_reservoir(xr,xr,0*xr(:,1),Arr,0*Arr(:,1),[.4;.7],sRat(pInd),'gs',.5,...
               'ns',6,'lw',0.7,'lcb',[0;1],'lc',CP([6 1],:),'ncb',[0;1],'nc',CG([8 10],:),...
               'hl',5,'hw',5,'hp',.7);
text(xo(1,1)+.04,xo(1,2)+.01,'$o_1$');
text(xo(2,1)+.04,xo(2,2)+.01,'$o_2$');
text(xo(3,1)+.04,xo(3,2)+.01,'$o_3$');
text(xo(end,1)+.04,xo(end,2)+.01,'$o_{15}$');

tv = linspace(0.18,1,size(WRP,2));
[XC,xI,XP] = downsample_curvature(WRP,.001);
plot(tv(xI)+xo(1,1),(XC([1:3 end],:)-rsG([1:3 end]))*2.5 + xo(:,2),'color',CP(2,:),'clipping',0);
vw = [24 13]; VM = viewmtx(vw(1),vw(2),0);
tv = linspace(0.18,1,size(WWRP,2));
[XC,xI,XP] = downsample_curvature(WWRP,.001,vw);
scvp = 2.5;
plot(XP(1,:)*scvp+1,XP(2,:)*scvp+.3,'clipping',0,'color',CP(2,:));

% Axes
xshv = .45; yshv = .05;
for i = 1:3
    plot_spline([0 VM(1,i); 0 VM(2,i)]*.2 + [xshv;yshv],'head',1,'headpos',1,...
                'ratio',sRat(pInd),'linewidth',.7,'headwidth',3,'headlength',3);
    text(VM(1,i)*.2+xshv+.02, VM(2,i)*.2+yshv+.02,['$o_' num2str(i) '$'])
end

% Text
text(-.05,1.01,'\textbf{f} compile $\|\bar{W}G_c - \bar{O}_c\|$, feedback',TextL{:});
xerel = 0.02; yerel = .5;
text(xerel,yerel,'$A$',TextC{:},'color',CP(6,:));
text(xerel+.11,yerel,'$=$',TextC{:});
text(xerel+.20,yerel,'$\bar{A}$',TextC{:},'color',CP(3,:));
text(xerel+.29,yerel,'$+$',TextC{:});
text(xerel+.36,yerel,'$\bar{B}$',TextC{:},'color',CP(4,:));
text(xerel+.46,yerel,'$\bar{W}$',TextC{:},'color',CP(5,:));
text(xerel,yerel-.15,'$W$',TextC{:},'color',CP(2,:));
text(xerel+.21,yerel-.15,'$\bar{W}$',TextC{:},'color',CP(5,:));
text(xerel+.11,yerel-.15,'$=$',TextC{:});
text(1,.59,'output: $W^{\circ}W${\boldmath$r$}',TextC{:});

set(gca,'visible',0,'xtick',[],'ytick',[]);
ax = [0 sRat(pInd) 0 1];
axis(ax);
drawnow;


%% Save
fName = 'fig_virtualize';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, ['../results/' fName], 'pdf');
set(gcf, 'Renderer', 'opengl');

