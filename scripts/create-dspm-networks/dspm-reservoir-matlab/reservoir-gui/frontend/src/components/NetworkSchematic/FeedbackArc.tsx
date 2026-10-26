import React from 'react';
import { PORT_COLORS } from '@/constants/colors';

interface FeedbackArcProps {
  radius: number;
  fromAngle: number;  // rec-out angle
  toAngle: number;    // rec-in angle
}

export const FeedbackArc: React.FC<FeedbackArcProps> = ({
  radius,
  fromAngle,
  toAngle,
}) => {
  // Colors from the recurrent ports
  const goldColor = PORT_COLORS['rec-out'].button;
  const slateColor = PORT_COLORS['rec-in'].button;
  
  // Convert angles to radians
  const startRad = (fromAngle * Math.PI) / 180;
  const endRad = (toAngle * Math.PI) / 180;
  
  // Calculate start and end points on the cloud edge
  const startX = Math.cos(startRad) * radius;
  const startY = -Math.sin(startRad) * radius;
  const endX = Math.cos(endRad) * radius;
  const endY = -Math.sin(endRad) * radius;
  
  // Create a smooth bezier curve that arcs below the cloud
  // Control points create a nice curved path
  const arcDrop = 55; // How far below the cloud the arc goes
  const spreadX = 25; // Horizontal spread of control points
  
  const cp1 = { x: startX + spreadX, y: startY + arcDrop };
  const cp2 = { x: endX - spreadX, y: endY + arcDrop };
  
  const path = `
    M ${startX} ${startY}
    C ${cp1.x} ${cp1.y}, ${cp2.x} ${cp2.y}, ${endX} ${endY}
  `;
  
  // Arrow head at the end - pointing toward rec-in
  const arrowSize = 8;
  // Calculate tangent direction at endpoint
  const tangentX = endX - cp2.x;
  const tangentY = endY - cp2.y;
  const tangentLen = Math.sqrt(tangentX * tangentX + tangentY * tangentY);
  const normX = tangentX / tangentLen;
  const normY = tangentY / tangentLen;
  
  // Perpendicular for arrow wings
  const perpX = -normY;
  const perpY = normX;
  
  const arrowTip = { x: endX, y: endY };
  const arrowBase = { x: endX - normX * arrowSize, y: endY - normY * arrowSize };
  const arrowLeft = {
    x: arrowBase.x + perpX * arrowSize * 0.5,
    y: arrowBase.y + perpY * arrowSize * 0.5,
  };
  const arrowRight = {
    x: arrowBase.x - perpX * arrowSize * 0.5,
    y: arrowBase.y - perpY * arrowSize * 0.5,
  };

  // Gradient ID
  const gradientId = 'feedbackGradient';

  return (
    <g>
      {/* Gradient definition for gold → slate transition */}
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor={goldColor} />
          <stop offset="100%" stopColor={slateColor} />
        </linearGradient>
      </defs>
      
      {/* Arc path with gradient */}
      <path
        d={path}
        fill="none"
        stroke={`url(#${gradientId})`}
        strokeWidth={2.5}
        strokeLinecap="round"
        opacity={0.7}
      />
      
      {/* Arrow head */}
      <polygon
        points={`${arrowTip.x},${arrowTip.y} ${arrowLeft.x},${arrowLeft.y} ${arrowRight.x},${arrowRight.y}`}
        fill={slateColor}
        opacity={0.8}
      />
      
      {/* Small "feedback" label */}
      <text
        x={0}
        y={radius + arcDrop - 8}
        textAnchor="middle"
        fontSize="9"
        fill="#64748b"
        opacity={0.6}
        fontStyle="italic"
      >
        feedback
      </text>
    </g>
  );
};
