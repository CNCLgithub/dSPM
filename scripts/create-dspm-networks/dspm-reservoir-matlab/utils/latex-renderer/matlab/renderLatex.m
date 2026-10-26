function hFig = renderLatex(latexStrings, varargin)
% RENDERLATEX Render LaTeX equations in a uifigure using KaTeX
%
%   hFig = renderLatex(latexStrings) renders one or more LaTeX strings
%   as beautifully formatted equations in a new uifigure.
%
%   Input:
%       latexStrings - char array, string, or cell array of LaTeX strings
%                      Multi-line equations can use '\\' as line breaks
%
%   Optional Name-Value pairs:
%       'Title'      - Figure/equation title (supports LaTeX)
%       'FontSize'   - Font size in pixels (default: auto-computed)
%       'ShowLabels' - Show equation numbers (default: auto)
%       'Theme'      - 'light', 'dark', or 'auto' (default: 'light')
%       'Position'   - Figure position [x y width height]
%       'Name'       - Figure window name
%       'HorizontalAlignment' - Equation alignment:
%                      Scalar: 'left', 'center', or 'right' (applies to all)
%                      Cell array: {'left','center',...} per-equation alignment
%                      (must match number of equations, otherwise defaults to 'left')
%
%   Output:
%       hFig - Handle to the created uifigure
%
%   Examples:
%       % Single equation (centered)
%       renderLatex('E = mc^2');
%
%       % Multiple equations
%       eqs = {
%           '\nabla \cdot \mathbf{E} = \frac{\rho}{\epsilon_0}'
%           '\nabla \times \mathbf{B} = \mu_0 \mathbf{J}'
%       };
%       renderLatex(eqs, 'Title', 'Maxwell''s Equations');
%
%       % Per-equation alignment
%       renderLatex(eqs, 'HorizontalAlignment', {'left', 'center'});
%
%       % Multi-line equation using \\
%       renderLatex(['a^2 + b^2 = c^2 \\' ...
%                    'a = \sqrt{c^2 - b^2}']);
%
%   See also: uifigure, uihtml

    % Parse inputs
    p = inputParser;
    addRequired(p, 'latexStrings');
    addParameter(p, 'Title', '');
    addParameter(p, 'FontSize', []);
    addParameter(p, 'ShowLabels', []);
    addParameter(p, 'Theme', 'light');
    addParameter(p, 'Position', []);
    addParameter(p, 'Name', 'LaTeX Equations');
    addParameter(p, 'HorizontalAlignment', 'left', @validateAlignment);
    parse(p, latexStrings, varargin{:});
    
    opts = p.Results;
    
    % Ensure cell array of strings
    if ischar(latexStrings) || isstring(latexStrings)
        latexStrings = {char(latexStrings)};
    end
    latexStrings = cellfun(@char, latexStrings, 'UniformOutput', false);
    
    nEqs = numel(latexStrings);
    
    % Process horizontal alignment
    alignments = processAlignments(opts.HorizontalAlignment, nEqs);
    
    % Count total lines for auto-sizing
    totalLines = countTotalLines(latexStrings);
    
    % Auto-compute font size if not specified
    if isempty(opts.FontSize)
        fontSize = computeFontSize(totalLines);
    else
        fontSize = opts.FontSize;
    end
    
    % Auto-determine label visibility
    if isempty(opts.ShowLabels)
        showLabels = nEqs > 1;
    else
        showLabels = opts.ShowLabels;
    end
    
    % Compute figure size
    hasTitle = ~isempty(opts.Title);
    if isempty(opts.Position)
        figPos = computeFigurePosition(totalLines, nEqs, fontSize, hasTitle);
    else
        figPos = opts.Position;
    end
    
    % Create uifigure
    hFig = uifigure('Name', opts.Name, ...
                    'Position', figPos, ...
                    'Resize', 'on', ...
                    'AutoResizeChildren', 'off');
    
    % Create uihtml component
    html = uihtml(hFig, 'Position', [0 0 figPos(3) figPos(4)]);
    
    % Get path to dist folder (relative to this function)
    thisDir = fileparts(mfilename('fullpath'));
    indexPath = fullfile(thisDir, '..', 'dist', 'index.html');
    
    if ~exist(indexPath, 'file')
        % Fallback: show build instructions
        html.HTMLSource = buildFallbackHTML(latexStrings, opts.Title);
        warning('renderLatex:notBuilt', ...
            ['Built assets not found. Run: cd frontend && npm install && npm run build\n' ...
             'Using fallback renderer (limited functionality).']);
    else
        % Load the built React app
        html.HTMLSource = indexPath;
    end
    
    % Build equation data for JavaScript
    equations = cell(nEqs, 1);
    for i = 1:nEqs
        equations{i} = struct('latex', latexStrings{i});
    end
    
    % Send data to JavaScript
    payload = struct(...
        'equations', {equations}, ...
        'title', opts.Title, ...
        'fontSize', fontSize, ...
        'showLabels', showLabels, ...
        'theme', opts.Theme, ...
        'displayMode', true, ...
        'horizontalAlignment', {alignments} ...
    );
    
    % Store data in figure for later updates
    hFig.UserData.html = html;
    hFig.UserData.payload = payload;
    
    % Allow HTML to fully load before sending data
    drawnow;
    pause(0.1);
    
    % Send initial data
    html.Data = struct('action', 'render', 'payload', payload);
    
    % Handle figure resize
    hFig.SizeChangedFcn = @(~,~) resizeHandler(hFig, html);
