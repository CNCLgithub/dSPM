function [] = draw_reservoir(xi,xo,xw,A,Aw,Ac,sRat,varargin)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function for drawing a reservoir
% xi:                   n x 2 matrix of start node coordinates
% xo:                   n x 2 matrix of end node coordinates
% xw:                   n x 1 vector of node activity
% A:                    k x 2 matrix of node connectivity
% Aw:                   k x 1 vector of connectivity weight
% Ac:                   1 x 2 vector of connectivity curvature
% 
% varargin:             variable argument inputs
% Connectivity
%   Ac:                 k x 2 matrix of connectivity curvature
%   lw:                 1 x 1 scalar of line width
%   lc:                 m x 3 matrix of weight colormap reference points
%   lcb:                m x 1 vector of weight reference points
%   hp:                 1 x 1 scalar of arrow position
%   hw:                 1 x 1 scalar for head width
%   hl:                 1 x 1 scalar for head length
% Node
%   ns:                 1 x 1 scalar of node size
%   nc:                 o x 3 matrix of activity colormap reference points
%   ncb:                m x 1 vector of activity reference points
%   bw:                 1 x 1 scalar of boarder width
%   bc:                 1 x 3 vector of boarder color
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Extract dimensions and relevant variables
n = size(xi,1);
k = size(A,1);

p = inputParser;
% Global scaling
addParameter(p,'gs',1);
% Edge
addParameter(p,'Ad' , [0;0]);
addParameter(p,'lw' , .5);
addParameter(p,'lc' , parula(10));
addParameter(p,'lcb', linspace(-1,1,10));
addParameter(p,'hp' , 0.7);
addParameter(p,'hw' , 5);
addParameter(p,'hl' , 5);
addParameter(p,'h'  , 1);
% Node
addParameter(p,'ns' , 7);
addParameter(p,'nc' , parula(10));
addParameter(p,'ncb', linspace(-1,1,10));
addParameter(p,'bw' , .5);
addParameter(p,'bc' , [0 0 0]);
% Reservoir
parse(p,varargin{:});

% Edge
gs  = p.Results.gs;
Ad  = p.Results.Ad;
lw  = p.Results.lw;
lc  = p.Results.lc;
lcb = p.Results.lcb;
hp  = p.Results.hp;
hw  = p.Results.hw*gs;
hl  = p.Results.hl*gs;
h   = p.Results.h;
% Node
ns  = p.Results.ns*gs;
nc  = p.Results.nc;
ncb = p.Results.ncb;
bw  = p.Results.bw*gs;
bc  = p.Results.bc;


%% Draw edges
hold on;
lC = interp1(lcb,lc,Aw);
for i = 1:k
    a = [0 Ac(1,:) 1; 0 Ac(2,:) 1];
    ad = [0 Ad(1)*ones(1,size(Ac,2)) 0;...
          0 Ad(2)*ones(1,size(Ac,2)) 0];
    Av = ad + (xo(A(i,2),:)-xi(A(i,1),:))';
    plot_spline(a.*Av + xi(A(i,1),:)',...
                'ratio',sRat,'color',lC(i,:),'linewidth',lw,...
                'headpos',hp,'headwidth',hw,'headlength',hl,...
                'head',h);
end


%% Draw nodes
% Get node coordinates
nC = interp1(ncb,nc,xw);
scatter(xi(:,1),xi(:,2),ns^2,nC,'filled','MarkerEdgeColor',bc,...
        'LineWidth',bw,'clipping',0);
end