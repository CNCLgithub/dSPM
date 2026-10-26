import type { PortType } from '@/types/reservoir';

export interface PortConfig {
  type: PortType;
  baseAngle: number;      // Center angle for this quadrant (degrees)
  angleSpread: number;    // Total degrees to spread ports across
  labelPrefix: string;    // "x" or "ẋ"
  startIndex: number;     // Starting index for labels
}

export interface ConnectionLineProps {
  angle: number;
  innerRadius: number;
  outerRadius: number;
  color: string;
  label: string;
  showEllipsis?: boolean;
}

export interface PortGroupProps {
  type: PortType;
  count: number;
  cloudRadius: number;
  outerRadius: number;
  startIndex?: number;
}

export interface NeuronCloudProps {
  radius: number;
  count: number;
  isClosedLoop: boolean;
}

export interface PortControlsProps {
  type: PortType;
  count: number;
  onIncrement: () => void;
  onDecrement: () => void;
  position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
}

// Port configuration constants
// External ports use x/ẋ, Recurrent ports use y/ẏ
export const PORT_CONFIGS: Record<PortType, PortConfig> = {
  'ext-in': {
    type: 'ext-in',
    baseAngle: 160,      // Upper left quadrant, pointing right
    angleSpread: 30,
    labelPrefix: 'x',    // External input: xₙ
    startIndex: 1,
  },
  'ext-out': {
    type: 'ext-out',
    baseAngle: 20,       // Upper right quadrant, pointing left
    angleSpread: 30,
    labelPrefix: 'ẋ',    // External output: ẋₙ
    startIndex: 1,
  },
  'rec-in': {
    type: 'rec-in',
    baseAngle: 200,      // Lower left quadrant, pointing right
    angleSpread: 30,
    labelPrefix: 'y',    // Recurrent input: yₖ
    startIndex: 1,
  },
  'rec-out': {
    type: 'rec-out',
    baseAngle: 340,      // Lower right quadrant, pointing left
    angleSpread: 30,
    labelPrefix: 'ẏ',    // Recurrent output: ẏₖ
    startIndex: 1,
  },
};