end

function isValid = validateAlignment(x)
    % Validate HorizontalAlignment input
    validOptions = {'left', 'center', 'right'};
    if ischar(x) || (isstring(x) && isscalar(x))
        isValid = ismember(char(x), validOptions);
    elseif iscell(x) || isstring(x)
        % Cell array or string array - check each element
        x = cellstr(x);
        isValid = all(cellfun(@(s) ismember(s, validOptions), x));
    else
        isValid = false;
    end
end

function alignments = processAlignments(alignInput, nEqs)
    % Process alignment input into a cell array of alignments
    % Returns a cell array with one alignment per equation
    
    if ischar(alignInput) || (isstring(alignInput) && isscalar(alignInput))
        % Scalar alignment - apply to all equations
        alignments = repmat({char(alignInput)}, 1, nEqs);
    else
        % Array of alignments
        alignInput = cellstr(alignInput);
        if numel(alignInput) == nEqs
            alignments = alignInput(:)';  % Row cell array
        else
            % Mismatch - warn and default to 'left'
            warning('renderLatex:alignmentMismatch', ...
                'HorizontalAlignment array length (%d) does not match number of equations (%d). Defaulting to ''left''.', ...
                numel(alignInput), nEqs);
            alignments = repmat({'left'}, 1, nEqs);
        end
    end
end

function resizeHandler(fig, html)
    pos = fig.Position;
    html.Position = [0 0 pos(3) pos(4)];
end

function totalLines = countTotalLines(latexStrings)
    % Count total visual lines across all equations
    % Only counts \\ outside of \begin{...}\end{...} environments
    totalLines = 0;
    for i = 1:numel(latexStrings)
        str = latexStrings{i};
        totalLines = totalLines + countLinesInEquation(str);
    end
end

