import { useState } from 'react';
import { ZoomIn, ZoomOut, RotateCcw, Play, Pause } from 'lucide-react';
import { Panel } from '../common/Panel';
import { Slider } from '../common/Slider';
import { useWizardStore } from '../../stores/wizardStore';

const EQUATION_COLORS = ['#e94560', '#4ade80', '#60a5fa', '#fbbf24', '#a78bfa', '#f472b6'];

export function NullclineViewer() {
  const [isAnimating, setIsAnimating] = useState(false);
  const { equations, constants, stateVariables, updateConstant, updateStateVariable } = useWizardStore();

  // Demo data when not connected
  const demoEquations = equations.length > 0 ? equations : [
    { index: 1, latex: '\\sigma(y_2 - y_1)', enabled: true, color: EQUATION_COLORS[0] },
    { index: 2, latex: 'y_1(\\rho - y_3) - y_2', enabled: true, color: EQUATION_COLORS[1] },
    { index: 3, latex: 'y_1 y_2 - \\beta y_3', enabled: true, color: EQUATION_COLORS[2] },
  ];

  const demoConstants = constants.length > 0 ? constants : [
    { name: 'σ', value: 10, min: 0, max: 20, step: 0.1 },
    { name: 'ρ', value: 28, min: 0, max: 50, step: 0.5 },
    { name: 'β', value: 2.667, min: 0, max: 10, step: 0.01 },
  ];

  const demoStateVars = stateVariables.length > 0 ? stateVariables : [
    { name: 'y1', displayName: 'y₁', value: 0, min: -1, max: 1, step: 0.01, isExternal: false },
    { name: 'y2', displayName: 'y₂', value: 0, min: -1, max: 1, step: 0.01, isExternal: false },
    { name: 'y3', displayName: 'y₃', value: 0, min: -1, max: 1, step: 0.01, isExternal: false },
  ];

  return (
    <div className="h-full flex">
      {/* Left Sidebar */}
      <div className="w-80 border-r border-wizard-accent overflow-y-auto p-4 space-y-4">
        <Panel title="Dynamical Equations" collapsible>
          <div className="space-y-2">
            {demoEquations.map((eq, i) => (
              <div key={i} className="flex items-center gap-2 p-2 bg-wizard-bg rounded-lg">
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: eq.color }} />
                <span className="text-sm text-wizard-muted flex-1">ẏ{eq.index} = {eq.latex}</span>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Parameters" collapsible>
          <div className="space-y-1">
            {demoConstants.map((c) => (
              <Slider key={c.name} label={c.name} value={c.value} min={c.min} max={c.max} step={c.step}
                onChange={(v) => updateConstant(c.name, v)} color="#fbbf24" />
            ))}
          </div>
        </Panel>

        <Panel title="State Variables" collapsible>
          <div className="space-y-1">
            {demoStateVars.map((v) => (
              <Slider key={v.name} label={v.displayName} value={v.value} min={v.min} max={v.max} step={v.step}
                onChange={(val) => updateStateVariable(v.name, val)} color={v.isExternal ? '#60a5fa' : '#e94560'} />
            ))}
          </div>
        </Panel>
      </div>

      {/* Main Canvas */}
      <div className="flex-1 flex flex-col">
        <div className="flex items-center gap-2 px-4 py-2 border-b border-wizard-accent">
          <button className="p-2 text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent rounded"><ZoomIn className="w-4 h-4" /></button>
          <button className="p-2 text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent rounded"><ZoomOut className="w-4 h-4" /></button>
          <button className="p-2 text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent rounded"><RotateCcw className="w-4 h-4" /></button>
          <div className="w-px h-6 bg-wizard-accent mx-2" />
          <button onClick={() => setIsAnimating(!isAnimating)}
            className={`p-2 rounded ${isAnimating ? 'bg-wizard-highlight text-white' : 'text-wizard-muted hover:text-wizard-text hover:bg-wizard-accent'}`}>
            {isAnimating ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
          </button>
        </div>
        <div className="flex-1 p-4">
          <div className="w-full h-full viz-canvas grid-overlay flex items-center justify-center">
            <div className="text-center text-wizard-muted">
              <p className="text-lg mb-2">Nullcline Visualization</p>
              <p className="text-sm">Connect to MATLAB to see live nullclines</p>
              <p className="text-xs mt-4">Sliders above control parameters in real-time</p>
            </div>
          </div>
        </div>
      </div>

      {/* Right Sidebar - Eigenanalysis */}
      <div className="w-72 border-l border-wizard-accent overflow-y-auto p-4">
        <Panel title="Eigenanalysis">
          <div className="text-sm text-wizard-muted text-center py-4">
            Run analysis to see fixed points and eigenvalues
          </div>
        </Panel>
        <div className="mt-4">
          <button className="w-full px-4 py-2 bg-wizard-accent text-wizard-text text-sm rounded-lg hover:bg-wizard-highlight transition-colors">
            Run Eigenanalysis
          </button>
        </div>
      </div>
    </div>
  );
}
