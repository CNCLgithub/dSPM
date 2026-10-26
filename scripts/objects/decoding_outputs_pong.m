classdef decoding_outputs_pong < matlab.System

    properties

        avg_train_error       
        avg_valid_error       
        avg_valid_correlation 
        avg_valid_cor_mse_sum 
        t_decode              
        t_validation          
        best_map              
        best_map_index        
       
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
        
        function varargout = plot_stuff(self, ax)
       
            if ~exist("ax","var"), ax = []; end

            ax = plotting_helper("plot_mapping_data" , self , ax);

            if nargout, varargout{1} = ax; end

        end


    end

  
    
    

    

end
