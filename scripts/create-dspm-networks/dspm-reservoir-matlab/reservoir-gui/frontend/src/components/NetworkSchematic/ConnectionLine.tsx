import React from 'react';
import katex from 'katex';

interface ConnectionLineProps {
  labelX: number;        // X position for the label
  labelY: number;        // Y position for the label
  cloudX: number;        // X position where line meets cloud
  cloudY: number;        // Y position where line meets cloud
  color: string;
  label: string | null;  // Display label (may include ellipsis indicator)
  labelIndex: number | null; // Actual numeric index for LaTeX rendering
  isLeftSide: boolean;
  isDerivative: boolean; // Whether to show ẋ/ẏ vs x/y
  varName?: string;      // Variable name: 'x' for external, 'y' for recurrent
}

export const ConnectionLine: React.FC<ConnectionLineProps> = ({
  labelX,
  labelY,
  cloudX,
  cloudY,
  color,
  label,
  labelIndex,
  isLeftSide,
  isDerivative,
  varName = 'x',
}) => {
  // If label is null, this is an ellipsis marker
  if (label === null) {
    return (
      <text
        x={labelX}
        y={labelY}
        fill={color}
        fontSize={16}
        fontWeight={500}
        textAnchor={isLeftSide ? 'end' : 'start'}
        dominantBaseline="middle"
        opacity={0.6}
      >
        ⋮
      </text>
    );
  }

  // Render LaTeX for the label - use varName (x for external, y for recurrent)
  const latexString = isDerivative 
    ? `\\dot{${varName}}_{${labelIndex}}` 
    : `${varName}_{${labelIndex}}`;
  
  let renderedLatex = '';
  try {
    renderedLatex = katex.renderToString(latexString, {
      throwOnError: false,
      displayMode: false,
    });
  } catch {
    renderedLatex = label;
  }

  // Starting point near the label
  const startX = isLeftSide ? labelX + 12 : labelX - 12;
  const startY = labelY;
  
  // Calculate where the horizontal line should bend toward the cloud
  // Elbow closer to cloud reduces crossing of curves
  const elbowX = isLeftSide ? cloudX - 30 : cloudX + 30;
  const elbowY = startY;
  
  // For quadratic bezier - control point creates the curve shape
  // Position it to create a smooth arc toward the cloud
  const controlX = isLeftSide ? cloudX - 10 : cloudX + 10;
  const controlY = elbowY;

  // Create path: horizontal line, then quadratic bezier to cloud
  const path = `M ${startX} ${startY} 
                L ${elbowX} ${elbowY}
                Q ${controlX} ${controlY}, ${cloudX} ${cloudY}`;

  // Label positioning
  const labelWidth = 50;
  const labelHeight = 24;

  return (
    <g>
      {/* Port dot at cloud edge - drawn FIRST so line draws over it */}
      <circle cx={cloudX} cy={cloudY} r={3.5} fill={color} opacity={0.9} />
      
      {/* Connection path - butt linecap prevents overshoot */}
      <path
        d={path}
        stroke={color}
        strokeWidth={2}
        strokeLinecap="butt"
        fill="none"
        opacity={0.7}
      />
      
      {/* Small dot at the very end to ensure clean termination */}
      <circle cx={cloudX} cy={cloudY} r={1} fill={color} />
      
      {/* LaTeX label using foreignObject */}
      <foreignObject
        x={isLeftSide ? labelX - labelWidth : labelX}
        y={labelY - labelHeight / 2}
        width={labelWidth}
        height={labelHeight}
        style={{ overflow: 'visible' }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: isLeftSide ? 'flex-end' : 'flex-start',
            height: '100%',
            color: color,
            fontSize: '16px',
            fontWeight: 600,
          }}
          dangerouslySetInnerHTML={{ __html: renderedLatex }}
        />
      </foreignObject>
    </g>
  );
};
