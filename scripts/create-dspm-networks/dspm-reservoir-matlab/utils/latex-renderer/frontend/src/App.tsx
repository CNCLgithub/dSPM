import React, { useState, useEffect, useCallback, useMemo } from 'react';
import katex from 'katex';

// Types for equation data from MATLAB
interface EquationData {
  latex: string;
  label?: string;
}

interface RenderConfig {
  equations: EquationData[];
  title?: string;
  fontSize?: number;
  showLabels?: boolean;
  theme?: 'light' | 'dark' | 'auto';
  displayMode?: boolean;
  horizontalAlignment?: ('left' | 'center' | 'right')[];
}

// MATLAB uihtml component interface
interface HTMLComponent {
  Data: { action: string; payload: RenderConfig } | null;
  addEventListener: (event: string, callback: () => void) => void;
}

// Extend window for MATLAB bridge
declare global {
  interface Window {
    __MATLAB_DATA__: { action: string; payload: RenderConfig } | null;
    __MATLAB_COMPONENT__: HTMLComponent | null;
    __REACT_READY__: boolean;
  }
}

// Parse multi-line equations (split on \\ but not inside environments)
function splitEquationLines(latex: string): string[] {
  // We need to split on \\ but NOT when inside \begin{...}\end{...} environments
  const result: string[] = [];
  let current = '';
  let envDepth = 0;
  let i = 0;
  
  while (i < latex.length) {
    // Check for \begin{
    if (latex.slice(i, i + 7) === '\\begin{') {
      envDepth++;
      const endBrace = latex.indexOf('}', i + 7);
      if (endBrace !== -1) {
        current += latex.slice(i, endBrace + 1);
        i = endBrace + 1;
        continue;
      }
    }
    
    // Check for \end{
    if (latex.slice(i, i + 5) === '\\end{') {
      envDepth = Math.max(0, envDepth - 1);
      const endBrace = latex.indexOf('}', i + 5);
      if (endBrace !== -1) {
        current += latex.slice(i, endBrace + 1);
        i = endBrace + 1;
        continue;
      }
    }
    
    // Check for \\ line break (only split if not inside an environment)
    if (envDepth === 0 && latex[i] === '\\' && latex[i + 1] === '\\') {
      // Make sure it's not followed by a letter (like \\alpha)
      const nextChar = latex[i + 2];
      if (!nextChar || !/[a-zA-Z]/.test(nextChar)) {
        // This is a line break - save current and start new
        const trimmed = current.trim();
        if (trimmed) {
          result.push(trimmed);
        }
        current = '';
        i += 2;
        continue;
      }
    }
    
    current += latex[i];
    i++;
  }
  
  // Add final segment
  const trimmed = current.trim();
  if (trimmed) {
    result.push(trimmed);
  }
  
  return result.length > 0 ? result : [''];
}

// Ensure $ delimiters for KaTeX
function ensureDelimiters(latex: string): string {
  const trimmed = latex.trim();
  if (!trimmed) return '';
  
  const hasStart = trimmed.startsWith('$') || trimmed.startsWith('$$');
  const hasEnd = trimmed.endsWith('$') || trimmed.endsWith('$$');
  
  if (hasStart && hasEnd) {
    // Strip delimiters - we'll use displayMode instead
    return trimmed.replace(/^\$+|\$+$/g, '');
  }
  return trimmed;
}

// Render a single line of LaTeX
function renderLatexLine(latex: string, displayMode: boolean): string {
  try {
    const prepared = ensureDelimiters(latex);
    if (!prepared) return '';
    
    return katex.renderToString(prepared, {
      throwOnError: false,
      displayMode,
      output: 'html',
    });
  } catch {
    return `<span class="equation-error">Parse error</span>`;
  }
}

