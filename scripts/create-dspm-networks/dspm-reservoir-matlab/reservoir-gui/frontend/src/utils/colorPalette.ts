import { PORT_COLORS, type PortColorConfig } from '@/constants/colors';
import type { PortType } from '@/types/reservoir';

/**
 * Get the color configuration for a port type
 */
export function getPortColor(type: PortType): PortColorConfig {
  return PORT_COLORS[type];
}

/**
 * Get the primary color for a port type
 */
export function getPortPrimaryColor(type: PortType): string {
  return PORT_COLORS[type].primary;
}

/**
 * Get the label for a port type
 */
export function getPortLabel(type: PortType): string {
  switch (type) {
    case 'ext-in':
      return 'External Inputs';
    case 'ext-out':
      return 'External Outputs';
    case 'rec-in':
      return 'Recurrent Inputs';
    case 'rec-out':
      return 'Recurrent Outputs';
  }
}

/**
 * Get the variable prefix for a port type
 */
export function getPortVariablePrefix(type: PortType): string {
  switch (type) {
    case 'ext-in':
    case 'rec-in':
      return 'x';
    case 'ext-out':
    case 'rec-out':
      return 'ẋ';
  }
}

/**
 * Get the short label for a port type (plain text fallback)
 */
export function getPortShortLabel(type: PortType): string {
  switch (type) {
    case 'ext-in':
      return 'xₑₓₜ';
    case 'ext-out':
      return 'ẋₑₓₜ';
    case 'rec-in':
      return 'xᵣₑ꜀';
    case 'rec-out':
      return 'ẋᵣₑ꜀';
  }
}

/**
 * Get the LaTeX label for a port type
 */
export function getPortLatexLabel(type: PortType): string {
  switch (type) {
    case 'ext-in':
      return 'x_{\\text{ext}}';
    case 'ext-out':
      return '\\dot{x}_{\\text{ext}}';
    case 'rec-in':
      return 'x_{\\text{rec}}';
    case 'rec-out':
      return '\\dot{x}_{\\text{rec}}';
  }
}
