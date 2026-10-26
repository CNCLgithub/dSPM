import React, { useEffect, useRef, useState, useMemo } from 'react';
import { X, Info } from 'lucide-react';
import katex from 'katex';
import { useReservoirStore } from '@/stores/reservoirStore';
import { LIMITS } from '@/constants';

interface SettingsPopupProps {
  onClose: () => void;
  anchorRef: React.RefObject<HTMLElement>;
}

// Tooltip component - renders to body via portal-like fixed positioning
const Tooltip: React.FC<{ text: string }> = ({ text }) => {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const iconRef = useRef<HTMLDivElement>(null);

  const handleMouseEnter = () => {
    if (iconRef.current) {
      const rect = iconRef.current.getBoundingClientRect();
      // Position to the right of the icon
      setPosition({
        top: rect.top + rect.height / 2,
        left: rect.right + 8,
      });
      setIsVisible(true);
    }
  };

  return (
    <div 
      ref={iconRef}
      className="inline-flex items-center ml-1"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={() => setIsVisible(false)}
    >
      <Info className="w-3.5 h-3.5 text-slate-400 dark:text-slate-500 cursor-help" />
      {isVisible && (
        <div 
          className="fixed px-3 py-2 text-xs text-slate-600 dark:text-slate-300
                     bg-white dark:bg-slate-800 
                     border border-slate-200 dark:border-slate-700
                     rounded-lg shadow-lg
                     w-56 z-[100]
                     -translate-y-1/2"
          style={{ top: position.top, left: position.left }}
        >
          {text}
        </div>
      )}
    </div>
  );
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

export const SettingsPopup: React.FC<SettingsPopupProps> = ({ onClose, anchorRef }) => {
  const popupRef = useRef<HTMLDivElement>(null);
  const {
    config,
    setDt,
    setBScale,
    setBSparsity,
    setVerbose,
    setExpansionPointValue,
  } = useReservoirStore();

  // Position below anchor, constrained to viewport
  const [position, setPosition] = useState({ top: 0, left: 0 });

  // Pre-render LaTeX for header
  const vecY0Label = useMemo(() => renderLatex('\\vec{y}_0'), []);

  useEffect(() => {
    if (anchorRef.current && popupRef.current) {
      const anchorRect = anchorRef.current.getBoundingClientRect();
      const popupWidth = 320;
      const popupHeight = popupRef.current.offsetHeight || 400;
      
      // Get viewport dimensions
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;
      
      // Calculate initial position (below anchor, right-aligned)
      let top = anchorRect.bottom + 8;
      let left = anchorRect.right - popupWidth;
      
      // Constrain to viewport with padding
      const padding = 16;
      
      // Horizontal bounds
      if (left < padding) {
        left = padding;
      }
      if (left + popupWidth > viewportWidth - padding) {
        left = viewportWidth - popupWidth - padding;
      }
      
      // Vertical bounds - if popup would go below viewport, position above anchor
      if (top + popupHeight > viewportHeight - padding) {
        top = anchorRect.top - popupHeight - 8;
        // If still doesn't fit, just constrain to bottom
        if (top < padding) {
          top = viewportHeight - popupHeight - padding;
        }
      }
      
      setPosition({ top, left });
    }
  }, [anchorRef]);

  // Close on click outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        onClose();
      }
    };

    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside);
    }, 10);

    return () => {
      clearTimeout(timer);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [onClose]);

  // Close on escape
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  // Get sorted expansion point entries
  const xEntries = Object.entries(config.expansionPoint.x)
    .map(([k, v]) => [parseInt(k), v] as [number, number])
    .sort((a, b) => a[0] - b[0]);
  
  const yEntries = Object.entries(config.expansionPoint.y)
    .map(([k, v]) => [parseInt(k), v] as [number, number])
    .sort((a, b) => a[0] - b[0]);

  return (
    <div
      ref={popupRef}
      className="fixed z-50 w-80
                 bg-white dark:bg-slate-900
                 border border-slate-200 dark:border-slate-700
                 rounded-xl shadow-xl dark:shadow-2xl
                 overflow-visible"
      style={{ top: position.top, left: position.left }}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 
                      border-b border-slate-100 dark:border-slate-800">
        <span className="text-sm font-medium text-slate-700 dark:text-slate-200">
          Settings
        </span>
        <button
          onClick={onClose}
          className="p-1 rounded-lg text-slate-400 hover:text-slate-600
                     dark:text-slate-500 dark:hover:text-slate-300
                     hover:bg-slate-100 dark:hover:bg-slate-800
                     transition-colors"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Content */}
      <div className="p-4 space-y-5">
        {/* Simulation Section */}
        <div>
          <div className="text-xs font-medium text-slate-400 dark:text-slate-500 mb-3">
            Simulation
          </div>
          
          <div className="flex items-center justify-between">
            <div className="flex items-center">
              <span className="text-sm text-slate-600 dark:text-slate-300">dt</span>
              <Tooltip text="Integration time step for numerical simulation. Smaller values give more accuracy but slower computation." />
            </div>
            <input
              type="text"
              inputMode="decimal"
              value={config.dt}
              onChange={(e) => {
                const v = parseFloat(e.target.value);
                if (!isNaN(v) && v >= LIMITS.minDt && v <= LIMITS.maxDt) {
                  setDt(v);
                }
              }}
              className="w-20 px-2 py-1 text-sm text-right font-medium
                         bg-slate-50 dark:bg-slate-800 rounded-lg
                         text-slate-700 dark:text-slate-200
                         border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
          </div>
        </div>

        {/* Initialization Section */}
        <div>
          <div className="text-xs font-medium text-slate-400 dark:text-slate-500 mb-3">
            Initialization
          </div>
          
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <span className="text-sm text-slate-600 dark:text-slate-300">B scale</span>
                <Tooltip text="Magnitude of random read-in weights. Larger values = stronger input coupling to reservoir neurons." />
              </div>
              <input
                type="text"
                inputMode="decimal"
                value={config.B_scale}
                onChange={(e) => {
                  const v = parseFloat(e.target.value);
                  if (!isNaN(v) && v >= LIMITS.minBScale && v <= LIMITS.maxBScale) {
                    setBScale(v);
                  }
                }}
                className="w-20 px-2 py-1 text-sm text-right font-medium
                           bg-slate-50 dark:bg-slate-800 rounded-lg
                           text-slate-700 dark:text-slate-200
                           border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
              />
            </div>

            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <span className="text-sm text-slate-600 dark:text-slate-300">B sparsity</span>
                <Tooltip text="Fraction of non-zero connections in B matrix. 1.0 = fully connected, 0.1 = 10% of connections active." />
              </div>
              <input
                type="text"
                inputMode="decimal"
                value={config.B_sparsity}
                onChange={(e) => {
                  const v = parseFloat(e.target.value);
                  if (!isNaN(v) && v >= LIMITS.minBSparsity && v <= LIMITS.maxBSparsity) {
                    setBSparsity(v);
                  }
                }}
                className="w-20 px-2 py-1 text-sm text-right font-medium
                           bg-slate-50 dark:bg-slate-800 rounded-lg
                           text-slate-700 dark:text-slate-200
                           border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
              />
            </div>
          </div>
        </div>

        {/* Expansion Point Section */}
        <div>
          <div className="flex items-center mb-3">
            <span className="text-xs font-medium text-slate-400 dark:text-slate-500 mr-1">
              Expansion Point
            </span>
            <span 
              className="text-xs text-slate-400 dark:text-slate-500"
              dangerouslySetInnerHTML={{ __html: vecY0Label }}
            />
            <Tooltip text="Point about which the polynomial Taylor series is expanded in combined input space (x, y). Default is zeros." />
          </div>
          
          <div className="space-y-2">
            {/* External inputs (x) */}
            {xEntries.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {xEntries.map(([idx, val]) => (
                  <div key={`x-${idx}`} className="flex items-center gap-1">
                    <span 
                      className="text-xs text-slate-400 dark:text-slate-500 w-6"
                      dangerouslySetInnerHTML={{ __html: renderLatex(`x_{${idx}}`) }}
                    />
                    <input
                      type="text"
                      inputMode="decimal"
                      value={val}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value);
                        if (!isNaN(v)) {
                          setExpansionPointValue('x', idx, v);
                        }
                      }}
                      className="w-14 px-1.5 py-1 text-xs text-center font-medium
                                 bg-slate-50 dark:bg-slate-800 rounded
                                 text-slate-700 dark:text-slate-200
                                 border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
                    />
                  </div>
                ))}
              </div>
            )}

            {/* Recurrent inputs (y) */}
            {yEntries.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {yEntries.map(([idx, val]) => (
                  <div key={`y-${idx}`} className="flex items-center gap-1">
                    <span 
                      className="text-xs text-slate-400 dark:text-slate-500 w-6"
                      dangerouslySetInnerHTML={{ __html: renderLatex(`y_{${idx}}`) }}
                    />
                    <input
                      type="text"
                      inputMode="decimal"
                      value={val}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value);
                        if (!isNaN(v)) {
                          setExpansionPointValue('y', idx, v);
                        }
                      }}
                      className="w-14 px-1.5 py-1 text-xs text-center font-medium
                                 bg-slate-50 dark:bg-slate-800 rounded
                                 text-slate-700 dark:text-slate-200
                                 border-0 focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
                    />
                  </div>
                ))}
              </div>
            )}

            {xEntries.length === 0 && yEntries.length === 0 && (
              <div className="text-xs text-slate-400 dark:text-slate-600 italic">
                Add inputs to configure expansion point
              </div>
            )}
          </div>
        </div>

        {/* Verbose checkbox */}
        <div className="flex items-center justify-between pt-2 border-t border-slate-100 dark:border-slate-800">
          <div className="flex items-center">
            <span className="text-sm text-slate-600 dark:text-slate-300">Verbose output</span>
            <Tooltip text="Print detailed status messages during compilation and simulation." />
          </div>
          <button
            onClick={() => setVerbose(!config.verbose)}
            className={`w-10 h-5 rounded-full transition-colors relative
                       ${config.verbose 
                         ? 'bg-slate-700 dark:bg-slate-300' 
                         : 'bg-slate-200 dark:bg-slate-700'
                       }`}
          >
            <div 
              className={`absolute top-0.5 w-4 h-4 rounded-full bg-white dark:bg-slate-900
                         transition-transform shadow-sm
                         ${config.verbose ? 'translate-x-5' : 'translate-x-0.5'}`}
            />
          </button>
        </div>
      </div>
    </div>
  );
};
