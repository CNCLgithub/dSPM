import React from 'react';
import { getPortPrimaryColor } from '@/utils/colorPalette';

interface FeedbackLoopProps {
  numRecOutputs: number;
  numRecInputs: number;
  cloudRadius: number;
  labelEdgeRight: number;  // X position of output labels
  labelEdgeLeft: number;   // X position of input labels
  verticalOffset: number;  // Vertical offset for recurrent groups
}

const LABEL_SPACING = 22;

// Helper to get Y positions for wires (matching PortGroup logic)
const getWireYPositions = (count: number, verticalOffset: number): number[] => {
  if (count === 0) return [];
  
  // Match the display logic from PortGroup
  const displayCount = count <= 3 ? count : 4; // 1,2 or 1,2,...,n
  const totalHeight = (displayCount - 1) * LABEL_SPACING;
  const startY = verticalOffset - totalHeight / 2;
  
  const positions: number[] = [];
  for (let i = 0; i < displayCount; i++) {
    // Skip the ellipsis position (index 2 when count > 3)
    if (count > 3 && i === 2) continue;
    positions.push(startY + i * LABEL_SPACING);
  }
  
  return positions;
};

// Helper to create a tapered path shape (filled polygon with varying width)
const createTaperedPath = (
  startX: number, startY: number,
  endX: number, endY: number,
  cp1X: number, cp1Y: number,
  cp2X: number, cp2Y: number,
  startWidth: number, endWidth: number
): string => {
  // Calculate perpendicular offsets at start and end
  // For start point - perpendicular to the initial direction
  const startDirX = cp1X - startX;
  const startDirY = cp1Y - startY;
  const startLen = Math.sqrt(startDirX * startDirX + startDirY * startDirY);
  const startPerpX = -startDirY / startLen;
  const startPerpY = startDirX / startLen;
  
  // For end point - perpendicular to the final direction
  const endDirX = endX - cp2X;
  const endDirY = endY - cp2Y;
  const endLen = Math.sqrt(endDirX * endDirX + endDirY * endDirY);
  const endPerpX = -endDirY / endLen;
  const endPerpY = endDirX / endLen;
  
  // Create the four corner points
  const startLeft = { x: startX + startPerpX * startWidth / 2, y: startY + startPerpY * startWidth / 2 };
  const startRight = { x: startX - startPerpX * startWidth / 2, y: startY - startPerpY * startWidth / 2 };
  const endLeft = { x: endX + endPerpX * endWidth / 2, y: endY + endPerpY * endWidth / 2 };
  const endRight = { x: endX - endPerpX * endWidth / 2, y: endY - endPerpY * endWidth / 2 };
  
  // Control points for the edges (offset from center control points)
  const cp1LeftX = cp1X + startPerpX * (startWidth + endWidth) / 4;
  const cp1LeftY = cp1Y + startPerpY * (startWidth + endWidth) / 4;
  const cp1RightX = cp1X - startPerpX * (startWidth + endWidth) / 4;
  const cp1RightY = cp1Y - startPerpY * (startWidth + endWidth) / 4;
  
  const cp2LeftX = cp2X + endPerpX * (startWidth + endWidth) / 4;
  const cp2LeftY = cp2Y + endPerpY * (startWidth + endWidth) / 4;
  const cp2RightX = cp2X - endPerpX * (startWidth + endWidth) / 4;
  const cp2RightY = cp2Y - endPerpY * (startWidth + endWidth) / 4;
  
  // Create closed path: start-left → end-left → end-right → start-right
  return `M ${startLeft.x} ${startLeft.y} 
          C ${cp1LeftX} ${cp1LeftY}, ${cp2LeftX} ${cp2LeftY}, ${endLeft.x} ${endLeft.y}
          L ${endRight.x} ${endRight.y}
          C ${cp2RightX} ${cp2RightY}, ${cp1RightX} ${cp1RightY}, ${startRight.x} ${startRight.y}
          Z`;
};

