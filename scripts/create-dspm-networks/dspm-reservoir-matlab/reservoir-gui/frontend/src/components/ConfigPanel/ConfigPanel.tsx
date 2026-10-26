import React, { useState, useRef, useMemo } from 'react';
import { Settings, Info } from 'lucide-react';
import katex from 'katex';
import { PresetDropdown } from './PresetDropdown';
import { SettingsPopup } from './SettingsPopup';
import { useReservoirStore } from '@/stores/reservoirStore';
import { useMatlabBridge } from '@/hooks/useMatlabBridge';
import type { BuiltInPreset, UserPreset } from '@/types/saveSchema';
import type { ConfigPanelProps } from './ConfigPanel.types';

type PresetItem = BuiltInPreset | UserPreset;

// Render LaTeX helper
const renderLatex = (latex: string, displayMode = false): string => {
  try {
    return katex.renderToString(latex, {
      throwOnError: false,
      displayMode,
    });
  } catch {
    return latex;
  }
};

// Inline tooltip for gamma - uses fixed positioning to avoid clipping
const GammaTooltip: React.FC = () => {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0, placeAbove: false });
  const iconRef = useRef<HTMLDivElement>(null);

  // Pre-render LaTeX for tooltip
  const equationHtml = useMemo(() => 
    renderLatex('\\frac{1}{\\gamma}\\dot{r} = -r + \\tanh(Ar + Bx + d)', true), 
  []);
  const gammaHtml = useMemo(() => renderLatex('\\gamma'), []);
  const tauHtml = useMemo(() => renderLatex('\\tau_k(t)'), []);

  const handleMouseEnter = () => {
    if (iconRef.current) {
      const rect = iconRef.current.getBoundingClientRect();
      const tooltipHeight = 160; // Approximate height of tooltip
      const viewportHeight = window.innerHeight;
      
      // Check if tooltip would go below viewport
      const wouldOverflowBottom = rect.bottom + 8 + tooltipHeight > viewportHeight - 16;
      
      if (wouldOverflowBottom) {
        // Position above the icon
        setPosition({
          top: rect.top - tooltipHeight - 8,
          left: rect.left - 120,
          placeAbove: true,
        });
      } else {
        // Position below the icon
        setPosition({
          top: rect.bottom + 8,
          left: rect.left - 120,
          placeAbove: false,
        });
      }
      setIsVisible(true);
    }
  };

  return (
    <div 
      ref={iconRef}
      className="inline-flex items-center"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={() => setIsVisible(false)}
    >
      <Info className="w-3 h-3 text-slate-300 dark:text-slate-600 cursor-help" />
      {isVisible && (
        <div 
          className="fixed px-4 py-3 text-xs text-slate-600 dark:text-slate-300
                     bg-white dark:bg-slate-800 
                     border border-slate-200 dark:border-slate-700
                     rounded-lg shadow-lg
                     w-80 z-[100]"
          style={{ top: position.top, left: Math.max(8, position.left) }}
        >
          <p className="mb-2">
            <span className="font-medium">Network time constant.</span> Controls the global rate of reservoir dynamics via
          </p>
          <div 
            className="my-3 text-center"
            dangerouslySetInnerHTML={{ __html: equationHtml }}
          />
          <p>
            Larger <span dangerouslySetInnerHTML={{ __html: gammaHtml }} /> = faster dynamics. 
            This is distinct from the local symbolic time scales{' '}
            <span dangerouslySetInnerHTML={{ __html: tauHtml }} /> in each equation.
          </p>
        </div>
      )}
    </div>
  );
};

export const ConfigPanel: React.FC<ConfigPanelProps> = ({ className = '' }) => {
  const [showSettings, setShowSettings] = useState(false);
  const settingsButtonRef = useRef<HTMLButtonElement>(null);
  
  // Pre-render gamma label
  const gammaLabel = useMemo(() => renderLatex('\\gamma'), []);
  
  const {
    config,
    setNeuronCount,
    setGamma,
    loadPresetV2,
  } = useReservoirStore();

  // Get preset management functions from matlab bridge
  const { removePreset } = useMatlabBridge();

  const handlePresetSelect = (preset: PresetItem) => {
    loadPresetV2(preset);
  };

  return (
    <div className={`flex flex-col ${className}`}>
      {/* Main row - Preset + neurons + gamma + settings */}
      <div className="flex items-center gap-4 px-5 py-3">
        {/* Preset dropdown */}
        <div className="flex-1 max-w-[200px]">
          <PresetDropdown 
            onSelect={handlePresetSelect} 
            onRemovePreset={removePreset}
          />
        </div>
        
        {/* Key parameters inline */}
        <div className="flex items-center gap-5 text-sm">
          {/* Neurons */}
          <div className="flex items-center gap-2">
            <span className="text-slate-400 dark:text-slate-500">neurons</span>
            <input
              type="text"
              inputMode="numeric"
              value={config.nNeurons}
              onChange={(e) => {
                const v = parseInt(e.target.value);
                if (!isNaN(v) && v >= 10 && v <= 10000) setNeuronCount(v);
              }}
              className="w-16 px-2 py-1 text-sm text-center font-medium
                         bg-slate-50 dark:bg-slate-800 rounded-lg
                         text-slate-700 dark:text-slate-200
                         border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
          </div>

          {/* Gamma with tooltip */}
          <div className="flex items-center gap-1.5">
            <span 
              className="text-slate-400 dark:text-slate-500"
              dangerouslySetInnerHTML={{ __html: gammaLabel }}
            />
            <GammaTooltip />
            <input
              type="text"
              inputMode="numeric"
              value={config.gamma}
              onChange={(e) => {
                const v = parseInt(e.target.value);
                if (!isNaN(v) && v > 0) setGamma(v);
              }}
              className="w-16 px-2 py-1 text-sm text-center font-medium
                         bg-slate-50 dark:bg-slate-800 rounded-lg
                         text-slate-700 dark:text-slate-200
                         border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
          </div>
        </div>
        
        {/* Settings button */}
        <button
          ref={settingsButtonRef}
          onClick={() => setShowSettings(!showSettings)}
          className={`p-1.5 rounded-lg transition-colors
                     ${showSettings 
                       ? 'text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800' 
                       : 'text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'
                     }`}
          title="Advanced settings"
        >
          <Settings className="w-4 h-4" />
        </button>
      </div>
      
      {/* Settings popup */}
      {showSettings && (
        <SettingsPopup 
          onClose={() => setShowSettings(false)} 
          anchorRef={settingsButtonRef}
        />
      )}
    </div>
  );
};
