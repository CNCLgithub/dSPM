import React from 'react';
import { ConnectionLine } from './ConnectionLine';
import { getPortLabels, polarToCartesian } from './geometry';
import { PORT_CONFIGS } from './NetworkSchematic.types';
import { PORT_COLORS } from '@/constants/colors';
import { getPortPrimaryColor } from '@/utils/colorPalette';
import type { PortType } from '@/types/reservoir';

interface PortGroupProps {
  type: PortType;
  count: number;
  cloudRadius: number;
  labelEdgeX: number;    // X position for label column
  startIndex: number;    // Starting index for labels (1-based)
  verticalOffset?: number; // Vertical offset from center
  onIncrement: () => void;
  onDecrement: () => void;
  hideButtons?: boolean;  // Hide +/- buttons (for rec-in which is tethered to rec-out)
}

// Vertical spacing between stacked labels
const LABEL_SPACING = 22;
const BUTTON_SIZE = 18;

// Ghost style button - outline only, colored stroke
const GhostButton: React.FC<{
  onClick: () => void;
  color: string;
  isPlus: boolean;
  disabled?: boolean;
}> = ({ onClick, color, isPlus, disabled }) => (
  <button
    onClick={onClick}
    disabled={disabled}
    className={`w-[18px] h-[18px] rounded-full flex items-center justify-center
               transition-all duration-150 ease-out
               hover:scale-110 active:scale-95
               ${disabled ? 'opacity-20 cursor-not-allowed' : 'opacity-50 hover:opacity-90'}`}
    style={{ 
      background: 'transparent',
      border: `1.5px solid ${color}`,
    }}
  >
    <svg width="9" height="9" viewBox="0 0 9 9" fill="none">
      {isPlus ? (
        <path d="M4.5 2V7M2 4.5H7" stroke={color} strokeWidth="1.5" strokeLinecap="round"/>
      ) : (
        <path d="M2 4.5H7" stroke={color} strokeWidth="1.5" strokeLinecap="round"/>
      )}
    </svg>
  </button>
);

export const PortGroup: React.FC<PortGroupProps> = ({
  type,
  count,
  cloudRadius,
  labelEdgeX,
  startIndex,
  verticalOffset = 0,
  onIncrement,
  onDecrement,
  hideButtons = false,
}) => {
  const config = PORT_CONFIGS[type];
  const color = PORT_COLORS[type];
  const primaryColor = getPortPrimaryColor(type);
  
  // Determine side
  const isLeftSide = type === 'ext-in' || type === 'rec-in';
  
  // Calculate vertical center for this group
  const groupCenterY = verticalOffset;

  // Cloud connection angles
  const getCloudAngle = (index: number, total: number): number => {
    if (total === 1) {
      if (type === 'ext-in') return 155;
      if (type === 'rec-in') return 205;
      if (type === 'ext-out') return 25;
      return 335;
    }
    
    const t = index / (total - 1);
    
    if (type === 'ext-in') {
      return 140 + t * 35;
    } else if (type === 'rec-in') {
      return 185 + t * 35;
    } else if (type === 'ext-out') {
      return 40 - t * 35;
    } else {
      return 355 - t * 35;
    }
  };

  // Position for single + button when count=0 (at 30/150/210/330 degrees near cloud)
  const getZeroStatePosition = () => {
    const angle = type === 'ext-in' ? 150 : type === 'ext-out' ? 30 : type === 'rec-in' ? 210 : 330;
    const distance = cloudRadius + 30;
    const rad = (angle * Math.PI) / 180;
    return {
      x: Math.cos(rad) * distance,
      y: -Math.sin(rad) * distance,
    };
  };

  // If count is 0, show a + button near the cloud (unless buttons are hidden)
  if (count === 0) {
    // For rec-in with hidden buttons, show nothing when count is 0
    if (hideButtons) {
      return null;
    }
    
    const pos = getZeroStatePosition();
    const boxSize = BUTTON_SIZE * 3;
    return (
      <g>
        <foreignObject
          x={pos.x - boxSize / 2}
          y={pos.y - boxSize / 2}
          width={boxSize}
          height={boxSize}
          style={{ overflow: 'visible' }}
        >
          <div className="w-full h-full flex items-center justify-center">
            <GhostButton onClick={onIncrement} color={color.primary} isPlus={true} />
          </div>
        </foreignObject>
      </g>
    );
  }

  // Normal rendering with labels
  const labels = getPortLabels(count, config.labelPrefix, startIndex);
  const displayCount = labels.length;
  const totalHeight = (displayCount - 1) * LABEL_SPACING;
  const startY = groupCenterY - totalHeight / 2;

  // Button position depends on group type:
  // - External (top groups): buttons ABOVE first label (upper outside)
  // - Recurrent (bottom groups): buttons BELOW last label (lower outside)
  const isExternalGroup = type === 'ext-in' || type === 'ext-out';
  const firstLabelY = startY;
  const lastLabelY = startY + totalHeight;
  
  // Vertical position: above first label for external, below last for recurrent
  const buttonY = isExternalGroup ? firstLabelY - 20 : lastLabelY + 20;
  
  // Horizontal position: symmetric distance from labels on both sides
  // Left side: buttons to the left of labelEdgeX
  // Right side: buttons to the right of labelEdgeX
  const horizontalOffset = 24; // Distance from label anchor
  const buttonGroupWidth = BUTTON_SIZE * 2 + 8;

  // Determine variable name: x for external, y for recurrent
  const varName = (type === 'rec-in' || type === 'rec-out') ? 'y' : 'x';

  return (
    <g>
      {labels.map((label, i) => {
        const labelY = startY + i * LABEL_SPACING;
        
        const effectiveIndex = label === null ? Math.floor(displayCount / 2) : i;
        const cloudAngle = getCloudAngle(effectiveIndex, displayCount);
        const cloudPoint = polarToCartesian(cloudAngle, cloudRadius);

        return (
          <ConnectionLine
            key={`${type}-${i}`}
            labelX={labelEdgeX}
            labelY={labelY}
            cloudX={cloudPoint.x}
            cloudY={cloudPoint.y}
            color={primaryColor}
            label={label}
            labelIndex={label === null ? null : (startIndex + (i < 2 ? i : count - (displayCount - i)))}
            isLeftSide={isLeftSide}
            isDerivative={type === 'ext-out' || type === 'rec-out'}
            varName={varName}
          />
        );
      })}
      
      {/* Button pair at outside corner of group - plus on left, minus on right */}
      {/* NOTE: hideButtons is used for rec-in which is tethered to rec-out count */}
      {!hideButtons && (
        <foreignObject
          x={isLeftSide ? labelEdgeX - horizontalOffset - buttonGroupWidth : labelEdgeX + horizontalOffset}
          y={buttonY - BUTTON_SIZE * 1.5}
          width={buttonGroupWidth + 16}
          height={BUTTON_SIZE * 3}
          style={{ overflow: 'visible' }}
        >
          <div className="w-full h-full flex items-center justify-center gap-1">
            <GhostButton onClick={onIncrement} color={color.primary} isPlus={true} />
            <GhostButton onClick={onDecrement} color={color.primary} isPlus={false} />
          </div>
        </foreignObject>
      )}
    </g>
  );
};
