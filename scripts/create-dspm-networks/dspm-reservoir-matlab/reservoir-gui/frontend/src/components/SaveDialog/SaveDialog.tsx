import React, { useState, useRef, useEffect } from 'react';
import { X } from 'lucide-react';

interface SaveDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (name: string, description: string, addToPresets: boolean) => void;
  defaultName?: string;
  defaultDescription?: string;
  isSaving?: boolean;
}

export const SaveDialog: React.FC<SaveDialogProps> = ({
  isOpen,
  onClose,
  onSave,
  defaultName = '',
  defaultDescription = '',
  isSaving = false,
}) => {
  const [name, setName] = useState(defaultName);
  const [description, setDescription] = useState(defaultDescription);
  const [addToPresets, setAddToPresets] = useState(true);
  const dialogRef = useRef<HTMLDivElement>(null);
  const nameInputRef = useRef<HTMLInputElement>(null);

  // Focus name input when dialog opens
  useEffect(() => {
    if (isOpen && nameInputRef.current) {
      nameInputRef.current.focus();
      nameInputRef.current.select();
    }
  }, [isOpen]);

  // Reset form when dialog opens with new defaults
  useEffect(() => {
    setName(defaultName);
    setDescription(defaultDescription);
  }, [defaultName, defaultDescription, isOpen]);

  // Close on escape
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [isOpen, onClose]);

  // Close on click outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) {
        onClose();
      }
    };

    if (isOpen) {
      // Delay to prevent immediate close from the triggering click
      const timer = setTimeout(() => {
        document.addEventListener('mousedown', handleClickOutside);
      }, 10);
      return () => {
        clearTimeout(timer);
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [isOpen, onClose]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (name.trim()) {
      onSave(name.trim(), description.trim(), addToPresets);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 dark:bg-black/50">
      <div
        ref={dialogRef}
        className="w-full max-w-md mx-4
                   bg-white dark:bg-slate-900
                   border border-slate-200 dark:border-slate-700
                   rounded-2xl shadow-2xl"
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 
                        border-b border-slate-100 dark:border-slate-800">
          <h2 className="text-base font-medium text-slate-700 dark:text-slate-200">
            Save Network
          </h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-600
                       dark:text-slate-500 dark:hover:text-slate-300
                       hover:bg-slate-100 dark:hover:bg-slate-800
                       transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          {/* Name */}
          <div>
            <label 
              htmlFor="network-name"
              className="block text-sm font-medium text-slate-600 dark:text-slate-400 mb-1.5"
            >
              Name
            </label>
            <input
              ref={nameInputRef}
              id="network-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="My Network"
              className="w-full px-3 py-2 text-sm
                         bg-slate-50 dark:bg-slate-800 
                         border border-slate-200 dark:border-slate-700
                         rounded-lg
                         text-slate-700 dark:text-slate-200
                         placeholder:text-slate-400 dark:placeholder:text-slate-600
                         focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
          </div>

          {/* Description */}
          <div>
            <label 
              htmlFor="network-description"
              className="block text-sm font-medium text-slate-600 dark:text-slate-400 mb-1.5"
            >
              Description <span className="text-slate-400 dark:text-slate-600 font-normal">(optional)</span>
            </label>
            <textarea
              id="network-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief description of the network dynamics..."
              rows={3}
              className="w-full px-3 py-2 text-sm resize-none
                         bg-slate-50 dark:bg-slate-800 
                         border border-slate-200 dark:border-slate-700
                         rounded-lg
                         text-slate-700 dark:text-slate-200
                         placeholder:text-slate-400 dark:placeholder:text-slate-600
                         focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
          </div>

          {/* Add to presets checkbox */}
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={addToPresets}
              onChange={(e) => setAddToPresets(e.target.checked)}
              className="w-4 h-4 rounded
                         text-slate-700 dark:text-slate-300
                         border-slate-300 dark:border-slate-600
                         bg-slate-50 dark:bg-slate-800
                         focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600"
            />
            <span className="text-sm text-slate-600 dark:text-slate-400">
              Add to presets
            </span>
          </label>

          {/* Buttons */}
          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={isSaving}
              className="px-4 py-2 text-sm font-medium
                         text-slate-600 dark:text-slate-400
                         hover:text-slate-800 dark:hover:text-slate-200
                         hover:bg-slate-100 dark:hover:bg-slate-800
                         rounded-lg transition-colors
                         disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || isSaving}
              className="px-5 py-2 text-sm font-medium
                         bg-slate-800 dark:bg-slate-100
                         text-white dark:text-slate-900
                         hover:bg-slate-700 dark:hover:bg-white
                         disabled:bg-slate-300 dark:disabled:bg-slate-700
                         disabled:text-slate-500 dark:disabled:text-slate-500
                         disabled:cursor-not-allowed
                         rounded-lg transition-colors"
            >
              {isSaving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
