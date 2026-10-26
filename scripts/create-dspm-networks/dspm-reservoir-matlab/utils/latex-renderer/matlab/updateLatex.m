function updateLatex(hFig, latexStrings, varargin)
% UPDATELATEX Update equations in an existing renderLatex figure
%
%   updateLatex(hFig, latexStrings) updates the equations displayed
%   in a figure created by renderLatex.
%
%   Input:
%       hFig         - Figure handle from renderLatex
%       latexStrings - New LaTeX strings to display
%
%   Optional Name-Value pairs:
%       'Title'      - New title
%       'FontSize'   - New font size
%       'ShowLabels' - Show/hide labels
%       'Theme'      - 'light' or 'dark'
%
%   Example:
%       h = renderLatex('x^2');
%       pause(1);
%       updateLatex(h, {'x^2', 'x^3', 'x^4'}, 'Title', 'Powers of x');
%
%   See also: renderLatex

    % Validate figure
    if ~isvalid(hFig) || ~isfield(hFig.UserData, 'html')
        error('updateLatex:invalidFigure', ...
            'Invalid figure handle. Use a figure created by renderLatex.');
    end
    
    % Parse optional arguments
    p = inputParser;
    addRequired(p, 'hFig');
    addRequired(p, 'latexStrings');
    addParameter(p, 'Title', []);
    addParameter(p, 'FontSize', []);
    addParameter(p, 'ShowLabels', []);
    addParameter(p, 'Theme', []);
    parse(p, hFig, latexStrings, varargin{:});
    
    opts = p.Results;
    
    % Get existing payload
    payload = hFig.UserData.payload;
    
    % Ensure cell array
    if ischar(latexStrings) || isstring(latexStrings)
        latexStrings = {char(latexStrings)};
    end
    latexStrings = cellfun(@char, latexStrings, 'UniformOutput', false);
    
    % Build new equations array
    nEqs = numel(latexStrings);
    equations = cell(nEqs, 1);
    for i = 1:nEqs
        equations{i} = struct('latex', latexStrings{i});
    end
    payload.equations = equations;
    
    % Update optional fields if provided
    if ~isempty(opts.Title)
        payload.title = opts.Title;
    end
    if ~isempty(opts.FontSize)
        payload.fontSize = opts.FontSize;
    end
    if ~isempty(opts.ShowLabels)
        payload.showLabels = opts.ShowLabels;
    end
    if ~isempty(opts.Theme)
        payload.theme = opts.Theme;
    end
    
    % Auto-compute font size if equations changed significantly
    if isempty(opts.FontSize)
        totalLines = 0;
        for i = 1:nEqs
            matches = regexp(latexStrings{i}, '\\\\(?![a-zA-Z])', 'match');
            totalLines = totalLines + numel(matches) + 1;
        end
        payload.fontSize = computeFontSize(totalLines);
    end
    
    % Send updated data
    html = hFig.UserData.html;
    html.Data = struct('action', 'render', 'payload', payload);
    
    % Store updated payload
    hFig.UserData.payload = payload;
end

function fontSize = computeFontSize(totalLines)
    if totalLines == 1
        fontSize = 28;
    elseif totalLines <= 3
        fontSize = 24;
    elseif totalLines <= 6
        fontSize = 20;
    elseif totalLines <= 10
        fontSize = 18;
    elseif totalLines <= 15
        fontSize = 16;
    else
        fontSize = max(14, round(24 - totalLines * 0.5));
    end
end
