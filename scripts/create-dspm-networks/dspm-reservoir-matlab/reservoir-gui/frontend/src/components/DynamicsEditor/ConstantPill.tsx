import React, { useState, useRef, useEffect } from 'react';
import katex from 'katex';
import { X } from 'lucide-react';

interface ConstantPillProps {
  id: string;
  latex: string;
  value: string;
  raw: string;
  onUpdate: (id: string, raw: string) => void;
  onRemove: (id: string) => void;
}

export const ConstantPill: React.FC<ConstantPillProps> = ({
  id,
  latex,
  value,
  raw,
  onUpdate,
  onRemove,
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState(raw);
  const [isHovered, setIsHovered] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  // Render the constant as LaTeX
  const renderedConstant = React.useMemo(() => {
    try {
      return katex.renderToString(`${latex} = ${value}`, {
        throwOnError: false,
        displayMode: false,
      });
    } catch {
      return `${latex} = ${value}`;
    }
  }, [latex, value]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      finishEditing();
    } else if (e.key === 'Escape') {
      setEditValue(raw);
      setIsEditing(false);
    }
  };

  const finishEditing = () => {
    if (editValue.trim() && editValue !== raw) {
      onUpdate(id, editValue);
    } else if (!editValue.trim()) {
      setEditValue(raw);
    }
    setIsEditing(false);
  };

  if (isEditing) {
    return (
      <input
        ref={inputRef}
        type="text"
        value={editValue}
        onChange={(e) => setEditValue(e.target.value)}
        onBlur={finishEditing}
        onKeyDown={handleKeyDown}
        className="
          px-2 py-1
          font-mono text-sm
          bg-white dark:bg-slate-900
          border border-slate-300 dark:border-slate-600
          rounded-md
          text-slate-700 dark:text-slate-200
          focus:outline-none focus:ring-2 focus:ring-blue-400 dark:focus:ring-blue-600
          min-w-[100px]
        "
        spellCheck={false}
      />
    );
  }

  return (
    <div
      className="
        group relative inline-flex items-center gap-1
        px-2.5 py-1
        bg-slate-100 dark:bg-slate-800
        hover:bg-slate-200 dark:hover:bg-slate-700
        rounded-md
        cursor-pointer
        transition-colors
      "
      onClick={() => setIsEditing(true)}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <span
        className="text-slate-700 dark:text-slate-300"
        style={{ fontSize: '0.9rem' }}
        dangerouslySetInnerHTML={{ __html: renderedConstant }}
      />
      
      {/* Delete button - appears on hover */}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onRemove(id);
        }}
        className={`
          flex items-center justify-center
          w-4 h-4 ml-0.5
          rounded-full
          text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400
          hover:bg-red-100 dark:hover:bg-red-900/30
          transition-all
          ${isHovered ? 'opacity-100' : 'opacity-0'}
        `}
        title="Remove constant"
      >
        <X className="w-3 h-3" />
      </button>
    </div>
  );
};
