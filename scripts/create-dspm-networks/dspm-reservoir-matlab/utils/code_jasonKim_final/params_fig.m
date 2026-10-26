%% Global parameters for figures
% Latex interpreter
set(groot,'defaulttextinterpreter','latex');

% Clear annotations
delete(findall(gcf,'type','annotation'));

% Plot parameters
FS = 10;                % Fontsize
ns = 6;                % Marker size for labeled nodes
resS = 70;

% Text parameters
TitleL  = {'Units','centimeters','fontsize',FS};
TitleR  = {'Units','centimeters','fontsize',FS,...
           'HorizontalAlignment','right'};
TitleC  = {'Units','centimeters','fontsize',FS,...
           'HorizontalAlignment','center'};
TextLn  = {'Units','Normalized','fontsize',FS};
TextRn  = {'Units','Normalized','fontsize',FS,...
          'HorizontalAlignment','right'};
TextCn  = {'Units','Normalized','fontsize',FS,...
          'HorizontalAlignment','center'};
TextL  = {'fontsize',FS};
TextR  = {'fontsize',FS,'HorizontalAlignment','right'};
TextC  = {'fontsize',FS,'HorizontalAlignment','center'};
TextLv  = {'fontsize',FS,'HorizontalAlignment','left',...
           'VerticalAlignment','middle'};
TextRv  = {'fontsize',FS,'HorizontalAlignment','right',...
           'VerticalAlignment','middle'};
TextCv  = {'fontsize',FS,'HorizontalAlignment','center',...
           'VerticalAlignment','middle'};

% Colors
C1 = [080 156 251]/255;
C2 = [080 181 193]/255;
C3 = [080 221 122]/255;
CA = [C1;C2;C3];

Cw1 = [.4 .4 1; [1 1 1]*.95; 1 .4 .4];





