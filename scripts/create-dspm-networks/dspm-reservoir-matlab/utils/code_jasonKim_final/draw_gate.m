function [] = draw_gate(x,T,s,varargin)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function for drawing a reservoir
% x:                    1 x 2 vector of coordinates
% T:                    string of gate type
% s:                    scaling factor
% 
% varargin:             variable argument inputs
%   lw:                 1 x 1 scalar of line width
%   lc:                 1 x 3 vector of weight colormap reference points
%   fill:               1 x 3 vector of fill color
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Extract dimensions and relevant variables
p = inputParser;
% Edge
addParameter(p,'lw' , 1);
addParameter(p,'lc' , [0 0 0]);
addParameter(p,'fill',[1 1 1]*.9);
parse(p,varargin{:});
lw = p.Results.lw;
lc = p.Results.lc;
f  = p.Results.fill;


%% Draw gate
hold on;
s3 = sqrt(3);
s2 = sqrt(2);
xc = s3-s2;
yc = 3/2;
nos = 25;
xl = 0.25;

% Angles
t45 = linspace(45,-45,91);
t90 = linspace(90,-90,181);
tro = linspace(-90,-90+atand(2*s2),ceil(abs(atand(2*2))));

% Coordinates
% Backs
xbf = [0 0; 1 -1]'*s + x;
xbr = [s2*cosd(t45)-s2; s2*sind(t45)]'*s + x;
% Walls
xwt = [0 s3+xl 0; 1 0 -1]'*s + x;
xwc = [0 cosd(t90)+s3-1+xl 0;...
       1 sind(t90)      -1]'*s + x;
xwr = [1-s2 yc*cosd(tro)+xc+xl    fliplr(yc*cosd(tro)+xc+xl)   1-s2;...
       -1   yc*sind(tro)+yc-1 -fliplr(yc*sind(tro)+yc-1) 1]'*s + x;

xpl1 = [];
xpl2 = [];
xpl3 = [];
switch T
    case 'BUF'
        xpl1 = [xbf;xwt];
    case 'NOT'
        xpl1 = [xbf;xwt];
        xpl2 = [(s3+.15)*s 0]+x;
    case 'AND'
        xpl1 = [xbf;xwc];
    case 'OR'
        xpl1 = [xbr;xwr];
    case 'NAND'
        xpl1 = [xbf;xwc];
        xpl2 = [(s3+.15+xl)*s 0]+x;
    case 'NOR'
        xpl1 = [xbr;xwr];
        xpl2 = [(s3+.15+xl)*s 0]+x;
    case 'XOR'
        xpl1 = [xbr;xwr];
        xpl3 = xbr - [.2 0]*s;
    case 'XNOR'
        xpl1 = [xbr;xwr];
        xpl3 = xbr - [.2 0]*s;
        xpl2 = [(s3+.15+xl)*s 0]+x;
end

if(~isempty(f))
    fill(xpl1(:,1),xpl1(:,2),f,'linewidth',.01,'clipping',0);
end

plot(xpl1(:,1),xpl1(:,2),'-','linewidth',lw,'color',lc,'clipping',0);
if(~isempty(xpl2))
    if(~isempty(f))
        plot(xpl2(:,1),xpl2(:,2),'ko','markerfacecolor',f,...
             'markersize',nos*s,'linewidth',lw,'color',lc,'clipping',0);
    else
        plot(xpl2(:,1),xpl2(:,2),'ko',...
             'markersize',nos*s,'linewidth',lw,'color',lc,'clipping',0);
    end
end
if(~isempty(xpl3))
    plot(xpl3(:,1),xpl3(:,2),'-','linewidth',lw','color',lc,'clipping',0);
end

end