function programming_gui(obj)
    % PROGRAMMING_GUI  Launch the GUI to program this reservoir
    %
    % USAGE:
    %   res.programming_gui()        % Opens GUI with reservoir pre-loaded
    %   fig = res.programming_gui()  % Also returns figure handle
    %
    % The GUI provides a visual interface for:
    %   - Defining dynamics using LaTeX equations
    %   - Managing constants and parameters  
    %   - Loading/saving network configurations
    %   - Compiling programs without symbolic toolbox
    %
    % See also: program, compile
    
    % Ensure GUI path is accessible
    guiPath    = obj.prog_gui_path;
    matlabPath = fullfile(guiPath, 'matlab');
    
    if ~exist(matlabPath, 'dir')
        error('dspm_reservoir:guiNotFound', ...
            ['GUI not found at expected location:\n  %s\n\n' ...
             'The reservoir-gui/ folder should be at ../reservoir-gui/ relative to dspm_reservoir.m'], ...
            guiPath);
    end
    
    % Add GUI matlab folder to path if not already
    if ~contains(path, matlabPath)
        addpath(matlabPath);
        if obj.verbose
            fprintf('Added to path: %s\n', matlabPath);
        end
    end
    
    % Launch the GUI with this reservoir
    addpath(genpath(guiPath))
    reservoir_programming_gui(obj);

end
