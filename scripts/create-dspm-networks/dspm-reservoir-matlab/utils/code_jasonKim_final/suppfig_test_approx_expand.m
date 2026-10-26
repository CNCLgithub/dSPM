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
fSize = [18 9];                      % Figure Size in cm  [w,h]
fMarg = [.25 .25 .25 .25];              % Margins in cm, [l,r,d,u]
subp = [[ 0.00 6.00  6.00  3.00];...     % Subplot position in cm [x,y,w,h]
        [ 0.00 3.00  6.00  3.00];...
        [ 0.00 0.00  6.00  3.00];...
        [ 6.40 6.00  6.00  3.00];...
        [ 6.40 3.00  6.00  3.00];...
        [ 6.40 0.00  6.00  3.00];...
        [12.80 6.00  6.00  3.00];...
        [12.80 3.00  6.00  3.00];...
        [12.80 0.00  6.00  3.00]];

% Adjust position for margins
subp  = subp + [fMarg(1) fMarg(3) -sum(fMarg(1:2)) -sum(fMarg(3:4))];
subpN = subp ./ [fSize(1) fSize(2) fSize(1) fSize(2)];
sRat  = subp(:,3) ./ subp(:,4);

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
n = 1000;
m = 3;
dt = 0.001;
gamb = 100;

% Test parameters
aR = linspace(0,0.1,3);
bR = linspace(1,2,3);

% Lorenz data
L = LorenzZ([.5;.2;.4],dt,[10;28;8/3]);
LX = L.propagate(30000); 

% Define dynamics
syms t; assume(t,'real');
syms x(t) [3,1]; x = x(t); assume(x,'real');
dx = [10*(x(2)-x(1));...
      x(1) - 20*x(1).*x(3) - x(2);...
      20*x(1).*x(2) - 8/3*(x(3)+27/20)];

% Stored variables
C1S  = cell(length(aR),length(bR));
C2S  = cell(length(aR),length(bR));
C3aS = cell(length(aR),length(bR));
C3bS = cell(length(aR),length(bR));
C4aS = cell(length(aR),length(bR));
C4bS = cell(length(aR),length(bR));
C4cS = cell(length(aR),length(bR));
RTM  = cell(length(aR),length(bR));
rsM  = zeros(n,length(aR),length(bR));

