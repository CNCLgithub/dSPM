import React, { useEffect, useRef } from 'react';
import { X, Plus, FileJson } from 'lucide-react';
import type { SavedNetworkSummary } from '@/types/saveSchema';

interface BrowseNetworksDialogProps {
  isOpen: boolean;
  onClose: () => void;
  networks: SavedNetworkSummary[];
  onAddToPresets: (filepath: string) => void;
}

export const BrowseNetworksDialog: React.FC<BrowseNetworksDialogProps> = ({
  isOpen,
  onClose,
  networks,
  onAddToPresets,
}) => {
  const dialogRef = useRef<HTMLDivElement>(null);

  // Close on escape
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    
    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      return () => document.removeEventListener('keydown', handleEscape);
    }
  }, [isOpen, onClose]);

  // Close on click outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40" />

      {/* Dialog */}
      <div
        ref={dialogRef}
        className="relative w-full max-w-lg mx-4
                   bg-white dark:bg-slate-900
                   rounded-2xl shadow-2xl
                   overflow-hidden"
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 
                        border-b border-slate-100 dark:border-slate-800">
          <h2 className="text-lg font-medium text-slate-800 dark:text-slate-100">
            Add to Presets
          </h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg 
                       text-slate-400 hover:text-slate-600
                       dark:text-slate-500 dark:hover:text-slate-300
                       hover:bg-slate-100 dark:hover:bg-slate-800
                       transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 max-h-80 overflow-auto">
          {networks.length === 0 ? (
            <div className="py-8 text-center text-slate-400 dark:text-slate-500">
              <FileJson className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p>No saved networks found</p>
              <p className="text-sm mt-1">
                Save a network first to add it to presets
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              {networks.map((network) => (
                <div
                  key={network.filepath}
                  className="flex items-center gap-3 p-3 
                             bg-slate-50 dark:bg-slate-800/50
                             rounded-xl
                             group"
                >
                  {/* Network info */}
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-slate-700 dark:text-slate-200 truncate">
                      {network.name}
                    </div>
                    {network.description && (
                      <div className="text-sm text-slate-400 dark:text-slate-500 truncate">
                        {network.description}
                      </div>
                    )}
                  </div>

                  {/* Add to presets button */}
                  <button
                    onClick={() => onAddToPresets(network.filepath)}
                    className="p-2 rounded-lg
                               text-slate-400 hover:text-emerald-600
                               dark:text-slate-500 dark:hover:text-emerald-400
                               hover:bg-emerald-50 dark:hover:bg-emerald-900/20
                               opacity-0 group-hover:opacity-100
                               transition-all"
                    title="Add to presets"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-slate-100 dark:border-slate-800
                        bg-slate-50 dark:bg-slate-800/30">
          <p className="text-xs text-slate-400 dark:text-slate-500 text-center">
            Select a network to add it to the presets dropdown
          </p>
        </div>
      </div>
    </div>
  );
};
