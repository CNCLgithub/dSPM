
x0 = rishi_data.x0;
y0 = rishi_data.y0;
xdata = rishi_data.sim_coordinates.x;
ydata = rishi_data.sim_coordinates.y;

xdata_avg = nan(100,79);
ydata_avg = nan(100,79);
xdata_ext = nan(100,79);
ydata_ext = nan(100,79);

xdata_avg(1:7,:) = repmat(x0',7,1);
ydata_avg(1:7,:) = repmat(y0',7,1);
xdata_ext(1:7,:) = repmat(x0',7,1);
ydata_ext(1:7,:) = repmat(y0',7,1);

TBIN_WIN = 1:50;
for i = 7:100

    tbinIdx = TBIN_WIN*(i-6);

    for j = 1:79

        if numel(xdata{j})< max(tbinIdx), continue,end

        xdata_avg(i,j) = mean(xdata{j}(tbinIdx))/100;
        ydata_avg(i,j) = mean(ydata{j}(tbinIdx))/100;
        xdata_ext(i,j) = mean(xdata{j}(max(tbinIdx)))/100;
        ydata_ext(i,j) = mean(ydata{j}(max(tbinIdx)))/100;

    end

end


%%
idx = rishi_data.nbounces;
subplot(231)
plot(xdata_ext(:,idx),ydata_ext(:,idx))

subplot(234)
plot(xdata_ext(:,~idx),ydata_ext(:,~idx))

idx = logical(perle.meta.n_bounce);
subplot(232)
plot(xdata_ext(:,idx),ydata_ext(:,idx))

subplot(235)
plot(xdata_ext(:,~idx),ydata_ext(:,~idx))

idx = logical(sum(ydata_Vel<0));
subplot(233)
plot(xdata_ext(:,idx),ydata_ext(:,idx))

subplot(236)
plot(xdata_ext(:,~idx),ydata_ext(:,~idx))

%%

sd     = sign(rishi_data.ydot0(:)');            % [1 × 79] launch y-direction
is_bnc = logical(rishi_data.nbounces(:)');      % [1 × 79] bounce trials (26)

bounce_state = ones(size(ydata_ext));           % [100 × 79], +1 everywhere
for j = find(is_bnc)
    yj      = ydata_ext(:, j) * sd(j);          % y projected onto launch direction
    [~, tb] = max(yj, [], 'omitnan');           % turning point = wall contact
    bounce_state(tb+1:end, j) = -1;             % post-bounce
end
bounce_state(isnan(ydata_ext)) = 0;             % ended / inactive

brain.bounce_mask = bounce_state';              % [79 × 100], matches all/vis/occ masks


%%

rishi_data.ballXData = xdata_ext;
rishi_data.ballYData = ydata_ext;

rishi_data.ballXData_tbinAvg = xdata_avg;
rishi_data.ballYData_tbinAvg = ydata_avg;

%%
bncvec = rishi_data.nbounces;
yvel   = rishi_data.ydot0;

bounce_yvel_pos    =  bncvec & (yvel > 0 );
nobounce_yvel_pos  = ~bncvec & (yvel > 0 );
bounce_yvel_neg    =  bncvec & (yvel < 0 );
nobounce_yvel_neg  = ~bncvec & (yvel < 0 );

tbl = struct();
tbl.bounce_yvel_pos   = bounce_yvel_pos  ;
tbl.nobounce_yvel_pos = nobounce_yvel_pos;
tbl.bounce_yvel_neg   = bounce_yvel_neg  ;
tbl.nobounce_yvel_neg = nobounce_yvel_neg;

rishi_data.bounce_velocity_groups = tbl;

%%


save("../../data/brain_and_rishi_data.mat","rishi_data","brain")


%%

bncvec = rishi_data.nbounces;
yvel   = rishi_data.ydot0;

bounce_yvel_pos    =  bncvec & (yvel > 0 );
nobounce_yvel_pos  = ~bncvec & (yvel > 0 );
bounce_yvel_neg    =  bncvec & (yvel < 0 );
nobounce_yvel_neg  = ~bncvec & (yvel < 0 );


close all

fplot = @(i) plot(xdata_ext(:,i),ydata_ext(:,i));

subplot(221); 
fplot(bounce_yvel_pos)
title(gca,"bounce $+\dot{y}$","Interpreter","latex")

subplot(222)
fplot(bounce_yvel_neg)
title(gca,"bounce $-\dot{y}$","Interpreter","latex")

subplot(223)
fplot(nobounce_yvel_pos)
title(gca,"no bounce $+\dot{y}$","Interpreter","latex")

subplot(224)
fplot(nobounce_yvel_neg)
title(gca,"no bounce $-\dot{y}$","Interpreter","latex")

