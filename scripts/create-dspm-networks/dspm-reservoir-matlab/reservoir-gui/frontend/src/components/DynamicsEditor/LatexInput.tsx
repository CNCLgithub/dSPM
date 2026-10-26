import React, { useState, useRef, useMemo } from 'react';
import katex from 'katex';
import { prepareForKatex } from '@/utils/latexParser';
import { PopupLatexEditor } from './PopupLatexEditor';
import type { LatexInputProps } from './DynamicsEditor.types';

export const LatexInput: React.FC<LatexInputProps> = ({
  value,
  onChange,
  placeholder = 'f(\\vec{x}, \\vec{y})',
  isValid = true,
  // errorMessage - could be used for popup validation display in future
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [livePreview, setLivePreview] = useState<string | null>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

  // Use live preview while editing, otherwise use saved value
  const displayValue = isEditing && livePreview !== null ? livePreview : value;

  // Render the equation as LaTeX
  const renderedEquation = useMemo(() => {
    if (!displayValue.trim()) {
      return null;
    }
    try {
      const prepared = prepareForKatex(displayValue);
      return katex.renderToString(prepared, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return null;
    }
  }, [displayValue]);

  // Render placeholder as LaTeX
  const renderedPlaceholder = useMemo(() => {
    try {
      return katex.renderToString(placeholder, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return placeholder;
    }
  }, [placeholder]);

  const handleClose = () => {
    setIsEditing(false);
    setLivePreview(null);
  };

  return (
    <>
      <button
        ref={buttonRef}
        onClick={() => setIsEditing(true)}
        className={`
          flex-1 text-left px-3 py-2
          rounded-lg
          transition-colors
          cursor-text
          min-h-[2.5rem]
          bg-slate-50 dark:bg-slate-800/50
          hover:bg-slate-100 dark:hover:bg-slate-800
          ${!isValid ? 'ring-1 ring-red-300 dark:ring-red-800' : ''}
          ${isEditing ? 'ring-2 ring-blue-400 dark:ring-blue-600' : ''}
        `}
      >
        {renderedEquation ? (
          <span 
            className="text-slate-700 dark:text-slate-200"
            style={{ fontSize: '1.1rem' }}
            dangerouslySetInnerHTML={{ __html: renderedEquation }} 
          />
        ) : (
          <span 
            className="text-slate-300 dark:text-slate-600 italic opacity-70"
            style={{ fontSize: '1rem' }}
            dangerouslySetInnerHTML={{ __html: renderedPlaceholder }}
          />
        )}
      </button>

      {/* Popup editor */}
      {isEditing && (
        <PopupLatexEditor
          value={value}
          onChange={onChange}
          onClose={handleClose}
          onLiveChange={setLivePreview}
          anchorRef={buttonRef}
          placeholder="e.g. \\sigma (x_2 - x_1)"
          minWidth={320}
          maxWidth={480}
        />
      )}
    </>
  );
};
