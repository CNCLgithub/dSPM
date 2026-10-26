function tf = hasSymbolicToolbox(~)
    % HASSYMBOLICTOOLBOX  Check if Symbolic Math Toolbox is available
    tf = license('test', 'Symbolic_Toolbox') && ...
         ~isempty(ver('symbolic'));
end
