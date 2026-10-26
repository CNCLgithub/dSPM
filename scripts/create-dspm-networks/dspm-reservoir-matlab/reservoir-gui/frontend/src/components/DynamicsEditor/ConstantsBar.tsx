import React, { useState } from 'react';
import { ConstantPill } from './ConstantPill';
import { ConstantInput } from './ConstantInput';
import { useReservoirStore } from '@/stores/reservoirStore';

export const ConstantsBar: React.FC = () => {
  const { constants, addConstant, updateConstant, removeConstant } = useReservoirStore();
  const [isAddingConstant, setIsAddingConstant] = useState(false);

  const handleAddConstant = (raw: string) => {
    const result = addConstant(raw);
    if (result) {
      setIsAddingConstant(false);
      return true;
    }
    return null;
  };

  return (
    <div className="flex items-center gap-2 flex-wrap">
      {/* Add constant button - comes first */}
      {isAddingConstant ? (
        <ConstantInput
          onSubmit={handleAddConstant}
          onCancel={() => setIsAddingConstant(false)}
        />
      ) : (
        <button
          onClick={() => setIsAddingConstant(true)}
          className="
            inline-flex items-center gap-1.5
            px-2 py-1
            text-sm font-medium
            text-slate-400 dark:text-slate-500
            hover:text-slate-600 dark:hover:text-slate-300
            hover:bg-slate-100 dark:hover:bg-slate-800
            rounded-md
            transition-colors
          "
          title="Add constant definition"
        >
          <span className="text-base">⊕</span>
          <span>const</span>
        </button>
      )}

      {/* Divider - only show if there are constants */}
      {constants.length > 0 && (
        <div className="h-4 w-px bg-slate-200 dark:bg-slate-700 mx-1" />
      )}

      {/* Rendered constants - flow to the right */}
      {constants.map((constant) => (
        <ConstantPill
          key={constant.id}
          id={constant.id}
          latex={constant.latex}
          value={constant.value}
          raw={constant.raw}
          onUpdate={updateConstant}
          onRemove={removeConstant}
        />
      ))}
    </div>
  );
};
