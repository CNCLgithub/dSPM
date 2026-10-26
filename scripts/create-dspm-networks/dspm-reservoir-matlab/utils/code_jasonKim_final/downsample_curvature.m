function [XC, dInd, XP] = downsample_curvature(X,a,v)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function for downsampling the curvature of data.
%
% Inputs:
% X:        3 x T matrix of a 3-dimensional time series
% a:        1 x 1 scalar for the curvature threshold
% v:        1 x 2 view vector (degrees) for the azimuth and elevation
% 
% Outputs
% XC:       3 x t matrix of downsampled datapoints
% dInd:     1 x t matrix of downsampled indices from the original series X
% XP:       2 x t matrix of projected datapoints
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(nargin == 3)
    % Save normally sampled data for later
    XS = X;
    
    % Project time series onto 2D plane
    A = viewmtx(v(1),v(2),0);
    X = A*[X;ones(1,size(X,2))];
    X = X(1:2,:);
end

VInd = [1 1];
n_start = size(X,2);
aInd = 1:n_start;
dInd = [];

while(length(VInd) > 1)
    % Initialize
    V = diff(X,1,2);
    VMag = sum(V(:,2:end) .* V(:,1:end-1)) ./ sqrt(sum(V(:,1:end-1).^2));
    VNorm = [a+1 sqrt(sum(V(:,2:end).^2) - VMag.^2)];
    
    % Find indices where curvature is already greater than a
    VIndL = find(VNorm < a);
    VIndU = find(VNorm > a);
    
    % Remove indices around points that are already too sharp
    VIndL = setdiff(VIndL,[VIndU+1 VIndU-1]);
    if(isempty(VIndL)); break; end
    
    % Search for consecutive points
    VIndD = [2 diff(VIndL)];
    VIndNC = VIndL(VIndD ~= 1);          % Nonconsecutive indices
    VIndC = VIndL(VIndD == 1);           % Consecutive indices
    
    % Putative points to remove
    VIndR = [VIndNC VIndC(1:2:end)];    % Remove every other conescutive
    % Putative points to keep
    VIndK = setdiff(1:size(X,2),VIndR);
    
    % Curvature of points to keep
    XP = X(:,VIndK);
    V = diff(XP,1,2);
    VMag = sum(V(:,2:end) .* V(:,1:end-1)) ./ sqrt(sum(V(:,1:end-1).^2));
    VNorm = [a sqrt(sum(V(:,2:end).^2) - VMag.^2)];
    VIndKO = VIndK(VNorm > a);
    
    % Remove bad points to remove
    VIndR = setdiff(VIndR,[VIndKO+1 VIndKO-1]);
    if(isempty(VIndR)); break; end
    
    % Keep track of removed points
    dInd = [dInd aInd(VIndR)];          % Collected removed indices
    dr = setdiff(1:size(X,2),VIndR);
    aInd = aInd(dr);                    % Remaining indices
    X = X(:,dr);
end
dInd = setdiff(1:n_start,dInd);
XP = X;
if(nargin == 3)
    X = XS(:,dInd);
end
XC = X(:,1:end);
disp(['compression ratio: ' num2str(size(XC,2)/n_start)]);
end