function nLines = countLinesInEquation(str)
    % Count line breaks (\\) that are outside environments
    nLines = 1;
    envDepth = 0;
    idx = 1;
    n = length(str);
    
    while idx <= n
        % Check for \begin{
        if idx + 6 <= n && strcmp(str(idx:idx+6), '\begin{')
            envDepth = envDepth + 1;
            % Skip to closing brace
            braceEnd = strfind(str(idx+7:end), '}');
            if ~isempty(braceEnd)
                idx = idx + 6 + braceEnd(1);
                continue;
            end
        end
        
        % Check for \end{
        if idx + 4 <= n && strcmp(str(idx:idx+4), '\end{')
            envDepth = max(0, envDepth - 1);
            % Skip to closing brace
            braceEnd = strfind(str(idx+5:end), '}');
            if ~isempty(braceEnd)
                idx = idx + 4 + braceEnd(1);
                continue;
            end
        end
        
        % Check for \\ (only count if not inside environment)
        if envDepth == 0 && idx + 1 <= n && strcmp(str(idx:idx+1), '\\')
            % Make sure it's not followed by a letter
            if idx + 2 > n || ~isletter(str(idx+2))
                nLines = nLines + 1;
                idx = idx + 2;
                continue;
            end
        end
        
        idx = idx + 1;
    end
end

function fontSize = computeFontSize(totalLines)
    % Compute font size based on total lines
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

function pos = computeFigurePosition(totalLines, nEqs, fontSize, hasTitle)
    % Compute figure position [x y width height] based on content
    screenSize = get(0, 'ScreenSize');
    maxHeight = screenSize(4) * 0.85;  % Max 85% of screen height
    maxWidth = screenSize(3) * 0.7;    % Max 70% of screen width
    
    % KaTeX display math with line-height: 2.5 needs about 3.2x font size per line
    lineHeightPx = fontSize * 3.2;
    
    % Each equation ROW has CSS padding: 0.75rem top + 0.75rem bottom + border
    % That's approximately 28px per row
    rowPaddingPx = 28;
    
    % Calculate content height
    titleHeight = hasTitle * (fontSize * 2.5 + 30);  % Title + margin-bottom
    equationContentHeight = totalLines * lineHeightPx;
    totalRowPadding = nEqs * rowPaddingPx;
    containerPadding = 48;  % Container padding (1.5rem * 2 = ~48px)
    
    contentHeight = titleHeight + equationContentHeight + totalRowPadding + containerPadding;
    
    % Calculate width based on expected equation length
    baseWidth = 600;
    if totalLines > nEqs
        % Has multi-line equations, need more width
        baseWidth = 800;
    end
    if totalLines > 10
        baseWidth = 900;
    end
    
    % Apply bounds
    height = min(maxHeight, max(250, contentHeight));
    width = min(maxWidth, max(400, baseWidth));
    
    % Center on screen
    x = max(50, (screenSize(3) - width) / 2);
    y = max(50, (screenSize(4) - height) / 2);
    
    pos = [x y width height];
end

function htmlStr = buildFallbackHTML(latexStrings, titleStr)
    % Build a simple fallback HTML using KaTeX CDN
    % This works without the built React app
    
    eqHTML = '';
    for i = 1:numel(latexStrings)
        latex = strrep(latexStrings{i}, '\', '\\');
        latex = strrep(latex, '''', '\\''');
        latex = strrep(latex, newline, ' ');
        
        if numel(latexStrings) > 1
            label = sprintf('<span class="eq-label">(%d)</span>', i);
        else
            label = '';
        end
        
        eqHTML = [eqHTML, sprintf(...
            '<div class="eq-row">%s<span class="eq-content" data-latex="%s"></span></div>\n', ...
            label, latex)]; %#ok<AGROW>
    end
    
    if ~isempty(titleStr)
        titleHTML = sprintf('<div class="eq-title">%s</div>', titleStr);
    else
        titleHTML = '';
    end
    
    htmlStr = sprintf([...
        '<!DOCTYPE html>\n' ...
        '<html><head>\n' ...
        '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">\n' ...
        '<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>\n' ...
        '<style>\n' ...
        'body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; }\n' ...
        '.eq-title { font-size: 1.5em; font-weight: 600; text-align: center; margin-bottom: 20px; }\n' ...
        '.eq-row { display: flex; align-items: baseline; padding: 10px 0; gap: 15px; }\n' ...
        '.eq-label { color: #64748b; min-width: 40px; text-align: right; }\n' ...
        '.eq-content { font-size: 1.3em; }\n' ...
        '</style>\n' ...
        '</head><body>\n' ...
        '%s\n' ...
        '<div class="eq-container">%s</div>\n' ...
        '<script>\n' ...
        'document.querySelectorAll(".eq-content").forEach(el => {\n' ...
        '  const latex = el.dataset.latex.replace(/\\\\\\\\(?![a-zA-Z])/g, "\\\\\\\\\\n");\n' ...
        '  const lines = latex.split("\\\\\\\\\\n");\n' ...
        '  el.innerHTML = lines.map(l => {\n' ...
        '    try { return katex.renderToString(l.trim(), {throwOnError:false,displayMode:true}); }\n' ...
        '    catch(e) { return "<span style=color:red>Error</span>"; }\n' ...
        '  }).join("<br>");\n' ...
        '});\n' ...
        '</script>\n' ...
        '</body></html>'], titleHTML, eqHTML);
end
