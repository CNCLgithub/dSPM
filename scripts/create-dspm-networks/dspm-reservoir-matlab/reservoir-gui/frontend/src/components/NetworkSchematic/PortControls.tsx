import React, { useState, useRef, useMemo } from 'react';
import { Info } from 'lucide-react';
import katex from 'katex';
import { PORT_COLORS } from '@/constants/colors';
import type { PortType } from '@/types/reservoir';

interface PortControlsProps {
  type: PortType;
  count: number;
}

const positionClasses: Record<PortType, string> = {
  'ext-in': 'top-1 left-1',
  'ext-out': 'top-1 right-1',
  'rec-in': 'bottom-1 left-1',
  'rec-out': 'bottom-1 right-1',
};

// Full descriptive labels for each port type
const portLabels: Record<PortType, string> = {
  'ext-in': 'external inputs',
  'ext-out': 'external outputs',
  'rec-in': 'recurrent inputs',
  'rec-out': 'recurrent outputs',
};

// Render LaTeX helper
const renderLatex = (latex: string): string => {
  try {
    return katex.renderToString(latex, {
      throwOnError: false,
      displayMode: false,
    });
  } catch {
    return latex;
  }
};

// Tooltip content with LaTeX - returns JSX
const getTooltipContent = (type: PortType): { text: string; varLatex: string } => {
  switch (type) {
    case 'ext-in':
      return {
        text: 'Exogenous input signals %VAR% that drive the network from outside. These remain as external inputs after compilation.',
        varLatex: '(x_n)',
      };
    case 'ext-out':
      return {
        text: 'Observable output signals %VAR% that read out network state. Use these for downstream processing or control.',
        varLatex: '(\\dot{x}_n)',
      };
    case 'rec-in':
      return {
        text: 'Feedback input channels %VAR% that receive recurrent connections. After compilation, these are driven by the network\'s own outputs.',
        varLatex: '(y_k)',
      };
    case 'rec-out':
      return {
        text: 'Recurrent output signals %VAR% that form feedback loops. These define the dynamical system you\'re programming.',
        varLatex: '(\\dot{y}_k)',
      };
  }
};

// Colored tooltip component with LaTeX support
const PortTooltip: React.FC<{ type: PortType; color: string }> = ({ type, color }) => {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const iconRef = useRef<HTMLDivElement>(null);

  const { text, varLatex } = getTooltipContent(type);
  const renderedVar = useMemo(() => renderLatex(varLatex), [varLatex]);

  // Split text around %VAR% placeholder
  const parts = text.split('%VAR%');

  const handleMouseEnter = () => {
    if (iconRef.current) {
      const rect = iconRef.current.getBoundingClientRect();
      const tooltipHeight = 80; // Approximate height
      const tooltipWidth = 224; // w-56 = 14rem = 224px
      const viewportHeight = window.innerHeight;
      const viewportWidth = window.innerWidth;
      
      // Determine vertical position
      let top: number;
      if (rect.bottom + 8 + tooltipHeight > viewportHeight - 16) {
        // Position above
        top = rect.top - tooltipHeight - 8;
      } else {
        // Position below
        top = rect.bottom + 8;
      }
      
      // Determine horizontal position
      let left = rect.left - 100;
      // Clamp to viewport
      left = Math.max(8, Math.min(left, viewportWidth - tooltipWidth - 8));
      
      setPosition({ top, left });
      setIsVisible(true);
    }
  };

  return (
    <div 
      ref={iconRef}
      className="inline-flex items-center cursor-help"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={() => setIsVisible(false)}
    >
      <Info className="w-3 h-3 opacity-50 hover:opacity-80 transition-opacity" style={{ color }} />
      {isVisible && (
        <div 
          className="fixed px-3 py-2 text-xs text-slate-600 dark:text-slate-300
                     bg-white dark:bg-slate-800 
                     border border-slate-200 dark:border-slate-700
                     rounded-lg shadow-lg
                     w-56 z-[100]"
          style={{ top: position.top, left: position.left }}
        >
          {parts[0]}
          <span dangerouslySetInnerHTML={{ __html: renderedVar }} />
          {parts[1]}
        </div>
      )}
    </div>
  );
};

export const PortControls: React.FC<PortControlsProps> = ({
  type,
  count,
}) => {
  const color = PORT_COLORS[type];
  const label = portLabels[type];
  const position = positionClasses[type];
  const isRightSide = type === 'ext-out' || type === 'rec-out';

  return (
    <div className={`absolute ${position} z-20 flex items-center gap-2 
                     px-2 py-1 rounded-md
                     bg-white/90 dark:bg-[#1E1E1E]/90
                     ${isRightSide ? 'flex-row-reverse' : ''}`}>
      {/* Full text label with tooltip */}
      <div className={`flex items-center gap-1 ${isRightSide ? 'flex-row-reverse' : ''}`}>
        <span 
          className="text-xs font-medium opacity-70"
          style={{ color: color.primary }}
        >
          {label}
        </span>
        <PortTooltip type={type} color={color.primary} />
      </div>
      
      {/* Count */}
      <span 
        className="text-lg font-bold tabular-nums"
        style={{ color: color.primary }}
      >
        {count}
      </span>
    </div>
  );
};
