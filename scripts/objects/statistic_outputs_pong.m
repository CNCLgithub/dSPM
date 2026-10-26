classdef statistic_outputs_pong < matlab.System

    properties

        brain_rsa
        correlation_stats
        game_stats_rand_training
        game_stats_rand_valid
        game_stats_pred_valid
       
        
    end

    
    methods 
        % Constructor
        function self = decoding_outputs_pong(varargin)

            if nargin 
                args  = reshape(varargin,2,[]);
                nargs = size(args,2);
                for i = 1:nargs
    
                    field = args{1,i};
                    self.(field) = args{i,2};              
                end
            end
            
        end
        
        function varargout = plot_correlation_fit(self, idx, ax)
       
            corstats = self.correlation_stats;
            t        = 10:1300;

            if ~exist("ax","var") || ~strcmpi(ax.Parent.Name , 'pRNN Correlation Fit')
                figure('Position',[223 158 842 929],'Name', 'pRNN Correlation Fit')
                
                ax = gca; 
                
                ylabel(ax,'Correlation')
                xlabel(ax, 'Time from Trial Start')
                title(ax, 'Final Position Prediction Correlation')

                r2 = corstats.r2;
                
                range_y  = cellfun(@(s) s(t),corstats{r2 > .7 , "ydata"},uniformoutput=false);
                range_y  = cat(2,range_y{:});

                x  = corstats.xdata{1}(t);
                nany  = nan(numel(x),1);
                hold(ax,'on')
                    plot(ax,x,   nany          ,'Tag' ,'fity')
                    plot(ax,x,   nany          ,'Tag' ,'ydata')
                    plot(ax,x,mean(range_y,2) ,'Tag' ,'avg')
                hold(ax,'off')
    
                set(ax , 'YLim',[-.3 .8])
            end

            if ~exist("idx","var")
                [~,idx] = max(corstats.r2);
                lgd = @(r2,t) {'tanh Fit','Max r^2','Avg r^2 >.7'};
            else
                lgd = @(r2,t) {'tanh Fit',['r^2 @ t_{' num2str(t) '} = ' num2str(r2)],'Avg r^2 >.7'};
            end

            hfity    = findall(ax,'-depth',1,'Tag','fity');
            hydata   = findall(ax,'-depth',1,'Tag','ydata');
    
            set(hfity,'YData' ,corstats.yfit{idx}(t));
            set(hydata,'YData',corstats.ydata{idx}(t));  

            legend(ax, lgd(corstats.r2(idx),idx),'Location','northeastoutside' )

            if nargout, varargout = {ax};end

        end


    end

  
    
    

    

end
