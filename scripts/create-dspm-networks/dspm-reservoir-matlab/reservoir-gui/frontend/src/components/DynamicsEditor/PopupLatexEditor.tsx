import React, { useState, useEffect, useRef } from 'react';

interface PopupLatexEditorProps {
  value: string;
  onChange: (value: string) => void;
  onClose: () => void;
  onLiveChange?: (value: string) => void;  // For live preview in anchor
  placeholder?: string;
  anchorRef: React.RefObject<HTMLElement>;
  minWidth?: number;
  maxWidth?: number;
  maxHeight?: number;
}

export const PopupLatexEditor: React.FC<PopupLatexEditorProps> = ({
  value,
  onChange,
  onClose,
  onLiveChange,
  placeholder = 'Enter LaTeX...',
  anchorRef,
  minWidth = 280,
  maxWidth = 400,
  maxHeight = 200,
}) => {
  const [inputValue, setInputValue] = useState(value);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const popupRef = useRef<HTMLDivElement>(null);

  // Position the popup below the anchor element
  useEffect(() => {
    if (anchorRef.current) {
      const rect = anchorRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom + 4,
        left: rect.left,
      });
    }
  }, [anchorRef]);

  // Focus textarea on mount
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.focus();
      // Move cursor to end
      const len = textareaRef.current.value.length;
      textareaRef.current.setSelectionRange(len, len);
    }
  }, []);

  // Handle click outside to close
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        handleSave();
      }
    };

    // Delay adding listener to avoid immediate trigger
    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside);
    }, 10);

    return () => {
      clearTimeout(timer);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [inputValue]);

  // Clean value for rendering (strip newlines)
  const getCleanValue = (val: string) => {
    return val.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
  };

  // Handle input changes with live preview
  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    setInputValue(newValue);
    
    // Update live preview in anchor
    if (onLiveChange) {
      onLiveChange(getCleanValue(newValue));
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSave();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      // Restore original value in preview
      if (onLiveChange) {
        onLiveChange(value);
      }
      onClose();
    }
    // Shift+Enter allows newline (default behavior)
  };

  const handleSave = () => {
    const cleanedValue = getCleanValue(inputValue);
    if (cleanedValue !== value) {
      onChange(cleanedValue);
    }
    onClose();
  };

  return (
    <div
      ref={popupRef}
      className="fixed z-50 flex flex-col gap-2
                 bg-white dark:bg-slate-900
                 border border-slate-200 dark:border-slate-700
                 rounded-xl shadow-lg dark:shadow-2xl
                 p-3"
      style={{
        top: position.top,
        left: position.left,
        minWidth,
        maxWidth,
      }}
    >
      {/* Textarea input */}
      <textarea
        ref={textareaRef}
        value={inputValue}
        onChange={handleInputChange}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        className="
          w-full px-3 py-2
          font-mono text-sm leading-relaxed
          bg-white dark:bg-slate-800
          border border-slate-200 dark:border-slate-600
          rounded-lg
          text-slate-700 dark:text-slate-200
          placeholder:text-slate-400 dark:placeholder:text-slate-600
          focus:outline-none focus:ring-2 focus:ring-blue-400 dark:focus:ring-blue-600
          resize-none
          overflow-y-auto
        "
        style={{
          minHeight: '3rem',
          maxHeight,
          whiteSpace: 'pre-wrap',
          wordWrap: 'break-word',
        }}
        spellCheck={false}
        rows={Math.min(5, Math.max(2, inputValue.split('\n').length))}
      />

      {/* Hint */}
      <div className="text-xs text-slate-400 dark:text-slate-500 px-1 text-center">
        <span>Esc to cancel</span>
        <span className="mx-2">•</span>
        <span>Shift+Enter for newline</span>
      </div>
    </div>
  );
};