export const FeedbackLoop: React.FC<FeedbackLoopProps> = ({
  numRecOutputs,
  numRecInputs,
  cloudRadius,
  labelEdgeRight,
  labelEdgeLeft,
  verticalOffset,
}) => {
  // Colors
  const goldColor = getPortPrimaryColor('rec-out');
  const slateColor = getPortPrimaryColor('rec-in');
  
  // Get wire positions
  const outputYs = getWireYPositions(numRecOutputs, verticalOffset);
  const inputYs = getWireYPositions(numRecInputs, verticalOffset);
  
  // If no recurrent connections, don't render
  if (outputYs.length === 0 && inputYs.length === 0) {
    return null;
  }
  
  // Fork point X positions (where the branch splits from the main wire)
  const outputForkBaseX = labelEdgeRight - 40;
  const inputForkBaseX = labelEdgeLeft + 40;
  
  // Fiber position - lowered a bit more for n-condition spacing
  const fiberY = cloudRadius + 24; // Lowered from 18 to 24
  const fiberSag = 6;
  
  // Single convergence points
  const outputConvergeX = cloudRadius + 10;
  const inputConvergeX = -cloudRadius - 10;
  
  // Horizontal spread for fork points
  const forkSpreadX = 10;
  
  // Calculate Y range for normalization
  const outputMinY = outputYs.length > 0 ? Math.min(...outputYs) : 0;
  const outputMaxY = outputYs.length > 0 ? Math.max(...outputYs) : 0;
  const inputMinY = inputYs.length > 0 ? Math.min(...inputYs) : 0;
  const inputMaxY = inputYs.length > 0 ? Math.max(...inputYs) : 0;
  
  // Stroke widths for tapering
  const thinWidth = 1.5;  // At fork point (wire end)
  const thickWidth = 3.5; // At convergence (bundle end)
  
  // Create tapered shapes for output fork branches
  // Bottom wires (large Y) fork EARLIER (more outward = negative offset on right side)
  // Top wires (small Y) fork LATER (more inward = positive offset on right side)
  const outputForkShapes = outputYs.map((y) => {
    const normalizedY = outputYs.length > 1 
      ? (y - outputMinY) / (outputMaxY - outputMinY)
      : 0.5;
    
    // Bottom (1) → negative offset (outward/earlier), Top (0) → positive offset (inward/later)
    const staggerOffset = (normalizedY - 0.5) * forkSpreadX * 2;
    
    const startX = outputForkBaseX + staggerOffset;
    const startY = y;
    const endX = outputConvergeX;
    const endY = fiberY;
    
    const cp1X = startX + 25;
    const cp1Y = startY + (endY - startY) * 0.3;
    const cp2X = endX + 12;
    const cp2Y = endY - 8;
    
    return createTaperedPath(startX, startY, endX, endY, cp1X, cp1Y, cp2X, cp2Y, thinWidth, thickWidth);
  });
  
  // Create tapered shapes for input fork branches
  // Bottom wires fork EARLIER (more outward = positive offset on left side)
  // Top wires fork LATER (more inward = negative offset on left side)
  const inputForkShapes = inputYs.map((y) => {
    const normalizedY = inputYs.length > 1 
      ? (y - inputMinY) / (inputMaxY - inputMinY)
      : 0.5;
    
    // Bottom (1) → positive offset (outward/earlier), Top (0) → negative offset (inward/later)
    const staggerOffset = (0.5 - normalizedY) * forkSpreadX * 2;
    
    const startX = inputConvergeX;
    const startY = fiberY;
    const endX = inputForkBaseX + staggerOffset;
    const endY = y;
    
    const cp1X = startX - 12;
    const cp1Y = startY - 8;
    const cp2X = endX - 25;
    const cp2Y = endY + (startY - endY) * 0.3;
    
    // Note: for input, we go from convergence (thick) to fork (thin)
    return createTaperedPath(startX, startY, endX, endY, cp1X, cp1Y, cp2X, cp2Y, thickWidth, thinWidth);
  });
  
  // Main fiber path
  const fiberPath = `M ${outputConvergeX} ${fiberY} C ${outputConvergeX - 20} ${fiberY + fiberSag}, ${inputConvergeX + 20} ${fiberY + fiberSag}, ${inputConvergeX} ${fiberY}`;
  
  // Bezier helpers for arrowheads
  const getPointOnCubicBezier = (t: number, p0: {x: number, y: number}, p1: {x: number, y: number}, p2: {x: number, y: number}, p3: {x: number, y: number}) => {
    const mt = 1 - t;
    return {
      x: mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x,
      y: mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y,
    };
  };
  
  const getTangentOnCubicBezier = (t: number, p0: {x: number, y: number}, p1: {x: number, y: number}, p2: {x: number, y: number}, p3: {x: number, y: number}) => {
    const mt = 1 - t;
    return {
      x: 3*mt*mt*(p1.x-p0.x) + 6*mt*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x),
      y: 3*mt*mt*(p1.y-p0.y) + 6*mt*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y),
    };
  };
  
  const fiberP0 = { x: outputConvergeX, y: fiberY };
  const fiberP1 = { x: outputConvergeX - 20, y: fiberY + fiberSag };
  const fiberP2 = { x: inputConvergeX + 20, y: fiberY + fiberSag };
  const fiberP3 = { x: inputConvergeX, y: fiberY };
  
  const arrowPositions = [0.35, 0.65];
  const arrowSize = 10;
  
  const arrowheads = arrowPositions.map((t) => {
    const pos = getPointOnCubicBezier(t, fiberP0, fiberP1, fiberP2, fiberP3);
    const tangent = getTangentOnCubicBezier(t, fiberP0, fiberP1, fiberP2, fiberP3);
    
    const len = Math.sqrt(tangent.x * tangent.x + tangent.y * tangent.y);
    const normX = tangent.x / len;
    const normY = tangent.y / len;
    
    const perpX = -normY;
    const perpY = normX;
    
    const tip = { x: pos.x + normX * arrowSize * 0.6, y: pos.y + normY * arrowSize * 0.6 };
    const baseX = pos.x - normX * arrowSize * 0.5;
    const baseY = pos.y - normY * arrowSize * 0.5;
    const left = { x: baseX + perpX * arrowSize * 0.45, y: baseY + perpY * arrowSize * 0.45 };
    const right = { x: baseX - perpX * arrowSize * 0.45, y: baseY - perpY * arrowSize * 0.45 };
    
    return { tip, left, right, t };
  });
  
  const gradientId = 'feedbackLoopGradient';

  return (
    <g>
      <defs>
        <linearGradient id={gradientId} x1="100%" y1="0%" x2="0%" y2="0%">
          <stop offset="0%" stopColor={goldColor} />
          <stop offset="100%" stopColor={slateColor} />
        </linearGradient>
      </defs>
      
      {/* Output fork branches - tapered filled shapes */}
      {outputForkShapes.map((shape, i) => (
        <path
          key={`out-fork-${i}`}
          d={shape}
          fill={goldColor}
          opacity={0.45}
        />
      ))}
      
      {/* Input fork branches - tapered filled shapes */}
      {inputForkShapes.map((shape, i) => (
        <path
          key={`in-fork-${i}`}
          d={shape}
          fill={slateColor}
          opacity={0.45}
        />
      ))}
      
      {/* Main fiber arc with gradient */}
      <path
        d={fiberPath}
        fill="none"
        stroke={`url(#${gradientId})`}
        strokeWidth={4}
        strokeLinecap="round"
        opacity={0.65}
      />
      
      {/* Arrowheads */}
      {arrowheads.map((arrow, i) => (
        <polygon
          key={`arrow-${i}`}
          points={`${arrow.tip.x},${arrow.tip.y} ${arrow.left.x},${arrow.left.y} ${arrow.right.x},${arrow.right.y}`}
          fill={`url(#${gradientId})`}
          opacity={0.9}
        />
      ))}
      
      {/* Feedback label */}
      <text
        x={0}
        y={fiberY - 5}
        textAnchor="middle"
        fontSize="8"
        fill="#64748b"
        opacity={0.4}
        fontStyle="italic"
      >
        feedback
      </text>
    </g>
  );
};
