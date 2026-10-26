classdef prnnvars_out < matlab.System

    properties

        decoding_maps
        prnn         
        basernn 
        input_data
        board_params
        training_data
        validation_data
        rnnvars_training
        rnnvars_valididation


    end

    
    methods 
         % Constructor
        function self = prnnvars_out(varargin)

            if nargin 

                args  = reshape(varargin,2,[]);
                nargs = size(args,2);
                for i = 1:nargs   
                    field = args{1,i};
                    self.(field) = args{i,2};
                end

            end
         
        end
        

        function run_networks_all(self)

            maps = self.decoding_maps;
            test_maps = maps.decoding_map(maps.test_idx,:);


            self.rnnvars_train1 = run_rnn_trials(self.basernn, self.training_data,"parallel",true,"printStuff",false);
            self.rnnvars_valid1 = run_rnn_trials(self.basernn, self.validation_data,"parallel",true,"printStuff",false);
            self.rnnvars_valid2 = play_rnn_trials(self.validation_data,'train', self.rnnvars_train1.progrnn,'map',test_maps,"parallel",true );

        end

        function run_networks_valid1(self)


            self.rnnvars_train1 = run_rnn_trials(self.basernn, self.training_data,"parallel",true,"printStuff",false);
            self.rnnvars_valid1 = run_rnn_trials(self.basernn, self.validation_data,"parallel",true,"printStuff",false);
            

        end

        function out = get_network_outputs(self)

            out = cellfun(@(s) self.rnnvars.W*s, self.rnnvars.network_states,uniformoutput=false);

        end

        function varargout = plot_game_trial(self, idx ,  ax)

            if ~exist("ax","var"), ax = []; end
    
            ntrials = numel(idx);

            data = self.get_network_outputs();
    
            bp = self.board_params;
            ax = plotting_helper("plot_game_trial"   , data{idx(1)} , ax , bp);
    
            for i = 2:ntrials
                plotting_helper("plot_game_trial"   , data{idx(i)} , ax );
                pause
            end
    
            varargout{1} = ax;
    
        end
    
        function varargout = plot_trial_set(self,ax)
        
            if ~exist("ax","var"), ax = []; end

            data = self.get_network_outputs();
    
            bp = self.board_params;
            ax = plotting_helper("plot_trial_set"   , data , ax , bp);
    
            varargout{1} = ax;
    
        end


    end
    
    

    

end