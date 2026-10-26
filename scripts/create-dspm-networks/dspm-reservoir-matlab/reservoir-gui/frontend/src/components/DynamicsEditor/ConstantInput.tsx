import React, { useState, useRef, useEffect } from 'react';

interface ConstantInputProps {
  onSubmit: (raw: string) => boolean | null;  // Returns truthy if successful
  onCancel: () => void;
}

export const ConstantInput: React.FC<ConstantInputProps> = ({
  onSubmit,
  onCancel,
}) => {
  const [value, setValue] = useState('');
  const [hasError, setHasError] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      onCancel();
    }
  };

  const handleSubmit = () => {
    if (!value.trim()) {
      onCancel();
      return;
    }
    
    const result = onSubmit(value);
    if (result) {
      setValue('');
      setHasError(false);
    } else {
      setHasError(true);
      // Shake animation feedback
      inputRef.current?.classList.add('animate-shake');
      setTimeout(() => {
        inputRef.current?.classList.remove('animate-shake');
      }, 300);
    }
  };

  const handleBlur = () => {
    if (!value.trim()) {
      onCancel();
    } else {
      handleSubmit();
    }
  };

  return (
    <input
      ref={inputRef}
      type="text"
      value={value}
      onChange={(e) => {
        setValue(e.target.value);
        setHasError(false);
      }}
      onBlur={handleBlur}
      onKeyDown={handleKeyDown}
      placeholder="\sigma = 10"
      className={`
        px-2 py-1
        font-mono text-sm
        bg-white dark:bg-slate-900
        border rounded-md
        text-slate-700 dark:text-slate-200
        placeholder:text-slate-400 dark:placeholder:text-slate-600
        focus:outline-none focus:ring-2
        min-w-[120px]
        transition-colors
        ${hasError 
          ? 'border-red-400 dark:border-red-600 focus:ring-red-300 dark:focus:ring-red-700' 
          : 'border-slate-300 dark:border-slate-600 focus:ring-blue-400 dark:focus:ring-blue-600'
        }
      `}
      spellCheck={false}
    />
  );
};
