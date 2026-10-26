import React from 'react';
import { NeuronCloud } from './NeuronCloud';
import { PortGroup } from './PortGroup';
import { PortControls } from './PortControls';
import { LoopToggle } from './LoopToggle';
import { FeedbackLoop } from './FeedbackLoop';
import { useReservoirStore } from '@/stores/reservoirStore';
import { useUIStore } from '@/stores/uiStore';

export const NetworkSchematic: React.FC = () => {
  const { config, incrementPort, decrementPort } = useReservoirStore();
  const { isClosedLoop, toggleLoop } = useUIStore();

  const {
    nNeurons,
    numExtInputs,
    numExtOutputs,
    numRecInputs,
    numRecOutputs,
  } = config;

  // SVG dimensions - wider to accommodate side labels and buttons
  const cloudRadius = 60;
  const labelEdgeLeft = -135;   // X position for left-side labels
  const labelEdgeRight = 135;   // X position for right-side labels
  const viewBoxWidth = 450;     // Expanded to fit buttons outside labels
  const viewBoxHeight = 300;    // Taller to give room for corner labels

  return (
    <div className="relative w-full h-full flex flex-col items-center justify-center p-4">
      {/* SVG Network Visualization */}
      <svg
        viewBox={`-${viewBoxWidth/2} -${viewBoxHeight/2} ${viewBoxWidth} ${viewBoxHeight}`}
        className="flex-1 w-full"
        preserveAspectRatio="xMidYMid meet"
      >
        {/* Connection lines (drawn first, under the cloud) */}
        
        {/* External Inputs (Rose, upper left) - xₙ numbering */}
        <PortGroup
          type="ext-in"
          count={numExtInputs}
          cloudRadius={cloudRadius}
          labelEdgeX={labelEdgeLeft}
          startIndex={1}
          verticalOffset={-40}
          onIncrement={() => incrementPort('ext-in')}
          onDecrement={() => decrementPort('ext-in')}
        />
        
        {/* External Outputs (Teal, upper right) - ẋₙ numbering (independent from inputs) */}
        <PortGroup
          type="ext-out"
          count={numExtOutputs}
          cloudRadius={cloudRadius}
          labelEdgeX={labelEdgeRight}
          startIndex={1}
          verticalOffset={-40}
          onIncrement={() => incrementPort('ext-out')}
          onDecrement={() => decrementPort('ext-out')}
        />
        
        {/* Recurrent Inputs (Slate, lower left) - yₖ numbering, tethered to rec-out */}
        <PortGroup
          type="rec-in"
          count={numRecInputs}
          cloudRadius={cloudRadius}
          labelEdgeX={labelEdgeLeft}
          startIndex={1}
          verticalOffset={40}
          onIncrement={() => incrementPort('rec-in')}
          onDecrement={() => decrementPort('rec-in')}
          hideButtons={true}  /* Buttons hidden - rec-in is tethered to rec-out */
        />
        
        {/* Recurrent Outputs (Gold, lower right) - ẏₖ numbering (independent, controls rec-in) */}
        <PortGroup
          type="rec-out"
          count={numRecOutputs}
          cloudRadius={cloudRadius}
          labelEdgeX={labelEdgeRight}
          startIndex={1}
          verticalOffset={40}
          onIncrement={() => incrementPort('rec-out')}
          onDecrement={() => decrementPort('rec-out')}
        />
        
        {/* Feedback loop (only in closed-loop mode) */}
        {isClosedLoop && (numRecOutputs > 0 || numRecInputs > 0) && (
          <FeedbackLoop
            numRecOutputs={numRecOutputs}
            numRecInputs={numRecInputs}
            cloudRadius={cloudRadius}
            labelEdgeRight={labelEdgeRight}
            labelEdgeLeft={labelEdgeLeft}
            verticalOffset={40}
          />
        )}
        
        {/* Neuron cloud (drawn last, on top to mask connection endpoints) */}
        <NeuronCloud
          radius={cloudRadius}
          count={nNeurons}
          isClosedLoop={isClosedLoop}
        />
      </svg>

      {/* Corner labels (just text, no buttons) */}
      <PortControls type="ext-in" count={numExtInputs} />
      <PortControls type="ext-out" count={numExtOutputs} />
      <PortControls type="rec-in" count={numRecInputs} />
      <PortControls type="rec-out" count={numRecOutputs} />

      {/* Loop Toggle (centered at bottom) */}
      <LoopToggle
        isClosedLoop={isClosedLoop}
        onToggle={toggleLoop}
        className="absolute bottom-3 left-1/2 -translate-x-1/2"
      />
    </div>
  );
};