// Single equation component
const Equation: React.FC<{
  data: EquationData;
  index: number;
  showLabel: boolean;
  displayMode: boolean;
  isSingle: boolean;
  alignment: 'left' | 'center' | 'right';
}> = ({ data, index, showLabel, displayMode, isSingle, alignment }) => {
  const lines = useMemo(() => splitEquationLines(data.latex), [data.latex]);
  const isMultiLine = lines.length > 1;

  const renderedLines = useMemo(() => {
    return lines.map(line => ({
      __html: renderLatexLine(line, displayMode),
    }));
  }, [lines, displayMode]);

  const label = data.label ?? `(${index + 1})`;

  // Compute alignment class
  const alignClass = alignment === 'center' ? 'align-center' : 
                     alignment === 'right' ? 'align-right' : '';

  return (
    <div className={`equation-row ${isSingle ? 'single' : ''} ${alignClass}`}>
      {showLabel && !isSingle && (
        <span className="equation-label">{label}</span>
      )}
      <div className={`equation-content ${isMultiLine ? 'equation-block' : ''}`}>
        {renderedLines.map((html, i) => (
          <span
            key={i}
            className={isMultiLine ? 'equation-line' : undefined}
            dangerouslySetInnerHTML={html}
          />
        ))}
      </div>
    </div>
  );
};

// Title component with optional LaTeX
const Title: React.FC<{ title: string }> = ({ title }) => {
  const rendered = useMemo(() => {
    // Check if title contains LaTeX (has $ or \)
    if (title.includes('$') || title.includes('\\')) {
      try {
        const latex = ensureDelimiters(title);
        return {
          __html: katex.renderToString(latex, {
            throwOnError: false,
            displayMode: false,
            output: 'html',
          }),
        };
      } catch {
        return { __html: title };
      }
    }
    return { __html: title };
  }, [title]);

  return <div className="equation-title" dangerouslySetInnerHTML={rendered} />;
};

// Main App component
export const App: React.FC = () => {
  const [config, setConfig] = useState<RenderConfig>({
    equations: [],
    showLabels: true,
    theme: 'light',
    displayMode: true,
    horizontalAlignment: ['left'],
  });

  // Handle data from MATLAB
  const handleMatlabData = useCallback((data: { action: string; payload: RenderConfig } | null) => {
    if (data?.action === 'render' && data.payload) {
      setConfig(prev => ({
        ...prev,
        ...data.payload,
      }));
    }
  }, []);

  // Set up MATLAB bridge
  useEffect(() => {
    // Signal that React is ready
    window.__REACT_READY__ = true;
    
    // Check for initial data (MATLAB may have set this before React mounted)
    if (window.__MATLAB_DATA__) {
      handleMatlabData(window.__MATLAB_DATA__);
    }
    
    // Listen for data changes via custom event
    const handleDataChanged = (event: CustomEvent) => {
      handleMatlabData(event.detail);
    };
    
    window.addEventListener('matlabDataChanged', handleDataChanged as EventListener);

    return () => {
      window.removeEventListener('matlabDataChanged', handleDataChanged as EventListener);
    };
  }, [handleMatlabData]);

  // Apply theme
  useEffect(() => {
    const root = document.documentElement;
    if (config.theme === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
  }, [config.theme]);

  // Apply font size
  useEffect(() => {
    if (config.fontSize) {
      document.documentElement.style.setProperty(
        '--eq-font-size',
        `${config.fontSize}px`
      );
    }
  }, [config.fontSize]);

  const { equations, title, showLabels, displayMode, horizontalAlignment } = config;
  const isSingle = equations.length === 1 && 
                   splitEquationLines(equations[0]?.latex ?? '').length === 1;
  const shouldShowLabels = showLabels ?? equations.length > 1;
  
  // Helper to get alignment for a specific equation index
  const getAlignment = (index: number): 'left' | 'center' | 'right' => {
    if (!horizontalAlignment || horizontalAlignment.length === 0) return 'left';
    // If array has values, use index (with fallback to first or 'left')
    return horizontalAlignment[index] ?? horizontalAlignment[0] ?? 'left';
  };

  // Empty state
  if (equations.length === 0) {
    return (
      <div className="equation-container centered">
        <span className="text-slate-400">No equations to display</span>
      </div>
    );
  }

  return (
    <div className={`equation-container ${isSingle ? 'centered' : ''}`}>
      {title && <Title title={title} />}
      {equations.map((eq, i) => (
        <Equation
          key={i}
          data={eq}
          index={i}
          showLabel={shouldShowLabels}
          displayMode={displayMode ?? true}
          isSingle={isSingle}
          alignment={getAlignment(i)}
        />
      ))}
    </div>
  );
};
