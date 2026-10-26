import { useState } from 'react';
import { ZoomIn, ZoomOut, RotateCcw, Play, Pause, Plus } from 'lucide-react';
import { Panel } from '../common/Panel';
import { Slider } from '../common/Slider';
import { useWizardStore } from '../../stores/wizardStore';

export function FlowFieldViewer() {
  const [isAnimating, setIsAnimating] = useState(false);
  const [is3D, setIs3D] = useState(false);
  const [arrowDensity, setArrowDensity] = useState(20);
  const [trajectoryICs, setTrajectoryICs] = useState<number[][]>([]);
  const { showNullclines, showFixedPoints, toggleNullclines, toggleFixedPoints } = useWizardStore();

  return (
    <div className="h-full flex">
      {/* Left Sidebar */}
      <div className="w-72 border-r border-wizard-accent overflow-y-auto p-4 space-y-4">
        <Panel title="View Settings">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-wizard-muted">Dimension</span>
              <div className="flex rounded-lg border border-wizard-accent overflow-hidden">
                <button onClick={() => setIs3D(false)} className={`px-3 py-1 text-sm ${!is3D ? 'bg-wizard-highlight text-white' : 'text-wizard-muted'}`}>2D</button>
                <button onClick={() => setIs3D(true)} className={`px-3 py-1 text-sm ${is3D ? 'bg-wizard-highlight text-white' : 'text-wizard-muted'}`}>3D</button>
              </div>
            </div>
            <Slider label="Density" value={arrowDensity} min={5} max={50} step={1} onChange={setArrowDensity} color="#60a5fa" />
          </div>
        </Panel>

        <Panel title="Display Options">
          <div className="space-y-3">
            <label className="flex items-center gap-3">
              <input type="checkbox" checked={showNullclines} onChange={toggleNullclines} className="rounded" />
              <span className="text-sm text-wizard-muted">Show Nullclines</span>
            </label>
            <label className="flex items-center gap-3">
              <input type="checkbox" checked={showFixedPoints} onChange={toggleFixedPoints} className="rounded" />
              <span className="text-sm text-wizard-muted">Show Fixed Points</span>
            </label>
          </div>
        </Panel>

        <Panel title="Trajectories" headerRight={
          <button onClick={() => setTrajectoryICs([...trajectoryICs, [0, 0, 0]])} className="p-1 text-wizard-muted hover:text-wizard-text">
            <Plus className="w-4 h-4" />
          </button>
        }>
          {trajectoryICs.length === 0 ? (
            <div className="text-sm text-wizard-muted text-center py-2">Click + to add initial conditions</div>
          ) : (
            <div className="space-y-2">
              {trajectoryICs.map((ic, i) => (
                <div key={i} className="flex items-center gap-2 p-2 bg-wizard-bg rounded text-xs font-mono">
                  [{ic.map(v => v.toFixed(2)).join(', ')}]
                </div>
              ))}
            </div>
          )}
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
          <span className="ml-auto text-sm text-wizard-muted">Click canvas to add trajectory IC</span>
        </div>
        <div className="flex-1 p-4">
          <div className="w-full h-full viz-canvas grid-overlay flex items-center justify-center">
            <div className="text-center text-wizard-muted">
              <p className="text-lg mb-2">{is3D ? '3D' : '2D'} Flow Field</p>
              <p className="text-sm">Vector field visualization with trajectories</p>
              <p className="text-xs mt-4">Uses D3.js for 2D, Three.js for 3D</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
