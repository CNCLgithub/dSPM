classdef network_outputs_pong < matlab.System

    properties

        rnn_trained   % id for network in run-batch
        rnn_untrained % id for run-batch
        board_params 
       
    end

    
    methods 
        % Constructor
        function self = network_outputs_pong(varargin)

            if nargin 
                args  = reshape(varargin,2,[]);
                nargs = size(args,2);
                for i = 1:nargs
    
                    field = args{1,i};
                    switch field
                        case {'rnn_trained', 'rnn_untrained'}
                            self.(field).data = args{i,2};
                        case 'board_params'
                            self.(field) = args{i,2};
                    end
                end
            end

            self.rnn_trained.plot_trial   = @(rnnidx,idx,ax) self.plot_game_trial(self,'trained' ,rnnidx,idx,ax);
            self.rnn_untrained.plot_trial = @(idx,ax)        self.plot_game_trial(self,'utrained',  []  ,idx,ax);
            self.rnn_trained.plot_set     = @(rnnidx,ax)     self.plot_trial_set(self, 'trained' ,rnnidx,ax);   
            self.rnn_untrained.plot_set   = @(ax)            self.plot_trial_set(self, 'utrained',  []  ,ax);
         
        end

    end

    methods (Access=private)

    function varargout = plot_game_trial(self, rnntype, rnnidx, idx ,  ax)

        switch rnntype
            case 'trained',   data = self.rnn_trained.data{rnnidx};
            case 'untrained', data = self.rnn_untrained.data;

        end

        if ~exist("ax","var"), ax = []; end

        ntrials = numel(idx);

        bp = self.board_params;
        ax = plotting_helper("plot_game_trial"   , data{idx(1)} , ax , bp);

        for i = 2:ntrials
            plotting_helper("plot_game_trial"   , data{idx(i)} , ax );
            pause
        end

        varargout{1} = ax;

    end

    function varargout = plot_trial_set(self,rnntype,rnnidx,ax)

        switch rnntype
                case 'trained',   data = self.rnn_trained.data{rnnidx};
                case 'untrained', data = self.rnn_untrained.data;

        end

        if ~exist("ax","var"), ax = []; end

        bp = self.board_params;
        ax = plotting_helper("plot_trial_set"   , data , ax , bp);

        varargout{1} = ax;

    end

    end

  
    
    

    

end

