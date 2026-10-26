export interface RenderedEquationProps {
  index: number;
  latex: string;
  coefficient: string;
  isRecurrent: boolean;
}

export interface EquationRendererProps {
  className?: string;
}
