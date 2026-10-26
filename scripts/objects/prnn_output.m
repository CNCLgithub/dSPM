classdef prnn_output < matlab.System

    properties

        netid % id for network in run-batch
        runid % id for run-batch
        rnnvars_training    % pre-decoding
        rnnvars_validation % pre-decoding
        % validation_rnn2 % post-decoding (game_play)
        decoding_maps
        board_params
        brain_rsa
        game_stats
        correlation_stats
        spectral_radius
        
       
    end

    
    methods 
        % Constructor
        function obj = prnn_output()
            
        end
        

        function varargout = plot_game_trial(self, idx , ax)

            if ~exist("ax","var"),ax = self.figure_setup();end
            self.plot_game(ax,idx);

            varargout{1} = ax;

        end

        function varargout = plot_trial_set(self)

            if ~exist("ax","var"),ax = self.figure_setup();end
            self.plot_set(ax);
            varargout{1} = ax;

        end

    end

    methods (Access=private)

        function ax = figure_setup(self)
        
            figure('Position',[570 328 892 748],'Name',"pRNN Pong");
            ax = gca;hold(ax,'on')

            xo    = self.board_params.buffer;
            yw    = self.board_params.y_width;
            xw    = self.board_params.x_width;
            ud.pxy   = self.board_params.paddle_fix_value;

            ud.paddle_var_index = self.board_params.paddle_var_index;
            ud.paddle_var_lims  = self.board_params.paddle_var_limits;

            % ps  = self.board_params.sensativity;
            
            wallx = self.board_params.plot_wall_x;
            wally = self.board_params.plot_wall_y;
            
            ud.outputs = self.network_outputs();
            
            switch self.board_params.paddle_pos
                case {'left' 'right'}
                    pfuncx = @(b,pxy) b(13,:);
                    pfuncy = @(b,pxy) repmat(pxy,size(b,2),1);
                case {'top' 'bottom'}
                    pfuncx = @(b,pxy) repmat(pxy,size(b,2),1); 
                    pfuncy = @(b,pxy) b(13,:);        
            end

            ud.pfuncx = pfuncx;
            ud.pfuncy = pfuncy;
             
            ballsz = 30;  

            % Plot Wall
            plot(ax, wallx, wally,'k-', 'linewidth',4,...
                 'clipping',0);

            % Ball        
            scatter(ax, nan, nan, ballsz, 'filled','MarkerFaceAlpha',.3,'Tag','ball'); 
            scatter(ax, nan, nan, ballsz, 'k', 'filled','Tag','ball_t0',...
                'MarkerFaceAlpha',0.3,'MarkerEdgeColor','r','LineWidth',2);
                     
            % Paddle
            scatter(ax, nan ,nan , ballsz, "square",'filled','Tag','paddle');
            
            set(ax, 'UserData',ud, 'Visible' , false,...
                'XLim' , [-1 1]*(yw+xo) , 'YLim' , [-1 1]*(xw+xo)  )           
            hold(ax,'off')

            ax.UserData = ud;


        end

        function plot_game(~,ax,idx)

            ud     = ax.UserData; 

            b      = ud.outputs{idx};         
            fnidx  = size(b,2);    

            x      = b(3,1:fnidx);
            y      = b(4,1:fnidx);
            py     = ud.pfuncx(b,ud.pxy);
            px     = ud.pfuncy(b,ud.pxy);
            nx     = numel(x);

            spacer = (randn(nx,1)*0.001);
            switch ud.paddle_var_index
                case 3,py = py + spacer;
                case 4,px = px + spacer;
            end
                 
            pdlc   = parula(numel(px));
                                   
            ball   = findall(ax,'-depth',1,'Tag','ball');
            ball0  = findall(ax,'-depth',1,'Tag','ball_t0');
            paddle = findall(ax,'-depth',1,'Tag','paddle');

            set(ball  , 'xdata',x,'ydata',y,'cdata',pdlc)
            set(ball0 , 'xdata',x(1),'ydata',y(1),'cdata',pdlc(1,:))
            set(paddle, 'xdata',px,'ydata',py,'cdata',pdlc)



        end

        function plot_set(~,ax)

            ud = ax.UserData; 

            outputs = ud.outputs;
            ntrials = numel(outputs);

            ball   = findall(ax,'-depth',1,'Tag','ball');
            ball0  = findall(ax,'-depth',1,'Tag','ball_t0');

            ballc  = turbo(ntrials);

            for i = 1:ntrials

                b      = ud.outputs{i};         
                fnidx  = size(b,2);    
    
                x      = b(3,1:fnidx);
                y      = b(4,1:fnidx);
                nx     = numel(x);                      
                                       
                grey   = [linspace(255, 100, nx)', linspace(255, 100, nx)', linspace(255, 10, nx)'];
                clr    = (ballc(i,:).*grey)/255;

                bcopy  = copyobj(ball ,ax);
                b0copy = copyobj(ball0,ax);
                
                set(b0copy , 'xdata',x(1),'ydata',y(1),'cdata',clr(1,:))
                set(bcopy , 'xdata',x,'ydata',y,'cdata',clr)
            
            end

            paddle = findall(ax,'-depth',1,'Tag','paddle');
            if strcmp(get(paddle,'type'),"scatter")
                delete(paddle);
                paddle = patch(ax , 'XData' , nan , 'YData' , nan,...
                    'FaceColor','k','FaceAlpha',0.2,'Tag','paddle');
            end
            
            fix  = ones(1,4)*ud.pxy + [-1 1 1 -1]*.002;
            vari = [-1 -1 1 1]*ud.pxy;
            switch ud.paddle_var_index
                case 3, px = vari; py =  fix;
                case 4, px =  fix; py = vari;          
            end

            set(paddle, 'xdata',px,'ydata',py)


        end


    end
    
    

    

end