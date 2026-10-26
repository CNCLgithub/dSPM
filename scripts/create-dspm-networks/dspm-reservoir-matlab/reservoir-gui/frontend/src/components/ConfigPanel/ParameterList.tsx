import React, { useState } from 'react';
import { Plus, X } from 'lucide-react';
import type { ParameterListProps } from './ConfigPanel.types';

export const ParameterList: React.FC<ParameterListProps> = ({
  parameters,
  onAdd,
  onUpdate,
  onRemove,
}) => {
  const [newName, setNewName] = useState('');
  const [newValue, setNewValue] = useState('1');

  const handleAdd = () => {
    if (newName.trim()) {
      onAdd({
        name: newName.trim(),
        value: parseFloat(newValue) || 1,
      });
      setNewName('');
      setNewValue('1');
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleAdd();
    }
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="text-xs text-slate-400 dark:text-slate-600">
        Parameters
      </div>
      
      {/* Existing parameters */}
      <div className="flex flex-col gap-2">
        {parameters.map((param) => (
          <div key={param.name} className="flex items-center gap-2 group">
            <span className="text-sm font-mono text-slate-500 dark:text-slate-400 w-16 truncate">
              {param.name}
            </span>
            <span className="text-slate-300 dark:text-slate-600">=</span>
            <input
              type="number"
              value={param.value}
              onChange={(e) => onUpdate(param.name, parseFloat(e.target.value) || 0)}
              className="w-20 px-2 py-1 text-sm 
                         bg-slate-50 dark:bg-slate-800 
                         border-0 rounded-lg
                         text-slate-700 dark:text-slate-200"
              step="any"
            />
            <button
              onClick={() => onRemove(param.name)}
              className="opacity-0 group-hover:opacity-100 
                         text-slate-400 hover:text-red-500 
                         dark:text-slate-600 dark:hover:text-red-400
                         transition-all p-1"
              title="Remove parameter"
            >
              <X className="w-3 h-3" />
            </button>
          </div>
        ))}
      </div>
      
      {/* Add new parameter */}
      <div className="flex items-center gap-2 pt-2 
                      border-t border-slate-100 dark:border-slate-800">
        <input
          type="text"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="name"
          className="w-16 px-2 py-1 text-sm 
                     bg-transparent border-b border-slate-200 dark:border-slate-700
                     text-slate-600 dark:text-slate-300 
                     placeholder:text-slate-300 dark:placeholder:text-slate-600
                     font-mono"
        />
        <span className="text-slate-300 dark:text-slate-600">=</span>
        <input
          type="number"
          value={newValue}
          onChange={(e) => setNewValue(e.target.value)}
          onKeyDown={handleKeyDown}
          className="w-16 px-2 py-1 text-sm 
                     bg-transparent border-b border-slate-200 dark:border-slate-700
                     text-slate-600 dark:text-slate-300"
          step="any"
        />
        <button
          onClick={handleAdd}
          disabled={!newName.trim()}
          className="p-1.5 rounded-lg
                     text-slate-400 hover:text-slate-600 
                     dark:text-slate-600 dark:hover:text-slate-400
                     hover:bg-slate-100 dark:hover:bg-slate-800
                     disabled:opacity-30 disabled:cursor-not-allowed
                     transition-colors"
          title="Add parameter"
        >
          <Plus className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
};
