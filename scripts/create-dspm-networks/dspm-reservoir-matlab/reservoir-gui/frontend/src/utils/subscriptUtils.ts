// Utilities for subscript/superscript conversions

const SUBSCRIPT_MAP: Record<string, string> = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ',
  'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
  'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ',
  'v': 'ᵥ', 'x': 'ₓ',
};

const SUPERSCRIPT_MAP: Record<string, string> = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'n': 'ⁿ', 'i': 'ⁱ',
};

/**
 * Convert a number or string to subscript Unicode
 */
export function toSubscript(n: number | string): string {
  return String(n)
    .split('')
    .map(char => SUBSCRIPT_MAP[char] ?? char)
    .join('');
}

/**
 * Convert a number or string to superscript Unicode
 */
export function toSuperscript(n: number | string): string {
  return String(n)
    .split('')
    .map(char => SUPERSCRIPT_MAP[char] ?? char)
    .join('');
}

/**
 * Format variable with subscript: x_1 → x₁
 */
export function formatVariable(base: string, index: number): string {
  return `${base}${toSubscript(index)}`;
}

/**
 * Format derivative: x with dot → ẋ
 */
export function formatDerivative(base: string, index: number, order: number = 1): string {
  const dots = order === 1 ? '̇' : order === 2 ? '̈' : '⃛';
  return `${base}${dots}${toSubscript(index)}`;
}

/**
 * Convert x_1 notation to x₁
 */
export function convertUnderscoreToSubscript(str: string): string {
  return str.replace(/([a-zA-Z])_(\d+)/g, (_, base, num) => formatVariable(base, parseInt(num)));
}

/**
 * Convert x^2 notation to x²
 */
export function convertCaretToSuperscript(str: string): string {
  return str.replace(/\^(\d+)/g, (_, num) => toSuperscript(num));
}

/**
 * Format for display: convert both subscripts and superscripts
 */
export function formatForDisplay(str: string): string {
  let result = convertUnderscoreToSubscript(str);
  result = convertCaretToSuperscript(result);
  return result;
}
