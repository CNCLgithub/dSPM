%% Prepare Space
clear; clc;
params_fig
rng(0);


%% Parameters and dimensions
fig = figure(2); clf;
delete(findall(gcf,'type','annotation'));

% Figure parameters
FS = 10;                                % Fontsize
gr = 0.8;                               % Alpha of gray color
fSize = [18 6];                      % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00 0.00  6.00  6.00];...     % Subplot position in cm [x,y,w,h]
        [ 5.75 0.00  6.00  6.00];...
        [12.00 0.00  6.00  6.00]];

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



%% Global parameters
% Reservoir
gam = 100;
n = 1000;
m = 3;
dt = 0.001;

% Test parameters
aR = linspace(0,0.1,10);
bR = linspace(0.01,0.1,10);
AM = zeros(n,n,length(aR),length(bR));
RTM = zeros(n,20000,length(aR),length(bR));
RLTM = zeros(n,20000,length(aR),length(bR));
rsM = zeros(n,length(aR),length(bR));

% Lorenz data
L = LorenzZ([.5;.2;.4],dt,[10;28;8/3]);
LX = L.propagate(30000); 

% Simulate
for i = 1:length(aR)
    disp(i)
    parfor j = 1:length(bR)
        % Parameters
        A = sparse((rand(n)-0.5).*(rand(n)<.05)*2*aR(i));
        B = (rand(n,m)-.5)*2*bR(j);
        rs = (rand(n,1)-.5)*0;
        xs = zeros(m,1);
        d = atanh(rs) - A*rs - B*xs;

        % Representation
        dv = A*rs + d;
        % Test expansion approximation of R
        AL = sparse(gam*((1-tanh(A*rs+B*xs+d).^2).*A - eye(n)));
        BL = gam*sparse(eye(n));
        RO = ReservoirTanhB(A,B,rs,xs,dt,gam);
        ROL = ReservoirLin(AL,BL,dt);
        % Run simulation
        tpmt = tanh(pagemtimes(B,LX)+dv);
        LXL = tpmt - (A*rs).*(1-tpmt.^2);
        RT = RO.train(LX);
        RLT = ROL.train(LXL);
        RTM(:,:,i,j) = RT(:,10001:end); 
        RLTM(:,:,i,j) = RLT(:,10001:end);
        rsM(:,i,j) = rs;
        % Store
        AM(:,:,i,j) = A;
    end
end

%% Error
aE = zeros(length(aR),length(bR));
eE = zeros(length(aR),length(bR));
for i = 1:length(aR)
    disp(i);
    for j = 1:length(bR)
        eE(i,j) = norm(RTM(:,:,i,j) - RLTM(:,:,i,j)) / norm(RTM(:,:,i,j)-rsM(:,i,j));
        aE(i,j) = max(abs(eigs(AM(:,:,i,j),3,'largestabs','Tolerance',1e-16,'MaxIterations',1e5)));
    end
end
        

%% Plot
vw = [-12,20];
lx = downsample_curvature(LX(:,:,1),0.001,vw);
CP = lines(5);
aEm = mean(aE,2);

% Plot Trajectory
pInd = 1; 
subplot('position',subpN(pInd,:)); cla;
% Axes
plot3([-1 -1 -1 1],[1 1 -1 -1],[1 -1 -1 -1],'k-','linewidth',1,'clipping',0);
hold on;
plot3([-1 1 1 1],[1 1 -1 -1],[1 1 1 -1],'k:','linewidth',.5,'clipping',0);
plot3(lx(1,:),lx(2,:),lx(3,:), 'clipping', 0,'color',CP(1,:));
hold off;
% Text
text(labX,subp(pInd,4),'\textbf{a}~~test input time series',TitleL{:});
text(0,-1,-1.25,'$x_1$',TextC{:});
text(-1,-1,-1.2,'$-1$',TextC{:});
text(1,-1,-1.2,'$1$',TextC{:});
text(-1.1,0,-1,'$x_2$',TextR{:});
text(-1.2,1,0,'$x_3$',TextL{:});
% Axes
view(vw);
set(gca,'visible',0);
axis([-1,1,-1,1,-1,1]*1.1);


% Scatterplot of output error
pInd = 2; 
subplot('position',subpN(pInd,:)); cla;
CV = parula(5);
cv = linspace(0,max(eE(:)),5)';
shv = .12;
[YG,XG] = meshgrid(linspace(shv,1-shv,length(aR)),linspace(shv,1-shv,length(bR)));
% YG = 1-YG;
scatter(XG(:),YG(:),300,interp1(cv,CV,eE(:)),'filled','marker','s');
% Colorbar
hold on;
cbx = 1.03; shvc = .15;
tv = linspace(shvc,1-shvc,100)';
scatter(0*tv+cbx,tv,100,interp1(cv,CV,linspace(0,max(cv),length(tv))'),...
        'filled','marker','s','clipping',0);
hold off;
% Text
text(labX,subp(pInd,4),'\textbf{b} relative error of {\boldmath$r$}$(t)$ approximation',TitleL{:});
text(.5,-.00,'average $\rho$',TextC{:});
text(shv,0.03,num2str(aR(1),2),TextC{:});
text(1-shv,0.03,num2str(aEm(end),2),TextC{:});
text(.00,.5,'$b$',TextR{:});
text(.07,shv,num2str(bR(1),2),TextR{:});
text(.07,1-shv,num2str(bR(end),2),TextR{:});
text(cbx,shvc-.07,'0',TextC{:});
text(cbx,1-shvc+.07,num2str(max(cv),2),TextC{:});
text(cbx-.05,.5,'relative error',TextC{:},'rotation',90);
% Axes
set(gca,'visible',0);
axis([0 1 0 1]);


% Spectral radius
pInd = 3; 
subplot('position',subpN(pInd,:)); cla;
% Axes
plot([0 0 max(aR)],[max(mean(aE,2)) 0 0], 'k-', 'linewidth', 1,'clipping',0);
% Plot
hold on;
plot(aR,mean(aE,2),'-','linewidth',.5,'color',CP(1,:));
errorbar(aR,mean(aE,2),std(aE,0,2),'.','markersize',10,'color',CP(1,:));
hold off;
% Text
text(labX+.35,subp(pInd,4),'\textbf{c}~~~spectral radius of $A$ \textit{versus} $a$',TitleL{:});
text(max(aR)/2,-.025,'$a$',TextL{:});
text(-.003,max(mean(aE,2))/2,'$\rho$',TextR{:});
text(0,-.025,'$0$',TextC{:});
text(max(aR)*1.02,0,num2str(max(aR),2),TextL{:});
text(-.003,0,'$0$',TextR{:});
text(0,max(mean(aE,2))*1.03,num2str(max(mean(aE,2)),2),TextC{:});

bw1 = .01;
bw2 = .05;
axis([-bw1 max(aR)+bw1 -bw2/2 max(mean(aE,2))+bw2]);
set(gca,'visible',0);


%% Save
fName = 'suppfig_test_approx_lin';
set(gcf, 'Renderer', 'painters');
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, fName, 'pdf');
set(gcf, 'Renderer', 'opengl');