% Generate Representation
for i = 1:length(aR)
    disp(i)
    for j = 1:length(bR)
        gam = gamb*bR(j);
        % Parameters
        A = sparse((rand(n)-0.5).*(rand(n)<.05)*2*aR(i));
        B = (rand(n,m)-.5)*2*0.01;
        rs = (rand(n,1)-.5)*.2;
        xs = zeros(m,1);
        d = atanh(rs) - A*rs - B*xs;
        
        % Representation
        dv = A*rs + d;
        [Pd1,C1,C2,C3a,C3b,C4a,C4b,C4c] = decomp_poly4_ns(A,B,rs,dv,gam,12);
        
        % Compute shift matrix
        [Pdx,Pdy] = find((sum(Pd1,2)+sum(Pd1,2)') <= max(sum(Pd1,2)));
        PdS = zeros(size(Pd1,1));
        for k = 1:length(Pdx)
            PdS(Pdx(k),Pdy(k)) = find(sum(Pd1==(Pd1(Pdx(k),:)+Pd1(Pdy(k),:)),2)==3);
        end
        
        pr = primes(5)';
        [GAM,DX,DDX,DDDX,DXDX,DXDXDX,DDXDX] = sym2deriv(dx,x,pr,Pd1,PdS);
        C1S{i,j} = C1;
        C2S{i,j}  = sum(deriv2shift(C2 ,DX     ,Pd1,PdS),3);
        C3aS{i,j} = sum(deriv2shift(C3a,DXDX   ,Pd1,PdS),3);
        C3bS{i,j} = sum(deriv2shift(C3b,DDX    ,Pd1,PdS),3);
        C4aS{i,j} = sum(deriv2shift(C4a,DXDXDX ,Pd1,PdS),3);
        C4bS{i,j} = sum(deriv2shift(C4b,DDXDX  ,Pd1,PdS),3);
        C4cS{i,j} = sum(deriv2shift(C4c,DDDX   ,Pd1,PdS),3);
        
        % Simulate Reservoir
        RO = ReservoirTanhB(A,B,rs,xs,dt,gam);
        RT = RO.train(LX); 
        RTM{i,j} = RT(:,10001:end); 
        rsM(:,i,j) = rs;
    end
end
LX = LX(:,10001:end,1);


%% Error
eE = cell(length(aR),length(aR));
LXM = zeros(size(Pd1,1),size(LX,2));
for i = 1:size(Pd1,1)
    LXM(i,:) = prod(LX.^(Pd1(i,:)'));
end

for i = 1:length(aR)
    i
    for j = 1:length(bR)
        C1 = C1S{i,j};
        C2 = C2S{i,j};
        C3a = C3aS{i,j};
        C3b = C3bS{i,j};
        C4a = C4aS{i,j};
        C4b = C4bS{i,j};
        C4c = C4cS{i,j};
        for k = 1:max(Pd1(:))
            disp(k);
            % Get index of approximation
            fI = max(find(sum(Pd1,2)==k));
            % Obtain estimates
            r1 = C1(:,1:fI)*LXM(1:fI,:);
            r2 = r1 + (C2(:,1:fI))*LXM(1:fI,:);
            r3 = r2 + (C3a(:,1:fI)+C3b(:,1:fI))*LXM(1:fI,:);
            r4 = r3 + (C4a(:,1:fI)+C4b(:,1:fI)+C4c(:,1:fI))*LXM(1:fI,:);
            e1 = norm(r1-RTM{i,j});
            e2 = norm(r2-RTM{i,j});
            e3 = norm(r3-RTM{i,j});
            e4 = norm(r4-RTM{i,j});
            eE{i,j} = [eE{i,j} [e1;e2;e3;e4]/norm(RTM{i,j}-rsM(:,i,j))];
        end
        disp(eE{i,j});
    end
end


%% Plot
sr = .65;
shv = .35;
[YG,XG] = meshgrid(linspace(shv/sRat(1),1-shv/sRat(1),size(eE{1,1},1))*sr,...
                   linspace(shv,sRat(1)-shv,size(eE{1,1},2)));
XG = XG'+.03; YG = YG'+.25;
CV = parula(5);
% cv = linspace(0,max(max([eE{:}])),5)';
cv = linspace(0,.01,5)';

tL = {'\textbf{a}','\textbf{b}','\textbf{c}',...
      '\textbf{d}','\textbf{e}','\textbf{f}',...
      '\textbf{g}','\textbf{h}','\textbf{i}'};

for i = 1:length(aR)
    for j = 1:length(bR)
        pInd = (i-1)*length(bR) + j;
        subplot('position',subpN(pInd,:)); cla;
        % Draw error
        scatter(XG(:),YG(:),210,interp1(cv,CV,eE{i,j}(:),'linear','extrap'),'filled','marker','s');
        % Colorbar
        if(pInd == 1)
            hold on;
            tv = linspace(.4,.8,100)';
            scatter(sRat(1)*.95,tv,10,interp1(cv,CV,linspace(0,max(cv),length(tv))),...
                    'filled','marker','s');
            hold off;
            text(sRat(1)*.95,tv(1)-.1,'0',TextC{:});
            text(sRat(1)*.95,tv(end)+.1,'0.01',TextC{:});
        end
        % Text
        text(labX,subp(pInd,4)+labY,...
             ['relative error: $\rho=$' num2str(aR(i)),...
             ', $\gamma=$', num2str(gamb*bR(j))],TitleL{:});
        text(sRat(1)/2-.01,.02,'\# of polynomial powers of {\boldmath$x$}',TextC{:});
        text(-.02,.56,'\# time',TextC{:},'rotation',90);
        text(.1,.56,'derivatives',TextC{:},'rotation',90);
        text(XG(1,1),YG(1,1)-.17,'1',TextC{:});
        text(XG(1,2),YG(1,2)-.17,'2',TextC{:});
        text(XG(1,end),YG(1,end)-.17,num2str(size(XG,2)),TextC{:});
        text(XG(1,1)-.13,YG(1,1),'1',TextC{:});
        text(XG(end,1)-.13,YG(end,1),'4',TextC{:});
        % Axes
        axis([0 sRat(pInd) 0 1]);
        set(gca,'visible',0);
        drawnow;
        
    end
end
        

%% Save
fName = 'suppfig_test_approx_expand';
set(gcf, 'Renderer', 'painters'); 
fig.PaperPositionMode = 'manual';
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 fSize];
fig.PaperSize = fSize;
saveas(fig, fName, 'pdf');
set(gcf, 'Renderer', 'opengl');
