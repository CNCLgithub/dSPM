import { toSubscript } from '@/utils/subscriptUtils';

/**
 * Calculate angles for distributing ports around a quadrant
 */
export function getPortAngles(count: number, baseAngle: number, spread: number): (number | null)[] {
  if (count === 0) return [];
  if (count === 1) return [baseAngle];
  if (count === 2) return [baseAngle + spread / 2, baseAngle - spread / 2];
  if (count === 3) return [
    baseAngle + spread / 2,
    baseAngle,
    baseAngle - spread / 2,
  ];
  
  // For n > 3: show first two, ellipsis gap, last one
  return [
    baseAngle + spread / 2,      // First
    baseAngle + spread / 4,      // Second
    null,                         // Ellipsis marker
    baseAngle - spread / 2,      // Last
  ];
}

/**
 * Get display labels for ports
 * For n > 3, returns labels for first two, ellipsis, and last
 */
export function getPortLabels(
  count: number,
  prefix: string,
  startIndex: number = 1
): (string | null)[] {
  if (count === 0) return [];
  if (count === 1) return [`${prefix}${toSubscript(startIndex)}`];
  if (count === 2) return [
    `${prefix}${toSubscript(startIndex)}`,
    `${prefix}${toSubscript(startIndex + 1)}`,
  ];
  if (count === 3) return [
    `${prefix}${toSubscript(startIndex)}`,
    `${prefix}${toSubscript(startIndex + 1)}`,
    `${prefix}${toSubscript(startIndex + 2)}`,
  ];
  
  // For n > 3: first two, ellipsis, last
  return [
    `${prefix}${toSubscript(startIndex)}`,
    `${prefix}${toSubscript(startIndex + 1)}`,
    null, // Ellipsis
    `${prefix}${toSubscript(startIndex + count - 1)}`,
  ];
}

/**
 * Convert polar coordinates to cartesian
 * Note: SVG y-axis is inverted, so we negate y
 */
export function polarToCartesian(
  angle: number,
  radius: number
): { x: number; y: number } {
  const rad = (angle * Math.PI) / 180;
  return {
    x: Math.cos(rad) * radius,
    y: -Math.sin(rad) * radius, // Negate for SVG coordinate system
  };
}

/**
 * Calculate the position for a label (offset from the line endpoint)
 */
export function getLabelPosition(
  angle: number,
  radius: number,
  offset: number = 15
): { x: number; y: number } {
  return polarToCartesian(angle, radius + offset);
}

/**
 * Generate a curved path for the feedback arc
 */
export function getFeedbackArcPath(
  fromAngle: number,
  toAngle: number,
  radius: number
): string {
  const start = polarToCartesian(fromAngle, radius);
  const end = polarToCartesian(toAngle, radius);
  
  // Calculate the arc
  const largeArcFlag = Math.abs(toAngle - fromAngle) > 180 ? 1 : 0;
  const sweepFlag = toAngle > fromAngle ? 0 : 1;
  
  return `M ${start.x} ${start.y} A ${radius} ${radius} 0 ${largeArcFlag} ${sweepFlag} ${end.x} ${end.y}`;
}
