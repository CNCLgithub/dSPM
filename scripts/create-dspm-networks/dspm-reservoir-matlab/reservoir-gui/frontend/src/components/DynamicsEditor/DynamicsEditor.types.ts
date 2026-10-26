export interface DynamicsRowProps {
  index: number;           // Store index (1-based, continuous for all outputs)
  displayIndex: number;    // Display index (1-based, separate for ext and rec)
  latex: string;
  coefficient: string;
  isValid: boolean;
  errorMessage?: string;
  onLatexChange: (latex: string) => void;
  onCoefficientChange: (coefficient: string) => void;
  isRecurrent: boolean;    // If true, use ẏₖ; if false, use ẋₙ
}

export interface LatexInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  isValid?: boolean;
  errorMessage?: string;
}

export interface CoefficientInputProps {
  value: string;
  onChange: (value: string) => void;
  displayIndex: number;    // Display index for τₖ or τₙ
  isRecurrent: boolean;    // Affects τ subscript style
}
