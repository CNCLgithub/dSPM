import React, { useRef } from 'react';
import { Moon, Sun } from 'lucide-react';
import { useMatlabBridge } from '@/hooks/useMatlabBridge';
import { useReservoirStore } from '@/stores/reservoirStore';
import { useUIStore } from '@/stores/uiStore';
import { SaveDialog } from '@/components/SaveDialog';
import type { ControlBarProps } from './ControlBar.types';
import type { NetworkSaveFile } from '@/types/saveSchema';

export const ControlBar: React.FC<ControlBarProps> = ({ className = '' }) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const { 
    compile, 
    saveConfig, 
    saveConfigWithDetails,
    exportToWorkspace,
    isSaving,
    showSaveDialog,
    closeSaveDialog,
  } = useMatlabBridge();
  const { isCompiling, equations, networkName, networkDescription, loadPresetV2 } = useReservoirStore();
  const { statusMessage, statusType, isDarkMode, toggleDarkMode, setStatus } = useUIStore();

  const hasEquations = equations.some((eq) => eq.latex.trim() !== '');

  // Status color
  const statusColor = {
    info: 'text-slate-400 dark:text-slate-500',
    success: 'text-emerald-500 dark:text-emerald-400',
    warning: 'text-amber-500 dark:text-amber-400',
    error: 'text-red-500 dark:text-red-400',
  }[statusType];

  // Handle file selection from HTML5 file input
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const json = JSON.parse(event.target?.result as string);
        // Validate it looks like a network file
        if (json.schema_version && json.name && json.config) {
          loadPresetV2(json as NetworkSaveFile & { isBuiltIn: false });
          setStatus(`Loaded: ${json.name}`, 'success');
        } else {
          setStatus('Invalid network file format', 'error');
        }
      } catch {
        setStatus('Failed to parse JSON file', 'error');
      }
    };
    reader.onerror = () => {
      setStatus('Failed to read file', 'error');
    };
    reader.readAsText(file);
    
    // Reset input so same file can be selected again
    e.target.value = '';
  };

  // Trigger file input click
  const handleLoadClick = () => {
    fileInputRef.current?.click();
  };

  return (
    <>
      {/* Hidden file input for fallback Load functionality */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".json"
        onChange={handleFileSelect}
        className="hidden"
      />
      
      <div className={`flex items-center justify-between px-6 py-4 
                       border-t border-slate-100 dark:border-slate-800 
                       bg-white dark:bg-[#1E1E1E] ${className}`}>
        {/* Left side: Secondary actions - ghost buttons */}
        <div className="flex items-center gap-1">
          <button
            onClick={handleLoadClick}
            className="px-3 py-1.5 text-sm 
                       text-slate-500 dark:text-slate-400 
                       hover:text-slate-700 dark:hover:text-slate-200
                       hover:bg-slate-100 dark:hover:bg-slate-800 
                       rounded-lg transition-colors"
          >
            Load
          </button>
          
          <button
            onClick={saveConfig}
            disabled={isSaving}
            className="px-3 py-1.5 text-sm 
                       text-slate-500 dark:text-slate-400 
                       hover:text-slate-700 dark:hover:text-slate-200
                       hover:bg-slate-100 dark:hover:bg-slate-800 
                       disabled:opacity-50 disabled:cursor-not-allowed
                       rounded-lg transition-colors"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
          
          <button
            onClick={exportToWorkspace}
            className="px-3 py-1.5 text-sm 
                       text-slate-500 dark:text-slate-400 
                       hover:text-slate-700 dark:hover:text-slate-200
                       hover:bg-slate-100 dark:hover:bg-slate-800 
                       rounded-lg transition-colors"
          >
            Export
          </button>

          {/* Separator */}
          <div className="w-px h-5 bg-slate-200 dark:bg-slate-700 mx-2" />

          {/* Dark mode toggle */}
          <button
            onClick={toggleDarkMode}
            className="p-1.5 rounded-lg 
                       text-slate-400 hover:text-slate-600 
                       dark:text-slate-500 dark:hover:text-slate-300
                       hover:bg-slate-100 dark:hover:bg-slate-800
                       transition-colors"
            aria-label="Toggle dark mode"
            title={isDarkMode ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {isDarkMode ? (
              <Sun className="w-4 h-4" />
            ) : (
              <Moon className="w-4 h-4" />
            )}
          </button>
        </div>

        {/* Center: Status - just text */}
        <span className={`text-sm ${statusColor}`}>
          {statusMessage}
        </span>

        {/* Right side: Compile button - primary action */}
        <button
          onClick={compile}
          disabled={!hasEquations || isCompiling}
          className="px-5 py-2 text-sm font-medium
                     bg-slate-800 dark:bg-slate-100
                     text-white dark:text-slate-900
                     hover:bg-slate-700 dark:hover:bg-white
                     disabled:bg-slate-200 dark:disabled:bg-slate-800
                     disabled:text-slate-400 dark:disabled:text-slate-600
                     disabled:cursor-not-allowed
                     rounded-xl transition-colors"
        >
          {isCompiling ? 'Compiling...' : 'Compile'}
        </button>
      </div>

      {/* Save Dialog */}
      <SaveDialog
        isOpen={showSaveDialog}
        onClose={closeSaveDialog}
        onSave={saveConfigWithDetails}
        defaultName={networkName}
        defaultDescription={networkDescription}
        isSaving={isSaving}
      />
    </>
  );
};
