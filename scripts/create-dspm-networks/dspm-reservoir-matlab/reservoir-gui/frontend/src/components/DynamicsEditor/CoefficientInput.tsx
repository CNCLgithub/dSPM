import React, { useState, useRef, useMemo } from 'react';
import katex from 'katex';
import { PopupLatexEditor } from './PopupLatexEditor';

interface CoefficientInputProps {
  value: string;
  onChange: (value: string) => void;
  displayIndex: number;
  isRecurrent: boolean;
}

export const CoefficientInput: React.FC<CoefficientInputProps> = ({
  value,
  onChange,
  displayIndex,
  isRecurrent,
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [livePreview, setLivePreview] = useState<string | null>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

  // Use live preview while editing, otherwise use saved value
  const displayValue = isEditing && livePreview !== null ? livePreview : value;

  // Render the tau label - τₙ for external, τₖ for recurrent
  const renderedTauLabel = useMemo(() => {
    try {
      return katex.renderToString(`\\tau_{${displayIndex}}(t)`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `τ${displayIndex}(t)`;
    }
  }, [displayIndex]);

  // Render the coefficient value as LaTeX
  const renderedValue = useMemo(() => {
    try {
      return katex.renderToString(displayValue || '1', {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return displayValue || '1';
    }
  }, [displayValue]);

  // Render equals sign
  const renderedEquals = useMemo(() => {
    try {
      return katex.renderToString(`=`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `=`;
    }
  }, []);

  const handleChange = (newValue: string) => {
    onChange(newValue.trim() || '1');
  };

  const handleClose = () => {
    setIsEditing(false);
    setLivePreview(null);
  };

  const tooltipText = isRecurrent
    ? `Time scale for ẏ${displayIndex}. Default is 1. Can be any function of (x, y).`
    : `Time scale for ẋ${displayIndex}. Default is 1. Can be any function of x.`;

  return (
    <>
      <div 
        className="flex items-center gap-1.5 flex-shrink-0"
        title={tooltipText}
      >
        <span className="text-slate-400 dark:text-slate-500">(</span>
        
        {/* τₙ(t) or τₖ(t) label */}
        <span 
          className="text-slate-500 dark:text-slate-400"
          style={{ fontSize: '1rem' }}
          dangerouslySetInnerHTML={{ __html: renderedTauLabel }}
        />
        
        {/* Equals sign */}
        <span 
          className="text-slate-400 dark:text-slate-500 mx-0.5"
          style={{ fontSize: '1rem' }}
          dangerouslySetInnerHTML={{ __html: renderedEquals }}
        />
        
        {/* Value - click to edit */}
        <button
          ref={buttonRef}
          onClick={() => setIsEditing(true)}
          className={`
            min-w-[1.5rem] px-1.5 py-0.5
            text-base
            bg-slate-50 dark:bg-slate-800
            hover:bg-slate-100 dark:hover:bg-slate-700
            border-0 rounded-md
            text-slate-600 dark:text-slate-300
            transition-colors
            cursor-text
            ${isEditing ? 'ring-2 ring-blue-400 dark:ring-blue-600' : ''}
          `}
        >
          <span dangerouslySetInnerHTML={{ __html: renderedValue }} />
        </button>
        
        <span className="text-slate-400 dark:text-slate-500">)</span>
      </div>

      {/* Popup editor */}
      {isEditing && (
        <PopupLatexEditor
          value={value}
          onChange={handleChange}
          onClose={handleClose}
          onLiveChange={setLivePreview}
          anchorRef={buttonRef}
          placeholder={isRecurrent ? "e.g. 1, y_1^2, \\gamma" : "e.g. 1, x_1^2, \\gamma"}
          minWidth={240}
          maxWidth={360}
        />
      )}
    </>
  );
};
