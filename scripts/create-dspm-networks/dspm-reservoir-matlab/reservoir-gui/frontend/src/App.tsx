import React, { useEffect } from 'react';
import { Moon, Sun } from 'lucide-react';
import { NetworkSchematic } from '@/components/NetworkSchematic';
import { ConfigPanel } from '@/components/ConfigPanel';
import { DynamicsEditor } from '@/components/DynamicsEditor';
import { ControlBar } from '@/components/ControlBar';
import { useUIStore } from '@/stores/uiStore';
import { useReservoirStore } from '@/stores/reservoirStore';

const App: React.FC = () => {
  const { isDarkMode, toggleDarkMode, showHeader } = useUIStore();

  useEffect(() => {
    // Signal to MATLAB that we're ready
    if (window.parent && (window as any).matlab) {
      (window as any).matlab.Data = { action: 'ready' };
    }
  }, []);

  useEffect(() => {
    const handleMatlabData = (event: CustomEvent) => {
      const data = event.detail;
      console.log('React received MATLAB data:', data);
      
      if (data?.action === 'init' && data?.payload && !data.payload.standaloneMode) {
        console.log('Init payload:', data.payload);
        // Actually load the data into the store!
        useReservoirStore.getState().loadPresetV2(data.payload);
      }
    };
    
    window.addEventListener('matlabData', handleMatlabData as EventListener);
    
    return () => {
      window.removeEventListener('matlabData', handleMatlabData as EventListener);
    };
  }, []);

  return (
    <div className={`h-screen w-screen min-w-[800px] min-h-[600px] flex flex-col overflow-hidden
                     bg-[#FAFAFA] dark:bg-[#121212] 
                     text-slate-800 dark:text-slate-200
                     transition-colors duration-200`}>
      
      {/* Header - conditional based on showHeader state */}
      {showHeader && (
        <header className="flex items-center justify-between px-6 py-3 
                           border-b border-slate-100 dark:border-slate-800/50">
          <h1 className="text-base font-medium text-slate-600 dark:text-slate-400 tracking-wide">
            Reservoir Programming
          </h1>
          
          {/* Dark mode toggle */}
          <button
            onClick={toggleDarkMode}
            className="p-2 rounded-lg 
                       text-slate-400 hover:text-slate-600 
                       dark:text-slate-500 dark:hover:text-slate-300
                       hover:bg-slate-100 dark:hover:bg-slate-800
                       transition-colors"
            aria-label="Toggle dark mode"
          >
            {isDarkMode ? (
              <Sun className="w-5 h-5" />
            ) : (
              <Moon className="w-5 h-5" />
            )}
          </button>
        </header>
      )}

      {/* Main content */}
      <main className="flex-1 grid grid-cols-2 gap-5 p-5 overflow-hidden">
        
        {/* Left Column */}
        <div className="flex flex-col gap-4 overflow-hidden">
          
          {/* Network Schematic - larger, takes most of the space */}
          <div className="flex-1 min-h-[320px]
                          bg-white dark:bg-[#1E1E1E] 
                          rounded-2xl shadow-soft dark:shadow-none
                          dark:ring-1 dark:ring-slate-800/50">
            <NetworkSchematic />
          </div>
          
          {/* Config Panel - compact, collapsed */}
          <div className="flex-shrink-0
                          bg-white dark:bg-[#1E1E1E] 
                          rounded-2xl shadow-soft dark:shadow-none
                          dark:ring-1 dark:ring-slate-800/50">
            <ConfigPanel />
          </div>
        </div>

        {/* Right Column - Dynamics Editor */}
        <div className="bg-white dark:bg-[#1E1E1E] 
                        rounded-2xl shadow-soft dark:shadow-none
                        dark:ring-1 dark:ring-slate-800/50
                        overflow-hidden flex flex-col">
          <DynamicsEditor className="flex-1 min-h-0" />
        </div>
      </main>

      {/* Control Bar - clean bottom */}
      <ControlBar />
    </div>
  );
};

export default App;
