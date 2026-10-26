%% =====================================================================
%  LDA GEOMETRY — PLOTTING  (two-stage results)
%
%  Consumes lda_results.mat from lda_analysis.m. Pure consumer.
%
%  Fig G   geometry scatter at (p*,t*): raw PC pair + (v1,v2) projection
%  Fig TC  gated theta(t) ribbon (top) over separation(t) envelope (bottom)
%          — DMFC transient vs dSPM flat; theta greyed where sep is low
%  Fig S   theta_hat ± CI vs marginal-null band, + paired Δtheta
% =====================================================================

load('lda_results.mat');   % geo_results, paired, theta_bs, sys_labels,
                           % sys_colors, nSystems, tvec_bs, CLASS_DEF,
                           % SEP_GATE_FRAC, ...

%% ── Presentation constants ───────────────────────────────────────────
CLASS_COLORS       = {'#1A5FA8','#7DAFD6','#C45B00','#F0A860'};
CLASS_LABELS_SHORT = {'+ẏ ¬b','−ẏ ¬b','+ẏ b','−ẏ b'};   % index-aligned to CLASS_DEF
V1_NAME = 'v_1  (ẏ-sign)';
V2_NAME = 'v_2  (approach)';
clrs4 = cell2mat(cellfun(@hex2rgb_lda, CLASS_COLORS, 'UniformOutput', false)');

if ~exist('TBIN_MAX_MS','var'), TBIN_MAX_MS = []; end   % older results w/o cap

active = find(arrayfun(@(si) ~isempty(geo_results(si).X2d_peak), 1:nSystems));

%% ── Fig G: geometry at (p*,t*) — raw + (v1,v2) projection ────────────
figG = figure('Name','Geometry at (p*,t*)','Color','w', ...
    'Units','inches','Position',[1 1 numel(active)*3.2 7]);
for col = 1:numel(active)
    si = active(col);  r = geo_results(si);

    ax = subplot(2, numel(active), col); hold(ax,'on');
    hs = gobjects(4,1);
    for k = 1:4
        idx = r.labs==k;
        hs(k) = scatter(ax, r.X2d_peak(idx,1), r.X2d_peak(idx,2), 38, clrs4(k,:), ...
            'filled','MarkerFaceAlpha',0.8);
        cm = mean(r.X2d_peak(idx,:),1);
        scatter(ax, cm(1), cm(2), 120, clrs4(k,:),'d','filled', ...
            'MarkerEdgeColor','k','LineWidth',0.8,'HandleVisibility','off');
    end
    sc = max(abs([ax.XLim ax.YLim]))*0.55;
    quiver(ax,0,0,r.v2_pk(1)*sc,r.v2_pk(2)*sc,0,'k-','LineWidth',2,'MaxHeadSize',0.4,'HandleVisibility','off');
    quiver(ax,0,0,r.v1_pk(1)*sc,r.v1_pk(2)*sc,0,'k--','LineWidth',2,'MaxHeadSize',0.4,'HandleVisibility','off');
    text(ax,r.v2_pk(1)*sc*1.15,r.v2_pk(2)*sc*1.15,'v_2','FontWeight','bold','HorizontalAlignment','center');
    text(ax,r.v1_pk(1)*sc*1.15,r.v1_pk(2)*sc*1.15,'v_1','FontWeight','bold','HorizontalAlignment','center');
    xline(ax,0,'Color',[.85 .85 .85]); yline(ax,0,'Color',[.85 .85 .85]);
    xlabel(ax, pcname(sys_labels{si}, r.best_pci));
    ylabel(ax, pcname(sys_labels{si}, r.best_pcj));
    pairstr = sprintf('%s–%s', pcname(sys_labels{si},r.best_pci), pcname(sys_labels{si},r.best_pcj));
    ttl = sprintf('%s\n%s @ %.0f ms', sys_labels{si}, pairstr, r.t_star_ms);
    if isfield(r,'search_agrees') && ~r.search_agrees
        ttl = [ttl sprintf('  (search: %s)', r.search_pair)];
    end
    title(ax, ttl,'FontSize',9,'FontWeight','normal');
    axis(ax,'equal'); box(ax,'off'); ax.TickDir='out'; ax.FontSize=8;
    lim=max(abs([ax.XLim ax.YLim]))*1.15; xlim(ax,[-lim lim]); ylim(ax,[-lim lim]);
    if col==1, legend(ax,hs,CLASS_LABELS_SHORT,'Location','best','FontSize',7,'Box','off'); end
    hold(ax,'off');

    ax = subplot(2, numel(active), numel(active)+col); hold(ax,'on');
    for k = 1:4
        idx = r.labs==k;
        scatter(ax, r.p_v2_pk(idx), r.p_v1_pk(idx), 38, clrs4(k,:),'filled','MarkerFaceAlpha',0.8);
        cm = [mean(r.p_v2_pk(idx)) mean(r.p_v1_pk(idx))];
        scatter(ax, cm(1),cm(2),120,clrs4(k,:),'d','filled','MarkerEdgeColor','k','LineWidth',0.8);
    end
    xline(ax,0,'Color',[.85 .85 .85]); yline(ax,0,'Color',[.85 .85 .85]);
    text(ax,0.05,0.97,sprintf('\\theta=%.1f° [%.0f–%.0f]  acc=%.0f%%', ...
        r.theta_hat, r.theta_ci(1), r.theta_ci(2), r.acc_star*100), ...
        'Units','normalized','FontSize',8,'Color',[.25 .25 .25],'VerticalAlignment','top');
    xlabel(ax,V2_NAME); ylabel(ax,V1_NAME);
    axis(ax,'equal'); box(ax,'off'); ax.TickDir='out'; ax.FontSize=8;
    lim=max(abs([ax.XLim ax.YLim]))*1.15; xlim(ax,[-lim lim]); ylim(ax,[-lim lim]);
    hold(ax,'off');
end
sgtitle('Best-pair geometry: raw (top) and (v_1,v_2)-projected (bottom)','FontSize',11);

%% ── Fig TC: gated theta(t) over separation(t) ───────────────────────
figTC = figure('Name','theta(t) / sep(t)','Color','w','Units','inches','Position',[1 1 9 6.5]);

axTop = subplot(2,1,1); hold(axTop,'on');
yline(axTop,90,'--','Color',[.5 .5 .5],'HandleVisibility','off');
text(axTop, tvec_bs(1), 90,'90°','FontSize',8,'Color',[.5 .5 .5],'VerticalAlignment','bottom');
if ~isempty(TBIN_MAX_MS)
    xline(axTop, TBIN_MAX_MS, '-', 'Color',[.75 .3 .3],'LineWidth',1,'HandleVisibility','off');
    text(axTop, TBIN_MAX_MS, 2, 'prebounce cap','FontSize',7,'Color',[.75 .3 .3], ...
        'Rotation',90,'VerticalAlignment','bottom','HorizontalAlignment','left');
end
hT = gobjects(numel(active),1);
for col = 1:numel(active)
    si = active(col); r = geo_results(si); c = hex2rgb_lda(sys_colors{si});
    t = r.tvec_win(:);  med = r.theta_t(:,2);  lo = r.theta_t(:,1);  hi = r.theta_t(:,3);
    sepmed = r.sep_t(:,2);
    gate = SEP_GATE_FRAC * max(sepmed);
    off  = sepmed < gate;                 % gate out low-separation bins
    med(off)=NaN; lo(off)=NaN; hi(off)=NaN;
    plot(axTop, t, lo, ':','Color',c,'LineWidth',0.8,'HandleVisibility','off');
    plot(axTop, t, hi, ':','Color',c,'LineWidth',0.8,'HandleVisibility','off');
    hT(col) = plot(axTop, t, med, '-','Color',c,'LineWidth',2.4);
    % mark t*
    [~,wistar] = min(abs(t - r.t_star_ms));
    plot(axTop, r.t_star_ms, med(wistar),'o','MarkerFaceColor',c,'MarkerEdgeColor','k','MarkerSize',7,'HandleVisibility','off');
end
legend(axTop, hT, sys_labels(active),'Location','southoutside','Orientation','horizontal','FontSize',8,'Box','off');
ylabel(axTop,'\theta(t) = v_1 \angle v_2  (°)','FontSize',10);
title(axTop,'Orthogonality over time (gated to separated window; dotted = 95% CI)','FontSize',10,'FontWeight','normal');
ylim(axTop,[0 92]); box(axTop,'off'); axTop.TickDir='out'; axTop.FontSize=9; hold(axTop,'off');

axBot = subplot(2,1,2); hold(axBot,'on');
if ~isempty(TBIN_MAX_MS)
    xline(axBot, TBIN_MAX_MS, '-', 'Color',[.75 .3 .3],'LineWidth',1,'HandleVisibility','off');
end
for col = 1:numel(active)
    si = active(col); r = geo_results(si); c = hex2rgb_lda(sys_colors{si});
    t = r.tvec_win(:);
    fill(axBot,[t;flipud(t)],[r.sep_t(:,3);flipud(r.sep_t(:,1))],c, ...
        'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    plot(axBot, t, r.sep_t(:,2),'-','Color',c,'LineWidth',2.2);
end
xlabel(axBot,'Time from trial onset (ms)','FontSize',10);
ylabel(axBot,'separation index (d''-style)','FontSize',10);
title(axBot,'Four-condition separation envelope — breakout / reconvergence','FontSize',10,'FontWeight','normal');
box(axBot,'off'); axBot.TickDir='out'; axBot.FontSize=9; hold(axBot,'off');

%% ── Fig S: theta_hat ± CI vs null band, + paired Δtheta ──────────────
figS = figure('Name','theta stats','Color','w','Units','inches','Position',[1 1 11 4.2]);
axL = subplot(1,3,[1 2]); hold(axL,'on');
for si = 1:nSystems
    r = geo_results(si);
    if ~isfield(r,'theta_hat') || isnan(r.theta_hat), continue; end
    nb = r.theta_null_band;
    patch(axL, si+[-.32 .32 .32 -.32],[nb(1) nb(1) nb(3) nb(3)],[.88 .88 .88],'EdgeColor','none','HandleVisibility','off');
    plot(axL, si+[-.32 .32],[nb(2) nb(2)],'-','Color',[.6 .6 .6],'HandleVisibility','off');
    c = hex2rgb_lda(sys_colors{si});
    plot(axL,[si si], r.theta_ci,'-','Color',c,'LineWidth',2.5,'HandleVisibility','off');
    plot(axL, si, r.theta_hat,'o','MarkerFaceColor',c,'MarkerEdgeColor','k','MarkerSize',8,'HandleVisibility','off');
end
yline(axL,90,'--','Color',[.5 .5 .5],'HandleVisibility','off');
set(axL,'XTick',1:nSystems,'XTickLabel',sys_labels,'XTickLabelRotation',20);
ylabel(axL,'\theta(v_1,v_2)  (°)','FontSize',10);
xlim(axL,[0.4 nSystems+0.6]); ylim(axL,[0 92]); box(axL,'off'); axL.TickDir='out'; axL.FontSize=9;
title(axL,'\theta median ± 95% CI (colour) vs marginal-shuffle null (grey)','FontSize',10,'FontWeight','normal');
hold(axL,'off');

axR = subplot(1,3,3); hold(axR,'on'); leg = {};
if isfield(paired,'dmfc_minus_ballstate')
    histogram(axR, paired.dmfc_minus_ballstate, 40,'Normalization','pdf','FaceColor',[.42 .24 .60],'EdgeColor','none','FaceAlpha',.55);
    leg{end+1}='DMFC − Ball State';
end
if isfield(paired,'dmfc_minus_nexttp')
    histogram(axR, paired.dmfc_minus_nexttp, 40,'Normalization','pdf','FaceColor',[.18 .49 .20],'EdgeColor','none','FaceAlpha',.55);
    leg{end+1}='DMFC − nextTP RNN';
end
xline(axR,0,'-','Color',[.2 .2 .2],'LineWidth',1.2,'HandleVisibility','off');
xlabel(axR,'\Delta\theta (°)','FontSize',10); ylabel(axR,'density','FontSize',10);
if ~isempty(leg), legend(axR,leg,'Location','best','FontSize',8,'Box','off'); end
title(axR,'Paired \Delta\theta  (>0 ⇒ DMFC more orthogonal)','FontSize',9,'FontWeight','normal');
box(axR,'off'); axR.TickDir='out'; axR.FontSize=9; hold(axR,'off');

%% ── helpers ──────────────────────────────────────────────────────────
function rgb = hex2rgb_lda(hex)
    hex = strrep(hex,'#','');
    rgb = double([hex2dec(hex(1:2)) hex2dec(hex(3:4)) hex2dec(hex(5:6))])/255;
end

function s = pcname(sys_label, k)
% ballState's "PCs" are its raw coordinates (identity basis); label them so.
    if ~isempty(regexpi(sys_label,'Ball\s*State','once'))
        coords = {'x','y','ẋ','ẏ'};
        if k>=1 && k<=numel(coords), s = coords{k}; else, s = sprintf('c%d',k); end
    else
        s = sprintf('PC%d', k);
    end
end
