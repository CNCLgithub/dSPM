// Utilities for parsing and validating LaTeX equations

/**
 * Basic validation of LaTeX equation syntax
 * Returns { valid: true } or { valid: false, error: string }
 */
export function validateLatex(latex: string): { valid: boolean; error?: string } {
  if (!latex || latex.trim() === '') {
    return { valid: false, error: 'Equation cannot be empty' };
  }

  // Check for balanced braces
  let braceCount = 0;
  for (const char of latex) {
    if (char === '{') braceCount++;
    if (char === '}') braceCount--;
    if (braceCount < 0) {
      return { valid: false, error: 'Unbalanced braces: extra closing brace' };
    }
  }
  if (braceCount !== 0) {
    return { valid: false, error: 'Unbalanced braces: missing closing brace' };
  }

  // Check for balanced parentheses
  let parenCount = 0;
  for (const char of latex) {
    if (char === '(') parenCount++;
    if (char === ')') parenCount--;
    if (parenCount < 0) {
      return { valid: false, error: 'Unbalanced parentheses' };
    }
  }
  if (parenCount !== 0) {
    return { valid: false, error: 'Unbalanced parentheses' };
  }

  return { valid: true };
}

/**
 * Extract variable references from a LaTeX equation
 * e.g., "x_1 + x_2^2" → ['x_1', 'x_2']
 */
export function extractVariables(latex: string): string[] {
  const matches = latex.match(/x_\{?\d+\}?/g) || [];
  const unique = [...new Set(matches.map(m => m.replace(/[{}]/g, '')))];
  return unique.sort((a, b) => {
    const numA = parseInt(a.replace('x_', ''));
    const numB = parseInt(b.replace('x_', ''));
    return numA - numB;
  });
}

/**
 * Extract parameter references from a LaTeX equation
 * e.g., "\\sigma x_1 + \\beta x_2" → ['\\sigma', '\\beta']
 */
export function extractParameters(latex: string): string[] {
  const greekLetters = latex.match(/\\[a-zA-Z]+/g) || [];
  // Filter out LaTeX commands that aren't parameters
  const commands = ['frac', 'sqrt', 'cdot', 'times', 'left', 'right', 'dot', 'ddot'];
  const params = greekLetters.filter(p => !commands.includes(p.slice(1)));
  return [...new Set(params)];
}

/**
 * Convert user-friendly LaTeX to display LaTeX
 * Adds proper formatting for fractions, etc.
 */
export function formatLatexForDisplay(latex: string, tau: number): string {
  // Wrap with time constant if tau !== 1
  if (tau !== 1) {
    return `\\frac{1}{${tau}} \\dot{x} = ${latex}`;
  }
  return `\\dot{x} = ${latex}`;
}

/**
 * Prepare LaTeX for KaTeX rendering
 * Ensures proper escaping and formatting
 */
export function prepareForKatex(latex: string): string {
  // Replace common shortcuts
  let prepared = latex;
  
  // Convert x_1 to x_{1} for proper subscript rendering
  prepared = prepared.replace(/x_(\d+)/g, 'x_{$1}');
  
  // Convert x^2 to x^{2} for proper superscript rendering
  prepared = prepared.replace(/\^(\d+)/g, '^{$1}');
  
  return prepared;
}
