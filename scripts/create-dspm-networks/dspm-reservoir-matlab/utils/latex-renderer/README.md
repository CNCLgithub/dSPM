# LaTeX Equation Renderer for MATLAB

Beautiful LaTeX equation rendering in MATLAB using `uifigure` + `uihtml` + KaTeX.

## Features

- 🎨 Beautiful typography with KaTeX
- 📐 Auto-scaling font size based on content
- 🌓 Light and dark themes
- 📝 Multi-line equations with `\\` 
- 🔢 Automatic equation numbering
- 🔄 Dynamic updates without recreating figures

## Quick Start

### 1. Build the Frontend

```bash
cd frontend
npm install
npm run build
```

This creates the `dist/` folder with bundled assets.

### 2. Add to MATLAB Path

```matlab
addpath('/path/to/latex-renderer/matlab');
```

### 3. Render Equations

```matlab
% Single equation (auto-centered)
renderLatex('E = mc^2');

% Multiple equations
eqs = {
    '\nabla \cdot \mathbf{E} = \frac{\rho}{\epsilon_0}'
    '\nabla \cdot \mathbf{B} = 0'
    '\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}'
    '\nabla \times \mathbf{B} = \mu_0 \mathbf{J} + \mu_0 \epsilon_0 \frac{\partial \mathbf{E}}{\partial t}'
};
renderLatex(eqs, 'Title', 'Maxwell''s Equations');

% Multi-line equation block
renderLatex(['(+1)(+i)(+i) = (+1)(+j)(+j) = (+1)(+k)(+k) \\' ...
             '(+1)(+i)(+j) = (+k) = (-1)(+j)(+i) \\' ...
             '(+1)(+j)(+k) = (+i) = (-1)(+k)(+j)'], ...
            'Title', 'Quaternion Multiplication');
```

## API Reference

### `renderLatex(latexStrings, Name, Value)`

Render LaTeX equations in a new figure.

**Required:**
- `latexStrings` - String, char, or cell array of LaTeX equations

**Optional Name-Value Pairs:**
- `'Title'` - Title string (supports LaTeX)
- `'FontSize'` - Font size in pixels (default: auto)
- `'ShowLabels'` - Show equation numbers (default: auto)
- `'Theme'` - `'light'`, `'dark'`, or `'auto'`
- `'Position'` - Figure position `[x y width height]`
- `'Name'` - Window title
- `'HorizontalAlignment'` - Equation alignment (see below)

**Returns:**
- `hFig` - Handle to the uifigure

### `updateLatex(hFig, latexStrings, Name, Value)`

Update equations in an existing figure.

```matlab
h = renderLatex('x^2');
pause(1);
updateLatex(h, {'x^2', 'x^3', 'x^4'}, 'Title', 'Powers');
```

## LaTeX Tips

### Supported Commands

KaTeX supports most common LaTeX math commands:

```matlab
% Greek letters
'\alpha, \beta, \gamma, \Gamma, \Delta'

% Fractions
'\frac{a}{b}'

% Subscripts and superscripts  
'x_1, x^2, x_1^2, x_{12}'

% Vectors and matrices
'\mathbf{v}, \vec{v}, \begin{pmatrix} a \\ b \end{pmatrix}'

% Operators
'\nabla, \partial, \sum, \int, \prod'

% Decorations
'\dot{x}, \ddot{x}, \hat{x}, \bar{x}, \tilde{x}'
```

### Multi-line Equations

Use `\\` to create line breaks within a single equation block:

```matlab
renderLatex(['a = b + c \\' ...
             'b = d + e \\' ...
             'c = f + g']);
```

### Dollar Signs

Dollar signs are optional - the renderer handles both:

```matlab
renderLatex('E = mc^2');       % Works
renderLatex('$E = mc^2$');     % Also works
```

## Customization

### Themes

```matlab
renderLatex(eqs, 'Theme', 'dark');   % Dark mode
renderLatex(eqs, 'Theme', 'light');  % Light mode (default)
```

### Font Size

```matlab
% Auto-sizing (default)
renderLatex(manyEquations);  % Smaller font for many equations

% Manual override
renderLatex(eqs, 'FontSize', 24);
```

### Labels

```matlab
renderLatex(eqs, 'ShowLabels', true);   % Show (1), (2), ...
renderLatex(eqs, 'ShowLabels', false);  % Hide labels
```

### Alignment

Global alignment applies to all equations:

```matlab
renderLatex(eqs, 'HorizontalAlignment', 'left');    % Left-aligned (default)
renderLatex(eqs, 'HorizontalAlignment', 'center');  % Centered
renderLatex(eqs, 'HorizontalAlignment', 'right');   % Right-aligned
```

Per-equation alignment allows different alignments for each equation:

```matlab
eqs = {
    '\nabla \cdot \mathbf{E} = \frac{\rho}{\epsilon_0}'   % Will be left
    '\nabla \cdot \mathbf{B} = 0'                          % Will be centered
    'i\hbar\frac{\partial}{\partial t}\Psi = \hat{H}\Psi' % Will be right
};
renderLatex(eqs, 'HorizontalAlignment', {'left', 'center', 'right'});
```

If the alignment array length doesn't match the number of equations, it defaults to `'left'` for all.

## Development

### Project Structure

```
latex-renderer/
├── frontend/           # React + TypeScript + KaTeX
│   ├── src/
│   │   ├── App.tsx    # Main React component
│   │   ├── main.tsx   # Entry point
│   │   └── index.css  # Styles
│   ├── package.json
│   └── vite.config.ts
├── dist/               # Built assets (created by npm run build)
├── matlab/
│   ├── renderLatex.m  # Main MATLAB function
│   └── updateLatex.m  # Update helper
└── README.md
```

### Building

```bash
cd frontend
npm install        # Install dependencies
npm run dev        # Development server (for testing)
npm run build      # Production build → ../dist/
```

### Fallback Mode

If the `dist/` folder doesn't exist, `renderLatex` falls back to using KaTeX from CDN. This works but doesn't include the full styling. Build the frontend for the best experience.

## Requirements

- MATLAB R2019b or later (for `uifigure` and `uihtml`)
- Node.js 18+ (for building frontend)

## License

MIT
