import React from 'react';

interface PlaceholderPanelProps {
  className?: string;
}

export const PlaceholderPanel: React.FC<PlaceholderPanelProps> = ({ className = '' }) => {
  return (
    <div className={`flex flex-col h-full ${className}`}>
      {/* Header */}
      <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-100 dark:border-slate-800">
        <span className="text-base font-medium text-slate-400 dark:text-slate-500">
          Coming Soon
        </span>
      </div>
      
      {/* Placeholder content */}
      <div className="flex-1 flex items-center justify-center p-6">
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-slate-100 dark:bg-slate-800 
                          flex items-center justify-center">
            <span className="text-2xl text-slate-300 dark:text-slate-600">✦</span>
          </div>
          <p className="text-slate-400 dark:text-slate-600 text-sm">
            Future functionality
          </p>
        </div>
      </div>
    </div>
  );
};
