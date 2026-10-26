import { useState, useRef } from 'react';
import { Settings2 } from 'lucide-react';

interface SliderProps {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  onChange: (value: number) => void;
  onBoundsChange?: (min: number, max: number) => void;
  color?: string;
  showValue?: boolean;
}

export function Slider({ label, value, min, max, step = 0.01, onChange, onBoundsChange, color = '#e94560', showValue = true }: SliderProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [localMin, setLocalMin] = useState(min);
  const [localMax, setLocalMax] = useState(max);
  const inputRef = useRef<HTMLInputElement>(null);

  const fillPercent = ((value - min) / (max - min)) * 100;

  return (
    <div className="relative group">
      <div className="flex items-center gap-3 py-2">
        <div className="w-16 text-sm font-medium text-wizard-text truncate">{label}</div>
        <div className="flex-1 relative">
          <input type="range" min={min} max={max} step={step} value={value}
            onChange={(e) => onChange(parseFloat(e.target.value))}
            className="w-full h-1 rounded-full appearance-none cursor-pointer"
            style={{ background: `linear-gradient(to right, ${color} 0%, ${color} ${fillPercent}%, #0f3460 ${fillPercent}%, #0f3460 100%)` }}
          />
        </div>
        {showValue && (
          <div className="w-20">
            {isEditing ? (
              <input ref={inputRef} type="number" value={value} step={step}
                onChange={(e) => onChange(parseFloat(e.target.value) || 0)}
                onBlur={() => setIsEditing(false)}
                className="w-full px-2 py-1 text-sm bg-wizard-accent text-wizard-text border border-wizard-highlight rounded text-right font-mono"
              />
            ) : (
              <button onClick={() => { setIsEditing(true); setTimeout(() => inputRef.current?.select(), 0); }}
                className="w-full px-2 py-1 text-sm text-right font-mono text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent/50 rounded">
                {value.toFixed(3)}
              </button>
            )}
          </div>
        )}
        {onBoundsChange && (
          <button onClick={() => setShowSettings(!showSettings)}
            className="p-1 text-wizard-muted hover:text-wizard-text opacity-0 group-hover:opacity-100 transition-opacity">
            <Settings2 className="w-4 h-4" />
          </button>
        )}
      </div>
      {showSettings && onBoundsChange && (
        <div className="absolute right-0 top-full mt-1 z-10 bg-wizard-panel border border-wizard-accent rounded-lg p-3 shadow-xl">
          <div className="text-xs text-wizard-muted mb-2">Slider Bounds</div>
          <div className="flex items-center gap-2">
            <input type="number" value={localMin} onChange={(e) => setLocalMin(parseFloat(e.target.value))}
              className="w-20 px-2 py-1 text-sm bg-wizard-accent text-wizard-text border border-wizard-accent rounded font-mono" placeholder="Min" />
            <span className="text-wizard-muted">to</span>
            <input type="number" value={localMax} onChange={(e) => setLocalMax(parseFloat(e.target.value))}
              className="w-20 px-2 py-1 text-sm bg-wizard-accent text-wizard-text border border-wizard-accent rounded font-mono" placeholder="Max" />
            <button onClick={() => { onBoundsChange(localMin, localMax); setShowSettings(false); }}
              className="px-3 py-1 text-sm bg-wizard-highlight text-white rounded hover:bg-wizard-highlight/80">Apply</button>
          </div>
        </div>
      )}
    </div>
  );
}
