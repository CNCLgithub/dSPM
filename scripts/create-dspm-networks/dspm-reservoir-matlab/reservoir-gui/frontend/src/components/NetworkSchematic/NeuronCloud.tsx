import React, { useMemo } from 'react';
import { getPortPrimaryColor } from '@/utils/colorPalette';

interface NeuronCloudProps {
  radius: number;
  count: number;
  isClosedLoop: boolean;
}

// Tuned hyperparameters (Generation 13) - evolved via interactive selection
const NEURON_CLOUD_PARAMS = {
  threshold: 0.8474,
  outerRouteRatio: 0.4343,
  curveMagnitude: 0.3344,
  loopSize: 8.0334,
  neuronSpread: 0.7864,
  arrowScale: 0.9562,
};

// Simple seeded random for deterministic results
const seededRandom = (seed: number) => {
  const x = Math.sin(seed * 9999) * 10000;
  return x - Math.floor(x);
};

// Generate a unique seed per component instance (stable across re-renders)
const generateInstanceSeed = () => Math.floor(Math.random() * 100000);

export const NeuronCloud: React.FC<NeuronCloudProps> = ({
  radius,
  count: _count,
  isClosedLoop,
}) => {
  const goldColor = getPortPrimaryColor('rec-out');
  const blueColor = getPortPrimaryColor('rec-in');
  
  // Stable random seed for this instance
  const instanceSeed = useMemo(() => generateInstanceSeed(), []);
  
  const { threshold, outerRouteRatio, curveMagnitude, loopSize, neuronSpread, arrowScale } = NEURON_CLOUD_PARAMS;
  
  // Scattered neurons using golden angle distribution
  const neurons = useMemo(() => {
    const n = 10;
    const points = [];
    for (let i = 0; i < n; i++) {
      const theta = i * 2.399963229728653; // Golden angle
      const r = Math.sqrt((i + 0.5) / n) * (radius * neuronSpread);
      points.push({
        x: Math.cos(theta) * r,
        y: Math.sin(theta) * r,
        idx: i,
      });
    }
    return points;
  }, [radius, neuronSpread]);

  // Generate connections with tuned parameters
  const connections = useMemo(() => {
    if (!isClosedLoop) return [];
    
    const n = neurons.length;
    const baseSeed = instanceSeed;
    
    // Generate adjacency matrix with values in [-1, 1]
    const adjacency: number[][] = [];
    for (let i = 0; i < n; i++) {
      adjacency[i] = [];
      for (let j = 0; j < n; j++) {
        const seed = baseSeed * 10000 + i * 1000 + j * 37 + 42;
        adjacency[i][j] = seededRandom(seed) * 2 - 1;
      }
    }
    
    // Ensure every neuron has at least one outgoing connection
    for (let i = 0; i < n; i++) {
      const hasConnection = adjacency[i].some((w, j) => j !== i && Math.abs(w) > threshold);
      if (!hasConnection) {
        const target = (i + 3) % n;
        adjacency[i][target] = seededRandom(baseSeed * 1000 + i * 777) > 0.5 ? 0.95 : -0.95;
      }
    }
    
    // Convert to connection list with outer route determination
    const conns: Array<{
      from: number;
      to: number;
      weight: number;
      outerRoute: boolean;
      key: string;
    }> = [];
    
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) {
        const w = adjacency[i][j];
        if (Math.abs(w) > threshold) {
          // Determine if this connection takes outer route
          const routeSeed = baseSeed * 7777 + i * 100 + j;
          const takeOuterRoute = i !== j && seededRandom(routeSeed) < outerRouteRatio;
          conns.push({ from: i, to: j, weight: w, outerRoute: takeOuterRoute, key: `${i}-${j}` });
        }
      }
    }
    
    conns.sort((a, b) => Math.abs(a.weight) - Math.abs(b.weight));
    return conns;
  }, [isClosedLoop, neurons.length, instanceSeed, threshold, outerRouteRatio]);

  // Create curved path with outer route support
  const createRoutedPath = (fromIdx: number, toIdx: number, outerRoute: boolean): string => {
    const from = neurons[fromIdx];
    const to = neurons[toIdx];
    
    // Self-loop
    if (fromIdx === toIdx) {
      const dist = Math.sqrt(from.x * from.x + from.y * from.y);
      const dirX = dist > 0.1 ? from.x / dist : 1;
      const dirY = dist > 0.1 ? from.y / dist : 0;
      const ls = loopSize;
      const outX = from.x + dirX * ls;
      const outY = from.y + dirY * ls;
      const perpX = -dirY;
      const perpY = dirX;
      const w = ls * 0.4;
      
      return `M ${from.x} ${from.y} 
              C ${from.x + dirX * (ls * 0.4) + perpX * w} ${from.y + dirY * (ls * 0.4) + perpY * w},
                ${outX + perpX * w} ${outY + perpY * w},
                ${outX} ${outY}
              C ${outX - perpX * w} ${outY - perpY * w},
                ${from.x + dirX * (ls * 0.4) - perpX * w} ${from.y + dirY * (ls * 0.4) - perpY * w},
                ${from.x} ${from.y}`;
    }
    
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    
    // Outer route - curve around the periphery
    if (outerRoute) {
      const fromAngle = Math.atan2(from.y, from.x);
      const toAngle = Math.atan2(to.y, to.x);
      
      let angleDiff = toAngle - fromAngle;
      if (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
      if (angleDiff < -Math.PI) angleDiff += Math.PI * 2;
      
      // Sometimes take the long way around for visual variety
      const goLongWay = seededRandom(fromIdx * 200 + toIdx * 3 + instanceSeed) > 0.5;
      if (goLongWay && Math.abs(angleDiff) < Math.PI * 0.7) {
        angleDiff = angleDiff > 0 ? angleDiff - Math.PI * 2 : angleDiff + Math.PI * 2;
      }
      
      const arcRadius = radius * 0.92;
      const ctrl1Angle = fromAngle + angleDiff * 0.33;
      const ctrl2Angle = fromAngle + angleDiff * 0.67;
      
      const ctrl1X = Math.cos(ctrl1Angle) * arcRadius;
      const ctrl1Y = Math.sin(ctrl1Angle) * arcRadius;
      const ctrl2X = Math.cos(ctrl2Angle) * arcRadius;
      const ctrl2Y = Math.sin(ctrl2Angle) * arcRadius;
      
      return `M ${from.x} ${from.y} C ${ctrl1X} ${ctrl1Y}, ${ctrl2X} ${ctrl2Y}, ${to.x} ${to.y}`;
    }
    
    // Interior route - simple quadratic curve
    const perpX = -dy / dist;
    const perpY = dx / dist;
    const curveMag = dist * curveMagnitude * (seededRandom(fromIdx * 100 + toIdx + instanceSeed) > 0.5 ? 1 : -1);
    const midX = (from.x + to.x) / 2 + perpX * curveMag;
    const midY = (from.y + to.y) / 2 + perpY * curveMag;
    
    return `M ${from.x} ${from.y} Q ${midX} ${midY} ${to.x} ${to.y}`;
  };

  // Get arrowhead angle based on path type
  const getArrowhead = (fromIdx: number, toIdx: number, outerRoute: boolean) => {
    const from = neurons[fromIdx];
    const to = neurons[toIdx];
    
    if (fromIdx === toIdx) {
      const dist = Math.sqrt(from.x * from.x + from.y * from.y);
      const dirX = dist > 0.1 ? from.x / dist : 1;
      const dirY = dist > 0.1 ? from.y / dist : 0;
      return { x: from.x, y: from.y, angle: Math.atan2(-dirY, -dirX) + 0.35 };
    }
    
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    
    // Outer route arrow direction
    if (outerRoute) {
      const fromAngle = Math.atan2(from.y, from.x);
      const toAngle = Math.atan2(to.y, to.x);
      let angleDiff = toAngle - fromAngle;
      if (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
      if (angleDiff < -Math.PI) angleDiff += Math.PI * 2;
      
      const goLongWay = seededRandom(fromIdx * 200 + toIdx * 3 + instanceSeed) > 0.5;
      if (goLongWay && Math.abs(angleDiff) < Math.PI * 0.7) {
        angleDiff = angleDiff > 0 ? angleDiff - Math.PI * 2 : angleDiff + Math.PI * 2;
      }
      
      const arcRadius = radius * 0.92;
      const ctrl2Angle = fromAngle + angleDiff * 0.67;
      const ctrl2X = Math.cos(ctrl2Angle) * arcRadius;
      const ctrl2Y = Math.sin(ctrl2Angle) * arcRadius;
      
      return { x: to.x, y: to.y, angle: Math.atan2(to.y - ctrl2Y, to.x - ctrl2X) };
    }
    
    // Interior route arrow direction
    const perpX = -dy / dist;
    const perpY = dx / dist;
    const curveMag = dist * curveMagnitude * (seededRandom(fromIdx * 100 + toIdx + instanceSeed) > 0.5 ? 1 : -1);
    const midX = (from.x + to.x) / 2 + perpX * curveMag;
    const midY = (from.y + to.y) / 2 + perpY * curveMag;
    return { x: to.x, y: to.y, angle: Math.atan2(to.y - midY, to.x - midX) };
  };

  return (
    <g>
      {/* Background circle */}
      <circle
        cx={0}
        cy={0}
        r={radius}
        className="fill-slate-50 dark:fill-slate-800/50"
        stroke={isClosedLoop ? '#64748b' : '#e2e8f0'}
        strokeWidth={isClosedLoop ? 2 : 1.5}
        strokeDasharray={isClosedLoop ? undefined : '4 3'}
      />
      
      {/* Connections */}
      {isClosedLoop && connections.map((conn) => {
        const absWeight = Math.abs(conn.weight);
        const color = conn.weight > 0 ? goldColor : blueColor;
        const strokeWidth = 1.2 + (absWeight - threshold) * 5;
        const opacity = 0.6 + (absWeight - threshold) * 1.5;
        
        const pathD = createRoutedPath(conn.from, conn.to, conn.outerRoute);
        const arrow = getArrowhead(conn.from, conn.to, conn.outerRoute);
        const arrowSize = (3.5 + strokeWidth * 0.6) * arrowScale;
        
        // Offset arrow so tip touches neuron boundary
        const neuronRadius = 3.5;
        const tipOffset = neuronRadius + arrowSize * 0.3;
        const arrowX = arrow.x - Math.cos(arrow.angle) * tipOffset;
        const arrowY = arrow.y - Math.sin(arrow.angle) * tipOffset;
        
        return (
          <g key={conn.key}>
            <path
              d={pathD}
              fill="none"
              stroke={color}
              strokeWidth={strokeWidth}
              strokeLinecap="round"
              opacity={opacity}
            />
            <polygon
              points={`
                ${arrowX + Math.cos(arrow.angle) * arrowSize * 0.3},${arrowY + Math.sin(arrow.angle) * arrowSize * 0.3}
                ${arrowX + Math.cos(arrow.angle + 2.5) * arrowSize},${arrowY + Math.sin(arrow.angle + 2.5) * arrowSize}
                ${arrowX + Math.cos(arrow.angle - 2.5) * arrowSize},${arrowY + Math.sin(arrow.angle - 2.5) * arrowSize}
              `}
              fill={color}
              opacity={Math.min(opacity + 0.1, 0.95)}
            />
          </g>
        );
      })}
      
      {/* Neuron dots */}
      {neurons.map((p, i) => (
        <circle
          key={i}
          cx={p.x}
          cy={p.y}
          r={3.5}
          className={isClosedLoop 
            ? 'fill-slate-500 dark:fill-slate-400' 
            : 'fill-slate-300 dark:fill-slate-600'}
        />
      ))}
    </g>
  );
};
